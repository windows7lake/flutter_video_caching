abstract class UrlMatcher {
  /// Determine which URIs match the .m3u8 file format
  bool matchM3u8(Uri uri);

  /// Determine which URIs match the m3u8 encryption key format
  bool matchM3u8Key(Uri uri);

  /// Determine which URIs match the .m3u8 media segment format
  bool matchM3u8Segment(Uri uri);

  /// Determine which URIs match the .mp4 file format
  bool matchMp4(Uri uri);

  /// Determine which URIs match the key of download cache
  Uri matchCacheKey(Uri uri);
}
