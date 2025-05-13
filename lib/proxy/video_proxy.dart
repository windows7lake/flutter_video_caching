import 'package:flutter_hls_parser/flutter_hls_parser.dart';

import '../download/download_manager.dart';
import '../global/config.dart';
import 'local_proxy_server.dart';

class VideoProxy {
  static late LocalProxyServer _localProxyServer;
  static late HlsPlaylistParser hlsPlaylistParser;
  static late DownloadManager downloadManager;

  static Future<void> init({
    String? ip,
    int? port,
    int maxMemoryCacheSize = 100,
    int maxStorageCacheSize = 1024,
    bool logPrint = false,
  }) async {
    Config.memoryCacheSize = maxMemoryCacheSize * Config.mbSize;
    Config.storageCacheSize = maxStorageCacheSize * Config.mbSize;

    Config.logPrint = logPrint;
    _localProxyServer = LocalProxyServer(ip: ip, port: port);
    await _localProxyServer.start();
    hlsPlaylistParser = HlsPlaylistParser.create();
    downloadManager = DownloadManager(maxConcurrentDownloads: 8);
  }
}
