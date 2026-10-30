import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/theme/app_theme.dart';
import 'package:pdf_office/data/db/app_database.dart';
import 'package:pdf_office/data/settings/settings_providers.dart';
import 'package:pdf_office/features/content_index/content_index_providers.dart';
import 'package:pdf_office/features/content_index/logic/search_text.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';
import 'package:pdf_office/features/documents/list_screens.dart';
import 'package:pdf_office/features/documents/widgets/document_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FixedIndex extends ContentIndexController {
  _FixedIndex(this.fixed);
  final ContentIndexState fixed;

  @override
  ContentIndexState build() => fixed;
}

DocItem _doc(String name) => DocItem(
  path: '/storage/$name',
  name: name,
  ext: name.split('.').last,
  size: 1000,
  modified: DateTime(2026, 1, 2, 3, 4),
  folder: 'Download',
);

final _docs = [
  _doc('Hợp đồng thuê.docx'),
  _doc('Bao cao.docx'),
  _doc('Ghi chu.txt'),
  _doc('Anh.docx'),
];

Future<List<String>> _pump(
  WidgetTester tester, {
  ContentIndexState index = const ContentIndexState(total: 4, done: 4),
  Map<String, String> contents = const {},
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final queries = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        documentsProvider.overrideWith((ref) => Stream.value(_docs)),
        favoritePathsProvider.overrideWith((ref) => Stream.value(<String>{})),
        contentIndexProvider.overrideWith(() => _FixedIndex(index)),
        contentSearcherProvider.overrideWithValue((q) async {
          queries.add(q);
          return [
            for (final e in contents.entries)
              if (normalizeForSearch(e.value).contains(q))
                ContentHit(path: e.key, window: e.value),
          ];
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const SearchScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return queries;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('search-field')), text);
  await tester.pump(const Duration(milliseconds: 250)); // hết debounce
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('chưa gõ: hiện mọi tài liệu như cũ', (tester) async {
    await _pump(tester);
    expect(find.byType(DocumentTile), findsNWidgets(_docs.length));
    expect(find.byKey(const ValueKey('search-group-content')), findsNothing);
  });

  testWidgets('lọc theo tên như cũ + gõ không dấu vẫn khớp tên có dấu', (
    tester,
  ) async {
    await _pump(tester);
    await _type(tester, 'bao');
    expect(find.text('Bao cao.docx'), findsOneWidget);
    expect(find.text('Ghi chu.txt'), findsNothing);

    await _type(tester, 'hop dong');
    expect(find.text('Hợp đồng thuê.docx'), findsOneWidget);
    expect(find.byType(DocumentTile), findsOneWidget);
  });

  testWidgets(
    'nhóm "Trong nội dung": không trùng file khớp tên, đoạn trích tô đậm',
    (tester) async {
      final queries = await _pump(
        tester,
        contents: {
          // Khớp cả tên lẫn nội dung → chỉ ở nhóm tên.
          '/storage/Hợp đồng thuê.docx': 'hợp đồng thuê nhà',
          '/storage/Ghi chu.txt': 'Nhắc ký Hợp đồng với khách',
          // File không còn trong danh sách → bỏ.
          '/storage/da-xoa.pdf': 'hợp đồng cũ',
        },
      );
      await _type(tester, 'Hop  Dong');
      expect(queries.last, 'hop dong');

      expect(find.text('Theo tên'), findsOneWidget);
      expect(find.text('Trong nội dung'), findsOneWidget);
      expect(find.text('Hợp đồng thuê.docx'), findsOneWidget);
      expect(find.text('Ghi chu.txt'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('content-hit-/storage/Ghi chu.txt')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('content-hit-/storage/Hợp đồng thuê.docx')),
        findsNothing,
      );

      final excerpt = tester.widget<Text>(
        find.byKey(const ValueKey('content-hit-excerpt')),
      );
      final spans = (excerpt.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans.map((s) => s.text).join(), 'Nhắc ký Hợp đồng với khách');
      final bold = spans.singleWhere(
        (s) => s.style?.fontWeight == FontWeight.w700,
      );
      expect(bold.text, 'Hợp đồng');
    },
  );

  testWidgets(
    'chỉ khớp nội dung: có nhóm nội dung, không có tiêu đề "Theo tên"',
    (tester) async {
      await _pump(
        tester,
        contents: {'/storage/Anh.docx': 'Biên bản nghiệm thu'},
      );
      await _type(tester, 'nghiem thu');
      expect(find.text('Theo tên'), findsNothing);
      expect(find.text('Trong nội dung'), findsOneWidget);
      expect(find.text('Anh.docx'), findsOneWidget);
    },
  );

  testWidgets('đang lập chỉ mục: hiện dòng trạng thái n/m', (tester) async {
    await _pump(
      tester,
      index: const ContentIndexState(total: 10, done: 3, running: true),
    );
    await _type(tester, 'bao');
    expect(find.byKey(const ValueKey('content-index-status')), findsOneWidget);
    expect(find.text('Đang lập chỉ mục 3/10 file'), findsOneWidget);

    // Không có kết quả nào: trạng thái hiện trong khối trống.
    await _type(tester, 'zzzz');
    expect(find.text('Không có file phù hợp'), findsOneWidget);
    expect(find.text('Đang lập chỉ mục 3/10 file'), findsOneWidget);
  });
}
