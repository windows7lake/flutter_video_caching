// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $VideosTable extends Videos with TableInfo<$VideosTable, Video> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VideosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _md5Meta = const VerificationMeta('md5');
  @override
  late final GeneratedColumn<String> md5 = GeneratedColumn<String>(
      'md5', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 16, maxTextLength: 32),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _linkMeta = const VerificationMeta('link');
  @override
  late final GeneratedColumn<String> link = GeneratedColumn<String>(
      'link', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fileMeta = const VerificationMeta('file');
  @override
  late final GeneratedColumn<String> file = GeneratedColumn<String>(
      'file', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
      'size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _mimeTypeMeta =
      const VerificationMeta('mimeType');
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
      'mime_type', aliasedName, false,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 32),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, md5, link, file, size, createdAt, mimeType];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'videos';
  @override
  VerificationContext validateIntegrity(Insertable<Video> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('md5')) {
      context.handle(
          _md5Meta, md5.isAcceptableOrUnknown(data['md5']!, _md5Meta));
    } else if (isInserting) {
      context.missing(_md5Meta);
    }
    if (data.containsKey('link')) {
      context.handle(
          _linkMeta, link.isAcceptableOrUnknown(data['link']!, _linkMeta));
    } else if (isInserting) {
      context.missing(_linkMeta);
    }
    if (data.containsKey('file')) {
      context.handle(
          _fileMeta, file.isAcceptableOrUnknown(data['file']!, _fileMeta));
    } else if (isInserting) {
      context.missing(_fileMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
          _sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('mime_type')) {
      context.handle(_mimeTypeMeta,
          mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta));
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Video map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Video(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      md5: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}md5'])!,
      link: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}link'])!,
      file: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file'])!,
      size: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      mimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime_type'])!,
    );
  }

  @override
  $VideosTable createAlias(String alias) {
    return $VideosTable(attachedDatabase, alias);
  }
}

