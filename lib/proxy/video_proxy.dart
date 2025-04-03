import '../download/download_manager.dart';
import 'local_proxy_server.dart';

class VideoProxy {
  static late LocalProxyServer _localProxyServer;

  static DownloadManager get downloadManager =>
      _localProxyServer.downloadManager;

  static Future<void> init({String? ip, int? port}) async {
    _localProxyServer = LocalProxyServer(ip: ip, port: port);
    await _localProxyServer.start();
  }

  static void switchTasks({String? url}) {
    _localProxyServer.downloadManager.switchTasks(url: url);
  }

  static void resetAllTasks() {
    _localProxyServer.downloadManager.resetAllTasks();
  }
}
