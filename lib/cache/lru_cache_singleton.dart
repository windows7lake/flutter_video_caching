import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_video_caching/cache/lru_cache_storage.dart';
import 'package:flutter_video_caching/ext/int_ext.dart';
import 'package:flutter_video_caching/ext/string_ext.dart';
import 'package:path/path.dart';
import 'package:synchronized/synchronized.dart';

import '../ext/file_ext.dart';
import '../global/config.dart';
import 'lru_cache_memory.dart';

class LruCacheSingleton {
  static final LruCacheSingleton _instance = LruCacheSingleton._();

  factory LruCacheSingleton() => _instance;

  LruCacheSingleton._() {
    _memoryCache = LruCacheMemory(Config.memoryCacheSize);
    _storageCache = LruCacheStorage(Config.storageCacheSize);
  }

  late LruCacheMemory _memoryCache;
  late LruCacheStorage _storageCache;
  Lock _lock = Lock();
  bool _isStorageInit = false;

  Future<Uint8List?> memoryGet(String key) {
    return _memoryCache.get(key);
  }

  Future<Uint8List?> memoryPut(String key, Uint8List value) {
    return _memoryCache.put(key, value);
  }

  Future<void> memoryRemove(String key) {
    return _memoryCache.remove(key);
  }

  Future<void> memoryClear() {
    return _memoryCache.clear();
  }

  Future<String> memoryFormatSize() async {
    return _memoryCache.size.toMemorySize;
  }

  Future<Uint8List?> storageGet(String key) async {
    await _storageInit();
    FileSystemEntity? file = await _storageCache.get(key);
    if (file != null && file is File) {
      return await file.readAsBytes();
    }
    return null;
  }

  Future<void> storagePut(String key, File value) async {
    await _storageInit();
    await _storageCache.put(key, value);
  }

  Future<void> storageRemove(String key) async {
    await _storageInit();
    await _storageCache.remove(key);
  }

  Future<void> storageClear() async {
    await _storageInit();
    await _storageCache.clear();
    Directory cacheDir = Directory(await FileExt.createCachePath());
    if (!(await cacheDir.exists())) return;
    for (FileSystemEntity file in cacheDir.listSync(recursive: true)) {
      await file.delete(recursive: true);
    }
  }

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

  Future<String> storageFormatSize() async {
    await _storageInit();
    return _storageCache.size.toMemorySize;
  }

  LinkedHashMap<String, FileSystemEntity> storageMap() {
    return _storageCache.map;
  }

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
