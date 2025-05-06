import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_video_cache/global/config.dart';

import '../download/download_isolate_pool.dart';
import '../download/download_status.dart';
import '../download/download_task.dart';
import '../ext/int_ext.dart';
import '../ext/log_ext.dart';
import '../memory/video_memory_cache.dart';
import '../proxy/video_proxy.dart';

class MP4Parser {
  Future<Uint8List?> downloadTask(DownloadTask task) async {
    logD('从网络中获取数据，正在下载中');
    Uint8List? netData;
    await VideoProxy.downloadManager.executeTask(task);
    await concurrent(task);
    await for (DownloadTask downloadTask in VideoProxy.downloadManager.stream) {
      if (downloadTask.status == DownloadStatus.COMPLETED &&
          downloadTask.matchUrl == task.matchUrl) {
        netData = Uint8List.fromList(downloadTask.data);
        break;
      } else if (downloadTask.status == DownloadStatus.FAILED &&
          downloadTask.matchUrl == task.matchUrl) {
        netData = null;
        break;
      }
    }
    return netData;
  }

  Future<Uint8List?> cacheTask(DownloadTask task) async {
    Uint8List? memoryCache = await VideoMemoryCache.get(task.matchUrl);
    if (memoryCache != null) {
      logD('从内存中获取数据: ${memoryCache.lengthInBytes.toMemorySize}');
      return memoryCache;
    }
    String cachePath = await DownloadIsolatePool.createVideoCachePath();
    File file = File('$cachePath/${task.saveFileName}');
    if (file.existsSync()) {
      logD('从文件中获取数据: ${file.path}');
      Uint8List fileCache = await file.readAsBytes();
      await VideoMemoryCache.put(task.matchUrl, fileCache);
      return fileCache;
    }
    return null;
  }

  Future<void> concurrent(DownloadTask task) async {
    int activeSize = VideoProxy.downloadManager.allTasks
        .where((e) => e.url == task.url)
        .length;
    DownloadTask newTask = task;
    while (activeSize < 3) {
      newTask = DownloadTask(
        uri: newTask.uri,
        startRange: newTask.startRange + Config.segmentSize,
        endRange: newTask.startRange + Config.segmentSize * 2 - 1,
      );
      bool isExit = VideoProxy.downloadManager.allTasks
          .where((e) => e.matchUrl == newTask.matchUrl)
          .isNotEmpty;
      Uint8List? memoryCache = await VideoMemoryCache.get(newTask.matchUrl);
      if (memoryCache != null) isExit = true;
      String cachePath = await DownloadIsolatePool.createVideoCachePath();
      File file = File('$cachePath/${task.saveFileName}');
      if (file.existsSync()) isExit = true;
      if (isExit) continue;
      await VideoProxy.downloadManager.executeTask(newTask);
      logD("异步下载开始： ${newTask.toString()}");
      activeSize = VideoProxy.downloadManager.allTasks
          .where((e) => e.url == task.url)
          .length;
    }
  }
}
