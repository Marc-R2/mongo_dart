// On development

import 'dart:async';
import 'dart:collection';

import 'package:mongo_dart/src/commands/base/command_operation.dart';
import 'package:mongo_dart/src/commands/administration_commands/kill_cursors_command/kill_cursors_command.dart';
import 'package:mongo_dart/src/commands/aggregation_commands/aggregate/return_classes/change_event.dart';
import 'package:mongo_dart/src/commands/aggregation_commands/wrapper/change_stream/change_stream_handler.dart';
import 'package:mongo_dart/src/commands/query_and_write_operation_commands/get_more_command/get_more_command.dart';
import 'package:mongo_dart/src/commands/query_and_write_operation_commands/get_more_command/get_more_options.dart';

import '../../mongo_dart_old.dart';
import '../core/error/mongo_dart_error.dart';
import '../commands/base/db_admin_command_operation.dart';
import '../commands/base/operation_base.dart';
import '../topology/server.dart';
import 'mongo_database.dart';
import 'mongo_collection.dart';

typedef MonadicBlock = void Function(Map<String, dynamic> value);

const defaultBatchSize = 101;

class ModernCursor {
  ModernCursor(CommandOperation operation, this.server,
      {bool? checksumPresent,
      bool? moreToCome,
      bool? exhaustAllowed,
      int? batchSize})
      // ignore: prefer_initializing_formals
      : operation = operation,
        collection = operation.collection,
        db = operation.collection?.db ?? operation.db,
        checksumPresent = checksumPresent ?? false,
        moreToCome = moreToCome ?? false,
        exhaustAllowed = exhaustAllowed ?? false {
    if (operation is FindOperation && collection == null) {
      throw MongoDartError('Collection required in cursor initialization');
    }
    if (operation is FindOperation) {
      tailable = (operation).isTailable;
      awaitData = (operation).isAwaitData;
    } else if (operation is ChangeStreamOperation) {
      isChangeStream = tailable = awaitData = true;
    }
    var internalBatchSize = batchSize;
    if (internalBatchSize == null) {
      var operationBatchSize = operation.options[keyBatchSize] as int?;
      if (operationBatchSize != null && operationBatchSize != 0) {
        internalBatchSize = operationBatchSize;
      }
    }

    _batchSize = internalBatchSize ?? defaultBatchSize;
  }
  ModernCursor.fromDbAdmincommand(DbAdminCommandOperation command, this.server,
      {bool? checksumPresent,
      bool? moreToCome,
      bool? exhaustAllowed,
      int? batchSize})
      // ignore: prefer_initializing_formals
      : operation = command,
        //collection = command.collection,
        db = command.db,
        checksumPresent = checksumPresent ?? false,
        moreToCome = moreToCome ?? false,
        exhaustAllowed = exhaustAllowed ?? false {
    if (command is FindOperation && collection == null) {
      throw MongoDartError('Collection required in cursor initialization');
    }

    var internalBatchSize = batchSize;
    if (internalBatchSize == null) {
      var operationBatchSize = command.options[keyBatchSize] as int?;
      if (operationBatchSize != null && operationBatchSize != 0) {
        internalBatchSize = operationBatchSize;
      }
    }

    _batchSize = internalBatchSize ?? defaultBatchSize;
  }

  /// This method allows the creation of the cursor from the Id and the
  /// collection. It is not intended for everyday use, but more for debugging
  /// and testing.
  ///
  /// All optional data must be correct or the result will be unpredictable.
  ///
  /// If another cursor already has been created with the same Id
  /// unpredictable results can be returned.
  ///
  /// The goal of this constructor is to build a cursor when a FindOperation
  /// or other read operation has been executed, without generating
  /// an explicit cursor. This way, for getting the extra documents,
  /// we may need a cursor.
  ModernCursor.fromOpenId(
      MongoCollection collection, this.cursorId, this.server,
      {bool? tailable,
      bool? awaitData,
      bool? isChangeStream,
      bool? checksumPresent,
      bool? moreToCome,
      bool? exhaustAllowed})
      // ignore: prefer_initializing_formals
      : collection = collection,
        collectionName = collection.collectionName,
        tailable = tailable ?? false,
        awaitData = awaitData ?? false,
        isChangeStream = isChangeStream ?? false,
        checksumPresent = checksumPresent ?? false,
        moreToCome = moreToCome ?? false,
        exhaustAllowed = exhaustAllowed ?? false {
    state = State.open;
    db = collection.db;
    if (this.isChangeStream) {
      this.tailable = this.awaitData = true;
    }
    _batchSize = defaultBatchSize;
  }

  State state = State.init;
  BsonLong cursorId = BsonLong(0);
  Server server;
  late MongoDatabase db;
  Queue<Map<String, Object?>> items = Queue<Map<String, Object?>>();
  MongoCollection? collection;
  bool tailable = false;
  bool awaitData = false;
  bool isChangeStream = false;

  // Batch size for the getMore command if different from the default
  late int _batchSize;
  int get batchSize => _batchSize;
  set batchSize(int value) {
    if (value < 0) {
      throw MongoDartError('Batch size must be a non negative value');
    }
    _batchSize = value;
  }

  // in case of collection agnostic commands (aggregate) is the name
  // of the collecton as returns from the first batch (taken from ns)
  String? collectionName;

  // at present you have to se these values on the operation options
  /* Map<String, dynamic> selector;
  Map<String, dynamic> fields;
  int skip = 0;
  int limit = 0;
  Map<String, dynamic> sort;
  Map<String, dynamic> hint; */
  //MonadicBlock eachCallback;
  //var eachComplete;

  // These 4 fields are not used at present
  bool explain = false;
  bool checksumPresent;
  bool moreToCome;
  bool exhaustAllowed;

