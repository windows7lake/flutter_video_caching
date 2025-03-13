import 'dart:collection';
import 'dart:io';

import 'download_isolate_manager.dart';
import 'download_task.dart';

// 线程池类
class ThreadPool {
  final int poolSize;
  final Queue<DownloadTask> taskQueue = Queue<DownloadTask>();
  final List<DownloadTask> activeTasks = [];

  ThreadPool({int? maxDownloads})
      : poolSize = maxDownloads ?? Platform.numberOfProcessors;

  void addTask(DownloadTask task, Function(String) onCompleted,
      Function(String, double) onProgressUpdate) {
    taskQueue.add(task);
    final taskList = taskQueue.toList();
    taskList.sort((a, b) => b.priority - a.priority);
    taskQueue.clear();
    taskQueue.addAll(taskList);
    _processQueue(onCompleted, onProgressUpdate);
  }

  void _processQueue(
      Function(String) onCompleted, Function(String, double) onProgressUpdate) {
    while (activeTasks.length < poolSize && taskQueue.isNotEmpty) {
      final task = taskQueue.removeFirst();
      activeTasks.add(task);
      task.start();
      DownloadIsolateManager.startDownload(
        task,
        (taskId) {
          activeTasks.remove(task);
          onCompleted(taskId);
          _processQueue(onCompleted, onProgressUpdate);
        },
        (taskId, progress) {
          onProgressUpdate(taskId, progress);
        },
      );
    }
  }

  void pauseTaskById(String taskId, Function(String) onCompleted,
      Function(String, int) onProgressUpdate) {
    final task =
        [...taskQueue, ...activeTasks].where((t) => t.id == taskId).firstOrNull;
    if (task != null) {
      task.pause();
    }
  }

  void resumeTaskById(String taskId, Function(String) onCompleted,
      Function(String, double) onProgressUpdate) {
    final task =
        [...taskQueue, ...activeTasks].where((t) => t.id == taskId).firstOrNull;
    if (task != null) {
      task.resume();
      if (task.status == DownloadTaskStatus.PAUSED) {
        taskQueue.remove(task);
        final taskList = taskQueue.toList();
        taskList.add(task);
        taskList.sort((a, b) => b.priority - a.priority);
        taskQueue.clear();
        taskQueue.addAll(taskList);
        _processQueue(onCompleted, onProgressUpdate);
      }
    }
  }

  void cancelTaskById(String taskId) {
    final task =
        [...taskQueue, ...activeTasks].where((t) => t.id == taskId).firstOrNull;
    if (task != null) {
      task.cancel();
      activeTasks.remove(task);
      taskQueue.remove(task);
    }
  }

  List<DownloadTask> get allTasks => [...taskQueue, ...activeTasks];
}
