// ignore_for_file: strong_mode_implicit_dynamic_list_literal, strong_mode_implicit_dynamic_parameter, argument_type_not_assignable, invalid_assignment, non_bool_condition, strong_mode_implicit_dynamic_variable, deprecated_member_use

import 'package:mysql1_ext/src/auth/auth_handler.dart';
import 'package:mysql1_ext/src/auth/character_set.dart';
import 'package:mysql1_ext/src/auth/handshake_handler.dart';
import 'package:mysql1_ext/src/auth/ssl_handler.dart';
import 'package:mysql1_ext/src/buffer.dart';
import 'package:mysql1_ext/src/constants.dart';
import 'package:mysql1_ext/src/handlers/handler.dart';
import 'package:mysql1_ext/src/mysql_client_error.dart';
import 'package:test/test.dart';

const int MAX_PACKET_SIZE = 16 * 1024 * 1024;

Buffer _createHandshake(
  int protocolVersion,
  String serverVersion,
  int threadId,
  dynamic scrambleBuffer,
  int serverCapabilities, [
  String? serverLanguage,
  int? serverStatus,
  int? serverCapabilities2,
  int? scrambleLength,
  dynamic scrambleBuffer2,
  String? pluginName,
  String? pluginNameNull,
]) {
  var length = 1 + serverVersion.length + 1 + 4 + 8 + 1 + 2;
  if (serverLanguage != null) {
    length += 1 + 2 + 2 + 1 + 10;
    if (scrambleBuffer2 != null) {
      length += (scrambleBuffer2.length as int) + 1;
    }
    if (pluginName != null) {
      length += pluginName.length;
      if (pluginNameNull) {
        length++;
      }
    }
  }

  final response = Buffer(length);
  response.writeByte(protocolVersion);
  response.writeNullTerminatedList(serverVersion.codeUnits);
  response.writeInt32(threadId);
  response.writeList(scrambleBuffer.codeUnits);
  response.writeByte(0);
  response.writeInt16(serverCapabilities);
  if (serverLanguage != null) {
    response.writeByte(serverLanguage);
    response.writeInt16(serverStatus);
    response.writeInt16(serverCapabilities2);
    response.writeByte(scrambleLength);
    response.fill(10, 0);
    if (scrambleBuffer2 != null) {
      response.writeNullTerminatedList(scrambleBuffer2.codeUnits);
    }
    if (pluginName != null) {
      response.writeList(pluginName.codeUnits);
      if (pluginNameNull) {
        response.writeByte(0);
      }
    }
  }
  return response;
}

