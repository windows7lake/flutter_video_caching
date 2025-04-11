import 'dart:io';
import 'dart:isolate';

import 'package:flutter_video_cache/ext/log_ext.dart';

import 'download_isolate_msg.dart';
import 'download_status.dart';
import 'download_task.dart';

void downloadIsolateEntry(SendPort mainSendPort) {
  logV('[DownloadIsolateEntry] mainSendPort: $mainSendPort');
  final receivePort = ReceivePort();
  mainSendPort.send(DownloadIsolateMsg(
    IsolateMsgType.sendPort,
    receivePort.sendPort,
  ));
  DownloadIsolate? downloadIsolate;
  receivePort.listen((message) async {
    logV('[DownloadIsolateEntry] receive message: $message');
    if (message is DownloadIsolateMsg) {
      switch (message.type) {
        case IsolateMsgType.task:
          if (message.data == null) break;
          final task = message.data as DownloadTask;
          if (task.status == DownloadStatus.PAUSED) {
            await downloadIsolate?.pause();
          } else if (task.status == DownloadStatus.CANCELLED) {
            await downloadIsolate?.cancel();
          } else {
            downloadIsolate = DownloadIsolate();
            await downloadIsolate!.start(task, mainSendPort);
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
  HttpClient? client;
  bool _isPaused = false;
  bool _isCancelled = false;

  Future<void> start(DownloadTask task, SendPort sendPort) async {
    logIsolate('[DownloadIsolate] START ${task.url}');
    try {
      client = HttpClient();
      HttpClientRequest request = await client!.getUrl(Uri.parse(task.url));

      if (task.downloadedBytes > 0) {
        request.headers.add('Range', 'bytes=${task.downloadedBytes}-');
      }

      final response = await request.close();
      logIsolate('[DownloadIsolate] status code: ${response.statusCode}');

      if (response.statusCode < 200 && response.statusCode >= 300) {
        logIsolate('[DownloadIsolate] failed: ${task.url}');
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

      final String tempFilePath = '${task.saveFile}.temp';
      final File tempFile = File(tempFilePath);
      final raf = await tempFile.open(mode: FileMode.append);
      await raf.setPosition(task.downloadedBytes);

      // 记录上一次更新进度的时间
      DateTime lastUpdateTime = DateTime.now();

      await for (var data in response) {
        // 检查是否被取消或暂停
        if (_isPaused) {
          await raf.close();
          task.status = DownloadStatus.PAUSED;
          sendPort.send(DownloadIsolateMsg(IsolateMsgType.task, task));
          logIsolate("[DownloadIsolate] PAUSED ${task.url} ");
          if (_isCancelled) {
            await tempFile.delete();
            task.status = DownloadStatus.CANCELLED;
            sendPort.send(DownloadIsolateMsg(IsolateMsgType.task, task));
            logIsolate("[DownloadIsolate] CANCELLED ${task.id} ");
          }
          return;
        }

        await raf.writeFrom(data);
        task.downloadedBytes += data.length;

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
        }
      }

      await raf.close();
      // 原子性写入磁盘操作：将临时文件重命名为最终文件
      if (await tempFile.exists()) {
        await tempFile.rename(task.saveFile);
      }

      task.status = DownloadStatus.COMPLETED;
      sendPort.send(DownloadIsolateMsg(IsolateMsgType.task, task));
      logIsolate("[DownloadIsolate] COMPLETED");
    } catch (e) {
      logIsolate('[DownloadIsolate] Download error: $e');
    } finally {
      logIsolate('[DownloadIsolate] close');
      client?.close();
    }
  }

  Future<void> pause() async {
    _isPaused = true;
  }

  Future<void> cancel() async {
    _isPaused = true;
    _isCancelled = true;
  }
}
