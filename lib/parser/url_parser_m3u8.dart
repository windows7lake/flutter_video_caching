import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../ext/int_ext.dart';
import '../ext/log_ext.dart';
import '../ext/socket_ext.dart';
import '../ext/uri_ext.dart';
import '../flutter_video_cache.dart';
import '../memory/video_memory_cache.dart';
import 'url_parser.dart';

class UrlParserM3U8 implements UrlParser {
  static final List<DownloadTask> _list = <DownloadTask>[];
  static String _latestUrl = '';

  @override
  bool match(Uri uri) {
    return uri.path.endsWith('.m3u8') || uri.path.endsWith('.ts');
  }

  @override
  Future<Uint8List?> cache(DownloadTask task) async {
    Uint8List? dataMemory = await VideoMemoryCache.get(task.matchUrl);
    if (dataMemory != null) {
      logD('从内存中获取: ${dataMemory.lengthInBytes.toMemorySize}, '
          '当前共占用: ${(await VideoMemoryCache.size()).toMemorySize}');
      return dataMemory;
    }
    String cachePath = await DownloadIsolatePool.createVideoCachePath();
    File file = File('$cachePath/${task.saveFile}');
    if (await file.exists()) {
      logD('从文件中获取: ${file.path}');
      Uint8List dataFile = await file.readAsBytes();
      await VideoMemoryCache.put(task.matchUrl, dataFile);
      return dataFile;
    }
    return null;
  }

  @override
  Future<Uint8List?> download(DownloadTask task) async {
    logD('从网络中获取: ${task.url}');
    Uint8List? dataNetwork;
    await VideoProxy.downloadManager.executeTask(task);
    await for (DownloadTask taskStream in VideoProxy.downloadManager.stream) {
      if (taskStream.status == DownloadStatus.COMPLETED &&
          taskStream.url == task.url) {
        dataNetwork = Uint8List.fromList(taskStream.data);
        break;
      }
    }
    return dataNetwork;
  }

  @override
  Future<void> push(DownloadTask task) async {
    Uint8List? dataMemory = await VideoMemoryCache.get(task.matchUrl);
    if (dataMemory != null) return;
    String cachePath = await DownloadIsolatePool.createVideoCachePath();
    File file = File('$cachePath/${task.saveFile}');
    if (await file.exists()) return;
    await VideoProxy.downloadManager.addTask(task);
  }

