import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:mysql1_ext/src/auth/handshake_handler.dart';
import 'package:mysql1_ext/src/auth/ssl_handler.dart';
import 'package:mysql1_ext/src/buffer.dart';
import 'package:mysql1_ext/src/buffered_socket.dart';
import 'package:mysql1_ext/src/connection_settings.dart';
import 'package:mysql1_ext/src/handlers/handler.dart';
import 'package:mysql1_ext/src/handlers/quit_handler.dart';
import 'package:mysql1_ext/src/mysql_client_error.dart';
import 'package:mysql1_ext/src/mysql_exception.dart';
import 'package:mysql1_ext/src/query/query_builder.dart';
import 'package:mysql1_ext/src/query/query_stream_handler.dart';
import 'package:mysql1_ext/src/results/field.dart';
import 'package:mysql1_ext/src/results/results_impl.dart';
import 'package:mysql1_ext/src/results/row.dart';

final Logger _log = Logger('MySqlConnection');

/// Represents a connection to the database. Use [connect] to open a connection. You
/// must call [close] when you are done.
class MySqlConnection {
  MySqlConnection(this._timeout, this._conn);

  final Duration _timeout;

  final ReqRespConnection _conn;
  bool _sentClose = false;
  bool get isClosed => _conn._socket.closed;

  /// Close the connection
  ///
  /// This method will never throw
  Future<void> close() async {
    if (_sentClose) return;
    _sentClose = true;

    try {
      await _conn.processHandlerNoResponse(QuitHandler(), _timeout);
    } catch (e, st) {
      _log.warning('Error sending quit on connection', e, st);
    }

    _conn.close();
  }

  /// Connects a MySQL server at the given [host] on [port], authenticates using [user]
  /// and [password] and connects to [db].
  ///
  /// [c.timeout] is used as the connection timeout and the default timeout for all socket
  /// communication.
  ///
  /// A [SocketException] is thrown on connection failure or a socket timeout connecting the
  /// socket.
  /// A [TimeoutException] is thrown if there is a timeout in the handshake with the
  /// server.
  static Future<MySqlConnection> connect(
    ConnectionSettings c, {
    bool isUnixSocket = false,
  }) async {
    assert(!c.useSSL); // Not implemented
    assert(!c.useCompression);

    ReqRespConnection? conn;
    late Completer<void> handshakeCompleter;
    _log.fine('opening connection to ${c.host}:${c.port}/${c.db}');

    final socket = await BufferedSocket.connect(
      c.host,
      c.port,
      c.timeout,
      isUnixSocket: isUnixSocket,
      onDataReady: () {
        conn?._readPacket();
      },
      onDone: () {
        _log.fine('done');
      },
      onError: (Object error) {
        _log.warning('socket error: $error');

        // If conn has not been connected there was a connection error.
        if (conn == null) {
          handshakeCompleter.completeError(error);
        } else {
          conn.handleError(error);
        }
      },
      onClosed: () {
        if (conn != null) {
          conn.handleError(const SocketException.closed());
        }
      },
    );

    final Handler handler = HandshakeHandler(
      c.user,
      c.password,
      c.maxPacketSize,
      c.characterSet,
      c.db,
      c.useCompression,
      c.useSSL,
    );
    handshakeCompleter = Completer<void>();
    conn = ReqRespConnection(socket, handler, handshakeCompleter, c.maxPacketSize);

    await handshakeCompleter.future.timeout(c.timeout);
    return MySqlConnection(c.timeout, conn);
  }

  /// Run [sql] query on the database using [values] as positional sql parameters.
  ///
  /// eg. ```query('SELECT FROM users WHERE id = ?', [userId])```.
  Future<Results> query(String sql, [List<Object?>? values]) async {
    if (values == null || values.isEmpty) {
      return _conn.processHandlerWithResults(QueryStreamHandler(sql), _timeout);
    }

    return (await queryMulti(sql, [values])).first;
  }

