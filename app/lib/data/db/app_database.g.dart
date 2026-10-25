// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, Document> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _extMeta = const VerificationMeta('ext');
  @override
  late final GeneratedColumn<String> ext = GeneratedColumn<String>(
    'ext',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedMsMeta = const VerificationMeta(
    'modifiedMs',
  );
  @override
  late final GeneratedColumn<int> modifiedMs = GeneratedColumn<int>(
    'modified_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderMeta = const VerificationMeta('folder');
  @override
  late final GeneratedColumn<String> folder = GeneratedColumn<String>(
    'folder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scannedAtMsMeta = const VerificationMeta(
    'scannedAtMs',
  );
  @override
  late final GeneratedColumn<int> scannedAtMs = GeneratedColumn<int>(
    'scanned_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    name,
    ext,
    size,
    modifiedMs,
    folder,
    scannedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<Document> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('ext')) {
      context.handle(
        _extMeta,
        ext.isAcceptableOrUnknown(data['ext']!, _extMeta),
      );
    } else if (isInserting) {
      context.missing(_extMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('modified_ms')) {
      context.handle(
        _modifiedMsMeta,
        modifiedMs.isAcceptableOrUnknown(data['modified_ms']!, _modifiedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedMsMeta);
    }
    if (data.containsKey('folder')) {
      context.handle(
        _folderMeta,
        folder.isAcceptableOrUnknown(data['folder']!, _folderMeta),
      );
    } else if (isInserting) {
      context.missing(_folderMeta);
    }
    if (data.containsKey('scanned_at_ms')) {
      context.handle(
        _scannedAtMsMeta,
        scannedAtMs.isAcceptableOrUnknown(
          data['scanned_at_ms']!,
          _scannedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scannedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  Document map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Document(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ext'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      modifiedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_ms'],
      )!,
      folder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder'],
      )!,
      scannedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scanned_at_ms'],
      )!,
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }
}

class Document extends DataClass implements Insertable<Document> {
  final String path;
  final String name;

  /// Đuôi chữ thường, không dấu chấm (`pdf`, `docx`…).
  final String ext;
  final int size;
  final int modifiedMs;

  /// Tên thư mục cha (hiện trong dòng thông tin file).
  final String folder;

  /// Lần quét gần nhất thấy file này (dùng để xoá file đã mất).
  final int scannedAtMs;
  const Document({
    required this.path,
    required this.name,
    required this.ext,
    required this.size,
    required this.modifiedMs,
    required this.folder,
    required this.scannedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['name'] = Variable<String>(name);
    map['ext'] = Variable<String>(ext);
    map['size'] = Variable<int>(size);
    map['modified_ms'] = Variable<int>(modifiedMs);
    map['folder'] = Variable<String>(folder);
    map['scanned_at_ms'] = Variable<int>(scannedAtMs);
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      path: Value(path),
      name: Value(name),
      ext: Value(ext),
      size: Value(size),
      modifiedMs: Value(modifiedMs),
      folder: Value(folder),
      scannedAtMs: Value(scannedAtMs),
    );
  }

  factory Document.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Document(
      path: serializer.fromJson<String>(json['path']),
      name: serializer.fromJson<String>(json['name']),
      ext: serializer.fromJson<String>(json['ext']),
      size: serializer.fromJson<int>(json['size']),
      modifiedMs: serializer.fromJson<int>(json['modifiedMs']),
      folder: serializer.fromJson<String>(json['folder']),
      scannedAtMs: serializer.fromJson<int>(json['scannedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'name': serializer.toJson<String>(name),
      'ext': serializer.toJson<String>(ext),
      'size': serializer.toJson<int>(size),
      'modifiedMs': serializer.toJson<int>(modifiedMs),
      'folder': serializer.toJson<String>(folder),
      'scannedAtMs': serializer.toJson<int>(scannedAtMs),
    };
  }

  Document copyWith({
    String? path,
    String? name,
    String? ext,
    int? size,
    int? modifiedMs,
    String? folder,
    int? scannedAtMs,
  }) => Document(
    path: path ?? this.path,
    name: name ?? this.name,
    ext: ext ?? this.ext,
    size: size ?? this.size,
    modifiedMs: modifiedMs ?? this.modifiedMs,
    folder: folder ?? this.folder,
    scannedAtMs: scannedAtMs ?? this.scannedAtMs,
  );
  Document copyWithCompanion(DocumentsCompanion data) {
    return Document(
      path: data.path.present ? data.path.value : this.path,
      name: data.name.present ? data.name.value : this.name,
      ext: data.ext.present ? data.ext.value : this.ext,
      size: data.size.present ? data.size.value : this.size,
      modifiedMs: data.modifiedMs.present
          ? data.modifiedMs.value
          : this.modifiedMs,
      folder: data.folder.present ? data.folder.value : this.folder,
      scannedAtMs: data.scannedAtMs.present
          ? data.scannedAtMs.value
          : this.scannedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Document(')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('ext: $ext, ')
          ..write('size: $size, ')
          ..write('modifiedMs: $modifiedMs, ')
          ..write('folder: $folder, ')
          ..write('scannedAtMs: $scannedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(path, name, ext, size, modifiedMs, folder, scannedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Document &&
          other.path == this.path &&
          other.name == this.name &&
          other.ext == this.ext &&
          other.size == this.size &&
          other.modifiedMs == this.modifiedMs &&
          other.folder == this.folder &&
          other.scannedAtMs == this.scannedAtMs);
}

class DocumentsCompanion extends UpdateCompanion<Document> {
  final Value<String> path;
  final Value<String> name;
  final Value<String> ext;
  final Value<int> size;
  final Value<int> modifiedMs;
  final Value<String> folder;
  final Value<int> scannedAtMs;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.path = const Value.absent(),
    this.name = const Value.absent(),
    this.ext = const Value.absent(),
    this.size = const Value.absent(),
    this.modifiedMs = const Value.absent(),
    this.folder = const Value.absent(),
    this.scannedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    required String path,
    required String name,
    required String ext,
    required int size,
    required int modifiedMs,
    required String folder,
    required int scannedAtMs,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       name = Value(name),
       ext = Value(ext),
       size = Value(size),
       modifiedMs = Value(modifiedMs),
       folder = Value(folder),
       scannedAtMs = Value(scannedAtMs);
  static Insertable<Document> custom({
    Expression<String>? path,
    Expression<String>? name,
    Expression<String>? ext,
    Expression<int>? size,
    Expression<int>? modifiedMs,
    Expression<String>? folder,
    Expression<int>? scannedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (name != null) 'name': name,
      if (ext != null) 'ext': ext,
      if (size != null) 'size': size,
      if (modifiedMs != null) 'modified_ms': modifiedMs,
      if (folder != null) 'folder': folder,
      if (scannedAtMs != null) 'scanned_at_ms': scannedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith({
    Value<String>? path,
    Value<String>? name,
    Value<String>? ext,
    Value<int>? size,
    Value<int>? modifiedMs,
    Value<String>? folder,
    Value<int>? scannedAtMs,
    Value<int>? rowid,
  }) {
    return DocumentsCompanion(
      path: path ?? this.path,
      name: name ?? this.name,
      ext: ext ?? this.ext,
      size: size ?? this.size,
      modifiedMs: modifiedMs ?? this.modifiedMs,
      folder: folder ?? this.folder,
      scannedAtMs: scannedAtMs ?? this.scannedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ext.present) {
      map['ext'] = Variable<String>(ext.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (modifiedMs.present) {
      map['modified_ms'] = Variable<int>(modifiedMs.value);
    }
    if (folder.present) {
      map['folder'] = Variable<String>(folder.value);
    }
    if (scannedAtMs.present) {
      map['scanned_at_ms'] = Variable<int>(scannedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('ext: $ext, ')
          ..write('size: $size, ')
          ..write('modifiedMs: $modifiedMs, ')
          ..write('folder: $folder, ')
          ..write('scannedAtMs: $scannedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, Favorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMsMeta = const VerificationMeta(
    'addedAtMs',
  );
  @override
  late final GeneratedColumn<int> addedAtMs = GeneratedColumn<int>(
    'added_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, addedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<Favorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('added_at_ms')) {
      context.handle(
        _addedAtMsMeta,
        addedAtMs.isAcceptableOrUnknown(data['added_at_ms']!, _addedAtMsMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  Favorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Favorite(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      addedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at_ms'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class Favorite extends DataClass implements Insertable<Favorite> {
  final String path;
  final int addedAtMs;
  const Favorite({required this.path, required this.addedAtMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['added_at_ms'] = Variable<int>(addedAtMs);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(path: Value(path), addedAtMs: Value(addedAtMs));
  }

  factory Favorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Favorite(
      path: serializer.fromJson<String>(json['path']),
      addedAtMs: serializer.fromJson<int>(json['addedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'addedAtMs': serializer.toJson<int>(addedAtMs),
    };
  }

  Favorite copyWith({String? path, int? addedAtMs}) =>
      Favorite(path: path ?? this.path, addedAtMs: addedAtMs ?? this.addedAtMs);
  Favorite copyWithCompanion(FavoritesCompanion data) {
    return Favorite(
      path: data.path.present ? data.path.value : this.path,
      addedAtMs: data.addedAtMs.present ? data.addedAtMs.value : this.addedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Favorite(')
          ..write('path: $path, ')
          ..write('addedAtMs: $addedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, addedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Favorite &&
          other.path == this.path &&
          other.addedAtMs == this.addedAtMs);
}

class FavoritesCompanion extends UpdateCompanion<Favorite> {
  final Value<String> path;
  final Value<int> addedAtMs;
  final Value<int> rowid;
  const FavoritesCompanion({
    this.path = const Value.absent(),
    this.addedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesCompanion.insert({
    required String path,
    required int addedAtMs,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       addedAtMs = Value(addedAtMs);
  static Insertable<Favorite> custom({
    Expression<String>? path,
    Expression<int>? addedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (addedAtMs != null) 'added_at_ms': addedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesCompanion copyWith({
    Value<String>? path,
    Value<int>? addedAtMs,
    Value<int>? rowid,
  }) {
    return FavoritesCompanion(
      path: path ?? this.path,
      addedAtMs: addedAtMs ?? this.addedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (addedAtMs.present) {
      map['added_at_ms'] = Variable<int>(addedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('path: $path, ')
          ..write('addedAtMs: $addedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecentsTable extends Recents with TableInfo<$RecentsTable, Recent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openedAtMsMeta = const VerificationMeta(
    'openedAtMs',
  );
  @override
  late final GeneratedColumn<int> openedAtMs = GeneratedColumn<int>(
    'opened_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, openedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recents';
  @override
  VerificationContext validateIntegrity(
    Insertable<Recent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('opened_at_ms')) {
      context.handle(
        _openedAtMsMeta,
        openedAtMs.isAcceptableOrUnknown(
          data['opened_at_ms']!,
          _openedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_openedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  Recent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Recent(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      openedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opened_at_ms'],
      )!,
    );
  }

  @override
  $RecentsTable createAlias(String alias) {
    return $RecentsTable(attachedDatabase, alias);
  }
}

class Recent extends DataClass implements Insertable<Recent> {
  final String path;
  final int openedAtMs;
  const Recent({required this.path, required this.openedAtMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['opened_at_ms'] = Variable<int>(openedAtMs);
    return map;
  }

  RecentsCompanion toCompanion(bool nullToAbsent) {
    return RecentsCompanion(path: Value(path), openedAtMs: Value(openedAtMs));
  }

  factory Recent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Recent(
      path: serializer.fromJson<String>(json['path']),
      openedAtMs: serializer.fromJson<int>(json['openedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'openedAtMs': serializer.toJson<int>(openedAtMs),
    };
  }

  Recent copyWith({String? path, int? openedAtMs}) => Recent(
    path: path ?? this.path,
    openedAtMs: openedAtMs ?? this.openedAtMs,
  );
  Recent copyWithCompanion(RecentsCompanion data) {
    return Recent(
      path: data.path.present ? data.path.value : this.path,
      openedAtMs: data.openedAtMs.present
          ? data.openedAtMs.value
          : this.openedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Recent(')
          ..write('path: $path, ')
          ..write('openedAtMs: $openedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, openedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Recent &&
          other.path == this.path &&
          other.openedAtMs == this.openedAtMs);
}

class RecentsCompanion extends UpdateCompanion<Recent> {
  final Value<String> path;
  final Value<int> openedAtMs;
  final Value<int> rowid;
  const RecentsCompanion({
    this.path = const Value.absent(),
    this.openedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentsCompanion.insert({
    required String path,
    required int openedAtMs,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       openedAtMs = Value(openedAtMs);
  static Insertable<Recent> custom({
    Expression<String>? path,
    Expression<int>? openedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (openedAtMs != null) 'opened_at_ms': openedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentsCompanion copyWith({
    Value<String>? path,
    Value<int>? openedAtMs,
    Value<int>? rowid,
  }) {
    return RecentsCompanion(
      path: path ?? this.path,
      openedAtMs: openedAtMs ?? this.openedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (openedAtMs.present) {
      map['opened_at_ms'] = Variable<int>(openedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentsCompanion(')
          ..write('path: $path, ')
          ..write('openedAtMs: $openedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  @override
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, path, page, createdAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
      );
    } else if (isInserting) {
      context.missing(_pageMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final int id;
  final String path;
  final int page;
  final int createdAtMs;
  const Bookmark({
    required this.id,
    required this.path,
    required this.page,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['page'] = Variable<int>(page);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      path: Value(path),
      page: Value(page),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      page: serializer.fromJson<int>(json['page']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'page': serializer.toJson<int>(page),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  Bookmark copyWith({int? id, String? path, int? page, int? createdAtMs}) =>
      Bookmark(
        id: id ?? this.id,
        path: path ?? this.path,
        page: page ?? this.page,
        createdAtMs: createdAtMs ?? this.createdAtMs,
      );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      page: data.page.present ? data.page.value : this.page,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('page: $page, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, page, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.path == this.path &&
          other.page == this.page &&
          other.createdAtMs == this.createdAtMs);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<int> id;
  final Value<String> path;
  final Value<int> page;
  final Value<int> createdAtMs;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.page = const Value.absent(),
    this.createdAtMs = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required int page,
    required int createdAtMs,
  }) : path = Value(path),
       page = Value(page),
       createdAtMs = Value(createdAtMs);
  static Insertable<Bookmark> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<int>? page,
    Expression<int>? createdAtMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (page != null) 'page': page,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<int>? page,
    Value<int>? createdAtMs,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      page: page ?? this.page,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (page.present) {
      map['page'] = Variable<int>(page.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('page: $page, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $RecentsTable recents = $RecentsTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final DocumentsDao documentsDao = DocumentsDao(this as AppDatabase);
  late final FavoritesDao favoritesDao = FavoritesDao(this as AppDatabase);
  late final RecentsDao recentsDao = RecentsDao(this as AppDatabase);
  late final BookmarksDao bookmarksDao = BookmarksDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    documents,
    favorites,
    recents,
    bookmarks,
  ];
}

typedef $$DocumentsTableCreateCompanionBuilder = DocumentsCompanion Function({
  required String path,
  required String name,
  required String ext,
  required int size,
  required int modifiedMs,
  required String folder,
  required int scannedAtMs,
  Value<int> rowid,
});
typedef $$DocumentsTableUpdateCompanionBuilder = DocumentsCompanion Function({
  Value<String> path,
  Value<String> name,
  Value<String> ext,
  Value<int> size,
  Value<int> modifiedMs,
  Value<String> folder,
  Value<int> scannedAtMs,
  Value<int> rowid,
});

class $$DocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifiedMs => $composableBuilder(
    column: $table.modifiedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scannedAtMs => $composableBuilder(
    column: $table.scannedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifiedMs => $composableBuilder(
    column: $table.modifiedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folder => $composableBuilder(
    column: $table.folder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scannedAtMs => $composableBuilder(
    column: $table.scannedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get ext =>
      $composableBuilder(column: $table.ext, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get modifiedMs => $composableBuilder(
    column: $table.modifiedMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<int> get scannedAtMs => $composableBuilder(
    column: $table.scannedAtMs,
    builder: (column) => column,
  );
}

class $$DocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentsTable,
          Document,
          $$DocumentsTableFilterComposer,
          $$DocumentsTableOrderingComposer,
          $$DocumentsTableAnnotationComposer,
          $$DocumentsTableCreateCompanionBuilder,
          $$DocumentsTableUpdateCompanionBuilder,
          (Document, BaseReferences<_$AppDatabase, $DocumentsTable, Document>),
          Document,
          PrefetchHooks Function()
        > {
  $$DocumentsTableTableManager(_$AppDatabase db, $DocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> ext = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> modifiedMs = const Value.absent(),
                Value<String> folder = const Value.absent(),
                Value<int> scannedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion(
                path: path,
                name: name,
                ext: ext,
                size: size,
                modifiedMs: modifiedMs,
                folder: folder,
                scannedAtMs: scannedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String name,
                required String ext,
                required int size,
                required int modifiedMs,
                required String folder,
                required int scannedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion.insert(
                path: path,
                name: name,
                ext: ext,
                size: size,
                modifiedMs: modifiedMs,
                folder: folder,
                scannedAtMs: scannedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DocumentsTable, Document>(table),
                  BaseReferences<_$AppDatabase, $DocumentsTable, Document>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentsTable,
      Document,
      $$DocumentsTableFilterComposer,
      $$DocumentsTableOrderingComposer,
      $$DocumentsTableAnnotationComposer,
      $$DocumentsTableCreateCompanionBuilder,
      $$DocumentsTableUpdateCompanionBuilder,
      (Document, BaseReferences<_$AppDatabase, $DocumentsTable, Document>),
      Document,
      PrefetchHooks Function()
    >;
typedef $$FavoritesTableCreateCompanionBuilder = FavoritesCompanion Function({
  required String path,
  required int addedAtMs,
  Value<int> rowid,
});
typedef $$FavoritesTableUpdateCompanionBuilder = FavoritesCompanion Function({
  Value<String> path,
  Value<int> addedAtMs,
  Value<int> rowid,
});

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAtMs => $composableBuilder(
    column: $table.addedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAtMs => $composableBuilder(
    column: $table.addedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get addedAtMs =>
      $composableBuilder(column: $table.addedAtMs, builder: (column) => column);
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          Favorite,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (Favorite, BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>),
          Favorite,
          PrefetchHooks Function()
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<int> addedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion(
                path: path,
                addedAtMs: addedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required int addedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion.insert(
                path: path,
                addedAtMs: addedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoritesTable, Favorite>(table),
                  BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      Favorite,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (Favorite, BaseReferences<_$AppDatabase, $FavoritesTable, Favorite>),
      Favorite,
      PrefetchHooks Function()
    >;
typedef $$RecentsTableCreateCompanionBuilder = RecentsCompanion Function({
  required String path,
  required int openedAtMs,
  Value<int> rowid,
});
typedef $$RecentsTableUpdateCompanionBuilder = RecentsCompanion Function({
  Value<String> path,
  Value<int> openedAtMs,
  Value<int> rowid,
});

class $$RecentsTableFilterComposer
    extends Composer<_$AppDatabase, $RecentsTable> {
  $$RecentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openedAtMs => $composableBuilder(
    column: $table.openedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecentsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentsTable> {
  $$RecentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openedAtMs => $composableBuilder(
    column: $table.openedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentsTable> {
  $$RecentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get openedAtMs => $composableBuilder(
    column: $table.openedAtMs,
    builder: (column) => column,
  );
}

class $$RecentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecentsTable,
          Recent,
          $$RecentsTableFilterComposer,
          $$RecentsTableOrderingComposer,
          $$RecentsTableAnnotationComposer,
          $$RecentsTableCreateCompanionBuilder,
          $$RecentsTableUpdateCompanionBuilder,
          (Recent, BaseReferences<_$AppDatabase, $RecentsTable, Recent>),
          Recent,
          PrefetchHooks Function()
        > {
  $$RecentsTableTableManager(_$AppDatabase db, $RecentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<int> openedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentsCompanion(
                path: path,
                openedAtMs: openedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required int openedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => RecentsCompanion.insert(
                path: path,
                openedAtMs: openedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecentsTable, Recent>(table),
                  BaseReferences<_$AppDatabase, $RecentsTable, Recent>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecentsTable,
      Recent,
      $$RecentsTableFilterComposer,
      $$RecentsTableOrderingComposer,
      $$RecentsTableAnnotationComposer,
      $$RecentsTableCreateCompanionBuilder,
      $$RecentsTableUpdateCompanionBuilder,
      (Recent, BaseReferences<_$AppDatabase, $RecentsTable, Recent>),
      Recent,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder = BookmarksCompanion Function({
  Value<int> id,
  required String path,
  required int page,
  required int createdAtMs,
});
typedef $$BookmarksTableUpdateCompanionBuilder = BookmarksCompanion Function({
  Value<int> id,
  Value<String> path,
  Value<int> page,
  Value<int> createdAtMs,
});

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
          Bookmark,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> page = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                path: path,
                page: page,
                createdAtMs: createdAtMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required int page,
                required int createdAtMs,
              }) => BookmarksCompanion.insert(
                id: id,
                path: path,
                page: page,
                createdAtMs: createdAtMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookmarksTable, Bookmark>(table),
                  BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark>),
      Bookmark,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$RecentsTableTableManager get recents =>
      $$RecentsTableTableManager(_db, _db.recents);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
}
