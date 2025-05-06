import 'dart:async';
import 'dart:isolate';

import 'download_task.dart';

class DownloadIsolateInstance {
  final Isolate isolate;
  final ReceivePort receivePort;
  SendPort? controlPort;
  StreamSubscription? subscription;
  DownloadTask? task;
  bool isBusy = false;

  DownloadIsolateInstance({
    required this.isolate,
    required this.receivePort,
    this.controlPort,
    this.subscription,
  });

  void bindTask(DownloadTask task) {
    this.task = task;
    isBusy = true;
  }

  void reset() {
    task = null;
    isBusy = false;
  }

  @override
  String toString() {
    return 'IsolateInstance [ '
        'isBusy: $isBusy, '
        'task: $task, '
        'isolate: $isolate, '
        'receivePort: $receivePort '
        'controlPort: $controlPort, '
        'subscription: $subscription '
        ' ]';
  }
}