  /// Run [sql] query multiple times for each set of positional sql parameters in [values].
  ///
  /// e.g. ```queryMulti('INSERT INTO USERS (name) VALUES (?)', ['Adam', 'Eve'])```.
  Future<List<Results>> queryMulti(
    String sql,
    Iterable<List<Object?>> values,
  ) async {
    final ret = <Results>[];
    var nSql = sql.replaceAll(RegExp(r'\?+'), '?');
    var index = 0;
    nSql = nSql.replaceAllMapped(RegExp(r'\?'), (m) => ':dr${index++}');

    for (final v in values) {
      final params = <String, dynamic>{};
      final cnt = v.length;
      for (var i = 0; i < cnt; i++) {
        params.addAll({'dr$i': v[i]});
      }
      ret.add(await execute(nSql, params));
    }

    return ret;
  }

  /// This method is the same `query`, however this will use parameter name.
  ///
  /// eg. ```execute('SELECT * FROM sessions WHERE session_id=:sid LIMIT 1', {'sid':'THIS IS SAMPLE SESSION'})```.
  Future<Results> execute(String sql, [Map<String, dynamic>? params]) {
    if (params != null && params.isNotEmpty) {
      sql = QueryBuilder(sql, params).toString();
    }
    return _conn.processHandlerWithResults(QueryStreamHandler(sql), _timeout);
  }

  Future<T?> transaction<T>(
    Future<T> Function(TransactionContext) queryBlock, {
    void Function(Object)? onError,
  }) async {
    await query('start transaction');
    try {
      final result = await queryBlock(TransactionContext._(this));
      await query('commit');
      return result;
    } catch (e) {
      await query('rollback');
      if (e is! _RollbackError) {
        rethrow;
      }
      onError?.call(e);
      return null;
    }
  }
}

class TransactionContext {
  TransactionContext._(this._conn);

  final MySqlConnection _conn;

  Future<Results> query(String sql, [List<Object?>? values]) => _conn.query(sql, values);

  Future<List<Results>> queryMulti(
    String sql,
    Iterable<List<Object?>> values,
  ) =>
      _conn.queryMulti(sql, values);

  Future<Results> execute(
    String sql, [
    Map<String, dynamic>? params,
  ]) =>
      _conn.execute(sql, params);

  void rollback() => throw _RollbackError();
}

class _RollbackError {}

/// An iterable of result rows returned by [MySqlConnection.query] or [MySqlConnection.queryMulti].
class Results extends IterableBase<ResultRow> {
  Results._(this._rows, this.fields, this.insertId, this.affectedRows);

  final int? insertId;
  final int? affectedRows;
  final List<Field> fields;
  final List<ResultRow> _rows;

  static Future<Results> _read(ResultsStream r) async {
    return r.toList().then((row) => Results._(row, r.fields, r.insertId, r.affectedRows));
  }

  static Results _empty() => Results._([], [], 0, 0);

  @override
  Iterator<ResultRow> get iterator => _rows.iterator;

  /// Return as List of Rows as Map
  Future<List<Map<String, dynamic>>> asMap([
    FutureOr<void> Function(Map<String, dynamic>)? onEachRow,
  ]) async {
    List<Map<String, dynamic>> lst = List.empty(growable: true);

    for (ResultRow rr in _rows) {
      var row = rr.fields;
      if (onEachRow != null) await onEachRow(row);
      lst.add(row);
    }
    return lst;
  }
}

class ReqRespConnection {
  ReqRespConnection(
    this._socket,
    this._handler,
    Completer<void>? handshakeCompleter,
    this._maxPacketSize,
  )   : _headerBuffer = Buffer(HEADER_SIZE),
        _compressedHeaderBuffer = Buffer(COMPRESSED_HEADER_SIZE),
        _completer = handshakeCompleter;
  static const int HEADER_SIZE = 4;
  static const int COMPRESSED_HEADER_SIZE = 7;
  static const int STATE_PACKET_HEADER = 0;
  static const int STATE_PACKET_DATA = 1;

