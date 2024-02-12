import 'package:mysql1_ext/src/auth/character_set.dart';

class ConnectionSettings {
  ConnectionSettings({
    this.host = 'localhost',
    this.port = 3306,
    this.user,
    this.password,
    this.db,
    this.useCompression = false,
    this.useSSL = false,
    this.maxPacketSize = 16 * 1024 * 1024,
    this.timeout = const Duration(seconds: 30),
    this.characterSet = CharacterSet.UTF8MB4,
  });

  factory ConnectionSettings.socket({
    required String path,
    String? user,
    String? password,
    String? db,
    bool useCompression = false,
    bool useSSL = false,
    int maxPacketSize = 16 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 30),
    int characterSet = CharacterSet.UTF8MB4,
  }) =>
      ConnectionSettings(
        host: path,
        user: user,
        password: password,
        db: db,
        useCompression: useCompression,
        useSSL: useSSL,
        maxPacketSize: maxPacketSize,
        timeout: timeout,
        characterSet: characterSet,
      );

  ConnectionSettings.copy(ConnectionSettings o)
      : host = o.host,
        port = o.port,
        user = o.user,
        password = o.password,
        db = o.db,
        useCompression = o.useCompression,
        useSSL = o.useSSL,
        maxPacketSize = o.maxPacketSize,
        timeout = o.timeout,
        characterSet = o.characterSet;
  String host;
  int port;
  String? user;
  String? password;
  String? db;
  bool useCompression;
  bool useSSL;
  int maxPacketSize;
  int characterSet;

  /// The timeout for connecting to the database and for all database operations.
  Duration timeout;
}
