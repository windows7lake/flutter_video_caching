import 'dart:isolate';
import 'download_task.dart';
import 'isolate_health.dart';
import 'memory_monitor.dart';

// 隔离管理类
class ManagedIsolate {
  final Isolate isolate;
  final SendPort controlPort;
  final IsolateHealth health;
  final MemoryMonitor memoryMonitor;
  DownloadTask? currentTask;
  bool _isBusy = false;

  bool get isBusy => _isBusy;

  ManagedIsolate({
    required this.isolate,
    required this.controlPort,
    required this.health,
    required this.memoryMonitor,
  }) {
    memoryMonitor.startMonitoring(isolate);
  }

  // 开始任务
  void startTask(DownloadTask task) {
    _isBusy = true;
    currentTask = task;
    health.recordActivity();
    memoryMonitor.reset();
  }

  // 完成任务
  void completeTask() {
    _isBusy = false;
    currentTask = null;
    health.recordActivity();
  }
}