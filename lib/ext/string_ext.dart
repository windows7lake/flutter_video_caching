import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../global/config.dart';

/// Extension methods for String to provide URL manipulation and hashing utilities.
extension UrlExt on String {
  /// The query parameter [toLocalUrl] tags a local url with.
  static const String _originMarker = 'origin';

  /// Converts the current string (assumed to be a URL) to a local HTTP address.
  /// - If the string does not start with 'http', returns itself.
  /// - If the URL has no host, or already points to the local IP and port,
  ///   returns itself.
  /// - Otherwise, replaces the host and port with local config values,
  ///   and appends an 'origin' query parameter (base64-encoded original origin).
  String toLocalUrl() {
    if (!startsWith('http')) return this;
    final Uri uri = this.toSafeUri();
    // `uri.origin` throws unless the uri has a host and an http(s) scheme, and
    // this sits on the playback path — every start-up goes through here.
    // `startsWith('http')` lets through 'httpx://…', 'http' and 'https:/a/b'.
    final bool canOrigin =
        uri.host.isNotEmpty && (uri.scheme == 'http' || uri.scheme == 'https');
    if (!canOrigin) return this;
    if (uri.host == Config.ip && uri.port == Config.port) return this;
    // The query string is carried over verbatim instead of going through
    // `replace(queryParameters:)`. That rebuilds it from a Map, which cannot
    // hold repeated keys (`?a=1&a=2` collapses to `?a=2`) and re-encodes what
    // is left (`%20` comes back as `+`).
    //
    // What that breaks is the request the proxy sends back to the CDN: a signed
    // url loses a parameter, or has one re-encoded, and the origin answers 403.
    // (It does not change the cache key — `UrlMatcherDefault.matchCacheKey`
    // strips every parameter except the range ones before the key is hashed.)
    //
    // The marker is appended even when the url already carries a parameter of
    // the same name; [toOriginUrl] picks ours out by value, not by name alone.
    final String marker =
        '$_originMarker=${base64Url.encode(utf8.encode(uri.origin))}';
    final String query = uri.query.isEmpty ? marker : '${uri.query}&$marker';
    // The credentials stay out of the local url. They belong to the origin, and
    // [toOriginUrl] cannot put them back (`uri.origin` drops them), so carrying
    // them over would only leak them into whatever logs the proxy url.
    return uri
        .replace(
          scheme: 'http',
          host: Config.ip,
          port: Config.port,
          userInfo: '',
          query: query,
        )
        .toString();
  }

  /// Converts the current string to a local HTTP Uri object.
  Uri toLocalUri() {
    return Uri.parse(toLocalUrl());
  }

  /// Restores the original URL from a local URL.
  ///
  /// `origin` is an ordinary parameter name a source URL may well use for its
  /// own purposes, so the marker cannot be found by name alone. The scan runs
  /// right to left and takes the first `origin=` whose value decodes into an
  /// absolute URL: [toLocalUrl] appends ours last, so ours is found first, and
  /// a business parameter that merely shares the name is left in place.
  ///
  /// Returns the string untouched when no such parameter is found.
  String toOriginUrl() {
    final Uri uri = this.toSafeUri();
    if (uri.query.isEmpty) return this;
    final List<String> parts = uri.query.split('&');
    for (int i = parts.length - 1; i >= 0; i--) {
      final String part = parts[i];
      if (!part.startsWith('$_originMarker=')) continue;
      final String value = part.substring(_originMarker.length + 1);
      if (value.isEmpty) continue;
      final String decoded;
      try {
        decoded = utf8.decode(base64Url.decode(value));
      } on FormatException {
        continue;
      }
      final Uri base = Uri.tryParse(decoded) ?? Uri();
      if (!base.hasScheme || base.host.isEmpty) continue;
      final String rest =
          <String>[...parts.sublist(0, i), ...parts.sublist(i + 1)].join('&');
      return base
          .replace(
            path: uri.path,
            query: rest.isEmpty ? null : rest,
            fragment: uri.fragment.isEmpty ? null : uri.fragment,
          )
          .toString();
    }
    return this;
  }

  /// Same as [toOriginUrl], as a [Uri]. Never throws: it goes through
  /// [toSafeUri], which falls back to an empty `Uri` on unparseable input.
  Uri toOriginUri() {
    return toOriginUrl().toSafeUri();
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
    return Uri.tryParse(toSafeUrl()) ?? Uri();
  }
}
