import 'dart:io';

import '../ext/log_ext.dart';
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
  LruCacheStorage(super.maxSize);

  /// Size snapshot for each key.
  ///
  /// Disk files can be deleted or changed outside this cache. Keeping the size
  /// that was added lets [remove] subtract the same value even when `stat()`
  /// later reports zero or throws, which prevents map/size drift.
  final Map<String, int> _entrySizes = <String, int>{};

  /// Retrieves the file associated with the given [key], or `null` if not present or does not exist.
  ///
  /// Updates hit/miss statistics accordingly. The operation is thread-safe.
  @override
  Future<FileSystemEntity?> get(String key) async {
    assert(key.isNotEmpty, 'key must not be empty');
    return await lock.synchronized(() async {
      final FileSystemEntity? entity = map[key];
      final File? file = entity is File ? entity : null;
      if (file != null && await file.exists()) {
        // LinkedHashMap is insertion-ordered, so reinsert on hit to make
        // eviction approximate access-order LRU instead of creation order.
        map.remove(key);
        map[key] = file;
        hitCount++;
        return file;
      }
      if (entity != null) {
        // The file disappeared outside the cache. Drop only the index entry so
        // later trims do not see an empty map with a non-zero size ledger.
        await _removeEntryLocked(key, deleteFile: false);
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
      final int valueSize = await _safeSize(value);
      final FileSystemEntity? previous = map[key];
      if (previous != null) {
        // Replace the bookkeeping first; deleting the same path here would
        // remove the new file when callers overwrite an existing key in place.
        await _removeEntryLocked(key, deleteFile: false);
      }

      size += valueSize;
      _entrySizes[key] = valueSize;
      map[key] = value;

      await _trimToSizeLocked(maxSize);
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
      return _removeEntryLocked(key);
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
      await _trimToSizeLocked(maxSize);
    });
  }

  /// Adds an existing file without triggering eviction.
  ///
  /// Used while rebuilding the cache index from disk during startup.
  Future<void> restore(
    String key,
    FileSystemEntity value,
    int valueSize,
  ) async {
    assert(key.isNotEmpty, 'key must not be empty');
    await lock.synchronized(() async {
      if (map.containsKey(key)) {
        await _removeEntryLocked(key, deleteFile: false);
      }
      map[key] = value;
      _entrySizes[key] = valueSize;
      size += valueSize;
    });
  }

  Future<void> _trimToSizeLocked(int maxSize) async {
    // Repair before evicting because the file system may have changed since
    // the last cache operation. Throwing here would recreate the Firebase
    // non-fatal loop this class is trying to avoid.
    await _repairSizeLocked();

    while (size > maxSize) {
      final toEvict = _eldest();
      if (toEvict == null) {
        size = 0;
        return;
      }

      await _removeEntryLocked(toEvict.key);
      evictionCount++;
    }
  }

  Future<void> _repairSizeLocked() async {
    int recalculatedSize = 0;
    final missingKeys = <String>[];

    for (final entry in map.entries) {
      if (await entry.value.exists()) {
        final entrySize = await _safeSize(entry.value);
        _entrySizes[entry.key] = entrySize;
        recalculatedSize += entrySize;
      } else {
        missingKeys.add(entry.key);
      }
    }

    for (final key in missingKeys) {
      // Missing files are already gone, so only remove their bookkeeping.
      map.remove(key);
      _entrySizes.remove(key);
    }

    size = recalculatedSize;
  }

  Future<FileSystemEntity?> _removeEntryLocked(
    String key, {
    bool deleteFile = true,
  }) async {
    final FileSystemEntity? previous = map.remove(key);
    if (previous == null) return null;

    size -= _entrySizes.remove(key) ?? await _safeSize(previous);
    if (size < 0) size = 0;

    if (deleteFile) {
      try {
        if (await previous.exists()) {
          await previous.delete(recursive: true);
        }
      } on FileSystemException catch (e) {
        // The index is already repaired. File deletion is best-effort because
        // the OS or another cleanup path may race us between exists/delete.
        logE('[LruCacheStorage] Delete cache file failed: $e');
      }
    }
    return previous;
  }

  Future<int> _safeSize(FileSystemEntity entity) async {
    try {
      return (await entity.stat()).size;
    } on FileSystemException {
      // Treat missing/unreadable files as zero-byte during repair; the next
      // repair pass will remove entries whose paths no longer exist.
      return 0;
    }
  }

  MapEntry<String, FileSystemEntity>? _eldest() => map.entries.firstOrNull;
}

/// Extension to get the last modified time of a [FileSystemEntity].
extension FileSystemEntityExt on FileSystemEntity {
  /// Returns the last modified [DateTime] of the file.
  DateTime get dataTime => statSync().modified;
}
