import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_caching/download/download_manager.dart';
import 'package:flutter_video_caching/cache/lru_cache_singleton.dart';
import 'package:flutter_video_caching/download/download_task.dart';
import 'package:flutter_video_caching/export/mp4_cache_exporter.dart';
import 'package:flutter_video_caching/ext/file_ext.dart';
import 'package:flutter_video_caching/ext/uri_ext.dart';
import 'package:flutter_video_caching/global/config.dart';
import 'package:flutter_video_caching/parser/url_parser_mp4.dart';
import 'package:flutter_video_caching/parser/video_caching.dart';
import 'package:flutter_video_caching/proxy/video_proxy.dart';
import 'package:flutter_video_caching/match/url_matcher_default.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationCachePath() async {
    return Directory.systemTemp.path;
  }
}

class _HeadStubUrlParserMp4 extends UrlParserMp4 {
  _HeadStubUrlParserMp4(this.contentLength);

  final int contentLength;
  int headCalls = 0;

  @override
  Future<int> head(Uri uri, {Map<String, Object>? headers}) async {
    headCalls++;
    return contentLength;
  }
}

class _ExportStubUrlParserMp4 extends UrlParserMp4 {
  _ExportStubUrlParserMp4(this.bytes, {this.downloadDelay = Duration.zero});

  final List<int> bytes;
  final Duration downloadDelay;
  final downloadedRanges = <String>[];

  @override
  Future<int> head(Uri uri, {Map<String, Object>? headers}) async {
    return bytes.length;
  }

