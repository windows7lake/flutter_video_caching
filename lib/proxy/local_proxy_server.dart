import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../ext/log_ext.dart';
import '../ext/socket_ext.dart';
import '../ext/string_ext.dart';
import '../global/config.dart';
import '../parser/video_caching.dart';

class LocalProxyServer {
  LocalProxyServer({this.ip, this.port}) {
    Config.ip = ip ?? Config.ip;
    Config.port = port ?? Config.port;
  }

  /// Proxy Server IP
  final String? ip;

  /// Proxy Server port
  final int? port;

  ServerSocket? server;

  /// Start the proxy server
  Future<void> start() async {
    try {
      final InternetAddress internetAddress = InternetAddress(Config.ip);
      server = await ServerSocket.bind(internetAddress, Config.port);
      logD('Proxy server started ${server?.address.address}:${server?.port}');
      server?.listen(_handleConnection);
    } on SocketException catch (e) {
      // If the port is occupied, try to use the next port
      if (e.osError?.errorCode == 98) {
        Config.port = Config.port + 1;
        start();
      }
    }
  }

  /// Turn off proxy server
  Future<void> close() async {
    await server?.close();
  }

  Future<void> _handleConnection(Socket socket) async {
    try {
      logV('_handleConnection start');
      StringBuffer buffer = StringBuffer();
      await for (Uint8List data in socket) {
        buffer.write(String.fromCharCodes(data));

        // Detect the end of the header (blank line \r\n\r\n)
        if (!buffer.toString().contains(httpTerminal)) continue;

        String? rawHeaders = buffer.toString().split(httpTerminal).firstOrNull;
        List<String> lines = rawHeaders?.split('\r\n') ?? <String>[];

        // Parsing request lines (compatible with non-standard requests)
        List<String>? requestLine = lines.firstOrNull?.split(' ') ?? <String>[];
        String method = requestLine.isNotEmpty ? requestLine[0] : '';
        String path = requestLine.length > 1 ? requestLine[1] : '/';
        String protocol = requestLine.length > 2 ? requestLine[2] : 'HTTP/1.1';

        // Extract headers (such as Range, User-Agent)
        Map<String, String> headers = <String, String>{};
        for (String line in lines.skip(1)) {
          int index = line.indexOf(':');
          if (index > 0) {
            String key = line.substring(0, index).trim().toLowerCase();
            String value = line.substring(index + 1).trim();
            headers[key] = value;
          }
        }

        if (headers.isEmpty) {
          await send400(socket);
          return;
        }

        String redirectUrl = path.replaceAll('/?url=', '');
        Uri originUri = redirectUrl.toOriginUri();
        logD('Handling Connections ========================================> \n'
            'protocol: $protocol, method: $method, path: $path \n'
            'headers: $headers \n'
            '$originUri');

        await VideoCaching.parse(socket, originUri, headers);
      }
    } catch (e) {
      logE('⚠ ⚠ ⚠ Connections exception: $e');
    } finally {
      await socket.close(); // 确保连接关闭
    }
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
}
