import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_video_caching/ext/log_ext.dart';
import 'package:flutter_video_caching/ext/uri_ext.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';
import 'package:flutter_video_caching/global/config.dart';
import 'package:video_player/video_player.dart';

import '../mixin/m3u8_mx.dart';

class PreCacheM3u8Play extends StatefulWidget {
  const PreCacheM3u8Play({super.key});

  @override
  State<PreCacheM3u8Play> createState() => _PreCacheM3u8PlayState();
}

class _PreCacheM3u8PlayState extends State<PreCacheM3u8Play> with M3U8MX {
  String videoUrl =
      'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8';
  late VideoPlayerController _controller;
  String? selectedResolutionUrl;
  List<ResolutionOption> resolutionOptions = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> resolveResolution() async {
    resolutionOptions = await getResolutionOptions(videoUrl);
    logW("resolutionOptions: $resolutionOptions");
  }

  Future<void> _initialize() async {
    try {
      // parse m3u8 file and fetch resolution options
      await resolveResolution();

      // choose the highest resolution by default
      selectedResolutionUrl =
          resolutionOptions.isNotEmpty ? resolutionOptions.first.url : videoUrl;

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(selectedResolutionUrl!.toLocalUrl()),
        httpHeaders: {Config.customCacheId: "custom_cache_id"},
      );

      _controller.initialize();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading video: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _changeResolution(String url) async {
    setState(() {
      isLoading = true;
    });

    final oldController = _controller;
    _controller = VideoPlayerController.networkUrl(
      url.toLocalUri(),
      httpHeaders: {Config.customCacheId: "custom_cache_id"},
    );
    _controller.initialize().then((_) {
      if (oldController.value.isPlaying) {
        _controller.play();
      }
      oldController.dispose();
      setState(() {
        selectedResolutionUrl = url;
        isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-cache M3U8 Video Player'),
      ),
      body: body(),
    );
  }

  Widget body() {
    if (errorMessage.isNotEmpty) {
      return Center(child: Text(errorMessage));
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            });
          },
          child: Text(
            _controller.value.isPlaying ? 'Pause' : 'Play',
          ),
        ),
        // resolution selection dropdown
        if (resolutionOptions.isNotEmpty)
          DropdownButton<String>(
            value: selectedResolutionUrl,
            items: resolutionOptions.map((option) {
              return DropdownMenuItem<String>(
                value: option.url,
                child: Text(
                    '${option.resolution} (${_formatBitrate(option.bitrate)})'),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                _changeResolution(newValue);
              }
            },
          ),
      ],
    );
  }

  String _formatBitrate(int bitrate) {
    if (bitrate < 1000) return '$bitrate bps';
    if (bitrate < 1000000) return '${(bitrate / 1000).toStringAsFixed(1)} Kbps';
    return '${(bitrate / 1000000).toStringAsFixed(1)} Mbps';
  }

  @override
  void dispose() {
    _controller.dispose();
    VideoProxy.downloadManager.removeAllTask();
    super.dispose();
  }
}
