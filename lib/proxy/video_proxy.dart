import 'package:flutter_hls_parser/flutter_hls_parser.dart';

import '../download/download_manager.dart';
import '../global/config.dart';
import 'local_proxy_server.dart';

class VideoProxy {
  static late LocalProxyServer _localProxyServer;
  static late HlsPlaylistParser hlsPlaylistParser;
  static late DownloadManager downloadManager;

  /// Initialize the video proxy server.
  ///
  /// [ip] is the IP address of the proxy server.
  /// [port] is the port number of the proxy server.
  /// [maxMemoryCacheSize] is the maximum size of the memory cache in MB.
  /// [maxStorageCacheSize] is the maximum size of the storage cache in MB.
  /// [logPrint] is a boolean value to enable or disable logging.
  /// [segmentSize] is the size of each segment in MB.
  /// [maxConcurrentDownloads] is the maximum number of concurrent downloads.
  static Future<void> init({
    String? ip,
    int? port,
    int maxMemoryCacheSize = 100,
    int maxStorageCacheSize = 1024,
    bool logPrint = false,
    int segmentSize = 2,
    int maxConcurrentDownloads = 8,
  }) async {
    Config.memoryCacheSize = maxMemoryCacheSize * Config.mbSize;
    Config.storageCacheSize = maxStorageCacheSize * Config.mbSize;
    Config.segmentSize = segmentSize * Config.mbSize;

    Config.logPrint = logPrint;
    _localProxyServer = LocalProxyServer(ip: ip, port: port);
    await _localProxyServer.start();
    hlsPlaylistParser = HlsPlaylistParser.create();
    downloadManager = DownloadManager(maxConcurrentDownloads);
  }
}
