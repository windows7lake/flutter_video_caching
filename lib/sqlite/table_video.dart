import 'package:sqflite/sqflite.dart';

import 'database.dart';

class TableVideo {
  /// 插入数据
  static Future<int> insert(
    String parentUrl,
    String url,
    String file,
    String mimeType,
    int fileSize,
  ) async {
    Database db = await DatabaseHelper().database;
    return await db.insert('videos', {
      'parent_url': parentUrl,
      'url': url,
      'file': file,
      'mime_type': mimeType,
      'file_size': fileSize,
    });
  }

  /// 查询数据
  static Future<InstanceVideo?> queryByUrl(String url) async {
    Database db = await DatabaseHelper().database;
    List<Map<String, dynamic>> maps = await db.query(
      'videos',
      where: 'url = ?',
      whereArgs: [url],
    );
    return maps.isNotEmpty ? InstanceVideo.fromJson(maps.first) : null;
  }

  /// 更新数据
  static Future<int> update(InstanceVideo video) async {
    Database db = await DatabaseHelper().database;
    return await db.update(
      'videos',
      video.toJson(),
      where: 'url = ?',
      whereArgs: [video.url],
    );
  }

  /// 删除数据
  static Future<int> deleteByUrl(String url) async {
    Database db = await DatabaseHelper().database;
    return await db.delete(
      'videos',
      where: 'url = ?',
      whereArgs: [url],
    );
  }
}

class InstanceVideo {
  final int id;
  final String parentUrl;
  final String url;
  final String file;
  final String mimeType;
  final int fileSize;
  final int? createdAt;

  const InstanceVideo({
    required this.id,
    required this.parentUrl,
    required this.url,
    required this.file,
    required this.mimeType,
    required this.fileSize,
    this.createdAt,
  });

  factory InstanceVideo.fromJson(Map<String, dynamic> json) {
    return InstanceVideo(
      id: json['id'],
      parentUrl: json['parent_url'],
      url: json['url'],
      file: json['file'],
      mimeType: json['mime_type'],
      fileSize: json['file_size'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_url': parentUrl,
      'url': url,
      'file': file,
      'mime_type': mimeType,
      'file_size': fileSize,
      'created_at': createdAt,
    };
  }

  @override
  String toString() {
    return (StringBuffer('Video(')
          ..write('id: $id, ')
          ..write('parentUrl: $parentUrl, ')
          ..write('url: $url, ')
          ..write('file: $file, ')
          ..write('mimeType: $mimeType, ')
          ..write('fileSize: $fileSize, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}
