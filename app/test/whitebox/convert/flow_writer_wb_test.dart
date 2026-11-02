// ignore_for_file: unnecessary_import
// Kiểm thử hộp trắng (A04, chủ đề convert) — lib/features/convert/engine/flow_writer.dart.
// Mã bộ = mã đường Bước 4/5: test-output/whitebox/convert/flow_writer/buoc-5-du-lieu-thu.md.
// Expected chép từ Bước 5 (nguồn yêu cầu), KHÔNG chỉnh theo code.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/convert/engine/flow_writer.dart';
import 'package:pdf_office/features/convert/engine/font_set.dart';
import 'package:pdf_office/features/convert/text/line_wrap.dart';
import 'package:pdf_office/features/convert/text/script_runs.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// PNG 1x1 hợp lệ.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

/// Bộ font ghi lại các style được hỏi (font chuẩn, không cần byte).
class _SpyFonts extends PdfFontSet {
  _SpyFonts() : super(const {});
  final asked = <StyledSpan>[];
  @override
  sf.PdfFont fontFor(ScriptFace face, StyledSpan style) {
    asked.add(style);
    return super.fontFor(face, style);
  }
}

double _h(double size) => sf.PdfStandardFont(sf.PdfFontFamily.helvetica, size).height;

/// Nội dung các stream (giải nén Flate nếu được) ghép lại — để đếm toán tử vẽ.
String _content(Uint8List pdf) {
  final s = latin1.decode(pdf);
  final out = StringBuffer();
  var i = 0;
  while (true) {
    final a = s.indexOf('stream', i);
    if (a < 0) break;
    if (a >= 3 && s.substring(a - 3, a) == 'end') {
      i = a + 6;
      continue;
    }
    var start = a + 6;
    if (s.startsWith('\r\n', start)) {
      start += 2;
    } else if (s.startsWith('\n', start)) {
      start += 1;
    }
    final e = s.indexOf('endstream', start);
    if (e < 0) break;
    final raw = pdf.sublist(start, e);
    try {
      out.write(latin1.decode(const ZLibDecoder().decodeBytes(raw), allowInvalid: true));
    } catch (_) {
      out.write(latin1.decode(raw, allowInvalid: true));
    }
    out.write('\n');
    i = e + 9;
  }
  return out.toString();
}

int _count(String content, String op) => RegExp('(^|\\s)${RegExp.escape(op)}(\\s|\$)', multiLine: true).allMatches(content).length;

List<sf.TextLine> _lines(Uint8List pdf) {
  final doc = sf.PdfDocument(inputBytes: pdf);
  try {
    return sf.PdfTextExtractor(doc).extractTextLines();
  } finally {
    doc.dispose();
  }
}

String _text(Uint8List pdf) {
  final doc = sf.PdfDocument(inputBytes: pdf);
  try {
    return sf.PdfTextExtractor(doc).extractText();
  } finally {
    doc.dispose();
  }
}

sf.TextWord _word(Uint8List pdf, String w) =>
    _lines(pdf).expand((l) => l.wordCollection).firstWhere((x) => x.text.contains(w));

PdfFlowWriter _w({double width = 595, double height = 842, double margin = 40, PdfFontSet? fonts}) =>
    PdfFlowWriter(fonts ?? PdfFontSet(const {}), pageWidth: width, pageHeight: height, margin: margin);

Uint8List _one(void Function(PdfFlowWriter w) draw) {
  final w = _w();
  draw(w);
  return w.finish();
}