  /// The operation to be executed.
  /// It must be an operation that returns a cursorId, like find, getMore, etc.
  OperationBase? operation;

  /// Specify the milliseconds between getMore on tailable cursor,
  /// only applicable when awaitData isn't set.
  /// Default value is 100 ms
  int tailableRetryInterval = 100;

  Map<String, Object?>? _getNextItem() => items.removeFirst();

  void extractCursorData(Map<String, Object?> operationReturnMap) {
    if (operationReturnMap[keyCursor] == null) {
      throw MongoDartError('The operation type ${operation.runtimeType} '
          'does not return a cursor');
    }
    var cursorMap = operationReturnMap[keyCursor] as Map<String, Object?>?;
    if (cursorMap == null) {
      throw MongoDartError('No cursor returned');
    }
    if (collectionName == null && cursorMap[keyNs] != null) {
      var ns = cursorMap[keyNs] as String;
      var nsParts = ns.split('.');
      nsParts.removeAt(0);
      collectionName = nsParts.join('.');
    }
    List<Map<String, Object?>> documents;
    if (cursorMap[keyNextBatch] != null && cursorMap[keyNextBatch] is List) {
      documents = <Map<String, Object?>>[...cursorMap[keyNextBatch] as List];
    } else if (cursorMap[keyFirstBatch] != null &&
        cursorMap[keyFirstBatch] is List) {
      documents = <Map<String, Object?>>[...cursorMap[keyFirstBatch] as List];
    } else {
      documents = <Map<String, Object?>>[];
    }

    for (var doc in documents) {
      items.add(doc);
    }
  }

  Future<void> _serverSideCursorClose() async {
    if (tailable) {
      throw MongoDartError('Tailable Cursor closed by the server.');
    }
    return close();
  }

  /// Returns only the first document (if any) and then closes the cursor
  ///
  /// Convenience method for
  /// ```dart
  /// await nextObject();
  /// await close();
  /// ```
  Future<Map<String, Object?>?> onlyFirst() async {
    var ret = await nextObject();
    await close();
    return ret;
  }

  Future<Map<String, Object?>?> nextObject() async {
    if (items.isNotEmpty) {
      return _getNextItem();
    }
    if (collection != null &&
        collection!.collectionName == r'$cmd' &&
        operation is FindOperation &&
        (operation! as FindOperation).limit == 1) {
      return operation!.execute();
    }

    var justPrepareCursor = false;
    Map<String, Object?>? result;
    if (state == State.init && operation != null) {
      if (operation!.options[keyBatchSize] != null &&
          operation!.options[keyBatchSize] == 0) {
        justPrepareCursor = true;
      }
      result = await operation!.execute();
      state = State.open;
    } else if (state == State.open) {
      if (cursorId.data == 0) {
        await _serverSideCursorClose();
        return null;
      }
      var command = GetMoreCommand(collection, cursorId,
          db: db,
          collectionName: collectionName,
          getMoreOptions: GetMoreOptions(batchSize: _batchSize));
      result = await command.execute();
    }
    if (result == null) {
      throw MongoDartError('Could not execut a further search');
    }
    if (result[keyOk] == 0.0) {
      await close();
      throw MongoDartError(
          result[keyErrmsg] as String? ??
              'Generic error in nextObject() method',
          mongoCode: result[keyCode] as int?,
          errorCodeName: result[keyCodeName] as String?);
    }
    var cursorMap = result[keyCursor] as Map<String, dynamic>?;
    cursorId =
        cursorMap == null ? BsonLong(0) : BsonLong(cursorMap[keyId] ?? 0);
    // The result map returns last records while setting cursorId to zero.
    extractCursorData(result);
    // batch size for "first batch" was 0, no data returned.
    // Just prepared the cursor for further fetching
    if (justPrepareCursor) {
      return nextObject();
    }
    if (items.isNotEmpty) {
      return _getNextItem();
    }
    if (cursorId.data == 0) {
      await _serverSideCursorClose();
      return null;
    }

    if (tailable) {
      if (awaitData) {
        return null;
      }
      return Future.delayed(
          Duration(milliseconds: tailableRetryInterval), () => null);
    }
    // residual check, it should never pass here.
    await close();
    return null;
  }

  Future<void> close() async {
    ////_log.finer("Closing cursor, cursorId = $cursorId");
    state = State.closed;
    if (cursorId.value != 0 && collection != null) {
      var command = KillCursorsCommand(collection!, [cursorId], db: db);
      if (server.state == ServerState.connected) {
        await command.execute();
      }
      cursorId = BsonLong(0);
    }
    return;
  }

  Stream<Map<String, Object?>> get stream {
    var paused = true;
    var controller = StreamController<Map<String, Object?>>();

    Future<void> readNext() async {
      try {
        do {
          var doc = await nextObject();
          if (doc != null) {
            controller.add(doc);
          }
        } while (state != State.closed && !paused);
        if (state == State.closed) {
          await controller.close();
        }
      } catch (e, stack) {
        controller.addError(e, stack);
      }
    }

    void startReading() {
      if (state == State.closed) {
        return;
      }
      paused = false;
      readNext();
    }

    void pauseReading() => paused = true;
    void resumeReading() => startReading();
    void cancelReading() async => await close();

    controller.onCancel = cancelReading;
    controller.onResume = resumeReading;
    controller.onPause = pauseReading;
    controller.onListen = startReading;

    return controller.stream;
  }

  Stream<ChangeEvent> get changeStream {
    if (!isChangeStream) {
      throw MongoDartError('Please, use this stream only for changeStreams');
    }
    return stream.transform(ChangeStreamHandler().transformer);
  }
}
