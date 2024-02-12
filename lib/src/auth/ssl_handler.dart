import 'package:logging/logging.dart';

import 'package:mysql1_ext/src/buffer.dart';
import 'package:mysql1_ext/src/handlers/handler.dart';

class SSLHandler extends Handler {
  SSLHandler(
    this.clientFlags,
    this.maxPacketSize,
    this.characterSet,
    this.nextHandler,
  ) : super(Logger('SSLHandler'));
  final int clientFlags;
  final int maxPacketSize;
  final int characterSet;

  final Handler nextHandler;

  @override
  Buffer createRequest() {
    final buffer = Buffer(32);
    buffer.seekWrite(0);
    buffer.writeUint32(clientFlags);
    buffer.writeUint32(maxPacketSize);
    buffer.writeByte(characterSet);
    buffer.fill(23, 0);

    return buffer;
  }
}
