import 'package:mysql1_ext/src/prepared_statements/prepare_handler.dart';
import 'package:mysql1_ext/src/results/field.dart';

class PreparedQuery {
  PreparedQuery(PrepareHandler handler)
      : sql = handler.sql,
        parameterCount = handler.parameters?.length ?? 0,
        columns = List.from(
          handler.columns?.where((element) => element != null) ?? <Field>[],
        ),
        statementHandlerId = handler.okPacket.statementHandlerId;
  final String sql;

  /// You cannot rely on the type of the parameters in mysql so we do not expose it as
  /// public api
  ///
  /// See https://jira.mariadb.org/browse/CONJ-568
  final int parameterCount;
  final List<Field> columns;
  final int statementHandlerId;
}
