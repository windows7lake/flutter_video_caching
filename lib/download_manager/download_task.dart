import 'download_state.dart';

// 下载任务实体类
class DownloadTask {
  final String id;
  final String url;
  final String savePath;
  int priority;
  final String? checksum;
  int retriesLeft;
  DateTime? createdTime;
  DownloadState state;
  int resumeOffset = 0; // 断点续传偏移量

  DownloadTask({
    required this.id,
    required this.url,
    required this.savePath,
    this.priority = 0,
    this.checksum,
    this.retriesLeft = 3,
    this.state = DownloadState.queued,
  }) : createdTime = DateTime.now();

  // 状态转换方法
  void transitState(DownloadState newState) {
    if (state == DownloadState.canceled) return;
    state = newState;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DownloadTask && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
