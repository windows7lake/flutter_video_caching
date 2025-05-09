import 'package:flutter/material.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';

class M3u8ParserPage extends StatefulWidget {
  const M3u8ParserPage({super.key});

  @override
  State<M3u8ParserPage> createState() => _M3u8ParserPageState();
}

class _M3u8ParserPageState extends State<M3u8ParserPage> {
  final List<String> urls = [
    'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    'https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8',
    'https://test-streams.mux.dev/test_001/stream.m3u8',
  ];
  List<HlsMediaPlaylist> playlists = [];

  @override
  void initState() {
    super.initState();
    initData();
  }

  void initData() {
    for (final url in urls) {
      UrlParserM3U8().parseMediaPlaylist(Uri.parse(url)).then((value) {
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
