import 'package:logging/logging.dart';

import 'package:mysql1_ext/src/buffer.dart';

class ResultSetHeaderPacket {
  ResultSetHeaderPacket(Buffer buffer)
      : log = Logger('ResultSetHeaderPacket'),
        _fieldCount = buffer.readLengthCodedBinary() {
    if (buffer.canReadMore()) {
      _extra = buffer.readLengthCodedBinary();
    }
  }
  late final int? _fieldCount;
  int? _extra;
  Logger log;

  int? get fieldCount => _fieldCount;

  @override
  String toString() => 'Field count: $_fieldCount, Extra: $_extra';
}
