import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../ext/file_ext.dart';
import '../ext/log_ext.dart';
import '../memory/video_memory_cache.dart';
import 'download_isolate_entry.dart';
import 'download_isolate_instance.dart';
import 'download_isolate_msg.dart';
import 'download_status.dart';
import 'download_task.dart';

const int MAX_ISOLATE_POOL_SIZE = 1;
const int MAX_TASK_PRIORITY = 9999;

/// DownloadIsolatePool manages a pool of isolates for downloading tasks.
class DownloadIsolatePool {
  /// List of isolates in the pool.
  final List<DownloadIsolateInstance> _isolateList = [];

  /// List of tasks in the pool.
  final List<DownloadTask> _taskList = [];

  /// The maximum number of isolates in the pool.
  final int _poolSize;

  DownloadIsolatePool({int poolSize = MAX_ISOLATE_POOL_SIZE})
      : _poolSize = poolSize;

  /// Stream controller for broadcasting download task updates.
  final StreamController<DownloadTask> _streamController =
      StreamController.broadcast();

  StreamController<DownloadTask> get streamController => _streamController;

  List<DownloadTask> get taskList => _taskList;

  List<DownloadTask> get prepareTasks => _taskList
      .where((task) => task.status != DownloadStatus.DOWNLOADING)
      .toList();

  Future<void> dispose() async {
    for (var isolate in _isolateList) {
      await isolate.subscription?.cancel();
      isolate.controlPort?.send(DownloadIsolateMsg(
        IsolateMsgType.task,
        isolate.task?..status = DownloadStatus.CANCELLED,
      ));
      isolate.receivePort.close();
      isolate.isolate.kill(priority: Isolate.immediate);
    }
    await _streamController.close();
    DownloadTask.resetId();
  }

  DownloadTask? findTaskById(String taskId) =>
      _taskList.where((task) => task.id == taskId).firstOrNull;

  DownloadIsolateInstance? findIsolateByTaskId(String taskId) =>
      _isolateList.where((isolate) => isolate.task?.id == taskId).firstOrNull;

  void notifyIsolate(String taskId, DownloadStatus message) {
    DownloadIsolateInstance? isolate = findIsolateByTaskId(taskId);
    logV('[DownloadIsolatePool] notifyIsolate: ${isolate.toString()} $message');
    if (isolate == null && message == DownloadStatus.DOWNLOADING) {
      final task = findTaskById(taskId);
      if (task == null) return;
      resumeTask(task);
    } else {
      isolate?.task?.status = message;
      isolate?.controlPort?.send(DownloadIsolateMsg(
        IsolateMsgType.task,
        isolate.task,
      ));
    }
  }

  Future<DownloadTask> addTask(DownloadTask task) async {
    logV('[DownloadIsolatePool] addTask: ${task.toString()}');
    if (task.cacheDir.isEmpty) {
      String cachePath = await FileExt.createCachePath();
      task.cacheDir = cachePath;
    }
    task.saveFile = task.saveFile;
    _taskList.add(task);
    return task;
  }

  Future<DownloadTask> executeTask(DownloadTask task) async {
    DownloadTask? existTask =
        _taskList.where((e) => e.matchUrl == task.matchUrl).firstOrNull;
    if (existTask != null && existTask.priority < task.priority) {
      _taskList.removeWhere((e) => e.matchUrl == task.matchUrl);
      await addTask(task);
    } else if (existTask == null) {
      await addTask(task);
    }
    await roundIsolate();
    return task;
  }

  Future<DownloadTask> resumeTask(DownloadTask task) async {
    await _resumeIsolateWithTask(task);
    return task;
  }

  Future<void> roundIsolate() async {
    if (_taskList.isEmpty) return;
    await _runIsolateWithTask();
  }

  Future<void> _runIsolateWithTask() async {
    _taskList.sort((a, b) => b.priority - a.priority);

    // Check if there are idle isolate instances
    List<DownloadIsolateInstance> isolatePool =
        _isolateList.where((isolate) => !isolate.isBusy).toList();
    if (isolatePool.isNotEmpty) {
      for (int i = 0; i < isolatePool.length; i++) {
        final tasks = prepareTasks;
        if (i >= tasks.length) break;
        await _bindingIsolate(isolatePool[i], tasks[i]);
      }
    }

    // Check whether the maximum number of isolated instance pools has been reached
    final tasks = prepareTasks;
    if (tasks.isNotEmpty && _isolateList.length < _poolSize) {
      for (int i = 0; i < tasks.length; i++) {
        DownloadIsolateInstance isolate = await _createIsolate();
        await _bindingIsolate(isolate, tasks[i]);
        if (_isolateList.length >= _poolSize) break;
      }
    }

    // Check if there is an isolated instance being downloaded with a lower priority
    for (DownloadTask task in prepareTasks) {
      List<DownloadIsolateInstance> busyIsolate =
          _isolateList.where((isolate) => isolate.isBusy).toList();
      DownloadIsolateInstance? minPriorityIsolate;
      for (DownloadIsolateInstance isolate in busyIsolate) {
        int currentTaskPriority = isolate.task?.priority ?? 0;
        int minPriority =
            minPriorityIsolate?.task?.priority ?? MAX_TASK_PRIORITY;
        if (currentTaskPriority < minPriority) {
          minPriorityIsolate = isolate;
        }
      }
      int minPriority = minPriorityIsolate?.task?.priority ?? 0;
      if (minPriority < task.priority) {
        minPriorityIsolate?.task?.status = DownloadStatus.PAUSED;
        minPriorityIsolate?.controlPort?.send(DownloadIsolateMsg(
          IsolateMsgType.task,
          minPriorityIsolate.task,
        ));
        minPriorityIsolate?.reset();
        if (minPriorityIsolate != null) {
          await _bindingIsolate(minPriorityIsolate, task);
        }
      }
    }
  }

