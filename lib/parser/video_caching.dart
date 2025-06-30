import 'dart:async';
import 'dart:io';

import 'package:flutter_hls_parser/flutter_hls_parser.dart';

import '../ext/string_ext.dart';
import '../ext/uri_ext.dart';
import 'url_parser.dart';
import 'url_parser_factory.dart';
import 'url_parser_m3u8.dart';

/// Provides video caching and parsing utilities for different video formats.
/// Supports parsing, caching, and pre-caching of video resources (e.g., MP4, HLS/M3U8).
class VideoCaching {
  /// Parses the given [uri] and handles the video request via the appropriate parser.
  ///
  /// [socket]: The client socket to send the response to.
  /// [uri]: The URI of the video resource to be parsed.
  /// [headers]: HTTP headers for the request.
  ///
  /// Returns a [Future] that completes when the parsing and response are done.
  static Future<void> parse(
    Socket socket,
    Uri uri,
    Map<String, String> headers,
  ) async {
    await UrlParserFactory.createParser(uri).parse(socket, uri, headers);
  }

  /// Pre-caches the video at the specified [url].
  ///
  /// [url]: The video URL to be pre-cached.
  /// [headers]: Optional HTTP headers for the request.
  /// [cacheSegments]: Number of segments to cache (default: 2).
  /// [downloadNow]: If true, downloads segments immediately; if false, pushes to the queue (default: true).
  /// [progressListen]: If true, returns a [StreamController] with progress updates (default: false).
  ///
  /// Returns a [StreamController] emitting progress/status updates, or `null` if not listening.
  static Future<StreamController<Map>?> precache(
    String url, {
    Map<String, Object>? headers,
    int cacheSegments = 2,
    bool downloadNow = true,
    bool progressListen = false,
  }) {
    return UrlParserFactory.createParser(url.toSafeUri())
        .precache(url, headers, cacheSegments, downloadNow, progressListen);
  }

  /// Parses the HLS master playlist from the given [url].
  ///
  /// [url]: The URL of the HLS master playlist.
  /// [headers]: Optional HTTP headers for the request.
  ///
  /// Returns an [HlsMasterPlaylist] instance if successful, otherwise returns `null`.
  static Future<HlsMasterPlaylist?> parseHlsMasterPlaylist(
    String url, {
    Map<String, Object>? headers,
  }) async {
    Uri uri = url.toSafeUri();
    UrlParser parser = UrlParserFactory.createParser(uri);
    if (parser is! UrlParserM3U8) return null;
    HlsPlaylist? playlist = await parser.parsePlaylist(uri,
        headers: headers, hlsKey: uri.generateMd5);
    return playlist is HlsMasterPlaylist ? playlist : null;
  }
}
