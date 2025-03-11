import 'dart:collection';

import 'package:synchronized/synchronized.dart';

/// A cache that holds a fixed number of elements and evicts the least
/// recently used element when full.
class LruCache<K, V> {
  final LinkedHashMap<K, V> _map;
  final Lock _lock = Lock();

  int _size = 0;
  int _maxSize;
  int _putCount = 0;
  int _createCount = 0;
  int _evictionCount = 0;
  int _hitCount = 0;
  int _missCount = 0;

  LruCache(int maxSize)
      : assert(maxSize > 0, 'maxSize must be greater than 0'),
        _maxSize = maxSize,
        _map = LinkedHashMap<K, V>();

  /// Resizes the cache to the specified [maxSize].
  /// If the new [maxSize] is smaller than the current size of the cache,
  /// the least recently used entries will be evicted until the size of the
  /// cache is less than or equal to the new [maxSize].
  Future<void> resize(int maxSize) async {
    assert(maxSize > 0, 'maxSize must be greater than 0');
    await _lock.synchronized(() {
      _maxSize = maxSize;
      _trimToSize(maxSize);
    });
  }

  /// Returns the value associated with the [key] or `null` if the [key] is not
  /// in the cache.
  /// If the [key] is in the cache, it is marked as the most recently used.
  /// If the [key] is not in the cache, the [create] method is called to create
  /// a value for the [key]. If the [create] method returns `null`, `null` is
  /// returned.
  Future<V?> get(K key) async {
    assert(key != null, 'key must not be null');
    return await _lock.synchronized(() {
      V? mapValue = _map[key];
      if (mapValue != null) {
        _hitCount++;
        return mapValue;
      }
      _missCount++;
      final V? createdValue = create(key);
      if (createdValue == null) {
        return null;
      }

      _createCount++;
      mapValue = _map.putIfAbsent(key, () => createdValue);
      if (mapValue != null) {
        // Undo the put if there was a conflict
        _map[key] = mapValue;
      } else {
        _size += safeSizeOf(key, createdValue);
      }

      if (mapValue != null) {
        entryRemoved(false, key, createdValue, mapValue);
        return mapValue;
      } else {
        _trimToSize(_maxSize);
        return createdValue;
      }
    });
  }

  /// Associates the [key] with the [value] in the cache.
  /// If the [key] is already in the cache, the [value] is replaced and the
  /// size of the cache is adjusted.
  /// If the [key] is not in the cache, the [value] is added and the size of
  /// the cache is adjusted.
  /// If the size of the cache exceeds the [maxSize], the least recently used
  /// entries are evicted until the size of the cache is less than or equal to
  /// the [maxSize].
  Future<V?> put(K key, V value) async {
    assert(key != null && value != null, 'key and value must not be null');
    return await _lock.synchronized(() {
      _putCount++;
      _size += safeSizeOf(key, value);

      final V? previous = _map[key];
      if (previous != null) {
        _size -= safeSizeOf(key, previous);
      }
      _map[key] = value;

      if (previous != null) {
        entryRemoved(false, key, previous, value);
      }
      _trimToSize(_maxSize);
      return previous;
    });
  }

  /// Evicts the least recently used entries until the size of the cache is
  /// less than or equal to the [maxSize].
  /// If the [maxSize] is less than 0, all entries are evicted.
  /// This method is called by [put] and [resize] after adding or updating
  /// an entry.
  Future<void> _trimToSize(int maxSize) async {
    await _lock.synchronized(() {
      while (true) {
        K key;
        V value;

        if (_size < 0 || (_map.isEmpty && _size != 0)) {
          throw StateError(
            '$runtimeType.sizeOf() is reporting inconsistent results!',
          );
        }

        if (_size <= maxSize) {
          break;
        }

        final toEvict = _eldest();
        if (toEvict == null) {
          break;
        }

        key = toEvict.key;
        value = toEvict.value;
        _map.remove(key);
        _size -= safeSizeOf(key, value);
        _evictionCount++;
        entryRemoved(true, key, value, null);
      }
    });
  }

  MapEntry<K, V>? _eldest() => _map.entries.firstOrNull;

  /// Removes the [key] and its associated value from the cache.
  /// Returns the value associated with the [key] or `null` if the [key] is not
  /// in the cache.
  /// If the [key] is in the cache, the entry is removed and the size of the
  /// cache is adjusted.
  Future<V?> remove(K key) async {
    assert(key != null, 'key must not be null');
    return await _lock.synchronized(() {
      final V? previous = _map.remove(key);
      if (previous != null) {
        _size -= safeSizeOf(key, previous);
        entryRemoved(false, key, previous, null);
      }
      return previous;
    });
  }

  void entryRemoved(bool evicted, K key, V oldValue, V? newValue) {}

  V? create(K key) => null;

  /// Returns the size of the [value] for the [key].
  /// The default implementation returns `1` for all entries.
  /// Subclasses can override this method to return the actual size of the
  /// [value].
  /// The size must be non-negative.
  /// If the size is negative, a [StateError] is thrown.
  /// If the size is zero, the entry is evicted from the cache.
  /// If the size is greater than the [maxSize], the entry is evicted from the
  /// cache.
  int safeSizeOf(K key, V value) {
    final int result = sizeOf(key, value);
    if (result < 0) {
      throw StateError('Size must be non-negative: $key=$value');
    }
    return result;
  }

  /// Returns the size of the [value] for the [key].
  int sizeOf(K key, V value) => 1;

  /// Removes all entries from the cache.
  Future<void> evictAll() async {
    await _trimToSize(-1);
  }

  /// Returns the number of entries in the cache.
  Future<int> size() async {
    return await _lock.synchronized(() => _size);
  }

  /// Returns the maximum size of the cache.
  int maxSize() => _maxSize;

  /// Returns the number of times an entry has been accessed.
  int hitCount() => _hitCount;

  /// Returns the number of times an entry has been accessed.
  int missCount() => _missCount;

  /// Returns the number of times an entry has been created.
  int createCount() => _createCount;

  /// Returns the number of times an entry has been added to the cache.
  int putCount() => _putCount;

  /// Returns the number of times an entry has been evicted.
  int evictionCount() => _evictionCount;

  /// Returns a snapshot of the cache.
  Map<K, V> snapshot() => Map<K, V>.from(_map);

  @override
  String toString() {
    final int accesses = _hitCount + _missCount;
    final int hitPercent = accesses != 0 ? (100 * _hitCount ~/ accesses) : 0;
    return 'LruCache[maxSize=$_maxSize,hits=$_hitCount,misses=$_missCount,'
        'hitRate=$hitPercent%]';
  }
}
