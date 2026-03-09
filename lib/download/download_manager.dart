import 'dart:async';

import '../ext/string_ext.dart';
import 'download_pool.dart';
import 'download_status.dart';
import 'download_task.dart';

/// A manager class that handles download tasks using a [DownloadPool].
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
  }

  /// Pauses all tasks about the given URL, including tasks that match the URL's MD5 hash.
  void pauseTaskAboutUrl(String url) {
    for (var task in downloadingTasks) {
      if (task.url == url) {
        pauseTaskById(task.id);
      } else if (task.hlsKey == task.url.generateMd5) {
        pauseTaskById(task.id);
      }
    }
  }

  /// Cancel all tasks about the given URL, including tasks that match the URL's MD5 hash.
  void cancelTaskAboutUrl(String url) {
    List<String> taskIdsToCancel = [];
    for (var task in allTasks) {
      if (task.url == url) {
        pauseTaskById(task.id);
        taskIdsToCancel.add(task.id);
      } else if (task.hlsKey == task.url.generateMd5) {
        pauseTaskById(task.id);
        taskIdsToCancel.add(task.id);
      }
    }
    allTasks.removeWhere((task) => taskIdsToCancel.contains(task.id));
  }

  /// Pauses all downloading tasks.
  void pauseAllTasks() {
    downloadingTasks.forEach((task) {
      pauseTaskById(task.id);
    });
  }

  /// Cancels and removes all tasks from the manager.
  void cancelAllTask() {
    pauseAllTasks();
    allTasks.clear();
  }

  /// Checks if a task with the given URL exists.
  bool isTaskExit(DownloadTask task) {
    return allTasks.where((t) => t.matchUrl == task.matchUrl).isNotEmpty;
  }

  /// Checks if a task with the given URL is currently downloading.
  bool isUrlDownloading(DownloadTask task) {
    return downloadingTasks
        .where((t) => t.matchUrl == task.matchUrl)
        .isNotEmpty;
  }

  /// Disposes of the download manager
  void dispose() {
    _downloadPool.dispose();
  }
}
