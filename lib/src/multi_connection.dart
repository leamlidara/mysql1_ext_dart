import 'dart:math';
import 'package:mysql1_ext/src/connection_settings.dart';
import 'package:mysql1_ext/src/single_connection.dart';
import 'package:mysql1_ext/src/mysql_client_error.dart';

class MySqlConnectionPool {
  MySqlConnectionPool._(ConnectionSettings connectionSettings, int maxConnection, bool isUnixSocket) {
    _settings = connectionSettings;
    _isUnixSocket = isUnixSocket;
    _maxConnection = maxConnection;
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
  static MySqlConnectionPool connect(
    ConnectionSettings settings, {
    int maxConnection = 10,
    bool isUnixSocket = false,
  }) {
    return MySqlConnectionPool._(settings, maxConnection, isUnixSocket);
  }

  late ConnectionSettings _settings;
  late bool _isUnixSocket;
  late int _maxConnection;
  final List<MySqlConnection> _activeConnections = [];
  final List<MySqlConnection> _idleConnections = [];

  int get activeConnections => _activeConnections.length;

  int get idleConnections => _idleConnections.length;

  int get allConnections => activeConnections + idleConnections;

  /// Run [sql] query on the database using [values] as positional sql parameters.
  ///
  /// eg. ```query('SELECT FROM users WHERE id = ?', [userId])```.
  Future<Results> query(String sql, [List<Object?>? values]) async {
    final conn = await _getFreeConnection();
    if (conn == null) throw MySqlClientError("Operation timeout.");

    try {
      final result = await conn.query(sql, values);
      _releaseConnection(conn);
      return result;
    } catch (e) {
      _releaseConnection(conn);
      rethrow;
    }
  }

  /// Run [sql] query multiple times for each set of positional sql parameters in [values].
  ///
  /// e.g. ```queryMulti('INSERT INTO USERS (name) VALUES (?)', ['Adam', 'Eve'])```.
  Future<List<Results>> queryMulti(
    String sql,
    Iterable<List<Object?>> values,
  ) async {
    final conn = await _getFreeConnection();
    if (conn == null) throw MySqlClientError("Operation timeout.");

    try {
      final result = await conn.queryMulti(sql, values);
      _releaseConnection(conn);
      return result;
    } catch (e) {
      _releaseConnection(conn);
      rethrow;
    }
  }

  /// This method is the same `query`, however this will use parameter name and
  /// expected to be faster than query since this method did not connect to
  /// server when prepare parameter.
  ///
  /// eg. ```execute('SELECT * FROM sessions WHERE session_id=:sid LIMIT 1', {'sid':'THIS IS SAMPLE SESSION'})```.
  Future<Results> execute(String sql, [Map<String, dynamic>? params]) async {
    final conn = await _getFreeConnection();
    if (conn == null) throw MySqlClientError("Operation timeout.");

    try {
      final result = await conn.execute(sql, params);
      _releaseConnection(conn);
      return result;
    } catch (e) {
      _releaseConnection(conn);
      rethrow;
    }
  }

  Future<T?> transaction<T>(
    Future<T> Function(TransactionContext) queryBlock, {
    void Function(Object)? onError,
  }) async {
    final conn = await _getFreeConnection();
    if (conn == null) throw MySqlClientError("Operation timeout.");

    try {
      final result = await conn.transaction<T>(queryBlock, onError: onError);
      _releaseConnection(conn);
      return result;
    } catch (e) {
      _releaseConnection(conn);
      rethrow;
    }
  }

  Future<MySqlConnection?> _getFreeConnection() async {
    // ignore: literal_only_boolean_expressions
    do {
      if (_idleConnections.isNotEmpty) {
        final conn = _idleConnections.removeAt(0);
        if (conn.isClosed) continue;

        _activeConnections.add(conn);
        return conn;
      } else {
        break;
      }
    } while (true);

    if (allConnections < _maxConnection) {
      final conn = await MySqlConnection.connect(
        _settings,
        isUnixSocket: _isUnixSocket,
      );

      _activeConnections.add(conn);
      return conn;
    }

    var expire = DateTime.now().add(Duration(milliseconds: Random().nextInt(50) + 30));
    await Future.doWhile(() => (idleConnections == 0 || expire.compareTo(DateTime.now()) == 1));
    try {
      final conn = _idleConnections.removeAt(0);
      _activeConnections.add(conn);
      return conn;
    } finally {
      return null;
    }
  }

  void _releaseConnection(MySqlConnection conn) {
    _activeConnections.remove(conn);
    _idleConnections.add(conn);
  }
}
