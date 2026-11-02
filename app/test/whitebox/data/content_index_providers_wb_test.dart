// Kiểm thử hộp trắng A12 — app/lib/features/content_index/content_index_providers.dart
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/features/content_index/content_index_providers.dart';
import 'package:pdf_office/features/content_index/data/text_extractor.dart';
import 'package:pdf_office/features/content_index/logic/search_text.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';

DocItem _doc(String name, {int size = 1000, int modified = 1}) => DocItem(
  path: '/storage/$name',
  name: name,
  ext: name.split('.').last,
  size: size,
  modified: DateTime.fromMillisecondsSinceEpoch(modified),
  folder: 'Download',
);

/// DAO có "cổng" để dừng giữa chừng một lời gọi (đặt dispose / danh sách mới đúng lúc).
class _GatedDao extends DocumentTextsDao {
  _GatedDao(super.attachedDatabase);
  Completer<void>? deleteGate;
  Completer<void>? staleGate;
  Completer<void>? upsertGate;
  int deleteCalls = 0;
  int staleCalls = 0;
  int upsertCalls = 0;

  @override
  Future<int> deleteExcept(Set<String> keep) async {
    deleteCalls++;
    final g = deleteGate;
    deleteGate = null;
    if (g != null) await g.future;
    return super.deleteExcept(keep);
  }

  @override
  Future<List<String>> stalePaths(Iterable<SourceFingerprint> sources) async {
    staleCalls++;
    final list = sources.toList();
    final g = staleGate;
    staleGate = null;
    if (g != null) await g.future;
    return super.stalePaths(list);
  }

  @override
  Future<void> upsert(DocumentTextsCompanion row) async {
    upsertCalls++;
    final g = upsertGate;
    upsertGate = null;
    if (g != null) await g.future;
    return super.upsert(row);
  }
}

class _GatedDb extends AppDatabase {
  _GatedDb() : super(NativeDatabase.memory());
  late final _GatedDao gated = _GatedDao(this);
  @override
  DocumentTextsDao get documentTextsDao => gated;
}

const _order = [
  AppLifecycleState.resumed,
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];

