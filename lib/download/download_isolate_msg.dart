enum IsolateMsgType { sendPort, task, logPrint }

/// Message sent to or from the download isolate.
class DownloadIsolateMsg {
  final IsolateMsgType type;
  final dynamic data;

  DownloadIsolateMsg(this.type, this.data);

  @override
  String toString() {
    return 'DownloadIsolateMsg [ type: $type, data: $data ]';
  }
}
