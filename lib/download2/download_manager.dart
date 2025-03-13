import 'download_task.dart';
import 'thread_pool.dart';

// 下载管理类
class DownloadManager {
  final ThreadPool _threadPool;

  DownloadManager({int? maxDownloads})
      : _threadPool = ThreadPool(maxDownloads: maxDownloads);

  // 添加下载任务
  void addTask(DownloadTask task, Function(String) onCompleted,
      Function(String, double) onProgressUpdate) {
    _threadPool.addTask(task, onCompleted, onProgressUpdate);
  }

  // 获取所有任务
  List<DownloadTask> get tasks => _threadPool.allTasks;

  // 根据任务 ID 暂停任务
  void pauseTaskById(String taskId, Function(String) onCompleted,
      Function(String, int) onProgressUpdate) {
    _threadPool.pauseTaskById(taskId, onCompleted, onProgressUpdate);
  }

  // 根据任务 ID 恢复任务
  void resumeTaskById(String taskId, Function(String) onCompleted,
      Function(String, double) onProgressUpdate) {
    _threadPool.resumeTaskById(taskId, onCompleted, onProgressUpdate);
  }

  // 根据任务 ID 取消任务
  void cancelTaskById(String taskId) {
    _threadPool.cancelTaskById(taskId);
  }
}
