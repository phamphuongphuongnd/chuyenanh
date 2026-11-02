// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/tools/tool_registry.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/tool_registry/buoc-5-du-lieu-thu.md
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/l10n/l10n.dart';
import 'package:pdf_office/core/router/routes.dart';
import 'package:pdf_office/core/tools/tool_registry.dart';

void main() {
  group('U1 toolById', () {
    test('1.1 id đầu danh sách (imageToPdf) ⇒ đúng công cụ', () {
      final t = toolById('imageToPdf');
      expect(t, isNotNull);
      expect(t!.route, Routes.imageToPdf);
      expect(t.group, ToolGroup.create);
    });

    test('1.2 id không có ⇒ null', () {
      expect(toolById('nope'), isNull);
      expect(toolById(''), isNull);
    });

    test('1.3 id cuối nhóm Công cụ PDF (insertPages, MỚI) ⇒ đúng route, nhóm, đầu vào PDF', () {
      final t = toolById('insertPages');
      expect(t, isNotNull);
      expect(t!.route, Routes.insertPages);
      expect(t.group, ToolGroup.pdfTools);
      expect(t.inputType, ToolInputType.pdf);
    });
  });

  group('U2 toolLabelFor', () {
    late AppLocalizations l;
    setUpAll(() async {
      l = await AppLocalizations.delegate.load(const Locale('en'));
    });

    final keys = <(String, String, bool, String Function(AppLocalizations))>[
      ('2.1', 'core_toolImageToPdf', false, (l) => l.core_toolImageToPdf),
      ('2.2', 'core_toolScanner', false, (l) => l.core_toolScanner),
      ('2.3', 'core_toolTextToPdf', false, (l) => l.core_toolTextToPdf),
      ('2.4', 'core_toolCreateBlank', false, (l) => l.core_toolCreateBlank),
      ('2.5', 'core_toolWordToPdf', false, (l) => l.core_toolWordToPdf),
      ('2.6', 'core_toolExcelToPdf', false, (l) => l.core_toolExcelToPdf),
      ('2.7', 'core_toolPdfToImage', false, (l) => l.core_toolPdfToImage),
      ('2.8', 'core_toolPdfToText', false, (l) => l.core_toolPdfToText),
      ('2.9', 'core_toolPdfToWord', false, (l) => l.core_toolPdfToWord),
      ('2.10', 'core_toolPdfToExcel', false, (l) => l.core_toolPdfToExcel),
      ('2.11', 'core_toolMerge', false, (l) => l.core_toolMerge),
      ('2.12', 'core_toolSplit', false, (l) => l.core_toolSplit),
      ('2.13', 'core_toolOrganize', false, (l) => l.core_toolOrganize),
      ('2.14', 'core_toolLock', false, (l) => l.core_toolLock),
      ('2.15', 'core_toolUnlock', false, (l) => l.core_toolUnlock),
      ('2.16', 'core_toolWatermark', false, (l) => l.core_toolWatermark),
      ('2.17', 'core_toolAnnotate', false, (l) => l.core_toolAnnotate),
      ('2.18', 'core_toolSign', false, (l) => l.core_toolSign),
      ('2.19', 'core_toolFillForm', false, (l) => l.core_toolFillForm),
      ('2.20', 'core_toolIdCard', true, (l) => l.core_toolIdCard),
      ('2.21', 'core_toolQrScan', true, (l) => l.core_toolQrScan),
      ('2.22', 'core_toolPptToPdf', true, (l) => l.core_toolPptToPdf),
      ('2.23', 'core_toolPdfToPpt', true, (l) => l.core_toolPdfToPpt),
      ('2.24', 'core_toolCompress', true, (l) => l.core_toolCompress),
      ('2.25', 'core_toolPageNumbers', true, (l) => l.core_toolPageNumbers),
      ('2.26', 'core_toolInsertPages', true, (l) => l.core_toolInsertPages),
    ];

    for (final (code, key, isNew, getter) in keys) {
      test('$code $key${isNew ? ' (MỚI)' : ''} ⇒ đúng chuỗi ARB của khoá, khác mọi khoá khác', () {
        final label = toolLabelFor(l, key);
        expect(label, getter(l));
        expect(label, isNot(key));
        final others = keys.where((k) => k.$2 != key).map((k) => k.$4(l)).toSet();
        expect(others.contains(label), isFalse, reason: 'nhãn $key trùng nhãn khoá khác');
      });
    }

    test('2.27 khoá lạ ⇒ trả lại chính khoá', () {
      expect(toolLabelFor(l, 'core_toolNope'), 'core_toolNope');
    });
  });
}
