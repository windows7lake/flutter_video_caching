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
  final PageController pageController = PageController();
  final List<String> urls = [
    'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341959_IpJiA57x83/full_hls/api_63_1741341959_IpJiA57x83.m3u8',
    'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341896_kQMmDNpe31/full_hls/api_63_1741341896_kQMmDNpe31.m3u8',
    'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341458_D3zoeHyhsS/full_hls/api_63_1741341458_D3zoeHyhsS.m3u8',
    'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341240_K8577E4A4v/full_hls/api_63_1741341240_K8577E4A4v.m3u8',
  ];

  @override
  void initState() {
    super.initState();
    initController();
  }

  void initController() {}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Demo',
      home: Scaffold(
        body: PageView.builder(
          scrollDirection: Axis.vertical,
          controller: pageController,
          // itemCount: controller.showVideoList.length,
          itemBuilder: (context, index) {
            int curIndex = index % urls.length;
            String url = urls[curIndex];
            return VideoPlayerWidget(url: url);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;

  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController playControl;

  @override
  void initState() {
    super.initState();
    Uri uri = widget.url.toLocalUri();
    // Uri uri = Uri.parse(widget.url);
    playControl = VideoPlayerController.networkUrl(uri)
      ..setLooping(true);
    playControl.initialize().then((value) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(Duration(milliseconds: 200), () {
          playControl.play();
          setState(() {});
        });
      });
    });
  }

  @override
  void dispose() {
    playControl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return playControl.value.isInitialized
        ? Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: playControl.value.aspectRatio,
                child: VideoPlayer(playControl),
              ),
              GestureDetector(
                onTap: () {
                  if (playControl.value.isPlaying) {
                    playControl.pause();
                  } else {
                    playControl.play();
                  }
                  setState(() {});
                },
                child: playControl.value.isPlaying
                    ? const Icon(
                        Icons.pause,
                        size: 30,
                        color: Colors.white,
                      )
                    : const Icon(
                        Icons.play_arrow,
                        size: 30,
                        color: Colors.white,
                      ),
              ),
              Positioned.fill(
                top: null,
                bottom: 100,
                child: SizedBox(
                  height: 20,
                  child: VideoProgressIndicator(
                    playControl,
                    allowScrubbing: true,
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
              child: const Icon(Icons.refresh),
            ),
          );
  }
}
