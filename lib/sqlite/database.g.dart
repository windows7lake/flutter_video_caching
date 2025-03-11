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
  @override
  List<GeneratedColumn> get $columns => [id, md5, link, file];
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
  const Video(
      {required this.id,
      required this.md5,
      required this.link,
      required this.file});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['md5'] = Variable<String>(md5);
    map['link'] = Variable<String>(link);
    map['file'] = Variable<String>(file);
    return map;
  }

  VideosCompanion toCompanion(bool nullToAbsent) {
    return VideosCompanion(
      id: Value(id),
      md5: Value(md5),
      link: Value(link),
      file: Value(file),
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
    };
  }

  Video copyWith({int? id, String? md5, String? link, String? file}) => Video(
        id: id ?? this.id,
        md5: md5 ?? this.md5,
        link: link ?? this.link,
        file: file ?? this.file,
      );
  Video copyWithCompanion(VideosCompanion data) {
    return Video(
      id: data.id.present ? data.id.value : this.id,
      md5: data.md5.present ? data.md5.value : this.md5,
      link: data.link.present ? data.link.value : this.link,
      file: data.file.present ? data.file.value : this.file,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Video(')
          ..write('id: $id, ')
          ..write('md5: $md5, ')
          ..write('link: $link, ')
          ..write('file: $file')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, md5, link, file);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Video &&
          other.id == this.id &&
          other.md5 == this.md5 &&
          other.link == this.link &&
          other.file == this.file);
}

class VideosCompanion extends UpdateCompanion<Video> {
  final Value<int> id;
  final Value<String> md5;
  final Value<String> link;
  final Value<String> file;
  const VideosCompanion({
    this.id = const Value.absent(),
    this.md5 = const Value.absent(),
    this.link = const Value.absent(),
    this.file = const Value.absent(),
  });
  VideosCompanion.insert({
    this.id = const Value.absent(),
    required String md5,
    required String link,
    required String file,
  })  : md5 = Value(md5),
        link = Value(link),
        file = Value(file);
  static Insertable<Video> custom({
    Expression<int>? id,
    Expression<String>? md5,
    Expression<String>? link,
    Expression<String>? file,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (md5 != null) 'md5': md5,
      if (link != null) 'link': link,
      if (file != null) 'file': file,
    });
  }

  VideosCompanion copyWith(
      {Value<int>? id,
      Value<String>? md5,
      Value<String>? link,
      Value<String>? file}) {
    return VideosCompanion(
      id: id ?? this.id,
      md5: md5 ?? this.md5,
      link: link ?? this.link,
      file: file ?? this.file,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VideosCompanion(')
          ..write('id: $id, ')
          ..write('md5: $md5, ')
          ..write('link: $link, ')
          ..write('file: $file')
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
});
typedef $$VideosTableUpdateCompanionBuilder = VideosCompanion Function({
  Value<int> id,
  Value<String> md5,
  Value<String> link,
  Value<String> file,
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
          }) =>
              VideosCompanion(
            id: id,
            md5: md5,
            link: link,
            file: file,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String md5,
            required String link,
            required String file,
          }) =>
              VideosCompanion.insert(
            id: id,
            md5: md5,
            link: link,
            file: file,
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
