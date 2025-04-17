import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_video_cache/ext/log_ext.dart';

import '../download/download_isolate_pool.dart';
import '../download/download_status.dart';
import '../download/download_task.dart';
import '../ext/string_ext.dart';
import '../memory/video_memory_cache.dart';
import 'hls_parser.dart';

class HlsMap {
  static final List<HlsSegment> _list = <HlsSegment>[];

  static List<HlsSegment> get list => _list;

  static void add(HlsSegment segment) {
    bool match = _list.where((e) => e.url == segment.url).isNotEmpty;
    if (!match) _list.add(segment);
  }

  static void complete(HlsSegment segment, {DownloadStatus? status}) {
    int index = _list.indexWhere((e) => e.url == segment.url);
    if (index == -1) return;
    _list[index].status = status ?? DownloadStatus.COMPLETED;
    Set<String> keys = _list.map((e) => e.key).toSet();
    String key = keys.elementAt(Random().nextInt(keys.length));
    logW("keys: $keys");
    logW("key: $key");
    HlsSegment? idleSegment = _list
        .where((e) => e.key == key)
        .where((e) => e.status == DownloadStatus.IDLE)
        .firstOrNull;
    if (idleSegment == null) {
      _list.removeWhere((e) => e.key == key);
      complete(segment);
      return;
    }
    concurrent(idleSegment.url);
  }

  static void concurrent(String url) async {
    Set<String> keys = _list.map((e) => e.key).toSet();
    if (keys.length > 2) {
      _list.removeWhere((e) => e.key == keys.first);
    }
    HlsSegment? segment = _list.where((e) => e.url == url).firstOrNull;
    if (segment == null) return;
    final downloading = _list
        .where((e) => e.key == segment.key)
        .where((e) => e.status == DownloadStatus.DOWNLOADING)
        .toList();
    if (downloading.length >= 4) return;
    final cache = await VideoMemoryCache.get(segment.url.generateMd5);
    if (cache != null) {
      complete(segment);
      return;
    }
    DownloadTask task = DownloadTask(uri: Uri.parse(segment.url));
    String cachePath = await DownloadIsolatePool.createVideoCachePath();
    File file = File('$cachePath/${task.saveFile}');
    if (file.existsSync()) {
      complete(segment);
      return;
    }
    final exitUri = HlsParser().downloadManager.isUrlExit(task.url);
    if (exitUri) {
      complete(segment, status: DownloadStatus.DOWNLOADING);
      return;
    }
    HlsParser().downloadManager.executeTask(task);
    HlsParser().downloadManager.stream.listen((downloadTask) {
      if (downloadTask.status == DownloadStatus.COMPLETED &&
          downloadTask.id == task.id) {
        final netData = Uint8List.fromList(downloadTask.data);
        VideoMemoryCache.put(segment.url.generateMd5, netData);
        complete(segment);
      }
    });
  }
}

class HlsSegment {
  final String key;
  final String url;
  DownloadStatus status = DownloadStatus.IDLE;

  HlsSegment({
    required this.key,
    required this.url,
  });

  @override
  String toString() {
    return 'HlsSegment{key: $key, url: $url, status: $status}';
  }
}
