import 'dart:async';

import 'download_pool.dart';
import 'download_status.dart';
import 'download_task.dart';

class DownloadManager {
  /// The pool that manages all download threads.
  late DownloadPool _downloadPool;

  /// Constructs a [DownloadManager] with an optional maximum number of concurrent downloads.
  DownloadManager([int maxConcurrentDownloads = MAX_POOL_SIZE]) {
    _downloadPool = DownloadPool(poolSize: maxConcurrentDownloads);
  }

  /// Provides a stream of [DownloadTask] updates for listeners.
  Stream<DownloadTask> get stream => _downloadPool.streamController.stream;

  /// Returns all download tasks currently managed.
  List<DownloadTask> get allTasks => _downloadPool.taskList;

  /// Returns all downloading tasks.
  List<DownloadTask> get downloadingTasks => _downloadPool.downloadingTasks;

  /// Adds a new [DownloadTask] to the pool.
  Future<DownloadTask> addTask(DownloadTask task) {
    return _downloadPool.addTask(task);
  }

  /// Executes a [DownloadTask], scheduling it for download.
  Future<DownloadTask> executeTask(DownloadTask task) {
    return _downloadPool.executeTask(task);
  }

  /// Triggers the pool to schedule and run tasks.
  Future<void> roundTask() {
    return _downloadPool.roundTask();
  }

  /// Pauses a task by its [taskId].
  void pauseTaskById(String taskId) {
    _downloadPool.updateTaskById(taskId, DownloadStatus.PAUSED);
  }

  /// Resumes a task by its [taskId].
  void resumeTaskById(String taskId) {
    _downloadPool.updateTaskById(taskId, DownloadStatus.DOWNLOADING);
  }

  /// Cancels a task by its [taskId].
  void cancelTaskById(String taskId) {
    _downloadPool.updateTaskById(taskId, DownloadStatus.CANCELLED);
    allTasks.removeWhere((task) => task.id == taskId);
  }

  /// Pauses a task by its URL.
  void pauseTaskByUrl(String url) {
    _downloadPool.updateTaskByUrl(url, DownloadStatus.PAUSED);
  }

  /// Resumes a task by its URL.
  void resumeTaskByUrl(String url) {
    _downloadPool.updateTaskByUrl(url, DownloadStatus.DOWNLOADING);
  }

  /// Cancels a task by its URL and removes it from the task list.
  void cancelTaskByUrl(String url) {
    _downloadPool.updateTaskByUrl(url, DownloadStatus.CANCELLED);
    allTasks.removeWhere((task) => task.url == url);
  }

  /// Pauses all downloading tasks.
  void pauseAllTasks() {
    downloadingTasks.forEach((task) {
      pauseTaskById(task.id);
    });
  }

  /// Cancels and removes all tasks from the manager.
  void removeAllTask() {
    pauseAllTasks();
    allTasks.clear();
  }
}
