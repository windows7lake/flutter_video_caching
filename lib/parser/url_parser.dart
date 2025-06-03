import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../download/download_task.dart';

abstract class UrlParser {
  /// Get the cache data from memory or file.
  Future<Uint8List?> cache(DownloadTask task);

  /// Download the data from network.
  Future<Uint8List?> download(DownloadTask task);

  /// Push the task to the download manager.
  Future<void> push(DownloadTask task);

  /// Parse the data from the socket.
  Future<bool> parse(Socket socket, Uri uri, Map<String, String> headers);

  /// Precache the video URL
  Future<StreamController<Map>?> precache(
      String url, int cacheSegments, bool downloadNow, bool progressListen);
}
