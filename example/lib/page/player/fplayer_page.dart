import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_video_caching/ext/log_ext.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';
import 'package:fplayer/fplayer.dart';
import 'package:screen_brightness/screen_brightness.dart';

class FPlayerPage extends StatefulWidget {
  const FPlayerPage({super.key});

  @override
  State<FPlayerPage> createState() => _FPlayerPageState();
}

class _FPlayerPageState extends State<FPlayerPage> {
  final FPlayer player = FPlayer();

  // 视频列表
  List<VideoItem> videoList = [
    VideoItem(
      title: '第一集',
      subTitle: '视频1副标题',
      url: 'http://player.alicdn.com/video/aliyunmedia.mp4',
    ),
    VideoItem(
      title: '第二集',
      subTitle: '视频2副标题',
      url: 'https://www.runoob.com/try/demo_source/mov_bbb.mp4',
    ),
    VideoItem(
      title: '第三集',
      subTitle: '视频3副标题',
      url:
          'https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8',
    ),
  ];

  // 倍速列表
  Map<String, double> speedList = {
    "2.0": 2.0,
    "1.5": 1.5,
    "1.0": 1.0,
    "0.5": 0.5,
  };

  // 清晰度列表
  Map<String, ResolutionItem> resolutionList = {
    "480P": ResolutionItem(
      value: 480,
      url: 'https://www.runoob.com/try/demo_source/mov_bbb.mp4',
    ),
    "270P": ResolutionItem(
      value: 270,
      url: 'http://player.alicdn.com/video/aliyunmedia.mp4',
    ),
  };

  // 视频索引,单个视频可不传
  int videoIndex = 0;

  // 模拟播放记录视频初始化完需要跳转的进度
  int seekTime = 100000;

  @override
  void initState() {
    super.initState();
    startPlay();
  }

  void startPlay() async {
    // 视频播放相关配置
    await player.setOption(FOption.hostCategory, "enable-snapshot", 1);
    await player.setOption(FOption.hostCategory, "request-screen-on", 1);
    await player.setOption(FOption.hostCategory, "request-audio-focus", 1);
    await player.setOption(FOption.playerCategory, "reconnect", 20);
    await player.setOption(FOption.playerCategory, "framedrop", 20);
    await player.setOption(FOption.playerCategory, "enable-accurate-seek", 1);
    await player.setOption(FOption.playerCategory, "mediacodec", 1);
    await player.setOption(FOption.playerCategory, "packet-buffering", 0);
    await player.setOption(FOption.playerCategory, "soundtouch", 1);

    // 播放视频列表的第一个视频
    // setVideoUrl(videoList[videoIndex].url.toLocalUrl());
    setVideoUrl(videoList[videoIndex].url);
  }

  Future<void> setVideoUrl(String url) async {
    try {
      await player.setDataSource(url, autoPlay: true, showCover: true);
    } catch (error) {
      logW("播放-异常: $error");
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQueryData = MediaQuery.of(context);
    Size size = mediaQueryData.size;
    double videoHeight = size.width * 9 / 16;
    return Scaffold(
      appBar: AppBar(
        title: Text('FPlayer'),
      ),
      body: Column(
        children: [
          FView(
            player: player,
            width: double.infinity,
            height: videoHeight,
            color: Colors.black,
            fsFit: FFit.contain,
            // 全屏模式下的填充
            fit: FFit.fill,
            // 正常模式下的填充
            panelBuilder: fPanelBuilder(
              // 单视频配置
              title: '视频标题',
              subTitle: '视频副标题',
              // 右下方截屏按钮
              isSnapShot: true,
              // 右上方按钮组开关
              isRightButton: true,
              // 右上方按钮组
              rightButtonList: [
                InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColorLight,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColorLight,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(5),
                      ),
                    ),
                    child: Icon(
                      Icons.thumb_up,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                )
              ],
              // 字幕功能：待内核提供api
              // caption: true,
              // 视频列表开关
              isVideos: true,
              // 视频列表列表
              videoList: videoList,
              // 当前视频索引
              videoIndex: videoIndex,
              // 全屏模式下点击播放下一集视频按钮
              playNextVideoFun: () {
                setState(() {
                  videoIndex += 1;
                });
              },
              settingFun: () {
                logD('设置按钮点击事件');
              },
              // 自定义倍速列表
              speedList: speedList,
              // 清晰度开关
              isResolution: true,
              // 自定义清晰度列表
              resolutionList: resolutionList,
              // 视频播放错误点击刷新回调
              onError: () async {
                await player.reset();
                setVideoUrl(videoList[videoIndex].url.toLocalUrl());
              },
              // 视频播放完成回调
              onVideoEnd: () async {
                var index = videoIndex + 1;
                if (index < videoList.length) {
                  await player.reset();
                  setState(() {
                    videoIndex = index;
                  });
                  setVideoUrl(videoList[index].url.toLocalUrl());
                }
              },
              onVideoTimeChange: () {
                // 视频时间变动则触发一次，可以保存视频播放历史
              },
              onVideoPrepared: () async {
                // 视频初始化完毕，如有历史记录时间段则可以触发快进
                try {
                  if (seekTime >= 1) {
                    /// seekTo必须在FState.prepared
                    logD('seekTo');
                    await player.seekTo(seekTime);
                    // logD("视频快进-$seekTime");
                    seekTime = 0;
                  }
                } catch (error) {
                  logD("视频初始化完快进-异常: $error");
                }
              },
            ),
          ),
          // 自定义小屏列表
          Container(
            width: double.infinity,
            height: 30,
            margin: const EdgeInsets.all(20),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: videoList.length,
              itemBuilder: (context, index) {
                bool isCurrent = videoIndex == index;
                Color textColor = Theme.of(context).primaryColor;
                Color bgColor = Theme.of(context).primaryColorDark;
                Color borderColor = Theme.of(context).primaryColor;
                if (isCurrent) {
                  textColor = Theme.of(context).primaryColorDark;
                  bgColor = Theme.of(context).primaryColor;
                  borderColor = Theme.of(context).primaryColor;
                }
                return GestureDetector(
                  onTap: () async {
                    await player.reset();
                    setState(() {
                      videoIndex = index;
                    });
                    setVideoUrl(videoList[index].url.toLocalUrl());
                  },
                  child: Container(
                    margin: EdgeInsets.only(left: index == 0 ? 0 : 10),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: bgColor,
                      border: Border.all(
                        width: 1.5,
                        color: borderColor,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      videoList[index].title,
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() async {
    VideoProxy.downloadManager.removeAllTask();
    super.dispose();
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (e) {
      logE(e);
      throw 'Failed to reset brightness';
    }
    player.release();
  }
}
