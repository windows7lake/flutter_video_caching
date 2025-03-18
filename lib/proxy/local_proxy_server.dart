import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_video_cache/global/config.dart';
import 'package:flutter_video_cache/sqlite/database.dart';
import 'package:log_wrapper/log/log.dart';
import 'package:pool/pool.dart';

import '../ext/log_ext.dart';
import '../ext/socket_ext.dart';
import '../flutter_video_cache.dart';
import '../memory/memory_cache.dart';
import '../sqlite/db_instance.dart';

/// 本地代理服务器
class LocalProxyServer {
  /// 本地代理服务器
  LocalProxyServer({this.ip, this.port}) {
    Config.ip = ip ?? Config.ip;
    Config.port = port ?? Config.port;
  }

  /// 代理服务器IP
  final String? ip;

  /// 代理服务器端口
  final int? port;

  /// 代理服务
  ServerSocket? server;

  /// 下载管理器
  DownloadManager downloadManager = DownloadManager();

  /// 启动代理服务器
  Future<void> start() async {
    LogWrapper().logFilter = LocalLogFilter();
    final InternetAddress internetAddress = InternetAddress(Config.ip);
    server = await ServerSocket.bind(internetAddress, Config.port);
    final Pool connectionPool = Pool(10, timeout: const Duration(seconds: 30));
    logD('Proxy server started at ${server?.address.address}:${server?.port}');
    server?.listen((Socket socket) {
      connectionPool.withResource(() => _handleConnection(socket));
    });
  }

  /// 关闭代理服务器
  Future<void> close() async {
    await server?.close();
  }

  /// 处理连接
  Future<void> _handleConnection(Socket socket) async {
    try {
      logD('_handleConnection start');
      final StringBuffer buffer = StringBuffer();
      await for (final Uint8List data in socket) {
        buffer.write(String.fromCharCodes(data));
        // 检测头部结束标记（空行 \r\n\r\n）
        if (buffer.toString().contains(httpTerminal)) {
          final String rawHeaders = buffer.toString().split(httpTerminal).first;
          final Map<String, String> headers = _parseHeaders(rawHeaders, socket);
          if (headers.isEmpty) {
            await send400(socket);
            return;
          }
          final String rangeHeader = headers['Range'] ?? '';
          final String url = headers['redirect'] ?? '';
          final Uri originUri = url.toOriginUri();
          logD('传入链接 Origin url：$originUri');
          final Uint8List? data =
              await parseData(socket, originUri, rangeHeader);
          if (data == null) {
            await send404(socket);
            break;
          }
          if (originUri.path.endsWith('m3u8')) {
            await _sendM3u8(socket, data);
          } else {
            await _sendContent(socket, data);
          }
          break;
        }
      }
    } catch (e) {
      await send500(socket);
      logE('⚠ ⚠ ⚠ 传输异常: $e');
    } finally {
      await socket.close(); // 确保连接关闭
      logD('连接关闭\n');
    }
  }

  /// 解析请求头
  Map<String, String> _parseHeaders(String rawHeaders, Socket socket) {
    final List<String> lines = rawHeaders.split('\r\n');
    if (lines.isEmpty) {
      return <String, String>{};
    }

    // 解析请求行（兼容非标准请求）
    final List<String> requestLine = lines.first.split(' ');
    final String method = requestLine[0];
    final String path = requestLine.length > 1 ? requestLine[1] : '/';
    final String protocol =
        requestLine.length > 2 ? requestLine[2] : 'HTTP/1.1';
    logD('protocol: $protocol, method: $method, path: $path');

    // 提取关键头部（如 Range、User-Agent）
    final Map<String, String> headers = <String, String>{};
    for (final String line in lines.skip(1)) {
      final int index = line.indexOf(':');
      if (index > 0) {
        final String key = line.substring(0, index).trim().toLowerCase();
        final String value = line.substring(index + 1).trim();
        headers[key] = value;
      }
    }

    final String redirectUrl = path.replaceAll('/?url=', '');
    headers['redirect'] = redirectUrl;

    return headers;
  }

