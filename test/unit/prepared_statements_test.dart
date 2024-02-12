import 'dart:convert';

import 'package:mysql1_ext/mysql1_ext.dart';
import 'package:mysql1_ext/src/buffer.dart';
import 'package:mysql1_ext/src/constants.dart';
import 'package:mysql1_ext/src/prepared_statements/binary_data_packet.dart';
import 'package:test/test.dart';

void main() {
  group('read fields:', () {
    test('can read a tiny BLOB', () {
      final dataPacket = BinaryDataPacket.forTests(null);
      final buffer = Buffer.fromList([3, 65, 66, 67]);
      final field = Field.forTests(FIELD_TYPE_BLOB);
      final value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals('ABC'));
    });

    test('can read a very tiny BLOB', () {
      final dataPacket = BinaryDataPacket.forTests(null);
      final buffer = Buffer.fromList([0]);
      final field = Field.forTests(FIELD_TYPE_BLOB);
      final value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals(''));
    });

    test('can read a several BLOBs', () {
      final dataPacket = BinaryDataPacket.forTests(null);
      final buffer = Buffer.fromList([0, 3, 65, 66, 67, 1, 65, 0, 0, 1, 65]);
      final field = Field.forTests(FIELD_TYPE_BLOB);

      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals(''));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals('ABC'));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals('A'));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals(''));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals(''));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is Blob));
      expect(value.toString(), equals('A'));
    });

    test('can read TINYs', () {
      final dataPacket = BinaryDataPacket.forTests(null);
      final buffer = Buffer.fromList([0, 3, 65]);
      final field = Field.forTests(FIELD_TYPE_TINY);

      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(0));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(3));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(65));
    });

    test('can read SHORTs', () {
      final dataPacket = BinaryDataPacket.forTests(null);
      final buffer = Buffer.fromList([0, 0, 255, 255, 255, 0]);
      final field = Field.forTests(FIELD_TYPE_SHORT);

      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(0));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(-1));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(255));
    });

    test('can read INT24s', () {
      final dataPacket = BinaryDataPacket.forTests(null);
      final buffer = Buffer.fromList([0, 0, 0, 0, 255, 255, 255, 255, 255, 0, 0, 0]);
      final field = Field.forTests(FIELD_TYPE_INT24);

      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(0));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(-1));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(255));
    });

    test('can read LONGs', () {
      final dataPacket = BinaryDataPacket.forTests(null);
      final buffer = Buffer.fromList([0, 0, 0, 0, 255, 255, 255, 255, 255, 0, 0, 0]);
      final field = Field.forTests(FIELD_TYPE_LONG);

      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(0));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(-1));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(255));
    });

    test('can read LONGLONGs', () {
      final dataPacket = BinaryDataPacket.forTests(null);
      final buffer = Buffer.fromList([0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0]);
      final field = Field.forTests(FIELD_TYPE_LONGLONG);

      var value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(0));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(-1));

      value = dataPacket.readField(field, buffer);
      expect(true, equals(value is num));
      expect(value, equals(255));
    });

    test('can read NEWDECIMALs', () {
      final dataPacket = BinaryDataPacket.forTests(null);
      final buffer = Buffer.fromList([5, 0x31, 0x33, 0x2E, 0x39, 0x33]);
      final field = Field.forTests(FIELD_TYPE_NEWDECIMAL);

      final value = dataPacket.readField(field, buffer);
      expect(value is num, equals(true));
      expect(value, equals(13.93));
    });

    //Test
    test('can read JSON', () {
      final dataPacket = BinaryDataPacket.forTests(null);
      final buffer =
          Buffer.fromList([15, 0x7b, 0x22, 0x74, 0x65, 0x73, 0x74, 0x22, 0x3a, 0x22, 0x74, 0x65, 0x73, 0x74, 0x22, 0x7d]);
      final j = {'test': 'test'};
      final field = Field.forTests(FIELD_TYPE_JSON);
      final value = dataPacket.readField(field, buffer);
      expect(value, equals(json.encode(j)));
    });
    //test FLOAT
    //test DOUBLE
    test('can read BITs', () {
      final dataPacket = BinaryDataPacket.forTests(null);
      final buffer = Buffer.fromList([
        1,
        123,
        20,
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
        0x00,
        0x11,
        0x12,
        0x13,
        0x14,
        0x15,
        0x16,
        0x17,
        0x18,
        0x19,
        0x10
      ]);
      final field = Field.forTests(FIELD_TYPE_BIT);

      var value = dataPacket.readField(field, buffer);
      expect(value is num, equals(true));
      expect(value, equals(123));

      value = dataPacket.readField(field, buffer);
      expect(value is num, equals(true));
      print(value);
//      expect(value, equals(0x0102030405060708090011121314151617181910));
    });
  });
}
