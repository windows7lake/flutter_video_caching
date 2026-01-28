import 'dart:async';
import 'dart:io';

import 'package:synchronized/synchronized.dart';

import '../ext/file_ext.dart';
import '../ext/gesture_ext.dart';
import '../ext/log_ext.dart';
import '../proxy/video_proxy.dart';
import 'download_status.dart';
import 'download_task.dart';

/// The maximum number of isolates allowed in the pool.
const int MAX_POOL_SIZE = 1;

/// The maximum task priority value.
const int MAX_TASK_PRIORITY = 9999;

/// The minimum interval (in milliseconds) for updating download progress.
const int MIN_PROGRESS_UPDATE_INTERVAL = 500;

class DownloadPool {
  /// Lock for synchronizing access to the pool to ensure thread safety.
  final Lock _lock = Lock();

  /// The maximum number of isolates allowed in the pool.
  final int _poolSize;

  /// List of all download tasks managed by the pool.
  final List<DownloadTask> _taskList = [];

  /// HTTP client used for downloading files.
  late final HttpClient _client;

  /// Stream controller for broadcasting download task updates to listeners.
  late final StreamController<DownloadTask> _streamController;

  /// Number of retry attempts left for the current download.
  int _retryTimes = 0;

  /// The last time progress was updated.
  DateTime _progressTime = DateTime.now();

  /// Constructs a [DownloadPool] with the specified [poolSize].
  /// Throws an [ArgumentError] if the pool size is less than or equal to zero.
  DownloadPool({int poolSize = MAX_POOL_SIZE}) : _poolSize = poolSize {
    if (_poolSize <= 0) {
      throw ArgumentError('Pool size must be greater than 0');
    }
    _client = VideoProxy.httpClientBuilderImpl.create();
    _streamController = StreamController.broadcast();
  }

  /// Returns the stream controller for task updates.
  StreamController<DownloadTask> get streamController => _streamController;

  /// Returns the list of all tasks in the pool.
  List<DownloadTask> get taskList => _taskList;

  /// Returns the list of tasks that are not currently downloading.
  List<DownloadTask> get prepareTasks => _taskList
      .where((task) => task.status != DownloadStatus.DOWNLOADING)
      .toList();

  /// Returns the list of tasks that are currently downloading.
  List<DownloadTask> get downloadingTasks => _taskList
      .where((task) => task.status == DownloadStatus.DOWNLOADING)
      .toList();

  /// Finds a task in the pool by its [taskId].
  DownloadTask? findTaskById(String taskId) =>
      _taskList.where((task) => task.id == taskId).firstOrNull;

  /// Finds a task in the pool by its [url].
  DownloadTask? findTaskByUrl(String url) =>
      _taskList.where((task) => task.url == url).firstOrNull;

  /// Adds a new [task] to the pool, creating a cache directory if needed.
  Future<DownloadTask> addTask(DownloadTask task) async {
    logV('[DownloadIsolatePool] addTask: ${task.toString()}');
    if (task.cacheDir.isEmpty) {
      String cachePath = await FileExt.createCachePath();
      task.cacheDir = cachePath;
    }
    task.saveFile = task.saveFile;
    _taskList.add(task);
    return task;
  }

  /// Executes a [task], replacing any existing lower-priority task with the same cache key.
  /// Schedules the isolate pool for task execution.
  Future<DownloadTask> executeTask(DownloadTask task) async {
    DownloadTask? existTask =
        _taskList.where((e) => e.matchUrl == task.matchUrl).firstOrNull;
    if (existTask != null && existTask.priority < task.priority) {
      _taskList.removeWhere((e) => e.matchUrl == task.matchUrl);
      await addTask(task);
    } else if (existTask == null) {
      await addTask(task);
    }
    FunctionProxy.debounce(roundTask);
    return task;
  }

  void updateTaskById(String taskId, DownloadStatus status) {
    final task = findTaskById(taskId);
    if (task != null) {
      task.status = status;
      FunctionProxy.debounce(roundTask);
    }
  }

  void updateTaskByUrl(String url, DownloadStatus status) {
    final task = findTaskByUrl(url);
    if (task != null) {
      task.status = status;
      FunctionProxy.debounce(roundTask);
    }
  }

