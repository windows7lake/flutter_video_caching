import 'dart:io';
import 'dart:isolate';

import 'download_task.dart';

/// 定义进度更新的最小时间间隔（毫秒）
const int MIN_PROGRESS_UPDATE_INTERVAL = 500;

/// 下载任务在 Isolate 中执行的入口函数
void downloadIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  DownloadTask? task;
  mainSendPort.send(receivePort.sendPort);
  receivePort.listen((message) {
    print("Isolate listen: $message");
    if (message is DownloadTask) {
      task = message;
      _downloadFile(task!, mainSendPort);
    } else if (message is DownloadTaskStatus) {
      task?.status = message;
      if (message == DownloadTaskStatus.DOWNLOADING) {
        mainSendPort.send(DownloadTaskStatus.DOWNLOADING);
        _downloadFile(task!, mainSendPort);
      }
    }
  });
}

/// 下载文件的具体实现
void _downloadFile(DownloadTask task, SendPort sendPort) async {
  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(task.url));

    // 设置 Range 头，从已下载的位置继续下载
    if (task.downloadedBytes > 0) {
      request.headers.add('Range', 'bytes=${task.downloadedBytes}-');
    }

    final response = await request.close();

    bool chunked = response.headers.chunkedTransferEncoding;
    print('Response status code: ${response.statusCode}');
    print('Response chunkedTransferEncoding: ${chunked}');
    // 检查 contentLength 是否有效
    if (response.contentLength == -1) {
      print('Failed to get the total file size.');
    }

    // 计算文件总大小
    final totalBytes = task.downloadedBytes + response.contentLength;
    task.totalBytes = response.contentLength == -1 ? 0 : totalBytes;
    task.updateProgress();

    final tempFilePath = '${task.saveFile}.temp';
    final tempFile = File(tempFilePath);
    final raf = await tempFile.open(mode: FileMode.append);
    await raf.setPosition(task.downloadedBytes);

    // 记录上一次更新进度的时间
    DateTime lastUpdateTime = DateTime.now();

    // if (chunked) {
    //   // 如果服务器使用分块传输编码，则直接写入文件
    //   await response.listen(
    //     (data) async {
    //       if (task.status == DownloadTaskStatus.PAUSED) {
    //         print("PAUSED");
    //         request.abort();
    //         client.close();
    //         await raf.close();
    //         sendPort.send(DownloadTaskStatus.PAUSED);
    //         return;
    //       }
    //       if (task.status == DownloadTaskStatus.CANCELLED) {
    //         print("CANCELLED");
    //         request.abort();
    //         client.close();
    //         await raf.close();
    //         await tempFile.delete();
    //         sendPort.send(DownloadTaskStatus.CANCELLED);
    //         return;
    //       }
    //       await raf.writeFrom(data);
    //       task.downloadedBytes += data.length;
    //
    //       // 计算当前时间与上一次更新时间的间隔
    //       final currentTime = DateTime.now();
    //       final timeDiff = currentTime.difference(lastUpdateTime).inMilliseconds;
    //
    //       // 如果时间间隔超过指定的最小更新间隔，或者已经下载完成，则更新进度
    //       if (task.status == DownloadTaskStatus.DOWNLOADING &&
    //           timeDiff >= MIN_PROGRESS_UPDATE_INTERVAL) {
    //         task.updateProgress();
    //         sendPort.send(task.progress);
    //         lastUpdateTime = currentTime;
    //       }
    //     },
    //     onDone: () async {
    //       await raf.close();
    //       await tempFile.rename(task.saveFile);
    //       task.updateProgress();
    //       sendPort.send(task.progress);
    //       sendPort.send(DownloadTaskStatus.COMPLETED);
    //     },
    //   );
    // } else {
    await for (var data in response) {
      if (task.status == DownloadTaskStatus.PAUSED) {
        print("PAUSED");
        request.abort();
        client.close();
        await raf.close();
        sendPort.send(DownloadTaskStatus.PAUSED);
        return;
      }
      if (task.status == DownloadTaskStatus.CANCELLED) {
        print("CANCELLED");
        request.abort();
        client.close();
        await raf.close();
        await tempFile.delete();
        sendPort.send(DownloadTaskStatus.CANCELLED);
        return;
      }
      await raf.writeFrom(data);
      task.downloadedBytes += data.length;

      // 计算当前时间与上一次更新时间的间隔
      final currentTime = DateTime.now();
      final timeDiff = currentTime.difference(lastUpdateTime).inMilliseconds;

      // 如果时间间隔超过指定的最小更新间隔，或者已经下载完成，则更新进度
      if (task.status == DownloadTaskStatus.DOWNLOADING &&
          timeDiff >= MIN_PROGRESS_UPDATE_INTERVAL) {
        task.updateProgress();
        sendPort.send(task.progress);
        lastUpdateTime = currentTime;
      }
    }

    await raf.close();
    // 原子性写入磁盘操作：将临时文件重命名为最终文件
    await tempFile.rename(task.saveFile);

    task.updateProgress();
    sendPort.send(task.progress);
    sendPort.send(DownloadTaskStatus.COMPLETED);
    // }
  } catch (e) {
    print('Download error: $e');
  }
}
