part of mongo_dart;

class GridFSFile {
  GridFS fs = null;
  var id;
  String filename;
  String contentType;
  int length;
  int chunkSize;
  DateTime uploadDate;
  Map<String, Object> extraData;
  String md5;

  GridFSFile([Map data]) {
    if (?data) {
      this.data = data;
    }
  }

  Future<Map> save() {
    if (fs == null) {
      throw "Need fs";
    }
    Map tempData = data;
    return fs.files.insert(tempData);
  }

  Future<bool> validate() {
    if (fs == null) {
      throw "no fs";
    }
    if (md5 == null) {
      throw "no md5 stored";
    }

    Completer completer = new Completer();
    // query for md5 at filemd5
    DbCommand dbCommand = new DbCommand(
        fs.database,fs.bucketName,0,0,1,{"filemd5" : id}, {"md5" : 1});
    fs.database.executeDbCommand(dbCommand).then((Map data) {
      if (data != null && data.containsKey("md5")) {
        completer.complete(md5 == data["md5"]);
      } else {
        completer.complete(false);
      }
    });
    return completer.future;
  }

  int numChunks() {
    return (length.toDouble() / chunkSize).ceil().toInt();
  }

  List<String> get aliases {
    return extraData["aliases"];
  }

  Map get metaData {
    return extraData["metadata"];
  }

  set metaData(Map metaData) {
    extraData["metadata"] = metaData;
  }

  Map get data {
    return {
      "_id" : id,
      "filename" : filename,
      "contentType" : contentType,
      "length" : length,
      "chunkSize" : chunkSize,
      "uploadDate" : uploadDate,
      "md5" : md5,
      // TODO(tsander): Extra Data?? Meta Data??
    };
  }

  set data(Map input) {
    id = input["_id"];
    filename = input["filename"];
    contentType = input["contentType"];
    length = input["length"];
    chunkSize = input["chunkSize"];
    uploadDate = input["uploadDate"];
    md5 = input["md5"];
    // TODO(tsander): Extra Data?? Meta Data??
  }

  void setGridFS( GridFS fs ) {
    this.fs = fs;
  }
}