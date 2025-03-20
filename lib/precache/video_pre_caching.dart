import '../flutter_video_cache.dart';

class VideoPreCaching {
  static void loadM3u8(String url, {int cacheSegments = 2}) async {
    List<String> mediaList = await HlsParser().parseSegment(url);
    if (mediaList.isEmpty) return;
    final List<String> segments = mediaList.take(cacheSegments).toList();
    for (final String segment in segments) {
      HlsParser().downloadSync(DownloadTask(url: segment));
    }
  }

  static void loadM3u8List(List<String> urls) {
    for (final String url in urls) {
      loadM3u8(url);
    }
  }
}