class Video extends DataClass implements Insertable<Video> {
  final int id;
  final String md5;
  final String link;
  final String file;
  final int size;
  final DateTime createdAt;
  final String mimeType;
  const Video(
      {required this.id,
      required this.md5,
      required this.link,
      required this.file,
      required this.size,
      required this.createdAt,
      required this.mimeType});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['md5'] = Variable<String>(md5);
    map['link'] = Variable<String>(link);
    map['file'] = Variable<String>(file);
    map['size'] = Variable<int>(size);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['mime_type'] = Variable<String>(mimeType);
    return map;
  }

  VideosCompanion toCompanion(bool nullToAbsent) {
    return VideosCompanion(
      id: Value(id),
      md5: Value(md5),
      link: Value(link),
      file: Value(file),
      size: Value(size),
      createdAt: Value(createdAt),
      mimeType: Value(mimeType),
    );
  }

  factory Video.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Video(
      id: serializer.fromJson<int>(json['id']),
      md5: serializer.fromJson<String>(json['md5']),
      link: serializer.fromJson<String>(json['link']),
      file: serializer.fromJson<String>(json['file']),
      size: serializer.fromJson<int>(json['size']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'md5': serializer.toJson<String>(md5),
      'link': serializer.toJson<String>(link),
      'file': serializer.toJson<String>(file),
      'size': serializer.toJson<int>(size),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'mimeType': serializer.toJson<String>(mimeType),
    };
  }

  Video copyWith(
          {int? id,
          String? md5,
          String? link,
          String? file,
          int? size,
          DateTime? createdAt,
          String? mimeType}) =>
      Video(
        id: id ?? this.id,
        md5: md5 ?? this.md5,
        link: link ?? this.link,
        file: file ?? this.file,
        size: size ?? this.size,
        createdAt: createdAt ?? this.createdAt,
        mimeType: mimeType ?? this.mimeType,
      );
  Video copyWithCompanion(VideosCompanion data) {
    return Video(
      id: data.id.present ? data.id.value : this.id,
      md5: data.md5.present ? data.md5.value : this.md5,
      link: data.link.present ? data.link.value : this.link,
      file: data.file.present ? data.file.value : this.file,
      size: data.size.present ? data.size.value : this.size,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Video(')
          ..write('id: $id, ')
          ..write('md5: $md5, ')
          ..write('link: $link, ')
          ..write('file: $file, ')
          ..write('size: $size, ')
          ..write('createdAt: $createdAt, ')
          ..write('mimeType: $mimeType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, md5, link, file, size, createdAt, mimeType);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Video &&
          other.id == this.id &&
          other.md5 == this.md5 &&
          other.link == this.link &&
          other.file == this.file &&
          other.size == this.size &&
          other.createdAt == this.createdAt &&
          other.mimeType == this.mimeType);
}

class VideosCompanion extends UpdateCompanion<Video> {
  final Value<int> id;
  final Value<String> md5;
  final Value<String> link;
  final Value<String> file;
  final Value<int> size;
  final Value<DateTime> createdAt;
  final Value<String> mimeType;
  const VideosCompanion({
    this.id = const Value.absent(),
    this.md5 = const Value.absent(),
    this.link = const Value.absent(),
    this.file = const Value.absent(),
    this.size = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.mimeType = const Value.absent(),
  });
  VideosCompanion.insert({
    this.id = const Value.absent(),
    required String md5,
    required String link,
    required String file,
    required int size,
    this.createdAt = const Value.absent(),
    required String mimeType,
  })  : md5 = Value(md5),
        link = Value(link),
        file = Value(file),
        size = Value(size),
        mimeType = Value(mimeType);
  static Insertable<Video> custom({
    Expression<int>? id,
    Expression<String>? md5,
    Expression<String>? link,
    Expression<String>? file,
    Expression<int>? size,
    Expression<DateTime>? createdAt,
    Expression<String>? mimeType,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (md5 != null) 'md5': md5,
      if (link != null) 'link': link,
      if (file != null) 'file': file,
      if (size != null) 'size': size,
      if (createdAt != null) 'created_at': createdAt,
      if (mimeType != null) 'mime_type': mimeType,
    });
  }

  VideosCompanion copyWith(
      {Value<int>? id,
      Value<String>? md5,
      Value<String>? link,
      Value<String>? file,
      Value<int>? size,
      Value<DateTime>? createdAt,
      Value<String>? mimeType}) {
    return VideosCompanion(
      id: id ?? this.id,
      md5: md5 ?? this.md5,
      link: link ?? this.link,
      file: file ?? this.file,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (md5.present) {
      map['md5'] = Variable<String>(md5.value);
    }
    if (link.present) {
      map['link'] = Variable<String>(link.value);
    }
    if (file.present) {
      map['file'] = Variable<String>(file.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VideosCompanion(')
          ..write('id: $id, ')
          ..write('md5: $md5, ')
          ..write('link: $link, ')
          ..write('file: $file, ')
          ..write('size: $size, ')
          ..write('createdAt: $createdAt, ')
          ..write('mimeType: $mimeType')
          ..write(')'))
        .toString();
  }
}

abstract class _$MyDatabase extends GeneratedDatabase {
  _$MyDatabase(QueryExecutor e) : super(e);
  $MyDatabaseManager get managers => $MyDatabaseManager(this);
  late final $VideosTable videos = $VideosTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [videos];
}

typedef $$VideosTableCreateCompanionBuilder = VideosCompanion Function({
  Value<int> id,
  required String md5,
  required String link,
  required String file,
  required int size,
  Value<DateTime> createdAt,
  required String mimeType,
});
typedef $$VideosTableUpdateCompanionBuilder = VideosCompanion Function({
  Value<int> id,
  Value<String> md5,
  Value<String> link,
  Value<String> file,
  Value<int> size,
  Value<DateTime> createdAt,
  Value<String> mimeType,
});

class $$VideosTableFilterComposer extends Composer<_$MyDatabase, $VideosTable> {
  $$VideosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get md5 => $composableBuilder(
      column: $table.md5, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get link => $composableBuilder(
      column: $table.link, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get file => $composableBuilder(
      column: $table.file, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnFilters(column));
}

class $$VideosTableOrderingComposer
    extends Composer<_$MyDatabase, $VideosTable> {
  $$VideosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get md5 => $composableBuilder(
      column: $table.md5, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get link => $composableBuilder(
      column: $table.link, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get file => $composableBuilder(
      column: $table.file, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnOrderings(column));
}

class $$VideosTableAnnotationComposer
    extends Composer<_$MyDatabase, $VideosTable> {
  $$VideosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get md5 =>
      $composableBuilder(column: $table.md5, builder: (column) => column);

  GeneratedColumn<String> get link =>
      $composableBuilder(column: $table.link, builder: (column) => column);

  GeneratedColumn<String> get file =>
      $composableBuilder(column: $table.file, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);
}

class $$VideosTableTableManager extends RootTableManager<
    _$MyDatabase,
    $VideosTable,
    Video,
    $$VideosTableFilterComposer,
    $$VideosTableOrderingComposer,
    $$VideosTableAnnotationComposer,
    $$VideosTableCreateCompanionBuilder,
    $$VideosTableUpdateCompanionBuilder,
    (Video, BaseReferences<_$MyDatabase, $VideosTable, Video>),
    Video,
    PrefetchHooks Function()> {
  $$VideosTableTableManager(_$MyDatabase db, $VideosTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VideosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VideosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VideosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> md5 = const Value.absent(),
            Value<String> link = const Value.absent(),
            Value<String> file = const Value.absent(),
            Value<int> size = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> mimeType = const Value.absent(),
          }) =>
              VideosCompanion(
            id: id,
            md5: md5,
            link: link,
            file: file,
            size: size,
            createdAt: createdAt,
            mimeType: mimeType,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String md5,
            required String link,
            required String file,
            required int size,
            Value<DateTime> createdAt = const Value.absent(),
            required String mimeType,
          }) =>
              VideosCompanion.insert(
            id: id,
            md5: md5,
            link: link,
            file: file,
            size: size,
            createdAt: createdAt,
            mimeType: mimeType,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$VideosTableProcessedTableManager = ProcessedTableManager<
    _$MyDatabase,
    $VideosTable,
    Video,
    $$VideosTableFilterComposer,
    $$VideosTableOrderingComposer,
    $$VideosTableAnnotationComposer,
    $$VideosTableCreateCompanionBuilder,
    $$VideosTableUpdateCompanionBuilder,
    (Video, BaseReferences<_$MyDatabase, $VideosTable, Video>),
    Video,
    PrefetchHooks Function()>;

class $MyDatabaseManager {
  final _$MyDatabase _db;
  $MyDatabaseManager(this._db);
  $$VideosTableTableManager get videos =>
      $$VideosTableTableManager(_db, _db.videos);
}
