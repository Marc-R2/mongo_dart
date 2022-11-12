import 'package:mongo_dart/mongo_dart_old.dart' show DbCollection;
import 'package:mongo_dart/src_old/database/commands/query_and_write_operation_commands/delete_operation/delete_operation.dart';
import 'package:mongo_dart/src_old/database/commands/query_and_write_operation_commands/return_classes/abstract_write_result.dart';
import 'package:mongo_dart/src_old/database/commands/query_and_write_operation_commands/return_classes/write_result.dart';

import '../../../../../../src/core/network/abstract/connection_base.dart';
import '../../../../../../src/core/topology/server.dart';
import 'delete_one_options.dart';
import 'delete_one_statement.dart';

class DeleteOneOperation extends DeleteOperation {
  //DeleteOneStatement deleteRequest;

  DeleteOneOperation(DbCollection collection, DeleteOneStatement deleteRequest,
      {DeleteOneOptions? deleteOneOptions, Map<String, Object>? rawOptions})
      : super(
          collection,
          [deleteRequest],
          deleteOptions: deleteOneOptions,
          rawOptions: rawOptions,
        );

  Future<WriteResult> executeDocument(Server server,
      {ConnectionBase? connection}) async {
    var ret = await super.execute(server, connection: connection);
    return WriteResult.fromMap(WriteCommandType.delete, ret);
  }
}
