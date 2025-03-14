// 定义下载任务的状态枚举
enum DownloadTaskStatus {
  IDLE,
  DOWNLOADING,
  RESUME,
  PAUSED,
  COMPLETED,
  CANCELLED
}

// 下载任务类
class DownloadTask {
  static int _autoId = 1;
  final String id;
  final String url;
  final int priority;
  DownloadTaskStatus status = DownloadTaskStatus.IDLE;
  String saveFile;
  double progress = 0.0;
  int downloadedBytes = 0;
  int totalBytes = 0;
  bool _isCompleted = false;

  DownloadTask({
    required this.url,
    String? fileName,
    this.priority = 1,
  })  : id = _autoId.toString(),
        saveFile = fileName ?? url.split('/').last {
    _autoId++;
    if (!isValidUrl(url)) {
      throw ArgumentError('Invalid URL: $url');
    }
  }

  bool isValidUrl(String url) {
    try {
      Uri.parse(url);
      return true;
    } catch (e) {
      return false;
    }
  }

  void updateProgress() {
    if (status == DownloadTaskStatus.DOWNLOADING && !_isCompleted) {
      if (totalBytes == 0) {
        print('Task $id: Total bytes is 0, cannot calculate progress.');
        return;
      }
      if (downloadedBytes >= totalBytes) {
        progress = 1.0;
        _isCompleted = true;
        status = DownloadTaskStatus.COMPLETED;
      } else {
        progress = downloadedBytes / totalBytes;
      }
      print('Task ${id} (${url}) progress: ${progress * 100}%');
    }
  }

  @override
  String toString() {
    return 'Task ID: $id, URL: $url, Status: $status, Progress: ${(progress * 100).toStringAsFixed(2)}%';
  }
}
