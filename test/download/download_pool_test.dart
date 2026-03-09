import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_caching/download/download_pool.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationCachePath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('DownloadIsolatePool', () {
    late DownloadPool pool;

    setUp(() {
      PathProviderPlatform.instance = FakePathProviderPlatform();
      VideoProxy.urlMatcherImpl = UrlMatcherDefault();
      pool = DownloadPool(poolSize: 1);
      DownloadTask.resetId();
    });

    tearDown(() async {
      pool.dispose();
    });

    test('addTask adds task to pool', () async {
      final task = DownloadTask(uri: Uri.parse('https://a.com/1.mp4'));
      await pool.addTask(task);
      expect(pool.taskList.length, 1);
      expect(pool.taskList.first.uri, task.uri);
    });

    test('findTaskById returns correct task', () async {
      final task = DownloadTask(uri: Uri.parse('https://a.com/2.mp4'));
      await pool.addTask(task);
      final found = pool.findTaskById(task.id);
      expect(found, isNotNull);
      expect(found!.uri, task.uri);
    });

    test('executeTask replaces lower priority', () async {
      final t1 =
          DownloadTask(uri: Uri.parse('https://a.com/3.mp4'), priority: 1);
      final t2 =
          DownloadTask(uri: Uri.parse('https://a.com/3.mp4'), priority: 5);
      await pool.executeTask(t1);
      await pool.executeTask(t2);
      expect(pool.taskList.length, 1);
      expect(pool.taskList.first.priority, 5);
    });

    test('notifyIsolate can pause and resume', () async {
      final task = DownloadTask(uri: Uri.parse('https://a.com/5.mp4'));
      await pool.executeTask(task);
      await Future.delayed(const Duration(milliseconds: 1000));
      final findTask = pool.findTaskById(task.id);
      expect(findTask, isNotNull);
      pool.updateTaskById(task.id, DownloadStatus.PAUSED);
      await Future.delayed(const Duration(milliseconds: 500));
      expect(findTask!.status, DownloadStatus.PAUSED);
      pool.updateTaskById(task.id, DownloadStatus.DOWNLOADING);
      await Future.delayed(const Duration(milliseconds: 500));
      expect(findTask.status, DownloadStatus.DOWNLOADING);
    });

    test('dispose clears all', () async {
      final task = DownloadTask(uri: Uri.parse('https://a.com/6.mp4'));
      await pool.executeTask(task);
      await Future.delayed(const Duration(milliseconds: 1000));
      pool.dispose();
      expect(pool.taskList, isEmpty);
    });
  });
}
