import 'dart:io';
import 'dart:isolate';

import 'package:synchronized/synchronized.dart';

import '../ext/log_ext.dart';
import '../global/config.dart';
import 'download_isolate_msg.dart';
import 'download_status.dart';
import 'download_task.dart';

/// Entry point function for the download isolate.
/// Sets up communication with the main isolate and listens for incoming messages
/// to control download tasks (start, pause, cancel, etc.).
void downloadIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  // Send the SendPort of this isolate back to the main isolate for communication.
  mainSendPort.send(DownloadIsolateMsg(
    IsolateMsgType.sendPort,
    receivePort.sendPort,
  ));
  DownloadIsolate? downloadIsolate;
  // Listen for messages from the main isolate.
  receivePort.listen((message) {
    if (message is DownloadIsolateMsg) {
      switch (message.type) {
        case IsolateMsgType.logPrint:
          // Update log print configuration if needed.
          if (message.data != null && message.data is bool) {
            Config.logPrint = message.data as bool;
          }
          break;
        case IsolateMsgType.task:
          // Handle download task messages (start, pause, cancel).
          if (message.data == null) break;
          final task = message.data as DownloadTask;
          downloadIsolate ??= DownloadIsolate();
          if (task.status == DownloadStatus.PAUSED) {
            downloadIsolate?.pause(task);
          } else if (task.status == DownloadStatus.CANCELLED) {
            downloadIsolate?.cancel(task);
          } else {
            downloadIsolate?.reset(task);
            downloadIsolate?.start(task, mainSendPort);
          }
          break;
        default:
          break;
      }
    }
  });
}

/// The minimum interval (in milliseconds) for updating download progress.
const int MIN_PROGRESS_UPDATE_INTERVAL = 500;

/// Handles the actual download logic within the isolate, including starting,
/// pausing, cancelling, and writing data to file.
class DownloadIsolate {
  /// Lock to ensure thread-safe file writing.
  final Lock _lock = Lock();

  /// HTTP client used for downloading files.
  final HttpClient client = HttpClient();

  /// Tracks the status of each download task by task ID.
  final Map<String, DownloadStatus> taskStatus = {};

  /// Number of retry attempts left for the current download.
  int retryTimes = 0;

  /// Starts downloading the file for the given [task], sending progress and status
  /// updates back to the main isolate via [sendPort].
  Future<void> start(DownloadTask task, SendPort sendPort) async {
    try {
      HttpClientRequest request = await client.getUrl(task.uri);

      bool fileAppend = false;
      String range = '';
      // Set up HTTP Range header for resuming or partial downloads.
      if (task.downloadedBytes > 0 || task.startRange > 0) {
        int startRange = task.downloadedBytes + task.startRange;
        range = 'bytes=$startRange-';
        fileAppend = true;
      }
      if (task.endRange != null) {
        if (range.isEmpty) range = 'bytes=0-';
        range += '${task.endRange}';
      }
      // Add custom headers except 'host' and 'range'.
      if (task.headers != null) {
        task.headers!.forEach((key, value) {
          logIsolate('task.headers: ${task.headers}');
          String keyLower = key.toLowerCase();
          if (keyLower == 'host' || keyLower == 'range') return;
          request.headers.set(key, value);
        });
      }
      request.headers.add('Range', range);
      logIsolate('[DownloadIsolate] START ${task.uri} \n'
          'headers: {\n ${request.headers} } \n');

      final response = await request.close();
      logIsolate('[DownloadIsolate] status code: ${response.statusCode} '
          '${task.uri} range: $range');
      // Handle HTTP errors and retry logic.
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 416) retryTimes = 0;
        if (retryTimes > 0) {
          logIsolate('[DownloadIsolate] retry $retryTimes: '
              '${task.uri} range: $range');
          retryTimes--;
          start(task, sendPort);
          return;
        }
        logIsolate('[DownloadIsolate] failed: ${task.uri}  range: $range');
        task.status = DownloadStatus.FAILED;
        sendPort.send(DownloadIsolateMsg(IsolateMsgType.task, task));
        return;
      }

