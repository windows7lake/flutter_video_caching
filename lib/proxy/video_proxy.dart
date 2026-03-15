import 'dart:io';

import 'package:flutter_hls_parser/flutter_hls_parser.dart';

import '../download/download_manager.dart';
import '../ext/file_ext.dart';
import '../global/config.dart';
import '../http/http_client_builder.dart';
import '../http/http_client_default.dart';
import '../match/url_matcher.dart';
import '../match/url_matcher_default.dart';
import 'local_proxy_server.dart';

/// Manages the initialization and configuration of the local video proxy server,
/// HLS playlist parser, download manager, and URL matcher for video streaming and caching.
class VideoProxy {
  /// Whether [init] has been called.
  static bool _initialized = false;

  /// Stored concurrency setting for recreating the download manager on restart.
  static int _maxConcurrentDownloads = 4;

  /// The local HTTP proxy server instance.
  static late LocalProxyServer _localProxyServer;

  /// HLS playlist parser instance for parsing HLS playlists.
  static late HlsPlaylistParser hlsPlaylistParser;

  /// Download manager instance for handling video segment downloads.
  static late DownloadManager downloadManager;

  /// URL matcher implementation for filtering and matching video URLs.
  static late UrlMatcher urlMatcherImpl;

  /// HTTP client builder for creating HTTP clients.
  static late HttpClientBuilder httpClientBuilderImpl;

  /// Initializes the video proxy server and related components.
  ///
  /// [ip]: Optional IP address for the proxy server to bind.<br>
  /// [port]: Optional port number for the proxy server to listen on.<br>
  /// [maxMemoryCacheSize]: Maximum memory cache size in MB (default: 100).<br>
  /// [maxStorageCacheSize]: Maximum storage cache size in MB (default: 1024).<br>
  /// [cacheDir]: Custom cache directory path (default: '').<br>
  /// [logPrint]: Enables or disables logging output (default: false).<br>
  /// [segmentSize]: Size of each video segment in MB (default: 2).<br>
  /// [maxConcurrentDownloads]: Maximum number of concurrent downloads (default: 8).<br>
  /// [urlMatcher]: Optional custom URL matcher for video URL filtering.<br>
  /// [httpClientBuilder]: Optional custom HTTP client builder for creating HTTP clients.<br>
  static Future<void> init({
    String? ip,
    int? port,
    int maxMemoryCacheSize = 100,
    int maxStorageCacheSize = 1024,
    String cacheDir = '',
    bool logPrint = false,
    int segmentSize = 2,
    int maxConcurrentDownloads = 4,
    UrlMatcher? urlMatcher,
    HttpClientBuilder? httpClientBuilder,
  }) async {
    // Set global configuration values for cache sizes and segment size.
    Config.memoryCacheSize = maxMemoryCacheSize * Config.mbSize;
    Config.storageCacheSize = maxStorageCacheSize * Config.mbSize;
    Config.segmentSize = segmentSize * Config.mbSize;

    // Set the cache root path for file operations.
    FileExt.cacheRootPath = cacheDir;

    // Enable or disable logging.
    Config.logPrint = logPrint;

    // Initialize and start the local proxy server.
    _localProxyServer = LocalProxyServer(ip: ip, port: port);
    await _localProxyServer.start();

    // Create the HLS playlist parser instance.
    hlsPlaylistParser = HlsPlaylistParser.create();

    // Set the HTTP client builder
    httpClientBuilderImpl = httpClientBuilder ?? HttpClientDefault();

    // Initialize the download manager with the specified concurrency.
    _maxConcurrentDownloads = maxConcurrentDownloads;
    downloadManager = DownloadManager(maxConcurrentDownloads);

    // Set the URL matcher implementation (custom or default).
    urlMatcherImpl = urlMatcher ?? UrlMatcherDefault();

    _initialized = true;
  }

  /// Restarts the local proxy server and recreates the download manager.
  ///
  /// When the app returns from background, the OS may have killed TCP
  /// connections between the download manager (Dio) and the CDN. Simply
  /// restarting the server socket is not enough — the download manager's
  /// in-flight tasks and HTTP client hold stale connection state that can
  /// cause requests to hang. This method disposes the old download manager
  /// and creates a fresh one so that all subsequent requests use new
  /// connections.
  ///
  /// Throws [StateError] if [init] has not been called yet.
  static Future<void> restart() async {
    if (!_initialized) {
      throw StateError('VideoProxy.init() must be called before restart()');
    }
    // Dispose stale download state (dead TCP connections, in-flight tasks)
    // and recreate with a fresh Dio client.
    downloadManager.dispose();
    downloadManager = DownloadManager(_maxConcurrentDownloads);
    await _localProxyServer.restart();
  }

  /// Checks whether the proxy server is currently reachable.
  ///
  /// Returns `true` if a TCP connection to the proxy succeeds, `false`
  /// otherwise. This can be used to decide whether [restart] is needed
  /// (e.g., after returning from background).
  static Future<bool> isRunning() async {
    if (!_initialized) return false;
    try {
      final socket = await Socket.connect(
        Config.ip,
        Config.port,
        timeout: Duration(seconds: 1),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
