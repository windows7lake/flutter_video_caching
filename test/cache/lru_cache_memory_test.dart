import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_caching/cache/lru_cache_memory.dart';

void main() {
  group('LruCacheMemory', () {
    late LruCacheMemory cache;

    setUp(() {
      cache = LruCacheMemory(10); // 10字节
    });

    test('put and get', () async {
      final key = 'a';
      final value = Uint8List.fromList([1, 2, 3]);
      await cache.put(key, value);
      final result = await cache.get(key);
      expect(result, value);
    });

    test('eviction when over maxSize', () async {
      await cache.put('a', Uint8List.fromList([1, 2, 3, 4, 5]));
      await cache.put('b', Uint8List.fromList([6, 7, 8, 9, 10]));
      // 插入第三个会超出10字节，应该触发淘汰
      await cache.put('c', Uint8List.fromList([11, 12, 13]));
      final a = await cache.get('a');
      final b = await cache.get('b');
      final c = await cache.get('c');
      // 'a' 应该被淘汰
      expect(a, isNull);
      expect(b?.toList(), [6, 7, 8, 9, 10]);
      expect(c?.toList(), [11, 12, 13]);
    });

    test('remove', () async {
      await cache.put('a', Uint8List.fromList([1, 2, 3]));
      final removed = await cache.remove('a');
      expect(removed, isNotNull);
      final result = await cache.get('a');
      expect(result, isNull);
    });

    test('clear', () async {
      await cache.put('a', Uint8List.fromList([1, 2, 3]));
      await cache.put('b', Uint8List.fromList([4, 5, 6]));
      await cache.clear();
      expect(await cache.get('a'), isNull);
      expect(await cache.get('b'), isNull);
    });
  });
}
