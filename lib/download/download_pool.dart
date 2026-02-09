import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:synchronized/synchronized.dart';

import '../cache/lru_cache_singleton.dart';
import '../ext/file_ext.dart';
import '../ext/gesture_ext.dart';
import '../ext/log_ext.dart';
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
  late final Dio _client;

  /// Stream controller for broadcasting download task updates to listeners.
  late final StreamController<DownloadTask> _streamController;

  /// The last time progress was updated.
  DateTime _progressTime = DateTime.now();

  /// Constructs a [DownloadPool] with the specified [poolSize].
  /// Throws an [ArgumentError] if the pool size is less than or equal to zero.
  DownloadPool({int poolSize = MAX_POOL_SIZE}) : _poolSize = poolSize {
    if (_poolSize <= 0) {
      throw ArgumentError('Pool size must be greater than 0');
    }
    _client = Dio()..httpClientAdapter = NativeAdapter();
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
      if (status == DownloadStatus.DOWNLOADING) {
        if (downloadingTasks.length > _poolSize) {
          DownloadTask lowest = downloadingTasks
              .where((e) => e.id != taskId)
              .reduce((a, b) => a.priority < b.priority ? a : b);
          lowest.status = DownloadStatus.PAUSED;
        }
        _download(task);
      } else if (status == DownloadStatus.COMPLETED ||
          status == DownloadStatus.FAILED ||
          status == DownloadStatus.CANCELLED) {
        _taskList.removeWhere((task) => task.id == taskId);
        _notifyTask(task);
      }
    }
  }

  void updateTaskByUrl(String url, DownloadStatus status) {
    final task = findTaskByUrl(url);
    if (task != null) {
      task.status = status;
      if (status == DownloadStatus.DOWNLOADING) {
        if (downloadingTasks.length > _poolSize) {
          DownloadTask lowest = downloadingTasks
              .where((e) => e.url != url)
              .reduce((a, b) => a.priority < b.priority ? a : b);
          lowest.status = DownloadStatus.PAUSED;
        }
        _download(task);
      } else if (status == DownloadStatus.COMPLETED ||
          status == DownloadStatus.FAILED ||
          status == DownloadStatus.CANCELLED) {
        _taskList.removeWhere((task) => task.url == url);
        _notifyTask(task);
      }
    }
  }

  /// Schedules the pool to run tasks, ensuring only one thread runs this logic at a time.
  Future<void> roundTask() async {
    await _lock.synchronized(() async {
      if (_taskList.isEmpty) return;
      _taskList.sort((a, b) => b.priority - a.priority);
      if (_taskList.length > _poolSize) {
        for (var task in _taskList.sublist(_poolSize)) {
          if (task.status == DownloadStatus.DOWNLOADING) {
            task.status = DownloadStatus.PAUSED;
            _notifyTask(task);
          }
        }
      }
      if (downloadingTasks.length < _poolSize) {
        for (int i = 0; i < _taskList.length; i++) {
          DownloadTask task = _taskList[i];
          if (task.status == DownloadStatus.DOWNLOADING) continue;
          if (downloadingTasks.length >= _poolSize) {
            task.status = DownloadStatus.PAUSED;
            _notifyTask(task);
            continue;
          }
          task.status = DownloadStatus.DOWNLOADING;
          _notifyTask(task);
          _download(task);
        }
      }
    });
  }

  Future<void> _download(DownloadTask task) async {
    DateTime startTime = DateTime.now();
    if (task.cancelToken == null) {
      task.cancelToken = CancelToken();
    }
    bool append = task.cachedBytes > 0;
    Map<String, Object> headers = _downloadHeader(task);
    await _client.download(
      task.url,
      task.savePath,
      cancelToken: task.cancelToken,
      fileAccessMode: append ? FileAccessMode.append : FileAccessMode.write,
      deleteOnError: false,
      onReceiveProgress: (received, total) {
        _downloadProgress(task, received, total);
        if (task.status == DownloadStatus.PAUSED ||
            task.status == DownloadStatus.COMPLETED) {
          task.cachedBytes += task.downloadedBytes;
          task.downloadedBytes = task.cachedBytes;
          task.cancelToken?.cancel();
          task.cancelToken = null;
          _updateProgress(task);
        }
      },
      options: Options(headers: headers),
    ).then((response) {
      _downloadResponse(task, startTime);
    }).catchError((error) {
      _downloadError(task, error);
    });
  }

  Map<String, Object> _downloadHeader(DownloadTask task) {
    Map<String, Object> headers = {};
    // Set up HTTP Range header for resuming or partial downloads.
    String range = '';
    if (task.startRange > 0 || task.cachedBytes > 0) {
      range = 'bytes=${task.startRange + task.cachedBytes}-';
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

  void _downloadProgress(DownloadTask task, int received, int total) {
    // Calculate the total file size
    task.downloadedBytes = task.cachedBytes + received;
    task.totalBytes = total == -1 ? 0 : (task.cachedBytes + total);

    // Calculate the interval between the current time and the last update time
    final currentTime = DateTime.now();
    final timeDiff = currentTime.difference(_progressTime).inMilliseconds;

    // If the time interval exceeds the specified minimum update interval,
    // or the download is complete, then update progress
    if (task.status == DownloadStatus.DOWNLOADING &&
        timeDiff >= MIN_PROGRESS_UPDATE_INTERVAL) {
      _updateProgress(task);
      _progressTime = currentTime;
    }
  }

  void _downloadResponse(DownloadTask task, DateTime startTime) {
    File saveFile = File(task.savePath);
    task.progress = 1;
    task.data = saveFile.readAsBytesSync();
    updateTaskById(task.id, DownloadStatus.COMPLETED);
    LruCacheSingleton().memoryPut(task.matchUrl, Uint8List.fromList(task.data));
    LruCacheSingleton().storagePut(task.matchUrl, saveFile);
    int duration = DateTime.now().difference(startTime).inSeconds;
    logV('[DownloadPool] Download done time: $duration s: ${task.toString()}');
    FunctionProxy.debounce(roundTask);
  }

  void _downloadError(DownloadTask task, dynamic error) {
    File saveFile = File(task.savePath);
    // Check if the download was cancelled.
    if (error is DioException && CancelToken.isCancel(error)) {
      logV('[DownloadPool] Download file size: ${saveFile.lengthSync()}');
      logV('[DownloadPool] Download ${task.status.name}: ${task.url}');
    } else {
      // Handle HTTP errors and retry logic.
      if (saveFile.existsSync()) saveFile.deleteSync();
      updateTaskById(task.id, DownloadStatus.FAILED);
      logV('[DownloadPool] Download error: $error');
      if (error is DioException && error.response?.statusCode == 416) {
        task.retryTimes = 0;
      }
      if (task.retryTimes > 0) {
        logV('[DownloadPool] Download retry ${task.retryTimes}: ${task.uri}');
        task.retryTimes--;
        _download(task);
      }
      FunctionProxy.debounce(roundTask);
    }
  }

  void _updateProgress(DownloadTask task) {
    if (task.totalBytes > 0) {
      task.progress = task.downloadedBytes / task.totalBytes;
    }
    _notifyTask(task);
    logV("[DownloadPool] DOWNLOADING ${task.toString()}");
  }

  void _notifyTask(DownloadTask task) {
    if (_streamController.isClosed) return;
    _streamController.sink.add(task);
  }

  void dispose() {
    downloadingTasks.forEach((e) {
      updateTaskById(e.id, DownloadStatus.CANCELLED);
    });
    _taskList.clear();
    _streamController.close();
    _client.close();
    DownloadTask.resetId();
  }
}
