import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../cache/lru_cache_singleton.dart';
import '../download/download_status.dart';
import '../download/download_task.dart';
import '../ext/file_ext.dart';
import '../ext/int_ext.dart';
import '../ext/log_ext.dart';
import '../ext/socket_ext.dart';
import '../ext/string_ext.dart';
import '../ext/uri_ext.dart';
import '../global/config.dart';
import '../proxy/video_proxy.dart';
import 'url_parser.dart';

/// Default URL parser implementation.
/// Handles caching, downloading, and parsing of common video files.
/// Implements the [UrlParser] interface for common video files.
class UrlParserDefault implements UrlParser {
  /// Retrieves cached data for the given [task] from memory or file.
  ///
  /// Returns a [Uint8List] containing the cached data if available,
  /// or `null` if the data is not cached.
  @override
  Future<Uint8List?> cache(DownloadTask task) async {
    Uint8List? dataMemory = await LruCacheSingleton().memoryGet(task.matchUrl);
    if (dataMemory != null) {
      logD('From memory: ${dataMemory.lengthInBytes.toMemorySize}');
      return dataMemory;
    }
    Uint8List? dataFile = await LruCacheSingleton().storageGet(task.matchUrl);
    if (dataFile != null) {
      logD('From file: ${task.matchUrl}');
      await LruCacheSingleton().memoryPut(task.matchUrl, dataFile);
      return dataFile;
    }
    return null;
  }

  /// Downloads data from the network for the given [task].
  ///
  /// Returns a [Uint8List] containing the downloaded data,
  /// or `null` if the download fails.
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

  /// Pushes the [task] to the download manager for processing.
  /// If the task is already in the download manager or cache, does nothing.
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

