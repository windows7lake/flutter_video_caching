import 'dart:io';

import 'lru_cache_impl.dart';

class LruCacheStorage extends LruCacheImpl<String, FileSystemEntity> {
  LruCacheStorage(int maxSize) : super(maxSize);

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

  @override
  Future<FileSystemEntity?> remove(String key) async {
    assert(key.isNotEmpty, 'key must not be empty');
    return await lock.synchronized(() async {
      final FileSystemEntity? previous = map.remove(key);
      if (previous != null) {
        size -= (await previous.stat()).size;
      }
      return previous;
    });
  }

  @override
  Future<void> trimToSize(int maxSize) async {
    await lock.synchronized(() async {
      if (size < 0 || (map.isEmpty && size != 0)) {
        throw StateError(
            '$runtimeType.sizeOf() is reporting inconsistent results!');
      }

      if (size <= maxSize) return;

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
        FileSystemEntity? toEvict = map[key];
        if (toEvict != null) {
          map.remove(key);
          size -= (await toEvict.stat()).size;
          await toEvict.delete();
          evictionCount++;
        }
      }
    });
  }
}

extension FileSystemEntityExt on FileSystemEntity {
  DateTime get dataTime => statSync().modified;
}
