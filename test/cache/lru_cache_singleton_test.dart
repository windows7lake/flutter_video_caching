import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_caching/cache/lru_cache_singleton.dart';
import 'package:flutter_video_caching/ext/file_ext.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationCachePath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('LruCacheSingleton integration', () {
    setUp(() async {
      PathProviderPlatform.instance = FakePathProviderPlatform();
    });
    final singleton = LruCacheSingleton();
    test('memory cache put/get/remove/clear', () async {
      final key = 'test_key';
      final value = Uint8List.fromList([1, 2, 3]);
      await singleton.memoryPut(key, value);
      final got = await singleton.memoryGet(key);
      expect(got, value);

      await singleton.memoryRemove(key);
      final got2 = await singleton.memoryGet(key);
      expect(got2, isNull);

      await singleton.memoryPut(key, value);
      await singleton.memoryClear();
      final got3 = await singleton.memoryGet(key);
      expect(got3, isNull);
    });

    test('storage cache put/get/remove/clear', () async {
      final key = 'test_file';
      Directory cacheDir = Directory(await FileExt.createCachePath());
      File file = File('${cacheDir.path}/test_file.txt');
      await file.writeAsBytes([1, 2, 3]);
      await singleton.storagePut(key, file);

      final got = await singleton.storageGet(key);
      expect(got?.toList(), [1, 2, 3]);

      await singleton.storageRemove(key);
      final got2 = await singleton.storageGet(key);
      expect(got2, isNull);

      await file.writeAsBytes([4, 5, 6]);
      await singleton.storagePut(key, file);
      await singleton.storageClear();
      final got3 = await singleton.storageGet(key);
      expect(got3, isNull);
    });
  });
}
