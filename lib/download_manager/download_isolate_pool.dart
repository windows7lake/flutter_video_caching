import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';

import 'constants.dart';
import 'download_progress.dart';
import 'download_state.dart';
import 'download_task.dart';
import 'isolate_health.dart';
import 'managed_isolate.dart';
import 'memory_monitor.dart';
import 'priority_queue_extensions.dart';

// 隔离池核心类
class DownloadIsolatePool {
  final Lock _atomicLock = Lock();
  final List<ManagedIsolate> _isolates = [];
  final PriorityQueue<DownloadTask> _taskQueue =
      PriorityQueue((a, b) => b.priority.compareTo(a.priority));
  final ReceivePort _mainPort = ReceivePort();
  final Map<String, StreamController<DownloadProgress>> _progressControllers =
      {};
  final Uuid _uuid = Uuid();
  final Map<String, Completer<void>> _pauseHandlers = {};
  late final Timer _healthCheckTimer;

  DownloadIsolatePool() {
    _healthCheckTimer = Timer.periodic(
      Duration(seconds: 30),
      (_) => _checkIsolateHealth(),
    );
    _initialize();
  }

  // 初始化隔离线程池
  Future<void> _initialize() async {
    for (var i = 0; i < maxConcurrent; i++) {
      _isolates.add(await _spawnIsolate());
    }
    _mainPort.listen(_handleMainMessage);
  }

