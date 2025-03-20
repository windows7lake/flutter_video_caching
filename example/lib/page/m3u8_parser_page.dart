import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';

class M3u8ParserPage extends StatefulWidget {
  const M3u8ParserPage({super.key});

  @override
  State<M3u8ParserPage> createState() => _M3u8ParserPageState();
}

class _M3u8ParserPageState extends State<M3u8ParserPage> {
  final List<String> urls = [
    'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341959_IpJiA57x83/full_hls/api_63_1741341959_IpJiA57x83.m3u8',
    'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341896_kQMmDNpe31/full_hls/api_63_1741341896_kQMmDNpe31.m3u8',
    'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341458_D3zoeHyhsS/full_hls/api_63_1741341458_D3zoeHyhsS.m3u8',
    'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341240_K8577E4A4v/full_hls/api_63_1741341240_K8577E4A4v.m3u8',
  ];
  List<HlsMediaPlaylist> playlists = [];

  @override
  void initState() {
    super.initState();
    initData();
  }

  void initData() {
    for (final url in urls) {
      HlsParser().parseMediaPlaylist(url).then((value) {
        if (value == null) return;
        playlists.add(value);
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('M3u8 Parser'),
      ),
      body: ListView.builder(
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          return ExpansionTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(urls[index].split('/').last),
                Text(
                  'Total Duration: ${(playlists[index].durationUs ?? 0) / 1000000}s',
                  style: TextStyle(color: Colors.grey),
                ),
                Text(
                  'Total Segments: ${playlists[index].segments.length}',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            children: playlists[index]
                .segments
                .map((e) => Text(
                      "${e.url}",
                      style: TextStyle(color: Colors.grey),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}
