import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:log_wrapper/log/log.dart';
import 'package:path_provider/path_provider.dart';

import 'download_task.dart';
import 'isolate_download.dart';
import 'isolate_instance.dart';

/// Isolate池的最大个数
const int MAX_POOL_SIZE = 1;

class IsolateManager {
  final StreamController<DownloadTask> _streamController =
      StreamController.broadcast();
  final List<IsolateInstance> _isolatePool = [];
  final List<DownloadTask> _taskList = [];
  int _poolSize = 0;
  String cacheDir = '';

  IsolateManager({int? poolSize}) {
    _poolSize = poolSize ?? MAX_POOL_SIZE;
  }

  StreamController<DownloadTask> get streamController => _streamController;

  List<DownloadTask> get taskList => _taskList;

  /// 根据任务ID查找隔离实例
  IsolateInstance? finaIsolateByTaskId(String taskId) =>
      _isolatePool.where((isolate) => isolate.task?.id == taskId).firstOrNull;

  /// 发送消息通知隔离实例
  void notifyIsolate(String taskId, DownloadTaskStatus message) {
    IsolateInstance? isolateInstance = finaIsolateByTaskId(taskId);
    isolateInstance?.controlPort?.send(message);
    logD("Task ${isolateInstance?.task?.id} notifyIsolate: $message");
  }

  /// 切换任务
  void switchTasks() {
    int nowTime = DateTime.now().millisecondsSinceEpoch;
    _taskList.removeWhere((e) => (nowTime - e.createAt).abs() > 1500);
    _isolatePool.forEach((isolate) {
      int createAt = isolate.task?.createAt ?? 0;
      if ((nowTime - createAt).abs() > 1500) {
        isolate.task?.status = DownloadTaskStatus.PAUSED;
        isolate.controlPort?.send(DownloadTaskStatus.PAUSED);
        isolate.isBusy = false;
        isolate.reset();
      }
    });
  }

  /// 重置所有隔离实例
  void resetAllIsolate() {
    _isolatePool.forEach((isolate) {
      isolate.task?.status = DownloadTaskStatus.PAUSED;
      isolate.controlPort?.send(DownloadTaskStatus.PAUSED);
      isolate.isBusy = false;
      isolate.reset();
    });
  }

  /// 添加任务，不会立即执行
  Future<DownloadTask> addTask(DownloadTask task) async {
    if (cacheDir.isEmpty) {
      final appDir = await getApplicationCacheDirectory();
      cacheDir = appDir.path + '/videos';
    }
    if (!Directory(cacheDir).existsSync()) {
      Directory(cacheDir).createSync(recursive: true);
    }
    task.saveFile = '$cacheDir/${task.saveFile}';
    _taskList.add(task);
    return task;
  }

  /// 添加并立即执行任务（根据任务优先级，如果当前有更高优先级的任务在执行，则会优先执行高优先级任务）
  Future<DownloadTask> executeTask(DownloadTask task) async {
    DownloadTask _task = await addTask(task);
    processTask();
    return _task;
  }

  /// 处理任务
  Future processTask() async {
    _taskList.sort((a, b) => b.priority - a.priority);

    // 检查是否有正在下载的隔离实例且优先级较低
    List<DownloadTask> taskPool1 = _taskList
        .where((task) => task.status != DownloadTaskStatus.DOWNLOADING)
        .toList();
    for (var _task in taskPool1) {
      List<IsolateInstance> busyIsolate =
          _isolatePool.where((isolate) => isolate.isBusy).toList();
      IsolateInstance? minPriorityIsolate;
      for (IsolateInstance isolate in busyIsolate) {
        int currentTaskPriority = isolate.task?.priority ?? 0;
        int minPriority = minPriorityIsolate?.task?.priority ?? 9999;
        if (currentTaskPriority < minPriority) {
          minPriorityIsolate = isolate;
        }
      }
      int minPriority = minPriorityIsolate?.task?.priority ?? 0;
      if (minPriority < _task.priority) {
        minPriorityIsolate?.task?.status = DownloadTaskStatus.PAUSED;
        minPriorityIsolate?.controlPort?.send(DownloadTaskStatus.PAUSED);
        minPriorityIsolate?.reset();
        if (minPriorityIsolate != null) {
          _task.status = DownloadTaskStatus.DOWNLOADING;
          await _attackToIsolate(minPriorityIsolate, _task);
        }
      }
    }

    // 检查是否有空闲的隔离实例
    List<DownloadTask> taskPool2 = _taskList
        .where((task) => task.status != DownloadTaskStatus.DOWNLOADING)
        .toList();
    List<IsolateInstance> isolatePool =
        _isolatePool.where((isolate) => !isolate.isBusy).toList();
    if (isolatePool.isNotEmpty) {
      for (int i = 0; i < isolatePool.length; i++) {
        if (i >= taskPool2.length) break;
        await _attackToIsolate(isolatePool[i], taskPool2[i]);
      }
    }

    // 检查是否达到隔离实例池的最大个数
    List<DownloadTask> taskPool3 = _taskList
        .where((task) => task.status != DownloadTaskStatus.DOWNLOADING)
        .toList();
    if (taskPool3.isNotEmpty && _isolatePool.length < _poolSize) {
      for (int i = 0; i < taskPool3.length; i++) {
        IsolateInstance isolate = await _createIsolate();
        await _attackToIsolate(isolate, taskPool3[i]);
        if (_isolatePool.length >= _poolSize) break;
      }
    }
  }

  /// 向隔离实例发送任务
  Future _attackToIsolate(IsolateInstance isolate, DownloadTask task) async {
    // logD("_attackToIsolate isolate: $isolate, task: $task");
    isolate.isBusy = true;
    isolate.task = task;
    isolate.subscription?.onData((message) {
      if (message is double) {
        // logD("Task ${task.id} Progress: $message");
        task.progress = message;
        _streamController.sink.add(task);
      } else if (message is DownloadTaskStatus) {
        // logD("Task ${task.id} message: $message");
        if (message == DownloadTaskStatus.COMPLETED) {
          logD("download COMPLETED $task");
          task.status = DownloadTaskStatus.COMPLETED;
          _taskList.removeWhere((task) => task.id == isolate.task?.id);
          _isolatePool
              .where((e) => e.task?.id == isolate.task?.id)
              .firstOrNull
              ?.reset();
          processTask();
        }
        _streamController.sink.add(task);
      } else if (message is SendPort) {
        // logD("Task ${task.id} controlPort: $message");
        task.status = DownloadTaskStatus.DOWNLOADING;
        isolate.controlPort = message;
        isolate.controlPort?.send(task);
      }
    });
    task.status = DownloadTaskStatus.DOWNLOADING;
    isolate.controlPort?.send(task);
  }

  /// 创建隔离实例
  Future<IsolateInstance> _createIsolate() async {
    final mainReceivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      downloadIsolateEntry,
      mainReceivePort.sendPort,
    );
    final isolateInstance = IsolateInstance(
      isolate: isolate,
      receivePort: mainReceivePort,
    );
    final StreamSubscription subscription =
        mainReceivePort.listen((message) {});
    isolateInstance.subscription = subscription;
    _isolatePool.add(isolateInstance);
    return isolateInstance;
  }

  void dispose() {
    _streamController.close();
    _isolatePool.forEach((isolate) {
      isolate.subscription?.cancel();
      isolate.receivePort.close();
      isolate.isolate.kill(priority: Isolate.immediate);
    });
  }
}
