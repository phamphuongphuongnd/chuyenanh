// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recents_dao.dart';

// ignore_for_file: type=lint
mixin _$RecentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RecentsTable get recents => attachedDatabase.recents;
  RecentsDaoManager get managers => RecentsDaoManager(this);
}

class RecentsDaoManager {
  final _$RecentsDaoMixin _db;
  RecentsDaoManager(this._db);
  $$RecentsTableTableManager get recents =>
      $$RecentsTableTableManager(_db.attachedDatabase, _db.recents);
}
