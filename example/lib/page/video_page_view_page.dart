import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:video_player/video_player.dart';

class VideoPageViewPage extends StatefulWidget {
  const VideoPageViewPage({super.key});

  @override
  State<VideoPageViewPage> createState() => _VideoPageViewPageState();
}

class _VideoPageViewPageState extends State<VideoPageViewPage> {
  final PageController pageController = PageController();
  final List<String> urls = [
    // 'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341959_IpJiA57x83/full_hls/api_63_1741341959_IpJiA57x83.m3u8',
    // 'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341896_kQMmDNpe31/full_hls/api_63_1741341896_kQMmDNpe31.m3u8',
    // 'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341458_D3zoeHyhsS/full_hls/api_63_1741341458_D3zoeHyhsS.m3u8',
    // 'https://cp4.100.com.tw/short_video/2025/03/07/api_63_1741341240_K8577E4A4v/full_hls/api_63_1741341240_K8577E4A4v.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/19/api_76_1739944065_it2uv2B37X.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740034816_gyJD2rv5iJ.m3u8',
    'https://images.debug.100.com.tw/short_video/2025/03/13/api_76_1741847328_sR96QRx6nz/full_hls/api_76_1741847328_sR96QRx6nz.m3u8',
    'https://images.debug.100.com.tw/short_video/2025/02/25/api_76_1740451086_YfIgNO1nAL/full_hls/api_76_1740451086_YfIgNO1nAL.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740041957_1mWiprwazK.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740043126_wJVXwIEOHh.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740042408_eJf8r036BT.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/20/api_30_1740041707_yOQW9ocCUX.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/18/api_76_1739860463_qHCzRqVkDd.m3u8',
    'https://images.debug.100.com.tw/short_video/hls/2025/02/18/api_76_1739868076_TDqSBrSqQC.m3u8',
    'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH.m3u8',
    'https://t100upload.s3.ap-northeast-1.amazonaws.com/video/hls/2024/12/26/api_1092601_1706519887_yMAyefOAuT.m3u8',
    'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH.m3u8',
    'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH.m3u8',
    'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH.m3u8',
    'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH.m3u8',
    'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH.m3u8',
    'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH.m3u8',
    'https://cp4.100.com.tw/video/hls/2025/01/20/api_1547501_1737362677_2U3MjWuhgH.m3u8',
  ];
  Timer? timer;

  @override
  void initState() {
    super.initState();
    // timer = Timer(const Duration(seconds: 8), () {
    //   for (int i = 1; i < urls.length; i++) {
    //     VideoPreCaching.loadM3u8(urls[i]);
    //   }
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video PageView'),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: pageController,
        // itemCount: controller.showVideoList.length,
        itemBuilder: (context, index) {
          int curIndex = index % urls.length;
          String url = urls[curIndex];
          return VideoPlayerWidget(url: url);
        },
        onPageChanged: (index) {
          VideoProxy.switchTasks();
        },
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    pageController.dispose();
    super.dispose();
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;

  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController playControl;

  bool initialize = false;
  bool showLoading = true;

  void _setShowLoading(bool show) {
    if (showLoading != show) {
      showLoading = show;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    Uri uri = widget.url.toLocalUri();
    // Uri uri = Uri.parse(widget.url);
    initPlayControl(uri);
  }

  Future initPlayControl(Uri uri) async {
    playControl = VideoPlayerController.networkUrl(uri)..setLooping(true);
    playControl.addListener(playListener);
    await playControl.initialize().then((value) {
      initialize = true;
      setState(() {});
      Future.delayed((Duration(milliseconds: 200))).then((value) {
        playControl.play();
      });
    });
  }

  void playListener() {
    print("playControl.value: ${playControl.value}");
    if (playControl.value.hasError) {
      if (playControl.value.errorDescription!.contains("Source error")) {
        Uri uri = Uri.parse(widget.url);
        initPlayControl(uri);
      } else {
        print("${playControl.value.errorDescription}");
      }
      return;
    }
    try {
      if (playControl.value.isInitialized) {
        if (playControl.value.isBuffering && !playControl.value.isPlaying) {
          _setShowLoading(true);
        } else {
          _setShowLoading(false);
        }
      } else {
        _setShowLoading(true);
      }
    } catch (e) {
      _setShowLoading(false);
    } finally {
      setState(() {});
    }
  }

  @override
  void dispose() {
    playControl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return initialize
        ? Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: playControl.value.aspectRatio,
                child: VideoPlayer(playControl),
              ),
              GestureDetector(
                onTap: () {
                  if (playControl.value.isPlaying) {
                    playControl.pause();
                  } else {
                    playControl.play();
                  }
                  setState(() {});
                },
                child: playControl.value.isPlaying
                    ? const Icon(
                        Icons.pause,
                        size: 30,
                        color: Colors.white,
                      )
                    : const Icon(
                        Icons.play_arrow,
                        size: 30,
                        color: Colors.white,
                      ),
              ),
              Positioned.fill(
                top: null,
                bottom: 100,
                child: SizedBox(
                  height: 20,
                  child: VideoProgressIndicator(
                    playControl,
                    allowScrubbing: true,
                    seekCallback: () {
                      VideoProxy.switchTasks();
                    },
                  ),
                ),
              ),
              if (showLoading)
                Positioned.fill(
                  top: null,
                  bottom: 120,
                  child: SizedBox(
                    height: 20,
                    child: const Icon(Icons.refresh),
                  ),
                ),
            ],
          )
        : Container(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () {
                setState(() {});
              },
              child: const Icon(Icons.refresh),
            ),
          );
  }
}

