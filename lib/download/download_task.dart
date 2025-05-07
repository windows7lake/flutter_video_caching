import '../ext/string_ext.dart';
import 'download_status.dart';

class DownloadTask {
  final String id;
  final Uri uri;

  int priority;
  String cacheDir;
  String saveFile;
  double progress;
  int downloadedBytes;
  int totalBytes;
  DownloadStatus status;
  int startRange;
  int? endRange;
  String? hlsKey;
  List<int> data = [];

  int createAt = DateTime.now().millisecondsSinceEpoch;

  DownloadTask({
    required this.uri,
    this.priority = 1,
    String? fileName,
    this.cacheDir = "",
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.IDLE,
    this.startRange = 0,
    this.endRange,
    this.hlsKey,
  })  : id = _autoId.toString(),
        saveFile = fileName ??
            uri.pathSegments.lastOrNull ??
            uri.toString().generateMd5 {
    _autoId++;
  }

  String get url => uri.toString();

  String get matchUrl {
    StringBuffer sb = StringBuffer();
    sb.write(uri.toString());
    if (startRange > 0) {
      sb.write("?startRange=$startRange");
    }
    if (endRange != null) {
      sb.write("&endRange=$endRange");
    }
    return sb.toString().generateMd5;
  }

  String get saveFileName {
    StringBuffer sb = StringBuffer();
    sb.write(saveFile);
    if (endRange != null) {
      sb.write("-$endRange");
    }
    return sb.toString();
  }

  static int _autoId = 1;

  static void resetId() {
    _autoId = 1;
  }

  void reset() {
    downloadedBytes = 0;
    totalBytes = 0;
    progress = 0.0;
    startRange = 0;
    endRange = null;
    data.clear();
  }

  @override
  String toString() {
    return 'Task [ '
        'ID: $id, '
        'URL: $uri, '
        'Status: $status, '
        'StartRange: $startRange, '
        'EndRange: $endRange, '
        'Priority: $priority, '
        'Progress: $progress, '
        'DownloadedBytes: $downloadedBytes, '
        'TotalBytes: $totalBytes, '
        'CacheDir: $cacheDir, '
        'SaveFile: $saveFile, '
        'HLSKey: $hlsKey, '
        ' ]';
  }
}
