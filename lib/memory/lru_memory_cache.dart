import 'dart:collection';
import 'dart:typed_data';

import 'package:synchronized/synchronized.dart';

class LruMemoryCache {
  final LinkedHashMap<String, Uint8List> _map;
  final Lock _lock = Lock();

  int _size = 0;
  int _maxSize;
  int _putCount = 0;
  int _evictionCount = 0;
  int _hitCount = 0;
  int _missCount = 0;

  LruMemoryCache(int maxSize)
      : assert(maxSize > 0, 'maxSize must be greater than 0'),
        _maxSize = maxSize,
        _map = LinkedHashMap<String, Uint8List>();

  Future<Uint8List?> get(String key) async {
    assert(key.isNotEmpty, 'key must not be empty');
    return await _lock.synchronized(() {
      Uint8List? mapValue = _map[key];
      if (mapValue != null) {
        _hitCount++;
        return mapValue;
      }
      _missCount++;
      return null;
    });
  }

  Future<Uint8List?> put(String key, Uint8List value) async {
    assert(key.isNotEmpty, 'key must not be empty');
    return await _lock.synchronized(() {
      _putCount++;
      _size += value.lengthInBytes;

      final Uint8List? previous = _map[key];
      if (previous != null) {
        _size -= previous.lengthInBytes;
      }
      _map[key] = value;

      _trimToSize(_maxSize);
      return previous;
    });
  }

  Future<Uint8List?> remove(String key) async {
    assert(key.isNotEmpty, 'key must not be empty');
    return await _lock.synchronized(() {
      final Uint8List? previous = _map.remove(key);
      if (previous != null) {
        _size -= previous.lengthInBytes;
      }
      return previous;
    });
  }

  /// Removes all entries from the cache.
  Future<void> evictAll() async {
    await _trimToSize(-1);
  }

  Future<List<String>> keys() async {
    return await _lock.synchronized(() => _map.keys.toList());
  }

  Future<int> size() async {
    return await _lock.synchronized(() => _size);
  }

  Future<void> _trimToSize(int maxSize) async {
    await _lock.synchronized(() {
      while (true) {
        String key;
        Uint8List value;

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
        _size -= value.lengthInBytes;
        _evictionCount++;
      }
    });
  }

  MapEntry<String, Uint8List>? _eldest() => _map.entries.firstOrNull;

  Future<void> resize(int maxSize) async {
    assert(maxSize > 0, 'maxSize must be greater than 0');
    await _lock.synchronized(() {
      _maxSize = maxSize;
      _trimToSize(maxSize);
    });
  }

  /// Returns the maximum size of the cache.
  int maxSize() => _maxSize;

  /// Returns the number of times an entry has been accessed.
  int hitCount() => _hitCount;

  /// Returns the number of times an entry has been accessed.
  int missCount() => _missCount;

  /// Returns the number of times an entry has been added to the cache.
  int putCount() => _putCount;

  /// Returns the number of times an entry has been evicted.
  int evictionCount() => _evictionCount;

  @override
  String toString() {
    final int accesses = _hitCount + _missCount;
    final int hitPercent = accesses != 0 ? (100 * _hitCount ~/ accesses) : 0;
    return 'LruMemoryCache [ '
        'maxSize=$_maxSize, '
        'hits=$_hitCount, '
        'misses=$_missCount, '
        'hitRate=$hitPercent% ]';
  }
}
