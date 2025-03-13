import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Download Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Download Manager Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final DownloadManager _downloadManager = DownloadManager(maxDownloads: 1);
  final Map<String, StreamController<double>> _progressControllers = {};

  @override
  void initState() {
    super.initState();
    // 添加示例下载任务
    final task1 = DownloadTask(
      url:
          'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/v6/main.mp4',
      priority: 2,
    );
    final task2 = DownloadTask(
      url:
          'https://mirrors.edge.kernel.org/linuxmint/stable/20.3/linuxmint-20.3-xfce-64bit.iso',
      priority: 1,
    );
    final task3 = DownloadTask(
      url:
          'https://download.blender.org/release/Blender3.4/blender-3.4.1-windows-x64.msi',
      priority: 3,
    );

    final onCompleted = (taskId) {
      _progressControllers[taskId]?.close();
      _progressControllers.remove(taskId);
    };
    final onProgressUpdate = (taskId, downloadedBytes) {
      final task = _downloadManager.tasks.firstWhere((t) => t.id == taskId);
      _progressControllers[taskId]?.add(task.progress);
    };

    _downloadManager.addTask(task1, onCompleted, onProgressUpdate);
    _downloadManager.addTask(task2, onCompleted, onProgressUpdate);
    _downloadManager.addTask(task3, onCompleted, onProgressUpdate);

    Future.delayed(const Duration(seconds: 5), () {
      _downloadManager.pauseTaskById(task1.id, onCompleted, onProgressUpdate);
    });

    Future.delayed(const Duration(seconds: 10), () {
      _downloadManager.resumeTaskById(task1.id, onCompleted, onProgressUpdate);
    });

    Future.delayed(const Duration(seconds: 15), () {
      _downloadManager.cancelTaskById(task2.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Download Manager Example',
            ),
            ..._downloadManager.tasks.map((task) {
              _progressControllers.putIfAbsent(
                  task.id, () => StreamController<double>());
              return StreamBuilder<double>(
                stream: _progressControllers[task.id]?.stream,
                builder: (context, snapshot) {
                  final progress = snapshot.data ?? 0.0;
                  return Column(
                    children: [
                      Text(
                        'Task ID: ${task.id}, URL: ${task.url}, Status: ${task.status}, Progress: ${(progress * 100).toStringAsFixed(2)}%',
                      ),
                      LinearProgressIndicator(
                        value: progress,
                      ),
                    ],
                  );
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    super.dispose();
  }
}
