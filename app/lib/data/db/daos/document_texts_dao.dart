import 'package:drift/drift.dart';

import '../app_database.dart';

part 'document_texts_dao.g.dart';

/// Một file khớp từ khoá trong nội dung + khúc chữ quanh chỗ khớp đầu tiên.
class ContentHit {
  const ContentHit({
    required this.path,
    required this.window,
    this.windowAtStart = true,
    this.windowAtEnd = true,
  });

  final String path;

  /// Khúc chữ gốc (từ cột `content`) bao quanh chỗ khớp đầu tiên; UI cắt lại thành đoạn trích.
  final String window;

  /// [window] bắt đầu ngay đầu nội dung (không cần "…" phía trước).
  final bool windowAtStart;

  /// [window] chạm cuối nội dung (không cần "…" phía sau).
  final bool windowAtEnd;
}

/// Dấu vân tay của một file để biết đã trích chữ bản mới nhất chưa.
typedef SourceFingerprint = ({String path, int modifiedMs, int size});

@DriftAccessor(tables: [DocumentTexts])
class DocumentTextsDao extends DatabaseAccessor<AppDatabase>
    with _$DocumentTextsDaoMixin {
  DocumentTextsDao(super.attachedDatabase);

  /// Số ký tự lấy trước chỗ khớp khi cắt [ContentHit.window].
  static const int windowBefore = 60;

  /// Số ký tự lấy sau chỗ khớp (ngoài phần từ khoá).
  static const int windowAfter = 60;

  Future<void> upsert(DocumentTextsCompanion row) =>
      into(documentTexts).insertOnConflictUpdate(row);

  Future<DocumentText?> getByPath(String path) => (select(
    documentTexts,
  )..where((t) => t.path.equals(path))).getSingleOrNull();

  Future<int> deleteByPath(String path) =>
      (delete(documentTexts)..where((t) => t.path.equals(path))).go();

  /// Mọi path đã có dòng (chỉ đọc cột nhỏ, không kéo `content`).
  Future<Set<String>> allPaths() async {
    final q = selectOnly(documentTexts)..addColumns([documentTexts.path]);
    final rows = await q.get();
    return {for (final r in rows) r.read(documentTexts.path)!};
  }

  /// Xoá dòng của file không còn trong [keep] (file đã mất khỏi bảng `documents`).
  Future<int> deleteExcept(Set<String> keep) async {
    final gone = (await allPaths()).difference(keep).toList();
    // Chia lô: SQLite giới hạn số biến trong một câu lệnh.
    for (var i = 0; i < gone.length; i += 500) {
      final chunk = gone.sublist(
        i,
        i + 500 > gone.length ? gone.length : i + 500,
      );
      await (delete(documentTexts)..where((t) => t.path.isIn(chunk))).go();
    }
    return gone.length;
  }

  /// Trong [sources], các file chưa có dòng hoặc đã đổi (modifiedMs/size khác lúc trích).
  /// Giữ nguyên thứ tự của [sources].
  Future<List<String>> stalePaths(Iterable<SourceFingerprint> sources) async {
    final q = selectOnly(documentTexts)
      ..addColumns([
        documentTexts.path,
        documentTexts.sourceModifiedMs,
        documentTexts.sourceSize,
      ]);
    final known = <String, (int, int)>{
      for (final r in await q.get())
        r.read(documentTexts.path)!: (
          r.read(documentTexts.sourceModifiedMs)!,
          r.read(documentTexts.sourceSize)!,
        ),
    };
    return [
      for (final s in sources)
        if (known[s.path] != (s.modifiedMs, s.size)) s.path,
    ];
  }

  /// Path các file có [normalizedQuery] trong cột `normalized` (LIKE `%q%`).
  /// [normalizedQuery] phải đã chuẩn hoá giống cột (chữ thường, bỏ dấu).
  Future<List<String>> searchPaths(
    String normalizedQuery, {
    int limit = 50,
  }) async {
    if (normalizedQuery.isEmpty) return const [];
    final rows = await customSelect(
      r"SELECT path FROM document_texts WHERE normalized LIKE ? ESCAPE '\' "
      'LIMIT ?',
      variables: [
        Variable.withString(likeContains(normalizedQuery)),
        Variable.withInt(limit),
      ],
      readsFrom: {documentTexts},
    ).get();
    return [for (final r in rows) r.read<String>('path')];
  }

  /// Như [searchPaths] nhưng kèm khúc chữ quanh chỗ khớp đầu tiên (cắt ngay trong SQLite,
  /// không kéo cả `content` dài về).
  Future<List<ContentHit>> searchHits(
    String normalizedQuery, {
    int limit = 50,
  }) async {
    if (normalizedQuery.isEmpty) return const [];
    // instr/substr/length của SQLite tính theo ký tự (code point); `normalized` đổi 1:1 với
    // `content` nên vị trí khớp trong `normalized` dùng thẳng được cho `content`.
    final qLen = normalizedQuery.runes.length;
    final rows = await customSelect(
      'SELECT path, instr(normalized, ?) AS pos, length(content) AS len, '
      'substr(content, max(1, instr(normalized, ?) - ?), ?) AS win '
      r"FROM document_texts WHERE normalized LIKE ? ESCAPE '\' LIMIT ?",
      variables: [
        Variable.withString(normalizedQuery),
        Variable.withString(normalizedQuery),
        Variable.withInt(windowBefore),
        Variable.withInt(windowBefore + qLen + windowAfter),
        Variable.withString(likeContains(normalizedQuery)),
        Variable.withInt(limit),
      ],
      readsFrom: {documentTexts},
    ).get();
    return [
      for (final r in rows)
        _hit(
          r.read<String>('path'),
          r.read<int>('pos'),
          r.read<int>('len'),
          r.read<String>('win'),
        ),
    ];
  }

  /// Khúc chữ quanh chỗ khớp đầu tiên của [normalizedQuery] trong file [path];
  /// `null` nếu file chưa có chữ hoặc không khớp.
  Future<ContentHit?> snippetFor(String path, String normalizedQuery) async {
    if (normalizedQuery.isEmpty) return null;
    final qLen = normalizedQuery.runes.length;
    final row = await customSelect(
      'SELECT instr(normalized, ?) AS pos, length(content) AS len, '
      'substr(content, max(1, instr(normalized, ?) - ?), ?) AS win '
      'FROM document_texts WHERE path = ? AND instr(normalized, ?) > 0',
      variables: [
        Variable.withString(normalizedQuery),
        Variable.withString(normalizedQuery),
        Variable.withInt(windowBefore),
        Variable.withInt(windowBefore + qLen + windowAfter),
        Variable.withString(path),
        Variable.withString(normalizedQuery),
      ],
      readsFrom: {documentTexts},
    ).getSingleOrNull();
    if (row == null) return null;
    return _hit(
      path,
      row.read<int>('pos'),
      row.read<int>('len'),
      row.read<String>('win'),
    );
  }

  ContentHit _hit(String path, int pos, int len, String window) {
    final start = pos - windowBefore < 1 ? 1 : pos - windowBefore;
    return ContentHit(
      path: path,
      window: window,
      windowAtStart: start == 1,
      windowAtEnd: start - 1 + window.runes.length >= len,
    );
  }
}

/// Mẫu LIKE `%q%` với `%`, `_`, `\` trong [q] được thoát (dùng cùng `ESCAPE '\'`).
String likeContains(String q) {
  final escaped = q
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
  return '%$escaped%';
}
