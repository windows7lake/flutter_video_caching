import 'local_proxy_server.dart';

class VideoProxy {
  static String compareUrl = "";
  static late LocalProxyServer _localProxyServer;

  static Future<void> init({String? ip, int? port}) async {
    _localProxyServer = LocalProxyServer(ip: ip, port: port);
    await _localProxyServer.start();
  }
}
