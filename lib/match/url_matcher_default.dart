import 'url_matcher.dart';

class UrlMatcherDefault extends UrlMatcher {
  @override
  bool matchM3u8(Uri uri) {
    return uri.path.toLowerCase().endsWith('.m3u8');
  }

  @override
  bool matchM3u8Key(Uri uri) {
    return uri.path.toLowerCase().endsWith('.key');
  }

  @override
  bool matchM3u8Segment(Uri uri) {
    return uri.path.toLowerCase().endsWith('.ts');
  }

  @override
  bool matchMp4(Uri uri) {
    return uri.path.toLowerCase().endsWith('.mp4');
  }
}
