import 'package:logging/logging.dart';
import 'package:mysql1_ext/mysql1_ext.dart';

class QueryBuilder {
  QueryBuilder(this.query, this.params) {
    log = Logger('QueryBuilder');
  }
  String query;
  Map<String, dynamic> params;
  late Logger log;

  @override
  String toString() {
    return _buildQuery(query, params);
  }

  String _buildQuery(String query, Map<String, dynamic> params) {
    log.fine('Building Query Params');
    // convert params to string
    Map<String, String> convertedParams = {};

    for (final param in params.entries) {
      String value;

      if (param.value == null) {
        value = 'NULL';
      } else if (param.value is String) {
        value = "'${_escapeString(param.value.toString())}'";
      } else if (param.value is num) {
        value = param.value.toString();
      } else if (param.value is bool) {
        value = (param.value as bool) ? 'TRUE' : 'FALSE';
      } else {
        value = "'${_escapeString(param.value.toString())}'";
      }

      convertedParams[param.key] = value;
    }

    // find all :placeholders, which can be substituted
    final pattern = RegExp(r":(\w+)");

    final matches = pattern.allMatches(query).where((match) {
      final subString = query.substring(0, match.start);

      int count = "'".allMatches(subString).length;
      if (count > 0 && count.isOdd) {
        return false;
      }

      count = '"'.allMatches(subString).length;
      if (count > 0 && count.isOdd) {
        return false;
      }

      return true;
    }).toList();

    int lengthShift = 0;

    for (final match in matches) {
      final paramName = match.group(1);

      // check param exists
      if (false == convertedParams.containsKey(paramName)) {
        throw MySqlClientError("There is no parameter with name: $paramName");
      }

      final newQuery = query.replaceFirst(
        match.group(0)!,
        convertedParams[paramName]!,
        match.start + lengthShift,
      );

      lengthShift += newQuery.length - query.length;
      query = newQuery;
    }

    return query;
  }

  String _escapeString(String input) {
    if (input == '') return '';

    final escapeChars = [r'\', "'"];
    for (final char in escapeChars) {
      input = input.replaceAll(char, '\\$char');
    }

    return input;
  }
}
