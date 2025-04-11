import '../download/download_manager.dart';
import 'local_proxy_server.dart';

class VideoProxy {
  static String compareUrl = "";
  static late LocalProxyServer _localProxyServer;

  static DownloadManager get downloadManager =>
      _localProxyServer.downloadManager;

  static Future<void> init({String? ip, int? port}) async {
    _localProxyServer = LocalProxyServer(ip: ip, port: port);
    await _localProxyServer.start();
  }
}
