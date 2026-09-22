import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_caching/ext/string_ext.dart';
import 'package:flutter_video_caching/global/config.dart';

/// `origin` is the query parameter a local url is tagged with, and it is also
/// an ordinary name a source url may use for its own purposes. These tests pin
/// down how the two are told apart, and that a url survives the round trip
/// byte for byte.
///
/// Both matter for the same reason: the restored url is what the proxy sends
/// back to the CDN. Lose a query parameter, or re-encode one, and a signed url
/// comes back 403 — no error anywhere on our side, the video just fails to
/// play. (The cache key itself is unaffected: `UrlMatcherDefault.matchCacheKey`
/// strips every parameter except the range ones before hashing.)
void main() {
  /// Sources that must survive `toLocalUrl()` → `toOriginUrl()` unchanged.
  const roundTrips = <String, String>{
    'no query': 'https://cdn.example.com/a.mp4',
    'plain query': 'https://cdn.example.com/a.mp4?t=1',
    // Rebuilding the query from a Map turned %20 into +.
    'percent-encoded space': 'https://cdn.example.com/a.mp4?t=b%20c',
    // A Map cannot hold both, so one of them used to be dropped.
    'repeated key': 'https://cdn.example.com/a.mp4?a=1&a=2',
    'marker name in the middle': 'https://cdn.example.com/a.mp4?a=1&origin=web&b=2',
    'signature-ish value': 'https://cdn.example.com/a.mp4?sign=x%2Fy%2Bz%3D',
    'encoded separators in value': 'https://cdn.example.com/a.mp4?v=a%26b',
    'valueless parameter': 'https://cdn.example.com/a.mp4?flag',
    'empty value': 'https://cdn.example.com/a.mp4?empty=&t=1',
    'fragment only': 'https://cdn.example.com/a.mp4#t=1',
    'query and fragment': 'https://cdn.example.com/a.mp4?t=1#frag',
    // The marker name is taken; ours is appended anyway and found by value.
    'own origin parameter': 'https://cdn.example.com/a.mp4?origin=web',
    'own origin parameter first': 'https://cdn.example.com/a.mp4?origin=web&t=1',
    'name merely starts with origin': 'https://cdn.example.com/a.mp4?originX=1',
  };

  group('proxy round trip', () {
    roundTrips.forEach((name, source) {
      test('survives: $name', () {
        final local = source.toLocalUrl();
        expect(local, contains('${Config.ip}:${Config.port}'), reason: name);
        expect(local.toOriginUrl(), source, reason: name);
      });
    });
  });

  group('toLocalUrl', () {
    test('leaves alone anything uri.origin would throw on', () {
      // `startsWith('http')` is not the same test as "has an origin": it lets
      // through a bare scheme, a missing slash, and http-lookalike schemes.
      // This runs on the playback path, so a throw here is a black screen.
      for (final url in <String>[
        'http',
        'httpfoo',
        'http://',
        'http:relative',
        'http:/path',
        'https:/a.com/v.mp4',
        'httpx://a.com/v.mp4',
      ]) {
        expect(url.toLocalUrl, returnsNormally, reason: url);
        expect(url.toLocalUrl(), url, reason: url);
        expect(url.toLocalUri, returnsNormally, reason: url);
      }
    });

    test('keeps credentials out of the local url', () {
      // They belong to the origin, and toOriginUrl cannot put them back
      // (`uri.origin` drops them), so carrying them over would only leak them
      // into whatever logs the proxy url.
      final local = 'https://user:pw@cdn.example.com/a.mp4?t=1'.toLocalUrl();
      expect(local, isNot(contains('user')));
      expect(local, isNot(contains('pw')));
      expect(local.toOriginUrl(), 'https://cdn.example.com/a.mp4?t=1');
    });

    test('leaves a local url alone', () {
      final local = 'https://cdn.example.com/a.mp4'.toLocalUrl();
      expect(local.toLocalUrl(), local);
    });
  });

  group('toOriginUrl', () {
    test('leaves a plain source url alone', () {
      const source = 'https://cdn.example.com/a.mp4?token=1';
      expect(source.toOriginUrl(), source);
    });

    test('keeps a business origin parameter that is not base64', () {
      const source = 'https://cdn.example.com/own.mp4?origin=web';
      expect(source.toOriginUrl(), source);
      expect(source.toOriginUri().host, 'cdn.example.com');
    });

    test('keeps one that decodes into something that is not a url', () {
      // Valid base64 for "hello". Using it as the base produced a schemeless
      // `/own.mp4` — a url pointing nowhere, which blew up on first request.
      const source = 'https://cdn.example.com/own.mp4?origin=aGVsbG8%3D';
      expect(source.toOriginUrl(), source);
      expect(source.toOriginUri().host, 'cdn.example.com');
    });

    test('keeps an empty one', () {
      const source = 'https://cdn.example.com/own.mp4?origin=';
      expect(source.toOriginUri().host, 'cdn.example.com');
    });

    test('picks our marker out of several origin parameters', () {
      // Right to left, first value that decodes into an absolute url. Ours is
      // appended last, so a business parameter of the same name survives on
      // either side of it.
      const marker = 'origin=aHR0cHM6Ly9jZG4uZXhhbXBsZS5jb20=';

      expect(
        'http://127.0.0.1:20250/a.mp4?origin=web&$marker'.toOriginUrl(),
        'https://cdn.example.com/a.mp4?origin=web',
      );
      expect(
        'http://127.0.0.1:20250/a.mp4?$marker&origin=web'.toOriginUrl(),
        'https://cdn.example.com/a.mp4?origin=web',
      );
    });

    test('rewritten hls segments keep their own parameters', () {
      // modifyM3u8File appends the marker to a relative segment line by hand.
      // A segment that already carries an `origin` parameter used to lose it
      // on the way back, so the request to the CDN went out short one.
      const rewritten = '/hls/seg1.ts?token=abc&origin=web'
          '&origin=aHR0cHM6Ly9jZG4uZXhhbXBsZS5jb20=';
      expect(
        rewritten.toOriginUrl(),
        'https://cdn.example.com/hls/seg1.ts?token=abc&origin=web',
      );
    });

    test('never throws, whatever the url looks like', () {
      for (final url in <String>[
        '  https://cdn.example.com/a.mp4\r',
        '::not a url::',
        'http://127.0.0.1:20250/a.mp4?origin=!!!',
        'http://127.0.0.1:20250/a.mp4?origin',
        '',
      ]) {
        expect(url.toOriginUri, returnsNormally, reason: url);
        expect(url.toOriginUrl, returnsNormally, reason: url);
      }
    });
  });
}
