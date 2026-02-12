import 'package:example/page/precache/pre_cache_m3u8_page.dart';
import 'package:example/page/precache/pre_cache_m3u8_play.dart';
import 'package:flutter/material.dart';
import 'package:flutter_video_caching/ext/log_ext.dart';
import 'package:flutter_video_caching/parser/video_caching.dart';

import 'page/download_page.dart';
import 'page/http_client_custom_page.dart';
import 'page/m3u8_parser_page.dart';
import 'page/page_view/fplayer_page_view_page.dart';
import 'page/page_view/fplayer_page_view_page2.dart';
import 'page/page_view/video_page_view_page.dart';
import 'page/player/flick_player_page.dart';
import 'page/player/fplayer_page.dart';
import 'page/player/media_kit_page.dart';
import 'page/player/pod_player_page.dart';
import 'page/player/video_play_page.dart';
import 'page/storage_cache_page.dart';

class MainRoute extends StatefulWidget {
  const MainRoute({super.key});

  @override
  State<MainRoute> createState() => _MainRouteState();
}

class _MainRouteState extends State<MainRoute> {
  final Map<String, Widget> _routes = {
    'Download': const DownloadPage(),
    'M3u8Parser': const M3u8ParserPage(),
    'Pre-CacheM3u8': const PreCacheM3u8Page(),
    'Pre-CacheM3u8 Play': const PreCacheM3u8Play(),
    'VideoPlay': const VideoPlayPage(),
    'VideoPageView': const VideoPageViewPage(),
    'StorageCache': const StorageCachePage(),
    'FPlayer': const FPlayerPage(),
    'FPlayerPageView': const FPlayerPageViewPage(),
    'FPlayerPageView2': const FPlayerPageViewPage2(),
    'FlickPlayerPage': const FlickPlayerPage(),
    'PodPlayerPage': const PodPlayerPage(),
    'MediaKitPage': const MediaKitPage(),
    'HttpClientCustom': const HttpClientCustomPage(),
  };
  final List<String> urls = [
    'https://vip.dytt-cine.com/20251215/64622_4555b7a6/index.m3u8',
    'https://video.rizzult.ai/story_content/17664301838250.mov',
    'http://jiexi.yuandongkj.top/Vtche/BF/3749826515.m3u8',
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
    cacheVideos();
  }

  void cacheVideos() async {
    logW('isCached: ${await VideoCaching.isCached(urls[6], cacheSegments: 3)}');
    VideoCaching.precache(urls[6], cacheSegments: 3).then((value) {
      logW('preCache done: $value');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_video_caching'),
      ),
      body: ListView.builder(
        itemCount: _routes.length,
        itemBuilder: (context, index) {
          final String key = _routes.keys.elementAt(index);
          final Widget value = _routes[key]!;
          return ListTile(
            title: Text(key),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => value),
              );
            },
          );
        },
      ),
    );
  }
}
