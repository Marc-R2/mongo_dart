import 'package:mongo_dart/src/command/command.dart';

import '../../../../../unions/query_union.dart';

class DeleteOneStatementOpen extends DeleteOneStatement {
  DeleteOneStatementOpen(QueryUnion filter, {super.collation, super.hint})
      : super.protected(filter);
}
