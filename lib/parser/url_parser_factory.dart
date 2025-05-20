import 'url_parser.dart';
import 'url_parser_default.dart';
import 'url_parser_m3u8.dart';
import 'url_parser_mp4.dart';

class UrlParserFactory {
  static bool matchM3u8(Uri uri) {
    return uri.path.toLowerCase().endsWith('.m3u8') ||
        uri.path.toLowerCase().endsWith('.key') ||
        uri.path.toLowerCase().endsWith('.ts');
  }

  static bool matchMp4(Uri uri) {
    return uri.path.toLowerCase().endsWith('.mp4');
  }

  static UrlParser createParser(Uri uri) {
    if (matchM3u8(uri)) {
      return UrlParserM3U8();
    } else if (matchMp4(uri)) {
      return UrlParserMp4();
    } else {
      return UrlParserDefault();
    }
  }
}
