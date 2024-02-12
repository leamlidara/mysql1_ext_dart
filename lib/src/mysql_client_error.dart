///
/// An error which is thrown when the client is used improperly.
///
class MySqlClientError extends Error {
  MySqlClientError(this.message);
  final String message;

  @override
  String toString() => 'MySQL Client Error: $message';
}
