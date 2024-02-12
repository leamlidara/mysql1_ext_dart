import 'package:mysql1_ext/src/buffer.dart';

MySqlException createMySqlException(Buffer buffer) => MySqlException._(buffer);

/// An exception which is returned by the MySQL server.
class MySqlException implements Exception {
  MySqlException._raw(this.errorNumber, this.sqlState, this.message);

  /// Create a [MySqlException] based on an error response from the mysql server
  factory MySqlException._(Buffer buffer) {
    buffer.seek(1);
    final errorNumber = buffer.readUint16();
    buffer.skip(1);
    final sqlState = buffer.readString(5);
    final message = buffer.readStringToEnd();
    return MySqlException._raw(errorNumber, sqlState, message);
  }

  /// The MySQL error number
  final int errorNumber;

  /// A five character ANSI SQLSTATE value
  final String sqlState;

  /// A textual description of the error
  final String message;

  @override
  String toString() => 'Error $errorNumber ($sqlState): $message';
}
