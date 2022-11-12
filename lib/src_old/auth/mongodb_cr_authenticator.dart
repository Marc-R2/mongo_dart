//part of mongo_dart;
import 'package:crypto/crypto.dart' as crypto;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:mongo_dart/mongo_dart_old.dart' show Db, DbCommand;
import 'package:mongo_dart/src/core/message/deprecated/mongo_query_message.dart';
import 'package:mongo_dart/src_old/auth/auth.dart';
import 'package:sasl_scram/sasl_scram.dart' show UsernamePasswordCredential;

import '../../src/core/network/abstract/connection_base.dart';
import '../../src/core/topology/server.dart';

class MongoDbCRAuthenticator extends Authenticator {
  MongoDbCRAuthenticator(this.db, this.credentials) : super();

  static final String name = 'MONGODB-CR';

  final Db db;
  final UsernamePasswordCredential credentials;

  @override
  Future authenticate(Server server, {ConnectionBase? connection}) {
    throw MongoDartError('Authentication no more used');
  }

  static DbCommand createMongoDbCrAuthenticationCommand(
      Db db, UsernamePasswordCredential credentials, String nonce) {
    var hashedPassword = crypto.md5
        .convert(
            '${credentials.username}:mongo:${credentials.password}'.codeUnits)
        .toString();
    var key = crypto.md5
        .convert('$nonce${credentials.username}$hashedPassword'.codeUnits)
        .toString();
    var selector = {
      'authenticate': 1,
      'user': credentials.username,
      'nonce': nonce,
      'key': key
    };
    return DbCommand(db.authSourceDb ?? db, DbCommand.SYSTEM_COMMAND_COLLECTION,
        MongoQueryMessage.OPTS_NONE, 0, -1, selector, null);
  }
}
