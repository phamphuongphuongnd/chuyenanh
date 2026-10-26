import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/theme/app_colors.dart';
import 'package:pdf_office/features/settings/app_logo.dart';

void main() {
  const res = 'android/app/src/main/res';

  test('màu nền logo trùng màu chủ đạo của app', () {
    expect(AppLogoPainter.background, AppColors.primary);
  });

  testWidgets('AppLogo vẽ đúng kích thước yêu cầu', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: AppLogo(size: 64)),
      ),
    );
    expect(tester.getSize(find.byType(AppLogo)), const Size(64, 64));
  });

  group('adaptive icon Android', () {
    test('ic_launcher.xml có nền, foreground và monochrome', () {
      final xml = File('$res/mipmap-anydpi-v26/ic_launcher.xml');
      expect(xml.existsSync(), isTrue);
      final text = xml.readAsStringSync();
      expect(text, contains('<adaptive-icon'));
      expect(text, contains('@color/ic_launcher_background'));
      expect(text, contains('@drawable/ic_launcher_foreground'));
      expect(text, contains('@drawable/ic_launcher_monochrome'));
    });

    test('nền icon là đỏ #E5393B', () {
      final text = File('$res/values/ic_launcher_background.xml')
          .readAsStringSync();
      expect(text.toUpperCase(), contains('#E5393B'));
    });

    test('foreground và monochrome tồn tại', () {
      expect(
        File('$res/drawable/ic_launcher_foreground.xml').existsSync(),
        isTrue,
      );
      expect(
        File('$res/drawable/ic_launcher_monochrome.xml').existsSync(),
        isTrue,
      );
    });
  });
}