void main() {
  group('HandshakeHandler._readResponseBuffer', () {
    test('throws if handshake protocol is not 10', () {
      final handler = HandshakeHandler('', '', MAX_PACKET_SIZE, CharacterSet.UTF8MB4);
      final response = Buffer.fromList([9]);
      expect(
        () {
          handler.readResponseBuffer(response);
        },
        throwsA(const isInstanceOf<MySqlClientError>()),
      );
    });

    test('set values and does not throw if handshake protocol is 10', () {
      const user = 'bob';
      const password = 'password';
      const db = 'db';
      final handler = HandshakeHandler(
        user,
        password,
        MAX_PACKET_SIZE,
        CharacterSet.UTF8MB4,
        db,
        true,
        true,
      );
      const serverVersion = 'version 1';
      const threadId = 123882394;
      const serverLanguage = 9;
      const serverStatus = 999;
      const serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      const serverCapabilities2 = 0;
      const scrambleBuffer1 = 'abcdefgh';
      const scrambleBuffer2 = 'ijklmnopqrstuvwxyz';
      const scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      final responseBuffer = _createHandshake(
        10,
        serverVersion,
        threadId,
        scrambleBuffer1,
        serverCapabilities1,
        serverLanguage,
        serverStatus,
        serverCapabilities2,
        scrambleLength,
        scrambleBuffer2,
      );
      handler.readResponseBuffer(responseBuffer);

      expect(handler.serverVersion, equals(serverVersion));
      expect(handler.threadId, equals(threadId));
      expect(handler.serverLanguage, equals(serverLanguage));
      expect(handler.serverStatus, equals(serverStatus));
      expect(handler.serverCapabilities, equals(serverCapabilities1));
      expect(handler.scrambleLength, equals(scrambleLength));
      expect(
        handler.scrambleBuffer,
        equals((scrambleBuffer1 + scrambleBuffer2).codeUnits),
      );
    });

    test('should cope with no data past first capability flags', () {
      const serverVersion = 'version 1';
      const scrambleBuffer1 = 'abcdefgh';
      const threadId = 123882394;
      const serverCapabilities = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;

      final responseBuffer = _createHandshake(
        10,
        serverVersion,
        threadId,
        scrambleBuffer1,
        serverCapabilities,
      );

      final handler = HandshakeHandler('', '', MAX_PACKET_SIZE, CharacterSet.UTF8MB4);
      handler.readResponseBuffer(responseBuffer);

      expect(handler.serverVersion, equals(serverVersion));
      expect(handler.threadId, equals(threadId));
      expect(handler.serverCapabilities, equals(serverCapabilities));
      expect(handler.serverLanguage, equals(null));
      expect(handler.serverStatus, equals(null));
    });

    test('should read plugin name', () {
      const user = 'bob';
      const password = 'password';
      const db = 'db';
      final handler = HandshakeHandler(
        user,
        password,
        MAX_PACKET_SIZE,
        CharacterSet.UTF8MB4,
        db,
        true,
        true,
      );
      const serverVersion = 'version 1';
      const threadId = 123882394;
      const serverLanguage = 9;
      const serverStatus = 999;
      const serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      const serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      const scrambleBuffer1 = 'abcdefgh';
      const scrambleBuffer2 = 'ijklmnopqrstuvwxyz';
      const scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      const pluginName = 'mysql_native_password';
      final responseBuffer = _createHandshake(
        10,
        serverVersion,
        threadId,
        scrambleBuffer1,
        serverCapabilities1,
        serverLanguage,
        serverStatus,
        serverCapabilities2,
        scrambleLength,
        scrambleBuffer2,
        pluginName,
        false,
      );
      handler.readResponseBuffer(responseBuffer);

      expect(handler.authPlugin, equals(AuthPlugin.mysqlNativePassword));
    });

    test('should read plugin name with null', () {
      const user = 'bob';
      const password = 'password';
      const db = 'db';
      final handler = HandshakeHandler(
        user,
        password,
        MAX_PACKET_SIZE,
        CharacterSet.UTF8MB4,
        db,
        true,
        true,
      );
      const serverVersion = 'version 1';
      const threadId = 123882394;
      const serverLanguage = 9;
      const serverStatus = 999;
      const serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      const serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      const scrambleBuffer1 = 'abcdefgh';
      const scrambleBuffer2 = 'ijklmnopqrstuvwxyz';
      const scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      const pluginName = 'mysql_native_password';
      final responseBuffer = _createHandshake(
        10,
        serverVersion,
        threadId,
        scrambleBuffer1,
        serverCapabilities1,
        serverLanguage,
        serverStatus,
        serverCapabilities2,
        scrambleLength,
        scrambleBuffer2,
        pluginName,
        true,
      );
      handler.readResponseBuffer(responseBuffer);

      expect(handler.authPlugin, equals(AuthPlugin.mysqlNativePassword));
    });

    test('should read buffer without scramble data', () {
      const user = 'bob';
      const password = 'password';
      const db = 'db';
      final handler = HandshakeHandler(
        user,
        password,
        MAX_PACKET_SIZE,
        CharacterSet.UTF8MB4,
        db,
        true,
        true,
      );
      const serverVersion = 'version 1';
      const threadId = 123882394;
      const serverLanguage = 9;
      const serverStatus = 999;
      const serverCapabilities1 = CLIENT_PROTOCOL_41;
      const serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      const scrambleBuffer1 = 'abcdefgh';
      var scrambleBuffer2;
      const scrambleLength = scrambleBuffer1.length;
      const pluginName = 'caching_sha2_password';
      final responseBuffer = _createHandshake(
        10,
        serverVersion,
        threadId,
        scrambleBuffer1,
        serverCapabilities1,
        serverLanguage,
        serverStatus,
        serverCapabilities2,
        scrambleLength,
        scrambleBuffer2,
        pluginName,
        true,
      );
      handler.readResponseBuffer(responseBuffer);

      expect(handler.authPlugin, equals(AuthPlugin.cachingSha2Password));
    });

    test('should read buffer with short scramble data length', () {
      const user = 'bob';
      const password = 'password';
      const db = 'db';
      final handler = HandshakeHandler(
        user,
        password,
        MAX_PACKET_SIZE,
        CharacterSet.UTF8MB4,
        db,
        true,
        true,
      );
      const serverVersion = 'version 1';
      const threadId = 123882394;
      const serverLanguage = 9;
      const serverStatus = 999;
      const serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      const serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      const scrambleBuffer1 = 'abcdefgh';
      const scrambleBuffer2 = 'ijklmnopqrst';
      const scrambleLength = 5;
      const pluginName = 'mysql_native_password';
      final responseBuffer = _createHandshake(
        10,
        serverVersion,
        threadId,
        scrambleBuffer1,
        serverCapabilities1,
        serverLanguage,
        serverStatus,
        serverCapabilities2,
        scrambleLength,
        scrambleBuffer2,
        pluginName,
        true,
      );
      handler.readResponseBuffer(responseBuffer);

      expect(handler.authPlugin, equals(AuthPlugin.mysqlNativePassword));
    });
  });

  group('HandshakeHandler.processResponse', () {
    test('throws if server protocol is not 4.1', () {
      final handler = HandshakeHandler('', '', MAX_PACKET_SIZE, CharacterSet.UTF8MB4);
      final response = _createHandshake(
        10,
        'version 1',
        123,
        'abcdefgh',
        0,
        0,
        0,
        0,
        0,
        'buffer',
      );
      expect(
        () {
          handler.processResponse(response);
        },
        throwsA(const isInstanceOf<MySqlClientError>()),
      );
    });

    test('works when plugin name is not set', () {
      const user = 'bob';
      const password = 'password';
      const db = 'db';
      final handler = HandshakeHandler(
        user,
        password,
        MAX_PACKET_SIZE,
        CharacterSet.UTF8MB4,
        db,
        true,
        true,
      );
      const serverVersion = 'version 1';
      const threadId = 123882394;
      const serverLanguage = 9;
      const serverStatus = 999;
      const serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      const serverCapabilities2 = 0;
      const scrambleBuffer1 = 'abcdefgh';
      const scrambleBuffer2 = 'ijklmnopqrstuvwxyz';
      const scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      final responseBuffer = _createHandshake(
        10,
        serverVersion,
        threadId,
        scrambleBuffer1,
        serverCapabilities1,
        serverLanguage,
        serverStatus,
        serverCapabilities2,
        scrambleLength,
        scrambleBuffer2,
      );
      final response = handler.processResponse(responseBuffer);

      expect(handler.useCompression, isFalse);
      expect(handler.useSSL, isFalse);

      expect(response, const isInstanceOf<HandlerResponse>());
      expect(response.nextHandler, const isInstanceOf<AuthHandler>());

      const clientFlags = CLIENT_PROTOCOL_41 |
          CLIENT_LONG_PASSWORD |
          CLIENT_LONG_FLAG |
          CLIENT_TRANSACTIONS |
          CLIENT_SECURE_CONNECTION |
          CLIENT_MULTI_RESULTS;

      final authHandler = response.nextHandler as AuthHandler;
      expect(authHandler.characterSet, equals(CharacterSet.UTF8MB4));
      expect(authHandler.username, equals(user));
      expect(authHandler.password, equals(password));
      expect(
        authHandler.scrambleBuffer,
        equals((scrambleBuffer1 + scrambleBuffer2).codeUnits),
      );
      expect(authHandler.db, equals(db));
      expect(authHandler.clientFlags, equals(clientFlags));
      expect(authHandler.maxPacketSize, equals(MAX_PACKET_SIZE));
    });

    test('works when plugin name is set', () {
      const user = 'bob';
      const password = 'password';
      const db = 'db';
      final handler = HandshakeHandler(
        user,
        password,
        MAX_PACKET_SIZE,
        CharacterSet.UTF8MB4,
        db,
        true,
        true,
      );
      const serverVersion = 'version 1';
      const threadId = 123882394;
      const serverLanguage = 9;
      const serverStatus = 999;
      const serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      const serverCapabilities2 = 0;
      const scrambleBuffer1 = 'abcdefgh';
      const scrambleBuffer2 = 'ijklmnopqrstuvwxyz';
      const scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      final responseBuffer = _createHandshake(
        10,
        serverVersion,
        threadId,
        scrambleBuffer1,
        serverCapabilities1,
        serverLanguage,
        serverStatus,
        serverCapabilities2,
        scrambleLength,
        scrambleBuffer2,
        'mysql_native_password',
        true,
      );
      final response = handler.processResponse(responseBuffer);

      expect(handler.useCompression, isFalse);
      expect(handler.useSSL, isFalse);

      expect(response, const isInstanceOf<HandlerResponse>());
      expect(response.nextHandler, const isInstanceOf<AuthHandler>());

      final authHandler = response.nextHandler as AuthHandler;
      expect(authHandler.username, equals(user));
      expect(authHandler.password, equals(password));
      expect(
        authHandler.scrambleBuffer,
        equals((scrambleBuffer1 + scrambleBuffer2).codeUnits),
      );
      expect(authHandler.db, equals(db));
    });

    test('throws if old password authentication is requested', () {
      const serverVersion = 'version 1';
      const scrambleBuffer1 = 'abcdefgh';
      const threadId = 123882394;
      const serverCapabilities = CLIENT_PROTOCOL_41;

      final responseBuffer = _createHandshake(
        10,
        serverVersion,
        threadId,
        scrambleBuffer1,
        serverCapabilities,
      );

      final handler = HandshakeHandler('', '', MAX_PACKET_SIZE, CharacterSet.UTF8MB4);
      expect(
        () {
          handler.processResponse(responseBuffer);
        },
        throwsA(const isInstanceOf<MySqlClientError>()),
      );
    });

    test('throws if plugin is set and is not mysql_native_password', () {
      const user = 'bob';
      const password = 'password';
      const db = 'db';
      final handler = HandshakeHandler(
        user,
        password,
        MAX_PACKET_SIZE,
        CharacterSet.UTF8MB4,
        db,
        true,
        true,
      );
      const serverVersion = 'version 1';
      const threadId = 123882394;
      const serverLanguage = 9;
      const serverStatus = 999;
      const serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION;
      const serverCapabilities2 = CLIENT_PLUGIN_AUTH >> 0x10;
      const scrambleBuffer1 = 'abcdefgh';
      const scrambleBuffer2 = 'ijklmnopqrstuvwxyz';
      const scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      final responseBuffer = _createHandshake(
        10,
        serverVersion,
        threadId,
        scrambleBuffer1,
        serverCapabilities1,
        serverLanguage,
        serverStatus,
        serverCapabilities2,
        scrambleLength,
        scrambleBuffer2,
        'some_random_plugin',
        true,
      );

      expect(
        () {
          handler.processResponse(responseBuffer);
        },
        throwsA(const isInstanceOf<MySqlClientError>()),
      );
    });

    test('works when ssl requested', () {
      const user = 'bob';
      const password = 'password';
      const db = 'db';
      final handler = HandshakeHandler(
        user,
        password,
        MAX_PACKET_SIZE,
        CharacterSet.UTF8MB4,
        db,
        true,
        true,
      );
      const serverVersion = 'version 1';
      const threadId = 123882394;
      const serverLanguage = 9;
      const serverStatus = 999;
      const serverCapabilities1 = CLIENT_PROTOCOL_41 | CLIENT_SECURE_CONNECTION | CLIENT_SSL;
      const serverCapabilities2 = 0;
      const scrambleBuffer1 = 'abcdefgh';
      const scrambleBuffer2 = 'ijklmnopqrstuvwxyz';
      const scrambleLength = scrambleBuffer1.length + scrambleBuffer2.length + 1;
      final responseBuffer = _createHandshake(
        10,
        serverVersion,
        threadId,
        scrambleBuffer1,
        serverCapabilities1,
        serverLanguage,
        serverStatus,
        serverCapabilities2,
        scrambleLength,
        scrambleBuffer2,
      );
      final response = handler.processResponse(responseBuffer);

      expect(handler.useCompression, isFalse);
      expect(handler.useSSL, isTrue);

      expect(response, const isInstanceOf<HandlerResponse>());
      expect(response.nextHandler, const isInstanceOf<SSLHandler>());

      const clientFlags = CLIENT_PROTOCOL_41 |
          CLIENT_LONG_PASSWORD |
          CLIENT_LONG_FLAG |
          CLIENT_TRANSACTIONS |
          CLIENT_SECURE_CONNECTION |
          CLIENT_SSL |
          CLIENT_MULTI_RESULTS;

      final sslHandler = response.nextHandler as SSLHandler;
      expect(sslHandler.nextHandler, const isInstanceOf<AuthHandler>());
      expect(sslHandler.characterSet, equals(CharacterSet.UTF8MB4));
      expect(sslHandler.clientFlags, equals(clientFlags));
      expect(sslHandler.maxPacketSize, equals(MAX_PACKET_SIZE));

      final authHandler = sslHandler.nextHandler as AuthHandler;
      expect(authHandler.characterSet, equals(CharacterSet.UTF8MB4));
      expect(authHandler.username, equals(user));
      expect(authHandler.password, equals(password));
      expect(
        authHandler.scrambleBuffer,
        equals((scrambleBuffer1 + scrambleBuffer2).codeUnits),
      );
      expect(authHandler.db, equals(db));
      expect(authHandler.clientFlags, equals(clientFlags));
      expect(authHandler.maxPacketSize, equals(MAX_PACKET_SIZE));
    });
  });
}

//TODO http://dev.mysql.com/doc/internals/en/determining-authentication-method.html
