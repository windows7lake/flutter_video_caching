import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Extension methods for the [Uri] class, providing additional utilities.
extension UriExt on Uri {
  /// Returns a string representation of the URI with a truncated path.
  ///
  /// [relativePath] specifies how many segments from the end of the path should be excluded.
  /// For example, if the URI is `https://example.com/a/b/c` and [relativePath] is 1,
  /// the result will be `https://example.com/a/b`.
  /// Throws an [Exception] if the path segments are empty.
  String pathPrefix([int relativePath = 0]) {
    if (pathSegments.isEmpty) throw Exception("Path segments are empty");
    // Remove the last [relativePath] + 1 segments from the path.
    List<String> segments =
        pathSegments.sublist(0, pathSegments.length - 1 - relativePath);
    // Create a new URI with the truncated path and no query parameters.
    Uri newUri = replace(pathSegments: segments, queryParameters: {});
    // Return the string representation without the query part.
    return newUri.toString().replaceAll('?', '');
  }

  /// Generates the MD5 hash of the URI as a string.
  ///
  /// Converts the URI to a string, encodes it as UTF-8, and returns the MD5 hash.
  String get generateMd5 {
    return md5.convert(utf8.encode(this.toString())).toString();
  }
}