  /// Parses the request and returns the data to the [socket].
  ///
  /// Handles HTTP range requests for large file downloads, splitting the file
  /// into segments (default 2MB, configurable via [Config.segmentSize]).
  ///
  /// Returns `true` if parsing and response succeed, otherwise `false`.
  @override
  Future<bool> parse(
    Socket socket,
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      RegExp exp = RegExp(r'bytes=(\d+)-(\d*)');
      RegExpMatch? rangeMatch = exp.firstMatch(headers['range'] ?? '');
      int requestRangeStart = int.tryParse(rangeMatch?.group(1) ?? '0') ?? 0;
      int requestRangeEnd = int.tryParse(rangeMatch?.group(2) ?? '0') ?? -1;
      bool partial = requestRangeStart > 0 || requestRangeEnd > 0;
      List<String> responseHeaders = <String>[
        partial ? 'HTTP/1.1 206 Partial Content' : 'HTTP/1.1 200 OK',
        'Accept-Ranges: bytes',
        'Content-Type: video/mp4',
        'Connection: keep-alive',
      ];

      if (Platform.isAndroid) {
        await parseAndroid(
          socket,
          uri,
          responseHeaders,
          requestRangeStart,
          requestRangeEnd,
          headers,
        );
      } else {
        await parseIOS(
          socket,
          uri,
          responseHeaders,
          requestRangeStart,
          requestRangeEnd,
          headers,
        );
      }
      await socket.flush();
      return true;
    } catch (e) {
      logW('[UrlParserDefault] ⚠ ⚠ ⚠ parse error: $e');
      return false;
    } finally {
      await socket.close();
      logD('Connection closed\n');
    }
  }

  /// Parses and responds to range requests on Android.
  ///
  /// Handles segmented download and response for large files.
  Future<void> parseAndroid(
    Socket socket,
    Uri uri,
    List<String> responseHeaders,
    int requestRangeStart,
    int requestRangeEnd,
    Map<String, String> headers,
  ) async {
    DownloadTask task =
        DownloadTask(uri: uri, startRange: 0, endRange: 1, headers: headers);
    Uint8List? data = await cache(task);
    int contentLength = 0;
    if (data != null) {
      contentLength = int.tryParse(Utf8Codec().decode(data)) ?? 0;
    }
    if (contentLength == 0) {
      contentLength = await head(uri, headers: headers);
      String filePath = '${await FileExt.createCachePath(task.uri.generateMd5)}'
          '/${task.saveFileName}';
      File file = File(filePath);
      file.writeAsString(contentLength.toString());
      LruCacheSingleton().storagePut(task.matchUrl, file);
    }

    requestRangeEnd = contentLength - 1;
    responseHeaders.add('content-length: ${contentLength - requestRangeStart}');
    responseHeaders.add('content-range: bytes '
        '$requestRangeStart-$requestRangeEnd/$contentLength');
    await socket.append(responseHeaders.join('\r\n'));

    bool downloading = true;
    int startRange =
        requestRangeStart - (requestRangeStart % Config.segmentSize);
    int endRange = startRange + Config.segmentSize - 1;
    int retry = 3;
    while (downloading) {
      DownloadTask task = DownloadTask(
        uri: uri,
        startRange: startRange,
        endRange: endRange,
        headers: headers,
      );
      logD('Request range：${task.startRange}-${task.endRange}');

      Uint8List? data = await cache(task);
      if (data == null) {
        concurrent(task, headers);
        task.priority += 10;
        data = await download(task);
      }
      if (data == null) {
        retry--;
        if (retry == 0) {
          downloading = false;
          break;
        }
        continue;
      }

      int startIndex = 0;
      int? endIndex;
      if (startRange < requestRangeStart) {
        startIndex = requestRangeStart - startRange;
      }
      if (endRange > requestRangeEnd) {
        endIndex = requestRangeEnd - startRange + 1;
      }
      data = data.sublist(startIndex, endIndex);
      socket.done.then((value) {
        downloading = false;
      }).catchError((e) {
        downloading = false;
      });
      bool success = await socket.append(data);
      if (!success) downloading = false;
      startRange += Config.segmentSize;
      endRange = startRange + Config.segmentSize - 1;
      if (startRange > requestRangeEnd) {
        downloading = false;
      }
    }
  }

  /// Parses and responds to range requests on iOS.
  ///
  /// Handles segmented download and response for large files.
  Future<void> parseIOS(
    Socket socket,
    Uri uri,
    List<String> responseHeaders,
    int requestRangeStart,
    int requestRangeEnd,
    Map<String, String> headers,
  ) async {
    if ((requestRangeStart == 0 && requestRangeEnd == 1) ||
        requestRangeEnd == -1) {
      DownloadTask task =
          DownloadTask(uri: uri, startRange: 0, endRange: 1, headers: headers);
      Uint8List? data = await cache(task);
      int contentLength = 0;
      if (data != null) {
        contentLength = int.tryParse(Utf8Codec().decode(data)) ?? 0;
      }
      if (contentLength == 0) {
        contentLength = await head(uri, headers: headers);
        String filePath =
            '${await FileExt.createCachePath(task.uri.generateMd5)}'
            '/${task.saveFileName}';
        File file = File(filePath);
        file.writeAsString(contentLength.toString());
        LruCacheSingleton().storagePut(task.matchUrl, file);
      }
      if (requestRangeStart == 0 && requestRangeEnd == 1) {
        responseHeaders.add('content-range: bytes 0-1/$contentLength');
        await socket.append(responseHeaders.join('\r\n'));
        await socket.append([0]);
        await socket.close();
        return;
      } else if (requestRangeEnd == -1) {
        requestRangeEnd = contentLength - 1;
      }
    }

    int contentLength = requestRangeEnd - requestRangeStart + 1;
    responseHeaders.add('content-length: $contentLength');
    await socket.append(responseHeaders.join('\r\n'));
    logD('content-range：$requestRangeStart-$requestRangeEnd');
    logD('content-length：$contentLength');

    bool downloading = true;
    int startRange =
        requestRangeStart - (requestRangeStart % Config.segmentSize);
    int endRange = startRange + Config.segmentSize - 1;
    int retry = 3;
    while (downloading) {
      DownloadTask task = DownloadTask(
        uri: uri,
        startRange: startRange,
        endRange: endRange,
        headers: headers,
      );
      logD('Request range：${task.startRange}-${task.endRange}');

      Uint8List? data = await cache(task);
      if (data == null) {
        concurrent(task, headers);
        task.priority += 10;
        data = await download(task);
      }
      if (data == null) {
        retry--;
        if (retry == 0) {
          downloading = false;
          break;
        }
        continue;
      }

      int startIndex = 0;
      int? endIndex;
      if (startRange < requestRangeStart) {
        startIndex = requestRangeStart - startRange;
      }
      if (endRange > requestRangeEnd) {
        endIndex = requestRangeEnd - startRange + 1;
      }
      data = data.sublist(startIndex, endIndex);
      socket.done.then((value) {
        downloading = false;
      }).catchError((e) {
        downloading = false;
      });
      bool success = await socket.append(data);
      if (!success) downloading = false;
      startRange += Config.segmentSize;
      endRange = startRange + Config.segmentSize - 1;
      if (startRange > requestRangeEnd) {
        downloading = false;
      }
    }
  }

  /// Sends a HEAD request to get the content length of the resource at [uri].
  ///
  /// Returns the content length as an [int].
  Future<int> head(Uri uri, {Map<String, Object>? headers}) async {
    HttpClient client = HttpClient();
    HttpClientRequest request = await client.headUrl(uri);
    if (headers != null) {
      headers.forEach((key, value) {
        if (key == 'host' && value == Config.serverUrl) return;
        request.headers.set(key, value);
      });
    }
    HttpClientResponse response = await request.close();
    client.close();
    return response.contentLength;
  }

  /// Deletes the file if it exceeds the expected segment size.
  ///
  /// Used to handle cases where network issues cause oversized downloads.
  Future<void> deleteExceedSizeFile(DownloadTask task) async {
    String cachePath = await FileExt.createCachePath(task.uri.generateMd5);
    File file = File('$cachePath/${task.saveFileName}');
    if (await file.exists()) await file.delete();
  }

  /// Manages concurrent download tasks.
  ///
  /// Ensures that no more than 3 concurrent downloads are active for the same URL.
  /// If the number of concurrent downloads is less than 3, creates and adds new tasks.
  Future<void> concurrent(
    DownloadTask task,
    Map<String, String> headers,
  ) async {
    int activeSize = VideoProxy.downloadManager.allTasks
        .where((e) => e.url == task.url)
        .length;
    DownloadTask newTask = task;
    while (activeSize < 3) {
      newTask = DownloadTask(
        uri: newTask.uri,
        startRange: newTask.startRange + Config.segmentSize,
        endRange: newTask.startRange + Config.segmentSize * 2 - 1,
        headers: headers,
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

  /// Pre-caches data from the network.
  ///
  /// [cacheSegments]: Number of segments to cache.
  /// [downloadNow]: If true, downloads immediately; otherwise, pushes tasks to the queue.
  /// [progressListen]: If true, returns a [StreamController] with progress updates.
  ///
  /// Returns a [StreamController] emitting progress maps, or `null` if not listening.
  @override
  Future<StreamController<Map>?> precache(
    String url,
    Map<String, Object>? headers,
    int cacheSegments,
    bool downloadNow,
    bool progressListen,
  ) async {
    StreamController<Map>? _streamController;
    if (progressListen) _streamController = StreamController();
    int contentLength = await head(url.toSafeUri(), headers: headers);
    if (contentLength > 0) {
      int segmentSize = contentLength ~/ Config.segmentSize +
          (contentLength % Config.segmentSize > 0 ? 1 : 0);
      if (cacheSegments > segmentSize) {
        cacheSegments = segmentSize;
      }
    }
    int downloadedSize = 0;
    int totalSize = cacheSegments;
    int count = 0;
    while (count < cacheSegments) {
      DownloadTask task = DownloadTask(uri: url.toSafeUri(), headers: headers);
      // Set the start and end range for each segment
      task.startRange += Config.segmentSize * count;
      task.endRange = task.startRange + Config.segmentSize - 1;
      count++;
      if (downloadNow) {
        Uint8List? data = await cache(task);
        if (data != null) {
          downloadedSize += 1;
          _streamController?.sink.add({
            'progress': downloadedSize / totalSize,
            'url': task.url,
            'startRange': task.startRange,
            'endRange': task.endRange,
          });
          continue;
        }
        download(task).whenComplete(() {
          downloadedSize += 1;
          _streamController?.sink.add({
            'progress': downloadedSize / totalSize,
            'url': task.url,
            'startRange': task.startRange,
            'endRange': task.endRange,
          });
        });
      } else {
        push(task);
      }
    }
    return _streamController;
  }
}
