import 'package:example/matcher/url_match_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';
import 'package:media_kit/media_kit.dart';

import 'main_route.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await VideoProxy.init(
    logPrint: true,
    urlMatcher: UrlMatcherCustom(),
    // httpClientBuilder: HttpClientCustom(),
  );
  runApp(const HomeApp());
}

class HomeApp extends StatelessWidget {
  const HomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home App',
      home: MainRoute(),
    );
  }
}
