import 'package:dio/dio.dart';

import '../ext/log_ext.dart';
import '../ext/string_ext.dart';
import '../global/config.dart';
import '../proxy/video_proxy.dart';
import 'download_status.dart';

/// Represents a single download task, including its metadata, status, and progress.
class DownloadTask {
  /// Unique ID for the task, auto-incremented.
  final String id;

  /// The URI of the file to be downloaded.
  final Uri uri;

  /// The priority of the task (default is 1, higher means higher priority).
  int priority;

  /// The progress of the download, from 0.0 (not started) to 1.0 (completed).
  double progress;

  /// The number of bytes cached so far.
  int cachedBytes;

  /// The number of bytes downloaded so far.
  int downloadedBytes;

  /// The total number of bytes to be downloaded.
  int totalBytes;

  /// The current status of the download (e.g., IDLE, DOWNLOADING, PAUSED, COMPLETED, CANCELLED).
  DownloadStatus status;

  /// The start byte range for partial download requests.
  int startRange;

  /// The end byte range for partial download requests (nullable).
  int? endRange;

  /// The headers to be used for the download request (nullable).
  Map<String, Object>? headers;

  /// The HLS key (generated from the URI) for the download, used to generate the cache directory,
  /// so that the segments of the same video can be cached in the same directory.
  String? hlsKey;

  /// The number of retry attempts for the download task.
  int retryTimes;

  /// The CancelToken used to cancel the download request (nullable).
  CancelToken? cancelToken;

  /// The list of data chunks downloaded (as bytes).
  List<int> data = [];

  /// The directory where the file will be cached.
  String cacheDir;

  /// The name of the file to be saved.
  String fileName;

  /// Constructs a new DownloadTask with the given parameters.
  /// [uri] is required. [fileName] is optional; if not provided, uses the URI as the file name.
  DownloadTask({
    required this.uri,
    this.priority = 1,
    String? fileName,
    this.cacheDir = "",
    this.progress = 0.0,
    this.cachedBytes = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.status = DownloadStatus.IDLE,
    this.startRange = 0,
    this.endRange,
    this.headers,
    this.hlsKey,
    this.retryTimes = 0,
    this.cancelToken,
  })  : id = _autoId.toString(),
        this.fileName = fileName ?? uri.toString() {
    _autoId++;
  }

  /// Returns the URL string of the download target.
  String get url => uri.toString();

  /// Generates a unique cache key for the download task, considering headers and range.
  String get matchUrl {
    String cacheKey = Config.customCacheId.toLowerCase();
    headers = headers?.map((key, value) => MapEntry(key.toLowerCase(), value));
    Uri safeUri;
    try {
      safeUri = fileName.toSafeUri();
    } catch (e) {
      safeUri = Uri(host: fileName);
    }
    if (headers != null && headers!.containsKey(cacheKey)) {
      safeUri = safeUri.replace(host: headers![cacheKey].toString());
    }
    Map<String, String> queryParameters = {};
    queryParameters.addAll(safeUri.queryParameters);
    if (startRange > 0) {
      queryParameters.putIfAbsent("startRange", () => startRange.toString());
    }
    if (endRange != null) {
      if (!queryParameters.containsKey("startRange")) {
        queryParameters.putIfAbsent("startRange", () => '0');
      }
      queryParameters.putIfAbsent("endRange", () => endRange.toString());
    }
    safeUri = safeUri.replace(queryParameters: queryParameters);
    Uri cacheUri = VideoProxy.urlMatcherImpl.matchCacheKey(safeUri);
    return cacheUri.toString().generateMd5;
  }

  /// Returns the file name to be used for saving, including the extension.
  String get saveFileName {
    String? extensionName = fileName.split(".").lastOrNull;
    try {
      Uri uri = fileName.toSafeUri();
      if (uri.pathSegments.isNotEmpty) {
        extensionName = uri.pathSegments.last.split(".").lastOrNull;
      }
    } catch (e) {
      logD("Uri parse error: $fileName");
    }
    return '${matchUrl}.$extensionName';
  }

  /// Returns the file path to be used for saving.
  String get savePath => "$cacheDir/$saveFileName";

  /// Static auto-incremented ID for generating unique task IDs.
  static int _autoId = 1;

  /// Resets the static auto-incremented ID to 1.
  static void resetId() {
    _autoId = 1;
  }

  /// Resets the download progress and range information for the task.
  void reset() {
    downloadedBytes = 0;
    totalBytes = 0;
    progress = 0.0;
    startRange = 0;
    endRange = null;
    data.clear();
  }

  /// Returns a string representation of the download task, including all key properties.
  @override
  String toString() {
    return 'Task [ '
        'ID: $id, '
        'URL: $uri, '
        'Status: $status, '
        'StartRange: $startRange, '
        'EndRange: $endRange, '
        'Priority: $priority, '
        'Progress: $progress, '
        'DownloadedBytes: $downloadedBytes, '
        'cachedBytes: $cachedBytes, '
        'TotalBytes: $totalBytes, '
        'CacheDir: $cacheDir, '
        'fileName: $fileName, '
        'HLSKey: $hlsKey, '
        ' ]';
  }
}
