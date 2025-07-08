import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:synchronized/synchronized.dart';

import '../cache/lru_cache_singleton.dart';
import '../ext/file_ext.dart';
import '../ext/gesture_ext.dart';
import '../ext/log_ext.dart';
import '../global/config.dart';
import '../proxy/video_proxy.dart';
import 'download_isolate_entry.dart';
import 'download_isolate_instance.dart';
import 'download_isolate_msg.dart';
import 'download_status.dart';
import 'download_task.dart';

/// The maximum number of isolates allowed in the pool.
const int MAX_ISOLATE_POOL_SIZE = 1;

/// The maximum task priority value.
const int MAX_TASK_PRIORITY = 9999;

/// Manages a pool of isolates for handling concurrent download tasks.
/// Responsible for task scheduling, isolate creation, task binding, and
/// communication between the main isolate and download isolates.
class DownloadIsolatePool {
  /// Lock for synchronizing access to the pool to ensure thread safety.
  final Lock _lock = Lock();

  /// List of all isolate instances managed by the pool.
  final List<DownloadIsolateInstance> _isolateList = [];

  /// List of all download tasks managed by the pool.
  final List<DownloadTask> _taskList = [];

  /// The maximum number of isolates allowed in the pool.
  final int _poolSize;

  /// Stream controller for broadcasting download task updates to listeners.
  late final StreamController<DownloadTask> _streamController;

  /// Constructs a [DownloadIsolatePool] with the specified [poolSize].
  /// Throws an [ArgumentError] if the pool size is less than or equal to zero.
  DownloadIsolatePool({int poolSize = MAX_ISOLATE_POOL_SIZE})
      : _poolSize = poolSize {
    if (_poolSize <= 0) {
      throw ArgumentError('Pool size must be greater than 0');
    }
    _streamController = StreamController.broadcast();
  }

  /// Returns the stream controller for task updates.
  StreamController<DownloadTask> get streamController => _streamController;

  /// Returns the list of all tasks in the pool.
  List<DownloadTask> get taskList => _taskList;

  /// Returns the list of tasks that are not currently downloading.
  List<DownloadTask> get prepareTasks => _taskList
      .where((task) => task.status != DownloadStatus.DOWNLOADING)
      .toList();

  /// Returns the list of all isolate instances in the pool.
  List<DownloadIsolateInstance> get isolateList => _isolateList;

  /// Returns the maximum number of isolates in the pool.
  int get poolSize => _poolSize;

