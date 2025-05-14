import 'dart:io';

/// HTTP request - terminator
const String httpTerminal = '\r\n\r\n';

extension SocketExtension on Socket {
  Future<void> append(Object data) async {
    if (data is String) {
      write('$data$httpTerminal');
    } else if (data is Stream<List<int>>) {
      await addStream(data);
    } else if (data is List<int>) {
      add(data);
    }
  }
}
