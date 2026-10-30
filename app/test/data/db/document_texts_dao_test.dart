import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/features/content_index/logic/search_text.dart';

void main() {
  late AppDatabase db;
  late DocumentTextsDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.documentTextsDao;
  });

  tearDown(() => db.close());

  Future<void> put(
    String path,
    String text, {
    int modified = 1,
    int size = 10,
  }) {
    final p = prepareContent(text);
    return dao.upsert(
      DocumentTextsCompanion.insert(
        path: path,
        content: p.content,
        normalized: p.normalized,
        sourceModifiedMs: modified,
        sourceSize: size,
        extractedAtMs: 0,
      ),
    );
  }

  test('DB mới có đủ bảng (cũ + document_texts)', () async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll([
        'documents',
        'favorites',
        'recents',
        'bookmarks',
        'document_texts',
      ]),
    );
    expect(db.schemaVersion, 2);
  });

  test('upsert + getByPath (ghi đè dòng cũ)', () async {
    await put('/a.pdf', 'bản 1');
    await put('/a.pdf', 'Bản 2');
    final row = await dao.getByPath('/a.pdf');
    expect(row?.content, 'Bản 2');
    expect(row?.normalized, 'ban 2');
    expect(await dao.getByPath('/x.pdf'), isNull);
  });

  test('searchPaths: gõ không dấu khớp chữ có dấu', () async {
    await put('/a.pdf', 'HỢP ĐỒNG thuê nhà số 12');
    await put('/b.docx', 'Biên bản họp');
    await put('/c.txt', '');
    expect(await dao.searchPaths(normalizeQuery('hop dong')), ['/a.pdf']);
    expect(await dao.searchPaths(normalizeQuery('Hợp Đồng')), ['/a.pdf']);
    expect((await dao.searchPaths(normalizeQuery('hop'))).toSet(), {
      '/a.pdf',
      '/b.docx',
    });
    expect(await dao.searchPaths(''), isEmpty);
    expect(await dao.searchPaths('khong co'), isEmpty);
  });

  test(
    'searchPaths: % và _ là chữ thường, không phải ký tự đại diện',
    () async {
      await put('/a.txt', 'giảm 50% giá');
      await put('/b.txt', 'giảm 50 lần');
      await put('/c.txt', 'ten_file');
      await put('/d.txt', 'tenxfile');
      expect(await dao.searchPaths('50%'), ['/a.txt']);
      expect(await dao.searchPaths('ten_file'), ['/c.txt']);
      expect(likeContains(r'a%b_c\d'), r'%a\%b\_c\\d%');
    },
  );

  test('searchHits + snippetFor: khúc chữ quanh chỗ khớp', () async {
    final filler = List.generate(30, (i) => 'chu$i').join(' ');
    await put('/a.pdf', '$filler Hợp đồng lao động $filler');
    await put('/b.pdf', 'Hợp đồng ngắn');

    final hits = await dao.searchHits('hop dong');
    expect(hits.map((h) => h.path).toSet(), {'/a.pdf', '/b.pdf'});

    final long = hits.firstWhere((h) => h.path == '/a.pdf');
    expect(long.window, contains('Hợp đồng lao động'));
    expect(long.windowAtStart, isFalse);
    expect(long.windowAtEnd, isFalse);
    final e = buildExcerpt(
      long.window,
      'hop dong',
      atStart: long.windowAtStart,
      atEnd: long.windowAtEnd,
    );
    expect(e.match, 'Hợp đồng');
    expect(e.text.startsWith('…'), isTrue);

    final short = hits.firstWhere((h) => h.path == '/b.pdf');
    expect(short.window, 'Hợp đồng ngắn');
    expect(short.windowAtStart, isTrue);
    expect(short.windowAtEnd, isTrue);

    final one = await dao.snippetFor('/b.pdf', 'ngan');
    expect(one?.window, 'Hợp đồng ngắn');
    expect(await dao.snippetFor('/b.pdf', 'khong co'), isNull);
    expect(await dao.snippetFor('/x.pdf', 'hop'), isNull);
  });

  test('searchHits: emoji (cặp surrogate) không làm lệch vị trí', () async {
    // 100 emoji trước chỗ khớp: khúc chữ bắt đầu giữa dãy emoji.
    await put('/e.txt', '${'😀' * 100} xin chào Hợp đồng nhé');
    final hit = (await dao.searchHits('hop dong')).single;
    expect(hit.window, endsWith('xin chào Hợp đồng nhé'));
    expect(hit.windowAtStart, isFalse);
    final e = buildExcerpt(hit.window, 'hop dong', atStart: false);
    expect(e.match, 'Hợp đồng');
  });

  test('stalePaths: chưa có hoặc đã đổi modified/size', () async {
    await put('/a.pdf', 'x', modified: 5, size: 100);
    await put('/b.pdf', 'x', modified: 5, size: 100);
    final stale = await dao.stalePaths([
      (path: '/a.pdf', modifiedMs: 5, size: 100), // không đổi
      (path: '/b.pdf', modifiedMs: 6, size: 100), // sửa lại
      (path: '/c.pdf', modifiedMs: 1, size: 1), // mới
    ]);
    expect(stale, ['/b.pdf', '/c.pdf']);
  });

  test('deleteExcept xoá dòng của file đã mất', () async {
    await put('/a.pdf', 'x');
    await put('/b.pdf', 'y');
    expect(await dao.deleteExcept({'/a.pdf'}), 1);
    expect(await dao.allPaths(), {'/a.pdf'});
  });

  test('renamePath / forgetPath cập nhật document_texts', () async {
    await put('/a.pdf', 'Hợp đồng');
    await db.renamePath('/a.pdf', '/b.pdf');
    expect(await dao.getByPath('/a.pdf'), isNull);
    expect((await dao.getByPath('/b.pdf'))?.content, 'Hợp đồng');
    await db.forgetPath('/b.pdf');
    expect(await dao.getByPath('/b.pdf'), isNull);
  });
}
