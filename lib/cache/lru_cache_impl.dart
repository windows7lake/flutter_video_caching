import 'dart:collection';

import 'package:synchronized/synchronized.dart';

import 'lru_cache.dart';

abstract class LruCacheImpl<K, V> extends LruCache<K, V> {
  LruCacheImpl(int maxSize) {
    assert(maxSize > 0, 'maxSize must be greater than 0');
    this.maxSize = maxSize;
    this.map = LinkedHashMap<K, V>();
  }

  /// The map of entries in the cache.
  late final LinkedHashMap<K, V> map;

  /// The maximum size of the cache.
  late int maxSize;

  /// The current size of the cache.
  int size = 0;

  /// The number of times an entry has been added to the cache.
  int putCount = 0;

  /// The number of times an entry has been evicted.
  int evictionCount = 0;

  /// The number of times an entry has been accessed.
  int hitCount = 0;

  /// The number of times an entry has not been found in the cache.
  int missCount = 0;

  /// A lock to synchronize access to the cache.
  final Lock lock = Lock();

  @override
  Future<void> clear() {
    return trimToSize(-1);
  }

  @override
  Future<void> resize(int maxSize) async {
    assert(maxSize > 0, 'maxSize must be greater than 0');
    await lock.synchronized(() {
      this.maxSize = maxSize;
      trimToSize(maxSize);
    });
  }

  @override
  String toString() {
    final int accesses = hitCount + missCount;
    final int hitPercent = accesses != 0 ? (100 * hitCount ~/ accesses) : 0;
    return '${runtimeType} [ '
        'maxSize=$maxSize, '
        'hits=$hitCount, '
        'misses=$missCount, '
        'hitRate=$hitPercent% ]';
  }
}
