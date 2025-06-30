import 'download_isolate_pool.dart';
import 'download_status.dart';
import 'download_task.dart';

/// Manages the lifecycle and orchestration of download isolates.
/// This class is responsible for initializing, tracking, and disposing
/// download isolates, as well as delegating download tasks.
class DownloadManager {
  /// The pool that manages all download isolates.
  late DownloadIsolatePool _isolatePool;

  /// Constructs a [DownloadIsolateManager] with an optional maximum number of concurrent downloads.
  DownloadManager([int maxConcurrentDownloads = MAX_ISOLATE_POOL_SIZE]) {
    _isolatePool = DownloadIsolatePool(poolSize: maxConcurrentDownloads);
  }

  /// Provides a stream of [DownloadTask] updates for listeners.
  Stream<DownloadTask> get stream => _isolatePool.streamController.stream;

  /// Returns all download tasks currently managed.
  List<DownloadTask> get allTasks => _isolatePool.taskList;

  /// Returns all active (downloading) tasks.
  List<DownloadTask> get activeTasks => _isolatePool.taskList
      .where((task) => task.status == DownloadStatus.DOWNLOADING)
      .toList();

  /// Returns the configured pool size.
  int get poolSize => _isolatePool.poolSize;

  /// Returns the current number of isolates in the pool.
  int get isolateSize => _isolatePool.isolateList.length;

  /// Adds a new [DownloadTask] to the pool.
  Future<DownloadTask> addTask(DownloadTask task) {
    return _isolatePool.addTask(task);
  }

  /// Executes a [DownloadTask], scheduling it for download.
  Future<DownloadTask> executeTask(DownloadTask task) {
    return _isolatePool.executeTask(task);
  }

  /// Triggers the isolate pool to schedule and run tasks.
  Future<void> roundIsolate() {
    return _isolatePool.roundIsolate();
  }

  /// Pauses a task by its [taskId].
  void pauseTaskById(String taskId) {
    _isolatePool.notifyIsolate(taskId, DownloadStatus.PAUSED);
  }

  /// Resumes a task by its [taskId].
  void resumeTaskById(String taskId) {
    _isolatePool.notifyIsolate(taskId, DownloadStatus.DOWNLOADING);
  }

  /// Cancels a task by its [taskId].
  void cancelTaskById(String taskId) {
    _isolatePool.notifyIsolate(taskId, DownloadStatus.CANCELLED);
  }

  /// Pauses a task by its URL.
  void pauseTaskByUrl(String url) {
    String? taskId =
        activeTasks.where((task) => task.url == url).firstOrNull?.id;
    if (taskId != null) {
      _isolatePool.notifyIsolate(taskId, DownloadStatus.PAUSED);
    }
  }

  /// Resumes a task by its URL.
  void resumeTaskByUrl(String url) {
    String? taskId =
        activeTasks.where((task) => task.url == url).firstOrNull?.id;
    if (taskId != null) {
      _isolatePool.notifyIsolate(taskId, DownloadStatus.DOWNLOADING);
    }
  }

  /// Cancels a task by its URL and removes it from the task list.
  void cancelTaskByUrl(String url) {
    String? taskId =
        activeTasks.where((task) => task.url == url).firstOrNull?.id;
    if (taskId != null) {
      _isolatePool.notifyIsolate(taskId, DownloadStatus.CANCELLED);
    }
    allTasks.removeWhere((task) => task.url == url);
  }

  /// Pauses all active tasks.
  void pauseAllTasks() {
    for (var isolate in _isolatePool.isolateList) {
      String? taskId = isolate.task?.id;
      if (taskId != null) {
        _isolatePool.notifyIsolate(taskId, DownloadStatus.PAUSED);
      }
    }
  }

  /// Cancels and removes all tasks from the manager.
  void removeAllTask() {
    for (var isolate in _isolatePool.isolateList) {
      String? taskId = isolate.task?.id;
      if (taskId != null) {
        _isolatePool.notifyIsolate(taskId, DownloadStatus.CANCELLED);
        isolate.reset();
      }
    }
    allTasks.clear();
  }

  /// Checks if a task with the given match URL exists.
  bool isMatchUrlExit(String url) {
    return allTasks.where((task) => task.matchUrl == url).isNotEmpty;
  }

  /// Checks if a task with the given URL exists.
  bool isUrlExit(String url) {
    return allTasks.where((task) => task.uri.toString() == url).isNotEmpty;
  }

  /// Checks if a task with the given URL is currently downloading.
  bool isUrlDownloading(String url) {
    return activeTasks.where((task) => task.uri.toString() == url).isNotEmpty;
  }

  /// Disposes the manager and releases all resources.
  void dispose() {
    _isolatePool.dispose();
  }
}
