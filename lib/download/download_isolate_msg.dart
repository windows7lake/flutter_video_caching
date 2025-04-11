enum IsolateMsgType {
  sendPort,
  task,
  status
}

class DownloadIsolateMsg {
  final IsolateMsgType type;
  final dynamic data;

  DownloadIsolateMsg(this.type, this.data);

  @override
  String toString() {
    return 'DownloadIsolateMsg [ type: $type, data: $data ]';
  }
}
