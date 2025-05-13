import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_video_caching/cache/lru_cache_singleton.dart';
import 'package:flutter_video_caching/ext/file_ext.dart';
import 'package:flutter_video_caching/ext/int_ext.dart';

class StorageCachePage extends StatefulWidget {
  const StorageCachePage({super.key});

  @override
  State<StorageCachePage> createState() => _StorageCachePageState();
}

class _StorageCachePageState extends State<StorageCachePage> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final cache = LruCacheSingleton().storageMap();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Cache'),
      ),
      body: ListView.builder(
        itemCount: cache.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(cache.keys.elementAt(index)),
            subtitle: Text(
                cache.values.elementAt(index).statSync().size.toMemorySize),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          String path = await FileExt.createCachePath();
          File file = File('$path/$index');
          await file.writeAsBytes(List.filled(10, 0));
          await LruCacheSingleton().storagePut('$path/$index', file);
          index++;
          setState(() {});
        },
      ),
    );
  }
}