class VideoProgressIndicator extends StatefulWidget {
  const VideoProgressIndicator(
    this.controller, {
    super.key,
    this.colors = const VideoProgressColors(),
    required this.allowScrubbing,
    this.padding = const EdgeInsets.only(top: 5.0),
    this.seekCallback,
  });

  final VideoPlayerController controller;

  final VideoProgressColors colors;

  final bool allowScrubbing;

  final EdgeInsets padding;

  final Function? seekCallback;

  @override
  State<VideoProgressIndicator> createState() => _VideoProgressIndicatorState();
}

class _VideoProgressIndicatorState extends State<VideoProgressIndicator> {
  _VideoProgressIndicatorState() {
    listener = () {
      if (!mounted) {
        return;
      }
      setState(() {});
    };
  }

  late VoidCallback listener;

  VideoPlayerController get controller => widget.controller;

  VideoProgressColors get colors => widget.colors;

  @override
  void initState() {
    super.initState();
    controller.addListener(listener);
  }

  @override
  void deactivate() {
    controller.removeListener(listener);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    Widget progressIndicator;
    if (controller.value.isInitialized) {
      final int duration = controller.value.duration.inMilliseconds;
      final int position = controller.value.position.inMilliseconds;

      int maxBuffering = 0;
      for (final DurationRange range in controller.value.buffered) {
        final int end = range.end.inMilliseconds;
        if (end > maxBuffering) {
          maxBuffering = end;
        }
      }

      progressIndicator = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          LinearProgressIndicator(
            value: maxBuffering / duration,
            valueColor: AlwaysStoppedAnimation<Color>(colors.bufferedColor),
            backgroundColor: colors.backgroundColor,
          ),
          LinearProgressIndicator(
            value: position / duration,
            valueColor: AlwaysStoppedAnimation<Color>(colors.playedColor),
            backgroundColor: Colors.transparent,
          ),
        ],
      );
    } else {
      progressIndicator = LinearProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(colors.playedColor),
        backgroundColor: colors.backgroundColor,
      );
    }
    final Widget paddedProgressIndicator = Padding(
      padding: widget.padding,
      child: progressIndicator,
    );
    if (widget.allowScrubbing) {
      return VideoScrubber(
        seekCallback: widget.seekCallback,
        controller: controller,
        child: paddedProgressIndicator,
      );
    } else {
      return paddedProgressIndicator;
    }
  }
}

/// A scrubber to control [VideoPlayerController]s
class VideoScrubber extends StatefulWidget {
  /// Create a [VideoScrubber] handler with the given [child].
  ///
  /// [controller] is the [VideoPlayerController] that will be controlled by
  /// this scrubber.
  const VideoScrubber({
    super.key,
    required this.child,
    required this.controller,
    this.seekCallback,
  });

  /// The widget that will be displayed inside the gesture detector.
  final Widget child;

  /// The [VideoPlayerController] that will be controlled by this scrubber.
  final VideoPlayerController controller;

  final Function? seekCallback;

  @override
  State<VideoScrubber> createState() => _VideoScrubberState();
}

class _VideoScrubberState extends State<VideoScrubber> {
  bool _controllerWasPlaying = false;

  VideoPlayerController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    void seekToRelativePosition(Offset globalPosition) {
      final RenderBox box = context.findRenderObject()! as RenderBox;
      final Offset tapPos = box.globalToLocal(globalPosition);
      final double relative = tapPos.dx / box.size.width;
      final Duration position = controller.value.duration * relative;
      widget.seekCallback?.call();
      controller.seekTo(position);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: widget.child,
      onHorizontalDragStart: (DragStartDetails details) {
        if (!controller.value.isInitialized) {
          return;
        }
        _controllerWasPlaying = controller.value.isPlaying;
        if (_controllerWasPlaying) {
          controller.pause();
        }
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        if (!controller.value.isInitialized) {
          return;
        }
        seekToRelativePosition(details.globalPosition);
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        if (_controllerWasPlaying &&
            controller.value.position != controller.value.duration) {
          controller.play();
        }
      },
      onTapDown: (TapDownDetails details) {
        if (!controller.value.isInitialized) {
          return;
        }
        seekToRelativePosition(details.globalPosition);
      },
    );
  }
}
