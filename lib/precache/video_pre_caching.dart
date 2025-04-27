import '../flutter_video_cache.dart';

class VideoPreCaching {
  static void loadM3u8(
    String url, {
    int cacheSegments = 2,
    bool downloadNow = true,
  }) async {
    HlsParser hlsParser = HlsParser();
    List<String> mediaList = await hlsParser.parseSegment(Uri.parse(url));
    if (mediaList.isEmpty) return;
    final List<String> segments = mediaList.take(cacheSegments).toList();
    for (final String segment in segments) {
      DownloadTask task = DownloadTask(uri: Uri.parse(segment));
      if (downloadNow) {
        hlsParser.downloadTask(task);
      } else {
        hlsParser.addTask(task);
      }
    }
  }

  static void loadM3u8List(List<String> urls) {
    for (final String url in urls) {
      loadM3u8(url);
    }
  }
}
