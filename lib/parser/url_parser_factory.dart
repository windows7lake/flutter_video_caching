import '../proxy/video_proxy.dart';
import 'url_parser.dart';
import 'url_parser_default.dart';
import 'url_parser_m3u8.dart';
import 'url_parser_mp4.dart';

/// Factory class for creating appropriate [UrlParser] instances
/// based on the given [Uri] type.
///
/// This factory inspects the URI and returns a parser implementation
/// for M3U8, MP4, or a default parser for other formats.
class UrlParserFactory {
  /// Creates and returns a suitable [UrlParser] implementation
  /// according to the type of the provided [uri].
  ///
  /// - If the URI matches an M3U8 playlist, key, or segment, returns [UrlParserM3U8].
  /// - If the URI matches an MP4 file, returns [UrlParserMp4].
  /// - Otherwise, returns [UrlParserDefault].
  ///
  /// [uri]: The URI of the video resource to be parsed.
  ///
  /// Returns: An instance of [UrlParser] for the given URI.
  static UrlParser createParser(Uri uri) {
    if (VideoProxy.urlMatcherImpl.matchM3u8(uri) ||
        VideoProxy.urlMatcherImpl.matchM3u8Key(uri) ||
        VideoProxy.urlMatcherImpl.matchM3u8Segment(uri)) {
      return UrlParserM3U8();
    } else if (VideoProxy.urlMatcherImpl.matchMp4(uri)) {
      return UrlParserMp4();
    } else {
      // Returns the default parser for other file types.
      return UrlParserDefault();
    }
  }
}
