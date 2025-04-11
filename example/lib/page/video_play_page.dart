import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:video_player/video_player.dart';

class VideoPlayPage extends StatefulWidget {
  const VideoPlayPage({super.key});

  @override
  State<VideoPlayPage> createState() => _VideoPlayPageState();
}

class _VideoPlayPageState extends State<VideoPlayPage> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    initController();
  }

  void initController() {
    // 'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH_hls.m3u8'))
    // 'http://127.0.0.1:12000/api_1547501_1737362677_2U3MjWuhgH_hls.m3u8?redirect=https://cp4.100.com.tw/video/hls/2025/01/20'))
    // 'http://127.0.0.1:12000?url=https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH_hls_00001.ts'))
    // 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'))
    // 'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/v2/fileSequence64.ts'))
    // 'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8'))
    // 'https://t100upload.s3.ap-northeast-1.amazonaws.com/video/hls/2024/12/25/api_64_1734338254_NUcT15ZNmE.m3u8'))
    // 'https://t100upload.s3.ap-northeast-1.amazonaws.com/video/hls/2024/12/25/api_64_1734338254_NUcT15ZNmE_hls_00001.ts'))
    var url =
        'https://cp4.100.com.tw/short_video/2025/02/27/api_63_1740649413_DHxpJR9NOT/full_hls/api_63_1740649413_DHxpJR9NOT.m3u8';
    String localUri = url.toLocalUrl();
    String remoteUri = localUri.toOriginUrl();
    print('localUri: $localUri');
    print('remoteUri: $remoteUri');
    Uri uri = url.toLocalUri();
    // Uri uri = Uri.parse(remoteUri);
    _controller = VideoPlayerController.networkUrl(uri)
      ..initialize().then((_) {
        setState(() {});
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
                child: const Icon(Icons.refresh),
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
    _controller.dispose();
    super.dispose();
  }
}
