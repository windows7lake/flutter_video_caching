import 'package:flutter/foundation.dart';

class Config {
  static const bool isDebug = kDebugMode;

  static String ip = '127.0.0.1';
  static int port = 20250;

  static int mbSize = 1024 * 1024;
  static int gbSize = 1024 * mbSize;
  static int memoryCacheSize = 100 * mbSize; // 100MB
  static int storageCacheSize = 1 * gbSize; // 1GB
}
