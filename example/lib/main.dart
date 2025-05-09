import 'package:flutter/material.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';

import 'main_route.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await VideoProxy.init(logPrint: true);
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
