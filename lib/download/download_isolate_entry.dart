import 'dart:io';
import 'dart:isolate';

import 'package:flutter_video_cache/ext/log_ext.dart';
import 'package:synchronized/synchronized.dart';

import 'download_isolate_msg.dart';
import 'download_status.dart';
import 'download_task.dart';

void downloadIsolateEntry(SendPort mainSendPort) {
  // logV('[DownloadIsolateEntry] mainSendPort: $mainSendPort');
  final receivePort = ReceivePort();
  mainSendPort.send(DownloadIsolateMsg(
    IsolateMsgType.sendPort,
    receivePort.sendPort,
  ));
  DownloadIsolate? downloadIsolate;
  receivePort.listen((message) {
    // logV('[DownloadIsolateEntry] receive message: $message');
    if (message is DownloadIsolateMsg) {
      switch (message.type) {
        case IsolateMsgType.task:
          if (message.data == null) break;
          final task = message.data as DownloadTask;
          downloadIsolate ??= DownloadIsolate();
          if (task.status == DownloadStatus.PAUSED) {
            downloadIsolate?.pause();
          } else if (task.status == DownloadStatus.CANCELLED) {
            downloadIsolate?.cancel();
          } else {
            downloadIsolate?.reset();
            downloadIsolate?.start(task, mainSendPort);
          }
          break;
        default:
          break;
      }
    }
  });
}

/// 定义进度更新的最小时间间隔（毫秒）
const int MIN_PROGRESS_UPDATE_INTERVAL = 500;

class DownloadIsolate {
  final Lock _lock = Lock();
  final HttpClient client = HttpClient();
  bool _isPaused = false;
  bool _isCancelled = false;
  int retryTimes = 3;

  Future<void> start(DownloadTask task, SendPort sendPort) async {
    try {
      HttpClientRequest request = await client.getUrl(task.uri);

      String range = '';
      if (task.downloadedBytes > 0 || task.startRange > 0) {
        int startRange = task.downloadedBytes + task.startRange;
        range = 'bytes=$startRange-';
      }
      if (task.endRange != null) {
        if (range.isEmpty) range = 'bytes=0-';
        range += '${task.endRange}';
      }
      request.headers.add('Range', range);
      logIsolate('[DownloadIsolate] START ${task.uri} range: $range');

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

      // 检查 contentLength 是否有效
      if (response.contentLength == -1) {
        logIsolate('[DownloadIsolate] failed to get the total file size.');
      }

      // 计算文件总大小
      final totalBytes = task.downloadedBytes + response.contentLength;
      task.totalBytes = response.contentLength == -1 ? 0 : totalBytes;

      // 记录上一次更新进度的时间
      DateTime lastUpdateTime = DateTime.now();

      // 创建临时存储
      List<int> buffer = [];

      final File saveFile = File('${task.cacheDir}/${task.saveFileName}');

      await for (var data in response) {
        // 检查是否被取消或暂停
        if (_isPaused) {
          await _writeToFile(saveFile, buffer);
          task.status = DownloadStatus.PAUSED;
          sendPort.send(DownloadIsolateMsg(IsolateMsgType.task, task));
          logIsolate("[DownloadIsolate] PAUSED ${task.toString()} ");
          return;
        }
        if (_isCancelled) {
          await saveFile.delete();
          task.status = DownloadStatus.CANCELLED;
          sendPort.send(DownloadIsolateMsg(IsolateMsgType.task, task));
          logIsolate("[DownloadIsolate] CANCELLED ${task.toString()} ");
          return;
        }

        task.downloadedBytes += data.length;
        buffer.addAll(data);

        // 计算当前时间与上一次更新时间的间隔
        final currentTime = DateTime.now();
        final timeDiff = currentTime.difference(lastUpdateTime).inMilliseconds;

        // 如果时间间隔超过指定的最小更新间隔，或者已经下载完成，则更新进度
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

      await _writeToFile(saveFile, buffer);
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

  Future<void> pause() async {
    _isPaused = true;
  }

  Future<void> cancel() async {
    _isPaused = true;
    _isCancelled = true;
  }

  void reset() {
    retryTimes = 3;
    _isPaused = false;
    _isCancelled = false;
  }

  Future<void> _writeToFile(File file, List<int> data) async {
    await _lock.synchronized(() async {
      try {
        await file.writeAsBytes(data);
      } catch (e) {
        logIsolate('[DownloadIsolate] write error: $e');
      }
    });
  }
}
