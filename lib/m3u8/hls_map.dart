import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../download/download_isolate_pool.dart';
import '../download/download_status.dart';
import '../download/download_task.dart';
import '../ext/string_ext.dart';
import '../memory/video_memory_cache.dart';
import '../proxy/video_proxy.dart';

class HlsMap {
  static final List<HlsSegment> _list = <HlsSegment>[];

  static List<HlsSegment> get list => _list;

  static String latestUrl = "";

  static void add(HlsSegment segment) {
    bool match = _list.where((e) => e.url == segment.url).isNotEmpty;
    if (!match) _list.add(segment);
  }

  static void complete(HlsSegment segment, {DownloadStatus? status}) {
    int index = _list.indexWhere((e) => e.url == segment.url);
    if (index == -1) return;
    _list[index].status = status ?? DownloadStatus.COMPLETED;
    HlsSegment? latest = _list.where((e) => e.url == latestUrl).firstOrNull;
    if (latest != null) {
      List<HlsSegment> list = _list.where((e) => e.key == latest.key).toList();
      int index = _list.indexWhere((e) => e.url == latest.url);
      if (index != -1 && index + 1 < list.length) {
        concurrent(list[index + 1].url);
        return;
      }
    }
    Set<String> keys = _list.map((e) => e.key).toSet();
    String key = keys.elementAt(Random().nextInt(keys.length));
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
    latestUrl = url;
    Set<String> keys = _list.map((e) => e.key).toSet();
    if (keys.length > 2) {
      _list.where((e) => e.key == keys.last).forEach((e) {
        VideoProxy.downloadManager.allTasks
            .removeWhere((task) => task.url == e.url);
      });
      _list.removeWhere((e) => e.key == keys.first);
    }
    HlsSegment? segment = _list.where((e) => e.url == url).firstOrNull;
    if (segment == null) return;
    final downloading = _list
        .where((e) => e.key == segment.key)
        .where((e) => e.status == DownloadStatus.DOWNLOADING)
        .toList();
    if (downloading.length >= 2) return;
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
    final exitUri = VideoProxy.downloadManager.isUrlExit(segment.url);
    if (exitUri) {
      complete(segment, status: DownloadStatus.DOWNLOADING);
      return;
    }
    await VideoProxy.downloadManager.executeTask(task);
    StreamSubscription? subscription;
    subscription = VideoProxy.downloadManager.stream.listen((downloadTask) {
      if (downloadTask.status == DownloadStatus.COMPLETED &&
          downloadTask.url == task.url) {
        subscription?.cancel();
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
