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
  flutter_video_caching: 0.1.1
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

### 2. Use with video_player

``` dart
playControl = VideoPlayerController.networkUrl(url.toLocalUri());
```

### 3. Precache video

``` dart
VideoCaching.precache(url);
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
