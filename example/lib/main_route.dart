import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';

import 'page/download_page.dart';
import 'page/m3u8_parser_page.dart';
import 'page/video_page_view_page.dart';
import 'page/video_play_page.dart';

class MainRoute extends StatefulWidget {
  const MainRoute({super.key});

  @override
  State<MainRoute> createState() => _MainRouteState();
}

class _MainRouteState extends State<MainRoute> {
  final Map<String, Widget> _routes = {
    'Download': const DownloadPage(),
    'M3u8Parser': const M3u8ParserPage(),
    'VideoPlay': const VideoPlayPage(),
    'VideoPageView': const VideoPageViewPage(),
  };
  final List<String> urls = [
    'https://images.debug.100.com.tw/short_video/hls/2025/02/19/api_76_1739944065_it2uv2B37X.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740034816_gyJD2rv5iJ.m3u8',
    'https://images.debug.100.com.tw/short_video/2025/03/13/api_76_1741847328_sR96QRx6nz/full_hls/api_76_1741847328_sR96QRx6nz.m3u8',
    'https://images.debug.100.com.tw/short_video/2025/02/25/api_76_1740451086_YfIgNO1nAL/full_hls/api_76_1740451086_YfIgNO1nAL.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740041957_1mWiprwazK.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740043126_wJVXwIEOHh.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740042408_eJf8r036BT.m3u8',
  ];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < urls.length; i++) {
      // VideoPreCaching.loadM3u8(urls[i]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_video_cache'),
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
