import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_video_caching/ext/log_ext.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';
import 'package:fplayer/fplayer.dart';

class FPlayerPageViewPage extends StatefulWidget {
  const FPlayerPageViewPage({super.key});

  @override
  State<FPlayerPageViewPage> createState() => _FPlayerPageViewPageState();
}

class _FPlayerPageViewPageState extends State<FPlayerPageViewPage> {
  final PageController pageController = PageController();
  final List<String> urls = [
    'https://vjs.zencdn.net/v/oceans.mp4',
    'https://player.alicdn.com/video/aliyunmedia.mp4',
    'https://www.runoob.com/try/demo_source/mov_bbb.mp4',
    'https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8',
    'https://www.tootootool.com/wp-content/uploads/2020/11/SampleVideo_176x144_5mb.3gp',
  ];
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
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
          int curIndex = index % urls.length;
          String url = urls[curIndex];
          return VideoPlayerWidget(url: url);
        },
        onPageChanged: (index) {
          currentIndex = index;
          // if (index + 1 < urls.length) {
          //   VideoCaching.precache(urls[index + 1], downloadNow: false);
          // }
        },
      ),
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    VideoProxy.downloadManager.removeAllTask();
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
  final FPlayer player = FPlayer();

  @override
  void initState() {
    super.initState();
    String url = widget.url.toLocalUrl();
    // String url = widget.url;
    initPlayControl(url);
  }

  void initPlayControl(String url) async {
    await player.setOption(FOption.hostCategory, "enable-snapshot", 1);
    await player.setOption(FOption.hostCategory, "request-screen-on", 1);
    await player.setOption(FOption.hostCategory, "request-audio-focus", 1);
    await player.setOption(FOption.playerCategory, "reconnect", 20);
    await player.setOption(FOption.playerCategory, "framedrop", 20);
    await player.setOption(FOption.playerCategory, "enable-accurate-seek", 1);
    await player.setOption(FOption.playerCategory, "mediacodec", 1);
    await player.setOption(FOption.playerCategory, "packet-buffering", 0);
    await player.setOption(FOption.playerCategory, "soundtouch", 1);
    setVideoUrl(url);
  }

  Future<void> setVideoUrl(String url) async {
    try {
      await player.setDataSource(url, autoPlay: true, showCover: true);
    } catch (error) {
      logW("play error: $error");
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FView(
      player: player,
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      fsFit: FFit.contain,
      fit: FFit.contain,
      panelBuilder: fPanelBuilder(
        title: 'Video title',
        subTitle: 'Video subtitle',
        onError: () async {
          await player.reset();
          setVideoUrl(widget.url.toLocalUrl());
        },
      ),
    );
  }

  @override
  void dispose() {
    player.release();
    super.dispose();
  }
}
