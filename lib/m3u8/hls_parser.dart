import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:flutter_video_cache/ext/int_ext.dart';
import 'package:flutter_video_cache/ext/uri_ext.dart';

import '../download/download_isolate_pool.dart';
import '../download/download_status.dart';
import '../download/download_task.dart';
import '../ext/log_ext.dart';
import '../memory/video_memory_cache.dart';
import '../proxy/video_proxy.dart';

/// M3U8 HLS parser
class HlsParser {
  /// 解析M3U8数据行
  Future<HlsPlaylist?> parseLines(List<String> lines) async {
    HlsPlaylist? playList;
    try {
      playList = await VideoProxy.hlsPlaylistParser.parse(Uri.base, lines);
    } catch (e) {
      logE('Exception: ${e}');
    }
    return playList;
  }

  /// 解析M3U8分辨率列表
  Future<HlsPlaylist?> parsePlaylist(Uri uri) async {
    Uint8List? uint8List = await downloadTask(DownloadTask(uri: uri));
    if (uint8List == null) return null;
    List<String> lines = readLineFromUint8List(uint8List);
    final HlsPlaylist? playList = await parseLines(lines);
    return playList;
  }

  /// 解析M3U8媒体播放列表
  Future<HlsMediaPlaylist?> parseMediaPlaylist(Uri uri) async {
    final HlsPlaylist? playList = await parsePlaylist(uri);
    if (playList is HlsMasterPlaylist) {
      for (final Uri? _uri in playList.mediaPlaylistUrls) {
        if (_uri == null) continue;
        Uri masterUri = Uri.parse('${uri.pathPrefix}${_uri.path}');
        HlsMediaPlaylist? mediaPlayList = await parseMediaPlaylist(masterUri);
        return mediaPlayList;
      }
    } else if (playList is HlsMediaPlaylist) {
      return playList;
    }
    return null;
  }

  /// 解析M3U8 ts文件
  Future<List<String>> parseSegment(Uri uri) async {
    final HlsMediaPlaylist? playList = await parseMediaPlaylist(uri);
    if (playList == null) return <String>[];
    List<String> segments = <String>[];
    for (final Segment segment in playList.segments) {
      String? segmentUrl = segment.url;
      if (segmentUrl != null && !segmentUrl.startsWith('http')) {
        segmentUrl = '${uri.pathPrefix}/$segmentUrl';
      }
      if (segmentUrl == null) continue;
      segments.add(segmentUrl);
    }
    return segments;
  }

  Future<void> addTask(DownloadTask task) async {
    final md5 = task.uri.generateMd5;
    Uint8List? memoryCache = await VideoMemoryCache.get(md5);
    if (memoryCache != null) return;
    String cachePath = await DownloadIsolatePool.createVideoCachePath();
    File file = File('$cachePath/${task.saveFile}');
    if (file.existsSync()) return;
    await VideoProxy.downloadManager.addTask(task);
  }

  Future<Uint8List?> downloadTask(DownloadTask task) async {
    final md5 = task.uri.generateMd5;
    Uint8List? memoryCache = await VideoMemoryCache.get(md5);
    if (memoryCache != null) {
      logD('从内存中获取数据: ${memoryCache.lengthInBytes.toMemorySize}');
      logD('当前内存占用: ${(await VideoMemoryCache.size()).toMemorySize}');
      return memoryCache;
    }
    String cachePath = await DownloadIsolatePool.createVideoCachePath();
    File file = File('$cachePath/${task.saveFile}');
    if (file.existsSync()) {
      logD('从数据库中获取数据');
      Uint8List fileCache = await file.readAsBytes();
      await VideoMemoryCache.put(md5, fileCache);
      return fileCache;
    } else {
      logD('从网络中获取数据，正在下载中');
      Uint8List? netData;
      task.priority += 10;
      await VideoProxy.downloadManager.executeTask(task);
      await for (DownloadTask downloadTask
          in VideoProxy.downloadManager.stream) {
        if (downloadTask.status == DownloadStatus.COMPLETED &&
            downloadTask.url == task.url) {
          netData = Uint8List.fromList(downloadTask.data);
          break;
        }
      }
      return netData;
    }
  }

  List<String> readLineFromUint8List(Uint8List uint8List) {
    final List<String> lines = [];
    final Utf8Codec codec = Utf8Codec();
    int startIndex = 0;
    int lastIndex = 0;
    for (var byte in uint8List) {
      if (byte == 0x0A) {
        final line = uint8List.sublist(startIndex, lastIndex);
        lines.add(codec.decode(line));
        startIndex = lastIndex + 1;
      }
      lastIndex++;
    }
    return lines;
  }
}
