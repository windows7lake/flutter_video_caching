import 'dart:async';
import 'dart:isolate';

import 'download_task.dart';

/// Represents an instance of a download isolate, encapsulating the isolate,
/// its communication ports, subscription, and the associated download task.
/// This class is used to manage the lifecycle and state of a single download
/// operation running in a separate isolate.
class DownloadIsolateInstance {
  /// The underlying Dart isolate that performs the download task.
  final Isolate isolate;

  /// The receive port used to receive messages from the isolate.
  final ReceivePort receivePort;

  /// The send port used to control or communicate with the isolate.
  SendPort? controlPort;

  /// The stream subscription for handling messages from the receive port.
  StreamSubscription? subscription;

  /// The download task currently bound to this isolate instance.
  DownloadTask? task;

  /// Indicates whether the isolate is currently processing a task.
  bool isBusy = false;

  /// Constructs a [DownloadIsolateInstance] with the given isolate, receive port,
  /// and optional control port and subscription.
  DownloadIsolateInstance({
    required this.isolate,
    required this.receivePort,
    this.controlPort,
    this.subscription,
  });

  /// Binds a [DownloadTask] to this isolate instance and marks it as busy.
  void bindTask(DownloadTask task) {
    this.task = task;
    isBusy = true;
  }

  /// Unbinds the current task and marks the isolate as not busy.
  void reset() {
    task = null;
    isBusy = false;
  }

  /// Returns a string representation of the isolate instance, including its state and properties.
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
