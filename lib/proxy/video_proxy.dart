import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:flutter_video_cache/global/config.dart';

import '../download/download_manager.dart';
import 'local_proxy_server.dart';

class VideoProxy {
  static late LocalProxyServer _localProxyServer;
  static late HlsPlaylistParser hlsPlaylistParser;
  static late DownloadManager downloadManager;

  static Future<void> init({
    String? ip,
    int? port,
    bool logPrint = false,
  }) async {
    Config.logPrint = logPrint;
    _localProxyServer = LocalProxyServer(ip: ip, port: port);
    await _localProxyServer.start();
    hlsPlaylistParser = HlsPlaylistParser.create();
    downloadManager = DownloadManager(maxConcurrentDownloads: 8);
  }
}
