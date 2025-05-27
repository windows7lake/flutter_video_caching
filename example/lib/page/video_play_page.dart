import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_video_caching/ext/log_ext.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';
import 'package:video_player/video_player.dart';

class VideoPlayPage extends StatefulWidget {
  const VideoPlayPage({super.key});

  @override
  State<VideoPlayPage> createState() => _VideoPlayPageState();
}

class _VideoPlayPageState extends State<VideoPlayPage> {
  late VideoPlayerController _controller;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    initController();
  }

  void initController() {
    List<String> urls = [
      'http://vjs.zencdn.net/v/oceans.mp4',
      'https://customer-fzuyyy7va6ohx90h.cloudflarestream.com/861279ab37d84dbfbf3247322fbcfc63/manifest/video.m3u8',
      'https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8',
      'https://vv.jisuzyv.com/play/DbDGZ8ka/index.m3u8',
    ];
    var url = urls[0];
    String localUri = url.toLocalUrl();
    String remoteUri = localUri.toOriginUrl();
    logD('localUri: $localUri');
    logD('remoteUri: $remoteUri');
    Uri uri = url.toLocalUri();
    // Uri uri = Uri.parse(remoteUri);
    _controller = VideoPlayerController.networkUrl(uri)
      ..setLooping(true)
      ..initialize().then((_) {
        setState(() {});
        timer = Timer(const Duration(milliseconds: 200), () {
          _controller.play();
        });
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Play Page'),
      ),
      body: _controller.value.isInitialized
          ? Stack(
              alignment: Alignment.bottomCenter,
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                SizedBox(
                  height: 20,
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                  ),
                ),
              ],
            )
          : Container(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () {
                  setState(() {});
                },
                child: SizedBox(
                  height: 100,
                  width: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _controller.dispose();
    VideoProxy.downloadManager.removeAllTask();
    super.dispose();
  }
}
