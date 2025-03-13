import 'download_state.dart';

// 下载进度实体类
class DownloadProgress {
  final String taskId;
  final double progress;
  final double? speed;
  final DownloadError? error;
  final bool isCompleted;
  final DateTime timestamp;
  final DownloadState state;

  DownloadProgress._internal({
    required this.taskId,
    this.progress = 0.0,
    this.speed,
    this.error,
    this.isCompleted = false,
    this.state = DownloadState.queued,
  }) : timestamp = DateTime.now();

  factory DownloadProgress.initial(String taskId) =>
      DownloadProgress._internal(taskId: taskId);

  factory DownloadProgress.running(
          String taskId, double progress, double speed) =>
      DownloadProgress._internal(
        taskId: taskId,
        progress: progress.clamp(0.0, 1.0),
        speed: speed,
      );

  factory DownloadProgress.complete(String taskId) =>
      DownloadProgress._internal(
        taskId: taskId,
        progress: 1.0,
        isCompleted: true,
      );

  factory DownloadProgress.error(String taskId, DownloadError error) =>
      DownloadProgress._internal(
        taskId: taskId,
        error: error,
      );

  // 新增暂停状态工厂方法
  factory DownloadProgress.paused(String taskId) => DownloadProgress._internal(
        taskId: taskId,
        progress: -1,
        state: DownloadState.paused,
      );
}

// 下载错误实体类
class DownloadError implements Exception {
  final String message;
  final StackTrace stackTrace;
  final DateTime occurrenceTime;

  DownloadError(this.message, [this.stackTrace = StackTrace.empty])
      : occurrenceTime = DateTime.now();

  @override
  String toString() => 'DownloadError: $message\n$stackTrace';
}
