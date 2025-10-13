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

/// Custom log filter that determines whether logs should be printed
/// based on the [Config.logPrint] flag.
class LocalLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return Config.logPrint;
  }
}

/// Prints a message in an isolate if logging is enabled.
/// Used for logging in Dart isolates where [Logger] may not be available.
void logIsolate(dynamic message) {
  if (Config.logPrint) {
    print(message);
  }
}

/// Logs a verbose message using the global logger.
void logV(dynamic message) => LogInstance.logger.t(message);

/// Logs a debug message using the global logger.
void logD(dynamic message) => LogInstance.logger.d(message);

/// Logs an info message using the global logger.
void logI(dynamic message) => LogInstance.logger.i(message);

/// Logs a warning message using the global logger.
void logW(dynamic message) => LogInstance.logger.w(message);

/// Logs an error message using the global logger.
void logE(dynamic message) => LogInstance.logger.e(message);

/// Logs a fatal (wtf) message using the global logger.
void logN(dynamic message) => LogInstance.logger.f(message);
