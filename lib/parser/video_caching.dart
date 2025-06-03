import 'dart:async';
import 'dart:io';

import 'url_parser_factory.dart';

class VideoCaching {
  /// Parse the URL and cache the video
  static Future<void> parse(
    Socket socket,
    Uri uri,
    Map<String, String> headers,
  ) async {
    await UrlParserFactory.createParser(uri).parse(socket, uri, headers);
  }

  /// Precache the video URL
  ///
  /// [url]: The URL to be precached.<br>
  /// [cacheSegments]: The number of segments to be cached, default is 2.<br>
  /// [downloadNow]: Whether to download the segments now, default is true, false will be pushed to the queue.
  static Future<StreamController<Map>?> precache(
    String url, {
    int cacheSegments = 2,
    bool downloadNow = true,
    bool progressListen = false,
  }) {
    return UrlParserFactory.createParser(Uri.parse(url))
        .precache(url, cacheSegments, downloadNow, progressListen);
  }
}
