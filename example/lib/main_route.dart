import 'package:example/page/precache/pre_cache_m3u8_page.dart';
import 'package:example/page/precache/pre_cache_m3u8_play.dart';
import 'package:flutter/material.dart';

import 'page/download_page.dart';
import 'page/page_view/fplayer_page_view_page.dart';
import 'page/page_view/fplayer_page_view_page2.dart';
import 'page/http_client_custom_page.dart';
import 'page/m3u8_parser_page.dart';
import 'page/player/flick_player_page.dart';
import 'page/player/fplayer_page.dart';
import 'page/player/media_kit_page.dart';
import 'page/player/pod_player_page.dart';
import 'page/player/video_play_page.dart';
import 'page/storage_cache_page.dart';
import 'page/page_view/video_page_view_page.dart';

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
    'http://vjs.zencdn.net/v/oceans.mp4',
    'https://customer-fzuyyy7va6ohx90h.cloudflarestream.com/861279ab37d84dbfbf3247322fbcfc63/manifest/video.m3u8',
    'http://mirror.aarnet.edu.au/pub/TED-talks/911Mothers_2010W-480p.mp4',
    'https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8',
  ];

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
