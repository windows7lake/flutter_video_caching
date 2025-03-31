import 'local_proxy_server.dart';

class VideoProxy {
  static late LocalProxyServer _localProxyServer;

  static Future<void> init({String? ip, int? port}) async {
    _localProxyServer = LocalProxyServer(ip: ip, port: port);
    await _localProxyServer.start();
  }

  static void switchTasks() {
    _localProxyServer.downloadManager.switchTasks();
  }

  static void resetAllTasks() {
    _localProxyServer.downloadManager.resetAllTasks();
  }
}
