import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf_office/features/reader/widgets/page_indicator_bar.dart';

import 'test_app.dart';

void main() {
  Widget bar({
    int page = 3,
    int pageCount = 25,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    ValueChanged<int>? onJump,
  }) => testApp(
    Scaffold(
      body: const SizedBox(),
      bottomNavigationBar: PageIndicatorBar(
        page: page,
        pageCount: pageCount,
        onPrevious: onPrevious ?? () {},
        onNext: onNext ?? () {},
        onJump: onJump ?? (_) {},
      ),
    ),
  );

  testWidgets('hien "trang / tong so trang"', (t) async {
    await t.pumpWidget(bar());
    expect(find.text('3 / 25'), findsOneWidget);
  });

  testWidgets('nut truoc/sau goi callback, khoa o trang dau/cuoi', (t) async {
    var prev = 0, next = 0;
    await t.pumpWidget(
      bar(page: 1, pageCount: 2, onPrevious: () => prev++, onNext: () => next++),
    );
    // Trang 1: nut truoc bi khoa.
    await t.tap(find.byIcon(Symbols.chevron_left_rounded));
    expect(prev, 0);
    await t.tap(find.byIcon(Symbols.chevron_right_rounded));
    expect(next, 1);

    await t.pumpWidget(
      bar(page: 2, pageCount: 2, onPrevious: () => prev++, onNext: () => next++),
    );
    await t.tap(find.byIcon(Symbols.chevron_right_rounded));
    expect(next, 1);
    await t.tap(find.byIcon(Symbols.chevron_left_rounded));
    expect(prev, 1);
  });

  testWidgets('cham so trang, nhap 7, xac nhan -> onJump(7)', (t) async {
    int? jumped;
    await t.pumpWidget(bar(onJump: (n) => jumped = n));
    await t.tap(find.byKey(const Key('reader_pageIndicator')));
    await t.pumpAndSettle();
    expect(find.text('Go to page'), findsOneWidget);

    await t.enterText(find.byType(TextField), '7');
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(jumped, 7);
    expect(find.text('Go to page'), findsNothing);
  });

  testWidgets('so trang ngoai pham vi -> bao loi, khong dong hop thoai', (t) async {
    int? jumped;
    await t.pumpWidget(bar(onJump: (n) => jumped = n));
    await t.tap(find.byKey(const Key('reader_pageIndicator')));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '26');
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.text('Enter a number from 1 to 25.'), findsOneWidget);
    expect(jumped, isNull);

    await t.enterText(find.byType(TextField), '0');
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.text('Enter a number from 1 to 25.'), findsOneWidget);

    await t.enterText(find.byType(TextField), '25');
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(jumped, 25);
  });

  testWidgets('huy hop thoai -> khong nhay', (t) async {
    int? jumped;
    await t.pumpWidget(bar(onJump: (n) => jumped = n));
    await t.tap(find.byKey(const Key('reader_pageIndicator')));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(jumped, isNull);
  });
}
