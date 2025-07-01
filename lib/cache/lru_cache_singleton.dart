import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:synchronized/synchronized.dart';

import '../ext/file_ext.dart';
import '../ext/int_ext.dart';
import '../ext/string_ext.dart';
import '../global/config.dart';
import 'lru_cache_memory.dart';
import 'lru_cache_storage.dart';

/// A singleton class that manages both in-memory and disk-based LRU caches.
///
/// This class provides a unified interface for caching binary data in memory and files on disk.
/// It ensures thread safety and lazy initialization for the storage cache.
/// The cache sizes are configurable via the [Config] class.
class LruCacheSingleton {
  /// The singleton instance.
  static final LruCacheSingleton _instance = LruCacheSingleton._();

  /// Factory constructor to return the singleton instance.
  factory LruCacheSingleton() => _instance;

  /// Private constructor for singleton pattern.
  LruCacheSingleton._() {
    _memoryCache = LruCacheMemory(Config.memoryCacheSize);
    _storageCache = LruCacheStorage(Config.storageCacheSize);
  }

  /// The in-memory LRU cache for binary data.
  late LruCacheMemory _memoryCache;

  /// The disk-based LRU cache for file system entities.
  late LruCacheStorage _storageCache;

  /// Lock for synchronizing storage cache initialization.
  Lock _lock = Lock();

  /// Flag indicating whether the storage cache has been initialized.
  bool _isStorageInit = false;

  /// Retrieves a value from the in-memory cache by [key].
  Future<Uint8List?> memoryGet(String key) {
    return _memoryCache.get(key);
  }

  /// Inserts a value into the in-memory cache.
  Future<Uint8List?> memoryPut(String key, Uint8List value) {
    return _memoryCache.put(key, value);
  }

  /// Removes a value from the in-memory cache by [key].
  Future<void> memoryRemove(String key) {
    return _memoryCache.remove(key);
  }

  /// Clears all entries from the in-memory cache.
  Future<void> memoryClear() {
    return _memoryCache.clear();
  }

  /// Returns the formatted size of the in-memory cache.
  Future<String> memoryFormatSize() async {
    return _memoryCache.size.toMemorySize;
  }

  /// Retrieves a value from the disk cache by [key] as bytes.
  ///
  /// Ensures the storage cache is initialized before access.
  Future<Uint8List?> storageGet(String key) async {
    await _storageInit();
    FileSystemEntity? file = await _storageCache.get(key);
    if (file != null && file is File) {
      return await file.readAsBytes();
    }
    return null;
  }

  /// Inserts a file into the disk cache.
  ///
  /// Ensures the storage cache is initialized before access.
  Future<void> storagePut(String key, File value) async {
    await _storageInit();
    await _storageCache.put(key, value);
  }

  /// Removes a file from the disk cache by [key].
  ///
  /// Ensures the storage cache is initialized before access.
  Future<void> storageRemove(String key) async {
    await _storageInit();
    await _storageCache.remove(key);
  }

  /// Clears all entries from the disk cache and deletes all files in the cache directory.
  Future<void> storageClear() async {
    await _storageInit();
    await _storageCache.clear();
    Directory cacheDir = Directory(await FileExt.createCachePath());
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }

  /// Clears all files in a specific directory path from the disk cache.
  ///
  /// Also removes corresponding entries from the cache.
  Future<void> storageClearByDirPath(String dirPath) async {
    await _storageInit();
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;

    final files = dir.listSync(recursive: true);
    for (FileSystemEntity entity in files) {
      final stat = await entity.stat();
      if (stat.type == FileSystemEntityType.file) {
        String filePath = entity.path;
        await entity.delete(recursive: true);
        await storageRemove(filePath);
      }
    }
    await dir.delete(recursive: true);
  }

  /// Returns the formatted size of the disk cache.
  Future<String> storageFormatSize() async {
    await _storageInit();
    return _storageCache.size.toMemorySize;
  }

  /// Returns the internal map of the disk cache.
  LinkedHashMap<String, FileSystemEntity> storageMap() {
    return _storageCache.map;
  }

  /// Initializes the storage cache by scanning the cache directory and loading existing files.
  ///
  /// Ensures this operation is performed only once (lazy initialization).
  Future<void> _storageInit() async {
    await _lock.synchronized(() async {
      if (_isStorageInit) return;
      _isStorageInit = true;
      Directory cacheDir = Directory(await FileExt.createCachePath());
      if (!(await cacheDir.exists())) return;
      for (FileSystemEntity file in cacheDir.listSync(recursive: true)) {
        FileStat stat = await file.stat();
        if (stat.type == FileSystemEntityType.file) {
          String key = basenameWithoutExtension(file.path);
          _storageCache.map[key] = file;
          _storageCache.size += stat.size;
        }
      }
    });
  }

  /// Removes cache entries (both in-memory and disk) associated with a URL.
  ///
  /// If [singleFile] is true, only the file matching the URL is removed.
  /// Otherwise, all files in the directory related to the URL are removed.
  Future<void> removeCacheByUrl(String url, {bool singleFile = false}) async {
    String key = url.generateMd5;
    await _storageInit();
    if (singleFile) {
      // delete single file from storage and memory
      await _storageCache.remove(key);
      await _memoryCache.remove(key);
    } else {
      // delete all files in directory related to the URL from storage and memory
      Directory cacheDir = Directory(await FileExt.createCachePath());
      if (!(await cacheDir.exists())) return;
      for (FileSystemEntity file in cacheDir.listSync()) {
        FileStat stat = await file.stat();
        if (stat.type == FileSystemEntityType.directory) {
          String directoryName = basename(file.path);
          if (directoryName == key) {
            Directory directory = file as Directory;
            await directory.list(recursive: true).forEach((subFile) async {
              if (subFile is File) {
                String subKey = basenameWithoutExtension(subFile.path);
                await _memoryCache.remove(subKey);
              }
            });
            await file.delete(recursive: true);
            await directory.delete(recursive: true);
          }
        }
      }
    }
  }
}
