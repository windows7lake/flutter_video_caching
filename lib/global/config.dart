import 'package:flutter/foundation.dart';

class Config {
  static const bool isDebug = kDebugMode;
  static bool logPrint = false;

  static String ip = '127.0.0.1';
  static int port = 20250;

  static int mbSize = 1000 * 1000;
  static int gbSize = 1000 * mbSize;
  static int memoryCacheSize = 100 * mbSize; // 100MB
  static int storageCacheSize = 1 * gbSize; // 1GB

  static int segmentSize = 2000000;
}
