import 'dart:io';

import 'package:path_provider/path_provider.dart';

class FileExt {
  static String cacheRootPath = "";
  static String cacheDirPath = "";

  static Future<String> createCachePath([String? cacheDir]) async {
    String rootPath = cacheRootPath;
    if (rootPath.isEmpty) {
      rootPath = (await getApplicationCacheDirectory()).path;
      cacheRootPath = rootPath;
    }
    rootPath = '$rootPath/videos';
    if (cacheDir != null && cacheDir.isNotEmpty) {
      rootPath = '$rootPath/$cacheDir';
    }
    if (Directory(rootPath).existsSync()) return rootPath;
    Directory(rootPath).createSync(recursive: true);
    return rootPath;
  }
}
