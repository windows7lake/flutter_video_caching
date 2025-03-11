import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'video_table.dart';

part 'database.g.dart';

const dbName = "video_cache";

@DriftDatabase(tables: [Videos])
class MyDatabase extends _$MyDatabase {
  MyDatabase() : super(createDatabaseConnection(dbName));

  @override
  int get schemaVersion => 1;

  static QueryExecutor createDatabaseConnection(String databaseName) {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(join(dbFolder.path, '$databaseName.sqlite'));
      return NativeDatabase(file);
    });
  }
}
