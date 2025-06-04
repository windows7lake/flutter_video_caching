import 'dart:io';

import 'package:path_provider/path_provider.dart';

class FileExt {
  static String _cacheRootPath = "";

  static Future<String> createCachePath([String? cacheDir]) async {
    String rootPath = _cacheRootPath;
    if (rootPath.isEmpty) {
      rootPath = (await (Platform.isAndroid
              ? getApplicationCacheDirectory()
              : getLibraryDirectory()))
          .path;
      _cacheRootPath = rootPath;
    }
    rootPath = '$rootPath/videos';
    if (cacheDir != null && cacheDir.isNotEmpty) {
      rootPath = '$rootPath/$cacheDir';
    }
    if (Directory(rootPath).existsSync()) return rootPath;
    Directory(rootPath).createSync(recursive: true);
    return rootPath;
  }

  static Future<void> deleteCacheDirByKey(String key) async {
    if (_cacheRootPath.isEmpty) return;
    await Directory('$_cacheRootPath/$key').delete(recursive: true);
  }

  static Future<void> deleteDefaultCacheDir() async {
    if (_cacheRootPath.isEmpty) return;
    await Directory('$_cacheRootPath').delete(recursive: true);
  }

  static String get cacheRootPath => _cacheRootPath;
}
