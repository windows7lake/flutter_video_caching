import 'dart:io';
import 'dart:typed_data';

import '../download/download_isolate_pool.dart';
import '../download/download_status.dart';
import '../download/download_task.dart';
import '../ext/int_ext.dart';
import '../ext/log_ext.dart';
import '../ext/string_ext.dart';
import '../memory/video_memory_cache.dart';
import '../proxy/video_proxy.dart';

class MP4Parser {
  Future<Uint8List?> downloadTask(DownloadTask task) async {
    logD('从网络中获取数据，正在下载中');
    Uint8List? netData;
    await VideoProxy.downloadManager.executeTask(task);
    await for (DownloadTask downloadTask in VideoProxy.downloadManager.stream) {
      if (downloadTask.status == DownloadStatus.COMPLETED &&
          downloadTask.url == task.url) {
        netData = Uint8List.fromList(downloadTask.data);
        break;
      } else if (downloadTask.status == DownloadStatus.FAILED &&
          downloadTask.url == task.url) {
        netData = null;
        break;
      }
    }
    return netData;
  }

  Future<Uint8List?> cacheTask(DownloadTask task) async {
    final md5 = '${task.url}-${task.endRange}'.generateMd5;
    Uint8List? memoryCache = await VideoMemoryCache.get(md5);
    if (memoryCache != null) {
      logD('从内存中获取数据: ${memoryCache.lengthInBytes.toMemorySize}');
      logD('当前内存占用: ${(await VideoMemoryCache.size()).toMemorySize}');
      return memoryCache;
    }
    String cachePath = await DownloadIsolatePool.createVideoCachePath();
    File file = File('$cachePath/${task.saveFile}-${task.endRange}');
    if (file.existsSync()) {
      logD('从文件中获取数据');
      Uint8List fileCache = await file.readAsBytes();
      await VideoMemoryCache.put(md5, fileCache);
      return fileCache;
    }
    return null;
  }
}
