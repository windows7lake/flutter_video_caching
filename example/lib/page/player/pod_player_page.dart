import 'package:flutter/material.dart';
import 'package:flutter_video_caching/ext/string_ext.dart';
import 'package:pod_player/pod_player.dart';

class PodPlayerPage extends StatefulWidget {
  const PodPlayerPage({super.key});

  @override
  State<PodPlayerPage> createState() => _PodPlayerPageState();
}

class _PodPlayerPageState extends State<PodPlayerPage> {
  late final PodPlayerController controller;

  List<String> urls = [
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
  ];

  @override
  void initState() {
    PlayVideoFrom playVideoFrom = PlayVideoFrom.network(urls[0].toLocalUrl());
    controller = PodPlayerController(playVideoFrom: playVideoFrom)
      ..initialise();
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Play Page'),
      ),
      body: PodVideoPlayer(controller: controller),
    );
  }
}
