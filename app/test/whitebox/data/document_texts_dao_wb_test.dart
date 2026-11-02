// Kiểm thử hộp trắng A12 — app/lib/data/db/daos/document_texts_dao.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';

DocumentTextsCompanion _row(
  String path,
  String content, {
  String? normalized,
  int modified = 1,
  int size = 10,
}) => DocumentTextsCompanion.insert(
  path: path,
  content: content,
  normalized: normalized ?? content,
  sourceModifiedMs: modified,
  sourceSize: size,
  extractedAtMs: 0,
);

void main() {
  late AppDatabase db;
  late DocumentTextsDao dao;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.documentTextsDao;
  });
  tearDown(() => db.close());

  group('U1 deleteExcept', () {
    test('U1.1 mọi dòng đều trong keep ⇒ không xoá, trả 0', () async {
      await dao.upsert(_row('/a', 'x'));
      final n = await dao.deleteExcept({'/a', '/z'});
      expect(await dao.allPaths(), {'/a'});
      expect(n, 0);
    });

    test('U1.2 một dòng không còn trong keep ⇒ xoá dòng đó, trả 1', () async {
      await dao.upsert(_row('/a', 'x'));
      await dao.upsert(_row('/b', 'y'));
      final n = await dao.deleteExcept({'/a'});
      expect(await dao.allPaths(), {'/a'});
      expect(n, 1);
    });

    test('U1.3 501 dòng mất ⇒ chia 2 lô (500 + 1), xoá hết, trả 501', () async {
      await db.batch(
        (b) => b.insertAll(db.documentTexts, [
          for (var i = 0; i <= 500; i++) _row('/f$i', 'x'),
        ]),
      );
      await dao.upsert(_row('/keep', 'k'));
      final n = await dao.deleteExcept({'/keep'});
      expect(await dao.allPaths(), {'/keep'});
      expect(n, 501);
    });
  });

  group('U2 stalePaths', () {
    test('U2.1 chưa có / đổi modified / đổi size ⇒ stale; trùng ⇒ không; giữ thứ tự', () async {
      await dao.upsert(_row('/same', 'x', modified: 1, size: 10));
      await dao.upsert(_row('/mod', 'x', modified: 1, size: 10));
      await dao.upsert(_row('/size', 'x', modified: 1, size: 10));
      final stale = await dao.stalePaths([
        (path: '/size', modifiedMs: 1, size: 11),
        (path: '/new', modifiedMs: 5, size: 5),
        (path: '/same', modifiedMs: 1, size: 10),
        (path: '/mod', modifiedMs: 2, size: 10),
      ]);
      expect(stale, ['/size', '/new', '/mod']);
    });

    test('U2.1b không có nguồn nào ⇒ danh sách rỗng', () async {
      await dao.upsert(_row('/a', 'x'));
      expect(await dao.stalePaths(const []), isEmpty);
    });
  });

  group('U3 searchPaths', () {
    setUp(() async {
      await dao.upsert(_row('/p1', 'giam 50% gia'));
      await dao.upsert(_row('/p2', 'giam 500 gia'));
      await dao.upsert(_row('/p3', 'ma a_b'));
      await dao.upsert(_row('/p4', 'ma axb'));
      await dao.upsert(_row('/p5', r'thu muc c\d'));
    });

    test('U3.1 từ khoá có % _ \\ ⇒ khớp đúng chữ (không thành ký tự đại diện); limit', () async {
      expect(await dao.searchPaths('50%'), ['/p1']);
      expect(await dao.searchPaths('a_b'), ['/p3']);
      expect(await dao.searchPaths(r'c\d'), ['/p5']);
      expect((await dao.searchPaths('gia')).toSet(), {'/p1', '/p2'});
      expect(await dao.searchPaths('gia', limit: 1), hasLength(1));
      expect(await dao.searchPaths('khong co'), isEmpty);
    });

    test('U3.2 từ khoá rỗng ⇒ []', () async {
      expect(await dao.searchPaths(''), isEmpty);
    });
  });

  // Nội dung có dấu (cột content) và bản bỏ dấu (cột normalized) cùng độ dài.
  final pre = 'á' * 100;
  final post = 'é' * 100;
  final content = '${pre}Hợp đồng$post';
  final normalized = '${'a' * 100}hop dong${'e' * 100}';

  group('U4 searchHits', () {
    test('U4.1 khớp ⇒ ContentHit có khúc chữ gốc 60 trước + từ khoá + 60 sau', () async {
      await dao.upsert(_row('/long', content, normalized: normalized));
      await dao.upsert(_row('/other', 'khac', normalized: 'khac'));
      final hits = await dao.searchHits('hop dong');
      expect(hits.map((h) => h.path), ['/long']);
      final h = hits.single;
      expect(h.window, content.substring(40, 168));
      expect(h.window, contains('Hợp đồng'));
      expect((h.windowAtStart, h.windowAtEnd), (false, false));
    });

    test('U4.2 từ khoá rỗng ⇒ []', () async {
      await dao.upsert(_row('/long', content, normalized: normalized));
      expect(await dao.searchHits(''), isEmpty);
    });
  });

  group('U5 snippetFor', () {
    setUp(() async {
      await dao.upsert(_row('/long', content, normalized: normalized));
    });

    test('U5.1 file có chữ khớp ⇒ ContentHit của chính file đó', () async {
      final h = await dao.snippetFor('/long', 'hop dong');
      expect(h, isNotNull);
      expect(h!.path, '/long');
      expect(h.window, content.substring(40, 168));
    });

    test('U5.2 từ khoá rỗng ⇒ null', () async {
      expect(await dao.snippetFor('/long', ''), isNull);
    });

    test('U5.3 file không khớp / chưa có chữ ⇒ null', () async {
      expect(await dao.snippetFor('/long', 'khong co'), isNull);
      expect(await dao.snippetFor('/chua-co', 'hop dong'), isNull);
    });
  });

  group('U6 _hit (qua searchHits)', () {
    test('U6.1 chỗ khớp ở đầu (pos ≤ 60) ⇒ window từ đầu nội dung, windowAtStart true', () async {
      final c = 'Hợp đồng ${'c' * 20}';
      await dao.upsert(_row('/short', c, normalized: 'hop dong ${'c' * 20}'));
      final h = (await dao.searchHits('hop dong')).single;
      expect(h.window, c);
      expect((h.windowAtStart, h.windowAtEnd), (true, true));
    });

    test('U6.1b biên: đúng 60 ký tự trước chỗ khớp ⇒ vẫn là đầu nội dung', () async {
      final c = '${'á' * 60}Hợp đồng';
      await dao.upsert(_row('/edge', c, normalized: '${'a' * 60}hop dong'));
      final h = (await dao.searchHits('hop dong')).single;
      expect(h.window, c);
      expect((h.windowAtStart, h.windowAtEnd), (true, true));
    });

    test('U6.2 chỗ khớp xa đầu (pos > 61), chạm cuối ⇒ windowAtStart false, windowAtEnd true', () async {
      final c = '${pre}Hợp đồng';
      await dao.upsert(_row('/tail', c, normalized: '${'a' * 100}hop dong'));
      final h = (await dao.searchHits('hop dong')).single;
      expect(h.window, c.substring(40));
      expect((h.windowAtStart, h.windowAtEnd), (false, true));
    });
  });

  test('U7.1 likeContains thoát % _ \\ và bọc %…%', () {
    expect(likeContains(r'a%b_c\d'), r'%a\%b\_c\\d%');
    expect(likeContains(''), '%%');
    expect(likeContains('hop dong'), '%hop dong%');
  });
}
