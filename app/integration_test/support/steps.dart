import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Chờ UI yên; quá 20 giây hoặc có exception thì chụp ảnh `FAIL-<label>` rồi báo đỏ.
Future<void> settle(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String label,
) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
  } catch (_) {
    await binding.takeScreenshot('FAIL-$label');
    rethrow;
  }
  final error = tester.takeException();
  if (error != null) {
    await binding.takeScreenshot('FAIL-$label');
    throw TestFailure('Exception khi dựng "$label": $error');
  }
}

/// Bấm widget có `ValueKey(key)`; cuộn trong [scrollable] nếu chưa được dựng.
Future<void> tapKey(
  WidgetTester tester,
  String key, {
  Finder? scrollable,
}) async {
  final finder = find.byKey(ValueKey(key));
  if (scrollable != null && finder.evaluate().isEmpty) {
    // scrollUntilVisible chỉ cuộn một chiều (xuống) → về đầu danh sách trước,
    // nếu không mục nằm phía trên (vd. Ngôn ngữ sau khi đã cuộn tới Giới thiệu) sẽ không bao giờ thấy.
    await tester.drag(scrollable, const Offset(0, 10000));
    await tester.pumpAndSettle();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
    }
  }
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

/// Bấm nút Back của AppBar. Không dùng `tester.pageBack()`: nó tìm theo tooltip
/// tiếng Anh 'Back', đổi sang tiếng Việt ("Quay lại") là không thấy.
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
}

/// Chờ yên rồi chụp ảnh `<name>.png`.
Future<void> shot(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await settle(tester, binding, name);
  await binding.takeScreenshot(name);
}