  Future<void> _resumeIsolateWithTask(DownloadTask task) async {
    if (_isolateList.length < _poolSize) {
      DownloadIsolateInstance isolate = await _createIsolate();
      await _bindingIsolate(isolate, task);
      return;
    }

    final idleIsolate = _isolateList
        .where((isolate) =>
            isolate.task == null ||
            isolate.task?.status != DownloadStatus.DOWNLOADING)
        .toList();
    if (idleIsolate.isNotEmpty) {
      await _bindingIsolate(idleIsolate[0], task);
      return;
    }

    DownloadIsolateInstance? minPriorityIsolate;
    for (DownloadIsolateInstance isolate in _isolateList) {
      int currentTaskPriority = isolate.task?.priority ?? 0;
      int minPriority = minPriorityIsolate?.task?.priority ?? MAX_TASK_PRIORITY;
      if (currentTaskPriority < minPriority) {
        minPriorityIsolate = isolate;
      }
    }
    minPriorityIsolate?.task?.status = DownloadStatus.PAUSED;
    minPriorityIsolate?.controlPort?.send(DownloadIsolateMsg(
      IsolateMsgType.task,
      minPriorityIsolate.task,
    ));
    minPriorityIsolate?.reset();
    if (minPriorityIsolate != null) {
      await _bindingIsolate(minPriorityIsolate, task);
    }
  }

  Future<DownloadIsolateInstance> _createIsolate() async {
    final mainReceivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      downloadIsolateEntry,
      mainReceivePort.sendPort,
    );
    final isolateInstance = DownloadIsolateInstance(
      isolate: isolate,
      receivePort: mainReceivePort,
      subscription: mainReceivePort.listen(null),
    );
    _isolateList.add(isolateInstance);
    return isolateInstance;
  }

  Future<void> _bindingIsolate(
    DownloadIsolateInstance isolate,
    DownloadTask task,
  ) async {
    logV('[DownloadIsolatePool] bindingIsolate ${task.id}');
    task.status = DownloadStatus.DOWNLOADING;
    isolate.bindTask(task);
    isolate.subscription?.onData((message) {
      // logV('[DownloadIsolatePool] isolateListener ${message.toString()}');
      if (message is DownloadIsolateMsg) {
        switch (message.type) {
          case IsolateMsgType.sendPort:
            if (isolate.task == null) return;
            isolate.task!.status = DownloadStatus.DOWNLOADING;
            isolate.controlPort = message.data as SendPort;
            isolate.controlPort!.send(DownloadIsolateMsg(
              IsolateMsgType.task,
              isolate.task,
            ));
            break;
          case IsolateMsgType.task:
            final task = message.data as DownloadTask;
            isolate.task = task;
            int taskIndex = _taskList.indexWhere((t) => t.id == task.id);
            if (taskIndex != -1) _taskList[taskIndex] = task;
            int isolateIndex =
                _isolateList.indexWhere((i) => i.task?.id == task.id);
            if (isolateIndex != -1) _isolateList[isolateIndex] = isolate;
            if (task.status == DownloadStatus.COMPLETED) {
              Uint8List netData = Uint8List.fromList(task.data);
              VideoMemoryCache.put(task.matchUrl, netData);
              if (taskIndex != -1) _taskList.removeAt(taskIndex);
              if (isolateIndex != -1) _isolateList[isolateIndex].reset();
            }
            if (task.status == DownloadStatus.FAILED) {
              if (taskIndex != -1) _taskList.removeAt(taskIndex);
              if (isolateIndex != -1) _isolateList[isolateIndex].reset();
            }
            if (task.status == DownloadStatus.FINISHED ||
                task.status == DownloadStatus.FAILED) {
              roundIsolate();
            }
            _streamController.sink.add(task);
            break;
        }
      }
    });
    isolate.controlPort?.send(DownloadIsolateMsg(IsolateMsgType.task, task));
  }
}
