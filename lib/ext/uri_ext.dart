import 'dart:convert';

import 'package:crypto/crypto.dart';

extension UriExt on Uri {
  String pathPrefix([int relativePath = 0]) {
    if (pathSegments.isEmpty) throw Exception("Path segments are empty");
    List<String> segments =
        pathSegments.sublist(0, pathSegments.length - 1 - relativePath);
    Uri newUri = replace(pathSegments: segments, queryParameters: {});
    return newUri.toString().replaceAll('?', '');
  }

  /// Generate MD5
  String get generateMd5 {
    return md5.convert(utf8.encode(this.toString())).toString();
  }
}
