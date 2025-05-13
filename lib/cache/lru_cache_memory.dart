import 'dart:typed_data';

import 'lru_cache_impl.dart';

class LruCacheMemory extends LruCacheImpl<String, Uint8List> {
  LruCacheMemory(int maxSize) : super(maxSize);

  @override
  Future<Uint8List?> get(String key) async {
    assert(key.isNotEmpty, 'key must not be empty');
    return await lock.synchronized(() {
      Uint8List? mapValue = map[key];
      if (mapValue != null) {
        hitCount++;
        return mapValue;
      }
      missCount++;
      return null;
    });
  }

  @override
  Future<Uint8List?> put(String key, Uint8List value) async {
    assert(key.isNotEmpty, 'key must not be empty');
    return await lock.synchronized(() {
      putCount++;
      size += value.lengthInBytes;

      final Uint8List? previous = map[key];
      if (previous != null) {
        size -= previous.lengthInBytes;
      }
      map[key] = value;

      trimToSize(maxSize);
      return previous;
    });
  }

  @override
  Future<Uint8List?> remove(key) async {
    assert(key.isNotEmpty, 'key must not be empty');
    return await lock.synchronized(() {
      final Uint8List? previous = map.remove(key);
      if (previous != null) {
        size -= previous.lengthInBytes;
      }
      return previous;
    });
  }

  @override
  Future<void> trimToSize(int maxSize) async {
    await lock.synchronized(() {
      while (true) {
        String key;
        Uint8List value;

        if (size < 0 || (map.isEmpty && size != 0)) {
          throw StateError(
            '$runtimeType.sizeOf() is reporting inconsistent results!',
          );
        }

        if (size <= maxSize) {
          break;
        }

        final toEvict = _eldest();
        if (toEvict == null) {
          break;
        }

        key = toEvict.key;
        value = toEvict.value;
        map.remove(key);
        size -= value.lengthInBytes;
        evictionCount++;
      }
    });
  }

  MapEntry<String, Uint8List>? _eldest() => map.entries.firstOrNull;
}
