import 'dart:typed_data';

import 'package:mysql1_ext/src/blob.dart';

import 'package:test/test.dart';

void main() {
  test('can create blob from string', () {
    final blob = Blob.fromString('Hello');
    expect(blob, isNotNull);
  });

  test('can string blob can turn into a string', () {
    final blob = Blob.fromString('Hello');
    expect(blob.toString(), equals('Hello'));
  });

  test('can string blob can turn into bytes', () {
    final blob = Blob.fromString('ABC');
    final bytes = blob.toBytes();
    expect(bytes[0], equals(65));
  });

  test('can create blob from bytes', () {
    final bytes = Uint8List(3);
    bytes[0] = 1;
    bytes[1] = 1;
    bytes[2] = 1;
    final blob = Blob.fromBytes(bytes);
    expect(blob, isNotNull);
  });

  test('can bytes blob turn into a string', () {
    final bytes = Uint8List(3);
    bytes[0] = 65;
    bytes[1] = 66;
    bytes[2] = 67;
    final blob = Blob.fromBytes(bytes);
    expect(blob.toString(), 'ABC');
  });

  test('can bytes blob turn into bytes', () {
    final bytes = Uint8List(3);
    bytes[0] = 65;
    bytes[1] = 66;
    bytes[2] = 67;
    final blob = Blob.fromBytes(bytes);
    final outBytes = blob.toBytes();
    expect(outBytes, bytes);
  });

  test('string blobs are equal', () {
    final blob1 = Blob.fromString('ABC');
    final blob2 = Blob.fromString('ABC');
    expect(blob1 == blob2, isTrue);
    expect(blob1.hashCode == blob2.hashCode, isTrue);
  });

  test('string blobs are not equal', () {
    final blob1 = Blob.fromString('ABC');
    final blob2 = Blob.fromString('ABD');
    expect(blob1 == blob2, isFalse);
    // hashCode may be equal, but probably isn't
  });

  test('byte blobs are equal', () {
    final bytes1 = Uint8List(3);
    bytes1[0] = 65;
    bytes1[1] = 66;
    bytes1[2] = 67;
    final blob1 = Blob.fromBytes(bytes1);
    final bytes2 = Uint8List(3);
    bytes2[0] = 65;
    bytes2[1] = 66;
    bytes2[2] = 67;
    final blob2 = Blob.fromBytes(bytes2);
    expect(blob1 == blob2, isTrue);
    expect(blob1.hashCode == blob2.hashCode, isTrue);
  });

  test('byte blobs are not equal', () {
    final bytes1 = Uint8List(3);
    bytes1[0] = 65;
    bytes1[1] = 66;
    bytes1[2] = 67;
    final blob1 = Blob.fromBytes(bytes1);
    final bytes2 = Uint8List(3);
    bytes2[0] = 65;
    bytes2[1] = 66;
    bytes2[2] = 68;
    final blob2 = Blob.fromBytes(bytes2);
    expect(blob1 == blob2, isFalse);
  });

  test('byte blobs equal to string blobs', () {
    final bytes1 = Uint8List(3);
    bytes1[0] = 65;
    bytes1[1] = 66;
    bytes1[2] = 67;
    final blob1 = Blob.fromBytes(bytes1);
    final blob2 = Blob.fromString('ABC');
    expect(blob1 == blob2, isTrue);
    expect(blob1.hashCode == blob2.hashCode, isTrue);
  });

  test('utf blobs', () {
    final blob1 = Blob.fromString('здрасти');
    final bytes = blob1.toBytes();
    final trimmedBytes = <int>[];
    for (final b in bytes) {
      trimmedBytes.add(b & 0xFF);
    }
    final blob2 = Blob.fromBytes(trimmedBytes);
    expect(blob2.toString(), equals('здрасти'));
  });
}
