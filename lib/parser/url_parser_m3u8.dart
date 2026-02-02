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

/// M3U8 URL parser implementation.
/// Handles caching, downloading, and parsing of HLS (M3U8) video streams.
/// Implements the [UrlParser] interface for HLS video files.
class UrlParserM3U8 implements UrlParser {
  /// Stores the list of all HLS segments currently being managed or downloaded.
  /// Each [HlsSegment] represents a TS segment in the HLS playlist.
  static final List<HlsSegment> _list = <HlsSegment>[];

  /// Records the most recently requested or processed segment URL.
  /// Used to track download progress and manage segment concurrency.
  static String _latestUrl = '';

  /// Finds a segment in the segment list by its [uri].
  ///
  /// Returns the [HlsSegment] if found, otherwise `null`.
  HlsSegment? findSegmentByUri(Uri uri) {
    return _list.where((task) => task.url == uri.toString()).firstOrNull;
  }

  /// Retrieves cached data for the given [task] from memory or file.
  ///
  /// Returns a [Uint8List] containing the cached data if available,
  /// or `null` if the data is not cached.
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

  /// Downloads data from the network for the given [task].
  ///
  /// Returns a [Uint8List] containing the downloaded data,
  /// or `null` if the download fails.
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

  /// Pushes the [task] to the download manager for processing.
  /// If the task is already in the download manager or cache, does nothing.
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

  /// Parses the request and returns the data to the [socket].
  ///
  /// Handles M3U8 playlist and segment requests, replacing URLs with local proxy URLs.
  /// Returns `true` if parsing and response succeed, otherwise `false`.
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
      if (hlsSegment != null) {
        task.hlsKey = hlsSegment.key;
        task.startRange = hlsSegment.startRange;
        task.endRange = hlsSegment.endRange;
      }
      // parse EXT-X-BYTERANGE to get range header
      if (headers.containsKey('range')) {
        String range = headers['range'] ?? '';
        if (range.startsWith("bytes=")) range = range.substring(6);
        List rangeList = range.split('-');
        if (rangeList.length == 2) {
          task.startRange = int.tryParse(rangeList[0]) ?? 0;
          task.endRange = int.tryParse(rangeList[1]);
        }
      }
      Uint8List? data = await cache(task);
      // if the task has been added, wait for the download to complete
      bool exitUri = VideoProxy.downloadManager.isUrlExit(task.url);
      if (exitUri) {
        while (data == null) {
          await Future.delayed(const Duration(milliseconds: 100));
          data = await cache(task);
        }
      }
      if (data == null) {
        // concurrentLoop(hlsSegment, headers);
        task.priority += 10;
        data = await download(task);
      }
      if (data == null) return false;
      String contentType = 'application/octet-stream';
      if (VideoProxy.urlMatcherImpl.matchM3u8(task.uri)) {
        // Parse and rewrite M3U8 playlist lines for local proxying
        List<String> lines = readLineFromUint8List(data);
        String lastLine = '';
        int lastEndRange = 0;
        StringBuffer buffer = StringBuffer();
        for (String line in lines) {
          String hlsLine = line.trim();
          String? parseUri;
          if (hlsLine.startsWith("#EXT-X-KEY") ||
              hlsLine.startsWith("#EXT-X-MEDIA") ||
              hlsLine.startsWith("#EXT-X-MAP")) {
            Match? match = RegExp(r'URI="([^"]+)"').firstMatch(hlsLine);
            if (match != null && match.groupCount >= 1) {
              parseUri = match.group(1);
              if (parseUri != null) {
                parseUri = parseUri.toSafeUrl();
                String newUri = parseUri.startsWith('http')
                    ? parseUri.toLocalUrl()
                    : '$parseUri${parseUri.contains('?') ? '&' : '?'}'
                        'origin=${base64Url.encode(utf8.encode(uri.origin))}';
                line = hlsLine.replaceAll(parseUri, newUri);
              }
            }
          }
          if (lastLine.startsWith("#EXTINF") ||
              lastLine.startsWith("#EXT-X-BYTERANGE") ||
              lastLine.startsWith("#EXT-X-STREAM-INF")) {
            if (!line.startsWith("#EXT")) {
              line = line.toSafeUrl();
              line = line.startsWith('http')
                  ? line.toLocalUrl()
                  : '$line${line.contains('?') ? '&' : '?'}'
                      'origin=${base64Url.encode(utf8.encode(uri.origin))}';
            }
          }
          // Add HLS segment to download list
          if (hlsLine.startsWith("#EXT-X-KEY") ||
              hlsLine.startsWith("#EXT-X-MEDIA") ||
              hlsLine.startsWith("#EXT-X-MAP")) {
            if (parseUri != null) {
              if (!parseUri.startsWith('http')) {
                int relativePath = 0;
                while (hlsLine.startsWith("../")) {
                  hlsLine = hlsLine.substring(3);
                  relativePath++;
                }
                parseUri = '${uri.pathPrefix(relativePath)}/' + parseUri;
              }
              concurrentAdd(
                HlsSegment(url: parseUri, key: task.hlsKey!),
                headers,
              );
            }
          }
          if (lastLine.startsWith("#EXTINF") ||
              lastLine.startsWith("#EXT-X-BYTERANGE") ||
              lastLine.startsWith("#EXT-X-STREAM-INF")) {
            if (!line.startsWith("#EXT")) {
              if (!hlsLine.startsWith('http')) {
                int relativePath = 0;
                // when hlsLine is relative path
                while (hlsLine.startsWith("../")) {
                  hlsLine = hlsLine.substring(3);
                  relativePath++;
                }
                // when hlsLine start with /, and prefix contain hlsLine
                String prefix = '${uri.pathPrefix(relativePath)}/';
                if (hlsLine.startsWith("/")) {
                  List<String> split = hlsLine.split("/");
                  List<String> result = [];
                  for (var item in split) {
                    if (prefix.contains(item)) continue;
                    result.add(item);
                  }
                  hlsLine = result.join("/");
                }
                hlsLine = prefix + hlsLine;
              }
              // parse EXT-X-BYTERANGE to get range header
              int startRange = 0;
              int? endRange;
              if (lastLine.startsWith("#EXT-X-BYTERANGE")) {
                final reg = RegExp(r'#EXT-X-BYTERANGE:(\d+)(?:@(\d+))?');
                final match = reg.firstMatch(line);
                if (match != null) {
                  if (match.groupCount == 2) {
                    int offset = int.tryParse(match.group(1)!) ?? 0;
                    startRange = int.tryParse(match.group(2)!) ?? 0;
                    endRange = offset == 0 ? null : startRange + offset;
                  } else if (match.groupCount == 1) {
                    startRange = lastEndRange;
                    int offset = int.tryParse(match.group(1)!) ?? 0;
                    endRange = offset == 0 ? null : startRange + offset;
                    lastEndRange = endRange ?? 0;
                  }
                }
              }
              concurrentAdd(
                HlsSegment(
                  url: hlsLine,
                  key: task.hlsKey!,
                  startRange: startRange,
                  endRange: endRange,
                ),
                headers,
              );
            }
          }
          buffer.write('$line\r\n');
          lastLine = line;
        }
        data = Uint8List.fromList(buffer.toString().codeUnits);
        contentType = 'application/vnd.apple.mpegurl';
      } else if (VideoProxy.urlMatcherImpl.matchM3u8Key(task.uri)) {
        contentType = 'application/octet-stream';
      } else if (VideoProxy.urlMatcherImpl.matchM3u8Segment(task.uri)) {
        contentType = 'video/MP2T';
      }
      // return contentRange and contentLength to video player which parse from EXT-X-BYTERANGE
      String contentRange = "";
      String contentLength = "";
      if (task.endRange != null) {
        contentRange = 'bytes=${task.startRange}-${task.endRange!}';
        contentLength = (task.endRange! - task.startRange + 1).toString();
      }
      String responseHeaders = <String>[
        contentRange.isEmpty
            ? 'HTTP/1.1 200 OK'
            : 'HTTP/1.1 206 Partial Content',
        'Content-Type: $contentType',
        'Connection: keep-alive',
        if (contentType == 'video/MP2T') 'Accept-Ranges: bytes',
        if (contentRange.isNotEmpty) 'Content-Range: $contentRange',
        if (contentLength.isNotEmpty) 'Content-Length: $contentLength',
      ].join('\r\n');

