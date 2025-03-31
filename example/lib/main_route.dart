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
    'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341959_IpJiA57x83/full_hls/api_63_1741341959_IpJiA57x83.m3u8',
    'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341896_kQMmDNpe31/full_hls/api_63_1741341896_kQMmDNpe31.m3u8',
    'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341458_D3zoeHyhsS/full_hls/api_63_1741341458_D3zoeHyhsS.m3u8',
    'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341240_K8577E4A4v/full_hls/api_63_1741341240_K8577E4A4v.m3u8',
  ];

  @override
  void initState() {
    super.initState();
      for (int i = 0; i < urls.length; i++) {
      VideoPreCaching.loadM3u8(urls[i]);
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
