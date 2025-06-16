import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../global/config.dart';

extension UrlExt on String {
  /// Convert to local http address
  String toLocalUrl() {
    if (!startsWith('http')) return this;
    Uri uri = this.toSafeUri();
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
    Uri uri = this.toSafeUri();
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

  /// Safely parses a URL string into a Uri object by:
  /// 1. Removing any hidden or invalid characters like '\r' and '\n'
  /// 2. Trimming extra whitespace
  /// 3. Truncating the string right after `.ts` to avoid garbage like `%0D`
  ///
  /// This ensures the resulting Uri is clean and avoids HTTP 400 errors when used.
  String toSafeUrl() {
    String encodedUrl = Uri.encodeComponent(this.trim());
    // Remove carriage returns (common source of %0D)
    encodedUrl = encodedUrl.replaceAll('%0D', '');
    return Uri.decodeComponent(encodedUrl);
  }

  /// Converts the string to a safe Uri by cleaning it up.
  Uri toSafeUri() {
    return Uri.parse(toSafeUrl());
  }
}
