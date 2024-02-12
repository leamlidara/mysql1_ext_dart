import 'dart:async';
import 'dart:collection';

import 'package:mysql1_ext/src/results/field.dart';
import 'package:mysql1_ext/src/results/row.dart';

class ResultsStream extends StreamView<ResultRow> {
  factory ResultsStream(
    int? insertId,
    int? affectedRows,
    List<Field>? fields, {
    Stream<ResultRow>? stream,
  }) {
    if (stream != null) {
      final newStream = stream.transform(
        StreamTransformer.fromHandlers(
          handleDone: (EventSink<ResultRow> sink) {
            sink.close();
          },
        ),
      );
      return ResultsStream._fromStream(
        insertId,
        affectedRows,
        fields,
        newStream,
      );
    } else {
      final newStream = Stream.fromIterable(<ResultRow>[]);
      return ResultsStream._fromStream(
        insertId,
        affectedRows,
        fields,
        newStream,
      );
    }
  }

  ResultsStream._fromStream(
    this.insertId,
    this.affectedRows,
    List<Field>? fields,
    Stream<ResultRow> stream,
  )   : fields = UnmodifiableListView(fields ?? []),
        super(stream);
  final int? insertId;
  final int? affectedRows;

  final List<Field> fields;

  /// Takes a _ResultsImpl and destreams it. That is, it listens to the stream, collecting
  /// all the rows into a list until the stream has finished. It then returns a new
  /// _ResultsImpl which wraps that list of rows.
  static Future<ResultsStream> destream(ResultsStream results) async {
    final rows = await results.toList();
    final newStream = Stream<ResultRow>.fromIterable(rows);
    return ResultsStream._fromStream(
      results.insertId,
      results.affectedRows,
      results.fields,
      newStream,
    );
  }
}