void main() {
  group('U1 constructor', () {
    test('U1-P1 khổ dọc 595x842 ⇒ trang 595x842', () {
      final pdf = _w().finish();
      final doc = sf.PdfDocument(inputBytes: pdf);
      expect(doc.pages[0].size.width, closeTo(595, 0.5));
      expect(doc.pages[0].size.height, closeTo(842, 0.5));
      doc.dispose();
    });
    test('U1-P2 khổ ngang 842x595 ⇒ trang rộng 842, cao 595', () {
      final pdf = _w(width: 842, height: 595).finish();
      final doc = sf.PdfDocument(inputBytes: pdf);
      expect(doc.pages[0].size.width, closeTo(842, 0.5));
      expect(doc.pages[0].size.height, closeTo(595, 0.5));
      doc.dispose();
    });
  });

  group('U2 pageBreak / U3 _ensureSpace', () {
    test('U2-P1 trang có nội dung ⇒ sang trang mới, y về lề', () {
      final w = _w()..paragraph(const [StyledSpan('a')]);
      w.pageBreak();
      expect(w.pageCount, 2);
      expect(w.y, 40);
    });
    test('U2-P2 trang còn trống ⇒ không tạo trang trắng', () {
      final w = _w()..pageBreak();
      expect(w.pageCount, 1);
    });
    test('U3-P1 đoạn vừa trang ⇒ 1 trang', () {
      final w = _w()..paragraph(const [StyledSpan('fits')]);
      expect(w.pageCount, 1);
    });
    test('U3-P2 tràn trang khi đã có nội dung ⇒ sang trang mới', () {
      final w = _w(height: 200, margin: 40);
      for (var i = 0; i < 12; i++) {
        w.paragraph([StyledSpan('line $i')]);
      }
      expect(w.pageCount, greaterThan(1));
      expect(_text(w.finish()), contains('line 11'));
    });
    test('U3-P3 dòng cao hơn cả trang nhưng trang trống ⇒ không tạo trang trắng', () {
      final w = _w(height: 200, margin: 40)..paragraph(const [StyledSpan('X')], fontSize: 200);
      expect(w.pageCount, 1);
    });
  });

  group('U4 _fill (qua font được hỏi)', () {
    test('U4-P1 span có size 10, rise 0 ⇒ vẽ cỡ 10', () {
      final f = _SpyFonts();
      _w(fonts: f).paragraph(const [StyledSpan('a', size: 10)], fontSize: 20);
      expect(f.asked.map((s) => s.size), everyElement(10));
    });
    test('U4-P2 span không size ⇒ cỡ của đoạn', () {
      final f = _SpyFonts();
      _w(fonts: f).paragraph(const [StyledSpan('a')], fontSize: 20);
      expect(f.asked.map((s) => s.size), contains(20));
    });
    test('U4-P3 chỉ số trên/dưới ⇒ cỡ 0.7 lần', () {
      final f = _SpyFonts();
      _w(fonts: f).paragraph(const [StyledSpan('a', size: 10, rise: 1)]);
      expect(f.asked.map((s) => s.size), contains(closeTo(7, 1e-9)));
    });
  });

  group('U5 _lineHeight', () {
    test('U5-P1 một run cỡ 12 ⇒ dòng cao bằng chiều cao font 12', () {
      final w = _w()..paragraph(const [StyledSpan('a')]);
      expect(w.y - 40, closeTo(_h(12), 1e-6));
    });
    test('U5-P2 đoạn rỗng ⇒ vẫn một dòng cao bằng font Latin cỡ đoạn', () {
      final w = _w()..paragraph(const [], fontSize: 16);
      expect(w.y - 40, closeTo(_h(16), 1e-6));
    });
    test('U5-P3 dòng có run 20 rồi run 10 ⇒ cao theo run lớn nhất', () {
      final w = _w()..paragraph(const [StyledSpan('Big ', size: 20), StyledSpan('small', size: 10)]);
      expect(w.y - 40, closeTo(_h(20), 1e-6));
    });
  });

  group('U6 _drawRun', () {
    final base = _one((w) => w.paragraph(const [StyledSpan('Plain')]));
    final baseC = _content(base);
    final emptyC = _content(_one((w) => w.paragraph(const []))); // trang đã khởi tạo graphics, chưa vẽ gì

    test('U6-P1 chữ thường ⇒ có chữ, màu đen, không kẻ/tô thêm', () {
      expect(_text(base), contains('Plain'));
      expect(_count(baseC, 're'), _count(emptyC, 're')); // so với trang trống
      expect(_count(baseC, 'l'), _count(emptyC, 'l'));
    });
    test('U6-P2 chỉ số trên ⇒ vẽ cao hơn chữ thường', () {
      final pdf = _one((w) => w.paragraph(const [StyledSpan('Base '), StyledSpan('Up', rise: 1)]));
      expect(_word(pdf, 'Up').bounds.center.dy, lessThan(_word(pdf, 'Base').bounds.center.dy));
    });
    test('U6-P3 chỉ số dưới ⇒ vẽ thấp hơn chữ thường', () {
      final pdf = _one((w) => w.paragraph(const [StyledSpan('Base '), StyledSpan('Down', rise: -1)]));
      expect(_word(pdf, 'Down').bounds.center.dy, greaterThan(_word(pdf, 'Base').bounds.center.dy));
    });
    test('U6-P4 tô sáng ⇒ có thêm hình chữ nhật nền', () {
      final c = _content(_one((w) => w.paragraph(const [StyledSpan('Hi', highlightArgb: 0xFFFFFF00)])));
      expect(_count(c, 're'), greaterThan(_count(baseC, 're')));
    });
    test('U6-P5 có màu chữ đỏ ⇒ dùng màu đỏ (1 0 0)', () {
      final c = _content(_one((w) => w.paragraph(const [StyledSpan('Red', colorArgb: 0xFFFF0000)])));
      expect(c, contains('1 0 0 rg'));
      expect(baseC, isNot(contains('1 0 0 rg')));
    });
    test('U6-P7 gạch dưới ⇒ thêm một nét kẻ', () {
      final c = _content(_one((w) => w.paragraph(const [StyledSpan('U', underline: true)])));
      expect(_count(c, 'l'), _count(baseC, 'l') + 1);
    });
    test('U6-P8 gạch ngang ⇒ thêm một nét kẻ', () {
      final c = _content(_one((w) => w.paragraph(const [StyledSpan('S', strike: true)])));
      expect(_count(c, 'l'), _count(baseC, 'l') + 1);
    });
  });

  group('U7 _alignDx (qua paragraph)', () {
    double left(FlowAlign a) => _word(_one((w) => w.paragraph(const [StyledSpan('Mid')], align: a)), 'Mid').bounds.left;
    double right(FlowAlign a) => _word(_one((w) => w.paragraph(const [StyledSpan('Mid')], align: a)), 'Mid').bounds.right;

    test('U7-P1 trái ⇒ sát lề trái', () => expect(left(FlowAlign.left), closeTo(40, 1.5)));
    test('U7-P2 giữa ⇒ tâm chữ ở giữa trang', () {
      final l = left(FlowAlign.center), r = right(FlowAlign.center);
      expect((l + r) / 2, closeTo(595 / 2, 2));
    });
    test('U7-P3 phải ⇒ sát lề phải', () => expect(right(FlowAlign.right), closeTo(595 - 40, 2)));
  });

  group('U8 paragraph', () {
    test('U8-P1 mặc định ⇒ cỡ cơ sở 12, y tăng một dòng', () {
      final f = _SpyFonts();
      final w = _w(fonts: f)..paragraph(const [StyledSpan('Hello')]);
      expect(f.asked.map((s) => s.size), contains(12));
      expect(w.y - 40, closeTo(_h(12), 1e-6));
    });
    test('U8-P2 fontSize 20 ⇒ dòng cao theo cỡ 20', () {
      final w = _w()..paragraph(const [StyledSpan('Hello')], fontSize: 20);
      expect(w.y - 40, closeTo(_h(20), 1e-6));
    });
    test('U8-P3 spaceBefore 10 khi trang đã có nội dung ⇒ cách thêm 10', () {
      final w = _w()..paragraph(const [StyledSpan('a')]);
      final y0 = w.y;
      w.paragraph(const [StyledSpan('b')], spaceBefore: 10);
      expect(w.y - y0, closeTo(10 + _h(12), 1e-6));
    });
    test('U8-P4 spaceBefore 10 ở đầu trang ⇒ không cách thêm', () {
      final w = _w()..paragraph(const [StyledSpan('b')], spaceBefore: 10);
      expect(w.y - 40, closeTo(_h(12), 1e-6));
    });
    test('U8-P6 đoạn nhiều dòng có nhãn ⇒ nhãn vẽ một lần ở dòng đầu', () {
      final long = List.filled(60, 'word').join(' ');
      final pdf = _one((w) => w.paragraph([StyledSpan(long)], marker: '1.', indentLeft: 30));
      final t = _text(pdf);
      expect('1.'.allMatches(t).length, 1);
      expect(_lines(pdf).length, greaterThan(1));
    });
    test('U8-P7 nhãn "1." thụt 30 ⇒ nhãn nằm bên trái chữ, trong lề thụt', () {
      final pdf = _one((w) => w.paragraph(const [StyledSpan('Item')], marker: '1.', indentLeft: 30));
      final m = _word(pdf, '1.'), item = _word(pdf, 'Item');
      expect(m.bounds.right, lessThanOrEqualTo(item.bounds.left));
      expect(item.bounds.left, closeTo(70, 1.5));
    });
    test('U8-P8 nhãn rỗng ⇒ không vẽ nhãn', () {
      final c = _content(_one((w) => w.paragraph(const [StyledSpan('Item')], marker: '')));
      expect(c, isNot(contains('()')));
      expect(_text(_one((w) => w.paragraph(const [StyledSpan('Item')], marker: ''))).trim(), 'Item');
    });
    test('U8-P9 đoạn không chữ nhưng có nhãn ⇒ vẫn vẽ nhãn', () {
      expect(_text(_one((w) => w.paragraph(const [], marker: '2.', indentLeft: 30))), contains('2.'));
    });
    test('U8-P10 thụt dòng đầu âm ⇒ nhãn bắt đầu ở indent + firstLineIndent', () {
      final pdf = _one((w) => w.paragraph(const [StyledSpan('Hang')], marker: '3.', indentLeft: 30, firstLineIndent: -20));
      expect(_word(pdf, '3.').bounds.left, closeTo(50, 1.5));
    });
    test('U8-P11 đoạn rỗng không nhãn ⇒ không vẽ chữ, y vẫn tăng một dòng', () {
      final w = _w()..paragraph(const []);
      expect(w.y - 40, closeTo(_h(12), 1e-6));
      expect(_text(w.finish()).trim(), isEmpty);
    });
  });

  group('U9 image', () {
    final logs = <String>[];
    final orig = debugPrint;
    setUp(() {
      logs.clear();
      debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
    });
    tearDown(() => debugPrint = orig);

    test('U9-P1 PNG 1x1, không truyền kích thước ⇒ true, y tăng 1 + 4', () {
      final w = _w();
      final r = w.image(_png);
      expect(w.y - 40, closeTo(5, 1e-6));
      expect(r, isTrue);
    });
    test('U9-P2 byte không phải ảnh ⇒ false, bỏ qua, có log', () {
      final w = _w();
      final r = w.image(Uint8List.fromList([1, 2, 3]));
      expect(w.y, 40);
      expect(logs.join(), contains('bỏ qua ảnh'));
      expect(r, isFalse);
    });
    test('U9-P3 width 2000, height null (lấy 1 của ảnh) ⇒ thu nhỏ vừa bề ngang', () {
      final w = _w();
      final r = w.image(_png, width: 2000);
      expect(w.y - 40, closeTo(1 * (515 / 2000) + 4, 1e-6));
      expect(r, isTrue);
    });
    test('U9-P3b width 2000, height 1000 ⇒ thu nhỏ giữ tỉ lệ theo bề ngang', () {
      final w = _w();
      final r = w.image(_png, width: 2000, height: 1000);
      expect(w.y - 40, closeTo(1000 * (515 / 2000) + 4, 1e-6));
      expect(r, isTrue);
    });
    test('U9-P4 height 50 ⇒ ảnh cao 50', () {
      final w = _w();
      expect(w.image(_png, height: 50), isTrue);
      expect(w.y - 40, closeTo(54, 1e-6));
    });
    test('U9-P5 width 0 ⇒ false', () {
      final w = _w();
      expect(w.image(_png, width: 0), isFalse);
      expect(w.y, 40);
    });
    test('U9-P6 height 0 ⇒ false', () {
      final w = _w();
      expect(w.image(_png, height: 0), isFalse);
      expect(w.y, 40);
    });
  });

  group('U10 table', () {
    final emptyRe = _count(_content(_one((w) => w.paragraph(const []))), 're'); // graphics đã khởi tạo (Syncfusion tự thêm 1 hình chữ nhật), chưa vẽ ô
    final row12 = 2 * 3 + _h(12);
    GridCell cell(String t, {bool covered = false, bool wrap = true, int? fill, bool border = true}) =>
        GridCell([StyledSpan(t)], covered: covered, wrap: wrap, fillArgb: fill, border: border);

    test('U10-P1 / P19 1 hàng 2 ô ⇒ cao 2·padding + 1 dòng, 2 viền, ô 2 lệch 100pt', () {
      final w = _w()..table(colWidths: const [100, 100], rows: [[cell('A'), cell('B')]]);
      expect(w.y - 40, closeTo(row12, 1e-6));
      final pdf = w.finish();
      expect(_count(_content(pdf), 're'), greaterThanOrEqualTo(2));
      expect(_word(pdf, 'B').bounds.left, closeTo(40 + 100 + 3, 1.5));
    });
    test('U10-P1b nhiều hàng tràn trang ⇒ sang trang, không mất hàng', () {
      final w = _w(height: 300);
      w.table(colWidths: const [100], rows: [for (var i = 0; i < 30; i++) [cell('R$i')]]);
      expect(w.pageCount, greaterThan(1));
      final t = _text(w.finish());
      for (var i = 0; i < 30; i++) {
        expect(t, contains('R$i'));
      }
    });
    test('U10-P2 fontSize 14 ⇒ hàng cao theo cỡ 14', () {
      final w = _w()..table(colWidths: const [100], rows: [[cell('A')]], fontSize: 14);
      expect(w.y - 40, closeTo(6 + _h(14), 1e-6));
    });
    test('U10-P3 không hàng ⇒ không vẽ gì', () {
      final w = _w()..table(colWidths: const [100], rows: const []);
      expect(w.y, 40);
      expect(_count(_content(w.finish()), 're'), _count(_content(_w().finish()), 're')); // như trang mới
    });
    test('U10-P4 / P18 hàng không ô ⇒ không vẽ ô nào, y không đổi', () {
      final w = _w()..table(colWidths: const [100], rows: const [[]]);
      expect(w.y, 40);
      expect(_count(_content(w.finish()), 're'), emptyRe);
    });
    test('U10-P5 / P20 nhiều ô hơn số cột ⇒ không lỗi, ô thừa không mở rộng bảng', () {
      final w = _w()..table(colWidths: const [100, 100], rows: [[cell('A'), cell('B'), cell('C'), cell('D')]]); // ô C ở cột 2, ô D ở cột 3 ⇒ vượt số cột
      expect(w.y - 40, closeTo(row12, 1e-6));
      expect(_text(w.finish()), contains('A'));
    });
    test('U10-P8 / P15 / P23 ô bị gộp che ⇒ chỉ viền, không chữ', () {
      final w = _w()..table(colWidths: const [100, 100], rows: [[cell('A'), cell('Hidden', covered: true)]]);
      final pdf = w.finish();
      expect(_text(pdf), isNot(contains('Hidden')));
      expect(_count(_content(pdf), 're'), greaterThanOrEqualTo(2));
    });
    test('U10-P10 wrap=false, chữ dài ⇒ một dòng (cắt phần tràn)', () {
      final w = _w()..table(colWidths: const [60], rows: [[cell('averyveryverylongword and more words here', wrap: false)]]);
      expect(w.y - 40, closeTo(row12, 1e-6));
    });
    test('U10-P12 / P16 ô nhiều dòng cạnh ô một dòng ⇒ hàng cao theo ô cao nhất', () {
      final w = _w()..table(colWidths: const [60, 60], rows: [[cell('one two three four five six'), cell('x')]]);
      expect(w.y - 40, greaterThan(row12 + _h(12) - 1e-6));
    });
    test('U10-P13 / P14 ô không chữ ⇒ hàng cao 2·padding + 1 dòng', () {
      final w = _w()..table(colWidths: const [60], rows: const [[GridCell([])]]);
      expect(w.y - 40, closeTo(row12, 1e-6));
    });
    test('U10-P17 ô cao hơn trang ⇒ hàng bị kẹp bằng chiều cao vùng nội dung', () {
      final w = _w(height: 200, margin: 20);
      w.table(colWidths: const [40], rows: [[cell(List.filled(80, 'w').join(' '))]]);
      expect(w.y - 20, closeTo(160, 1e-6));
    });
    test('U10-P21 ô có nền ⇒ thêm hình chữ nhật tô', () {
      final a = _content(_one((w) => w.table(colWidths: const [100], rows: [[cell('A')]])));
      final b = _content(_one((w) => w.table(colWidths: const [100], rows: [[cell('A', fill: 0xFFFF0000)]])));
      expect(_count(b, 're'), _count(a, 're') + 1);
    });
    test('U10-P22 ô không viền ⇒ không có hình chữ nhật', () {
      final c = _content(_one((w) => w.table(colWidths: const [100], rows: [[cell('A', border: false)]])));
      expect(_count(c, 're'), emptyRe + 1); // chỉ còn vùng cắt (clip), không nét viền
    });
    test('U10-P25 ô có dòng trống giữa ⇒ 3 dòng, chữ hai đầu đều vẽ', () {
      final w = _w()..table(colWidths: const [100], rows: [[cell('a\n\nb')]]);
      expect(w.y - 40, closeTo(6 + 3 * _h(12), 1e-6));
      final t = _text(w.finish());
      expect(t, contains('a'));
      expect(t, contains('b'));
    });
  });
}
