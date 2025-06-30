import 'dart:collection';

import 'package:synchronized/synchronized.dart';

import 'lru_cache.dart';

/// An abstract base class that provides a partial implementation of the [LruCache] interface.
///
/// This class manages the core data structures and statistics for an LRU cache,
/// including the underlying map, size tracking, and synchronization.
/// Subclasses should implement the remaining logic for cache operations.
abstract class LruCacheImpl<K, V> extends LruCache<K, V> {
  /// Constructs an [LruCacheImpl] with the specified [maxSize].
  ///
  /// Throws an assertion error if [maxSize] is not greater than 0.
  LruCacheImpl(int maxSize) {
    assert(maxSize > 0, 'maxSize must be greater than 0');
    this.maxSize = maxSize;
    this.map = LinkedHashMap<K, V>();
  }

  /// The map that stores the cache entries in access order.
  ///
  /// Uses [LinkedHashMap] to maintain insertion order, which can be leveraged
  /// for LRU eviction policies.
  late final LinkedHashMap<K, V> map;

  /// The maximum number of entries the cache can hold.
  late int maxSize;

  /// The current number of entries in the cache.
  int size = 0;

  /// The total number of times an entry has been added to the cache.
  int putCount = 0;

  /// The total number of times an entry has been evicted from the cache.
  int evictionCount = 0;

  /// The total number of cache hits (successful lookups).
  int hitCount = 0;

  /// The total number of cache misses (failed lookups).
  int missCount = 0;

  /// A lock used to synchronize access to the cache for thread safety.
  final Lock lock = Lock();

  /// Removes all entries from the cache.
  ///
  /// This method delegates to [trimToSize] with a size of -1, which should
  /// clear the cache completely.
  @override
  Future<void> clear() {
    return trimToSize(-1);
  }

  /// Resizes the cache to the new [maxSize].
  ///
  /// If the current size exceeds [maxSize], this method will evict entries as needed.
  /// The operation is synchronized to ensure thread safety.
  @override
  Future<void> resize(int maxSize) async {
    assert(maxSize > 0, 'maxSize must be greater than 0');
    await lock.synchronized(() {
      this.maxSize = maxSize;
      trimToSize(maxSize);
    });
  }

  /// Returns a string representation of the cache, including statistics such as
  /// maximum size, hit count, miss count, and hit rate percentage.
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
