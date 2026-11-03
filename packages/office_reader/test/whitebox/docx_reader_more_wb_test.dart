// Kiểm thử hộp trắng (agent A17, lượt bổ sung A17b) cho lib/src/docx/docx_reader.dart.
// Sinh từ Bước 5 (test-output/whitebox/office-reader/docx_reader/buoc-5-du-lieu-thu.md).
// Expected chép từ Bước 5 — KHÔNG chỉnh cho khớp code. Tên test bắt đầu bằng mã bộ.
import 'package:office_reader/office_reader.dart';
import 'package:test/test.dart';

import '../helpers/ooxml.dart';
Object? _run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

/// Run đầu tiên của đoạn duy nhất, dạng chuỗi: text|smallCaps|bold|italic|underline|strike|sup|sub.
String mk(String rPr, [String text = 'ab']) {
  final r = readDocx(buildDocx(body: '<w:p><w:r><w:rPr>$rPr</w:rPr><w:t>$text</w:t></w:r></w:p>'))
      .blocks
      .whereType<DocxParagraph>()
      .first
      .inlines
      .whereType<DocxRun>()
      .first;
  return '${r.text}|sc=${r.smallCaps}|b=${r.bold}|i=${r.italic}|u=${r.underline}|s=${r.strike}|sup=${r.superscript}|sub=${r.subscript}';
}

void main() {
  group('Đơn vị 23 — _DocxReader._makeRun', () {
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S D11S → R1
    test('23-1 caps=0, smallCaps=0, b/i/u/strike bật, vertAlign=superscript', () {
      final res = _run(() => mk('<w:caps w:val="0"/><w:smallCaps w:val="0"/><w:b/><w:i/><w:u w:val="single"/><w:strike/><w:vertAlign w:val="superscript"/>'));
      expect(res, 'ab|sc=false|b=true|i=true|u=true|s=true|sup=true|sub=false');
    });
    // Đường: D1Đ D3S D4S D5S D6S D7S D8S D9S D10S D11S → R1
    test('23-2 không có w:caps (caps null)', () {
      final res = _run(() => mk('<w:smallCaps w:val="0"/><w:b/><w:i/><w:u w:val="single"/><w:strike/><w:vertAlign w:val="superscript"/>'));
      expect(res, 'ab|sc=false|b=true|i=true|u=true|s=true|sup=true|sub=false');
    });
    // Đường: D1S D2Đ D5S D6S D7S D8S D9S D10S D11S → R1
    test('23-3 w:caps bật', () {
      final res = _run(() => mk('<w:caps/><w:smallCaps w:val="0"/><w:b/><w:i/><w:u w:val="single"/><w:strike/><w:vertAlign w:val="superscript"/>'));
      expect(res, 'AB|sc=false|b=true|i=true|u=true|s=true|sup=true|sub=false');
    });
    // Đường: D1S D2S D3Đ D5Đ D6S D7S D8S D9S D10S D11S → R1
    test('23-4 không có w:smallCaps (smallCaps null)', () {
      final res = _run(() => mk('<w:caps w:val="0"/><w:b/><w:i/><w:u w:val="single"/><w:strike/><w:vertAlign w:val="superscript"/>'));
      expect(res, 'ab|sc=false|b=true|i=true|u=true|s=true|sup=true|sub=false');
    });
    // Đường: D1S D2S D3S D4Đ D5S D6S D7S D8S D9S D10S D11S → R1
    test('23-5 w:smallCaps bật', () {
      final res = _run(() => mk('<w:caps w:val="0"/><w:smallCaps/><w:b/><w:i/><w:u w:val="single"/><w:strike/><w:vertAlign w:val="superscript"/>'));
      expect(res, 'AB|sc=true|b=true|i=true|u=true|s=true|sup=true|sub=false');
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ D7S D8S D9S D10S D11S → R1
    test('23-7 không có w:b', () {
      final res = _run(() => mk('<w:caps w:val="0"/><w:smallCaps w:val="0"/><w:i/><w:u w:val="single"/><w:strike/><w:vertAlign w:val="superscript"/>'));
      expect(res, 'ab|sc=false|b=false|i=true|u=true|s=true|sup=true|sub=false');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7Đ D8S D9S D10S D11S → R1
    test('23-8 không có w:i', () {
      final res = _run(() => mk('<w:caps w:val="0"/><w:smallCaps w:val="0"/><w:b/><w:u w:val="single"/><w:strike/><w:vertAlign w:val="superscript"/>'));
      expect(res, 'ab|sc=false|b=true|i=false|u=true|s=true|sup=true|sub=false');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8Đ D9S D10S D11S → R1
    test('23-9 không có w:u', () {
      final res = _run(() => mk('<w:caps w:val="0"/><w:smallCaps w:val="0"/><w:b/><w:i/><w:strike/><w:vertAlign w:val="superscript"/>'));
      expect(res, 'ab|sc=false|b=true|i=true|u=false|s=true|sup=true|sub=false');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9Đ D10S D11S → R1
    test('23-10 không có w:strike', () {
      final res = _run(() => mk('<w:caps w:val="0"/><w:smallCaps w:val="0"/><w:b/><w:i/><w:u w:val="single"/><w:vertAlign w:val="superscript"/>'));
      expect(res, 'ab|sc=false|b=true|i=true|u=true|s=false|sup=true|sub=false');
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10Đ D11Đ → R1
    test('23-11 không có w:vertAlign (superscript và subscript cùng null)', () {
      final res = _run(() => mk('<w:caps w:val="0"/><w:smallCaps w:val="0"/><w:b/><w:i/><w:u w:val="single"/><w:strike/>'));
      expect(res, 'ab|sc=false|b=true|i=true|u=true|s=true|sup=false|sub=false');
    });
  });
}