  @override
  Future<Uint8List?> download(DownloadTask task) async {
    if (downloadDelay > Duration.zero) {
      await Future<void>.delayed(downloadDelay);
    }
    final endRange = task.endRange ?? bytes.length - 1;
    final data = bytes.sublist(task.startRange, endRange + 1);
    final file = File(task.savePath);
    await file.writeAsBytes(data);
    await LruCacheSingleton().storagePut(task.matchUrl, file);
    downloadedRanges.add('${task.startRange}-$endRange');
    return Uint8List.fromList(data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late int originalSegmentSize;

  group('Mp4RangeResponse', () {
    test('open-ended range uses 206 metadata for the full remaining file', () {
      final response = Mp4RangeResponse.fromRequest(
        start: 0,
        end: -1,
        totalLength: 1000,
        partial: true,
      );

      expect(response.start, 0);
      expect(response.end, 999);
      expect(response.contentLength, 1000);
      expect(response.contentRangeHeader, 'content-range: bytes 0-999/1000');
    });

    test('two-byte iOS probe range returns matching length and total', () {
      final response = Mp4RangeResponse.fromRequest(
        start: 0,
        end: 1,
        totalLength: 1000,
        partial: true,
      );

      expect(response.contentLength, 2);
      expect(response.contentRangeHeader, 'content-range: bytes 0-1/1000');
    });

    test('non-range response omits content range', () {
      final response = Mp4RangeResponse.fromRequest(
        start: 0,
        end: -1,
        totalLength: 1000,
        partial: false,
      );

      expect(response.contentLength, 1000);
      expect(response.contentRangeHeader, isNull);
    });
  });

  group('UrlParserMp4 precache', () {
    setUp(() async {
      PathProviderPlatform.instance = _FakePathProviderPlatform();
      FileExt.cacheRootPath = '';
      VideoProxy.urlMatcherImpl = UrlMatcherDefault();
      VideoProxy.downloadManager = DownloadManager();
      await LruCacheSingleton().memoryClear();
      await LruCacheSingleton().storageClear();
    });

    tearDown(() {
      VideoProxy.downloadManager.dispose();
    });

    test('stores content length metadata for later proxy parse', () async {
      final parser = _HeadStubUrlParserMp4(12345);
      final url = 'https://example.com/video.mp4';

      await parser.precache(url, null, 0, true, false);

      final cachedLength = await parser.cache(
        DownloadTask(
          uri: Uri.parse(url),
          startRange: 0,
          endRange: 1,
        ),
      );

      expect(parser.headCalls, 1);
      expect(String.fromCharCodes(cachedLength!), '12345');
    });

    test('passes priority to queued precache range tasks', () async {
      final parser = _HeadStubUrlParserMp4(1024 * 1024 * 3);
      final url = 'https://example.com/priority.mp4';

      await parser.precache(url, null, 2, false, false, 7);
      await _waitUntil(() => VideoProxy.downloadManager.allTasks.length == 2);

      expect(VideoProxy.downloadManager.allTasks, hasLength(2));
      expect(
        VideoProxy.downloadManager.allTasks.map((task) => task.priority),
        everyElement(7),
      );
    });
  });

  group('VideoCaching.exportCachedMp4', () {
    setUp(() async {
      originalSegmentSize = Config.segmentSize;
      Config.segmentSize = 4;
      PathProviderPlatform.instance = _FakePathProviderPlatform();
      FileExt.cacheRootPath = '';
      VideoProxy.urlMatcherImpl = UrlMatcherDefault();
      VideoProxy.downloadManager = DownloadManager();
      await LruCacheSingleton().memoryClear();
      await LruCacheSingleton().storageClear();
    });

    tearDown(() {
      Config.segmentSize = originalSegmentSize;
      VideoProxy.downloadManager.dispose();
    });

    test('builds one mp4 file from all cached range segments', () async {
      final url = 'https://example.com/export.mp4';
      final uri = Uri.parse(url);
      await _cacheContentLength(uri, 10);
      await _cacheRange(uri, 0, 3, [0, 1, 2, 3]);
      await _cacheRange(uri, 4, 7, [4, 5, 6, 7]);
      await _cacheRange(uri, 8, 9, [8, 9]);

      final file = await VideoCaching.exportCachedMp4(
        url,
        downloadMissingSegments: false,
      );

      expect(file, isNotNull);
      expect(await file!.readAsBytes(), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    });

    test('returns null when a required segment is missing and download is off',
        () async {
      final url = 'https://example.com/missing.mp4';
      final uri = Uri.parse(url);
      await _cacheContentLength(uri, 10);
      await _cacheRange(uri, 0, 3, [0, 1, 2, 3]);

      final file = await VideoCaching.exportCachedMp4(
        url,
        downloadMissingSegments: false,
      );

      expect(file, isNull);
    });

    test('returns null for non-mp4 urls', () async {
      final file = await VideoCaching.exportCachedMp4(
        'https://example.com/playlist.m3u8',
        downloadMissingSegments: false,
      );

      expect(file, isNull);
    });

    test('downloads only missing ranges before exporting', () async {
      final url = 'https://example.com/partial.mp4';
      final uri = Uri.parse(url);
      final parser = _ExportStubUrlParserMp4([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      await _cacheRange(uri, 0, 3, [0, 1, 2, 3]);

      final file = await Mp4CacheExporter(parser: parser).export(url);

      expect(file, isNotNull);
      expect(await file!.readAsBytes(), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(parser.downloadedRanges, ['4-7', '8-9']);
    });

    test('returns null when timeout expires while filling missing ranges',
        () async {
      final url = 'https://example.com/timeout.mp4';
      final parser = _ExportStubUrlParserMp4(
        [0, 1, 2, 3],
        downloadDelay: const Duration(milliseconds: 50),
      );

      final file = await Mp4CacheExporter(parser: parser).export(
        url,
        timeout: const Duration(milliseconds: 1),
      );

      expect(file, isNull);
    });
  });
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 1),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition() && stopwatch.elapsed < timeout) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _cacheContentLength(Uri uri, int contentLength) async {
  final task = DownloadTask(
    uri: uri,
    startRange: 0,
    endRange: 1,
  );
  task.cacheDir = await FileExt.createCachePath(uri.generateMd5);
  final file = File(task.savePath);
  await file.writeAsString(contentLength.toString());
  await LruCacheSingleton().storagePut(task.matchUrl, file);
}

Future<void> _cacheRange(
  Uri uri,
  int startRange,
  int endRange,
  List<int> bytes,
) async {
  final task = DownloadTask(
    uri: uri,
    startRange: startRange,
    endRange: endRange,
  );
  task.cacheDir = await FileExt.createCachePath(uri.generateMd5);
  final file = File(task.savePath);
  await file.writeAsBytes(bytes);
  await LruCacheSingleton().storagePut(task.matchUrl, file);
}
