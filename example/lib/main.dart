import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:video_player/video_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalProxyServer().start();
  runApp(const VideoApp());
}

/// Stateful widget to fetch and then display video content.
class VideoApp extends StatefulWidget {
  const VideoApp({super.key});

  @override
  _VideoAppState createState() => _VideoAppState();
}

class _VideoAppState extends State<VideoApp> {
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
    _controller = VideoPlayerController.networkUrl(url.toLocalUri())
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Demo',
      home: Scaffold(
        body: Center(
          child: _controller.value.isInitialized
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
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
