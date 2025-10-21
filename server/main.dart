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
  print('Local M3U8 Server started：$link');

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
