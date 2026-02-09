import 'package:flutter/material.dart';
import 'package:flutter_video_caching/ext/log_ext.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';
import 'package:fplayer/fplayer.dart';

class FPlayerPageViewPage2 extends StatefulWidget {
  const FPlayerPageViewPage2({super.key});

  @override
  State<FPlayerPageViewPage2> createState() => _FPlayerPageViewPageState();
}

class _FPlayerPageViewPageState extends State<FPlayerPageViewPage2> {
  final PageController pageController = PageController();
  final List<String> urls = [
    'https://vjs.zencdn.net/v/oceans.mp4',
    'https://player.alicdn.com/video/aliyunmedia.mp4',
    'https://www.runoob.com/try/demo_source/mov_bbb.mp4',
    'https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8',
    'https://www.tootootool.com/wp-content/uploads/2020/11/SampleVideo_176x144_5mb.3gp',
  ];
  final Map<String, FPlayer> playControllers = {};

  void initPlayControl(FPlayer player, String url,
      {bool autoPlay = false}) async {
    await player.setOption(FOption.hostCategory, "enable-snapshot", 1);
    await player.setOption(FOption.hostCategory, "request-screen-on", 1);
    await player.setOption(FOption.hostCategory, "request-audio-focus", 1);
    await player.setOption(FOption.playerCategory, "reconnect", 20);
    await player.setOption(FOption.playerCategory, "framedrop", 20);
    await player.setOption(FOption.playerCategory, "enable-accurate-seek", 1);
    await player.setOption(FOption.playerCategory, "mediacodec", 1);
    await player.setOption(FOption.playerCategory, "packet-buffering", 0);
    await player.setOption(FOption.playerCategory, "soundtouch", 1);
    try {
      await player.setDataSource(url.toLocalUrl(),
          autoPlay: autoPlay, showCover: true);
    } catch (error) {
      logW("play error: $error");
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 2; i++) {
      String url = urls[i];
      if (!playControllers.containsKey(url)) {
        playControllers[url] = FPlayer();
        initPlayControl(playControllers[url]!, url, autoPlay: i == 0);
      }
    }
  }

  void initFPlayer(String url) {
    if (!playControllers.containsKey(url)) {
      playControllers[url] = FPlayer();
      initPlayControl(playControllers[url]!, url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video PageView'),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: pageController,
        itemCount: urls.length,
        itemBuilder: (context, index) {
          return VideoPlayerWidget(fPlayer: playControllers[urls[index]]!);
        },
        onPageChanged: (index) {
          String pre = index == 0 ? "" : urls[index - 1];
          if (pre.isNotEmpty) initFPlayer(pre);
          String after = index >= urls.length - 1 ? "" : urls[index + 1];
          if (after.isNotEmpty) initFPlayer(after);
          playControllers[pre]?.pause();
          playControllers[after]?.pause();
          playControllers[urls[index]]?.start();
          List<String> keys = [];
          for (var entry in playControllers.entries) {
            if (entry.key != pre &&
                entry.key != after &&
                entry.key != urls[index]) {
              entry.value.pause();
              entry.value.release();
              keys.add(entry.key);
            }
          }
          playControllers.removeWhere((key, value) => keys.contains(key));
        },
      ),
    );
  }

  @override
  void dispose() {
    playControllers.values.map((e) => e.release());
    pageController.dispose();
    VideoProxy.downloadManager.removeAllTask();
    super.dispose();
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final FPlayer fPlayer;

  const VideoPlayerWidget({super.key, required this.fPlayer});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  @override
  Widget build(BuildContext context) {
    return FView(
      player: widget.fPlayer,
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      fsFit: FFit.contain,
      fit: FFit.contain,
      panelBuilder: fPanelBuilder(
        title: 'Video title',
        subTitle: 'Video subtitle',
        onError: () async {
          await widget.fPlayer.reset();
        },
      ),
    );
  }
}
