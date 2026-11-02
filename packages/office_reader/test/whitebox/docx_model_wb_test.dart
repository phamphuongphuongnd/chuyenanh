// Kiểm thử hộp trắng (agent A17) cho lib/src/docx/docx_model.dart.
// Sinh từ Bước 5 (test-output/whitebox/office-reader/docx_model/buoc-5-du-lieu-thu.md).
// Expected chép từ Bước 5 — KHÔNG chỉnh cho khớp code. Tên test bắt đầu bằng mã bộ.
import 'dart:typed_data';

import 'package:office_reader/src/docx/docx_model.dart';
import 'package:test/test.dart';
Object? _run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

final img = DocxImage(bytes: Uint8List(0), extension: 'png', widthEmu: 1, heightEmu: 1);
const listPara = DocxParagraph(
  listLevel: 1,
  listOrdered: true,
  listLabel: '2.',
  inlines: [DocxRun(text: 'a')],
  pageBreakBefore: true,
);

void main() {
  group('Đơn vị 1 — DocxParagraph.plainText (lambda switch)', () {
    // Đường: D1Đ → R1
    test('1-1 inlines [DocxRun(\'ab\')]', () {
      final res = _run(() => const DocxParagraph(inlines: [DocxRun(text: 'ab')]).plainText);
      expect(res, 'ab');
    });
    // Đường: D1S D2Đ → R2
    test('1-2 inlines [Run(\'a\'), DocxBreak(), Run(\'b\')]', () {
      final res = _run(() => const DocxParagraph(inlines: [DocxRun(text: 'a'), DocxBreak(), DocxRun(text: 'b')]).plainText);
      expect(res, 'a\nb');
    });
    // Đường: D1S D2S → R3
    test('1-3 inlines [DocxImage]', () {
      final res = _run(() => DocxParagraph(inlines: [img]).plainText);
      expect(res, '');
    });
  });
  group('Đơn vị 2 — DocxParagraph.copyWith', () {
    // Đường: D1S D2S D3S D4S D5S D6S → R1
    test('2-1 listPara.copyWith(listLabel: \'x\', inlines: [Run(\'b\')], pageBreakBefore: false)', () {
      final res = _run(() => listPara.copyWith(listLabel: 'x', inlines: const [DocxRun(text: 'b')], pageBreakBefore: false));
      expect(res, isA<DocxParagraph>().having((p) => p.listLevel, 'listLevel', 1).having((p) => p.listOrdered, 'ordered', isTrue).having((p) => p.listLabel, 'label', 'x').having((p) => p.plainText, 'text', 'b').having((p) => p.pageBreakBefore, 'pbb', isFalse));
    });
    // Đường: D1Đ D2Đ D3Đ D5S D6S → R1
    test('2-2 listPara.copyWith(clearList: true, inlines: [Run(\'b\')], pageBreakBefore: false)', () {
      final res = _run(() => listPara.copyWith(clearList: true, inlines: const [DocxRun(text: 'b')], pageBreakBefore: false));
      expect(res, isA<DocxParagraph>().having((p) => p.listLevel, 'listLevel', isNull).having((p) => p.listOrdered, 'ordered', isFalse).having((p) => p.listLabel, 'label', isNull));
    });
    // Đường: D1S D2S D3S D4Đ D5S D6S → R1
    test('2-5 listPara.copyWith(inlines: [Run(b)], pageBreakBefore: false) — listLabel null', () {
      final res = _run(() => listPara.copyWith(inlines: const [DocxRun(text: 'b')], pageBreakBefore: false).listLabel);
      expect(res, '2.');
    });
    // Đường: D1S D2S D3S D4S D5Đ D6S → R1
    test('2-6 listPara.copyWith(listLabel: \'x\', pageBreakBefore: false) — inlines null', () {
      final res = _run(() => listPara.copyWith(listLabel: 'x', pageBreakBefore: false).plainText);
      expect(res, 'a');
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ → R1
    test('2-7 listPara.copyWith(listLabel: \'x\', inlines: [Run(b)]) — pageBreakBefore null', () {
      final res = _run(() => listPara.copyWith(listLabel: 'x', inlines: const [DocxRun(text: 'b')]).pageBreakBefore);
      expect(res, isTrue);
    });
  });
}
