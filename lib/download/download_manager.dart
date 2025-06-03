import 'download_isolate_pool.dart';
import 'download_status.dart';
import 'download_task.dart';

class DownloadManager {
  late DownloadIsolatePool _isolatePool;

  DownloadManager([int maxConcurrentDownloads = MAX_ISOLATE_POOL_SIZE]) {
    _isolatePool = DownloadIsolatePool(poolSize: maxConcurrentDownloads);
  }

  Stream<DownloadTask> get stream => _isolatePool.streamController.stream;

  List<DownloadTask> get allTasks => _isolatePool.taskList;

  List<DownloadTask> get activeTasks => _isolatePool.taskList
      .where((task) => task.status == DownloadStatus.DOWNLOADING)
      .toList();

  Future<DownloadTask> addTask(DownloadTask task) {
    return _isolatePool.addTask(task);
  }

  Future<DownloadTask> executeTask(DownloadTask task) {
    return _isolatePool.executeTask(task);
  }

  Future<void> roundIsolate() {
    return _isolatePool.roundIsolate();
  }

  void pauseTaskById(String taskId) {
    _isolatePool.notifyIsolate(taskId, DownloadStatus.PAUSED);
  }

  void resumeTaskById(String taskId) {
    _isolatePool.notifyIsolate(taskId, DownloadStatus.DOWNLOADING);
  }

  void cancelTaskById(String taskId) {
    _isolatePool.notifyIsolate(taskId, DownloadStatus.CANCELLED);
  }

  void pauseTaskByUrl(String url) {
    String? taskId =
        activeTasks.where((task) => task.url == url).firstOrNull?.id;
    if (taskId != null) {
      _isolatePool.notifyIsolate(taskId, DownloadStatus.PAUSED);
    }
  }

  void resumeTaskByUrl(String url) {
    String? taskId =
        activeTasks.where((task) => task.url == url).firstOrNull?.id;
    if (taskId != null) {
      _isolatePool.notifyIsolate(taskId, DownloadStatus.DOWNLOADING);
    }
  }

  void cancelTaskByUrl(String url) {
    String? taskId =
        activeTasks.where((task) => task.url == url).firstOrNull?.id;
    if (taskId != null) {
      _isolatePool.notifyIsolate(taskId, DownloadStatus.CANCELLED);
    }
    allTasks.removeWhere((task) => task.url == url);
  }

  void pauseAllTasks() {
    for (var isolate in _isolatePool.isolateList) {
      String? taskId = isolate.task?.id;
      if (taskId != null) {
        _isolatePool.notifyIsolate(taskId, DownloadStatus.PAUSED);
      }
    }
  }

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

  bool isMatchUrlExit(String url) {
    return allTasks.where((task) => task.matchUrl == url).isNotEmpty;
  }

  bool isUrlExit(String url) {
    return allTasks.where((task) => task.uri.toString() == url).isNotEmpty;
  }

  bool isUrlDownloading(String url) {
    return activeTasks.where((task) => task.uri.toString() == url).isNotEmpty;
  }

  void dispose() {
    _isolatePool.dispose();
  }
}
