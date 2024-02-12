import 'package:mysql1_ext/mysql1_ext.dart';
import 'package:mysql1_ext/src/buffer.dart';
import 'package:mysql1_ext/src/constants.dart';
import 'package:mysql1_ext/src/prepared_statements/binary_data_packet.dart';

import 'package:test/test.dart';

void main() {
  group('buffer:', () {
    test('can read short blob', () {
      final packet = BinaryDataPacket.forTests(null);
      final field = Field.forTests(FIELD_TYPE_BLOB);
      final buffer = Buffer.fromList([1, 32]);
      final value = packet.readField(field, buffer);

      expect(value, const TypeMatcher<Blob>());
      expect((value as Blob).toString(), equals(' '));
    });

    test('can read long blob', () {
      final packet = BinaryDataPacket.forTests(null);
      final field = Field.forTests(FIELD_TYPE_BLOB);

      final buffer = Buffer(500 + 3);
      buffer.writeLengthCodedBinary(500);
      for (var i = 0; i < 500; i++) {
        buffer.writeByte(32);
      }
      final value = packet.readField(field, buffer);

      expect(value, const TypeMatcher<Blob>());
      expect((value as Blob).toString(), hasLength(500));
    });

    test('can read very long blob', () {
      final packet = BinaryDataPacket.forTests(null);
      final field = Field.forTests(FIELD_TYPE_BLOB);

      final buffer = Buffer(50000 + 3);
      buffer.writeLengthCodedBinary(50000);
      for (var i = 0; i < 50000; i++) {
        buffer.writeByte(32);
      }
      final value = packet.readField(field, buffer);

      expect(value, const TypeMatcher<Blob>());
      expect((value as Blob).toString(), hasLength(50000));
    });
  });
}
