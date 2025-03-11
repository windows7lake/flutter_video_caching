import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:log_wrapper/log/log.dart';
import 'package:path_provider/path_provider.dart';

import '../ext/function_ext.dart';
import '../ext/url_ext.dart';
import '../memory/memory_cache.dart';
import '../sqlite/database.dart';
import '../sqlite/db_instance.dart';

/// 文件下载器
class FileDownloader {
  /// 获取单例对象
  factory FileDownloader() => instance;

  /// 私有构造函数
  FileDownloader._();

  /// 单例对象
  static final FileDownloader instance = FileDownloader._();

  final StreamController<double> _progressController =
      StreamController<double>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  /// 获取下载进度流
  Stream<double> get progressStream => _progressController.stream;

  /// 获取状态流
  Stream<String> get statusStream => _statusController.stream;

  bool _isPaused = false;

  /// 是否暂停
  bool get isPaused => _isPaused;

  /// 开始下载
  Future<String> start(String url, String fileName) async {
    try {
      Video? video = await selectVideoFromDB(url.generateMd5);
      if (video != null) {
        logD('文件已存在，从数据库中获取');
        return video.file;
      }

      // 获取存储路径（建议使用应用缓存目录）
      final String directory = await createDirectory(fileName);
      final String savePath = '$directory/$fileName';

      int downloadedBytes = 0;
      final File file = File(savePath);
      if (file.existsSync()) {
        final int? fileSize = await getFileSize(url);
        if (fileSize == null) {
          logD('无法获取文件大小，无法断点续传');
        }
        final int downloaded = await file.length();
        if (downloaded < fileSize!) {
          downloadedBytes = downloaded;
          logD('文件已存在，继续下载: $downloaded');
        } else {
          logD('文件已存在，无需下载');
          await insertVideoToDB(url, savePath);
          return savePath;
        }
      }

      final http.Request request = http.Request('GET', Uri.parse(url));
      request.headers['Range'] = 'bytes=$downloadedBytes-';

      final http.StreamedResponse response = await http.Client().send(request);
      final int totalBytes = downloadedBytes + (response.contentLength ?? 0);

      final IOSink sink = file.openWrite(mode: FileMode.writeOnlyAppend);

      await response.stream.listen(
        (List<int> chunk) async {
          if (_isPaused) {
            await sink.close();
            return;
          }
          sink.add(chunk);
          MemoryCache.append(url.generateMd5, Uint8List.fromList(chunk));
          downloadedBytes += chunk.length;
          FunctionProxy.throttle(() async {
            _progressController.add(downloadedBytes / totalBytes);
          }, key: 'Progress', timeout: 200);
        },
        onDone: () async {
          await sink.close();
          _statusController.add('completed');
          await insertVideoToDB(url, savePath);
        },
        onError: (e) async {
          await sink.close();
          _statusController.add('error: $e');
        },
        cancelOnError: true,
      ).asFuture<dynamic>();

      return savePath;
    } on Exception catch (e) {
      logE('下载失败: $e');
    }
    return '';
  }

  /// 暂停下载
  void pause() {
    _isPaused = true;
    _statusController.add('paused');
  }

  /// 恢复下载
  void resume(String url, String fileName) {
    _isPaused = false;
    _statusController.add('resumed');
    start(url, fileName);
  }

  /// 停止下载
  void dispose() {
    _progressController.close();
    _statusController.close();
  }

  /// 创建目录
  Future<String> createDirectory(String fileName) async {
    // 获取存储路径（建议使用应用缓存目录）
    final String directory = fileName.substring(0, fileName.lastIndexOf('.'));
    final Directory dir = await getTemporaryDirectory();
    // 如果已经存在同样前缀的目录，则直接返回
    for (final FileSystemEntity entity in dir.listSync()) {
      if (entity is Directory) {
        if (fileName.startsWith(directory)) {
          return entity.path;
        }
      }
    }
    // 创建和文件同名的目录
    final String directoryPath = '${dir.path}/$directory';
    if (!Directory(directoryPath).existsSync()) {
      await Directory(directoryPath).create();
    }
    return directoryPath;
  }

  /// 获取文件大小
  Future<int?> getFileSize(String url) async {
    try {
      final http.Request request = http.Request('HEAD', Uri.parse(url));
      request.headers['Accept-Encoding'] = 'identity'; // 禁用压缩干扰
      final http.StreamedResponse response = await http.Client().send(request);

      // 优先从 Content-Length 头获取
      final String? contentLength = response.headers['content-length'];
      // 处理分块传输编码场景
      final String? transferEncoding = response.headers['transfer-encoding'];

      return contentLength != null
          ? int.parse(contentLength)
          : (transferEncoding == 'chunked' ? -1 : null);
    } catch (e) {
      logE('HEAD请求失败: $e');
      return null;
    }
  }
}
