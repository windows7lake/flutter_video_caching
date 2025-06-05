import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_video_caching/ext/file_ext.dart';
import 'package:flutter_video_caching/ext/log_ext.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';

class PreCacheM3u8Page extends StatefulWidget {
  const PreCacheM3u8Page({super.key});

  @override
  State<PreCacheM3u8Page> createState() => _PreCacheM3u8PageState();
}

class _PreCacheM3u8PageState extends State<PreCacheM3u8Page> {
  final ValueNotifier<List<Map>> _segmentProgress = ValueNotifier([]);

  final ValueNotifier<String> _hlsKey = ValueNotifier('');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                          _segmentProgress.value = [];
                        },
                        icon: Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                          size: 24,
                        ),
                      );
              }),
        ],
      ),
      body: ValueListenableBuilder(
          valueListenable: _segmentProgress,
          builder: (ctx, segmentProgress, _) {
            return segmentProgress.isNotEmpty
                ? SingleChildScrollView(
                    child: Column(
                      children: segmentProgress.map((Map map) {
                        return Card(
                          margin:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: map.entries.map((entry) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${entry.key}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
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
                  )
                : Center(
                    child: TextButton(
                      onPressed: () {
                        VideoCaching.precache(
                          'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
                          cacheSegments: 999,
                          progressListen: true,
                        ).then((streamController) {
                          if (streamController == null) return;
                          StreamSubscription? subscription;
                          subscription =
                              streamController.stream.listen((value) {
                            logD(
                                'segment download progress: $value, ${value['hls_key']}');
                            _hlsKey.value = value['hls_key'];
                            final currentList =
                                List<Map<dynamic, dynamic>>.from(
                                    _segmentProgress.value);
                            currentList.add(value);
                            _segmentProgress.value = currentList;

                            if (value['progress'] == 1) {
                              subscription?.cancel();
                              streamController.close();
                              logD('close listener');
                              setState(() {});
                              return;
                            }
                          });
                        });
                      },
                      child: Text('Start Pre-cache'),
                    ),
                  );
          }),
    );
  }
}
