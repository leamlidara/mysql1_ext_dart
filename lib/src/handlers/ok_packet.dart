import 'package:mysql1_ext/src/buffer.dart';

class OkPacket {
  OkPacket(Buffer buffer) {
    buffer.seek(1);
    _affectedRows = buffer.readLengthCodedBinary();
    _insertId = buffer.readLengthCodedBinary();
    _serverStatus = buffer.readUint16();
    _message = buffer.readStringToEnd();
  }
  late int? _affectedRows;
  late int? _insertId;
  late int _serverStatus;
  late String _message;

  int? get affectedRows => _affectedRows;
  int? get insertId => _insertId;
  int get serverStatus => _serverStatus;
  String get message => _message;

  @override
  String toString() => 'OK: affected rows: $affectedRows, insert id: $insertId, server status: $serverStatus, message: $message';
}
