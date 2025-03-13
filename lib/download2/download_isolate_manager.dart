import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';

import 'download_task.dart';

// 定义进度更新的最小时间间隔（毫秒）
const int MIN_PROGRESS_UPDATE_INTERVAL = 500;

// 下载隔离管理器类
class DownloadIsolateManager {
  static void startDownload(DownloadTask task, Function(String) onCompleted,
      Function(String, double) onProgressUpdate) async {
    final appDir = await getApplicationDocumentsDirectory();
    task.saveFile = '${appDir.path}/${task.saveFile}';

    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _downloadIsolateEntry,
      [task, receivePort.sendPort],
    );

    receivePort.listen((message) {
      if (message is double) {
        print("receivePort: $message  task.progress: ${task.progress}");
        onProgressUpdate(task.id, task.progress);
      } else if (message == 'completed') {
        task.status = DownloadTaskStatus.COMPLETED;
        onCompleted(task.id);
        receivePort.close();
        isolate.kill(priority: Isolate.immediate);
      }
    });
  }
}

// 下载任务在 Isolate 中执行的入口函数
void _downloadIsolateEntry(List<dynamic> args) {
  final DownloadTask task = args[0];
  final SendPort sendPort = args[1];

  _downloadFile(task, sendPort);
}

// 下载文件的具体实现
void _downloadFile(DownloadTask task, SendPort sendPort) async {
  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(task.url));

    // 设置 Range 头，从已下载的位置继续下载
    if (task.downloadedBytes > 0) {
      request.headers.add('Range', 'bytes=${task.downloadedBytes}-');
    }

    final response = await request.close();

    // 检查 contentLength 是否有效
    if (response.contentLength == -1) {
      print('Failed to get the total file size.');
      return;
    }

    // 计算文件总大小
    final totalBytes = task.downloadedBytes + response.contentLength;
    task.totalBytes = totalBytes;
    task.updateProgress();

    final tempFilePath = '${task.saveFile}.temp';
    final tempFile = File(tempFilePath);
    final raf = await tempFile.open(mode: FileMode.append);

    // 记录上一次更新进度的时间
    DateTime lastUpdateTime = DateTime.now();

    await for (var data in response) {
      if (task.status == DownloadTaskStatus.PAUSED) {
        await raf.close();
        task.updateProgress();
        sendPort.send(task.progress);
        return;
      }
      if (task.status == DownloadTaskStatus.CANCELLED) {
        await raf.close();
        await tempFile.delete();
        return;
      }
      await raf.writeFrom(data);
      task.downloadedBytes += data.length;

      // 计算当前时间与上一次更新时间的间隔
      final currentTime = DateTime.now();
      final timeDiff = currentTime.difference(lastUpdateTime).inMilliseconds;

      // 如果时间间隔超过指定的最小更新间隔，或者已经下载完成，则更新进度
      if ((timeDiff >= MIN_PROGRESS_UPDATE_INTERVAL ||
              task.downloadedBytes == totalBytes) &&
          task.status == DownloadTaskStatus.DOWNLOADING) {
        task.updateProgress();
        sendPort.send(task.progress);
        lastUpdateTime = currentTime;
      }
    }

    await raf.close();
    // 原子性写入磁盘操作：将临时文件重命名为最终文件
    await tempFile.rename(task.saveFile);
    sendPort.send('completed');
  } catch (e) {
    print('Download error: $e');
  }
}
