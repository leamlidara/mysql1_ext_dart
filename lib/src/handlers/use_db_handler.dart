import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:mysql1_ext/src/buffer.dart';
import 'package:mysql1_ext/src/constants.dart';
import 'package:mysql1_ext/src/handlers/handler.dart';

class UseDbHandler extends Handler {
  UseDbHandler(this._dbName) : super(Logger('UseDbHandler'));
  final String _dbName;

  @override
  Buffer createRequest() {
    final encoded = utf8.encode(_dbName);
    final buffer = Buffer(encoded.length + 1);
    buffer.writeByte(COM_INIT_DB);
    buffer.writeList(encoded);
    return buffer;
  }
}
