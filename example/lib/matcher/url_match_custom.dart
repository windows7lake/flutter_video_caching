import 'package:flutter_video_caching/flutter_video_caching.dart';

class UrlMatcherCustom extends UrlMatcherDefault {
  @override
  bool matchM3u8Key(Uri uri) {
    return uri.path.toLowerCase().endsWith('.key') ||
        uri.path.toLowerCase().endsWith('app/media/decrypt');
  }
}
