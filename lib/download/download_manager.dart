import 'dart:async';

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

  Stream<DownloadTask> get stream => _isolateManager.streamController.stream;

  Future<DownloadTask> addTask(DownloadTask task) {
    return _isolateManager.addTask(task);
  }

  Future<DownloadTask> executeTask(DownloadTask task) {
    return _isolateManager.executeTask(task);
  }

  Future processTask() {
    return _isolateManager.processTask();
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
