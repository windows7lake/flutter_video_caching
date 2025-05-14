import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';
import 'package:video_player/video_player.dart';

class VideoPageViewPage extends StatefulWidget {
  const VideoPageViewPage({super.key});

  @override
  State<VideoPageViewPage> createState() => _VideoPageViewPageState();
}

class _VideoPageViewPageState extends State<VideoPageViewPage> {
  final PageController pageController = PageController();
  final List<String> urls = [
    'http://vjs.zencdn.net/v/oceans.mp4',
    'http://mirror.aarnet.edu.au/pub/TED-talks/911Mothers_2010W-480p.mp4',
    'https://test-streams.mux.dev/x36xhzz/url_6/193039199_mp4_h264_aac_hq_7.m3u8',
    'https://www.tootootool.com/wp-content/uploads/2020/11/SampleVideo_1280x720_5mb.mkv',
    'https://www.tootootool.com/wp-content/uploads/2020/11/SampleVideo_176x144_5mb.3gp',
  ];
  Timer? timer;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
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
        itemBuilder: (context, index) {
          int curIndex = index % urls.length;
          String url = urls[curIndex];
          return VideoPlayerWidget(url: url);
        },
        onPageChanged: (index) {
          currentIndex = index;
          if (index + 1 < urls.length) {
            VideoCaching.precache(urls[index + 1], downloadNow: false);
          }
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

  Timer? timer;
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
      timer = Timer(const Duration(milliseconds: 200), () {
        playControl.play();
      });
    });
  }

  void playListener() {
    if (playControl.value.hasError) {
      print("errorDescription: ${playControl.value.errorDescription}");
      if (playControl.value.errorDescription!.contains("Source error")) {
        Uri uri = Uri.parse(widget.url);
        initPlayControl(uri);
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
    timer?.cancel();
    playControl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (initialize) {
      return Stack(
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
                seekCallback: () {},
              ),
            ),
          ),
          if (showLoading)
            Positioned.fill(
              top: null,
              bottom: 350,
              child: SizedBox(
                height: 100,
                width: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      );
    } else {
      return Container(
        alignment: Alignment.center,
        child: TextButton(
          onPressed: () {
            setState(() {});
          },
          child: SizedBox(
            height: 100,
            width: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
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