      logW("[UrlParserM3U8] append 1: ${responseHeaders}");
      logW("[UrlParserM3U8] append 2: ${data.length}");
      await socket.append(responseHeaders);
      await socket.append(data);
      await socket.flush();
      logD('Return request data: $uri');
      return true;
    } catch (e) {
      logW('[UrlParserM3U8] ⚠ ⚠ ⚠ parse socket close: $e');
      return false;
    } finally {
      await socket.close();
      logD('Connection closed\n');
    }
  }

  /// Reads lines from a [Uint8List] and decodes them to a list of [String].
  ///
  /// Handles both LF and CRLF line endings.
  List<String> readLineFromUint8List(
    Uint8List uint8List, {
    Encoding encoding = utf8,
  }) {
    final lines = <String>[];
    final buffer = StringBuffer();
    bool isCarriageReturn = false;

    for (var i = 0; i < uint8List.length; i++) {
      final codeUnit = uint8List[i];
      if (codeUnit == 10) {
        // LF (0x0A)
        // If the previous character is CR, combine to CRLF
        if (isCarriageReturn) {
          buffer.writeCharCode(13);
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
          buffer.writeCharCode(13);
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
    return lines.map((line) => encoding.decode(line.codeUnits)).toList();
  }

  /// Asynchronously downloads TS files for HLS segments.
  ///
  /// Manages download concurrency and updates segment status.
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
      uri: segment.url.toSafeUri(),
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

  /// Adds a new [HlsSegment] to the segment list if not already present.
  void concurrentAdd(
    HlsSegment hlsSegment,
    Map<String, String> headers,
  ) {
    bool match = _list.where((e) => e.url == hlsSegment.url).isNotEmpty;
    if (!match) _list.add(hlsSegment);
  }

  /// Marks a segment as completed and triggers the next download if available.
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
    List<HlsSegment> mediaList = await parseSegment(url.toSafeUri(), headers);
    int totalSize = mediaList.length;
    if (cacheSegments > totalSize) cacheSegments = totalSize;
    if (mediaList.isEmpty) return false;

    final List<HlsSegment> segments = mediaList.take(cacheSegments).toList();
    final String hlsKey = url.generateMd5;

    for (final segment in segments) {
      final task = DownloadTask(
        uri: segment.url.toSafeUri(),
        hlsKey: hlsKey,
        headers: headers,
        startRange: segment.startRange,
        endRange: segment.endRange,
      );
      Uint8List? data = await cache(task);
      if (data == null) return false;
    }
    return true;
  }

  /// Pre-caches HLS video segments from the network.
  ///
  /// Parses the given HLS playlist URL, selects a specified number of segments to cache,
  /// and either immediately downloads them or queues them for later processing.
  ///
  /// If [progressListen] is true, returns a [StreamController] that emits progress updates.
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

    List<HlsSegment> mediaList = await parseSegment(url.toSafeUri(), headers);
    int totalSize = mediaList.length;
    if (cacheSegments > totalSize) cacheSegments = totalSize;
    if (mediaList.isEmpty) return _streamController;

    final List<HlsSegment> segments = mediaList.take(cacheSegments).toList();
    final String hlsKey = url.generateMd5;
    int downloadedSize = 0;

    /// Downloads or loads a segment from cache and emits progress to the stream.
    Future<void> processSegment(HlsSegment segment) async {
      final task = DownloadTask(
        uri: segment.url.toSafeUri(),
        hlsKey: hlsKey,
        headers: headers,
        startRange: segment.startRange,
        endRange: segment.endRange,
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

    if (downloadNow) {
      for (final segment in segments) {
        await processSegment(segment);
      }
    } else {
      for (final segment in segments) {
        final task = DownloadTask(
          uri: segment.url.toSafeUri(),
          hlsKey: hlsKey,
          headers: headers,
          startRange: segment.startRange,
          endRange: segment.endRange,
        );
        push(task);
      }
    }

    return _streamController;
  }

  /// Parses M3U8 TS file segment URLs from the playlist at [uri].
  ///
  /// Returns a list of segment URLs.
  Future<List<HlsSegment>> parseSegment(
    Uri uri,
    Map<String, Object>? headers,
  ) async {
    final HlsMediaPlaylist? playList =
        await parseMediaPlaylist(uri, headers: headers);
    if (playList == null) return <HlsSegment>[];
    List<HlsSegment> segments = <HlsSegment>[];
    for (final Segment segment in playList.segments) {
      String? segmentUrl = segment.url;
      if (segmentUrl != null && !segmentUrl.startsWith('http')) {
        int relativePath = 0;
        // when hlsLine is relative path
        while (segmentUrl!.startsWith("../")) {
          segmentUrl = segmentUrl.substring(3);
          relativePath++;
        }
        // when hlsLine start with /, and prefix contain hlsLine
        String prefix = '${uri.pathPrefix(relativePath)}/';
        if (segmentUrl.startsWith("/")) {
          List<String> split = segmentUrl.split("/");
          List<String> result = [];
          for (var item in split) {
            if (prefix.contains(item)) continue;
            result.add(item);
          }
          segmentUrl = result.join("/");
        }
        segmentUrl = prefix + segmentUrl;
      }
      if (segmentUrl == null) continue;
      int? endRange;
      if (segment.byterangeOffset != null && segment.byterangeOffset != null) {
        endRange = segment.byterangeLength! - segment.byterangeOffset! - 1;
      }
      segments.add(HlsSegment(
        key: segmentUrl.generateMd5,
        url: segmentUrl,
        startRange: segment.byterangeOffset ?? 0,
        endRange: endRange,
      ));
    }
    return segments;
  }

  /// Parses the HLS media playlist from the given [uri].
  ///
  /// Returns an [HlsMediaPlaylist] if successful, otherwise `null`.
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
        Uri masterUri = '${uri.pathPrefix()}${_uri.path}'.toSafeUri();
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

  /// Parses the HLS playlist (master or media) from the given [uri].
  ///
  /// Returns an [HlsPlaylist] if successful, otherwise `null`.
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

  /// Parses HLS playlist lines into an [HlsPlaylist] object.
  ///
  /// Returns the parsed [HlsPlaylist], or `null` if parsing fails.
  Future<HlsPlaylist?> parseLines(List<String> lines) async {
    if (lines.isEmpty) return null;
    HlsPlaylist? playList;
    try {
      playList = await VideoProxy.hlsPlaylistParser.parse(Uri.base, lines);
    } catch (e) {
      logE('Exception: ${e}');
    }
    return playList;
  }
}

/// Represents a single HLS segment with its key, URL, and download status.
class HlsSegment {
  final String key;
  final String url;
  final int startRange;
  final int? endRange;
  DownloadStatus status;

  HlsSegment({
    required this.key,
    required this.url,
    this.status = DownloadStatus.IDLE,
    this.startRange = 0,
    this.endRange,
  });
}
