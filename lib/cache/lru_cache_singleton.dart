import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_video_caching/cache/lru_cache_storage.dart';
import 'package:flutter_video_caching/ext/int_ext.dart';

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
  bool _isStorageInit = false;

  Future<Uint8List?> memoryGet(String key) {
    return _memoryCache.get(key);
  }

  Future<Uint8List?> memoryPut(String key, Uint8List value) {
    return _memoryCache.put(key, value);
  }

  Future<String> memoryMbSize() async {
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

  Future<String> storageMbSize() async {
    await _storageInit();
    return _storageCache.size.toMemorySize;
  }

  LinkedHashMap<String, FileSystemEntity> storageMap() {
    return _storageCache.map;
  }

  Future<void> _storageInit() async {
    if (_isStorageInit) return;
    _isStorageInit = true;
    Directory cacheDir = Directory(await FileExt.createCachePath());
    if (!(await cacheDir.exists())) return;
    for (FileSystemEntity file in cacheDir.listSync(recursive: true)) {
      FileStat stat = await file.stat();
      if (stat.type == FileSystemEntityType.file) {
        _storageCache.map[file.path] = file;
        _storageCache.size += stat.size;
      }
    }
  }
}
