import 'package:drift/drift.dart';

class Videos extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get md5 => text().withLength(min: 16, max: 32)();

  TextColumn get link => text()();

  TextColumn get file => text()();

  IntColumn get size => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get mimeType => text().withLength(max: 32)();
}
