import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_caching/cache/lru_cache_singleton.dart';
import 'package:flutter_video_caching/download/download_task.dart';
import 'package:flutter_video_caching/parser/url_parser_mp4.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      VideoProxy.urlMatcherImpl = UrlMatcherDefault();
      await LruCacheSingleton().memoryClear();
      await LruCacheSingleton().storageClear();
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
  });
}