  // 创建新的隔离线程
  Future<ManagedIsolate> _spawnIsolate() async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _isolateEntry,
      receivePort.sendPort,
      debugName: 'DL_Isolate_${_uuid.v4()}',
      errorsAreFatal: false,
      onExit: receivePort.sendPort,
    );

    final completer = Completer<SendPort>();
    late final subscription;
    subscription = receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
        subscription.cancel();
      }
    });

    return ManagedIsolate(
      isolate: isolate,
      controlPort: await completer.future,
      health: IsolateHealth(),
      memoryMonitor: MemoryMonitor(
        maxAllowedMB: 512,
        checkInterval: Duration(seconds: 5),
      ),
    );
  }

  // 隔离线程入口函数
  static void _isolateEntry(SendPort mainSendPort) async {
    final commandPort = ReceivePort();
    mainSendPort.send(commandPort.sendPort);
    final Map<String, DownloadTask> _activeTasks = {};
    final Map<String, StreamSubscription> _subscriptions = {};

    await for (final message in commandPort) {
      if (message is Map<String, dynamic>) {
        final task = message['task'] as DownloadTask;
        final progressPort = message['progressPort'] as SendPort;
        final responsePort = message['responsePort'] as SendPort;

        _activeTasks[task.id] = task;
        try {
          final subscription = await _executeDownload(task, (progress) {
            progressPort.send(progress);
          });
          _subscriptions[task.id] = subscription;
          responsePort.send(_TaskResult.success(task.id));
        } catch (e, st) {
          responsePort.send(_TaskResult.failure(
            task.id,
            DownloadError(e.toString(), st),
          ));
        } finally {
          _activeTasks.remove(task.id);
          _subscriptions.remove(task.id);
        }
      } else if (message is Map<String, dynamic> &&
          message['type'] == 'control') {
        final taskId = message['taskId'] as String;
        final action = message['action'] as String;
        final task = _activeTasks[taskId];
        final subscription = _subscriptions[taskId];

        if (task != null) {
          switch (action) {
            case 'pause':
              task.transitState(DownloadState.paused);
              subscription?.pause();
              break;
            case 'cancel':
              task.transitState(DownloadState.canceled);
              subscription?.cancel();
              break;
            case 'resume':
              task.transitState(DownloadState.downloading);
              subscription?.resume();
              break;
          }
        }
      }
    }
  }

  // 暂停下载任务
  Future<void> pauseDownload(String taskId) async {
    await _atomicLockOperation(() async {
      final task = findTask(taskId);
      if (task == null || task.state != DownloadState.downloading) return;

      task.transitState(DownloadState.paused);
      final isolate =
          _isolates.firstWhereOrNull((iso) => iso.currentTask?.id == taskId);

      if (isolate != null) {
        final completer = Completer<void>();
        _pauseHandlers[taskId] = completer;
        isolate.controlPort
            .send({'type': 'control', 'action': 'pause', 'taskId': taskId});
        await completer.future;
      } else {
        _taskQueue.remove(task);
        _taskQueue.add(task);
      }
    });
  }

  // 取消下载任务

  Future<void> cancelDownload(String taskId) async {
    await _atomicLockOperation(() async {
      final task = findTask(taskId);
      if (task == null) return;

      task.transitState(DownloadState.canceled);
      final isolate =
          _isolates.firstWhereOrNull((iso) => iso.currentTask?.id == taskId);

      if (isolate != null) {
        isolate.controlPort
            .send({'type': 'control', 'action': 'cancel', 'taskId': taskId});
      } else {
        _taskQueue.remove(task);
      }

      await cleanupTask(task);
      _progressControllers[taskId]?.close();
    });
  }

  // 继续下载任务

  Future<void> resumeDownload(String taskId) async {
    await _atomicLockOperation(() async {
      final task = findTask(taskId);
      if (task == null || task.state != DownloadState.paused) return;

      task.transitState(DownloadState.downloading);
      final isolate =
          _isolates.firstWhereOrNull((iso) => iso.currentTask?.id == taskId);

      if (isolate != null) {
        isolate.controlPort
            .send({'type': 'control', 'action': 'resume', 'taskId': taskId});
      } else {
        _taskQueue.remove(task);
        _taskQueue.add(task);
        _scheduleNextTask();
      }
    });
  }

  // 添加下载任务
  Future<String> addDownload({
    required String url,
    String? savePath,
    int priority = 0,
    String? checksum,
    int maxRetries = 3,
  }) async {
    final taskId = _uuid.v4();
    final resolvedPath = savePath ?? await _generateDefaultPath(url);

    _atomicLockOperation(() {
      _taskQueue.add(DownloadTask(
        id: taskId,
        url: url,
        savePath: resolvedPath,
        priority: priority,
        checksum: checksum,
        retriesLeft: maxRetries,
      ));
      _scheduleNextTask();
    });

    return taskId;
  }

  // 获取下载进度流
  Stream<DownloadProgress> getProgressStream(String taskId) {
    return _progressControllers
        .putIfAbsent(
          taskId,
          () => StreamController.broadcast(),
        )
        .stream;
  }

  // 限速
  void throttleSpeed(String taskId, {required double maxSpeed}) {
    _atomicLockOperation(() {
      final task = _taskQueue.firstWhereOrNull((t) => t.id == taskId);
      if (task != null) {
        _taskQueue.remove(task);
        task.priority = (task.priority - 10).clamp(0, 100);
        _taskQueue.add(task);
        _scheduleNextTask();
      }
    });
  }

  // 调度下一个任务
  void _scheduleNextTask() {
    _atomicLockOperation(() {
      if (_taskQueue.isEmpty) return;

      final freeIsolate = _isolates.firstWhereOrNull(
        (iso) => !iso.isBusy && iso.health.isHealthy,
      );

      if (freeIsolate != null) {
        final task = _taskQueue.removeFirst();
        freeIsolate.startTask(task);
        freeIsolate.controlPort.send({
          'task': task,
          'progressPort': _mainPort.sendPort,
          'responsePort': _mainPort.sendPort,
        });
      }

      // 动态扩容机制
      if (_taskQueue.length > _isolates.length * 2) {
        _spawnIsolate().then((iso) => _isolates.add(iso));
      }
    });
  } // 主消息处理

  void _handleMainMessage(dynamic message) {
    if (message is DownloadProgress) {
      final controller = _progressControllers[message.taskId];
      if (controller != null && !controller.isClosed) {
        controller.add(message);
        if (message.isCompleted) controller.close();
        if (message.state == DownloadState.paused) {
          _pauseHandlers[message.taskId]?.complete();
          _pauseHandlers.remove(message.taskId);
        }
      }
    } else if (message is _TaskResult) {
      _handleTaskResult(message);
    }
  }

  // 处理任务结果
  void _handleTaskResult(_TaskResult result) {
    _atomicLockOperation(() {
      final isolate = _isolates.firstWhere(
        (iso) => iso.currentTask?.id == result.taskId,
      );

      isolate.completeTask();

      if (result.isFailure) {
        final task = isolate.currentTask!;
        if (task.retriesLeft > 0) {
          task.retriesLeft--;
          _taskQueue.add(task);
        } else {
          _progressControllers[task.id]?.add(
            DownloadProgress.error(task.id, result.error!),
          );
        }
        isolate.health.recordError();
      }

      _scheduleNextTask();
    });
  }

  // 生成默认保存路径
  Future<String> _generateDefaultPath(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    final filename = path.basename(Uri.parse(url).path);
    return path.join(dir.path, filename);
  }

  // 原子操作
  Future _atomicLockOperation(VoidCallback action) async {
    await _atomicLock.synchronized(() => action());
  }

  // 检查隔离线程健康状态
  void _checkIsolateHealth() {
    _atomicLockOperation(() {
      _isolates.removeWhere((iso) {
        if (!iso.health.isHealthy) {
          iso.isolate.kill(priority: Isolate.immediate);
          return true;
        }
        return false;
      });
    });
  }

  // 执行下载任务

  static Future<StreamSubscription> _executeDownload(
    DownloadTask task,
    void Function(DownloadProgress) progressCallback,
  ) async {
    final client = http.Client();
    final tempFile = File('${task.savePath}.tmp');
    final resumeOffset = await tempFile.exists() ? await tempFile.length() : 0;
    task.resumeOffset = resumeOffset;
    final request = http.Request('GET', Uri.parse(task.url))
      ..headers['Range'] = 'bytes=$resumeOffset-';

    var lastUpdate = DateTime.now();

    final response = await client.send(request);
    final contentLength = response.contentLength ?? 0;
    final totalBytes = contentLength + resumeOffset;

    final streamController = StreamController<List<int>>();
    final subscription = response.stream.listen(
      (chunk) async {
        if (task.state == DownloadState.paused) {
          streamController.close();
          return;
        }
        if (task.state == DownloadState.canceled) {
          streamController.close();
          await tempFile.delete();
          throw DownloadError('Download canceled');
        }

        streamController.add(chunk);
        await tempFile.writeAsBytes(chunk, mode: FileMode.append);

        final now = DateTime.now();
        final elapsed = now.difference(lastUpdate).inMilliseconds;
        final bytesDelta = chunk.length;

        if (elapsed > 100) {
          final speed = (bytesDelta / elapsed * 1000).roundToDouble();
          progressCallback(DownloadProgress.running(
            task.id,
            (tempFile.lengthSync() / totalBytes).clamp(0.0, 1.0),
            speed,
          ));
          lastUpdate = now;
        }
      },
      onDone: () async {
        streamController.close();
        if (task.state == DownloadState.canceled) {
          await tempFile.delete();
          return;
        }
        if (task.checksum != null) {
          await _verifyChecksum(tempFile.path, task.checksum!);
        }
        await tempFile.rename(task.savePath);
        progressCallback(DownloadProgress.complete(task.id));
      },
      onError: (error) {
        streamController.addError(error);
      },
    );

    return subscription;
  }

  // 验证文件校验和
  static Future<void> _verifyChecksum(String path, String expected) async {
    final file = File(path);
    if (!await file.exists()) {
      throw DownloadError('校验文件不存在');
    }

    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != expected) {
      await file.delete();
      throw DownloadError('文件校验失败');
    }
  }

  // 清理任务文件
  Future<void> cleanupTask(DownloadTask task) async {
    try {
      final tempFile = File('${task.savePath}.tmp');
      if (await tempFile.exists()) await tempFile.delete();
      if (await File(task.savePath).exists())
        await File(task.savePath).delete();
    } catch (e) {
      debugPrint('清理文件失败: $e');
    }
  }

  // 查找任务
  DownloadTask? findTask(String taskId) {
    return _taskQueue.firstWhereOrNull((t) => t.id == taskId) ??
        _isolates
            .expand((iso) => iso.currentTask != null ? [iso.currentTask!] : [])
            .firstWhereOrNull((t) => t.id == taskId);
  }

  // 释放资源
  void dispose() {
    _healthCheckTimer.cancel();
    _isolates.forEach((iso) => iso.isolate.kill());
    _mainPort.close();
    _progressControllers.forEach((_, controller) => controller.close());
  }
}

// 内部结果类
class _TaskResult {
  final String taskId;
  final DownloadError? error;

  bool get isSuccess => error == null;

  bool get isFailure => !isSuccess;

  _TaskResult.success(this.taskId) : error = null;

  _TaskResult.failure(this.taskId, this.error);
}
