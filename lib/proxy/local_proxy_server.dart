import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../ext/log_ext.dart';
import '../ext/socket_ext.dart';
import '../ext/string_ext.dart';
import '../global/config.dart';
import '../parser/video_caching.dart';

/// A local HTTP proxy server implementation.
/// Listens on a specified IP and port, accepts incoming socket connections,
/// parses HTTP requests, and delegates video caching logic.
class LocalProxyServer {
  /// Constructor for LocalProxyServer.
  /// Optionally accepts an IP and port to bind the server.
  LocalProxyServer({this.ip, this.port}) {
    // Set global config values if provided.
    Config.ip = ip ?? Config.ip;
    Config.port = port ?? Config.port;
  }

  /// Proxy Server IP address.
  final String? ip;

  /// Proxy Server port number.
  final int? port;

  /// The underlying server socket instance.
  ServerSocket? server;

  /// Health check timer reference for proper cleanup.
  Timer? _healthCheckTimer;

  /// Starts the proxy server.
  /// Binds to the configured IP and port, and listens for incoming connections.
  /// If the port is already in use, it will try the next port.
  Future<void> start() async {
    try {
      final InternetAddress internetAddress = InternetAddress(Config.ip);
      server = await ServerSocket.bind(internetAddress, Config.port);
      logD('Proxy server started ${server?.address.address}:${server?.port}');
      if (server == null) {
        retry();
      } else {
        startHealthCheck();
        server?.listen(_handleConnection);
      }
    } on SocketException catch (e) {
      logW('Proxy server Socket close: $e');
      // If the port is occupied (error code 98), increment port and retry.
      if (e.osError?.errorCode == 98) {
        Config.port = Config.port + 1;
        start();
      }
    }
  }

  void startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      try {
        final socket = await Socket.connect(
          Config.ip,
          Config.port,
          timeout: Duration(seconds: 1),
        );
        socket.destroy();
        logD('Proxy server health check pass...');
      } catch (e) {
        print('Server seems down: $e');
        retry();
      }
    });
  }

  void retry() {
    logD('Proxy server restarting...');
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    server?.close();
    server = null;
    Future.delayed(Duration(seconds: 1), start);
  }

  /// Restarts the proxy server.
  ///
  /// Closes the existing server and health check timer, then starts a new
  /// server on the same port. This is useful when the app returns to the
  /// foreground after the OS has killed the server socket in the background.
  Future<void> restart() async {
    logD('Proxy server restart requested...');
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    try {
      await server?.close();
    } catch (_) {
      // Server may already be dead (killed by OS in background).
    }
    server = null;
    await start();
  }

  /// Shuts down the proxy server and cancels the health check timer.
  Future<void> close() async {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    await server?.close();
    server = null;
  }

  /// Handles an incoming socket connection.
  /// Reads data from the socket, parses the HTTP request,
  /// extracts method, path, protocol, and headers,
  /// and delegates further processing to VideoCaching.
  Future<void> _handleConnection(Socket socket) async {
    try {
      logV('_handleConnection start');
      StringBuffer buffer = StringBuffer();
      // Read data from the socket stream.
      await for (Uint8List data in socket) {
        buffer.write(String.fromCharCodes(data));

        // Wait until the end of HTTP headers (\r\n\r\n) is detected.
        if (!buffer.toString().contains(httpTerminal)) continue;

        // Extract raw HTTP headers.
        String? rawHeaders = buffer.toString().split(httpTerminal).firstOrNull;
        List<String> lines = rawHeaders?.split('\r\n') ?? <String>[];

        // Parse the request line (e.g., GET /path HTTP/1.1).
        List<String>? requestLine = lines.firstOrNull?.split(' ') ?? <String>[];
        String method = requestLine.isNotEmpty ? requestLine[0] : '';
        String path = requestLine.length > 1 ? requestLine[1] : '/';
        String protocol = requestLine.length > 2 ? requestLine[2] : 'HTTP/1.1';

        // Parse HTTP headers into a map.
        Map<String, String> headers = <String, String>{};
        for (String line in lines.skip(1)) {
          int index = line.indexOf(':');
          if (index > 0) {
            String key = line.substring(0, index).trim().toLowerCase();
            String value = line.substring(index + 1).trim();
            headers[key] = value;
          }
        }

        // If no headers are found, send a 400 Bad Request response.
        if (headers.isEmpty) {
          await send400(socket);
          return;
        }

        // Convert the path to a Uri object.
        Uri originUri = path.toOriginUri();
        logD('Handling Connections ========================================> \n'
            'protocol: $protocol, method: $method, path: $path \n'
            'headers: $headers \n'
            '$originUri');

        // Delegate request handling to VideoCaching.
        await VideoCaching.parse(socket, originUri, headers);
      }
    } catch (e) {
      logW('⚠ ⚠ ⚠ Socket connections close: $e');
    } finally {
      // Ensure the socket is closed after handling.
      await socket.close();
    }
  }

  /// Sends a 400 Bad Request HTTP response to the client.
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
