// ignore_for_file: return_of_invalid_type, strong_mode_implicit_dynamic_return, strong_mode_implicit_dynamic_parameter, invalid_assignment, strong_mode_implicit_dynamic_variable

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:mysql1_ext/src/buffer.dart';
import 'package:mysql1_ext/src/constants.dart';
import 'package:mysql1_ext/src/handlers/handler.dart';
import 'package:mysql1_ext/src/handlers/ok_packet.dart';
import 'package:mysql1_ext/src/query/result_set_header_packet.dart';
import 'package:mysql1_ext/src/query/standard_data_packet.dart';
import 'package:mysql1_ext/src/results/field.dart';
import 'package:mysql1_ext/src/results/results_impl.dart';
import 'package:mysql1_ext/src/results/row.dart';

class QueryStreamHandler extends Handler {
  QueryStreamHandler(this._sql) : super(Logger('QueryStreamHandler'));
  static const int STATE_HEADER_PACKET = 0;
  static const int STATE_FIELD_PACKETS = 1;
  static const int STATE_ROW_PACKETS = 2;
  final String _sql;
  int _state = STATE_HEADER_PACKET;

  OkPacket? _okPacket;
  ResultSetHeaderPacket? _resultSetHeaderPacket;
  final List<Field> fieldPackets = <Field>[];

  StreamController<ResultRow>? _streamController;

  @override
  Buffer createRequest() {
    final encoded = utf8.encode(_sql);
    final buffer = Buffer(encoded.length + 1);
    buffer.writeByte(COM_QUERY);
    buffer.writeList(encoded);
    return buffer;
  }

  @override
  HandlerResponse processResponse(Buffer response) {
    log.fine('Processing query response');
    final packet = checkResponse(response, isHandlingRows: _state == STATE_ROW_PACKETS);

    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        if (_state == STATE_FIELD_PACKETS) {
          return _handleEndOfFields();
        } else if (_state == STATE_ROW_PACKETS) {
          return _handleEndOfRows();
        }
      } else {
        switch (_state) {
          case STATE_HEADER_PACKET:
            _handleHeaderPacket(response);
            break;
          case STATE_FIELD_PACKETS:
            _handleFieldPacket(response);
            break;
          case STATE_ROW_PACKETS:
            _handleRowPacket(response);
            break;
        }
      }
    } else if (packet is OkPacket) {
      return _handleOkPacket(packet);
    }
    return HandlerResponse.notFinished;
  }

  HandlerResponse _handleEndOfFields() {
    _state = STATE_ROW_PACKETS;
    _streamController = StreamController<ResultRow>(
      onCancel: () {
        _streamController!.close();
      },
    );
    return HandlerResponse(
      result: ResultsStream(
        null,
        null,
        fieldPackets,
        stream: _streamController!.stream,
      ),
    );
  }

  HandlerResponse _handleEndOfRows() {
    // the connection's _handler field needs to have been nulled out before the stream is closed,
    // otherwise the stream will be reused in an unfinished state.
    // TODO: can we use Future.delayed elsewhere, to make reusing connections nicer?
//    Future.delayed(Duration(seconds: 0), _streamController.close);
    _streamController?.close();
    return HandlerResponse(finished: true);
  }

  void _handleHeaderPacket(Buffer response) {
    _resultSetHeaderPacket = ResultSetHeaderPacket(response);
    log.fine(_resultSetHeaderPacket.toString());
    _state = STATE_FIELD_PACKETS;
  }

  void _handleFieldPacket(Buffer response) {
    final fieldPacket = Field(response);
    log.fine(fieldPacket.toString());
    fieldPackets.add(fieldPacket);
  }

  void _handleRowPacket(Buffer response) {
    final dataPacket = StandardDataPacket(response, fieldPackets);
    log.fine(dataPacket.toString());
    _streamController?.add(dataPacket);
  }

  HandlerResponse _handleOkPacket(OkPacket packet) {
    _okPacket = packet;
    var finished = false;
    // TODO: I think this is to do with multiple queries. Will probably break.
    if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
      finished = true;
    }

    //TODO is this finished value right?
    return HandlerResponse(
      finished: finished,
      result: ResultsStream(
        _okPacket!.insertId,
        _okPacket!.affectedRows,
        fieldPackets,
      ),
    );
  }

  @override
  String toString() {
    return 'QueryStreamHandler($_sql)';
  }
}
