import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';

import 'main_route.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalProxyServer().start();
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
