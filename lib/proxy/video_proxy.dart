import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:flutter_video_caching/http/http_client_default.dart';

import '../download/download_manager.dart';
import '../global/config.dart';
import '../http/http_client_builder.dart';
import '../match/url_matcher.dart';
import '../match/url_matcher_default.dart';
import 'local_proxy_server.dart';

/// Manages the initialization and configuration of the local video proxy server,
/// HLS playlist parser, download manager, and URL matcher for video streaming and caching.
class VideoProxy {
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
    downloadManager = DownloadManager(maxConcurrentDownloads);

    // Set the URL matcher implementation (custom or default).
    urlMatcherImpl = urlMatcher ?? UrlMatcherDefault();
  }
}