void _goTo(TestWidgetsFlutterBinding b, AppLifecycleState target) {
  final cur = b.lifecycleState;
  if (cur == null || !_order.contains(cur)) {
    b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
  var i = _order.indexOf(b.lifecycleState!);
  final t = _order.indexOf(target);
  while (i != t) {
    i += i < t ? 1 : -1;
    b.handleAppLifecycleStateChanged(_order[i]);
  }
}

Future<void> _until(bool Function() cond, {String what = ''}) async {
  for (var i = 0; i < 400; i++) {
    if (cond()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('hết giờ chờ: $what');
}

Future<void> _settle([int ms = 60]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // Chạy TRƯỚC mọi test khác (chưa ai đặt lifecycle) để có lifecycleState == null.
  test('U4.3 lifecycleState null lúc build ⇒ coi như tiền cảnh, lập chỉ mục chạy', () async {
    final pre = binding.lifecycleState;
    final db = AppDatabase(NativeDatabase.memory());
    final docs = StreamController<List<DocItem>>.broadcast();
    final extracted = <String>[];
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        documentsProvider.overrideWith((ref) => docs.stream),
        contentIndexPauseProvider.overrideWithValue(Duration.zero),
        contentExtractorProvider.overrideWithValue((path, ext) async {
          extracted.add(path);
          return prepareContent('chu');
        }),
      ],
    );
    c.listen(contentIndexProvider, (_, _) {});
    docs.add([_doc('a.pdf')]);
    await _until(() => extracted.isNotEmpty, what: 'trích a.pdf');
    c.dispose();
    await docs.close();
    await db.close();
    // Nhánh đã đi: lifecycle == null (điều kiện dựng).
    expect(pre, isNull);
    expect(extracted, ['/storage/a.pdf']);
  });

  group('content_index_providers', () {
    late _GatedDb db;
    late StreamController<List<DocItem>> docs;
    late List<String> extracted;
    late Future<PreparedText?> Function(String path, String ext) impl;
    late Duration pause;
    late ProviderContainer container;
    late List<ContentIndexState> states;
    var disposed = false;

    ProviderContainer make() {
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          documentsProvider.overrideWith((ref) => docs.stream),
          contentIndexPauseProvider.overrideWithValue(pause),
          contentExtractorProvider.overrideWithValue((path, ext) async {
            extracted.add(path);
            return impl(path, ext);
          }),
        ],
      );
      return c;
    }

    void start() {
      container = make();
      disposed = false;
      container.listen(contentIndexProvider, (_, next) => states.add(next));
    }

    void dispose() {
      if (!disposed) container.dispose();
      disposed = true;
    }

    ContentIndexState now() => container.read(contentIndexProvider);

    Future<void> idle() => _until(() {
      final s = now();
      return !s.running && s.total > 0 && s.done == s.total;
    }, what: 'lập chỉ mục xong');

    setUp(() {
      _goTo(binding, AppLifecycleState.resumed);
      db = _GatedDb();
      docs = StreamController<List<DocItem>>.broadcast();
      extracted = [];
      states = [];
      pause = Duration.zero;
      impl = (path, ext) async => prepareContent('Nội dung của $path');
      disposed = true;
    });

    tearDown(() async {
      dispose();
      await docs.close();
      _goTo(binding, AppLifecycleState.resumed);
      await db.close();
    });

    Future<void> seed(DocItem d) => db.documentTextsDao.upsert(
      DocumentTextsCompanion.insert(
        path: d.path,
        content: 'cu',
        normalized: 'cu',
        sourceModifiedMs: d.modified.millisecondsSinceEpoch,
        sourceSize: d.size,
        extractedAtMs: 0,
      ),
    );

    group('U1 isIndexable', () {
      test('U1.1 PDF 1000 byte ⇒ true; mọi đuôi hỗ trợ ⇒ true', () {
        expect(isIndexable(_doc('a.pdf')), isTrue);
        for (final e in ['docx', 'xlsx', 'pptx', 'txt']) {
          expect(isIndexable(_doc('a.$e')), isTrue, reason: e);
        }
      });
      test('U1.2 đuôi đời cũ .doc ⇒ false', () {
        expect(isIndexable(_doc('a.doc')), isFalse);
      });
      test('U1.3 PDF 60MB ⇒ false; đúng 50MB ⇒ true', () {
        expect(isIndexable(_doc('a.pdf', size: 60 * 1024 * 1024)), isFalse);
        expect(isIndexable(_doc('a.pdf', size: 50 * 1024 * 1024)), isTrue);
        expect(isIndexable(_doc('a.pdf', size: 50 * 1024 * 1024 + 1)), isFalse);
      });
    });

    group('U2 isIndexing', () {
      test('U2.1 đang chạy, còn file ⇒ true', () {
        expect(const ContentIndexState(total: 3, done: 1, running: true).isIndexing, isTrue);
      });
      test('U2.2 không chạy ⇒ false', () {
        expect(const ContentIndexState(total: 3, done: 1).isIndexing, isFalse);
      });
      test('U2.3 chạy nhưng đã đủ ⇒ false', () {
        expect(const ContentIndexState(total: 3, done: 3, running: true).isIndexing, isFalse);
      });
    });

    group('U3 ContentIndexState ==', () {
      const s = ContentIndexState(total: 2, done: 1, running: true);
      test('U3.1 cùng giá trị ⇒ true, cùng hashCode', () {
        const t = ContentIndexState(total: 2, done: 1, running: true);
        expect(s == t, isTrue);
        expect(s.hashCode, t.hashCode);
      });
      test('U3.2 khác kiểu ⇒ false', () => expect(s == Object(), isFalse));
      test('U3.3 khác total ⇒ false', () {
        expect(s == const ContentIndexState(total: 3, done: 1, running: true), isFalse);
      });
      test('U3.4 khác done ⇒ false', () {
        expect(s == const ContentIndexState(total: 2, done: 2, running: true), isFalse);
      });
      test('U3.5 khác running ⇒ false', () {
        expect(s == const ContentIndexState(total: 2, done: 1), isFalse);
      });
    });

    group('U4–U10 build / lifecycle / listen / _wake / _onDocuments / _set', () {
      test('U4.2 app ở nền lúc build ⇒ chờ, chưa trích; U7.1/U8.2 quay lại ⇒ chạy tiếp', () async {
        _goTo(binding, AppLifecycleState.paused);
        start();
        docs.add([_doc('a.pdf')]);
        await _settle();
        expect(extracted, isEmpty);
        expect((now().done, now().total, now().isIndexing), (0, 1, true));
        // U7.2: chuyển giữa các trạng thái nền (không phải resumed) ⇒ vẫn chờ.
        _goTo(binding, AppLifecycleState.hidden);
        await _settle(30);
        expect(extracted, isEmpty);
        _goTo(binding, AppLifecycleState.resumed);
        await idle();
        expect(extracted, ['/storage/a.pdf']);
      });

      test('U4.1 / U6.1 / U9.1 / U10.1 tiền cảnh + danh sách tới ⇒ chạy, cập nhật state', () async {
        start();
        docs.add([_doc('a.pdf'), _doc('cu.doc')]);
        await idle();
        expect(now(), const ContentIndexState(total: 1, done: 1));
        expect(extracted, ['/storage/a.pdf']);
      });

      test('U6.2 documentsProvider còn loading ⇒ không làm gì', () async {
        start();
        await _settle();
        expect(now(), const ContentIndexState());
        expect(extracted, isEmpty);
        expect(db.gated.staleCalls, 0);
      });

      test('U5.1 / U8.1 dispose khi không chờ ⇒ gỡ listener lifecycle, không lỗi', () async {
        start();
        docs.add([_doc('a.pdf')]);
        await idle();
        dispose();
        // Sau dispose, đổi lifecycle không gọi lại vào controller đã huỷ.
        _goTo(binding, AppLifecycleState.paused);
        _goTo(binding, AppLifecycleState.resumed);
        await _settle(20);
        expect(extracted, ['/storage/a.pdf']);
      });

      test('U9.2 danh sách đổi khi đang chạy ⇒ không chạy song song, tính lại hàng đợi', () async {
        final gate = Completer<void>();
        var active = 0;
        var maxActive = 0;
        impl = (path, ext) async {
          active++;
          if (active > maxActive) maxActive = active;
          if (path.endsWith('a.pdf')) await gate.future;
          active--;
          return prepareContent('x $path');
        };
        start();
        docs.add([_doc('a.pdf')]);
        await _until(() => extracted.isNotEmpty, what: 'bắt đầu trích a');
        docs.add([_doc('a.pdf'), _doc('b.txt')]);
        await _settle(20);
        gate.complete();
        await idle();
        expect(extracted, ['/storage/a.pdf', '/storage/b.txt']);
        expect(maxActive, 1);
        expect(now(), const ContentIndexState(total: 2, done: 2));
      });

      test('U10.2 dispose đúng lúc đang upsert ⇒ không đặt state sau dispose, không lỗi', () async {
        db.gated.upsertGate = Completer<void>();
        final gate = db.gated.upsertGate!;
        start();
        docs.add([_doc('a.pdf')]);
        await _until(() => db.gated.upsertCalls == 1, what: 'vào upsert');
        final before = states.length;
        dispose();
        gate.complete();
        await _settle();
        expect(states.length, before);
        expect(await db.documentTextsDao.allPaths(), {'/storage/a.pdf'});
      });
    });

    group('U11 _run', () {
      test('R1 một file cần trích ⇒ dọn, tính hàng đợi, trích, lưu, dừng', () async {
        start();
        docs.add([_doc('a.pdf')]);
        await idle();
        expect(db.gated.deleteCalls, 1);
        expect(extracted, ['/storage/a.pdf']);
        final row = await db.documentTextsDao.getByPath('/storage/a.pdf');
        expect(row?.content, 'Nội dung của /storage/a.pdf');
        expect(row?.normalized, normalizeForSearch('Nội dung của /storage/a.pdf'));
        expect((row?.sourceModifiedMs, row?.sourceSize), (1, 1000));
        expect(now(), const ContentIndexState(total: 1, done: 1));
      });

      test('R2 mọi file đã có chỉ mục mới nhất ⇒ không trích, done = total', () async {
        await seed(_doc('a.pdf'));
        start();
        docs.add([_doc('a.pdf')]);
        await idle();
        expect(extracted, isEmpty);
        expect(now(), const ContentIndexState(total: 1, done: 1));
      });

      test('R3 danh sách đổi đúng lúc vòng lặp sắp thoát ⇒ chạy lại cho danh sách mới', () async {
        await seed(_doc('a.pdf'));
        db.gated.staleGate = Completer<void>();
        final gate = db.gated.staleGate!;
        start();
        docs.add([_doc('a.pdf')]);
        await _until(() => db.gated.staleCalls == 1, what: 'vào stalePaths');
        docs.add([_doc('a.pdf'), _doc('b.txt')]);
        await _settle(20);
        gate.complete();
        await _until(() => extracted.isNotEmpty, what: 'trích b');
        await idle();
        expect(extracted, ['/storage/b.txt']);
        expect(now(), const ContentIndexState(total: 2, done: 2));
      });

      test('R4 danh sách rỗng ⇒ không dọn chỉ mục cũ', () async {
        await seed(_doc('cu.pdf'));
        start();
        docs.add(const []);
        await _until(() => db.gated.staleCalls == 1, what: 'stalePaths');
        await _settle();
        expect(db.gated.deleteCalls, 0);
        expect(await db.documentTextsDao.allPaths(), {'/storage/cu.pdf'});
        expect(now().running, isFalse);
      });

      test('R5 dispose khi đang dọn (deleteExcept) ⇒ dừng, không tính hàng đợi', () async {
        db.gated.deleteGate = Completer<void>();
        final gate = db.gated.deleteGate!;
        start();
        docs.add([_doc('a.pdf')]);
        await _until(() => db.gated.deleteCalls == 1, what: 'vào deleteExcept');
        dispose();
        gate.complete();
        await _settle();
        expect(db.gated.staleCalls, 0);
        expect(extracted, isEmpty);
      });

      test('R6 dispose khi đang tính hàng đợi (stalePaths) ⇒ dừng, không trích', () async {
        db.gated.staleGate = Completer<void>();
        final gate = db.gated.staleGate!;
        start();
        docs.add([_doc('a.pdf')]);
        await _until(() => db.gated.staleCalls == 1, what: 'vào stalePaths');
        dispose();
        gate.complete();
        await _settle();
        expect(extracted, isEmpty);
        expect(db.gated.upsertCalls, 0);
      });

      test('R7 app vào nền giữa chừng ⇒ dừng giữa hai file, quay lại thì tiếp', () async {
        final gate = Completer<void>();
        impl = (path, ext) async {
          if (path.endsWith('a.pdf')) await gate.future;
          return prepareContent('x');
        };
        start();
        docs.add([_doc('a.pdf'), _doc('b.txt')]);
        await _until(() => extracted.length == 1, what: 'trích a');
        _goTo(binding, AppLifecycleState.paused);
        gate.complete();
        await _settle();
        expect(extracted, ['/storage/a.pdf']);
        expect(now().isIndexing, isTrue);
        _goTo(binding, AppLifecycleState.resumed);
        await idle();
        expect(extracted, ['/storage/a.pdf', '/storage/b.txt']);
      });

      test('R8 đang chờ ở nền mà bị dispose ⇒ thoát, không trích', () async {
        _goTo(binding, AppLifecycleState.paused);
        start();
        docs.add([_doc('a.pdf')]);
        await _settle();
        expect(now().isIndexing, isTrue);
        dispose();
        await _settle();
        expect(extracted, isEmpty);
        expect(db.gated.upsertCalls, 0);
      });

      test('R10 dispose khi đang trích ⇒ không lưu kết quả', () async {
        final gate = Completer<void>();
        impl = (path, ext) async {
          await gate.future;
          return prepareContent('x');
        };
        start();
        docs.add([_doc('a.pdf')]);
        await _until(() => extracted.isNotEmpty, what: 'vào extract');
        dispose();
        gate.complete();
        await _settle();
        expect(db.gated.upsertCalls, 0);
      });

      test('R11 trích trả null (PDF khoá / hỏng) ⇒ lưu dòng rỗng', () async {
        impl = (path, ext) async => null;
        start();
        docs.add([_doc('locked.pdf')]);
        await idle();
        final row = await db.documentTextsDao.getByPath('/storage/locked.pdf');
        expect((row?.content, row?.normalized), ('', ''));
        expect(now(), const ContentIndexState(total: 1, done: 1));
      });

      test('R15 hai file, nghỉ 0 ⇒ trích lần lượt, state tiến 0→1→2', () async {
        start();
        docs.add([_doc('a.pdf'), _doc('b.txt')]);
        await idle();
        expect(extracted, ['/storage/a.pdf', '/storage/b.txt']);
        expect(states, contains(const ContentIndexState(total: 2, done: 0, running: true)));
        expect(states, contains(const ContentIndexState(total: 2, done: 1, running: true)));
        expect(states.last, const ContentIndexState(total: 2, done: 2));
      });

      test('R16 hàng đợi hết nhưng danh sách vừa đổi ⇒ vẫn báo đang chạy rồi làm tiếp', () async {
        final gate = Completer<void>();
        impl = (path, ext) async {
          if (path.endsWith('a.pdf')) await gate.future;
          return prepareContent('x');
        };
        start();
        docs.add([_doc('a.pdf')]);
        await _until(() => extracted.isNotEmpty, what: 'vào extract a');
        docs.add([_doc('a.pdf'), _doc('b.txt')]);
        await _settle(20);
        gate.complete();
        await idle();
        expect(states, contains(const ContentIndexState(total: 1, done: 1, running: true)));
        expect(states, isNot(contains(const ContentIndexState(total: 1, done: 1))));
        expect(extracted, ['/storage/a.pdf', '/storage/b.txt']);
      });

      test('R18 nghỉ > 0 giữa hai file ⇒ có khoảng nghỉ', () async {
        pause = const Duration(milliseconds: 80);
        final times = <DateTime>[];
        impl = (path, ext) async {
          times.add(DateTime.now());
          return prepareContent('x');
        };
        start();
        docs.add([_doc('a.pdf'), _doc('b.txt')]);
        await idle();
        expect(times.length, 2);
        expect(times[1].difference(times[0]).inMilliseconds, greaterThanOrEqualTo(70));
      });

      test('R19 dispose trong lúc nghỉ ⇒ dừng, không trích file sau', () async {
        pause = const Duration(milliseconds: 200);
        start();
        docs.add([_doc('a.pdf'), _doc('b.txt')]);
        await _until(() => db.gated.upsertCalls == 1, what: 'lưu a');
        await _settle(20);
        dispose();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(extracted, ['/storage/a.pdf']);
      });

      test('R20 danh sách đổi trong lúc nghỉ ⇒ vòng sau tính lại hàng đợi', () async {
        pause = const Duration(milliseconds: 150);
        start();
        docs.add([_doc('a.pdf'), _doc('b.txt')]);
        await _until(() => db.gated.upsertCalls == 1, what: 'lưu a');
        await _settle(20);
        docs.add([_doc('a.pdf'), _doc('c.docx')]);
        await idle();
        expect(extracted, ['/storage/a.pdf', '/storage/c.docx']);
        expect(await db.documentTextsDao.allPaths(), {'/storage/a.pdf', '/storage/c.docx'});
      });
    });

    group('U12 contentSearchProvider', () {
      late List<String> asked;
      ProviderContainer search() => ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          documentsProvider.overrideWith((ref) => docs.stream),
          contentIndexPauseProvider.overrideWithValue(Duration.zero),
          contentExtractorProvider.overrideWithValue((p, e) async => null),
          contentSearcherProvider.overrideWithValue((q) async {
            asked.add(q);
            return [ContentHit(path: '/storage/$q.pdf', window: q)];
          }),
        ],
      );

      setUp(() => asked = []);

      test('U12.1 từ khoá ≥ 2 ký tự ⇒ gọi tìm nội dung', () async {
        final c = search();
        addTearDown(c.dispose);
        final sub = c.listen(contentSearchProvider('hop'), (_, _) {});
        addTearDown(sub.close);
        final r = await c.read(contentSearchProvider('hop').future);
        expect(asked, contains('hop'));
        expect(r.single.path, '/storage/hop.pdf');
      });

      test('U12.2 từ khoá 1 ký tự ⇒ [] và không gọi tìm', () async {
        final c = search();
        addTearDown(c.dispose);
        final sub = c.listen(contentSearchProvider('h'), (_, _) {});
        addTearDown(sub.close);
        final r = await c.read(contentSearchProvider('h').future);
        expect(asked, isEmpty);
        expect(r, isEmpty);
      });
    });
  });

  test('hằng số dùng trong expected: 50MB', () {
    expect(maxIndexedFileBytes, 50 * 1024 * 1024);
  });
}
