import 'package:flutter_video_cache/ext/string_ext.dart';

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
  })  : id = _autoId.toString(),
        saveFile = fileName ??
            uri.pathSegments.lastOrNull ??
            uri.toString().generateMd5 {
    _autoId++;
  }

  String get url => uri.toString();

  static int _autoId = 1;

  static void resetId() {
    _autoId = 1;
  }

  void reset() {
    downloadedBytes = 0;
    totalBytes = 0;
    progress = 0.0;
    data.clear();
  }

  @override
  String toString() {
    return 'Task [ '
        'ID: $id, '
        'URL: $uri, '
        'Status: $status, '
        'Priority: $priority, '
        'Progress: $progress, '
        'DownloadedBytes: $downloadedBytes, '
        'TotalBytes: $totalBytes'
        ' ]';
  }
}
