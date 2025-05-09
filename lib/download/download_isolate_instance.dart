import 'dart:async';
import 'dart:isolate';

import 'download_task.dart';

/// This class represents an instance of a download isolate.
class DownloadIsolateInstance {
  /// The isolate instance.
  final Isolate isolate;

  /// The receive port for the isolate.
  final ReceivePort receivePort;

  /// The control port for the isolate.
  SendPort? controlPort;

  /// The subscription for the isolate.
  StreamSubscription? subscription;

  /// The task associated with this isolate instance.
  DownloadTask? task;

  /// Indicates whether the isolate is busy processing a task.
  bool isBusy = false;

  DownloadIsolateInstance({
    required this.isolate,
    required this.receivePort,
    this.controlPort,
    this.subscription,
  });

  /// Binds a task to this isolate instance and marks it as busy.
  void bindTask(DownloadTask task) {
    this.task = task;
    isBusy = true;
  }

  /// Unbinds the task from this isolate instance and marks it as not busy.
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
