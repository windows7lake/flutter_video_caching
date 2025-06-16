import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_video_caching/ext/file_ext.dart';
import 'package:flutter_video_caching/ext/log_ext.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';
import 'package:flutter_video_caching/global/config.dart';

import '../mixin/m3u8_mx.dart';

class PreCacheM3u8Page extends StatefulWidget {
  const PreCacheM3u8Page({super.key});

  @override
  State<PreCacheM3u8Page> createState() => _PreCacheM3u8PageState();
}

class _PreCacheM3u8PageState extends State<PreCacheM3u8Page> with M3U8MX {
  final ValueNotifier<int> _step = ValueNotifier<int>(0);
  final ValueNotifier<String> _hlsKey = ValueNotifier('');
  List<ResolutionOption> _resolutions = [];
  final List<Map> _segmentProgress = <Map>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar(),
      body: ValueListenableBuilder(
        valueListenable: _step,
        builder: (ctx, step, _) {
          if (step == 0) {
            return body();
          } else if (step == 1) {
            return hlsMasterPlaylist();
          }
          return segmentList();
        },
      ),
    );
  }

  PreferredSizeWidget appBar() {
    return AppBar(
      title: const Text('Pre-cache M3u8'),
      actions: [
        ValueListenableBuilder(
          valueListenable: _hlsKey,
          builder: (ctx, hlsKey, _) {
            return hlsKey.isEmpty
                ? SizedBox()
                : IconButton(
                    onPressed: () async {
                      String dirPath =
                          '${FileExt.cacheRootPath}/videos/$hlsKey';
                      await LruCacheSingleton().storageClearByDirPath(dirPath);
                      _segmentProgress.clear();
                      _step.value = 0;
                    },
                    icon: Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                      size: 24,
                    ),
                  );
          },
        ),
      ],
    );
  }

  Widget hlsMasterPlaylist() {
    if (_resolutions.isEmpty) {
      return Center(
        child: Text('Loading master playlist...'),
      );
    }
    return SingleChildScrollView(
      child: Column(
        children: _resolutions.map((ResolutionOption map) {
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ListTile(
              title: Text('Resolution: ${map.resolution}'),
              subtitle: Column(
                spacing: 10,
                children: [
                  Text('HLS URL:\n${map.url}'),
                  Text('Original URL:\n${map.originalUrl}'),
                ],
              ),
              trailing: TextButton(
                onPressed: () async {
                  _step.value = 2;
                  _segmentProgress.clear();
                  setState(() {});
                  VideoCaching.precache(
                    map.url,
                    headers: {Config.customCacheId: "custom_cache_id"},
                    cacheSegments: 999,
                    progressListen: true,
                  ).then((streamController) {
                    if (streamController == null) return;
                    StreamSubscription? subscription;
                    subscription = streamController.stream.listen((value) {
                      logD('segment download progress: $value');
                      _hlsKey.value = value['hls_key'];
                      _segmentProgress.add(value);
                      if (!mounted) {
                        subscription?.cancel();
                        streamController.close();
                        return;
                      }
                      setState(() {});

                      if (value['progress'] == 1) {
                        subscription?.cancel();
                        streamController.close();
                        logD('close listener');
                        return;
                      }
                    });
                  });
                },
                child: Text("Start Pre-Cache"),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget segmentList() {
    if (_segmentProgress.isEmpty) {
      return Center(
        child: Text('Loading segments...'),
      );
    }
    return SingleChildScrollView(
      child: Column(
        children: _segmentProgress.map((Map map) {
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: map.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${entry.key}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('${entry.value}'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget body() {
    return Center(
      child: TextButton(
        onPressed: () async {
          _step.value = 1;
          _segmentProgress.clear();
          String url =
              // 'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8';
              'https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8';
          _resolutions = await getResolutionOptions(url);
          setState(() {});
        },
        child: Text('Extract Video Resolution'),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    VideoProxy.downloadManager.removeAllTask();
  }
}
