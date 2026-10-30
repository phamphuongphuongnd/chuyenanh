// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_texts_dao.dart';

// ignore_for_file: type=lint
mixin _$DocumentTextsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DocumentTextsTable get documentTexts => attachedDatabase.documentTexts;
  DocumentTextsDaoManager get managers => DocumentTextsDaoManager(this);
}

class DocumentTextsDaoManager {
  final _$DocumentTextsDaoMixin _db;
  DocumentTextsDaoManager(this._db);
  $$DocumentTextsTableTableManager get documentTexts =>
      $$DocumentTextsTableTableManager(_db.attachedDatabase, _db.documentTexts);
}
