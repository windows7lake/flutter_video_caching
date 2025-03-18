import '../ext/url_ext.dart';
import 'database.dart';

final database = MyDatabase();

Future<int> insertVideoToDB(
  String url,
  String path,
  int fileSize,
  String mimeType,
) async {
  return database.into(database.videos).insert(VideosCompanion.insert(
        md5: url.generateMd5,
        link: url,
        file: path,
        size: fileSize,
        mimeType: mimeType,
      ));
}

Future<Video?> selectVideoFromDB(String md5) async {
  List<Video> videos = await (database.select(database.videos)
        ..where((t) => t.md5.equals(md5)))
      .get();
  return videos.firstOrNull;
}