  Handler? _handler;
  Completer<void>? _completer;

  final BufferedSocket _socket;
  final _largePacketBuffers = <Buffer>[];

  final Buffer _headerBuffer;
  final Buffer _compressedHeaderBuffer;

  bool _readyForHeader = true;

  int _packetNumber = 0;

  int _compressedPacketNumber = 0;
  bool _useCompression = false;
  bool _useSSL = false;
  final int _maxPacketSize;

  void close() => _socket.close();

  void handleError(Object e, {bool keepOpen = false, StackTrace? st}) {
    if (_completer?.isCompleted ?? false) {
      _log.warning('Ignoring error because no response', e, st);
    } else {
      _completer?.completeError(e, st);
    }
    if (!keepOpen) {
      close();
    }
  }

  Future<void> _readPacket() async {
    _log.fine('readPacket readyForHeader=$_readyForHeader');
    if (_readyForHeader) {
      _readyForHeader = false;
      final buffer = await _socket.readBuffer(_headerBuffer);
      await _handleHeader(buffer);
    }
  }

  Future<void> _handleHeader(Buffer buffer) async {
    final dataSize = buffer[0] + (buffer[1] << 8) + (buffer[2] << 16);
    _packetNumber = buffer[3];
    _log.fine('about to read $dataSize bytes for packet $_packetNumber');
    final dataBuffer = Buffer(dataSize);
    _log.fine('buffer size=${dataBuffer.length}');
    if (dataSize == 0xffffff || _largePacketBuffers.isNotEmpty) {
      final buffer = await _socket.readBuffer(dataBuffer);
      await _handleMoreData(buffer);
    } else {
      final buffer = await _socket.readBuffer(dataBuffer);
      await _handleData(buffer);
    }
  }

  Future<void> _handleMoreData(Buffer buffer) async {
    _largePacketBuffers.add(buffer);
    if (buffer.length < 0xffffff) {
      final length = _largePacketBuffers.fold<int>(0, (length, buf) {
        return length + buf.length;
      });
      final combinedBuffer = Buffer(length);
      var start = 0;
      for (final aBuffer in _largePacketBuffers) {
        combinedBuffer.list.setRange(start, start + aBuffer.length, aBuffer.list);
        start += aBuffer.length;
      }
      _largePacketBuffers.clear();
      await _handleData(combinedBuffer);
    } else {
      _readyForHeader = true;
      _headerBuffer.reset();
      await _readPacket();
    }
  }

  Future<void> _handleData(Buffer buffer) async {
    _readyForHeader = true;
    _headerBuffer.reset();
    final handler = _handler;

    try {
      final response = handler?.processResponse(buffer);
      if (handler is HandshakeHandler) {
        _useCompression = handler.useCompression;
        _useSSL = handler.useSSL;
      }
      if (response?.nextHandler != null) {
        // if handler.processResponse() returned a Handler, pass control to that handler now
        _handler = response!.nextHandler;
        final handler = _handler;
        await sendBuffer(_handler!.createRequest());
        if (_useSSL && handler is SSLHandler) {
          _log.fine('Use SSL');
          await _socket.startSSL();
          _handler = handler.nextHandler;
          await sendBuffer(_handler!.createRequest());
          _log.fine('Sent buffer');
          return;
        }
      }

      if (response?.finished ?? false) {
        _log.fine('Finished $_handler');
        _finishAndReuse();
      }
      if (response?.hasResult ?? false) {
        if (_completer?.isCompleted ?? false) {
          _completer?.completeError(StateError('Request has already completed'));
        }
        _completer?.complete(response!.result);
      }
    } on MySqlException catch (e, st) {
      // This clause means mysql returned an error on the wire. It is not a fatal error
      // and the connection can stay open.
      _log.fine('completing with MySqlException: $e');
      _finishAndReuse();
      handleError(e, st: st, keepOpen: true);
    } catch (e, st) {
      // Errors here are fatal_finishAndReuse();
      handleError(e, st: st);
    }
  }

