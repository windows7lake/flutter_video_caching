import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_hls_parser/flutter_hls_parser.dart';

import '../download/download_manager.dart';
import '../download/download_status.dart';
import '../download/download_task.dart';
import '../ext/log_ext.dart';
import '../ext/string_ext.dart';
import '../memory/video_memory_cache.dart';
import '../proxy/video_proxy.dart';
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

  DownloadManager get downloadManager => VideoProxy.downloadManager;

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
    final path = await downloadSync(DownloadTask(url: url, fileName: fileName));
    final File file = File(path);
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
    final HlsMediaPlaylist? playList = await parseMediaPlaylist(url);
    if (playList == null) return <String>[];
    final String prefix = url.substring(0, url.lastIndexOf('/') + 1);
    List<String> segments = <String>[];
    for (final Segment segment in playList.segments) {
      final String? segmentUrl = segment.url;
      if (segmentUrl != null) {
        String segmentPath = segmentUrl;
        if (!segmentUrl.startsWith('http')) {
          segmentPath = '$prefix$segmentUrl';
        }
        segments.add(segmentPath);
      }
    }
    return segments;
  }

  Future<String> downloadSync(DownloadTask task) {
    Completer<String> completer = Completer();
    TableVideo.queryByUrl(task.url).then((video) {
      if (video != null && File(video.file).existsSync()) {
        completer.complete(video.file);
      } else {
        downloadManager.stream.listen((_task) async {
          if (_task.status == DownloadStatus.COMPLETED && _task.id == task.id) {
            File file = File(task.saveFile);
            Uint8List uint8list;
            if (file.existsSync()) {
              await TableVideo.insert(
                "",
                task.url,
                task.saveFile,
                task.url.endsWith("m3u8")
                    ? 'application/vnd.apple.mpegurl'
                    : 'video/mp2t',
                file.lengthSync(),
              );
            }
            if (task.url.endsWith("m3u8")) {
              Uri uri = Uri.parse(task.url);
              final List<String> lines = await file.readAsLines();
              final StringBuffer buffer = StringBuffer();
              String lastLine = '';
              for (final String line in lines) {
                String changeUrl = '';
                if (lastLine.startsWith("#EXTINF") ||
                    lastLine.startsWith("#EXT-X-STREAM-INF")) {
                  changeUrl = '?redirect=${uri.origin}';
                }
                buffer.write('$line$changeUrl\r\n');
                lastLine = line;
              }
              uint8list = Uint8List.fromList(buffer.toString().codeUnits);
            } else {
              uint8list = file.readAsBytesSync();
            }
            await VideoMemoryCache.put(_task.url.generateMd5, uint8list);
            if (!completer.isCompleted) {
              completer.complete(_task.saveFile);
            }
          }
        });
        downloadManager.executeTask(task);
      }
    });
    return completer.future;
  }

  Future<String> addTask(DownloadTask task) async {
    Completer<String> completer = Completer();
    TableVideo.queryByUrl(task.url).then((video) {
      if (video != null && File(video.file).existsSync()) {
        completer.complete(video.file);
      } else {
        downloadManager.addTask(task);
      }
    });
    return completer.future;
  }
}
