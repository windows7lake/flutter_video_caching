import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

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

/// MP4 URL parser implementation.
/// Handles caching, downloading, and parsing of MP4 video files.
class UrlParserMp4 implements UrlParser {
  /// Retrieves cached data for the given [task] from memory or file.
  ///
  /// Returns a [Uint8List] containing the cached data if available,
  /// or `null` if the data is not cached.
  @override
  Future<Uint8List?> cache(DownloadTask task) async {
    Uint8List? dataMemory = await LruCacheSingleton().memoryGet(task.matchUrl);
    if (dataMemory != null) {
      logD(
        'From memory: ${dataMemory.lengthInBytes.toMemorySize}, '
        'total memory size: ${await LruCacheSingleton().memoryFormatSize()}'
        'Request range：${task.startRange}-${task.endRange}',
      );
      return dataMemory;
    }
    Uint8List? dataFile = await LruCacheSingleton().storageGet(task.matchUrl);
    if (dataFile != null) {
      logD(
        'From file: ${task.matchUrl} '
        'Request range：${task.startRange}-${task.endRange}',
      );
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
    task.cacheDir = await FileExt.createCachePath(task.uri.generateMd5);
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
      // Implementation for parsing and responding to HTTP range requests.
      // Handles both Android and iOS platforms.
      RegExp exp = RegExp(r'bytes=(\d+)-(\d*)');
      RegExpMatch? rangeMatch = exp.firstMatch(headers['range'] ?? '');
      int requestRangeStart = int.tryParse(rangeMatch?.group(1) ?? '0') ?? 0;
      int requestRangeEnd = int.tryParse(rangeMatch?.group(2) ?? '0') ?? -1;
      // iOS may request `Range: bytes=0-` for normal startup. That is still a
      // range request and AVPlayer expects a 206 with Content-Range; returning
      // 200 makes the proxy look non-range-capable and delays startup.
      bool partial = rangeMatch != null;
      List<String> responseHeaders = <String>[
        partial ? 'HTTP/1.1 206 Partial Content' : 'HTTP/1.1 200 OK',
        'Accept-Ranges: bytes',
        'Content-Type: video/mp4',
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
          partial,
          headers,
        );
      }
      await socket.flush();
      return true;
    } catch (e) {
      // Handles any errors during parsing.
      logW('[UrlParserMp4] ⚠ ⚠ ⚠ parse error: $e');
      return false;
    } finally {
      // Ensures the socket is closed after processing.
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
    DownloadTask task = DownloadTask(
      uri: uri,
      startRange: 0,
      endRange: 1,
      headers: headers,
    );
    Uint8List? data = await cache(task);
    int contentLength = 0;
    if (data != null) {
      contentLength = int.tryParse(Utf8Codec().decode(data)) ?? 0;
    }
    if (contentLength == 0) {
      contentLength = await head(uri, headers: headers);
      await _cacheContentLength(task, contentLength);
    }

    requestRangeEnd = contentLength - 1;
    responseHeaders.add('content-length: ${contentLength - requestRangeStart}');
    responseHeaders.add(
      'content-range: bytes '
      '$requestRangeStart-$requestRangeEnd/$contentLength',
    );
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
      logD(
        'Start ${task.url} '
        'Request range：${task.startRange}-${task.endRange}',
      );

      // Submit following segments before serving the current segment. When the
      // current segment is already cached, the old flow returned immediately
      // and never warmed the next segment, so UI "preload" did not help the
      // next swipe.
      await concurrent(task, headers, contentLength);
      Uint8List? data = await cache(task);
      // if the task has been added, wait for the download to complete
      bool exitUri = VideoProxy.downloadManager.isTaskExit(task);
      if (exitUri) {
        while (data == null) {
          await Future.delayed(const Duration(milliseconds: 100));
          data = await cache(task);
        }
      }
      if (data == null) {
        task.priority += 2;
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
    bool partial,
    Map<String, String> headers,
  ) async {
    final totalContentLength = await _contentLength(uri, headers);
    final rangeResponse = Mp4RangeResponse.fromRequest(
      start: requestRangeStart,
      end: requestRangeEnd,
      totalLength: totalContentLength,
      partial: partial,
    );
    responseHeaders.add('content-length: ${rangeResponse.contentLength}');
    if (rangeResponse.contentRangeHeader != null) {
      responseHeaders.add(rangeResponse.contentRangeHeader!);
    }
    await socket.append(responseHeaders.join('\r\n'));

    bool downloading = true;
    int startRange =
        rangeResponse.start - (rangeResponse.start % Config.segmentSize);
    int endRange = startRange + Config.segmentSize - 1;
    int retry = 3;
    while (downloading) {
      DownloadTask task = DownloadTask(
        uri: uri,
        startRange: startRange,
        endRange: endRange,
        headers: headers,
      );
      logD(
        'Start ${task.url} '
        'Request range：${task.startRange}-${task.endRange}',
      );

      await concurrent(task, headers, totalContentLength);
      Uint8List? data = await cache(task);
      // if the task has been added, wait for the download to complete
      bool exitUri = VideoProxy.downloadManager.isTaskExit(task);
      if (exitUri) {
        while (data == null) {
          await Future.delayed(const Duration(milliseconds: 100));
          data = await cache(task);
        }
      }
      if (data == null) {
        task.priority += 2;
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
      if (startRange < rangeResponse.start) {
        startIndex = rangeResponse.start - startRange;
      }
      if (endRange > rangeResponse.end) {
        endIndex = rangeResponse.end - startRange + 1;
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
      if (startRange > rangeResponse.end) {
        downloading = false;
      }
    }
  }

  Future<int> _contentLength(
    Uri uri,
    Map<String, String> headers,
  ) async {
    // Store content length in the existing first-segment metadata slot. Range
    // normalization and tail clamping both need total length, and avoiding a
    // HEAD on every iOS `bytes=0-` request keeps startup cheap.
    final task = DownloadTask(
      uri: uri,
      startRange: 0,
      endRange: 1,
      headers: headers,
    );
    final data = await cache(task);
    var contentLength = 0;
    if (data != null) {
      contentLength = int.tryParse(Utf8Codec().decode(data)) ?? 0;
    }
    if (contentLength == 0) {
      contentLength = await head(uri, headers: headers);
      await _cacheContentLength(task, contentLength);
    }
    return contentLength;
  }

  /// Sends a HEAD request to get the content length of the resource at [uri].
  ///
  /// Returns the content length as an [int].
  Future<int> head(Uri uri, {Map<String, Object>? headers}) async {
    Dio client = VideoProxy.httpClientBuilderImpl.create();
    if (headers != null) {
      headers.forEach((key, value) {
        String keyLower = key.toLowerCase();
        if (keyLower == 'host' && value == Config.serverUrl) return;
        if (keyLower == 'range') return;
        client.options.headers[key] = value;
      });
    }
    Response response = await client.headUri(uri);
    // Get content-length from content-range, if failed get from content-length
    String? contentRange = response.headers.value(
      HttpHeaders.contentRangeHeader,
    );
    if (contentRange != null) {
      final match = RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(contentRange);
      if (match != null && match.group(3) != null) {
        String total = match.group(3)!;
        if (total.isNotEmpty && total != '0') {
          return int.parse(total);
        }
      }
    }
    String? contentLength = response.headers.value(
      HttpHeaders.contentLengthHeader,
    );
    client.close();
    return int.tryParse(contentLength ?? '-1') ?? -1;
  }

  Future<void> _cacheContentLength(
    DownloadTask task,
    int contentLength,
  ) async {
    try {
      // Content length is already known by the caller. This small metadata file
      // only speeds up later requests, so failures must not block the response.
      String filePath = '${await FileExt.createCachePath(task.uri.generateMd5)}'
          '/${task.saveFileName}';
      File file = File(filePath);
      await file.writeAsString(contentLength.toString());
      await LruCacheSingleton().storagePut(task.matchUrl, file);
    } catch (e) {
      logE('[UrlParserMp4] Cache content length failed: $e');
    }
  }

  /// Manages concurrent download tasks.
  ///
  /// Ensures that no more than 3 concurrent downloads are active for the same URL.
  /// If the number of concurrent downloads is less than 3, creates and adds new tasks.
  Future<void> concurrent(
    DownloadTask task,
    Map<String, String> headers,
    int contentLength,
  ) async {
    DownloadTask newTask = task;
    int activeSize = VideoProxy.downloadManager.allTasks
        .where((e) => e.url == newTask.url)
        .length;
    while (activeSize < 2) {
      final nextStartRange = newTask.startRange + Config.segmentSize;
      if (contentLength > 0 && nextStartRange >= contentLength) return;
      // Clamp the last warmed segment to the real file boundary. Some servers
      // reject over-wide byte ranges, which can leave a "preloaded" tail
      // segment missing.
      newTask = DownloadTask(
        uri: newTask.uri,
        startRange: nextStartRange,
        endRange: _segmentEndRange(nextStartRange, contentLength),
        headers: headers,
      );
      bool isExit = VideoProxy.downloadManager.allTasks
          .where((e) => e.matchUrl == newTask.matchUrl)
          .isNotEmpty;
      Uint8List? dataMemory = await LruCacheSingleton().memoryGet(
        newTask.matchUrl,
      );
      if (dataMemory != null) isExit = true;
      newTask.cacheDir = await FileExt.createCachePath(newTask.uri.generateMd5);
      File file = File(newTask.savePath);
      if (file.existsSync()) isExit = true;
      if (isExit) continue;
      logD("Asynchronous download start： ${newTask.toString()}");
      await VideoProxy.downloadManager.executeTask(newTask);
      activeSize = VideoProxy.downloadManager.allTasks
          .where((e) => e.url == newTask.url)
          .length;
    }
  }

  /// Whether the video is cached.
  ///
  /// [url]: The video URL to check.
  /// [headers]: Optional HTTP headers to use for the request.
  /// [cacheSegments]: Number of segments to cache.
  ///
  /// Returns `true` if the video is cached, otherwise `false`.
  @override
  Future<bool> isCached(
    String url,
    Map<String, Object>? headers,
    int cacheSegments,
  ) async {
    final uri = url.toSafeUri();
    final contentLengthTask = DownloadTask(
      uri: uri,
      startRange: 0,
      endRange: 1,
      headers: headers,
    );
    int contentLength = await head(uri, headers: headers);
    if (contentLength > 0) {
      await _cacheContentLength(contentLengthTask, contentLength);
    }
    if (contentLength > 0) {
      int segmentSize = contentLength ~/ Config.segmentSize +
          (contentLength % Config.segmentSize > 0 ? 1 : 0);
      if (cacheSegments > segmentSize) {
        cacheSegments = segmentSize;
      }
    }
    int count = 0;
    while (count < cacheSegments) {
      DownloadTask task = DownloadTask(uri: url.toSafeUri(), headers: headers);
      // Set the start and end range for each segment
      task.startRange += Config.segmentSize * count;
      task.endRange = task.startRange + Config.segmentSize - 1;
      count++;
      Uint8List? data = await cache(task);
      if (data == null) return false;
    }
    return true;
  }

  int _segmentEndRange(int startRange, int contentLength) {
    final endRange = startRange + Config.segmentSize - 1;
    if (contentLength <= 0) return endRange;
    final lastByte = contentLength - 1;
    return endRange > lastByte ? lastByte : endRange;
  }

  /// Pre-caches data from the network.
  ///
  /// [cacheSegments]: Number of segments to cache.<br>
  /// [downloadNow]: If true, downloads immediately; otherwise, pushes tasks to the queue.<br>
  /// [progressListen]: If true, returns a [StreamController] with progress updates.
  /// [priority]: Download task priority. Higher values are scheduled first.
  ///
  /// Returns a [StreamController] emitting progress maps, or `null` if not listening.
  @override
  Future<StreamController<Map>?> precache(
      String url,
      Map<String, Object>? headers,
      int cacheSegments,
      bool downloadNow,
      bool progressListen,
      [int priority = 1]) async {
    StreamController<Map>? _streamController;
    if (progressListen) _streamController = StreamController();
    final uri = url.toSafeUri();
    final contentLengthTask = DownloadTask(
      uri: uri,
      startRange: 0,
      endRange: 1,
      headers: headers,
    );
    int contentLength = await head(uri, headers: headers);
    if (contentLength > 0) {
      await _cacheContentLength(contentLengthTask, contentLength);
    }
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
      DownloadTask task = DownloadTask(
        uri: uri,
        headers: headers,
        priority: priority,
      );
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
}

class Mp4RangeResponse {
  const Mp4RangeResponse({
    required this.start,
    required this.end,
    required this.totalLength,
    required this.partial,
  });

  factory Mp4RangeResponse.fromRequest({
    required int start,
    required int end,
    required int totalLength,
    required bool partial,
  }) {
    final resolvedEnd = end >= 0 ? end : totalLength - 1;
    return Mp4RangeResponse(
      start: start,
      end: resolvedEnd,
      totalLength: totalLength,
      partial: partial,
    );
  }

  final int start;
  final int end;
  final int totalLength;
  final bool partial;

  int get contentLength => end - start + 1;

  String? get contentRangeHeader {
    if (!partial) return null;
    return 'content-range: bytes $start-$end/$totalLength';
  }
}
