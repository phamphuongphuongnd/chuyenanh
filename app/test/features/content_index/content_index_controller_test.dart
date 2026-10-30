import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/features/content_index/content_index_providers.dart';
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

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StreamController<List<DocItem>> docs;
  late List<String> extracted;
  late ProviderContainer container;

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    db = AppDatabase(NativeDatabase.memory());
    docs = StreamController<List<DocItem>>.broadcast();
    extracted = [];
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        documentsProvider.overrideWith((ref) => docs.stream),
        contentIndexPauseProvider.overrideWithValue(Duration.zero),
        contentExtractorProvider.overrideWithValue((path, ext) async {
          extracted.add(path);
          if (path.contains('locked')) return null; // PDF có mật khẩu
          return prepareContent('Nội dung của $path');
        }),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await docs.close();
    await db.close();
  });

  /// Khởi động bộ lập chỉ mục như `SearchScreen` (`ref.watch`). Phải `listen`, không chỉ
  /// `read`: Riverpod 3 tạm dừng provider không có listener, kéo theo `ref.listen` của nó tới
  /// `documentsProvider` — danh sách tài liệu không bao giờ tới controller.
  /// Subscription đóng theo `container.dispose()`.
  void start() => container.listen(contentIndexProvider, (_, _) {});

  /// Chờ tới khi lập chỉ mục xong (không chạy, done == total).
  Future<ContentIndexState> idle() async {
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final s = container.read(contentIndexProvider);
      if (!s.running && s.total > 0 && s.done == s.total) return s;
    }
    fail('không xong: ${container.read(contentIndexProvider).total}');
  }

  test('chỉ file đọc được, ≤ 50MB; PDF khoá lưu dòng rỗng', () async {
    start();
    docs.add([
      _doc('hop-dong.pdf'),
      _doc('bao-cao.docx'),
      _doc('locked.pdf'),
      _doc('cu.doc'), // đời cũ: bỏ
      _doc('to.pdf', size: 60 * 1024 * 1024), // > 50MB: bỏ
    ]);
    final s = await idle();
    expect(s.total, 3);
    expect(s.done, 3);
    expect(extracted.toSet(), {
      '/storage/hop-dong.pdf',
      '/storage/bao-cao.docx',
      '/storage/locked.pdf',
    });
    final dao = db.documentTextsDao;
    expect(
      (await dao.getByPath('/storage/hop-dong.pdf'))?.content,
      'Nội dung của /storage/hop-dong.pdf',
    );
    expect((await dao.getByPath('/storage/locked.pdf'))?.content, '');
    expect(await dao.searchPaths(normalizeQuery('noi dung')), hasLength(2));
  });

  test('chỉ trích lại file đã đổi; file mất thì xoá chỉ mục', () async {
    start();
    docs.add([_doc('a.pdf'), _doc('b.txt')]);
    await idle();
    extracted.clear();

    docs.add([_doc('a.pdf', modified: 99), _doc('b.txt')]);
    await idle();
    expect(extracted, ['/storage/a.pdf']);

    extracted.clear();
    docs.add([_doc('a.pdf', modified: 99)]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(extracted, isEmpty);
    expect(await db.documentTextsDao.allPaths(), {'/storage/a.pdf'});
  });

  test('app ở nền thì dừng, quay lại thì chạy tiếp', () async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    start();
    docs.add([_doc('a.pdf')]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(extracted, isEmpty);
    final waiting = container.read(contentIndexProvider);
    expect(waiting.isIndexing, isTrue);
    expect((waiting.done, waiting.total), (0, 1));

    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await idle();
    expect(extracted, ['/storage/a.pdf']);
  });
}
