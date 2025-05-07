import 'dart:io';
import 'dart:typed_data';

import '../download/download_task.dart';

abstract class UrlParser {
  bool match(Uri uri);

  Future<Uint8List?> cache(DownloadTask task);

  Future<Uint8List?> download(DownloadTask task);

  Future<void> push(DownloadTask task);

  Future<bool> parse(Socket socket, Uri uri, Map<String, String> headers);

  void precache(String url, int cacheSegments, bool downloadNow);
}
