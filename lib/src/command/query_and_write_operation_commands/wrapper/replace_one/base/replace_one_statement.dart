import 'package:meta/meta.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:mongo_dart/src/unions/hint_union.dart';

import '../../../../../unions/query_union.dart';
import '../../../update_operation/base/update_union.dart';
import '../open/replace_one_statement_open.dart';
import '../v1/replace_one_statement_v1.dart';

abstract class ReplaceOneStatement extends UpdateStatement {
  @protected
  ReplaceOneStatement.protected(QueryUnion q, UpdateUnion u,
      {super.upsert, super.collation, super.hint})
      : super.protected(q, u, multi: false) {
    if (!u.specs.isPureDocument) {
      throw MongoDartError('Invalid document in ReplaceOneStatement. '
          'The document is either null or contains update operators');
    }
  }

  factory ReplaceOneStatement(QueryUnion q, UpdateUnion u,
      {ServerApi? serverApi,
      bool? upsert,
      CollationOptions? collation,
      HintUnion? hint}) {
    if (serverApi != null && serverApi.version == ServerApiVersion.v1) {
      return ReplaceOneStatementV1(q, u,
          upsert: upsert, collation: collation, hint: hint);
    }
    return ReplaceOneStatementOpen(q, u,
        upsert: upsert, collation: collation, hint: hint);
  }

  ReplaceOneStatementOpen get toReplaceOneOpen =>
      this is ReplaceOneStatementOpen
          ? this as ReplaceOneStatementOpen
          : ReplaceOneStatementOpen(QueryUnion(q), UpdateUnion(u.value),
              upsert: upsert, collation: collation, hint: hint);

  ReplaceOneStatementV1 get toReplaceOneV1 => this is ReplaceOneStatementV1
      ? this as ReplaceOneStatementV1
      : ReplaceOneStatementV1(QueryUnion(q), UpdateUnion(u.value),
          upsert: upsert, collation: collation, hint: hint);
}
