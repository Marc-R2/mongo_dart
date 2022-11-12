import 'dart:async';

import 'package:logging/logging.dart';
import 'package:mongo_dart/src/core/error/connection_exception.dart';
import 'package:mongo_dart/src/core/network/abstract/connection_base.dart';

import '../error/mongo_dart_error.dart';
import '../info/server_capabilities.dart';
import '../info/server_config.dart';
import '../info/server_status.dart';
import '../message/abstract/section.dart';
import '../message/mongo_modern_message.dart';
import '../network/connection_pool.dart';

enum ServerState { closed, connected }

class Server {
  Server({ServerConfig? serverConfig})
      : serverConfig = serverConfig ?? ServerConfig() {
    connectionPool = ConnectionPool(this.serverConfig);
  }

  final Logger log = Logger('Server');
  ServerConfig serverConfig;
  late ConnectionPool connectionPool;
  ServerState state = ServerState.closed;

  final ServerCapabilities serverCapabilities = ServerCapabilities();
  final ServerStatus serverStatus = ServerStatus();

  bool get isAuthenticated => serverConfig.isAuthenticated;

  Future<void> connect() async {
    if (state == ServerState.connected) {
      return;
    }
    await connectionPool.connectPool();
    if (!connectionPool.isConnected) {
      throw ConnectionException('No Connection Available');
    }
    state = ServerState.connected;
  }

  Future<void> close() async {
    await connectionPool.closePool();
    return;
  }

  Future<Map<String, Object?>> executeModernMessage(MongoModernMessage message,
      {ConnectionBase? connection}) async {
    if (state != ServerState.connected) {
      throw MongoDartError('Server is not is not connected. $state');
    }

    connection ??= await connectionPool.getAvailableConnection();

    var response = await connection.execute(message);

    var section = response.sections.firstWhere((Section section) =>
        section.payloadType == MongoModernMessage.basePayloadType);
    return section.payload.content;
  }
}
