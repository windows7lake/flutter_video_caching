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

/// MP4 URL parser
class UrlParserMp4 implements UrlParser {
  /// Get the cache data from memory or file.
  /// If there is no cache data, return null.
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

  /// Download the data from network.
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

  /// Push the task to the download manager.
  /// If the task is already in the download manager, do nothing.
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

  /// Parse the request and return the data.
  /// If the request is not valid, return false.
  ///
  /// Large file download is divided into segments, and each segment is 2Mb by default.
  /// The segment size can be changed by modifying the `Config.segmentSize` value.
  @override
  Future<bool> parse(
    Socket socket,
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      RegExp exp = RegExp(r'bytes=(\d+)-(\d*)');
      RegExpMatch? rangeMatch = exp.firstMatch(headers['range'] ?? '');
      int rangeStart = int.tryParse(rangeMatch?.group(1) ?? '0') ?? 0;
      int rangeEnd = int.tryParse(rangeMatch?.group(2) ?? '0') ?? 0;
      bool partial = rangeStart > 0 || rangeEnd > 0;
      List<String> responseHeaders = <String>[
        partial ? 'HTTP/1.1 206 Partial Content' : 'HTTP/1.1 200 OK',
        'Accept-Ranges: bytes',
        'Content-Type: video/mp4',
        'Connection: keep-alive',
      ];

      if (Platform.isAndroid) {
        await parseAndroid(socket, uri, responseHeaders, rangeStart, rangeEnd);
      } else {
        if (rangeStart == 0 && rangeEnd == 1) {
          int contentLength = await head(uri);
          responseHeaders.add('content-range: bytes 0-1/$contentLength');
          await socket.append(responseHeaders.join('\r\n'));
          await socket.append([0]);
          await socket.close();
          return true;
        }

        int contentLength = rangeEnd - rangeStart + 1;
        responseHeaders.add('content-length: $contentLength');
        await socket.append(responseHeaders.join('\r\n'));
        logD('content-range：$rangeStart-$rangeEnd');
        logD('content-length：$contentLength');

        bool downloading = true;
        int startRange = rangeStart - (rangeStart % Config.segmentSize);
        int endRange = startRange + Config.segmentSize - 1;
        while (downloading) {
          DownloadTask task = DownloadTask(
            uri: uri,
            startRange: startRange,
            endRange: endRange,
          );
          logD('Request range：${task.startRange}-${task.endRange}');
          logD('Request length：${task.endRange! - task.startRange}');

          Uint8List? data = await cache(task);
          if (data == null) {
            concurrent(task);
            task.priority += 10;
            data = await download(task);
          }

          if (data == null) return false;
          int startIndex = startRange % Config.segmentSize;
          if (startIndex != 0) {
            int? endIndex;
            if (data.length > contentLength) {
              endIndex = startIndex + contentLength;
              logD('startIndex: $startIndex endIndex : $endIndex');
              logD('start length: ${endIndex - startIndex}');
            }
            data = data.sublist(startIndex, endIndex);
          }
          await socket.append(data);
          startRange += Config.segmentSize;
          endRange = startRange + Config.segmentSize - 1;
          if (startRange > rangeEnd) {
            // logW('startRange: $startRange > rangeEnd: $rangeEnd');
            downloading = false;
          }
        }
      }
      await socket.flush();
      return true;
    } catch (e) {
      logE('[UrlParserMp4] ⚠ ⚠ ⚠ parse error: $e');
      return false;
    } finally {
      await socket.close();
      logD('Connection closed\n');
    }
  }

  Future<void> parseAndroid(
    Socket socket,
    Uri uri,
    List<String> responseHeaders,
    int rangeStart,
    int rangeEnd,
  ) async {
    await socket.append(responseHeaders.join('\r\n'));
    int startRange = rangeStart - (rangeStart % Config.segmentSize);
    int endRange = startRange + Config.segmentSize - 1;
    DownloadTask task = DownloadTask(
      uri: uri,
      startRange: startRange,
      endRange: endRange,
    );
    logD('Total memory： ${await LruCacheSingleton().memoryFormatSize()}');
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
          await socket.append(data);
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
              await socket.append(data);
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
            await socket.append(data);
          }
        }
        break;
      }
    }
    await socket.flush();
    logD('Return request data: $uri range: $startRange-$endRange');
  }

  Future<int> head(Uri uri) async {
    HttpClient client = HttpClient();
    HttpClientRequest request = await client.headUrl(uri);
    HttpClientResponse response = await request.close();
    client.close();
    return response.contentLength;
  }

  /// Delete the file if it exceeds the size limit.
  /// Sometimes because network problem, the download file size is larger than
  /// the segment size, so we need to delete and re-download the file.
  /// Or it may lead to source error.
  Future<void> deleteExceedSizeFile(DownloadTask task) async {
    String cachePath = await FileExt.createCachePath(task.uri.generateMd5);
    File file = File('$cachePath/${task.saveFileName}');
    if (await file.exists()) await file.delete();
  }

  /// Download task concurrently.<br>
  /// The maximum number of concurrent downloads is 3. Too many concurrent
  /// connections will result in long waiting times.<br>
  /// If the number of concurrent downloads is less than 3, create a new task and
  /// add it to the download queue.<br>
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

  /// Pre-cache the data from network.
  ///
  /// [cacheSegments] is the number of segments to cache.
  /// [downloadNow] is whether to download the data now or just push the task to the queue.
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
