import 'package:mongo_dart/mongo_dart.dart';
import 'package:mongo_dart/src/command/query_and_write_operation_commands/wrapper/insert_one/open/insert_one_options_open.dart';

base class InsertOneOperationOpen extends InsertOneOperation {
  InsertOneOperationOpen(super.collection, super.document,
      {super.session, InsertOneOptionsOpen? insertOneOptions, super.rawOptions})
      : super.protected(insertOneOptions: insertOneOptions);
}
