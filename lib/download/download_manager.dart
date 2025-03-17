import 'download_task.dart';
import 'isolate_manager.dart';

// 下载管理类
class DownloadManager {
  late IsolateManager _isolateManager;

  DownloadManager({int? maxConcurrentDownloads}) {
    _isolateManager = IsolateManager(poolSize: maxConcurrentDownloads);
  }

  List<DownloadTask> get allTasks => _isolateManager.taskList;

  List<DownloadTask> get activeTasks => _isolateManager.taskList
      .where((task) => task.status == DownloadTaskStatus.DOWNLOADING)
      .toList();

  Future addTask(DownloadTask task) {
    return _isolateManager.addTask(task);
  }

  Future processTask({Function(DownloadTask)? onProgressUpdate}) {
    return _isolateManager.processTask(onProgressUpdate: onProgressUpdate);
  }

  void pauseTaskById(String taskId) {
    _isolateManager.notifyIsolate(taskId, DownloadTaskStatus.PAUSED);
  }

  void resumeTaskById(String taskId) {
    _isolateManager.notifyIsolate(taskId, DownloadTaskStatus.DOWNLOADING);
  }

  void cancelTaskById(String taskId) {
    _isolateManager.notifyIsolate(taskId, DownloadTaskStatus.CANCELLED);
  }
}
