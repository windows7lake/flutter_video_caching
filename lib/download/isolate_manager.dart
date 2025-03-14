import 'dart:async';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

import 'download_task.dart';
import 'isolate_download.dart';
import 'isolate_instance.dart';

/// Isolate池的最大个数
const int MAX_POOL_SIZE = 1;

class IsolateManager {
  final Lock _atomicLock = Lock();
  final List<IsolateInstance> _isolatePool = [];
  final List<DownloadTask> _taskList = [];
  int _poolSize = 0;

  IsolateManager({int? poolSize}) {
    _poolSize = poolSize ?? MAX_POOL_SIZE;
  }

  List<DownloadTask> get taskList => _taskList;

  IsolateInstance? finaIsolateByTaskId(String taskId) =>
      _isolatePool.where((isolate) => isolate.task?.id == taskId).firstOrNull;

  void notifyIsolate(String taskId, DownloadTaskStatus message) {
    IsolateInstance? isolateInstance = finaIsolateByTaskId(taskId);
    isolateInstance?.controlPort?.send(message);
    print("Task ${isolateInstance?.task?.id} notifyIsolate: $message");
  }

  Future addTask(
    DownloadTask task, {
    Function(DownloadTask)? onProgressUpdate,
  }) async {
    await _atomicLock.synchronized(() async {
      final appDir = await getApplicationDocumentsDirectory();
      task.saveFile = '${appDir.path}/${task.saveFile}';
      _taskList.add(task);
      _taskList.sort((a, b) => b.priority - a.priority);
      task = _taskList.first;
      await _attackToIsolate(task, onProgressUpdate: onProgressUpdate);
    });
  }

  Future _attackToIsolate(
    DownloadTask task, {
    Function(DownloadTask)? onProgressUpdate,
  }) async {
    IsolateInstance? availableIsolate =
        _isolatePool.where((isolate) => !isolate.isBusy).firstOrNull;
    if (availableIsolate == null && _isolatePool.length < _poolSize) {
      availableIsolate = await _createIsolate();
    }
    if (availableIsolate == null) {
      IsolateInstance? _isolate;
      int minPriority = task.priority;
      for (final isolate in _isolatePool) {
        if (isolate.task != null && isolate.task!.priority < minPriority) {
          minPriority = isolate.task!.priority;
          _isolate = isolate;
        }
      }
      if (_isolate?.task != null && _isolate!.task!.id != task.id) {
        availableIsolate = _isolate;
      }
    }
    if (availableIsolate == null) return;
    availableIsolate.isBusy = true;
    availableIsolate.task = task;
    availableIsolate.subscription?.onData((message) {
      if (message is double) {
        print("Task ${task.id} Progress: $message");
        task.progress = message;
        onProgressUpdate?.call(task);
      } else if (message is DownloadTaskStatus) {
        print("Task ${task.id} message: $message");
        if (message == DownloadTaskStatus.COMPLETED) {
          task.progress = 1.0;
          availableIsolate?.reset();
        }
        task.status = message;
        onProgressUpdate?.call(task);
      } else if (message is SendPort) {
        print("Task ${task.id} controlPort: $message");
        task.status = DownloadTaskStatus.DOWNLOADING;
        availableIsolate?.controlPort = message;
        availableIsolate?.controlPort?.send(task);
      }
    });
  }

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
}
