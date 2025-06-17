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

  @override
  Uri matchCacheKey(Uri uri) {
    Map<String, String> params = {};
    params.addAll(uri.queryParameters);
    params.removeWhere((key, _) => key != 'startRange' && key != 'endRange');
    uri = uri.replace(queryParameters: params.isEmpty ? null : params);
    return uri;
  }
}
