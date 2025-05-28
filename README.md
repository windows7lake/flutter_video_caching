flutter_video_caching is a powerful flutter plugin for caching video. It can be use with
video_player package. It supports formats like m3u8 and mp4, play and cache videos simultaneously,
precache the video before playing.

## Features

+ `Multi-format support`: supports common video formats such as m3u8 (HLS) and MP4
+ `Memory and file cache`: implements LRU (least recently used) memory cache strategy, combined with
  local file cache to reduce network requests
+ `Pre-caching mechanism`: supports downloading video clips in advance to improve the continuous
  playback experience
+ `Background download`: uses Isolate to achieve multi-task parallel download without blocking UI
  threads
+ `Priority scheduling`: supports setting priorities for download tasks and optimizes resource
  allocation

## Getting started

``` dart
dependencies:
  flutter_video_caching: 0.1.3
```

## Usage

### 1. Init video proxy

``` dart
import 'package:flutter_video_caching/flutter_video_caching.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  VideoProxy.init();
  runApp(const HomeApp());
}
```

#### API: VideoProxy.init():

``` dart
  /// Initialize the video proxy server.
  ///
  /// [ip] is the IP address of the proxy server.
  /// [port] is the port number of the proxy server.
  /// [maxMemoryCacheSize] is the maximum size of the memory cache in MB.
  /// [maxStorageCacheSize] is the maximum size of the storage cache in MB.
  /// [logPrint] is a boolean value to enable or disable logging.
  /// [segmentSize] is the size of each segment in MB.
  /// [maxConcurrentDownloads] is the maximum number of concurrent downloads.
  static Future<void> init({
    String? ip,
    int? port,
    int maxMemoryCacheSize = 100,
    int maxStorageCacheSize = 1024,
    bool logPrint = false,
    int segmentSize = 2,
    int maxConcurrentDownloads = 8,
  })

```


### 2. Use with video_player

``` dart
playControl = VideoPlayerController.networkUrl(url.toLocalUri());
```

### 3. Precache video

``` dart
VideoCaching.precache(url);
```

#### API: VideoCaching.precache:

``` dart
VideoCaching.precache(String url, {
    int cacheSegments = 2,
    bool downloadNow = true,
  })
```

### 4. Use in PageView

``` dart
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

### 5. Revert video uri proxy when proxy server is broken

``` dart
Future initPlayControl(Uri uri) async {
  playControl = VideoPlayerController.networkUrl(uri.toLocalUri())..setLooping(true);
  playControl.addListener(playListener);
}

void playListener() {
  if (playControl.value.hasError) {
    print("errorDescription: ${playControl.value.errorDescription}");
    if (playControl.value.errorDescription!.contains("Source error")) {
      initPlayControl(uri);
    }
  }
}
```

## QA

1. How to set the maximum cache limit?

Answer: 

Memory and file cache: implements LRU (least recently used) memory cache strategy, combined with local file cache to reduce network requests.

```dart
  /// Initialize the video proxy server.
  ///
  /// [ip] is the IP address of the proxy server.
  /// [port] is the port number of the proxy server.
  /// [maxMemoryCacheSize] is the maximum size of the memory cache in MB.
  /// [maxStorageCacheSize] is the maximum size of the storage cache in MB.
  /// [logPrint] is a boolean value to enable or disable logging.
  /// [segmentSize] is the size of each segment in MB.
  /// [maxConcurrentDownloads] is the maximum number of concurrent downloads.
  static Future<void> init({
    String? ip,
    int? port,
    int maxMemoryCacheSize = 100,
    int maxStorageCacheSize = 1024,
    bool logPrint = false,
    int segmentSize = 2,
    int maxConcurrentDownloads = 8,
  })
```

2. How to track download progress in video?

Answer: <br>
```dart
VideoProxy.downloadManager.stream.listen((task) {
      print('${task.uri}, ${task.progress}, ${task.downloadedBytes}, ${task.totalBytes}');
});
```
The code show above, can track download progress for each segments of hls format, but no whole video link.<br>
For m3u8, it track progress on each ts file. For mp4, it track progress on splite segment.<br>
Currently, the function of tracking the download progress of the entire video has not been developed.<br>

3. Does this library handle download resume case?

Answer: <br>
For e.g.: user download https://example.ts file, assume it has more than 50ts file (segment).<br>
Use Case: user download the hls video, out of 50, 10ts file was downloaded, during downloading other ts files, user terminate the app.<br>
When user replay the video, the downloaad task will be continue, and 10ts file will be loaded from file system, then continue to download rest 40ts file.<br>

