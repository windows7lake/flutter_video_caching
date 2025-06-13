import 'package:flutter_video_caching/flutter_video_caching.dart';

class ResolutionOption {
  final int bitrate;
  final String resolution;
  final String url; // Final usable HLS URL (absolute)
  final String originalUrl; // Original as provided (file:// or relative)

  ResolutionOption({
    required this.bitrate,
    required this.resolution,
    required this.url,
    required this.originalUrl,
  });

  @override
  String toString() {
    return 'ResolutionOption(resolution: $resolution, bitrate: $bitrate, url: $url, originalUrl: $originalUrl)';
  }
}

mixin class M3U8MX {
  Future<List<ResolutionOption>> getResolutionOptions(String videoUrl) async {
    final HlsMasterPlaylist? playlist =
        await VideoCaching.parseHlsMasterPlaylist(videoUrl);

    final Uri baseUri = Uri.parse(videoUrl);

    final baseDir = baseUri.toString().replaceFirst(RegExp(r'/[^/]*$'), '/');

    final resolutionOptions = playlist?.variants.map((e) {
          // Resolution string
          String resolution = 'Unknown';
          if (e.format.width != null && e.format.height != null) {
            resolution = '${e.format.width}x${e.format.height}';
          }

          Uri originalUri = e.url;

          String fileName = originalUri.path;

          // Remove leading slashes if any
          if (fileName.startsWith('/')) {
            fileName = fileName.substring(1);
          }

          // Final absolute HTTP URL
          final fullUrl = '$baseDir$fileName';

          return ResolutionOption(
            bitrate: e.format.bitrate ?? 0,
            resolution: resolution,
            url: fullUrl, // Final usable HTTP URL
            originalUrl: originalUri
                .toString(), //  Playlist original (file:// or relative)
          );
        }).toList() ??
        [];

    return resolutionOptions;
  }
}
