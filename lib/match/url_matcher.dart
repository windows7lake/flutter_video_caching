/// An abstract class that defines a set of methods for matching and identifying
/// specific types of media-related URIs.
///
/// Implementations of this class should provide logic to:
/// - Identify if a given URI points to an `.m3u8` playlist file.
/// - Identify if a given URI points to an `.m3u8` encryption key.
/// - Identify if a given URI points to an `.m3u8` media segment (such as `.ts` files).
/// - Identify if a given URI points to an `.mp4` file.
/// - Generate or extract a cache key from a given URI, which can be used for
///   caching downloaded media resources.
///
/// This abstraction allows for flexible and testable URI matching logic,
/// which can be customized for different streaming protocols or caching strategies.
abstract class UrlMatcher {
  /// Returns `true` if the given [uri] matches the `.m3u8` playlist file format.
  bool matchM3u8(Uri uri);

  /// Returns `true` if the given [uri] matches the format of an `.m3u8` encryption key.
  bool matchM3u8Key(Uri uri);

  /// Returns `true` if the given [uri] matches the format of an `.m3u8` media segment,
  /// such as a `.ts` file.
  bool matchM3u8Segment(Uri uri);

  /// Returns `true` if the given [uri] matches the `.mp4` file format.
  bool matchMp4(Uri uri);

  /// Returns a [Uri] that represents the cache key for the given [uri].
  /// This can be used to uniquely identify cached media resources.
  Uri matchCacheKey(Uri uri);
}
