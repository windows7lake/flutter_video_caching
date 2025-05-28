import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';
import 'package:video_player/video_player.dart';

class FlickPlayerPage extends StatefulWidget {
  const FlickPlayerPage({super.key});

  @override
  State<FlickPlayerPage> createState() => _FlickPlayerPageState();
}

class _FlickPlayerPageState extends State<FlickPlayerPage> {
  List<String> urls = [
    "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4",
    "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4",
    "https://flutter.github.io/assets-for-api-docs/assets/videos/elephant.mp4",
  ];
  late FlickManager flickManager;

  @override
  void initState() {
    super.initState();
    // Uri uri = Uri.parse(urls[0]);
    Uri uri = urls[0].toLocalUri();
    var videoPlayerController = VideoPlayerController.networkUrl(uri);
    flickManager = FlickManager(videoPlayerController: videoPlayerController);
  }

  @override
  void dispose() {
    flickManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Play Page'),
      ),
      body: FlickVideoPlayer(flickManager: flickManager),
    );
  }
}
