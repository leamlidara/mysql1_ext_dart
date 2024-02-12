MySqlProtocolError createMySqlProtocolError(String message) =>
    MySqlProtocolError._(message);

/// An error which is thrown when something unexpected is read from the the MySQL protocol.
class MySqlProtocolError extends Error {
  /// Create a [MySqlProtocolError]
  MySqlProtocolError._(this.message);
  final String message;
}
