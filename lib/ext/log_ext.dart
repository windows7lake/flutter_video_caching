import 'package:logger/logger.dart';

import '../global/config.dart';

class LocalLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return Config.isDebug;
  }
}

logIsolate(dynamic message) {
  if (Config.isDebug) {
    print(message);
  }
}
