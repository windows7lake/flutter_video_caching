import 'package:flutter/foundation.dart';
import 'package:log_wrapper/log/log.dart';

import '../global/config.dart';
import 'lru_cache.dart';

class MemoryCache {
  static final LruCache<String, Uint8List> _memoryCache =
      LruCache(Config.memoryCacheSize); // 100MB

  static Future<Uint8List?> get(String key) {
    return _memoryCache.get(key);
  }

  static Future<Uint8List?> put(String key, Uint8List value) {
    return _memoryCache.put(key, value);
  }

  static Future<Uint8List?> append(String key, Uint8List value) async {
    Uint8List result = value;
    Uint8List? last = await _memoryCache.get(key);
    if (last != null) {
      result = _safeMerge([last, value]);
    }
    return await _memoryCache.put(key, result);
  }

  static Uint8List _mergeUint8Lists(List<Uint8List> lists) {
    // 计算总长度
    int totalLength = lists.fold(0, (sum, list) => sum + list.length);
    // 创建目标容器
    final merged = Uint8List(totalLength);
    int offset = 0;
    // 分段拷贝
    for (var list in lists) {
      merged.setAll(offset, list);
      offset += list.length;
    }
    return merged;
  }

  static Uint8List _safeMerge(List<Uint8List> lists) {
    try {
      // 有效性校验
      if (lists.isEmpty) return Uint8List(0);

      // 内存占用预警
      const maxMemory = 100 * 1024 * 1024; // 512MB
      final total = lists.fold<int>(0, (s, e) => s + e.length);
      if (total > maxMemory) {
        throw Exception('合并后数据超过内存限制');
      }

      return _mergeUint8Lists(lists);
    } on Exception catch (e) {
      logE('内存错误: ${e}');
      return Uint8List(0);
    }
  }
}
