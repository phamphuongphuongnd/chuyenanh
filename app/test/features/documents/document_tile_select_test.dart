import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/features/documents/documents_logic.dart';
import 'package:pdf_office/features/documents/documents_providers.dart';
import 'package:pdf_office/features/documents/widgets/document_tile.dart';

// Đuôi docx: pdfLockedProvider trả false ngay, không đụng đĩa.
final _a = DocItem(
  path: '/fake/a.docx',
  name: 'a.docx',
  ext: 'docx',
  size: 10,
  modified: DateTime(2024, 1, 1),
  folder: 'fake',
);
final _b = DocItem(
  path: '/fake/b.docx',
  name: 'b.docx',
  ext: 'docx',
  size: 10,
  modified: DateTime(2024, 1, 2),
  folder: 'fake',
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  // Stream tự điều khiển thay cho drift: tránh timer treo sau khi cây widget huỷ.
  late StreamController<Set<String>> favs;
  var current = <String>{};

  setUp(() {
    current = {};
    favs = StreamController<Set<String>>();
    addTearDown(favs.close);
  });

  Future<void> setFavs(WidgetTester tester, Set<String> value) async {
    current = value;
    favs.add(value);
    await _settle(tester);
  }

  Future<void> toggle(WidgetTester tester, String path) =>
      setFavs(tester, {...current}..toggle(path));

  Future<void> pumpTiles(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [favoritePathsProvider.overrideWith((ref) => favs.stream)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Column(children: [DocumentTile(_a), DocumentTile(_b)]),
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  // Sao Material Symbols: đã thích = fill 1, chưa thích = fill 0 (cùng một glyph).
  Finder starWithFill(DocItem d, double fill) => find.descendant(
    of: find.byKey(ValueKey(d.path)),
    matching: find.byWidgetPredicate(
      (w) => w is Icon && w.icon == Symbols.star_rounded && w.fill == fill,
    ),
  );
  Finder starOf(DocItem d) => starWithFill(d, 1);
  Finder starBorderOf(DocItem d) => starWithFill(d, 0);

  testWidgets('sao đúng trạng thái theo favoritePathsProvider', (tester) async {
    await pumpTiles(tester);
    await setFavs(tester, {_a.path});

    expect(starOf(_a), findsOneWidget);
    expect(starBorderOf(_a), findsNothing);
    expect(starOf(_b), findsNothing);
    expect(starBorderOf(_b), findsOneWidget);

    // Bật sao b, tắt sao a → giao diện cập nhật theo.
    await setFavs(tester, {_b.path});

    expect(starOf(_a), findsNothing);
    expect(starBorderOf(_a), findsOneWidget);
    expect(starOf(_b), findsOneWidget);
  });

  testWidgets('đổi sao của file khác không dựng lại dòng này', (tester) async {
    await pumpTiles(tester);

    final builds = <String, int>{};
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      final w = element.widget;
      if (w is DocumentTile) {
        builds.update(w.item.path, (n) => n + 1, ifAbsent: () => 1);
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);

    // Bật sao file b: chỉ dòng b được dựng lại, dòng a thì không.
    await toggle(tester, _b.path);

    expect(starOf(_b), findsOneWidget);
    expect(builds[_b.path] ?? 0, greaterThanOrEqualTo(1));
    expect(builds[_a.path] ?? 0, 0);

    // Tắt sao b: dòng a vẫn không dựng lại.
    builds.clear();
    await toggle(tester, _b.path);

    expect(starBorderOf(_b), findsOneWidget);
    expect(builds[_a.path] ?? 0, 0);
  });
}

extension on Set<String> {
  void toggle(String v) {
    if (!remove(v)) add(v);
  }
}
