flutter_video_cache is a Flutter plugin for caching video.

## Features
* support m3u8

## Getting started
``` dart
dependencies:
  flutter_video_cache:
    git:
      url: https://github.com/windows7lake/flutter_video_cache.git
```

## Usage

### 1. Init video proxy
``` dart
import 'package:flutter_video_cache/flutter_video_cache.dart';

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
VideoPreCaching.loadM3u8(url);
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
      VideoPreCaching.loadM3u8(urls[index + 1], downloadNow: false);
    }
  },
);
```