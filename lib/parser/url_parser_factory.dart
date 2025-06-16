import '../proxy/video_proxy.dart';
import 'url_parser.dart';
import 'url_parser_default.dart';
import 'url_parser_m3u8.dart';
import 'url_parser_mp4.dart';

class UrlParserFactory {
  static UrlParser createParser(Uri uri) {
    if (VideoProxy.urlMatcherImpl.matchM3u8(uri) ||
        VideoProxy.urlMatcherImpl.matchM3u8Key(uri) ||
        VideoProxy.urlMatcherImpl.matchM3u8Segment(uri)) {
      return UrlParserM3U8();
    } else if (VideoProxy.urlMatcherImpl.matchMp4(uri)) {
      return UrlParserMp4();
    } else {
      return UrlParserDefault();
    }
  }
}
