// ignore_for_file: strong_mode_implicit_dynamic_list_literal, strong_mode_implicit_dynamic_parameter, argument_type_not_assignable, invalid_assignment, non_bool_condition, strong_mode_implicit_dynamic_variable, deprecated_member_use

@TestOn('!windows')
import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mysql1_ext/mysql1_ext.dart';
import 'package:mysql1_ext/src/buffer.dart';
import 'package:mysql1_ext/src/buffered_socket.dart';
import 'package:mysql1_ext/src/single_connection.dart';
import 'package:test/test.dart';

class MockBufferedSocket extends Mock implements BufferedSocket {}

class BufferFake extends Fake implements Buffer {}

void main() {
  setUpAll(() {
    registerFallbackValue(BufferFake());
  });

  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.OFF;
  //Logger('BufferedSocket').level = Level.ALL;

  Logger.root.onRecord.listen((LogRecord r) {
    print('${r.time}: ${r.loggerName}: ${r.message}');
  });

  test('connection fail connect test', () async {
    try {
      await MySqlConnection.connect(ConnectionSettings(port: 12345));
    } on SocketException catch (e) {
      expect(e.osError?.errorCode, 111);
    }
  });

  test('timeout connect test', () async {
    // The connect call should raise a timeout.
    late ServerSocket sock;
    var thrown = false;
    try {
      sock = await ServerSocket.bind('localhost', 12346);
      await MySqlConnection.connect(
        ConnectionSettings(
          port: 12346,
          timeout: const Duration(microseconds: 5),
        ),
      );
    } on TimeoutException {
      thrown = true;
    } on SocketException {
      thrown = true;
    } finally {
      await sock.close();
    }
    expect(thrown, true);
  });

  test('calling close on a broken socket should respect the socket timeout. close never throws.', () async {
    final m = MockBufferedSocket();
    when(m.close).thenReturn(null);

    final r = ReqRespConnection(m, null, null, 1024);
    final conn = MySqlConnection(const Duration(microseconds: 5), r);
    await conn.close(); // does not timeout the test.
  });

  test('calling query on a broken socket should respect the socket timeout', () async {
    final m = MockBufferedSocket();
    when(() => m.writeBuffer(any<Buffer>())).thenAnswer((_) => Future.value(BufferFake()));
    when(() => m.writeBufferPart(any<Buffer>(), any<int>(), any<int>())).thenAnswer((_) => Future.value(BufferFake()));
    final r = ReqRespConnection(m, null, null, 1024);
    final conn = MySqlConnection(const Duration(microseconds: 5), r);
    expect(conn.query('SELECT 1'), throwsA(timeoutMatcher));
  });

  test('socket closed before handshake', () async {
    late ServerSocket sock;
    var thrown = false;
    try {
      sock = await ServerSocket.bind('localhost', 12347);
      sock.listen((socket) => socket.close());
      await MySqlConnection.connect(ConnectionSettings(port: 12347));
    } on SocketException catch (e) {
      thrown = true;
      expect(e.message, 'Socket has been closed');
    } finally {
      await sock.close();
    }
    expect(thrown, true);
  });

  test('socket too many connections on connect', () async {
    late ServerSocket sock;
    var thrown = false;
    try {
      sock = await ServerSocket.bind('localhost', 12348);
      sock.listen((socket) async {
        socket.add([23, 0, 0, 0]);
        socket.add([255, 16, 4, 84, 111, 111, 32, 109, 97, 110, 121, 32, 99, 111, 110, 110, 101, 99, 116, 105, 111, 110, 115]);
        await socket.close();
      });
      await MySqlConnection.connect(
        ConnectionSettings(
          port: 12348,
        ),
      );
    } on MySqlException catch (e) {
      thrown = true;
      expect(e.message, 'ny connections');
    } finally {
      await sock.close();
    }
    expect(thrown, true);
  });

  test('bad protocol', () async {
    late ServerSocket sock;
    var thrown = false;
    try {
      sock = await ServerSocket.bind('localhost', 12348);
      sock.listen((socket) async {
        socket.add([1, 0, 0, 0]);
        socket.add([9]);
        await socket.close();
      });
      await MySqlConnection.connect(
        ConnectionSettings(
          port: 12348,
        ),
      );
    } on MySqlClientError catch (e) {
      thrown = true;
      expect(e.message, 'Protocol not supported');
    } finally {
      await sock.close();
    }
    expect(thrown, true);
  });
}

const Matcher timeoutMatcher = _TimeoutException();

class _TimeoutException extends TypeMatcher<TimeoutException> {
  const _TimeoutException() : super('TimeoutException');

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) => item is TimeoutException;
}

Matcher socketExceptionMatcher(int code) => _SocketException(code);

class _SocketException extends TypeMatcher<SocketException> {
  const _SocketException(this.errorCode) : super('SocketException');
  final int errorCode;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) => item is SocketException && item.osError?.errorCode == errorCode;
}