  /// Schedules the pool to run tasks, ensuring only one thread runs this logic at a time.
  Future<void> roundTask() async {
    await _lock.synchronized(() async {
      if (_taskList.isEmpty) return;
      _taskList.sort((a, b) => b.priority - a.priority);
      while (downloadingTasks.length < _poolSize) {
        if (_taskList.isNotEmpty) {
          DownloadTask task = prepareTasks.first;
          task.status = DownloadStatus.DOWNLOADING;
          _notifyTask(task);
          _download(task);
        }
      }
    });
  }

  Future<void> _download(DownloadTask task) async {
    try {
      final request = await _client.getUrl(task.uri);
      Map<String, Object> headers = _downloadHeader(task);
      headers.forEach((key, value) => request.headers.add(key, value));

      final response = await request.close();
      if (!_downloadResponse(response, task)) {
        return;
      }

      final file = File(task.filePath);
      final sink = file.openWrite();
      await for (final chunk in response) {
        if (task.status == DownloadStatus.PAUSED ||
            task.status == DownloadStatus.COMPLETED) {
          (await response.detachSocket()).close();
          _notifyTask(task);
          break;
        }
        task.downloadedBytes += chunk.length;
        sink.add(chunk);
        _downloadProgress(response, task);
      }

      await sink.close();
    } catch (e) {
      logV('[DownloadPool] Download error: $e');
    } finally {
      logV('[DownloadPool] Download close: ${task.url}');
    }
  }

  Map<String, Object> _downloadHeader(DownloadTask task) {
    Map<String, Object> headers = {};
    // Set up HTTP Range header for resuming or partial downloads.
    String range = '';
    if (task.downloadedBytes > 0 || task.startRange > 0) {
      int startRange = task.downloadedBytes + task.startRange;
      range = 'bytes=$startRange-';
    }
    if (task.endRange != null) {
      if (range.isEmpty) range = 'bytes=0-';
      range += '${task.endRange}';
    }
    headers.putIfAbsent('Range', () => range);
    // Add custom headers except 'host' and 'range'.
    if (task.headers != null) {
      task.headers!.forEach((key, value) {
        String keyLower = key.toLowerCase();
        if (keyLower == 'host' || keyLower == 'range') return;
        headers.putIfAbsent(key, () => value);
      });
    }
    return headers;
  }

  bool _downloadResponse(HttpClientResponse response, DownloadTask task) {
    if (response.statusCode >= 200 && response.statusCode < 300) return true;
    // Check if contentLength is valid
    if (response.contentLength == -1) {
      logV('[DownloadPool] failed to get the total file size.');
    }
    // Handle HTTP errors and retry logic.
    final range = 'range: ${task.startRange}-${task.endRange}';
    if (response.statusCode == 416) _retryTimes = 0;
    if (_retryTimes > 0) {
      logV('[DownloadPool] retry $_retryTimes: ${task.uri} $range');
      _retryTimes--;
      _download(task);
      return false;
    }
    logV('[DownloadPool] failed: ${task.uri} $range');
    task.status = DownloadStatus.FAILED;
    _notifyTask(task);
    return false;
  }

  void _downloadProgress(HttpClientResponse response, DownloadTask task) {
    // Calculate the total file size
    final totalBytes = task.downloadedBytes + response.contentLength;
    task.totalBytes = response.contentLength == -1 ? 0 : totalBytes;

    // Calculate the interval between the current time and the last update time
    final currentTime = DateTime.now();
    final timeDiff = currentTime.difference(_progressTime).inMilliseconds;

    // If the time interval exceeds the specified minimum update interval,
    // or the download is complete, then update progress
    if (task.status == DownloadStatus.DOWNLOADING &&
        timeDiff >= MIN_PROGRESS_UPDATE_INTERVAL) {
      if (task.totalBytes > 0) {
        task.progress = task.downloadedBytes / task.totalBytes;
      }
      _progressTime = currentTime;
      _notifyTask(task);
      logV("[DownloadPool] DOWNLOADING ${task.toString()}");
    }
  }

  void _notifyTask(DownloadTask task) {
    _streamController.sink.add(task);
    if (task.status == DownloadStatus.FAILED ||
        task.status == DownloadStatus.PAUSED ||
        task.status == DownloadStatus.COMPLETED) {
      roundTask();
    }
  }
}
