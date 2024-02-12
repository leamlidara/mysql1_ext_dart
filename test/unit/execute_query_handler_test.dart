// ignore_for_file: strong_mode_implicit_dynamic_list_literal

import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:mysql1_ext/src/blob.dart';
import 'package:mysql1_ext/src/prepared_statements/execute_query_handler.dart';

import 'package:mysql1_ext/src/prepared_statements/prepared_query.dart';

import 'package:test/test.dart';

void main() {
  group('ExecuteQueryHandler.createNullMap', () {
    test('can build empty map', () {
      final handler = ExecuteQueryHandler(null, false, []);
      final nullmap = handler.createNullMap();
      expect(nullmap, equals([]));
    });

    test('can build map with no nulls', () {
      final handler = ExecuteQueryHandler(null, false, [1]);
      final nullmap = handler.createNullMap();
      expect(nullmap, equals([0]));
    });

    test('can build map with one null', () {
      final handler = ExecuteQueryHandler(null, false, [null]);
      final nullmap = handler.createNullMap();
      expect(nullmap, equals([1]));
    });

    test('can build map with eight nulls', () {
      final handler = ExecuteQueryHandler(
        null,
        false,
        [null, null, null, null, null, null, null, null],
      );
      final nullmap = handler.createNullMap();
      expect(nullmap, equals([255]));
    });

    test('can build map with eight not nulls', () {
      final handler = ExecuteQueryHandler(null, false, [0, 0, 0, 0, 0, 0, 0, 0]);
      final nullmap = handler.createNullMap();
      expect(nullmap, equals([0]));
    });

    test('can build map with some nulls and some not', () {
      final handler = ExecuteQueryHandler(null, false, [null, 0, 0, 0, 0, 0, 0, null]);
      final nullmap = handler.createNullMap();
      expect(nullmap, equals([129]));
    });

    test('can build map with some nulls and some not', () {
      final handler = ExecuteQueryHandler(null, false, [null, 0, 0, 0, 0, 0, 0, null]);
      final nullmap = handler.createNullMap();
      expect(nullmap, equals([129]));
    });

    test('can build map which is more than one byte', () {
      final handler = ExecuteQueryHandler(
        null,
        false,
        [null, 0, 0, 0, 0, 0, 0, null, 0, 0, 0, 0, 0, 0, 0, 0],
      );
      final nullmap = handler.createNullMap();
      expect(nullmap, equals([129, 0]));
    });

    test('can build map which just is more than one byte', () {
      final handler = ExecuteQueryHandler(null, false, [null, 0, 0, 0, 0, 0, 0, null, 0]);
      final nullmap = handler.createNullMap();
      expect(nullmap, equals([129, 0]));
    });

    test('can build map which just is more than one byte with a null', () {
      final handler = ExecuteQueryHandler(
        null,
        false,
        [null, 0, 0, 0, 0, 0, 0, null, null],
      );
      final nullmap = handler.createNullMap();
      expect(nullmap, equals([129, 1]));
    });

    test('can build map which just is more than one byte with a null, another pattern', () {
      final handler = ExecuteQueryHandler(
        null,
        false,
        [null, 0, null, 0, 0, 0, 0, null, null],
      );
      final nullmap = handler.createNullMap();
      expect(nullmap, equals([129 + 4, 1]));
    });
  });

  group('ExecuteQueryHandler.writeValuesToBuffer', () {
    late List<int> types;

    setUp(() {
      types = <int>[];
    });

    test('can write values for unexecuted query', () {
      final preparedQuery = MockPreparedQuery();
      when(() => preparedQuery.statementHandlerId).thenReturn(123);

      final handler = ExecuteQueryHandler(preparedQuery, false, []);
      handler.preparedValues = [];
      final buffer = handler.writeValuesToBuffer([], 0, types);
      expect(buffer.length, equals(11));
      expect(buffer.list, equals([23, 123, 0, 0, 0, 0, 1, 0, 0, 0, 1]));
    });

    test('can write values for executed query', () {
      final preparedQuery = MockPreparedQuery();
      when(() => preparedQuery.statementHandlerId).thenReturn(123);

      final handler = ExecuteQueryHandler(preparedQuery, true, []);
      handler.preparedValues = [];
      final buffer = handler.writeValuesToBuffer([], 0, types);
      expect(buffer.length, equals(11));
      expect(buffer.list, equals([23, 123, 0, 0, 0, 0, 1, 0, 0, 0, 0]));
    });

    test('can write values for executed query with nullmap', () {
      final preparedQuery = MockPreparedQuery();
      when(() => preparedQuery.statementHandlerId).thenReturn(123);

      final handler = ExecuteQueryHandler(preparedQuery, true, []);
      handler.preparedValues = [];
      final buffer = handler.writeValuesToBuffer([5, 6, 7], 0, types);
      expect(buffer.length, equals(14));
      expect(
        buffer.list,
        equals([23, 123, 0, 0, 0, 0, 1, 0, 0, 0, 5, 6, 7, 0]),
      );
    });

    test('can write values for unexecuted query with values', () {
      final preparedQuery = MockPreparedQuery();
      when(() => preparedQuery.statementHandlerId).thenReturn(123);

      types = [100];
      final handler = ExecuteQueryHandler(preparedQuery, false, [123]);
      handler.preparedValues = [123];
      final buffer = handler.writeValuesToBuffer([5, 6, 7], 8, types);
      expect(buffer.length, equals(23));
      expect(
        buffer.list,
        equals([23, 123, 0, 0, 0, 0, 1, 0, 0, 0, 5, 6, 7, 1, 100, 123, 0, 0, 0, 0, 0, 0, 0]),
      );
    });
  });

  group('ExecuteQueryHandler.prepareValue', () {
    MockPreparedQuery preparedQuery;
    late ExecuteQueryHandler handler;

    setUp(() {
      preparedQuery = MockPreparedQuery();
      handler = ExecuteQueryHandler(preparedQuery, false, []);
    });

    test('can prepare int values correctly', () {
      expect(handler.prepareValue(123), equals(123));
    });

    test('can prepare string values correctly', () {
      expect(handler.prepareValue('hello'), equals(utf8.encode('hello')));
    });

    test('can prepare double values correctly', () {
      expect(handler.prepareValue(123.45), equals(utf8.encode('123.45')));
    });

    test('can prepare datetime values correctly', () {
      final dateTime = DateTime.utc(2014, 3, 4, 5, 6, 7, 8);
      expect(handler.prepareValue(dateTime), equals(dateTime));
    });

    test('can prepare bool values correctly', () {
      expect(handler.prepareValue(true), equals(true));
    });

    test('can prepare list values correctly', () {
      expect(handler.prepareValue([1, 2, 3]), equals([1, 2, 3]));
    });

    test('can prepare blob values correctly', () {
      expect(
        handler.prepareValue(Blob.fromString('hello')),
        equals(utf8.encode('hello')),
      );
    });
  });

  group('ExecuteQueryHandler._measureValue', () {
    MockPreparedQuery preparedQuery;
    late ExecuteQueryHandler handler;

    setUp(() {
      preparedQuery = MockPreparedQuery();
      handler = ExecuteQueryHandler(preparedQuery, false, []);
    });

    test('can measure int values correctly', () {
      expect(handler.measureValue(123, 123), equals(8));
    });

    test('can measure short string correctly', () {
      const string = 'a';
      final preparedString = utf8.encode(string);
      expect(handler.measureValue(string, preparedString), equals(2));
    });

    test('can measure longer string correctly', () {
      final string = String.fromCharCodes(List.filled(300, 65));
      final preparedString = utf8.encode(string);
      expect(
        handler.measureValue(string, preparedString),
        equals(3 + string.length),
      );
    });

    test('can measure even longer string correctly', () {
      final string = String.fromCharCodes(List.filled(70000, 65));
      final preparedString = utf8.encode(string);
      expect(
        handler.measureValue(string, preparedString),
        equals(4 + string.length),
      );
    });

//    test('can measure even very long string correctly', () {
//      var string = String.fromCharCodes(List.filled(2 << 23 + 1, 65));
//      var preparedString = utf8.encode(string);
//      expect(handler.measureValue(string, preparedString),
//          equals(5 + string.length));
//    });

    //etc
  });
}

class MockPreparedQuery extends Mock implements PreparedQuery {}
