import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_caching/cache/lru_cache_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LruCacheStorage', () {
    late Directory tempDir;
    late LruCacheStorage cache;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('lru_cache_test');
      cache = LruCacheStorage(1000); // 1000字节
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('put and get file', () async {
      final file = File(p.join(tempDir.path, 'a.txt'));
      await file.writeAsBytes([1, 2, 3]);
      await cache.put('a', file);
      final result = await cache.get('a');
      expect(result, isA<File>());
      expect(await (result as File).readAsBytes(), [1, 2, 3]);
    });

    test('remove file', () async {
      final file = File(p.join(tempDir.path, 'b.txt'));
      await file.writeAsBytes([4, 5, 6]);
      await cache.put('b', file);
      final removed = await cache.remove('b');
      expect(removed, isNotNull);
      final result = await cache.get('b');
      expect(result, isNull);
    });

    test('clear', () async {
      final file1 = File(p.join(tempDir.path, 'c.txt'));
      final file2 = File(p.join(tempDir.path, 'd.txt'));
      await file1.writeAsBytes([7, 8, 9]);
      await file2.writeAsBytes([10, 11, 12]);
      await cache.put('c', file1);
      await cache.put('d', file2);
      await cache.clear();
      expect(await cache.get('c'), isNull);
      expect(await cache.get('d'), isNull);
    });

    test('put waits for eviction before completing', () async {
      cache = LruCacheStorage(5);
      final file1 = File(p.join(tempDir.path, 'e.txt'));
      final file2 = File(p.join(tempDir.path, 'f.txt'));
      await file1.writeAsBytes([1, 2, 3, 4]);
      await file2.writeAsBytes([5, 6, 7, 8]);

      await cache.put('e', file1);
      await cache.put('f', file2);

      expect(cache.size, lessThanOrEqualTo(cache.maxSize));
    });

    test('get prunes missing files and repairs the size ledger', () async {
      final file = File(p.join(tempDir.path, 'g.txt'));
      await file.writeAsBytes([1, 2, 3]);
      await cache.put('g', file);
      await file.delete();

      final result = await cache.get('g');

      expect(result, isNull);
      expect(cache.size, 0);
      expect(cache.map, isEmpty);
      await cache.trimToSize(cache.maxSize);
    });

    test(
      'remove repairs the size ledger when the file was already deleted',
      () async {
        final file = File(p.join(tempDir.path, 'h.txt'));
        await file.writeAsBytes([1, 2, 3]);
        await cache.put('h', file);
        await file.delete();

        final removed = await cache.remove('h');

        expect(removed, isNotNull);
        expect(cache.size, 0);
        expect(cache.map, isEmpty);
        await cache.trimToSize(cache.maxSize);
      },
    );
  });
}
