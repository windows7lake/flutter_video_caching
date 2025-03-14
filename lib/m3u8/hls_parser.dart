import 'dart:io';

import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:log_wrapper/log/log.dart';

import '../flutter_video_cache.dart';

/// M3U8 HLS parser
class HlsParser {
  /// 获取单例对象
  factory HlsParser() => instance;

  /// 私有构造函数
  HlsParser._();

  /// 单例对象
  static final HlsParser instance = HlsParser._();

  final HlsPlaylistParser _parser = HlsPlaylistParser.create();

  /// 解析M3U8文件
  Future<HlsPlaylist?> parseString(List<String> lines) async {
    HlsPlaylist? playList;
    try {
      playList = await _parser.parse(Uri.base, lines);
    } on ParserException catch (e) {
      logE('ParserException: ${e.message}');
    }
    return playList;
  }

  /// 解析M3U8链接
  Future<HlsPlaylist?> parsePlaylist(String url) async {
    final String fileName = url.split('/').last;
    final String savePath = await DownloadManager()
        .addTask(DownloadTask(url: url, fileName: fileName));
    final File file = File(savePath);
    final List<String> lines = await file.readAsLines();
    final HlsPlaylist? playList = await parseString(lines);
    return playList;
  }

  /// 解析M3U8媒体播放列表
  Future<HlsMediaPlaylist?> parseMediaPlaylist(String url) async {
    final String prefix = url.substring(0, url.lastIndexOf('/') + 1);
    final HlsPlaylist? playList = await parsePlaylist(url);
    if (playList is HlsMasterPlaylist) {
      for (final Uri? uri in playList.mediaPlaylistUrls) {
        if (uri == null) {
          continue;
        }
        final String mediaUrl = '$prefix${uri.path}';
        final HlsMediaPlaylist? mediaPlayList =
            await parseMediaPlaylist(mediaUrl);
        if (mediaPlayList != null) {
          return mediaPlayList;
        }
      }
    } else if (playList is HlsMediaPlaylist) {
      return playList;
    }
    return null;
  }

  /// 解析M3U8 ts文件
  Future<List<String>> parseSegment(String url) async {
    final String prefix = url.substring(0, url.lastIndexOf('/') + 1);
    final HlsMediaPlaylist? playList = await parseMediaPlaylist(url);
    if (playList == null) {
      return <String>[];
    }
    final List<String> downloaded = <String>[];
    for (final Segment segment in playList.segments) {
      final String? segmentUrl = segment.url;
      if (segmentUrl != null) {
        String segmentPath = segmentUrl;
        if (!segmentUrl.startsWith('http')) {
          segmentPath = '$prefix$segmentUrl';
        }
        final String segmentName = segmentUrl.split('/').last;
        final String savePath = await DownloadManager()
            .addTask(DownloadTask(url: segmentPath, fileName: segmentName));
        downloaded.add(savePath);
      }
    }
    logD('下载完成：${downloaded.length}');
    return downloaded;
  }
}