      // Check if contentLength is valid
      if (response.contentLength == -1) {
        logIsolate('[DownloadIsolate] failed to get the total file size.');
      }

      // Calculate the total file size
      final totalBytes = task.downloadedBytes + response.contentLength;
      task.totalBytes = response.contentLength == -1 ? 0 : totalBytes;

      // Record the time of the last update progress
      DateTime lastUpdateTime = DateTime.now();

      // Creating a temporary storage area
      List<int> buffer = [];

      File saveFile = File(task.isolateSavePath);

      // Read data from the response stream.
      await for (var data in response) {
        // Check if it has been cancelled or suspended
        if (taskStatus[task.id] == DownloadStatus.PAUSED) {
          await _writeToFile(saveFile, buffer, fileAppend);
          task.status = DownloadStatus.PAUSED;
          sendPort.send(DownloadIsolateMsg(IsolateMsgType.task, task));
          logIsolate("[DownloadIsolate] PAUSED ${task.toString()} ");
          return;
        }
        if (taskStatus[task.id] == DownloadStatus.CANCELLED) {
          await saveFile.delete();
          task.status = DownloadStatus.CANCELLED;
          sendPort.send(DownloadIsolateMsg(IsolateMsgType.task, task));
          logIsolate("[DownloadIsolate] CANCELLED ${task.toString()} ");
          return;
        }

        task.downloadedBytes += data.length;
        buffer.addAll(data);

        // Calculate the interval between the current time and the last update time
        final currentTime = DateTime.now();
        final timeDiff = currentTime.difference(lastUpdateTime).inMilliseconds;

        // If the time interval exceeds the specified minimum update interval,
        // or the download is complete, then update progress
        if (task.status == DownloadStatus.DOWNLOADING &&
            timeDiff >= MIN_PROGRESS_UPDATE_INTERVAL) {
          if (task.totalBytes > 0) {
            task.progress = task.downloadedBytes / task.totalBytes;
          }
          sendPort.send(DownloadIsolateMsg(IsolateMsgType.task, task));
          lastUpdateTime = currentTime;
          logIsolate("[DownloadIsolate] DOWNLOADING ${task.toString()}");
        }
      }

      // Download complete, update status and write to file.
      task.data = buffer;
      task.status = DownloadStatus.COMPLETED;
      sendPort.send(DownloadIsolateMsg(IsolateMsgType.task, task));
      logIsolate("[DownloadIsolate] COMPLETED ${task.toString()}");

      await _writeToFile(saveFile, buffer, fileAppend);
      task.file = saveFile;
      task.status = DownloadStatus.FINISHED;
      sendPort.send(DownloadIsolateMsg(IsolateMsgType.task, task));
      logIsolate("[DownloadIsolate] FINISHED ${task.toString()}");
      task.reset();
    } catch (e) {
      logIsolate('[DownloadIsolate] Download error: $e');
    } finally {
      logIsolate('[DownloadIsolate] close ${task.url}');
    }
  }

  /// Marks the given [task] as paused.
  Future<void> pause(DownloadTask task) async {
    taskStatus[task.id] = DownloadStatus.PAUSED;
  }

  /// Marks the given [task] as cancelled.
  Future<void> cancel(DownloadTask task) async {
    taskStatus[task.id] = DownloadStatus.CANCELLED;
  }

  /// Resets the status and retry count for the given [task].
  void reset(DownloadTask task) {
    taskStatus.remove(task.id);
    retryTimes = 3;
  }

  /// Writes the downloaded [data] to the specified [file].
  /// Uses a lock to ensure thread safety. Appends or overwrites based on [append].
  Future<void> _writeToFile(File file, List<int> data, bool append) async {
    await _lock.synchronized(() async {
      try {
        FileMode fileMode = FileMode.write;
        if (append) fileMode = FileMode.append;
        await file.writeAsBytes(data, mode: fileMode);
      } catch (e) {
        logIsolate('[DownloadIsolate] write error: $e');
      }
    });
  }
}