  @override
  Future<bool> parse(
    Socket socket,
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      DownloadTask task = DownloadTask(uri: uri);
      Uint8List? data = await cache(task);
      if (data == null) {
        concurrentLoop(task);
        task.priority += 10;
        data = await download(task);
      }
      if (data == null) return false;
      if (task.url.endsWith('.m3u8')) {
        List<String> lines = readLineFromUint8List(data);
        String lastLine = '';
        StringBuffer buffer = StringBuffer();
        for (String line in lines) {
          String hlsLine = line.trim();
          if (lastLine.startsWith("#EXTINF") ||
              lastLine.startsWith("#EXT-X-STREAM-INF")) {
            line = line.startsWith('http')
                ? line.toLocalUrl()
                : '$line?origin=${uri.origin}';
          }
          if (lastLine.startsWith("#EXTINF")) {
            if (!hlsLine.startsWith('http')) {
              hlsLine = '${uri.pathPrefix}/' + hlsLine;
            }
            concurrentAdd(DownloadTask(
              uri: Uri.parse(hlsLine),
              hlsKey: uri.generateMd5,
            ));
          }
          buffer.write('$line\r\n');
          lastLine = line;
        }
        data = Uint8List.fromList(buffer.toString().codeUnits);
      }
      String contentType = uri.path.endsWith('.m3u8')
          ? 'application/vnd.apple.mpegurl'
          : 'video/MP2T';
      String responseHeaders = <String>[
        'HTTP/1.1 200 OK',
        'Accept-Ranges: bytes',
        'Content-Type: $contentType',
        'Connection: keep-alive',
      ].join('\r\n');
      await socket.append(responseHeaders);
      await socket.append(data);
      await socket.flush();
      logD('返回请求数据 $uri');
      return true;
    } catch (e) {
      logE('⚠ ⚠ ⚠ UrlParserM3U8 解析异常: $e');
      return false;
    } finally {
      await socket.close(); // 确保连接关闭
      logD('连接关闭\n');
    }
  }

  List<String> readLineFromUint8List(Uint8List uint8List) {
    List<String> lines = [];
    Utf8Codec codec = Utf8Codec();
    int startIndex = 0;
    int lastIndex = 0;
    for (var byte in uint8List) {
      if (byte == 0x0A) {
        Uint8List line = uint8List.sublist(startIndex, lastIndex);
        lines.add(codec.decode(line));
        startIndex = lastIndex + 1;
      }
      lastIndex++;
    }
    return lines;
  }

  Future<void> concurrentLoop(DownloadTask task) async {
    _latestUrl = task.matchUrl;
    Set<String?> hlsKeys = _list.map((e) => e.hlsKey).toSet();
    if (hlsKeys.length > 2) {
      _list.where((e) => e.hlsKey == hlsKeys.first).forEach((e) {
        VideoProxy.downloadManager.allTasks
            .removeWhere((task) => task.matchUrl == e.matchUrl);
      });
      _list.removeWhere((e) => e.hlsKey == hlsKeys.first);
    }
    String? url =
        _list.where((e) => e.matchUrl == task.matchUrl).firstOrNull?.url;
    if (url == null) return;
    DownloadTask newTask = DownloadTask(uri: Uri.parse(url));
    List<DownloadTask> downloading = _list
        .where((e) => e.hlsKey == task.hlsKey)
        .where((e) => e.status == DownloadStatus.DOWNLOADING)
        .toList();
    if (downloading.length >= 4) return;
    Uint8List? cache = await VideoMemoryCache.get(task.matchUrl);
    if (cache != null) {
      concurrentComplete(newTask);
      return;
    }
    String cachePath = await DownloadIsolatePool.createVideoCachePath();
    File file = File('$cachePath/${task.saveFile}');
    if (await file.exists()) {
      concurrentComplete(newTask);
      return;
    }
    bool exitUri = VideoProxy.downloadManager.isMatchUrlExit(newTask.matchUrl);
    if (exitUri) {
      concurrentComplete(newTask, status: DownloadStatus.DOWNLOADING);
      return;
    }
    await VideoProxy.downloadManager.executeTask(newTask);
    StreamSubscription? subscription;
    subscription = VideoProxy.downloadManager.stream.listen((downloadTask) {
      if (downloadTask.status == DownloadStatus.COMPLETED &&
          downloadTask.matchUrl == newTask.matchUrl) {
        logD("异步下载完成： ${newTask.toString()}");
        subscription?.cancel();
        concurrentComplete(newTask);
      }
    });
  }

  void concurrentAdd(DownloadTask task) {
    bool match = _list.where((e) => e.matchUrl == task.matchUrl).isNotEmpty;
    if (!match) _list.add(task);
  }

  void concurrentComplete(DownloadTask task, {DownloadStatus? status}) {
    int index = _list.indexWhere((e) => e.matchUrl == task.matchUrl);
    if (index == -1) return;
    _list[index].status = status ?? DownloadStatus.COMPLETED;
    DownloadTask? latest =
        _list.where((e) => e.matchUrl == _latestUrl).firstOrNull;
    if (latest != null) {
      List<DownloadTask> list =
          _list.where((e) => e.hlsKey == latest.hlsKey).toList();
      int index = list.indexWhere((e) => e.matchUrl == latest.matchUrl);
      if (index != -1 && index + 1 < list.length) {
        concurrentLoop(list[index + 1]);
        return;
      }
    }
    Set<String?> keys = _list.map((e) => e.hlsKey).toSet();
    String? key = keys.elementAt(Random().nextInt(keys.length));
    DownloadTask? idleTask = _list
        .where((e) => e.hlsKey == key)
        .where((e) => e.status == DownloadStatus.IDLE)
        .firstOrNull;
    if (idleTask == null) {
      _list.removeWhere((e) => e.hlsKey == key);
      concurrentComplete(task);
      return;
    }
    concurrentLoop(idleTask);
  }

  @override
  void precache(String url, int cacheSegments, bool downloadNow) async {
    List<String> mediaList = await parseSegment(Uri.parse(url));
    if (mediaList.isEmpty) return;
    final List<String> segments = mediaList.take(cacheSegments).toList();
    for (final String segment in segments) {
      if (downloadNow) {
        download(DownloadTask(uri: Uri.parse(segment)));
      } else {
        push(DownloadTask(uri: Uri.parse(segment)));
      }
    }
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

  /// 解析M3U8分辨率列表
  Future<HlsPlaylist?> parsePlaylist(Uri uri) async {
    Uint8List? uint8List = await download(DownloadTask(uri: uri));
    if (uint8List == null) return null;
    List<String> lines = readLineFromUint8List(uint8List);
    final HlsPlaylist? playList = await parseLines(lines);
    return playList;
  }

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
}
