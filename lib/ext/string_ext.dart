import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_video_cache/global/config.dart';

extension UrlExt on String {
  /// Convert to local http address
  String toLocalUrl() {
    if (!startsWith('http')) return this;
    Uri uri = Uri.parse(this);
    if (uri.host == Config.ip && uri.port == Config.port) return this;
    String proxy = 'http://${Config.ip}:${Config.port}';
    return "$proxy${uri.path}?origin=${uri.origin}";
  }

  /// Convert to local http address
  Uri toLocalUri() {
    return Uri.parse(toLocalUrl());
  }

  /// Convert to original link
  String toOriginUrl() {
    if (!contains('?origin=')) return this;
    Uri uri = Uri.parse(this);
    String? origin = uri.queryParameters['origin'];
    String? path = uri.path;
    if (origin == null) return this;
    return '$origin$path';
  }

  /// Convert to original link
  Uri toOriginUri() {
    return Uri.parse(toOriginUrl());
  }

  /// Generate MD5
  String get generateMd5 {
    return md5.convert(utf8.encode(this)).toString();
  }
}