  void _finishAndReuse() {
    _handler = null;
  }

  Future<void> sendBuffer(Buffer buffer) {
    if (buffer.length > _maxPacketSize) {
      throw MySqlClientError(
        'Buffer length (${buffer.length}) bigger than maxPacketSize ($_maxPacketSize)',
      );
    }
    if (_useCompression) {
      _headerBuffer[0] = buffer.length & 0xFF;
      _headerBuffer[1] = (buffer.length & 0xFF00) >> 8;
      _headerBuffer[2] = (buffer.length & 0xFF0000) >> 16;
      _headerBuffer[3] = ++_packetNumber;
      final encodedHeader = zlib.encode(_headerBuffer.list);
      final encodedBuffer = zlib.encode(buffer.list);
      _compressedHeaderBuffer.writeUint24(encodedHeader.length + encodedBuffer.length);
      _compressedHeaderBuffer.writeByte(++_compressedPacketNumber);
      _compressedHeaderBuffer.writeUint24(4 + buffer.length);
      return _socket.writeBuffer(_compressedHeaderBuffer);
    } else {
      _log.fine('sendBuffer header');
      return _sendBufferPart(buffer, 0);
    }
  }

  Future<Buffer> _sendBufferPart(Buffer buffer, int start) async {
    final len = math.min(buffer.length - start, 0xFFFFFF);

    _headerBuffer[0] = len & 0xFF;
    _headerBuffer[1] = (len & 0xFF00) >> 8;
    _headerBuffer[2] = (len & 0xFF0000) >> 16;
    _headerBuffer[3] = ++_packetNumber;
    _log.fine('sending header, packet $_packetNumber');
    await _socket.writeBuffer(_headerBuffer);
    _log.fine(
      'sendBuffer body, buffer length=${buffer.length}, start=$start, len=$len',
    );
    await _socket.writeBufferPart(buffer, start, len);
    if (len == 0xFFFFFF) {
      return _sendBufferPart(buffer, start + len);
    } else {
      return buffer;
    }
  }

  /// This method just sends the handler data.
  Future<void> _processHandlerNoResponse(Handler handler) {
    if (_handler != null) {
      throw MySqlClientError(
        'Connection cannot process a request for $handler while a request is already in progress for $_handler',
      );
    }
    _packetNumber = -1;
    _compressedPacketNumber = -1;
    return sendBuffer(handler.createRequest());
  }

  /// Processes a handler, from sending the initial request to handling any packets returned from
  /// mysql
  Future<T> _processHandler<T>(Handler handler) async {
    if (_handler != null) {
      throw MySqlClientError(
        'Connection cannot process a request for $handler while a request is already in progress for $_handler',
      );
    }
    _log.fine('start handler $handler');
    _packetNumber = -1;
    _compressedPacketNumber = -1;
    final c = Completer<T>();
    _completer = c;
    _handler = handler;
    await sendBuffer(handler.createRequest());
    return c.future;
  }

  /// The 2 functions below this line are the main interface to the running handlers on the connection.
  /// Each function MUST tidy up the connection (leave _handler null) before finishing.

  Future<Results> processHandlerWithResults(Handler handler, Duration timeout) {
    return _processHandler<ResultsStream>(handler).timeout(timeout).then((results) {
      return Future.delayed(const Duration(microseconds: 2), () {
        return Results._read(results).timeout(timeout).then((value) {
          _handler = null;
          return value;
        }).catchError((e) {
          _handler = null;
          return Results._empty();
        });
      });
    }).catchError((e) {
      _handler = null;
      return Results._empty();
    });
  }

  Future<void> processHandlerNoResponse(Handler handler, Duration timeout) {
    return _processHandlerNoResponse(handler).timeout(timeout).then((result) {
      _handler = null;
      return result;
    }).catchError((e) {
      _handler = null;
    });
  }
}
