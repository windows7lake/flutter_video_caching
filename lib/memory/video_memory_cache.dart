import 'dart:typed_data';

import '../global/config.dart';
import 'lru_memory_cache.dart';

class VideoMemoryCache {
  static final LruMemoryCache _memoryCache =
      LruMemoryCache(Config.memoryCacheSize); // 100MB

  static Future<Uint8List?> get(String key) {
    return _memoryCache.get(key);
  }

  static Future<Uint8List?> put(String key, Uint8List value) {
    return _memoryCache.put(key, value);
  }

  static Future<int> size() {
    return _memoryCache.size();
  }
}
