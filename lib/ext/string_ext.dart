import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../global/config.dart';

/// Extension methods for String to provide URL manipulation and hashing utilities.
extension UrlExt on String {
  /// Converts the current string (assumed to be a URL) to a local HTTP address.
  /// - If the string does not start with 'http', returns itself.
  /// - If the URL already points to the local IP and port, returns itself.
  /// - Otherwise, replaces the host and port with local config values,
  ///   and adds an 'origin' query parameter (base64-encoded original origin).
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

  /// Converts the current string to a local HTTP Uri object.
  Uri toLocalUri() {
    return Uri.parse(toLocalUrl());
  }

  /// Restores the original URL from a local URL.
  /// - If the 'origin' query parameter exists, decodes it and uses it as the base.
  /// - Replaces the path and query parameters with those from the current URL,
  ///   except for the 'origin' parameter which is removed.
  /// - If 'origin' is missing, returns itself.
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

  /// Restores the original URL as a Uri object.
  Uri toOriginUri() {
    return Uri.parse(toOriginUrl());
  }

  /// Generates the MD5 hash of the current string.
  /// Returns the hash as a hexadecimal string.
  String get generateMd5 {
    return md5.convert(utf8.encode(this)).toString();
  }

  /// Cleans and safely encodes the current string as a URL.
  /// - Trims whitespace.
  /// - Removes carriage return characters (which may cause HTTP 400 errors).
  String toSafeUrl() {
    String encodedUrl = Uri.encodeComponent(this.trim());
    // Remove carriage returns (common source of %0D)
    encodedUrl = encodedUrl.replaceAll('%0D', '');
    return Uri.decodeComponent(encodedUrl);
  }

  /// Cleans the current string and parses it as a Uri object.
  Uri toSafeUri() {
    return Uri.parse(toSafeUrl());
  }
}
