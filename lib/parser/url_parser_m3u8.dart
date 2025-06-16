import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_hls_parser/flutter_hls_parser.dart';

import '../cache/lru_cache_singleton.dart';
import '../download/download_status.dart';
import '../download/download_task.dart';
import '../ext/file_ext.dart';
import '../ext/int_ext.dart';
import '../ext/log_ext.dart';
import '../ext/socket_ext.dart';
import '../ext/string_ext.dart';
import '../ext/uri_ext.dart';
import '../proxy/video_proxy.dart';
import 'url_parser.dart';

/// M3U8 URL parser
class UrlParserM3U8 implements UrlParser {
  static final List<HlsSegment> _list = <HlsSegment>[];
  static String _latestUrl = '';

  HlsSegment? findSegmentByUri(Uri uri) {
    return _list.where((task) => task.url == uri.toString()).firstOrNull;
  }

  /// Get the cache data from memory or file.
  /// If there is no cache data, return null.
  @override
  Future<Uint8List?> cache(DownloadTask task) async {
    Uint8List? dataMemory = await LruCacheSingleton().memoryGet(task.matchUrl);
    if (dataMemory != null) {
      logD('From memory: ${dataMemory.lengthInBytes.toMemorySize}, '
          'total memory size: ${await LruCacheSingleton().memoryFormatSize()}');
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

  /// Download the data from network.
  @override
  Future<Uint8List?> download(DownloadTask task) async {
    logD('From network: ${task.url}');
    Uint8List? dataNetwork;
    task.cacheDir = await FileExt.createCachePath(task.hlsKey);
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

  /// Push the task to the download manager.
  /// If the task is already in the download manager, do nothing.
  @override
  Future<void> push(DownloadTask task) async {
    Uint8List? dataMemory = await LruCacheSingleton().memoryGet(task.matchUrl);
    if (dataMemory != null) return;
    String cachePath = await FileExt.createCachePath(task.hlsKey);
    File file = File('$cachePath/${task.saveFileName}');
    if (await file.exists()) return;
    task.cacheDir = cachePath;
    await VideoProxy.downloadManager.addTask(task);
  }

  /// Parse the data from socket.
  /// If the request is not valid, return false.
  ///
  /// After parsing m3u8 file, it will replace the url with the local url.
  @override
  Future<bool> parse(
    Socket socket,
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      DownloadTask task = DownloadTask(
        uri: uri,
        hlsKey: uri.generateMd5,
        headers: headers,
      );
      HlsSegment? hlsSegment = findSegmentByUri(uri);
      if (hlsSegment != null) task.hlsKey = hlsSegment.key;
      Uint8List? data = await cache(task);
      if (data == null) {
        concurrentLoop(hlsSegment, headers);
        task.priority += 10;
        data = await download(task);
      }
      if (data == null) return false;
      String contentType = 'application/octet-stream';
      if (task.uri.path.endsWith('.m3u8')) {
        List<String> lines = readLineFromUint8List(data);
        String lastLine = '';
        StringBuffer buffer = StringBuffer();
        for (String line in lines) {
          String hlsLine = line.trim();
          String? parseUri;
          if (hlsLine.startsWith("#EXT-X-KEY") ||
              hlsLine.startsWith("#EXT-X-MEDIA")) {
            Match? match = RegExp(r'URI="([^"]+)"').firstMatch(hlsLine);
            if (match != null && match.groupCount >= 1) {
              parseUri = match.group(1);
              if (parseUri != null) {
                String newUri = parseUri.startsWith('http')
                    ? parseUri.toLocalUrl()
                    : '$parseUri${parseUri.contains('?') ? '&' : '?'}'
                        'origin=${base64Url.encode(utf8.encode(uri.origin))}';
                line = hlsLine.replaceAll(parseUri, newUri);
              }
            }
          }
          if (lastLine.startsWith("#EXTINF") ||
              lastLine.startsWith("#EXT-X-STREAM-INF")) {
            line = line.startsWith('http')
                ? line.toLocalUrl()
                : '$line${line.contains('?') ? '&' : '?'}'
                    'origin=${base64Url.encode(utf8.encode(uri.origin))}';
          }
          // Setting HLS segment to same key, it will be downloaded in the same directory.
          if ((hlsLine.startsWith("#EXT-X-KEY") ||
                  hlsLine.startsWith("#EXT-X-MEDIA")) &&
              parseUri != null) {
            if (!parseUri.startsWith('http')) {
              parseUri = '${uri.pathPrefix()}/' + parseUri;
            }
            concurrentAdd(
              HlsSegment(url: parseUri, key: task.hlsKey!),
              headers,
            );
          }
          if (lastLine.startsWith("#EXTINF") ||
              lastLine.startsWith("#EXT-X-STREAM-INF")) {
            if (!hlsLine.startsWith('http')) {
              int relativePath = 0;
              while (hlsLine.startsWith("../")) {
                hlsLine = hlsLine.substring(3);
                relativePath++;
              }
              hlsLine = '${uri.pathPrefix(relativePath)}/' + hlsLine;
            }
            concurrentAdd(HlsSegment(url: hlsLine, key: task.hlsKey!), headers);
          }
          buffer.write('$line\r\n');
          lastLine = line;
        }
        data = Uint8List.fromList(buffer.toString().codeUnits);
        contentType = 'application/vnd.apple.mpegurl';
      } else if (task.uri.path.endsWith('.key')) {
        contentType = 'application/octet-stream';
      } else if (task.uri.path.endsWith('.ts')) {
        contentType = 'video/MP2T';
      }
      String responseHeaders = <String>[
        'HTTP/1.1 200 OK',
        'Content-Type: $contentType',
        'Connection: keep-alive',
        if (contentType == 'video/MP2T') 'Accept-Ranges: bytes',
      ].join('\r\n');
      await socket.append(responseHeaders);
      await socket.append(data);
      await socket.flush();
      logD('Return request data: $uri');
      return true;
    } catch (e) {
      logW('[UrlParserM3U8] ⚠ ⚠ ⚠ parse error: $e');
      return false;
    } finally {
      await socket.close();
      logD('Connection closed\n');
    }
  }

  /// Read the lines from Uint8List and decode them to String.
  List<String> readLineFromUint8List(
    Uint8List uint8List, {
    Encoding encoding = utf8,
  }) {
    final lines = <String>[];
    final buffer = StringBuffer();
    bool isCarriageReturn = false;

    for (var i = 0; i < uint8List.length; i++) {
      final codeUnit = uint8List[i];

      // Process line break
      if (codeUnit == 10) {
        // LF (0x0A)
        // If the previous character is CR, combine to CRLF
        if (isCarriageReturn) {
          buffer.writeCharCode(13); // Add CR to the current line
          isCarriageReturn = false;
        }
        lines.add(buffer.toString());
        buffer.clear();
      } else if (codeUnit == 13) {
        // CR (0x0D)
        // Alone CR or part of CRLF
        isCarriageReturn = true;
        // Check if the next character is LF
        if (i + 1 < uint8List.length && uint8List[i + 1] == 10) {
          // Is part of CRLF, wait for LF processing
        } else {
          // Single CR, treated as line break
          lines.add(buffer.toString());
          buffer.clear();
          isCarriageReturn = false;
        }
      } else {
        // Ordinary character
        if (isCarriageReturn) {
          buffer.writeCharCode(13); // Add the previous CR
          isCarriageReturn = false;
        }
        buffer.writeCharCode(codeUnit);
      }
    }

    // Add the last line (if there is remaining content)
    if (buffer.isNotEmpty || isCarriageReturn) {
      if (isCarriageReturn) {
        buffer.writeCharCode(13);
      }
      lines.add(buffer.toString());
    }

    // Decode all lines
    return lines.map((line) => encoding.decode(line.codeUnits)).toList();
  }

  /// Asynchronous downloading of ts files.
  Future<void> concurrentLoop(
    HlsSegment? hlsSegment,
    Map<String, String> headers,
  ) async {
    if (hlsSegment == null) return;
    _latestUrl = hlsSegment.url;
    Set<String?> hlsKeys = _list.map((e) => e.key).toSet();
    if (hlsKeys.length > 2) {
      _list.where((e) => e.key == hlsKeys.first).forEach((e) {
        VideoProxy.downloadManager.allTasks
            .removeWhere((task) => task.url == e.url);
      });
      _list.removeWhere((e) => e.key == hlsKeys.first);
    }
    HlsSegment? segment = _list.where((e) => e.url == _latestUrl).firstOrNull;
    if (segment == null) return;
    List<HlsSegment> downloading = _list
        .where((e) => e.key == segment.key)
        .where((e) => e.status == DownloadStatus.DOWNLOADING)
        .toList();
    if (downloading.length >= 4) return;
    Uint8List? cache =
        await LruCacheSingleton().memoryGet(segment.url.generateMd5);
    if (cache != null) {
      concurrentComplete(segment, headers);
      return;
    }
    DownloadTask task = DownloadTask(
      uri: Uri.parse(segment.url),
      headers: headers,
    );
    String cachePath = await FileExt.createCachePath(segment.key);
    File file = File('$cachePath/${task.saveFileName}');
    if (await file.exists()) {
      concurrentComplete(segment, headers);
      return;
    }
    bool exitUri = VideoProxy.downloadManager.isUrlExit(segment.url);
    if (exitUri) {
      concurrentComplete(segment, headers, status: DownloadStatus.DOWNLOADING);
      return;
    }
    task.priority += 1;
    task.cacheDir = cachePath;
    await VideoProxy.downloadManager.executeTask(task);
    StreamSubscription? subscription;
    subscription = VideoProxy.downloadManager.stream.listen((downloadTask) {
      if (downloadTask.status == DownloadStatus.COMPLETED &&
          downloadTask.matchUrl == task.matchUrl) {
        logD("Asynchronous download completed： ${task.toString()}");
        subscription?.cancel();
        concurrentComplete(segment, headers);
      }
    });
  }

  void concurrentAdd(
    HlsSegment hlsSegment,
    Map<String, String> headers,
  ) {
    bool match = _list.where((e) => e.url == hlsSegment.url).isNotEmpty;
    if (!match) _list.add(hlsSegment);
  }

  void concurrentComplete(
    HlsSegment hlsSegment,
    Map<String, String> headers, {
    DownloadStatus? status,
  }) {
    int index = _list.indexWhere((e) => e.url == hlsSegment.url);
    if (index == -1) return;
    _list[index].status = status ?? DownloadStatus.COMPLETED;
    HlsSegment? latest = _list.where((e) => e.url == _latestUrl).firstOrNull;
    if (latest != null) {
      List<HlsSegment> list = _list.where((e) => e.key == latest.key).toList();
      int index = list.indexWhere((e) => e.url == latest.url);
      if (index != -1 && index + 1 < list.length) {
        concurrentLoop(list[index + 1], headers);
        return;
      }
    }
    Set<String?> keys = _list.map((e) => e.key).toSet();
    String? key = keys.elementAt(Random().nextInt(keys.length));
    HlsSegment? idleSegment = _list
        .where((e) => e.key == key)
        .where((e) => e.status == DownloadStatus.IDLE)
        .firstOrNull;
    if (idleSegment == null) {
      _list.removeWhere((e) => e.key == key);
      concurrentComplete(hlsSegment, headers);
      return;
    }
    concurrentLoop(idleSegment, headers);
  }

  /// Pre-caches HLS video segments from the network.
  ///
  /// This method parses the given HLS playlist URL, selects a specified number
  /// of segments to cache, and either immediately downloads them or queues
  /// them for later processing based on [downloadNow].
  ///
  /// If [progressListen] is true, a [StreamController] is returned that emits
  /// progress updates in the form of a `Map`, including:
  ///   - 'progress' (0.0 to 1.0)
  ///   - 'segment_url'
  ///   - 'parent_url'
  ///   - 'file_name'
  ///   - 'hls_key'
  ///   - 'total_segments'
  ///   - 'current_segment_index'
  ///
  /// Download concurrency is throttled to avoid overwhelming the device/network.
  ///
  /// Parameters:
  /// - [url]: The master or variant HLS URL to parse and cache segments from.
  /// - [cacheSegments]: The number of segments to pre-cache (max capped at total available).
  /// - [downloadNow]: If true, downloads are performed immediately with throttling; otherwise, tasks are pushed to a background queue.
  /// - [progressListen]: If true, returns a [StreamController] with progress updates.
  ///
  /// Returns:
  /// - A [StreamController] that emits progress maps if [progressListen] is true,
  ///   otherwise returns `null`.
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

    List<String> mediaList = await parseSegment(Uri.parse(url), headers);
    int totalSize = mediaList.length;
    if (cacheSegments > totalSize) cacheSegments = totalSize;
    if (mediaList.isEmpty) return _streamController;

    final List<String> segments = mediaList.take(cacheSegments).toList();
    final String hlsKey = url.generateMd5;
    final Queue<String> segmentQueue = Queue.of(segments);
    final int maxConcurrent = 5;
    int downloadedSize = 0;
    final List<Future<void>> activeTasks = [];

    /// Safely parses a URL string into a Uri object by:
    /// 1. Removing any hidden or invalid characters like '\r' and '\n'
    /// 2. Trimming extra whitespace
    /// 3. Truncating the string right after `.ts` to avoid garbage like `%0D`
    ///
    /// This ensures the resulting Uri is clean and avoids HTTP 400 errors when used.
    Uri safeParse(String inputUrl) {
      final cleaned = inputUrl
          .replaceAll(
              '\r', '') // Remove carriage returns (common source of %0D)
          .replaceAll('\n', '') // Remove newline characters
          .trim(); // Remove leading/trailing whitespace

      // Optional: strip garbage after .ts
      final tsIndex = cleaned.indexOf('.ts');
      final finalString = tsIndex != -1
          ? cleaned.substring(0, tsIndex + 3)
          : cleaned; // Keep up to and including '.ts'

      return Uri.parse(finalString);
    }

    /// Downloads or loads a segment from cache and emits progress to the stream.
    ///
    /// If the segment is already cached, it skips downloading.
    /// After success (cached or downloaded), it pushes the progress info to the stream.
    Future<void> processSegment(String segment) async {
      final task = DownloadTask(
        uri: safeParse(segment),
        hlsKey: hlsKey,
        headers: headers,
      );
      Uint8List? data = await cache(task);
      if (data == null) {
        await download(task);
      }

      downloadedSize += 1;
      if (_streamController?.isClosed ?? false) return;
      _streamController?.sink.add({
        'progress': downloadedSize / cacheSegments,
        'segment_url': segment,
        'parent_url': url,
        'file_name': task.saveFile,
        'hls_key': hlsKey,
        'total_segments': segments.length,
        'current_segment_index': downloadedSize - 1,
      });
    }

    /// Starts the download process for a segment and tracks it in [activeTasks].
    ///
    /// Once the segment processing is complete, it removes the task from the active list.
    void startSegmentTask(String segment) {
      final future = processSegment(segment);
      activeTasks.add(future);
      future.whenComplete(() {
        activeTasks.remove(future);
      });
    }

    /// Handles throttled downloading of segments.
    ///
    /// Ensures that no more than [maxConcurrent] tasks run in parallel.
    /// Continuously starts new tasks from the queue as others complete.
    Future<void> throttledDownloader() async {
      while (segmentQueue.isNotEmpty || activeTasks.isNotEmpty) {
        while (activeTasks.length < maxConcurrent && segmentQueue.isNotEmpty) {
          final segment = segmentQueue.removeFirst();
          startSegmentTask(segment);
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    if (downloadNow) {
      throttledDownloader();
    } else {
      for (final segment in segments) {
        final task = DownloadTask(
          uri: Uri.parse(segment),
          hlsKey: hlsKey,
          headers: headers,
        );
        push(task);
      }
    }

    return _streamController;
  }

  /// Parsing M3U8 ts files
  Future<List<String>> parseSegment(
    Uri uri,
    Map<String, Object>? headers,
  ) async {
    final HlsMediaPlaylist? playList =
        await parseMediaPlaylist(uri, headers: headers);
    if (playList == null) return <String>[];
    List<String> segments = <String>[];
    for (final Segment segment in playList.segments) {
      String? segmentUrl = segment.url;
      if (segmentUrl != null && !segmentUrl.startsWith('http')) {
        int relativePath = 0;
        while (segmentUrl!.startsWith("../")) {
          segmentUrl = segmentUrl.substring(3);
          relativePath++;
        }
        segmentUrl = '${uri.pathPrefix(relativePath)}/' + segmentUrl;
      }
      if (segmentUrl == null) continue;
      segments.add(segmentUrl);
    }
    return segments;
  }

  /// Parsing M3U8 media playlist
  Future<HlsMediaPlaylist?> parseMediaPlaylist(
    Uri uri, {
    Map<String, Object>? headers,
    String? hlsKey,
  }) async {
    final HlsPlaylist? playList =
        await parsePlaylist(uri, headers: headers, hlsKey: hlsKey);
    if (playList is HlsMasterPlaylist) {
      for (final Uri? _uri in playList.mediaPlaylistUrls) {
        if (_uri == null) continue;
        Uri masterUri = Uri.parse('${uri.pathPrefix()}${_uri.path}');
        HlsMediaPlaylist? mediaPlayList = await parseMediaPlaylist(
          masterUri,
          headers: headers,
          hlsKey: uri.generateMd5,
        );
        return mediaPlayList;
      }
    } else if (playList is HlsMediaPlaylist) {
      return playList;
    }
    return null;
  }

  /// Parsing M3U8 resolution list
  Future<HlsPlaylist?> parsePlaylist(
    Uri uri, {
    Map<String, Object>? headers,
    String? hlsKey,
  }) async {
    DownloadTask task = DownloadTask(
      uri: uri,
      headers: headers,
      hlsKey: hlsKey ?? uri.generateMd5,
    );
    Uint8List? uint8List = await cache(task);
    if (uint8List == null) uint8List = await download(task);
    if (uint8List == null) return null;
    List<String> lines = readLineFromUint8List(uint8List);
    final HlsPlaylist? playList = await parseLines(lines);
    return playList;
  }

  /// Parsing M3U8 data lines
  Future<HlsPlaylist?> parseLines(List<String> lines) async {
    HlsPlaylist? playList;
    try {
      playList = await VideoProxy.hlsPlaylistParser.parse(Uri.base, lines);
    } catch (e) {
      logE('Exception: ${e}');
    }
    return playList;
  }
}

class HlsSegment {
  final String key;
  final String url;
  DownloadStatus status;

  HlsSegment({
    required this.key,
    required this.url,
    this.status = DownloadStatus.IDLE,
  });
}
