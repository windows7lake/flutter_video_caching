import 'package:flutter/material.dart';
import 'package:flutter_video_cache/download/download_isolate_pool.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DownloadPage());
}

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  DownloadPageState createState() => DownloadPageState();
}

class DownloadPageState extends State<DownloadPage> {
  final _downloadPool = DownloadIsolatePool();
  final Map<String, DownloadStatus> _tasks = {};

  Future<void> _startDownload() async {
    final taskId = await _downloadPool.addDownload(
      url: 'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/v6/main.mp4',
    );

    setState(() => _tasks[taskId] = DownloadStatus.inProgress);

    _downloadPool.getProgressStream(taskId).listen((progress) {
      if (progress.progress >= 1.0) {
        setState(() => _tasks[taskId] = DownloadStatus.completed);
      } else if (progress.error != null) {
        setState(() => _tasks[taskId] = DownloadStatus.error);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('并发下载示例')),
        body: Column(
          children: [
            ElevatedButton(
              onPressed: _startDownload,
              child: Text('开始下载'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _tasks.length,
                itemBuilder: (ctx, index) {
                  final taskId = _tasks.keys.elementAt(index);
                  return _buildDownloadItem(taskId);
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadItem(String taskId) {
    return StreamBuilder<DownloadProgress>(
      stream: _downloadPool.getProgressStream(taskId),
      builder: (context, snapshot) {
        final progress = snapshot.data?.progress ?? 0.0;
        return ListTile(
          title: LinearProgressIndicator(value: progress),
          subtitle: Text('进度: ${(progress * 100).toStringAsFixed(1)}%'),
          trailing: _getStatusIcon(_tasks[taskId]),
        );
      },
    );
  }

  Widget _getStatusIcon(DownloadStatus? status) {
    switch (status) {
      case DownloadStatus.completed:
        return Icon(Icons.check_circle, color: Colors.green);
      case DownloadStatus.error:
        return Icon(Icons.error, color: Colors.red);
      default:
        return CircularProgressIndicator();
    }
  }
}

enum DownloadStatus { inProgress, completed, error }
