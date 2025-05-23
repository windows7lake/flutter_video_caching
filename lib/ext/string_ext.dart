import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../global/config.dart';

extension UrlExt on String {
  /// Convert to local http address
  String toLocalUrl() {
    if (!startsWith('http')) return this;
    Uri uri = Uri.parse(this);
    if (uri.host == Config.ip && uri.port == Config.port) return this;
    Map<String, String> queryParameters = {...uri.queryParameters};
    queryParameters.putIfAbsent(
        'origin', () => base64Url.encode(utf8.encode(uri.origin)));
    uri = uri.replace(
      scheme: 'http',
      host: Config.ip,
      port: Config.port,
      queryParameters: queryParameters,
    );
    return uri.toString();
  }

  /// Convert to local http address
  Uri toLocalUri() {
    return Uri.parse(toLocalUrl());
  }

  /// Convert to original link
  String toOriginUrl() {
    Uri uri = Uri.parse(this);
    Map<String, String> queryParameters = {...uri.queryParameters};
    if (!queryParameters.containsKey('origin')) return this;
    String? origin = queryParameters['origin'];
    if (origin != null && origin.isNotEmpty) {
      origin = utf8.decode(base64Url.decode(origin));
    }
    if (origin == null) return this;
    Uri originUri = Uri.parse(origin);
    queryParameters.remove('origin');
    originUri = originUri.replace(
      path: uri.path,
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );
    return originUri.toString();
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
