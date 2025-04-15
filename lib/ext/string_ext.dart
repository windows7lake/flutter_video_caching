import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_video_cache/global/config.dart';

extension UrlExt on String {
  /// 转换为本地地址
  String toLocalUrl() {
    if (!startsWith('http')) return this;
    Uri uri = Uri.parse(this);
    if (uri.host == Config.ip && uri.port == Config.port) return this;
    String proxy = 'http://${Config.ip}:${Config.port}';
    return "$proxy${uri.path}?origin=${uri.origin}";
  }

  /// 转换为本地地址
  Uri toLocalUri() {
    return Uri.parse(toLocalUrl());
  }

  /// 转换为原始链接
  String toOriginUrl() {
    if (!contains('?origin=')) return this;
    Uri uri = Uri.parse(this);
    String? origin = uri.queryParameters['origin'];
    String? path = uri.path;
    if (origin == null) return this;
    return '$origin$path';
  }

  /// 转换为原始链接
  Uri toOriginUri() {
    return Uri.parse(toOriginUrl());
  }

  /// 生成MD5
  String get generateMd5 {
    return md5.convert(utf8.encode(this)).toString();
  }
}
