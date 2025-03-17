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
      home: const MyHomePage(title: 'Download Manager'),
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
  final DownloadManager _manager = DownloadManager(maxConcurrentDownloads: 2);
  final Map<String, StreamController<double>> _controllers = {};

  @override
  void initState() {
    super.initState();
    _addSampleTasks();
  }

  void _addSampleTasks() async {
    final List<String> links = [
      'https://filesamples.com/samples/video/mp4/sample_960x400_ocean_with_audio.mp4',
      'https://filesamples.com/samples/video/mp4/sample_1280x720_surfing_with_audio.mp4',
      'https://filesamples.com/samples/video/mp4/sample_1280x720.mp4',
      'https://filesamples.com/samples/video/mp4/sample_1920x1080.mp4',
      'https://filesamples.com/samples/video/mp4/sample_2560x1440.mp4',
      'https://filesamples.com/samples/video/mp4/sample_3840x2160.mp4',

      // 'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/v6/main.mp4',
      // 'https://mirrors.edge.kernel.org/linuxmint/stable/20.3/linuxmint-20.3-xfce-64bit.iso',
      // 'https://download.blender.org/release/Blender3.4/blender-3.4.1-windows-x64.msi',
      // 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    ];

    final tasks = [
      DownloadTask(url: links[0], priority: 3),
      DownloadTask(url: links[1], priority: 3),
      DownloadTask(url: links[2], priority: 1),
      DownloadTask(url: links[3], priority: 1),
      DownloadTask(url: links[4], priority: 2),
      DownloadTask(url: links[5], priority: 2),
    ];

    for (final task in tasks) {
      await _manager.addTask(task);
    }

    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {});
    });

    await _manager.processTask(onProgressUpdate: (task) {
      if (task.status == DownloadTaskStatus.COMPLETED) {
        _controllers[task.id]?.close();
        _controllers.remove(task.id);
      } else {
        _controllers[task.id]?.add(task.progress);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: _manager.allTasks.map((task) {
              _controllers.putIfAbsent(task.id, () => StreamController<double>());
              return StreamBuilder<double>(
                stream: _controllers[task.id]?.stream,
                builder: (context, snapshot) {
                  final progress = snapshot.data ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Task ${task.id}',
                          style: const TextStyle(fontSize: 20),
                        ),
                        Text(
                          'Status: ${task.status.name}',
                          style: TextStyle(color: _getStatusColor(task.status)),
                        ),
                        LinearProgressIndicator(value: progress),
                        Text(progressText(task)),
                        ElevatedButton(
                          onPressed: () {
                            switch (task.status) {
                              case DownloadTaskStatus.DOWNLOADING:
                                _manager.pauseTaskById(task.id);
                                break;
                              case DownloadTaskStatus.PAUSED:
                                _manager.resumeTaskById(task.id);
                                break;
                              default:
                                _manager.cancelTaskById(task.id);
                            }
                          },
                          child: Text(_getButtonText(task.status)),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String progressText(DownloadTask task) {
    return task.totalBytes == 0
        ? '${(task.progress / 1000 / 1000).toStringAsFixed(2)}MB'
        : '${(task.progress * 100).toStringAsFixed(2)}%';
  }

  Color _getStatusColor(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.DOWNLOADING:
        return Colors.blue;
      case DownloadTaskStatus.PAUSED:
        return Colors.orange;
      case DownloadTaskStatus.COMPLETED:
        return Colors.green;
      case DownloadTaskStatus.CANCELLED:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getButtonText(DownloadTaskStatus status) {
    switch (status) {
      case DownloadTaskStatus.DOWNLOADING:
        return 'Pause';
      case DownloadTaskStatus.PAUSED:
        return 'Resume';
      default:
        return 'Cancel';
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    super.dispose();
  }
}
