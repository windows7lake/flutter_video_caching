import 'dart:io';
import 'dart:isolate';

import 'package:flutter_video_caching/global/config.dart';
import 'package:synchronized/synchronized.dart';

import '../ext/log_ext.dart';
import 'download_isolate_msg.dart';
import 'download_status.dart';
import 'download_task.dart';

void downloadIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(DownloadIsolateMsg(
    IsolateMsgType.sendPort,
    receivePort.sendPort,
  ));
  DownloadIsolate? downloadIsolate;
  receivePort.listen((message) {
    if (message is DownloadIsolateMsg) {
      switch (message.type) {
        case IsolateMsgType.logPrint:
          if (message.data != null && message.data is bool) {
            Config.logPrint = message.data as bool;
          }
          break;
        case IsolateMsgType.task:
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

/// The minimum interval for updating progress in milliseconds.
const int MIN_PROGRESS_UPDATE_INTERVAL = 500;

class DownloadIsolate {
  final Lock _lock = Lock();
  final HttpClient client = HttpClient();
  final Map<String, DownloadStatus> taskStatus = {};
  int retryTimes = 0;

  Future<void> start(DownloadTask task, SendPort sendPort) async {
    try {
      HttpClientRequest request = await client.getUrl(task.uri);

      bool fileAppend = true;
      String range = '';
      if (task.downloadedBytes > 0 || task.startRange > 0) {
        int startRange = task.downloadedBytes + task.startRange;
        range = 'bytes=$startRange-';
      }
      if (task.endRange != null) {
        if (range.isEmpty) range = 'bytes=0-';
        range += '${task.endRange}';
        fileAppend = false;
      }
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

  Future<void> pause(DownloadTask task) async {
    taskStatus[task.id] = DownloadStatus.PAUSED;
  }

  Future<void> cancel(DownloadTask task) async {
    taskStatus[task.id] = DownloadStatus.CANCELLED;
  }

  void reset(DownloadTask task) {
    taskStatus.remove(task.id);
    retryTimes = 3;
  }

  Future<void> _writeToFile(File file, List<int> data, bool append) async {
    await _lock.synchronized(() async {
      try {
        await file.writeAsBytes(data,
            mode: append ? FileMode.append : FileMode.write);
      } catch (e) {
        logIsolate('[DownloadIsolate] write error: $e');
      }
    });
  }
}
