import 'package:bson/bson.dart';
import 'package:meta/meta.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:mongo_dart/src/command/base/command_operation.dart';
import 'package:mongo_dart/src/command/base/operation_base.dart';

import '../../../../session/client_session.dart';
import '../open/insert_operation_open.dart';
import '../v1/insert_operation_v1.dart';
import 'insert_options.dart';

typedef InsertRec = (
  MongoDocument serverDocument,
  List<MongoDocument> insertedDocuments,
  List ids
);

abstract base class InsertOperation extends CommandOperation {
  @protected
  InsertOperation.protected(MongoCollection collection, this.documents,
      {super.session, InsertOptions? insertOptions, Options? rawOptions})
      : ids = List.filled(documents.length, null),
        super(
            collection.db,
            {},
            <String, dynamic>{
              ...?insertOptions?.getOptions(collection.db),
              ...?rawOptions
            },
            collection: collection,
            aspect: Aspect.writeOperation) {
    if (documents.isEmpty) {
      throw ArgumentError('Documents required in insert operation');
    }

    for (var idx = 0; idx < documents.length; idx++) {
      documents[idx][key_id] ??= ObjectId();
      ids[idx] = documents[idx][key_id];
    }
  }

  factory InsertOperation(
      MongoCollection collection, List<MongoDocument> documents,
      {ClientSession? session,
      InsertOptions? insertOptions,
      Options? rawOptions}) {
    if (collection.serverApi != null) {
      switch (collection.serverApi!.version) {
        case ServerApiVersion.v1:
          return InsertOperationV1(collection, documents,
              session: session,
              insertOptions: insertOptions?.toV1,
              rawOptions: rawOptions);
        default:
          throw MongoDartError(
              'Stable Api ${collection.serverApi!.version} not managed');
      }
    }
    return InsertOperationOpen(collection, documents,
        session: session,
        insertOptions: insertOptions?.toOpen,
        rawOptions: rawOptions);
  }

  List<MongoDocument> documents;
  List ids;

  @override
  Command $buildCommand() => <String, dynamic>{
        keyInsert: collection!.collectionName,
        keyDocuments: documents
      };

  Future<InsertRec> executeInsert() async {
    var ret = await super.process();
    return (ret, documents, ids);
  }
}
