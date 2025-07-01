import 'dart:io';

import 'lru_cache_impl.dart';

/// An LRU cache implementation for storing file system entities (such as files) on disk.
///
/// This class extends [LruCacheImpl] and uses [String] as the key type and [FileSystemEntity]
/// as the value type. The cache size is managed based on the total size (in bytes) of the files.
/// Eviction is based on the last modified time of the files.
class LruCacheStorage extends LruCacheImpl<String, FileSystemEntity> {
  /// Constructs an [LruCacheStorage] with the specified [maxSize] in bytes.
  ///
  /// Throws an assertion error if [maxSize] is not greater than 0.
  LruCacheStorage(int maxSize) : super(maxSize);

  /// Retrieves the file associated with the given [key], or `null` if not present or does not exist.
  ///
  /// Updates hit/miss statistics accordingly. The operation is thread-safe.
  @override
  Future<FileSystemEntity?> get(String key) async {
    assert(key.isNotEmpty, 'key must not be empty');
    return await lock.synchronized(() async {
      File? file = map[key] as File?;
      if (file != null && await file.exists()) {
        hitCount++;
        return file;
      }
      missCount++;
      return null;
    });
  }

  /// Inserts or updates the file for the given [key] in the cache.
  ///
  /// Returns the previous file if it existed, or `null` otherwise.
  /// Updates the cache size and triggers eviction if necessary.
  /// The operation is thread-safe.
  @override
  Future<FileSystemEntity?> put(String key, FileSystemEntity value) async {
    assert(key.isNotEmpty, 'key must not be empty');
    return await lock.synchronized(() async {
      putCount++;
      size += (await value.stat()).size;

      final FileSystemEntity? previous = map[key];
      if (previous != null) {
        size -= (await previous.stat()).size;
      }
      map[key] = value;

      trimToSize(maxSize);
      return previous;
    });
  }

  /// Removes the entry for the specified [key] from the cache, if it exists.
  ///
  /// Returns the removed file, or `null` if the key was not present.
  /// Updates the cache size and deletes the file from disk.
  /// The operation is thread-safe.
  @override
  Future<FileSystemEntity?> remove(String key) async {
    assert(key.isNotEmpty, 'key must not be empty');
    return await lock.synchronized(() async {
      final FileSystemEntity? previous = map.remove(key);
      if (previous != null) {
        size -= (await previous.stat()).size;
        await previous.delete();
      }
      return previous;
    });
  }

  /// Trims the cache so that its total size does not exceed [maxSize] bytes.
  ///
  /// Evicts the least recently modified files until the size constraint is satisfied.
  /// Throws a [StateError] if the cache size becomes inconsistent.
  /// The operation is thread-safe.
  @override
  Future<void> trimToSize(int maxSize) async {
    await lock.synchronized(() async {
      if (size < 0 || (map.isEmpty && size != 0)) {
        throw StateError(
            '$runtimeType.sizeOf() is reporting inconsistent results!');
      }

      if (size <= maxSize) return;

      // Sort entries by last modified time (oldest first)
      final sortedEntries = map.entries.toList()
        ..sort((a, b) => a.value.dataTime.compareTo(b.value.dataTime));

      int removeSize = 0;
      List<String> keysToRemove = [];
      for (final entry in sortedEntries) {
        if (size - removeSize >= maxSize || removeSize <= maxSize * 0.2) {
          removeSize += (await entry.value.stat()).size;
          keysToRemove.add(entry.key);
        } else {
          break;
        }
      }
      for (final key in keysToRemove) {
        FileSystemEntity? toEvict = map.remove(key);
        if (toEvict != null) {
          size -= (await toEvict.stat()).size;
          await toEvict.delete();
          evictionCount++;
        }
      }
    });
  }
}

/// Extension to get the last modified time of a [FileSystemEntity].
extension FileSystemEntityExt on FileSystemEntity {
  /// Returns the last modified [DateTime] of the file.
  DateTime get dataTime => statSync().modified;
}
