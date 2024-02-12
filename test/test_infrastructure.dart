import 'package:mysql1_ext/mysql1_ext.dart';
import 'package:options_file/options_file.dart';
import 'package:test/test.dart';

import 'test_util.dart';

MySqlConnection get conn => _conn;
late MySqlConnection _conn;

void initializeTest([String? tableName, String? createSql, String? insertSql]) {
  final options = OptionsFile('connection.options');

  final s = ConnectionSettings(
    user: options.getString('user'),
    password: options.getString('password'),
    port: options.getInt('port', 3306)!,
    db: options.getString('db'),
    host: options.getString('host', 'localhost')!,
  );

  setUp(() async {
    // Ensure db exists
    final checkSettings = ConnectionSettings.copy(s);
    checkSettings.db = null;
    final c = await MySqlConnection.connect(checkSettings);
    await c.query('CREATE DATABASE IF NOT EXISTS ${s.db} CHARACTER SET utf8');
    await c.close();

    _conn = await MySqlConnection.connect(s);

    if (tableName != null) {
      await setup(_conn, tableName, createSql, insertSql);
    }
  });

  tearDown(() async {
    await _conn.close();
  });
}
