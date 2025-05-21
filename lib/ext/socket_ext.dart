import 'dart:io';

import 'package:flutter_video_caching/ext/log_ext.dart';

/// HTTP request - terminator
const String httpTerminal = '\r\n\r\n';

extension SocketExtension on Socket {
  Future<void> append(Object data) async {
    try {
      if (data is String) {
        write('$data$httpTerminal');
      } else if (data is Stream<List<int>>) {
        await addStream(data);
      } else if (data is List<int>) {
        if (Platform.isIOS) {
          if (data.length <= 100000) {
            add(data);
          } else {
            int startIndex = 0, endIndex = 100000;
            while (startIndex < data.length) {
              add(data.sublist(startIndex, endIndex));
              await Future.delayed(Duration(milliseconds: 10));
              startIndex = endIndex;
              endIndex += 100000;
              if (endIndex > data.length) {
                endIndex = data.length;
              }
            }
          }
        } else {
          add(data);
        }
      }
    } catch (e) {
      logW("Socket closed: $e, can't append data");
    }
  }
}
