import 'dart:io';
import 'dart:typed_data';

import '../cache/lru_cache_singleton.dart';
import '../download/download_status.dart';
import '../download/download_task.dart';
import '../ext/file_ext.dart';
import '../ext/int_ext.dart';
import '../ext/log_ext.dart';
import '../ext/socket_ext.dart';
import '../ext/uri_ext.dart';
import '../global/config.dart';
import '../proxy/video_proxy.dart';
import 'url_parser.dart';

class UrlParserDefault implements UrlParser {
  @override
  bool match(Uri uri) {
    return true;
  }

  @override
  Future<Uint8List?> cache(DownloadTask task) async {
    Uint8List? dataMemory = await LruCacheSingleton().memoryGet(task.matchUrl);
    if (dataMemory != null) {
      logD('From memory: ${dataMemory.lengthInBytes.toMemorySize}');
      return dataMemory;
    }
    String filePath = '${await FileExt.createCachePath(task.uri.generateMd5)}'
        '/${task.saveFileName}';
    Uint8List? dataFile = await LruCacheSingleton().storageGet(filePath);
    if (dataFile != null) {
      logD('From file: ${filePath}');
      await LruCacheSingleton().memoryPut(task.matchUrl, dataFile);
      return dataFile;
    }
    return null;
  }

  @override
  Future<Uint8List?> download(DownloadTask task) async {
    logD('From network: ${task.url}');
    Uint8List? dataNetwork;
    String cachePath = await FileExt.createCachePath(task.uri.generateMd5);
    task.cacheDir = cachePath;
    await VideoProxy.downloadManager.executeTask(task);
    await for (DownloadTask taskStream in VideoProxy.downloadManager.stream) {
      if (taskStream.status == DownloadStatus.COMPLETED &&
          taskStream.matchUrl == task.matchUrl) {
        dataNetwork = Uint8List.fromList(taskStream.data);
        break;
      }
    }
    return dataNetwork;
  }

  @override
  Future<void> push(DownloadTask task) async {
    Uint8List? dataMemory = await LruCacheSingleton().memoryGet(task.matchUrl);
    if (dataMemory != null) return;
    String cachePath = await FileExt.createCachePath(task.uri.generateMd5);
    File file = File('$cachePath/${task.saveFileName}');
    if (await file.exists()) return;
    task.cacheDir = cachePath;
    await VideoProxy.downloadManager.addTask(task);
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
      logD(
          'Total memory size： ${await LruCacheSingleton().memoryFormatSize()}');
      logD('Request range： ${task.startRange}-${task.endRange}');

      int retry = 3;
      while (retry > 0) {
        Uint8List? data = await cache(task);
        if (data != null) {
          if (rangeStart % Config.segmentSize != 0) {
            data = data.sublist(rangeStart % Config.segmentSize);
          }
          if (data.lengthInBytes > Config.segmentSize) {
            await deleteExceedSizeFile(task);
            retry--;
            continue;
          } else {
            socket.add(data);
          }
          int count = 2;
          while (count > 0) {
            count--;
            task.startRange += Config.segmentSize;
            task.endRange = task.startRange + Config.segmentSize - 1;
            logD('Request range： ${task.startRange}-${task.endRange}');
            data = await cache(task);
            if (data != null) {
              if (data.lengthInBytes > Config.segmentSize) {
                await deleteExceedSizeFile(task);
                retry--;
                break;
              } else {
                socket.add(data);
              }
            }
          }
          break;
        } else {
          concurrent(task);
          task.priority += 10;
          data = await download(task);
          if (rangeStart % Config.segmentSize != 0) {
            data = data?.sublist(rangeStart % Config.segmentSize);
          }
          if (data != null) {
            if (data.lengthInBytes > Config.segmentSize) {
              await deleteExceedSizeFile(task);
              retry--;
              continue;
            } else {
              socket.add(data);
            }
          }
          break;
        }
      }
      await socket.flush();
      logD('Return request data: $uri range: $startRange-$endRange');
      return true;
    } catch (e) {
      logE('[UrlParserMp4] ⚠ ⚠ ⚠ parse error: $e');
      return false;
    } finally {
      await socket.close();
      logD('Connection closed\n');
    }
  }

  Future<void> deleteExceedSizeFile(DownloadTask task) async {
    String cachePath = await FileExt.createCachePath(task.uri.generateMd5);
    File file = File('$cachePath/${task.saveFileName}');
    if (await file.exists()) await file.delete();
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
      Uint8List? dataMemory =
          await LruCacheSingleton().memoryGet(newTask.matchUrl);
      if (dataMemory != null) isExit = true;
      String cachePath = await FileExt.createCachePath(task.uri.generateMd5);
      File file = File('$cachePath/${task.saveFileName}');
      if (await file.exists()) isExit = true;
      if (isExit) continue;
      logD("Asynchronous download start： ${newTask.toString()}");
      newTask.cacheDir = cachePath;
      await VideoProxy.downloadManager.executeTask(newTask);
      activeSize = VideoProxy.downloadManager.allTasks
          .where((e) => e.url == task.url)
          .length;
    }
  }

  @override
  void precache(String url, int cacheSegments, bool downloadNow) async {
    int count = 0;
    while (count < cacheSegments) {
      DownloadTask task = DownloadTask(uri: Uri.parse(url));
      task.startRange += Config.segmentSize * count;
      task.endRange = task.startRange + Config.segmentSize - 1;
      if (downloadNow) {
        Uint8List? data = await cache(task);
        if (data == null) download(task);
      } else {
        push(task);
      }
      count++;
    }
  }
}
