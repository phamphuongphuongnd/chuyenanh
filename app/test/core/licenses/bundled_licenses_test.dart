import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/licenses/bundled_licenses.dart';

void main() {
  testWidgets('khai giấy phép font và uCrop cho trang giấy phép', (tester) async {
    registerBundledLicenses();

    final entries = (await tester.runAsync(() => LicenseRegistry.licenses.toList()))!;
    final packages = {for (final e in entries) ...e.packages};

    expect(packages, containsAll(['Be Vietnam Pro', 'Noto Sans', 'uCrop']));

    final ucrop = entries.firstWhere((e) => e.packages.contains('uCrop'));
    final text = ucrop.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('Apache License'));
    expect(text, contains('Yalantis'));
  });
}
