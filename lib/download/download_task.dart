import 'download_status.dart';

class DownloadTask {
  final String id;
  final String url;

  int priority;
  String saveFile;
  double progress;
  int downloadedBytes;
  int totalBytes;
  DownloadStatus status;

  int createAt = DateTime.now().millisecondsSinceEpoch;

  DownloadTask({
    required this.url,
    this.priority = 1,
    String? fileName,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.IDLE,
  })  : id = _autoId.toString(),
        saveFile = fileName ?? url.split('/').last {
    _autoId++;
    checkUrl();
  }

  void checkUrl() {
    try {
      Uri.parse(url);
    } catch (e) {
      throw ArgumentError('Invalid URL: $url');
    }
  }

  static int _autoId = 1;

  static void resetId() {
    _autoId = 1;
  }

  @override
  String toString() {
    return 'Task [ '
        'ID: $id, '
        'URL: $url, '
        'Status: $status, '
        'Priority: $priority, '
        'Progress: $progress, '
        'DownloadedBytes: $downloadedBytes, '
        'TotalBytes: $totalBytes'
        ' ]';
  }
}
