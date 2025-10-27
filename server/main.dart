import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main() async {
  final scriptPath = Platform.script.toFilePath();
  String scriptDir = p.dirname(scriptPath);
  Directory baseDir = Directory(p.join(scriptDir, 'videos'));
  if (!(await baseDir.exists())) {
    print('Error: Base directory does not exist: ${baseDir.path}');
    return;
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  String link = 'http://${server.address.host}:${server.port}/';
  print('Local Server started：$link');

  void m3u8() async {
    await for (HttpRequest request in server) {
      final uriPath = request.uri.path;

      final rel = uriPath.startsWith('/') ? uriPath.substring(1) : uriPath;
      final safePath = p.normalize(p.join(baseDir.path, rel));
      // 403 Forbidden
      if (!p.isWithin(baseDir.path, safePath) &&
          p.normalize(safePath) != p.normalize(baseDir.path)) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..write('403 Forbidden');
        await request.response.close();
        continue;
      }

      if (uriPath == '/' || uriPath == '') {
        String html = '''
<h2>M3U8 Server running</h2>
<p>Visit <a href="/videos/playlist.m3u8">/videos/playlist.m3u8</a></p>
<p>Visit <a href="/videos/segment1.ts">/videos/segment1.ts</a></p>
<p>Visit <a href="/videos/segment2.ts">/videos/segment2.ts</a></p>
<p>Visit <a href="/videos/segment3.ts">/videos/segment3.ts</a></p>
      ''';
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write(html);
        await request.response.close();
        continue;
      }

      File file = File(p.join(baseDir.path, uriPath.split('/').last));
      if (await file.exists()) {
        final ext = p.extension(file.path).toLowerCase();
        if (ext == 'm3u8') {
          request.response.headers.contentType =
              ContentType('application', 'vnd.apple.mpegurl');
        } else if (ext == 'ts') {
          request.response.headers.contentType = ContentType('video', 'mp2t');
        } else {
          request.response.headers.contentType = ContentType.binary;
        }
        try {
          await request.response.addStream(file.openRead());
        } catch (e, st) {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('500 Error reading file: $e\n$st');
        }
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('404 Not Found: $safePath');
      }

      await request.response.close();
    }
  }

  void mp4() async {
    await for (HttpRequest request in server) {
      final uriPath = request.uri.path;

      final rel = uriPath.startsWith('/') ? uriPath.substring(1) : uriPath;
      final safePath = p.normalize(p.join(baseDir.path, rel));
      // 403 Forbidden
      if (!p.isWithin(baseDir.path, safePath) &&
          p.normalize(safePath) != p.normalize(baseDir.path)) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..write('403 Forbidden');
        await request.response.close();
        continue;
      }

      if (uriPath == '/' || uriPath == '') {
        String html = '''
<h2>MP4 Server running</h2>
<p>Visit <a href="/videos/oQAyZf2kpPfAi0oMHEbPmDBjU5NNLHCfeACJft">/videos/oQAyZf2kpPfAi0oMHEbPmDBjU5NNLHCfeACJft</a></p>
      ''';
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write(html);
        await request.response.close();
        continue;
      }

      // File file = File(p.join(baseDir.path, uriPath.split('/').last));
      File file = File(
          p.join(baseDir.path, 'oQAyZf2kpPfAi0oMHEbPmDBjU5NNLHCfeACJft.mp4'));

      if (!(await file.exists())) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('404 Not Found: $safePath');
        await request.response.close();
        continue;
      }

      final fileLength = await file.length();
      request.response.headers.contentType = ContentType('video', 'mp4');

      // 支持 HEAD 请求（只返回文件信息，不发送数据）
      // if (request.method == 'HEAD') {
      //   request.response.headers
      //       .set(HttpHeaders.contentLengthHeader, fileLength);
      //   await request.response.close();
      //   continue;
      // }

      // 检查 Range 请求头
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        try {
          // 解析范围: bytes=start-end
          final parts = rangeHeader.substring(6).split('-');
          final start = int.parse(parts[0]);
          final end = (parts.length > 1 && parts[1].isNotEmpty)
              ? int.parse(parts[1])
              : fileLength - 1;

          if (start >= fileLength || end >= fileLength || start > end) {
            request.response
              ..statusCode = HttpStatus.requestedRangeNotSatisfiable
              ..headers.set('Content-Range', 'bytes */$fileLength');
            await request.response.close();
            continue;
          }

          final contentLength = end - start + 1;

          // 设置分段响应头
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers
            ..set(HttpHeaders.acceptRangesHeader, 'bytes')
            ..set(HttpHeaders.contentLengthHeader, contentLength)
            ..set(HttpHeaders.contentRangeHeader,
                'bytes $start-$end/$fileLength');

          // 按范围读取
          final stream = file.openRead(start, end + 1);
          await request.response.addStream(stream);
          await request.response.close();
          continue;
        } catch (e, st) {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Error processing range: $e\n$st');
          await request.response.close();
          continue;
        }
      }

      // 普通请求：返回整个文件
      request.response.headers
        ..set(HttpHeaders.contentLengthHeader, fileLength)
        ..set(HttpHeaders.acceptRangesHeader, 'bytes');
      try {
        await request.response.addStream(file.openRead());
      } catch (e, st) {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('500 Error reading file: $e\n$st');
      }

      await request.response.close();
    }
  }

  mp4();
}
