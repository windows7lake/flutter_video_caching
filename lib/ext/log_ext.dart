import 'package:logger/logger.dart';

import '../global/config.dart';

class LogInstance {
  static final Logger logger = Logger(
    filter: LocalLogFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      noBoxingByDefault: true,
    ),
  );
}

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

logV(dynamic message) => LogInstance.logger.t(message);

logD(dynamic message) => LogInstance.logger.d(message);

logI(dynamic message) => LogInstance.logger.i(message);

logW(dynamic message) => LogInstance.logger.w(message);

logE(dynamic message) => LogInstance.logger.e(message);

logN(dynamic message) => LogInstance.logger.f(message);
