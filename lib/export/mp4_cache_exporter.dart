import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../cache/lru_cache_singleton.dart';
import '../download/download_task.dart';
import '../ext/file_ext.dart';
import '../ext/string_ext.dart';
import '../ext/uri_ext.dart';
import '../global/config.dart';
import '../parser/url_parser_mp4.dart';
import '../proxy/video_proxy.dart';

/// Builds a complete MP4 file from the existing range cache.
///
/// The exporter uses the same [DownloadTask] cache keys as [UrlParserMp4], so it
/// reuses segments already loaded by playback. If a segment is missing and
/// [downloadMissingSegments] is true, only the missing range is downloaded.
class Mp4CacheExporter {
  Mp4CacheExporter({UrlParserMp4? parser}) : _parser = parser ?? UrlParserMp4();

  final UrlParserMp4 _parser;

  /// Exports [url] to a complete MP4 file.
  ///
  /// Returns `null` when the total length is unknown, a required segment is
  /// missing while [downloadMissingSegments] is false, or [timeout] expires.
  Future<File?> export(
    String url, {
    Map<String, Object>? headers,
    Duration timeout = const Duration(seconds: 30),
    bool downloadMissingSegments = true,
    int priority = 5,
  }) async {
    final uri = url.toSafeUri();
    if (!VideoProxy.urlMatcherImpl.matchMp4(uri)) return null;
    final deadline = DateTime.now().add(timeout);
    final contentLength = await _contentLength(uri, headers, deadline);
    if (contentLength <= 0) return null;

    final exportFile = await _exportFile(uri);
    if (await _isCompleteFile(exportFile, contentLength)) {
      return exportFile;
    }

    final segmentFiles = <File>[];
    for (var startRange = 0;
        startRange < contentLength;
        startRange += Config.segmentSize) {
      final endRange = _segmentEndRange(startRange, contentLength);
      final task = await _segmentTask(
        uri,
        startRange,
        endRange,
        headers,
        priority,
      );
      final segmentFile = await _loadSegment(
        task,
        expectedBytes: endRange - startRange + 1,
        downloadMissingSegments: downloadMissingSegments,
        deadline: deadline,
      );
      if (segmentFile == null) return null;
      segmentFiles.add(segmentFile);
    }

    return _joinSegments(exportFile, segmentFiles, contentLength);
  }

  Future<int> _contentLength(
    Uri uri,
    Map<String, Object>? headers,
    DateTime deadline,
  ) async {
    final task = DownloadTask(
      uri: uri,
      startRange: 0,
      endRange: 1,
      headers: headers,
    );
    final cached = await _withRemainingTime(
      _parser.cache(task),
      deadline,
    );
    if (cached != null) {
      final value = int.tryParse(const Utf8Codec().decode(cached)) ?? 0;
      if (value > 0) return value;
    }
    final contentLength = await _withRemainingTime(
      _parser.head(uri, headers: headers),
      deadline,
    );
    if (contentLength == null || contentLength <= 0) return -1;

    task.cacheDir = await FileExt.createCachePath(uri.generateMd5);
    final file = File(task.savePath);
    await file.writeAsString(contentLength.toString());
    await LruCacheSingleton().storagePut(task.matchUrl, file);
    return contentLength;
  }

  Future<DownloadTask> _segmentTask(
    Uri uri,
    int startRange,
    int endRange,
    Map<String, Object>? headers,
    int priority,
  ) async {
    final task = DownloadTask(
      uri: uri,
      startRange: startRange,
      endRange: endRange,
      headers: headers,
      priority: priority,
    );
    task.cacheDir = await FileExt.createCachePath(uri.generateMd5);
    return task;
  }

  Future<File?> _loadSegment(
    DownloadTask task, {
    required int expectedBytes,
    required bool downloadMissingSegments,
    required DateTime deadline,
  }) async {
    final cachedFile = File(task.savePath);
    if (await _isCompleteFile(cachedFile, expectedBytes)) {
      return cachedFile;
    }
    if (!downloadMissingSegments) return null;

    final data = await _withRemainingTime(
      _parser.download(task),
      deadline,
    );
    if (data == null || data.lengthInBytes != expectedBytes) return null;
    if (await _isCompleteFile(cachedFile, expectedBytes)) {
      return cachedFile;
    }
    await cachedFile.writeAsBytes(data);
    await LruCacheSingleton().storagePut(task.matchUrl, cachedFile);
    return cachedFile;
  }

  Future<File?> _joinSegments(
    File exportFile,
    List<File> segmentFiles,
    int contentLength,
  ) async {
    final tempFile = File('${exportFile.path}.tmp');
    final sink = tempFile.openWrite();
    try {
      for (final segmentFile in segmentFiles) {
        await sink.addStream(segmentFile.openRead());
      }
    } finally {
      await sink.close();
    }

    if (!await _isCompleteFile(tempFile, contentLength)) {
      if (await tempFile.exists()) await tempFile.delete();
      return null;
    }
    if (await exportFile.exists()) await exportFile.delete();
    return tempFile.rename(exportFile.path);
  }

  Future<File> _exportFile(Uri uri) async {
    final cacheDir = await FileExt.createCachePath(uri.generateMd5);
    return File('$cacheDir/${uri.generateMd5}.export.mp4');
  }

  Future<bool> _isCompleteFile(File file, int expectedBytes) async {
    if (!await file.exists()) return false;
    return await file.length() == expectedBytes;
  }

  int _segmentEndRange(int startRange, int contentLength) {
    final endRange = startRange + Config.segmentSize - 1;
    final lastByte = contentLength - 1;
    return endRange > lastByte ? lastByte : endRange;
  }

  Future<T?> _withRemainingTime<T>(Future<T> future, DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) return Future<T?>.value();
    return future
        .then<T?>((value) => value)
        .timeout(remaining, onTimeout: () => null);
  }
}
