# flutter_video_caching

[![Pub Version](https://img.shields.io/pub/v/flutter_video_caching)](https://pub.dev/packages/flutter_video_caching) [![Pub Points](https://img.shields.io/pub/points/flutter_video_caching)](https://pub.dev/packages/flutter_video_caching) [![GitHub](https://img.shields.io/badge/github-flutter_video_caching-blue?logo=github)](https://github.com/windows7lake/flutter_video_caching)

`flutter_video_caching` is a powerful Flutter plugin for efficient video caching. 
It supports integration with the `video_player` package and works with popular formats like m3u8 (HLS) and MP4. 
The plugin enables simultaneous playback and caching, as well as pre-caching for smoother user experiences.

## Features

- **Multi-format support:** Works with m3u8 (HLS), MP4, and other common video formats.
- **Memory & file cache:** LRU-based memory cache combined with local file cache to minimize network requests.
- **Pre-caching:** Download video segments in advance to ensure seamless playback.
- **Background downloading:** Uses Isolates for multi-task parallel downloads without blocking the UI.
- **Priority scheduling:** Supports setting download task priorities for optimized resource allocation.
- **Custom headers & cache file names:** Allows custom HTTP headers and cache file naming.
- **Download resume:** Supports automatic resumption of interrupted downloads.

## Support plugin

- [video_player](https://pub.dev/packages/video_player)
- [flick_video_player](https://pub.dev/packages/flick_video_player)
- [pod_player](https://pub.dev/packages/pod_player)
- [flick_video_player](https://pub.dev/packages/flick_video_player)
- [fplayer](https://pub.dev/packages/fplayer)

## Installation

Add the dependency in your `pubspec.yaml`:

```yaml
dependencies:
  flutter_video_caching: ^newest_version
```

Then run:

```sh
flutter pub get
```

## Quick Start

### 1. Initialize the video proxy

```dart
import 'package:flutter_video_caching/flutter_video_caching.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  VideoProxy.init();
  runApp(const HomeApp());
}
```

### 2. Use with `video_player`

```dart
playControl = VideoPlayerController.networkUrl(url.toLocalUri());
```

### 3. Pre-cache a video

```dart
VideoCaching.precache(url);
```

### 4. Preload in `PageView` scenarios

```dart
PageView.builder(
  controller: pageController,
  itemCount: urls.length,
  itemBuilder: (context, index) {
    return VideoPlayerWidget(url: urls[index]);
  },
  onPageChanged: (index) {
    if (index + 1 < urls.length) {
      VideoCaching.precache(urls[index + 1], downloadNow: false);
    }
  },
);
```

### 5. Fallback to original URL if proxy fails

```dart
Future initPlayControl(Uri uri) async {
  playControl = VideoPlayerController.networkUrl(uri.toLocalUri())..setLooping(true);
  playControl.addListener(playListener);
}

void playListener() {
  if (playControl.value.hasError) {
    if (playControl.value.errorDescription?.contains("Source error") ?? false) {
      initPlayControl(uri);
    }
  }
}
```

### 6. Delete cache

```dart
// Remove cache for a single file or the entire directory
LruCacheSingleton().removeCacheByUrl(String url, {bool singleFile = false});
```

### 7. Custom request headers & cache file names

```dart
// Custom header for playback
_controller = VideoPlayerController.networkUrl(uri, httpHeaders: {'Token': 'xxxxxxx'});

// Custom header for pre-caching
VideoCaching.precache(url, headers: {'Token': 'xxxxxxx'});

// Custom cache file name using CUSTOM-CACHE-ID
_controller = VideoPlayerController.networkUrl(uri, httpHeaders: {'CUSTOM-CACHE-ID': 'xxxxxxx'});
VideoCaching.precache(url, headers: {'CUSTOM-CACHE-ID': 'xxxxxxx'});
```

### 8. Custom URL matching

```dart
class UrlMatcherDefault extends UrlMatcher {
  @override
  bool matchM3u8(Uri uri) => uri.path.toLowerCase().endsWith('.m3u8');

  @override
  bool matchM3u8Key(Uri uri) => uri.path.toLowerCase().endsWith('.key');

  @override
  bool matchM3u8Segment(Uri uri) => uri.path.toLowerCase().endsWith('.ts');

  @override
  bool matchMp4(Uri uri) => uri.path.toLowerCase().endsWith('.mp4');

  @override
  Uri matchCacheKey(Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters)
      ..removeWhere((key, _) => key != 'startRange' && key != 'endRange');
    return uri.replace(queryParameters: params.isEmpty ? null : params);
  }
}
```

- Use `UrlMatcher` to distinguish video types.
- **Caching logic:**
  - m3u8: Each segment is cached as a separate file.
  - mp4/others: The file is split into 2MB segments for caching.

### 9. Custom HttpClient

You can customize the HTTP client used for video downloading and caching by implementing the HttpClientBuilder interface. 
This allows you to configure certificate verification, custom headers, or other HTTP behaviors.

Example: Allow Self-Signed Certificates
```dart
class HttpClientCustom extends HttpClientBuilder {
  @override
  HttpClient create() {
    return HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Print certificate info for debugging
        debugPrint('Certificate subject: ${cert.subject}');
        debugPrint('Issuer: ${cert.issuer}');
        debugPrint('Valid until: ${cert.endValidity}');
        debugPrint('SHA-1 fingerprint: ${cert.sha1}');

        // Custom verification logic: here simply allow all certificates, should be stricter in real applications
        // For example, verify if the certificate fingerprint matches the expected value
        return true;
      };
  }
}
```
To use your custom client, pass it to `VideoProxy.init()`.  

> Note: Allowing all certificates is insecure and should only be used for testing. In production, implement strict certificate validation.

## Api

### 1. VideoProxy.init:

```dart
  /// Initializes the video proxy server and related components.
  ///
  /// [ip]: Optional IP address for the proxy server to bind.<br>
  /// [port]: Optional port number for the proxy server to listen on.<br>
  /// [maxMemoryCacheSize]: Maximum memory cache size in MB (default: 100).<br>
  /// [maxStorageCacheSize]: Maximum storage cache size in MB (default: 1024).<br>
  /// [logPrint]: Enables or disables logging output (default: false).<br>
  /// [segmentSize]: Size of each video segment in MB (default: 2).<br>
  /// [maxConcurrentDownloads]: Maximum number of concurrent downloads (default: 8).<br>
  /// [urlMatcher]: Optional custom URL matcher for video URL filtering.<br>
  static Future<void> init({
    String? ip,
    int? port,
    int maxMemoryCacheSize = 100,
    int maxStorageCacheSize = 1024,
    bool logPrint = false,
    int segmentSize = 2,
    int maxConcurrentDownloads = 8,
    UrlMatcher? urlMatcher,
  })
```

### 2. VideoCaching.precache:

```dart
  /// Pre-caches the video at the specified [url].
  ///
  /// [url]: The video URL to be pre-cached.
  /// [headers]: Optional HTTP headers for the request.
  /// [cacheSegments]: Number of segments to cache (default: 2).
  /// [downloadNow]: If true, downloads segments immediately; if false, pushes to the queue (default: true).
  /// [progressListen]: If true, returns a [StreamController] with progress updates (default: false).
  ///
  /// Returns a [StreamController] emitting progress/status updates, or `null` if not listening.
  static Future<StreamController<Map>?> precache(
    String url, {
    Map<String, Object>? headers,
    int cacheSegments = 2,
    bool downloadNow = true,
    bool progressListen = false,
  })
```


## FAQ

### 1. How to set the maximum cache limit?

Set `maxMemoryCacheSize` and `maxStorageCacheSize` in `VideoProxy.init`.

### 2. How to track download progress?

```dart
VideoProxy.downloadManager.stream.listen((Map map) {
});
```
**For .m3u8:** 
```
{
  'progress': 0.0,                // Download progress (0.0 ~ 1.0)
  'segment_url': url,             // Current segment URL being downloaded
  'parent_url': url,              // Main m3u8 playlist URL
  'file_name': '',                // Name of the segment file
  'hls_key': '',                  // The HLS key (generated from the URI) for the download, used to generate the cache directory,
                                  // so that the segments of the same video can be cached in the same directory.
  'total_segments': 0,            // Total number of segments
  'current_segment_index': 0,     // Index of the current segment being downloaded
}
```

**For .mp4:** 

```
{
  'progress': 0,                  // Download progress (0 ~ 100)
  'url': url,                     // MP4 file URL
  'startRange': 0,                // Start byte of the current download range
  'endRange': 0,                  // End byte of the current download range
}
```

### 3. Does the library support download resume?

Yes. Downloaded segments are loaded from local cache, and unfinished segments will resume downloading when playback restarts.

## Contributing

Contributions are welcome! Please submit issues and pull requests.

## License

This project is licensed under the [MIT License](LICENSE).

---

For more detailed API documentation, please refer to the source code [here](https://github.com/windows7lake/flutter_video_caching).