import 'dart:convert';

import 'package:crypto/crypto.dart';

extension UriExt on Uri {
  String get pathPrefix {
    if (pathSegments.isEmpty) throw Exception("Path segments are empty");
    List<String> segments = pathSegments.sublist(0, pathSegments.length - 1);
    Uri newUri = replace(pathSegments: segments);
    return newUri.toString();
  }

  /// Generate MD5
  String get generateMd5 {
    return md5.convert(utf8.encode(this.toString())).toString();
  }
}
