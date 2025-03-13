// 定义下载任务的状态枚举
enum DownloadTaskStatus { IDLE, DOWNLOADING, PAUSED, COMPLETED, CANCELLED }

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
  }

  void start() {
    if (status == DownloadTaskStatus.IDLE ||
        status == DownloadTaskStatus.PAUSED) {
      status = DownloadTaskStatus.DOWNLOADING;
    }
  }

  void pause() {
    if (status == DownloadTaskStatus.DOWNLOADING) {
      status = DownloadTaskStatus.PAUSED;
    }
  }

  void resume() {
    if (status == DownloadTaskStatus.PAUSED) {
      status = DownloadTaskStatus.DOWNLOADING;
    }
  }

  void cancel() {
    if (status == DownloadTaskStatus.DOWNLOADING ||
        status == DownloadTaskStatus.PAUSED) {
      status = DownloadTaskStatus.CANCELLED;
    }
  }

  void updateProgress() {
    if (status == DownloadTaskStatus.DOWNLOADING && !_isCompleted) {
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

  String toString() {
    return 'Task ID: $id, URL: $url, Status: $status, Progress: ${(progress * 100).toStringAsFixed(2)}%';
  }
}
