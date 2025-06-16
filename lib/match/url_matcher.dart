abstract class UrlMatcher {
  bool matchM3u8(Uri uri);

  bool matchM3u8Key(Uri uri);

  bool matchM3u8Segment(Uri uri);

  bool matchMp4(Uri uri);
}
