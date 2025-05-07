import 'dart:io';
import 'dart:typed_data';

import '../download/download_isolate_pool.dart';
import '../download/download_status.dart';
import '../download/download_task.dart';
import '../ext/int_ext.dart';
import '../ext/log_ext.dart';
import '../ext/socket_ext.dart';
import '../global/config.dart';
import '../memory/video_memory_cache.dart';
import '../proxy/video_proxy.dart';
import 'url_parser.dart';

class UrlParserMp4 implements UrlParser {
  @override
  bool match(Uri uri) {
    return uri.path.endsWith('.mp4');
  }

  @override
  Future<Uint8List?> cache(DownloadTask task) async {
    Uint8List? dataMemory = await VideoMemoryCache.get(task.matchUrl);
    if (dataMemory != null) {
      logD('从内存中获取: ${dataMemory.lengthInBytes.toMemorySize}');
      return dataMemory;
    }
    String cachePath = await DownloadIsolatePool.createVideoCachePath();
    File file = File('$cachePath/${task.saveFile}');
    if (await file.exists()) {
      logD('从文件中获取: ${file.path}');
      Uint8List dataFile = await file.readAsBytes();
      await VideoMemoryCache.put(task.matchUrl, dataFile);
      return dataFile;
    }
    return null;
  }

  @override
  Future<Uint8List?> download(DownloadTask task) async {
    logD('从网络中获取: ${task.url}');
    Uint8List? dataNetwork;
    await VideoProxy.downloadManager.executeTask(task);
    await for (DownloadTask taskStream in VideoProxy.downloadManager.stream) {
      if (taskStream.status == DownloadStatus.COMPLETED &&
          taskStream.url == task.url) {
        dataNetwork = Uint8List.fromList(taskStream.data);
        break;
      }
    }
    return dataNetwork;
  }

  @override
  Future<bool> parse(
    Socket socket,
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      RegExp exp = RegExp(r'bytes=(\d+)-(\d*)');
      RegExpMatch? rangeMatch = exp.firstMatch(headers['range'] ?? '');
      int rangeStart = int.parse(rangeMatch?.group(1) ?? '0');
      String responseHeaders = <String>[
        rangeStart > 0 ? 'HTTP/1.1 206 Partial Content' : 'HTTP/1.1 200 OK',
        'Accept-Ranges: bytes',
        'Content-Type: video/mp4',
        'Connection: keep-alive',
      ].join('\r\n');
      await socket.append(responseHeaders);

      int startRange = rangeStart - (rangeStart % Config.segmentSize);
      int endRange = startRange + Config.segmentSize - 1;
      DownloadTask task = DownloadTask(
        uri: uri,
        startRange: startRange,
        endRange: endRange,
      );
      logD('当前共占内存： ${(await VideoMemoryCache.size()).toMemorySize}');
      logD('解析链接 range： ${task.startRange}-${task.endRange}');

      Uint8List? data = await cache(task);
      if (data != null) {
        if (rangeStart % Config.segmentSize != 0) {
          data = data.sublist(rangeStart % Config.segmentSize);
        }
        socket.add(data);
        int count = 2;
        while (count > 0) {
          count--;
          task.startRange += Config.segmentSize;
          task.endRange = task.startRange + Config.segmentSize - 1;
          logD('解析链接 range： ${task.startRange}-${task.endRange}');
          data = await cache(task);
          if (data == null) break;
          socket.add(data);
        }
      } else {
        data = await download(task);
        if (rangeStart % Config.segmentSize != 0) {
          data = data?.sublist(rangeStart % Config.segmentSize);
        }
        if (data != null) socket.add(data);
      }
      await socket.flush();
      logD('返回请求数据: $uri range: $startRange-$endRange');
      return true;
    } catch (e) {
      logE('⚠ ⚠ ⚠ UrlParserMp4 解析异常: $e');
      return false;
    } finally {
      await socket.close(); // 确保连接关闭
      logD('连接关闭\n');
    }
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

  @override
  void precache(String url, int cacheSegments, bool downloadNow) {}

  @override
  Future<void> push(DownloadTask task) async {}
}
