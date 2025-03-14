import 'dart:async';
import 'dart:isolate';

import 'download_task.dart';

// 隔离实例类，用于管理单个 isolate
class IsolateInstance {
  final Isolate isolate;
  final ReceivePort receivePort;
  SendPort? controlPort;
  StreamSubscription? subscription;
  DownloadTask? task;
  bool isBusy = false;

  IsolateInstance({
    required this.isolate,
    required this.receivePort,
  });

  void reset() {
    task = null;
    isBusy = false;
  }

  String toString() {
    return 'IsolateInstance(isolate: $isolate, receivePort: $receivePort '
        'controlPort: $controlPort, task: $task, subscription: $subscription '
        'isBusy: $isBusy)';
  }
}