  /// 解析并返回对应的文件
  Future<Uint8List?> parseData(Socket socket, Uri uri, String range) async {
    final md5 = uri.toString().generateMd5;
    Uint8List? memoryData = await MemoryCache.get(md5);
    if (memoryData != null) {
      logD('从内存中获取数据');
      return memoryData;
    }
    Video? video = await selectVideoFromDB(md5);
    File file;
    if (video != null && File(video.file).existsSync()) {
      logD('从数据库中获取数据');
      file = File(video.file);
    } else {
      logD('从网络中获取数据');
      final String fileName = uri.pathSegments.last;
      final DownloadTask task = await downloadManager.addTask(DownloadTask(
        url: uri.toString(),
        fileName: fileName,
      ));
      await downloadManager.processTask();
      file = File(task.saveFile);
      while (!file.existsSync()) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    if (uri.path.endsWith('m3u8')) {
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
      final Uint8List data = Uint8List.fromList(buffer.toString().codeUnits);
      insertVideoToDB(
        uri.toString(),
        file.path,
        file.lengthSync(),
        'application/vnd.apple.mpegurl',
      );
      return await MemoryCache.put(md5, data);
    } else {
      final int fileSize = await file.length();
      int start = 0, end = fileSize - 1;

      if (range.isNotEmpty) {
        final List<String> parts = range.split('-');
        start = int.parse(parts[0]);
        end = parts[1].isNotEmpty ? int.parse(parts[1]) : fileSize - 1;
      }

      if (start >= fileSize || end >= fileSize) {
        await send416(socket, fileSize);
        return null;
      }

      final RandomAccessFile raf = await file.open();
      raf.setPositionSync(start);
      final Uint8List data = raf.readSync(end - start + 1);
      insertVideoToDB(
        uri.toString(),
        file.path,
        file.lengthSync(),
        'application/vnd.apple.mpegurl',
      );
      return await MemoryCache.put(md5, data);
    }
  }

  /// 发送m3u8文件
  Future<void> _sendM3u8(Socket socket, Uint8List data) async {
    // 构建响应头
    const int statusCode = 200;
    const String statusMessage = 'OK';
    final String headers = <String>[
      'HTTP/1.1 $statusCode $statusMessage',
      'Accept-Ranges: bytes',
      'Content-Type: application/vnd.apple.mpegurl',
    ].join('\r\n');
    await socket.append(headers);

    await socket.append(data);
    await socket.flush();
  }

  /// 发送内容
  Future<void> _sendContent(Socket socket, Uint8List data) async {
    // logD('start: $start, end: $end, fileSize: $fileSize');

    // 构建响应头
    // final int statusCode = range.isEmpty ? 200 : 206;
    // final String statusMessage = range.isEmpty ? 'OK' : 'Partial Content';
    final String headers = <String>[
      // 'HTTP/1.1 $statusCode $statusMessage',
      'HTTP/1.1 200 OK',
      'Accept-Ranges: bytes',
      'Content-Type: video/mp4',
      // 'Content-Length: ${end - start + 1}',
      // 'Content-Range: bytes $start-$end/$fileSize',
    ].join('\r\n');
    await socket.append(headers);

    await socket.append(data);
    await socket.flush();
  }

  /// 发送400
  Future<void> send400(Socket socket) async {
    logD('HTTP/1.1 400 Bad Request');
    final String headers = <String>[
      'HTTP/1.1 400 Bad Request',
      'Content-Type: text/plain',
      'Bad Request'
    ].join(httpTerminal);
    await socket.append(headers);
  }

  /// 发送404
  Future<void> send404(Socket socket) async {
    logD('HTTP/1.1 404 Not Found');
    final String headers = <String>[
      'HTTP/1.1 404 Not Found',
      'Content-Type: text/plain',
      'Video file not found'
    ].join(httpTerminal);
    await socket.append(headers);
  }

  /// 发送416
  Future<void> send416(Socket socket, int fileSize) async {
    logD('HTTP/1.1 416 Range Not Satisfiable');
    final String headers = <String>[
      'HTTP/1.1 416 Range Not Satisfiable',
      'Content-Range: bytes */$fileSize'
    ].join(httpTerminal);
    await socket.append(headers);
  }

  /// 发送500
  Future<void> send500(Socket socket) async {
    logD('HTTP/1.1 500 Internal Error');
    final String headers = <String>[
      'HTTP/1.1 500 Internal Error',
      'Content-Type: text/plain',
      'Internal Error'
    ].join(httpTerminal);
    await socket.append(headers);
  }
}
