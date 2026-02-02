import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final DownloadManager _manager = DownloadManager(2);
  final List<String> links = [
    'https://samples.mplayerhq.hu/MPEG-4/fridayafternext_http.mp4',
    'https://samples.mplayerhq.hu/MPEG-4/MPEGSolution_jurassic.mp4',
    'https://samples.mplayerhq.hu/MPEG-4/MPEGSolution_stuart.mp4',
    'https://samples.mplayerhq.hu/MPEG-4/video.mp4',
    'https://samples.mplayerhq.hu/MPEG-4/video2.mp4',
    'https://samples.mplayerhq.hu/MPEG-4/mp3on4/lotr.mp4',
    'https://samples.mplayerhq.hu/MPEG-4/mp3on4/red.mp4',
    'https://samples.mplayerhq.hu/MPEG-4/NeroRecodeSample-MP4/NeroRecodeSample.mp4',
    'https://samples.mplayerhq.hu/3D/00001-2.MTS',
    'https://samples.mplayerhq.hu/3D/00001.MTS',
    'https://samples.mplayerhq.hu/3D/00002.MTS',
    'https://samples.mplayerhq.hu/3D/20110805-112659-ch0.mkv',
    'https://samples.mplayerhq.hu/3D/3d_lg_cinema_3d_world_2-DWEU.m2ts',
    'https://samples.mplayerhq.hu/3D/DSCF1912_parrot.AVI',
    'https://samples.mplayerhq.hu/3D/DSCF1928_fish.AVI',
    'https://samples.mplayerhq.hu/3D/Dracula%20480p.wmv',
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/v6/main.mp4',
    'http://vjs.zencdn.net/v/oceans.mp4',
    'https://mirrors.edge.kernel.org/linuxmint/stable/20.3/linuxmint-20.3-xfce-64bit.iso',
    'https://filesamples.com/samples/video/mp4/sample_960x400_ocean_with_audio.mp4',
    'https://filesamples.com/samples/video/mp4/sample_1280x720_surfing_with_audio.mp4',
    'https://filesamples.com/samples/video/mp4/sample_3840x2160.mp4',
    'https://filesamples.com/samples/video/mp4/sample_2560x1440.mp4',
    'https://filesamples.com/samples/video/mp4/sample_1920x1080.mp4',
    'https://filesamples.com/samples/video/mp4/sample_1280x720.mp4',
    'https://download.blender.org/release/Blender3.4/blender-3.4.1-windows-x64.msi',
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
  ];
  int index = 0;

  @override
  void initState() {
    super.initState();
    _initTasks();
  }

  void _initTasks() async {
    _manager.stream.listen((task) {
      setState(() {});
    });
  }

  // ignore: unused_element
  void _addTaskMore() async {
    for (var i = 0; i < 6; i++) {
      await _manager.addTask(DownloadTask(
        uri: Uri.parse(links[i]),
        priority: i,
      ));
    }
    await _manager.roundTask();
    setState(() {});
  }

  Future _addTask() async {
    await _manager.executeTask(DownloadTask(
      uri: Uri.parse(links[index]),
      priority: index,
    ));
    if (++index >= links.length) {
      index = 0;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Download Test")),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: _manager.allTasks.map((task) {
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
                  Text(
                    'Priority: ${task.priority}',
                    style: TextStyle(color: Colors.blue),
                  ),
                  LinearProgressIndicator(value: task.progress),
                  Text(progressText(task)),
                  ElevatedButton(
                    onPressed: () {
                      switch (task.status) {
                        case DownloadStatus.IDLE:
                          _manager.resumeTaskById(task.id);
                          break;
                        case DownloadStatus.DOWNLOADING:
                          _manager.pauseTaskById(task.id);
                          break;
                        case DownloadStatus.PAUSED:
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
          }).toList(),
        ),
      ),
    );
  }

  String progressText(DownloadTask task) {
    return task.totalBytes == 0
        ? '${(task.downloadedBytes / 1000 / 1000).toStringAsFixed(2)}MB'
        : '${(task.progress * 100).toStringAsFixed(2)}%';
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.DOWNLOADING:
        return Colors.blue;
      case DownloadStatus.PAUSED:
        return Colors.orange;
      case DownloadStatus.COMPLETED:
        return Colors.green;
      case DownloadStatus.CANCELLED:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getButtonText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.DOWNLOADING:
        return 'Pause';
      case DownloadStatus.PAUSED:
        return 'Resume';
      case DownloadStatus.IDLE:
        return 'Start';
      default:
        return 'Cancel';
    }
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }
}
