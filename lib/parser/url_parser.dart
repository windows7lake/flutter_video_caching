import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../download/download_task.dart';

/// Abstract class that defines the interface for URL parsers.
/// Implementations are responsible for handling video URL parsing,
/// caching, downloading, and precaching logic.
abstract class UrlParser {
  /// Retrieves cached data for the given [task] from memory or file.
  ///
  /// Returns a [Uint8List] containing the cached data if available,
  /// or `null` if the data is not cached.
  Future<Uint8List?> cache(DownloadTask task);

  /// Downloads data from the network for the given [task].
  ///
  /// Returns a [Uint8List] containing the downloaded data,
  /// or `null` if the download fails.
  Future<Uint8List?> download(DownloadTask task);

  /// Pushes the [task] to the download manager for processing.
  Future<void> push(DownloadTask task);

  /// Parses data from the given [socket] using the specified [uri] and [headers].
  ///
  /// Returns `true` if parsing is successful, otherwise `false`.
  Future<bool> parse(Socket socket, Uri uri, Map<String, String> headers);

  /// Whether the video is cached.
  ///
  /// [url]: The video URL to check.
  /// [headers]: Optional HTTP headers to use for the request.
  /// [cacheSegments]: Number of segments to cache.
  ///
  /// Returns `true` if the video is cached, otherwise `false`.
  Future<bool> isCached(
    String url,
    Map<String, Object>? headers,
    int cacheSegments,
  );

  /// Pre-caches the video at the specified [url].
  ///
  /// [url]: The video URL to precache.
  /// [headers]: Optional HTTP headers to use for the request.
  /// [cacheSegments]: Number of segments to cache.
  /// [downloadNow]: Whether to start downloading immediately.
  /// [progressListen]: Whether to listen for download progress.
  ///
  /// Returns a [StreamController] that emits progress or status updates,
  /// or `null` if precaching is not supported.
  Future<StreamController<Map>?> precache(
    String url,
    Map<String, Object>? headers,
    int cacheSegments,
    bool downloadNow,
    bool progressListen,
  );
}
