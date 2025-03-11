import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 文件工具
class FileExt {
  /// 资源转文件
  static Future<File> assetToFile(String assetPath) async {
    try {
      // 获取字节数据
      final ByteData byteData = await rootBundle.load(assetPath);

      // 创建临时文件
      final Directory dir = await getTemporaryDirectory();
      final File file = File('${dir.path}/${assetPath.split('/').last}');

      // 写入文件系统
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

      return file;
    } on PlatformException catch (e) {
      throw Exception('资源加载失败: ${e.message}');
    } on IOException catch (e) {
      throw Exception('文件写入失败: $e');
    }
  }
}
