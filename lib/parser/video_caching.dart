import 'dart:io';

import 'url_parser.dart';
import 'url_parser_default.dart';
import 'url_parser_m3u8.dart';
import 'url_parser_mp4.dart';

class VideoCaching {
  static final List<UrlParser> _parsers = [
    UrlParserM3U8(),
    UrlParserMp4(),
    UrlParserDefault(),
  ];

  /// Parse the URL and cache the video
  static Future<void> parse(
    Socket socket,
    Uri uri,
    Map<String, String> headers,
  ) async {
    for (UrlParser parser in _parsers) {
      if (parser.match(uri)) {
        await parser.parse(socket, uri, headers);
        break;
      }
    }
  }

  /// Precache the video URL
  ///
  /// [url]: The URL to be precached.<br>
  /// [cacheSegments]: The number of segments to be cached, default is 2.<br>
  /// [downloadNow]: Whether to download the segments now, default is true, false will be pushed to the queue.
  static void precache(
    String url, {
    int cacheSegments = 2,
    bool downloadNow = true,
  }) {
    for (UrlParser parser in _parsers) {
      if (parser.match(Uri.parse(url))) {
        parser.precache(url, cacheSegments, downloadNow);
        break;
      }
    }
  }
}
