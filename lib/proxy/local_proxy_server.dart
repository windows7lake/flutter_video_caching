import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../download/download_task.dart';
import '../ext/int_ext.dart';
import '../ext/log_ext.dart';
import '../ext/socket_ext.dart';
import '../ext/string_ext.dart';
import '../ext/uri_ext.dart';
import '../global/config.dart';
import '../m3u8/hls_map.dart';
import '../m3u8/hls_parser.dart';
import '../memory/video_memory_cache.dart';
import '../mp4/mp4_parser.dart';

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

  /// 启动代理服务器
  Future<void> start() async {
    try {
      final InternetAddress internetAddress = InternetAddress(Config.ip);
      server = await ServerSocket.bind(internetAddress, Config.port);
      logD('Proxy server started ${server?.address.address}:${server?.port}');
      server?.listen(_handleConnection);
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 98) {
        Config.port = Config.port + 1;
        start();
      }
    }
  }

  /// 关闭代理服务器
  Future<void> close() async {
    await server?.close();
  }

  /// 处理连接
  Future<void> _handleConnection(Socket socket) async {
    try {
      logV('_handleConnection start');
      final StringBuffer buffer = StringBuffer();
      await for (final Uint8List data in socket) {
        buffer.write(String.fromCharCodes(data));
        // 检测头部结束标记（空行 \r\n\r\n）
        if (buffer.toString().contains(httpTerminal)) {
          String? rawHeaders =
              buffer.toString().split(httpTerminal).firstOrNull;
          Map<String, String> headers = _parseHeaders(rawHeaders);
          logD("传入请求头： $headers");
          if (headers.isEmpty) {
            await send400(socket);
            return;
          }
          final String rangeHeader = headers['range'] ?? '';
          final String url = headers['redirect'] ?? '';
          final Uri originUri = url.toOriginUri();
          logD('传入链接 Origin url：$originUri');

          if (originUri.path.endsWith('mp4')) {
            RegExp exp = RegExp(r'bytes=(\d+)-(\d*)');
            RegExpMatch? rangeMatch = exp.firstMatch(rangeHeader);
            int rangeStart = int.parse(rangeMatch?.group(1) ?? '0');

            // 处理完整请求
            final responseHeaders = [
              rangeStart > 0
                  ? 'HTTP/1.1 206 Partial Content'
                  : 'HTTP/1.1 200 OK',
              'Content-Type: video/mp4',
              'Accept-Ranges: bytes',
              'Connection: keep-alive',
            ].join('\r\n');
            await socket.append(responseHeaders);

            int startRange = rangeStart - (rangeStart % Config.segmentSize);
            int endRange = startRange + Config.segmentSize - 1;
            DownloadTask task = DownloadTask(
              uri: originUri,
              startRange: startRange,
              endRange: endRange,
            );
            logD('传入Range => start: $startRange, end: $endRange');

            logD('当前内存占用: ${(await VideoMemoryCache.size()).toMemorySize}');
            MP4Parser mp4parser = MP4Parser();
            Uint8List? result = await mp4parser.cacheTask(task);
            if (result != null) {
              if (rangeStart % Config.segmentSize != 0) {
                result = result.sublist(rangeStart % Config.segmentSize);
              }
              socket.add(result);
              int count = 2;
              while (count > 0) {
                count--;
                task.startRange += Config.segmentSize;
                task.endRange = task.startRange + Config.segmentSize - 1;
                result = await mp4parser.cacheTask(task);
                if (result == null) break;
                socket.add(result);
              }
            } else {
              result = await mp4parser.downloadTask(task);
              if (rangeStart % Config.segmentSize != 0) {
                result = result?.sublist(rangeStart % Config.segmentSize);
              }
              if (result != null) socket.add(result);
            }
            await socket.flush();

            logD('返回请求数据 Origin url：$originUri range: $startRange-$endRange');
            break;
          } else {
            final Uint8List? data = await _parseData(originUri, rangeHeader);
            if (data == null) {
              // await send404(socket);
              break;
            }
            if (originUri.path.endsWith('m3u8')) {
              await _sendM3u8(socket, data);
            } else {
              await _sendContent(socket, data);
            }
            logD('返回请求数据 Origin url：$originUri');
            break;
          }
        }
      }
    } catch (e) {
      logE('⚠ ⚠ ⚠ 传输异常: $e');
    } finally {
      await socket.close(); // 确保连接关闭
      logD('连接关闭\n');
    }
  }

  /// 解析请求头
  Map<String, String> _parseHeaders(String? rawHeaders) {
    if (rawHeaders == null || rawHeaders.isEmpty) {
      return <String, String>{};
    }
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
  Future<Uint8List?> _parseData(Uri uri, String range) async {
    HlsParser hlsParser = HlsParser();
    Uint8List? data = await hlsParser.downloadTask(DownloadTask(uri: uri));
    HlsMap.concurrent(uri.toString());
    if (data != null && uri.toString().endsWith('.m3u8')) {
      List<String> lines = hlsParser.readLineFromUint8List(data);
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
          HlsMap.add(HlsSegment(
            key: uri.generateMd5,
            url: hlsLine.startsWith('http')
                ? hlsLine
                : '${uri.pathPrefix}/$hlsLine',
          ));
        }
        buffer.write('$line\r\n');
        lastLine = line;
      }
      data = Uint8List.fromList(buffer.toString().codeUnits);
    }
    return data;
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
      'Connection: keep-alive',
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
      'Content-Type: video/MP2T',
      'Connection: keep-alive',
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

  /// 发送416
  Future<void> send416(Socket socket, int fileSize) async {
    logD('HTTP/1.1 416 Range Not Satisfiable');
    final String headers = <String>[
      'HTTP/1.1 416 Range Not Satisfiable',
      'Content-Range: bytes */$fileSize'
    ].join(httpTerminal);
    await socket.append(headers);
  }
}