  /// Disposes the pool, cancels all subscriptions, kills all isolates,
  /// closes ports and the stream controller, and resets task IDs.
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
    _isolateList.clear();
    _taskList.clear();
    await _streamController.close();
    DownloadTask.resetId();
  }

  /// Finds a task in the pool by its [taskId].
  DownloadTask? findTaskById(String taskId) =>
      _taskList.where((task) => task.id == taskId).firstOrNull;

  /// Finds an isolate instance by the associated task's [taskId].
  DownloadIsolateInstance? findIsolateByTaskId(String taskId) =>
      _isolateList.where((isolate) => isolate.task?.id == taskId).firstOrNull;

  /// Notifies the isolate associated with [taskId] to update its status to [message].
  /// If the isolate is not found and the message is to start downloading, resumes the task.
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

  /// Adds a new [task] to the pool, creating a cache directory if needed.
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

  /// Executes a [task], replacing any existing lower-priority task with the same cache key.
  /// Schedules the isolate pool for task execution.
  Future<DownloadTask> executeTask(DownloadTask task) async {
    DownloadTask? existTask =
        _taskList.where((e) => e.matchUrl == task.matchUrl).firstOrNull;
    if (existTask != null && existTask.priority < task.priority) {
      _taskList.removeWhere((e) => e.matchUrl == task.matchUrl);
      await addTask(task);
    } else if (existTask == null) {
      await addTask(task);
    }
    FunctionProxy.debounce(roundIsolate);
    return task;
  }

  /// Resumes a paused or new [task] by binding it to an available isolate.
  Future<DownloadTask> resumeTask(DownloadTask task) async {
    await _resumeIsolateWithTask(task);
    return task;
  }

  /// Schedules the pool to run tasks, ensuring only one thread runs this logic at a time.
  Future<void> roundIsolate() async {
    await _lock.synchronized(() async {
      if (_taskList.isEmpty) return;
      await _runIsolateWithTask();
    });
  }

  /// Internal method to assign tasks to available isolates, create new isolates if needed,
  /// and handle task preemption based on priority.
  Future<void> _runIsolateWithTask() async {
    _taskList.sort((a, b) => b.priority - a.priority);

    // Assign tasks to idle isolates
    List<DownloadIsolateInstance> isolatePool =
        _isolateList.where((isolate) => !isolate.isBusy).toList();
    if (isolatePool.isNotEmpty) {
      for (int i = 0; i < isolatePool.length; i++) {
        final tasks = prepareTasks;
        if (i >= tasks.length) break;
        await _bindingIsolate(isolatePool[i], tasks[i]);
      }
    }

    // Create new isolates if pool size allows and assign tasks
    final tasks = prepareTasks;
    if (tasks.isNotEmpty && _isolateList.length < _poolSize) {
      for (int i = 0; i < tasks.length; i++) {
        DownloadIsolateInstance isolate = await _createIsolate();
        await _bindingIsolate(isolate, tasks[i]);
        if (_isolateList.length >= _poolSize) break;
      }
    }

    // Preempt lower-priority tasks if higher-priority tasks are waiting
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
        await Future.delayed(const Duration(milliseconds: 500));
        minPriorityIsolate?.reset();
        if (minPriorityIsolate != null) {
          await _bindingIsolate(minPriorityIsolate, task);
        }
      }
    }
  }

  /// Binds a [task] to an available isolate, or preempts a lower-priority task if needed.
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
  }

  /// Creates a new isolate for downloading and adds it to the pool.
  /// Returns the created [DownloadIsolateInstance].
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

  /// Binds a [task] to the given [isolate], sets up message handling,
  /// and starts the download process in the isolate.
  Future<void> _bindingIsolate(
    DownloadIsolateInstance isolate,
    DownloadTask task,
  ) async {
    logV('[DownloadIsolatePool] bindingIsolate ${task.id}');
    task.status = DownloadStatus.DOWNLOADING;
    isolate.bindTask(task);
    isolate.subscription?.onData((message) {
      // Handles messages from the isolate, including status updates and file caching.
      if (message is DownloadIsolateMsg) {
        switch (message.type) {
          case IsolateMsgType.sendPort:
            if (isolate.task == null) return;
            isolate.task!.status = DownloadStatus.DOWNLOADING;
            isolate.controlPort = message.data as SendPort;
            isolate.controlPort!.send(DownloadIsolateMsg(
              IsolateMsgType.logPrint,
              Config.logPrint,
            ));
            isolate.controlPort!.send(DownloadIsolateMsg(
              IsolateMsgType.httpClient,
              VideoProxy.httpClientBuilderImpl,
            ));
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
              LruCacheSingleton().memoryPut(task.matchUrl, netData);
              if (taskIndex != -1) _taskList.removeAt(taskIndex);
              if (isolateIndex != -1) _isolateList[isolateIndex].reset();
            }
            if (task.status == DownloadStatus.FINISHED && task.file != null) {
              LruCacheSingleton().storagePut(task.matchUrl, task.file!);
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
          default:
            break;
        }
      }
    });
    // Prepares the file path for the isolate to use for saving the download.
    task.isolateSavePath = '${task.cacheDir}/${task.saveFileName}';
    isolate.controlPort?.send(DownloadIsolateMsg(IsolateMsgType.task, task));
  }
}
