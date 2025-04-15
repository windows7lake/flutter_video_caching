import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:flutter_video_cache/ext/int_ext.dart';
import 'package:flutter_video_cache/ext/uri_ext.dart';

import '../download/download_manager.dart';
import '../download/download_status.dart';
import '../download/download_task.dart';
import '../ext/log_ext.dart';
import '../memory/video_memory_cache.dart';
import '../sqlite/table_video.dart';

/// M3U8 HLS parser
class HlsParser {
  /// 获取单例对象
  factory HlsParser() => instance;

  /// 私有构造函数
  HlsParser._();

  /// 单例对象
  static final HlsParser instance = HlsParser._();

  final HlsPlaylistParser _parser = HlsPlaylistParser.create();

  final DownloadManager downloadManager =
      DownloadManager(maxConcurrentDownloads: 4);

  /// 解析M3U8数据行
  Future<HlsPlaylist?> parseLines(List<String> lines) async {
    HlsPlaylist? playList;
    try {
      playList = await _parser.parse(Uri.base, lines);
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
    InstanceVideo? video = await TableVideo.queryByUrl(task.url);
    if (video != null && File(video.file).existsSync()) return;
    await downloadManager.addTask(task);
  }

  Future<Uint8List?> downloadTask(DownloadTask task) async {
    final md5 = task.uri.generateMd5;
    Uint8List? memoryCache = await VideoMemoryCache.get(md5);
    if (memoryCache != null) {
      logD('从内存中获取数据: ${memoryCache.lengthInBytes.toMemorySize}');
      logD('当前内存占用: ${(await VideoMemoryCache.size()).toMemorySize}');
      return memoryCache;
    }
    InstanceVideo? video = await TableVideo.queryByUrl(task.url);
    if (video != null && File(video.file).existsSync()) {
      logD('从数据库中获取数据');
      File file = File(video.file);
      Uint8List fileCache = await file.readAsBytes();
      await VideoMemoryCache.put(md5, fileCache);
      return fileCache;
    } else {
      logD('从网络中获取数据，正在下载中');
      Uint8List? netData;
      await downloadManager.executeTask(task);
      await for (DownloadTask downloadTask in downloadManager.stream) {
        if (downloadTask.status == DownloadStatus.COMPLETED &&
            downloadTask.id == task.id) {
          netData = Uint8List.fromList(downloadTask.data);
          String mimeType = task.url.endsWith('m3u8')
              ? 'application/vnd.apple.mpegurl'
              : 'video/*';
          TableVideo.insert(
            "",
            task.url,
            downloadTask.saveFile,
            mimeType,
            netData.lengthInBytes,
          );
          await VideoMemoryCache.put(md5, netData);
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
