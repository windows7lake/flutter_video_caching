import 'dart:io';

/// HTTP请求 - 终止符
const String httpTerminal = '\r\n\r\n';

/// Socket扩展
extension SocketExtension on Socket {
  /// 写入数据
  Future<void> append(Object data) async {
    if (data is String) {
      write('$data$httpTerminal');
    } else if (data is Stream<List<int>>) {
      await addStream(data);
      write(httpTerminal);
    } else if (data is List<int>) {
      add(data);
      write(httpTerminal);
    }
  }
}
