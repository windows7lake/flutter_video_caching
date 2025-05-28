import 'package:flutter/material.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class MediaKitPage extends StatefulWidget {
  const MediaKitPage({super.key});

  @override
  State<MediaKitPage> createState() => _MediaKitPageState();
}

class _MediaKitPageState extends State<MediaKitPage> {
  List<String> urls = [
    'https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4',
    'http://vjs.zencdn.net/v/oceans.mp4',
    'https://customer-fzuyyy7va6ohx90h.cloudflarestream.com/861279ab37d84dbfbf3247322fbcfc63/manifest/video.m3u8',
    'https://vv.jisuzyv.com/play/DbDGZ8ka/index.m3u8',
    'https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8',
  ];

  // Create a [Player] to control playback.
  late final player = Player();

  // Create a [VideoController] to handle video output from [Player].
  late final controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    // Play a [Media] or [Playlist].
    player.open(Media(urls[0].toLocalUrl()));
    // player.open(Media(urls[0]));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Play Page'),
      ),
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * 9.0 / 16.0,
          // Use [Video] widget to display video output.
          child: Video(controller: controller),
        ),
      ),
    );
  }
}
