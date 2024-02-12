import 'package:mysql1_ext/src/auth/auth_handler.dart';
import 'package:mysql1_ext/src/auth/handshake_handler.dart';
import 'package:mysql1_ext/src/constants.dart';

import 'package:test/test.dart';

void main() {
  group('auth_handler:', () {
    test('hash password correctly', () {
      final handler = AuthHandler(
        'username',
        'password',
        'db',
        [1, 2, 3, 4],
        0,
        100,
        0,
        AuthPlugin.mysqlNativePassword,
      );

      final hash = handler.getHash();

      expect(
        hash,
        equals([211, 136, 65, 109, 153, 241, 227, 117, 168, 83, 80, 136, 188, 116, 50, 54, 235, 225, 54, 225]),
      );
    });

    test('hash password correctly', () {
      const clientFlags = 12345;
      const maxPacketSize = 9898;
      const characterSet = 56;
      const username = 'Boris';
      const password = 'Password';
      final handler = AuthHandler(
        username,
        password,
        null,
        [1, 2, 3, 4],
        clientFlags,
        maxPacketSize,
        characterSet,
        AuthPlugin.mysqlNativePassword,
      );

      final hash = handler.getHash();
      final buffer = handler.createRequest();

      buffer.seek(0);
      expect(buffer.readUint32(), equals(clientFlags));
      expect(buffer.readUint32(), equals(maxPacketSize));
      expect(buffer.readByte(), equals(characterSet));
      buffer.skip(23);
      expect(buffer.readNullTerminatedString(), equals(username));
      expect(buffer.readByte(), equals(hash.length));
      expect(buffer.readList(hash.length), equals(hash));
      expect(buffer.hasMore, isFalse);
    });

    test('check another set of values', () {
      const clientFlags = 2435623 & ~CLIENT_CONNECT_WITH_DB;
      const maxPacketSize = 34536;
      const characterSet = 255;
      const username = 'iamtheuserwantingtologin';
      const password = 'wibblededee';
      const database = 'thisisthenameofthedatabase';
      final handler = AuthHandler(
        username,
        password,
        database,
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        clientFlags,
        maxPacketSize,
        characterSet,
        AuthPlugin.mysqlNativePassword,
      );

      final hash = handler.getHash();
      final buffer = handler.createRequest();

      buffer.seek(0);
      expect(buffer.readUint32(), equals(clientFlags | CLIENT_CONNECT_WITH_DB));
      expect(buffer.readUint32(), equals(maxPacketSize));
      expect(buffer.readByte(), equals(characterSet));
      buffer.skip(23);
      expect(buffer.readNullTerminatedString(), equals(username));
      expect(buffer.readByte(), equals(hash.length));
      expect(buffer.readList(hash.length), equals(hash));
      expect(buffer.readNullTerminatedString(), equals(database));
      expect(buffer.hasMore, isFalse);
    });
  });

  test('check utf8', () {
    const username = 'Борис';
    const password = 'здрасти';
    const database = 'дтабасе';
    final handler = AuthHandler(
      username,
      password,
      database,
      [1, 2, 3, 4],
      0,
      100,
      0,
      AuthPlugin.mysqlNativePassword,
    );

    final hash = handler.getHash();
    final buffer = handler.createRequest();

    buffer.seek(0);
    buffer.readUint32();
    buffer.readUint32();
    buffer.readByte();
    buffer.skip(23);
    expect(buffer.readNullTerminatedString(), equals(username));
    expect(buffer.readByte(), equals(hash.length));
    expect(buffer.readList(hash.length), equals(hash));
    expect(buffer.readNullTerminatedString(), equals(database));
    expect(buffer.hasMore, isFalse);
  });
}
