import 'package:drift/drift.dart';

import '../app_database.dart';

part 'documents_dao.g.dart';

@DriftAccessor(tables: [Documents])
class DocumentsDao extends DatabaseAccessor<AppDatabase>
    with _$DocumentsDaoMixin {
  DocumentsDao(super.attachedDatabase);

  /// Mọi tài liệu, mới sửa trước. [exts] lọc theo đuôi (null = tất cả).
  Stream<List<Document>> watchAll({Set<String>? exts}) => _query(exts).watch();

  Future<List<Document>> getAll({Set<String>? exts}) => _query(exts).get();

  SimpleSelectStatement<$DocumentsTable, Document> _query(Set<String>? exts) {
    final q = select(documents);
    if (exts != null) q.where((t) => t.ext.isIn(exts));
    q.orderBy([(t) => OrderingTerm.desc(t.modifiedMs)]);
    return q;
  }

  Future<Document?> getByPath(String path) =>
      (select(documents)..where((t) => t.path.equals(path))).getSingleOrNull();

  Stream<Document?> watchByPath(String path) => (select(
    documents,
  )..where((t) => t.path.equals(path))).watchSingleOrNull();

  Future<void> upsert(DocumentsCompanion row) =>
      into(documents).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<DocumentsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(documents, rows));

  Future<int> deleteByPath(String path) =>
      (delete(documents)..where((t) => t.path.equals(path))).go();

  /// Sau một lượt quét đầy đủ: xoá file không còn thấy (scannedAtMs < [scanStartedMs]).
  Future<int> deleteNotSeenSince(int scanStartedMs) => (delete(
    documents,
  )..where((t) => t.scannedAtMs.isSmallerThanValue(scanStartedMs))).go();

  Future<int> clear() => delete(documents).go();
}
