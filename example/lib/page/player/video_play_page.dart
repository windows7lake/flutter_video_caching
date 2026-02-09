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
  List<String> urls = [
    'https://europe.olemovienews.com/ts4/20251025/9ao27jr9/mp4/9ao27jr9.mp4/master.m3u8',
    'https://storage.googleapis.com/weppo-app.firebasestorage.app/videos/tamires/5xath5800ge85hara2x6fd9b/hls/master.m3u8',
    'https://storage.googleapis.com/video-cdn.vdone.vn/users/19565/ConvertToFluter-1761536867738.mp4/highpp-ts.m3u8',
    'https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8',
    // 'http://8.bf8bf.com/video/shengwanwu/%E7%AC%AC01%E9%9B%86/index.m3u8',
    // 'https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8',
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8',
    // 'https://storage.googleapis.com/tiksetif-a2d3d-stream-videos/2d72aa13-9dd9-4372-b8bd-69fa30ce565c/master.m3u8',
    'https://customer-fzuyyy7va6ohx90h.cloudflarestream.com/861279ab37d84dbfbf3247322fbcfc63/manifest/video.m3u8',
    // 'https://t.vchaturl.com/60af0a4a4a8771f0bfb387c7371d0102/video/9e462fae647e406ab1ecef64695c8b8d-337ae773f8993fc0d8e6dce1a471c3cf-video-ld-encrypt-stream.m3u8?MtsHlsUriToken=jyL/MHXnUFyNC/Aekt7%2BZ5VKReuFC7TgGlei6lPSk8Z4l3w3C89lcJtMMlXhg/JqCNVVlcLWP0jy8f2UJI2d4A==',
    'https://vjs.zencdn.net/v/oceans.mp4',
    'https://user-images.githubusercontent.com/28951144/229373695-22f88f13-d18f-4288-9bf1-c3e078d83722.mp4',
    'https://www.sample-videos.com/video321/3gp/240/big_buck_bunny_240p_30mb.3gp',
    'https://test-videos.co.uk/vids/jellyfish/mkv/1080/Jellyfish_1080_10s_30MB.mkv',
    'https://vv.jisuzyv.com/play/DbDGZ8ka/index.m3u8',
    'https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8',
  ];

  @override
  void initState() {
    super.initState();
    initController();
    // VideoCaching.isCached(urls[0], cacheSegments: 5).then((value) {
    //   logW("cache: $value");
    // });
  }

  void initController() {
    var url = urls[0];
    String localUri = url.toLocalUrl();
    String remoteUri = localUri.toOriginUrl();
    logD('localUri: $localUri');
    // logD('remoteUri: $remoteUri');
    Uri uri = url.toLocalUri();
    // Uri uri = Uri.parse(url);
    logW('url：$url  uri：$uri');
    logW('controller initialized 1：${DateTime.now().toIso8601String()}');
    _controller = VideoPlayerController.networkUrl(uri)
      ..setLooping(true)
      ..initialize().then((_) {
        logW('controller initialized 2：${DateTime.now().toIso8601String()}');
        setState(() {});
        timer = Timer(const Duration(milliseconds: 200), () {
          _controller.play();
          setState(() {});
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
                GestureDetector(
                  onTap: () {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                    setState(() {});
                  },
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
                SizedBox(
                  height: 20,
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                  ),
                ),
                Positioned.fill(
                  child: Offstage(
                    offstage: _controller.value.isPlaying,
                    child: GestureDetector(
                      onTap: () {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                        setState(() {});
                      },
                      child: Icon(
                        Icons.play_circle,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
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
          LruCacheSingleton().removeCacheByUrl(urls[0]);
          Navigator.pop(context);
        },
        child: Icon(Icons.code),
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
