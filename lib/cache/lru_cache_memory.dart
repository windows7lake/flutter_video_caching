import 'dart:typed_data';

import 'lru_cache_impl.dart';

/// An in-memory implementation of an LRU cache for storing binary data.
///
/// This class extends [LruCacheImpl] and uses [String] as the key type and [Uint8List]
/// as the value type for storing binary resources of files.
/// The cache size is managed based on the total number of bytes stored.
class LruCacheMemory extends LruCacheImpl<String, Uint8List> {
  /// Constructs an [LruCacheMemory] with the specified [maxSize] in bytes.
  ///
  /// Throws an assertion error if [maxSize] is not greater than 0.
  LruCacheMemory(int maxSize) : super(maxSize);

  /// Retrieves the value associated with the given [key], or `null` if not present.
  ///
  /// Updates hit/miss statistics accordingly. The operation is thread-safe.
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

  /// Inserts or updates the value for the given [key] in the cache.
  ///
  /// Returns the previous value if it existed, or `null` otherwise.
  /// Updates the cache size and triggers eviction if necessary.
  /// The operation is thread-safe.
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

  /// Removes the entry for the specified [key] from the cache, if it exists.
  ///
  /// Returns the removed value, or `null` if the key was not present.
  /// Updates the cache size accordingly. The operation is thread-safe.
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

  /// Trims the cache so that its total size does not exceed [maxSize] bytes.
  ///
  /// Evicts the least recently used entries until the size constraint is satisfied.
  /// Throws a [StateError] if the cache size becomes inconsistent.
  /// The operation is thread-safe.
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

  /// Returns the eldest entry in the cache, or `null` if the cache is empty.
  ///
  /// Used internally for eviction logic.
  MapEntry<String, Uint8List>? _eldest() => map.entries.firstOrNull;
}
