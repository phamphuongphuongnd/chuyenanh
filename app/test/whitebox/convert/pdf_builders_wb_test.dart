// ignore_for_file: unnecessary_import
// Kiểm thử hộp trắng (A04, chủ đề convert) — lib/features/convert/engine/pdf_builders.dart.
// Mã bộ = mã đường Bước 4/5: test-output/whitebox/convert/pdf_builders/buoc-5-du-lieu-thu.md.
// Expected chép từ Bước 5 (nguồn yêu cầu), KHÔNG chỉnh theo code.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as office;
import 'package:pdf_layout/pdf_layout.dart' show LayoutPage;
import 'package:pdf_office/engines/convert/convert_engine.dart';
import 'package:pdf_office/features/convert/engine/font_set.dart';
import 'package:pdf_office/features/convert/engine/pdf_builders.dart';
import 'package:pdf_office/features/convert/engine/pdf_extract.dart';
import 'package:pdf_office/features/convert/text/line_wrap.dart';
import 'package:pdf_office/features/convert/text/script_runs.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

// ------------------------------------------------------------------ tiện ích

/// Font chuẩn (không cần Noto) + ghi lại mọi lần đo chữ (text, style) để biết span đã dựng ra sao.
class _SpyFonts extends PdfFontSet {
  _SpyFonts() : super(const {});
  final calls = <(String, StyledSpan)>[];

  @override
  double width(ScriptFace face, StyledSpan style, String text) {
    calls.add((text, style));
    return super.width(face, style, text);
  }

  StyledSpan? styleOf(String text) {
    for (final c in calls) {
      if (c.$1 == text) return c.$2;
    }
    return null;
  }

  Set<String> get texts => calls.map((c) => c.$1).toSet();
}

const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
final _png = base64Decode(_png1x1);

office.DocxImage _img() =>
    office.DocxImage(bytes: _png, extension: 'png', widthEmu: 12700 * 20, heightEmu: 12700 * 20);

office.DocxDocument _doc(List<office.DocxBlock> blocks) =>
    office.DocxDocument(blocks: blocks, page: office.DocxPageSetup.a4);

office.DocxParagraph _p(String text, {int? heading}) =>
    office.DocxParagraph(headingLevel: heading, inlines: [office.DocxRun(text: text)]);

office.DocxTable _table(List<List<List<office.DocxBlock>>> rows,
        {List<int> widths = const [], bool bordered = true}) =>
    office.DocxTable(
      columnWidthsTwips: widths,
      bordered: bordered,
      rows: [
        for (final r in rows) office.DocxTableRow(cells: [for (final c in r) office.DocxTableCell(blocks: c)]),
      ],
    );

office.XlsxCell _c(String display,
        {office.XlsxCellType type = office.XlsxCellType.string, office.XlsxStyle style = office.XlsxStyle.plain}) =>
    office.XlsxCell(display: display, raw: null, type: type, style: style);

office.XlsxSheet _sheet(
  Map<(int, int), office.XlsxCell> cells, {
  String name = 'S',
  List<office.XlsxRange> merges = const [],
  Map<int, double> colW = const {},
  Map<int, double> rowH = const {},
  bool hidden = false,
}) =>
    office.XlsxSheet(
      name: name,
      maxRow: 0,
      maxCol: 0,
      cells: cells,
      merges: merges,
      columnWidthsChars: colW,
      rowHeightsPt: rowH,
      hidden: hidden,
    );

office.XlsxWorkbook _wb(List<office.XlsxSheet> sheets) => office.XlsxWorkbook(sheets: sheets);

List<LayoutPage> _pages(Uint8List pdf) => extractLayoutPages(pdf);

String _allText(Uint8List pdf) => _pages(pdf).expand((p) => p.lines).map((l) => l.text).join('\n');

/// Vị trí (left, top, right) của từ [text] đầu tiên tìm thấy.
(double, double, double)? _pos(Uint8List pdf, String text) {
  for (final p in _pages(pdf)) {
    for (final l in p.lines) {
      for (final w in l.words) {
        if (w.text.trim() == text) return (w.bounds.left, w.bounds.top, w.bounds.right);
      }
      if (l.text.trim() == text) return (l.bounds.left, l.bounds.top, l.bounds.right);
    }
  }
  return null;
}

/// Nội dung các stream (giải nén Flate nếu được) — để thấy toán tử vẽ (rg / RG / re / Do).
String _content(Uint8List pdf) {
  final s = latin1.decode(pdf);
  final b = StringBuffer();
  var i = 0;
  while (true) {
    final k = s.indexOf('stream', i);
    if (k < 0) break;
    if (k >= 3 && s.substring(k - 3, k) == 'end') {
      i = k + 6;
      continue;
    }
    var start = k + 6;
    if (s.startsWith('\r\n', start)) {
      start += 2;
    } else if (s.startsWith('\n', start)) {
      start += 1;
    }
    final e = s.indexOf('endstream', start);
    if (e < 0) break;
    final raw = pdf.sublist(start, e);
    try {
      b.write(latin1.decode(const ZLibDecoder().decodeBytes(raw), allowInvalid: true));
    } catch (_) {
      b.write(latin1.decode(raw, allowInvalid: true));
    }
    b.write('\n');
    i = e + 9;
  }
  return b.toString();
}

bool _hasImage(Uint8List pdf) => latin1.decode(pdf, allowInvalid: true).contains('/Image') || _content(pdf).contains('/Image');

sf.PdfDocument _open(Uint8List pdf) => sf.PdfDocument(inputBytes: pdf);

const _opt = ToPdfOptions();
const _a4w = 595.28, _a4h = 841.89, _m = 40.0;
const _cw = _a4w - 2 * _m; // 515.28

PdfBuildResult _docx(List<office.DocxBlock> blocks, {PdfFontSet? fonts, void Function(double)? report}) =>
    buildDocxPdf(_doc(blocks), _opt, fonts ?? _SpyFonts(), report: report);

PdfBuildResult _xlsx(List<office.XlsxSheet> sheets, {PdfFontSet? fonts, void Function(double)? report}) =>
    buildXlsxPdf(_wb(sheets), _opt, fonts ?? _SpyFonts(), report: report);

/// Cột mặc định 8.43 ký tự → ((8.43*7+5)*0.75) point.
const _colDef = (8.43 * 7 + 5) * 0.75;

void main() {
  // ---------------------------------------------------------------- U1 pageDimensions
  group('U1 pageDimensions', () {
    test('U1-P1 A4 dọc ⇒ (595.28, 841.89)', () {
      expect(pageDimensions(const ToPdfOptions()), (_a4w, _a4h));
    });
    test('U1-P2 A4 ngang ⇒ đảo (841.89, 595.28)', () {
      expect(pageDimensions(const ToPdfOptions(landscape: true)), (_a4h, _a4w));
    });
  });

  // ---------------------------------------------------------------- U2 _writer
  group('U2 _writer', () {
    test('U2-P1 dọc, lề 40 ⇒ trang 595×842, chữ bắt đầu ở x≈40', () {
      final r = buildTextPdf('Hello', const ToPdfOptions(), _SpyFonts());
      final d = _open(r.bytes);
      final size = d.pages[0].size;
      d.dispose();
      expect(size.width, closeTo(_a4w, 0.5));
      expect(_pos(r.bytes, 'Hello')!.$1, closeTo(_m, 1.5));
    });
    test('U2-P2 ngang, lề 40 ⇒ trang 842×595, chữ ở x≈40', () {
      final r = buildTextPdf('Hello', const ToPdfOptions(landscape: true), _SpyFonts());
      final d = _open(r.bytes);
      final size = d.pages[0].size;
      d.dispose();
      expect(size.width, closeTo(_a4h, 0.5));
      expect(size.height, closeTo(_a4w, 0.5));
      expect(_pos(r.bytes, 'Hello')!.$1, closeTo(_m, 1.5));
    });
  });

  // ---------------------------------------------------------------- U3 buildTextPdf
  group('U3 buildTextPdf', () {
    test('U3-P1 1 dòng, có report ⇒ tiến độ tăng dần, kết thúc 1, 1 trang', () {
      final rep = <double>[];
      final r = buildTextPdf('a', _opt, _SpyFonts(), report: rep.add);
      expect(rep, hasLength(2)); // nhánh: i=0 báo, cuối báo 1
      expect(rep, orderedEquals([...rep]..sort()));
      expect(rep.last, 1);
      expect(r.pageCount, 1);
      expect(_allText(r.bytes), contains('a'));
    });
    test('U3-P3 101 dòng ⇒ chỉ báo ở i=0, i=100 và cuối; tăng dần tới 1', () {
      final rep = <double>[];
      final text = [for (var i = 0; i < 101; i++) 'L$i'].join('\n');
      final r = buildTextPdf(text, _opt, _SpyFonts(), report: rep.add);
      expect(rep, hasLength(3));
      expect(rep, orderedEquals([...rep]..sort()));
      expect(rep.every((v) => v >= 0 && v <= 1), isTrue);
      expect(rep.last, 1);
      final t = _allText(r.bytes);
      expect(t, contains('L0'));
      expect(t, contains('L100'));
    });
    test('U3-P4 report null ⇒ không lỗi, ra PDF', () {
      final r = buildTextPdf('a', _opt, _SpyFonts());
      expect(r.pageCount, 1);
      expect(r.bytes, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------- U4 walk (docxPlainText)
  group('U4 walk / docxPlainText', () {
    test('U4-P1 1 đoạn ⇒ "a\\n"', () => expect(docxPlainText(_doc([_p('a')])), 'a\n'));
    test('U4-P2 không khối ⇒ ""', () => expect(docxPlainText(_doc(const [])), ''));
    test('U4-P3 bảng 1 ô có đoạn ⇒ chữ trong ô', () {
      expect(
          docxPlainText(_doc([
            _table([
              [
                [_p('x')]
              ]
            ])
          ])),
          'x\n');
    });
    test('U4-P4 ngắt trang ⇒ ""', () => expect(docxPlainText(_doc(const [office.DocxPageBreak()])), ''));
    test('U4-P5 bảng không hàng ⇒ ""', () => expect(docxPlainText(_doc([_table(const [])])), ''));
    test('U4-P6 hàng không ô ⇒ ""', () {
      expect(
          docxPlainText(_doc([
            _table(const [[]])
          ])),
          '');
    });
  });

  // ---------------------------------------------------------------- U5 _docxSpans
  group('U5 _docxSpans (qua buildDocxPdf)', () {
    office.DocxParagraph run(office.DocxRun r, {int? heading}) =>
        office.DocxParagraph(headingLevel: heading, inlines: [r]);

    test('U5-P1 run thường ⇒ không đậm/gạch, cỡ 12, không màu, rise 0', () {
      final f = _SpyFonts();
      final r = _docx([run(const office.DocxRun(text: 'Hello'))], fonts: f);
      final st = f.styleOf('Hello')!;
      expect(st.bold, isFalse);
      expect(st.underline, isFalse);
      expect(st.size, 12);
      expect(st.colorArgb, isNull);
      expect(st.rise, 0);
      expect(_allText(r.bytes), contains('Hello'));
    });
    test('U5-P2 đoạn không inline ⇒ không đo chữ nào, vẫn 1 trang', () {
      final f = _SpyFonts();
      final r = _docx([const office.DocxParagraph()], fonts: f);
      expect(f.texts.where((t) => t.trim().isNotEmpty), isEmpty);
      expect(r.pageCount, 1);
    });
    test('U5-P3 run, xuống dòng, run ⇒ 2 dòng khác nhau', () {
      final r = _docx([
        const office.DocxParagraph(inlines: [
          office.DocxRun(text: 'a'),
          office.DocxBreak(),
          office.DocxRun(text: 'b'),
        ])
      ]);
      final a = _pos(r.bytes, 'a')!, b = _pos(r.bytes, 'b')!;
      expect(b.$2, greaterThan(a.$2));
    });
    test('U5-P4 run + ảnh PNG ⇒ có chữ và có ảnh', () {
      final r = _docx([
        office.DocxParagraph(inlines: [const office.DocxRun(text: 'a'), _img()])
      ]);
      expect(_allText(r.bytes), contains('a'));
      expect(_hasImage(r.bytes), isTrue);
    });
    test('U5-P5 run rỗng sau chuẩn hoá bị bỏ, run sau vẫn có', () {
      final f = _SpyFonts();
      final r = _docx([
        const office.DocxParagraph(inlines: [office.DocxRun(text: '\u0007', bold: true), office.DocxRun(text: 'x')])
      ], fonts: f);
      expect(f.texts.where((t) => t.trim().isNotEmpty), {'x'});
      expect(_allText(r.bytes).trim(), 'x');
    });
    test('U5-P6 run đậm ⇒ bold', () {
      final f = _SpyFonts();
      _docx([run(const office.DocxRun(text: 'B', bold: true))], fonts: f);
      expect(f.styleOf('B')!.bold, isTrue);
    });
    test('U5-P7 heading 1, run thường ⇒ đậm, cỡ lớn hơn chữ thường (12×1.8)', () {
      final f = _SpyFonts();
      _docx([run(const office.DocxRun(text: 'T'), heading: 1)], fonts: f);
      final st = f.styleOf('T')!;
      expect(st.bold, isTrue);
      expect(st.size, closeTo(12 * 1.8, 1e-9));
    });
    test('U5-P8 run gạch chân ⇒ underline', () {
      final f = _SpyFonts();
      _docx([run(const office.DocxRun(text: 'U', underline: true))], fonts: f);
      expect(f.styleOf('U')!.underline, isTrue);
    });
    test('U5-P9 liên kết không màu ⇒ gạch chân + màu xanh liên kết', () {
      final f = _SpyFonts();
      _docx([run(const office.DocxRun(text: 'L', hyperlink: 'https://x.y'))], fonts: f);
      final st = f.styleOf('L')!;
      expect(st.underline, isTrue);
      expect(st.colorArgb, 0xFF1155CC);
    });
    test('U5-P10 liên kết có màu riêng ⇒ giữ màu, không tự gạch chân', () {
      final f = _SpyFonts();
      _docx([run(const office.DocxRun(text: 'L', hyperlink: 'https://x.y', colorArgb: 0xFFFF0000))], fonts: f);
      final st = f.styleOf('L')!;
      expect(st.underline, isFalse);
      expect(st.colorArgb, 0xFFFF0000);
    });
    test('U5-P11 run cỡ 20 ⇒ size 20', () {
      final f = _SpyFonts();
      _docx([run(const office.DocxRun(text: 'Z', fontSizePt: 20))], fonts: f);
      expect(f.styleOf('Z')!.size, 20);
    });
    test('U5-P12 heading 2 + run đậm ⇒ đậm, cỡ 12×1.5', () {
      final f = _SpyFonts();
      _docx([run(const office.DocxRun(text: 'H', bold: true), heading: 2)], fonts: f);
      final st = f.styleOf('H')!;
      expect(st.bold, isTrue);
      expect(st.size, closeTo(18, 1e-9));
    });
    test('U5-P13 run có màu (không liên kết) ⇒ giữ màu', () {
      final f = _SpyFonts();
      _docx([run(const office.DocxRun(text: 'C', colorArgb: 0xFF00FF00))], fonts: f);
      expect(f.styleOf('C')!.colorArgb, 0xFF00FF00);
      expect(f.styleOf('C')!.underline, isFalse);
    });
    test('U5-P15 chỉ số trên ⇒ rise 1, chữ nhỏ hơn', () {
      final f = _SpyFonts();
      _docx([run(const office.DocxRun(text: 'sup', superscript: true))], fonts: f);
      final st = f.styleOf('sup')!;
      expect(st.rise, 1);
      expect(st.size!, lessThan(12));
    });
    test('U5-P16 chỉ số dưới ⇒ rise -1', () {
      final f = _SpyFonts();
      _docx([run(const office.DocxRun(text: 'sub', subscript: true))], fonts: f);
      expect(f.styleOf('sub')!.rise, -1);
    });
    test('U5-P17 ảnh PNG trong ô bảng ⇒ ảnh được giữ', () {
      final r = _docx([
        _table([
          [
            [
              office.DocxParagraph(inlines: [const office.DocxRun(text: 'cell'), _img()])
            ]
          ]
        ])
      ]);
      expect(_allText(r.bytes), contains('cell')); // nhánh: đi qua _cellSpans (images == null)
      expect(_hasImage(r.bytes), isTrue);
    });
  });

  // ---------------------------------------------------------------- U6 _align
  group('U6 _align', () {
    office.DocxParagraph al(office.DocxAlign a, String t) =>
        office.DocxParagraph(align: a, inlines: [office.DocxRun(text: t)]);
    test('U6-P1 justify ⇒ căn trái (x≈40)', () {
      final r = _docx([al(office.DocxAlign.justify, 'J')]);
      expect(_pos(r.bytes, 'J')!.$1, closeTo(_m, 1.5));
    });
    test('U6-P2 center ⇒ tâm chữ ≈ tâm trang', () {
      final r = _docx([al(office.DocxAlign.center, 'Mid')]);
      final p = _pos(r.bytes, 'Mid')!;
      expect((p.$1 + p.$3) / 2, closeTo(_a4w / 2, 3));
    });
    test('U6-P3 right ⇒ mép phải chữ ≈ lề phải', () {
      final r = _docx([al(office.DocxAlign.right, 'End')]);
      expect(_pos(r.bytes, 'End')!.$3, closeTo(_a4w - _m, 3));
    });
  });

  // ---------------------------------------------------------------- U7 _docxParagraph
  group('U7 _docxParagraph', () {
    final long = List.filled(60, 'word').join(' ');
    double topOf(Uint8List pdf, String t) => _pos(pdf, t)!.$2;

    test('U7-P1 đoạn thường ⇒ có chữ, x≈40, 1 trang', () {
      final r = _docx([_p('Hello')]);
      expect(r.pageCount, 1);
      expect(_pos(r.bytes, 'Hello')!.$1, closeTo(_m, 1.5));
    });
    test('U7-P2 pageBreakBefore ⇒ đoạn sau sang trang 2', () {
      final r = _docx([
        _p('A'),
        const office.DocxParagraph(pageBreakBefore: true, inlines: [office.DocxRun(text: 'B')]),
      ]);
      expect(r.pageCount, 2);
      expect(_pages(r.bytes)[1].lines.map((l) => l.text).join(), contains('B'));
    });
    test('U7-P3 indentLeftPt 36 ⇒ x≈76', () {
      final r = _docx([
        const office.DocxParagraph(indentLeftPt: 36, inlines: [office.DocxRun(text: 'Ind')])
      ]);
      expect(_pos(r.bytes, 'Ind')!.$1, closeTo(_m + 36, 1.5));
    });
    test('U7-P4 mục danh sách cấp 0 ⇒ thụt 18, có nhãn', () {
      final r = _docx([
        const office.DocxParagraph(listLevel: 0, listLabel: '1.', inlines: [office.DocxRun(text: 'item')])
      ]);
      expect(_pos(r.bytes, 'item')!.$1, closeTo(_m + 18, 1.5));
      expect(_allText(r.bytes), contains('1.'));
    });
    test('U7-P5 đoạn trống (không chữ, không ảnh) ⇒ vẫn chiếm 1 dòng', () {
      final with_ = _docx([_p('A'), const office.DocxParagraph(), _p('B')]);
      final without = _docx([_p('A'), _p('B')]);
      expect(topOf(with_.bytes, 'B'), greaterThan(topOf(without.bytes, 'B') + 5));
    });
    test('U7-P6 chỉ có ảnh ⇒ vẽ ảnh, không có dòng chữ', () {
      final r = _docx([
        office.DocxParagraph(inlines: [_img()])
      ]);
      expect(_hasImage(r.bytes), isTrue);
      expect(_allText(r.bytes).trim(), isEmpty);
    });
    test('U7-P7 indentRightPt 200 ⇒ dòng hẹp hơn (nhiều dòng hơn)', () {
      int lines(Uint8List pdf) => _pages(pdf).first.lines.length;
      final narrow = _docx([
        office.DocxParagraph(indentRightPt: 200, inlines: [office.DocxRun(text: long)])
      ]);
      final normal = _docx([_p(long)]);
      expect(lines(narrow.bytes), greaterThan(lines(normal.bytes)));
    });
    test('U7-P8 danh sách có indentLeftPt 36 ⇒ x≈76 (thụt khai báo thắng), có nhãn', () {
      final r = _docx([
        const office.DocxParagraph(
            listLevel: 0, listLabel: '1.', indentLeftPt: 36, inlines: [office.DocxRun(text: 'item')])
      ]);
      expect(_pos(r.bytes, 'item')!.$1, closeTo(_m + 36, 1.5));
      expect(_allText(r.bytes), contains('1.'));
    });
    test('U7-P9 firstLineIndentPt 20 ⇒ dòng đầu x≈60, dòng 2 x≈40', () {
      final r = _docx([
        office.DocxParagraph(firstLineIndentPt: 20, inlines: [office.DocxRun(text: long)])
      ]);
      final ls = _pages(r.bytes).first.lines;
      expect(ls[0].bounds.left, closeTo(_m + 20, 1.5));
      expect(ls[1].bounds.left, closeTo(_m, 1.5));
    });
    test('U7-P10 spaceBeforePt 20 ⇒ đoạn sau lùi xuống ~20', () {
      final a = _docx([
        _p('A'),
        const office.DocxParagraph(spaceBeforePt: 20, inlines: [office.DocxRun(text: 'B')])
      ]);
      final b = _docx([_p('A'), _p('B')]);
      expect(topOf(a.bytes, 'B') - topOf(b.bytes, 'B'), closeTo(20, 1.5));
    });
    test('U7-P11 spaceAfterPt 20 ⇒ đoạn sau lùi thêm 16 so với mặc định 4', () {
      final a = _docx([
        const office.DocxParagraph(spaceAfterPt: 20, inlines: [office.DocxRun(text: 'A')]),
        _p('B'),
      ]);
      final b = _docx([_p('A'), _p('B')]);
      expect(topOf(a.bytes, 'B') - topOf(b.bytes, 'B'), closeTo(16, 1.5));
    });
    test('U7-P12 heading không khai báo spaceAfter ⇒ cách sau 6 (bằng khai báo 6)', () {
      final a = _docx([_p('A', heading: 1), _p('B')]);
      final b = _docx([
        const office.DocxParagraph(headingLevel: 1, spaceAfterPt: 6, inlines: [office.DocxRun(text: 'A')]),
        _p('B'),
      ]);
      expect(topOf(a.bytes, 'B'), closeTo(topOf(b.bytes, 'B'), 0.5));
    });
    test('U7-P13 lineSpacing 2 ⇒ khoảng cách dòng gấp đôi', () {
      double pitch(Uint8List pdf) {
        final ls = _pages(pdf).first.lines;
        return ls[1].bounds.top - ls[0].bounds.top;
      }

      final d = _docx([
        office.DocxParagraph(lineSpacing: 2, inlines: [office.DocxRun(text: long)])
      ]);
      final s = _docx([_p(long)]);
      expect(pitch(d.bytes), closeTo(2 * pitch(s.bytes), 1));
    });
    test('U7-P15 chữ + ảnh ⇒ có cả hai', () {
      final r = _docx([
        office.DocxParagraph(inlines: [const office.DocxRun(text: 'cap'), _img()])
      ]);
      expect(_allText(r.bytes), contains('cap'));
      expect(_hasImage(r.bytes), isTrue);
    });
    test('U7-P16 (biên) indentLeftPt âm lớn (-300) ⇒ không ném, vẫn có chữ', () {
      Object? err;
      PdfBuildResult? r;
      try {
        r = _docx([
          const office.DocxParagraph(indentLeftPt: -300, inlines: [office.DocxRun(text: 'neg')])
        ]);
      } catch (e) {
        err = e;
      }
      expect(err, isNull, reason: 'ném: $err');
      expect(_allText(r!.bytes), contains('neg'));
    });
  });

  // ---------------------------------------------------------------- U8 _cellSpans
  group('U8 _cellSpans (qua bảng DOCX)', () {
    Uint8List one(List<office.DocxBlock> cell) => _docx([
          _table([
            [cell]
          ])
        ]).bytes;

    test('U8-P1 ô 1 đoạn ⇒ có chữ', () => expect(_allText(one([_p('a')])), contains('a')));
    test('U8-P2 ô rỗng ⇒ không lỗi, không chữ', () => expect(_allText(one(const [])).trim(), isEmpty));
    test('U8-P3 bảng lồng ⇒ chữ ô trong', () {
      expect(
          _allText(one([
            _table([
              [
                [_p('n')]
              ]
            ])
          ])),
          contains('n'));
    });
    test('U8-P4 2 đoạn trong ô ⇒ 2 dòng', () {
      final b = one([_p('a'), _p('b')]);
      expect(_pos(b, 'b')!.$2, greaterThan(_pos(b, 'a')!.$2));
    });
    test('U8-P5 đoạn có nhãn danh sách ⇒ "1. a"', () {
      final b = one([
        const office.DocxParagraph(listLabel: '1.', inlines: [office.DocxRun(text: 'a')])
      ]);
      expect(_allText(b), contains('1. a'));
    });
    test('U8-P6 ngắt trang trong ô ⇒ bỏ qua', () {
      final r = _docx([
        _table([
          [
            [const office.DocxPageBreak(), _p('k')]
          ]
        ])
      ]);
      expect(r.pageCount, 1);
      expect(_allText(r.bytes), contains('k'));
    });
    test('U8-P7 bảng lồng không hàng ⇒ không chữ', () => expect(_allText(one([_table(const [])])).trim(), isEmpty));
    test('U8-P8 bảng lồng hàng không ô ⇒ không chữ', () {
      expect(_allText(one([_table(const [[]])])).trim(), isEmpty);
    });
  });

  // ---------------------------------------------------------------- U9 _docxTable
  group('U9 _docxTable', () {
    Uint8List t2(List<int> widths) => _docx([
          _table([
            [
              [_p('a')],
              [_p('b')]
            ]
          ], widths: widths)
        ]).bytes;
    const pad = 3.0;

    test('U9-P1 cột 2000/2000 twip ⇒ ô 2 bắt đầu ở 40+100', () {
      final b = t2(const [2000, 2000]);
      expect(_pos(b, 'a')!.$1, closeTo(_m + pad, 1.5));
      expect(_pos(b, 'b')!.$1, closeTo(_m + 100 + pad, 1.5));
    });
    test('U9-P2 bảng không hàng ⇒ không vẽ gì', () {
      final r = _docx([_table(const [])]);
      expect(_content(r.bytes), isNot(contains(' re')));
    });
    test('U9-P4 không khai báo cột ⇒ chia đều bề ngang', () {
      final b = t2(const []);
      expect(_pos(b, 'b')!.$1, closeTo(_m + _cw / 2 + pad, 1.5));
    });
    test('U9-P5 hàng không ô, không cột ⇒ không lỗi, không vẽ', () {
      final r = _docx([_table(const [[]])]);
      expect(r.pageCount, 1);
      expect(_content(r.bytes), isNot(contains(' re')));
    });
    test('U9-P6 cột [2000, 0] ⇒ cột thiếu = trung bình cột đã biết (100)', () {
      final b = t2(const [2000, 0]);
      expect(_pos(b, 'b')!.$1, closeTo(_m + 100 + pad, 1.5));
    });
    test('U9-P7 cột [0, 0] ⇒ chia đều bề ngang', () {
      final b = t2(const [0, 0]);
      expect(_pos(b, 'b')!.$1, closeTo(_m + _cw / 2 + pad, 1.5));
    });
    test('U9-P9 cột [0, 2000] ⇒ cột thiếu = 100', () {
      final b = t2(const [0, 2000]);
      expect(_pos(b, 'b')!.$1, closeTo(_m + 100 + pad, 1.5));
    });
    test('U9-P10 bảng rộng 800pt ⇒ co vừa bề ngang trang', () {
      final b = t2(const [8000, 8000]);
      expect(_pos(b, 'b')!.$1, closeTo(_m + _cw / 2 + pad, 1.5));
    });
  });

  // ---------------------------------------------------------------- U10 buildDocxPdf
  group('U10 buildDocxPdf', () {
    test('U10-P1 1 đoạn, có report ⇒ tiến độ tăng dần, kết thúc 1', () {
      final rep = <double>[];
      final r = _docx([_p('a')], report: rep.add);
      expect(rep, hasLength(2));
      expect(rep, orderedEquals([...rep]..sort()));
      expect(rep.last, 1);
      expect(_allText(r.bytes), contains('a'));
    });
    test('U10-P2 không khối ⇒ 1 trang trống, report 1', () {
      final rep = <double>[];
      final r = _docx(const [], report: rep.add);
      expect(rep, [1.0]);
      expect(r.pageCount, 1);
    });
    test('U10-P3 khối bảng ⇒ chữ ô', () {
      final r = _docx([
        _table([
          [
            [_p('tc')]
          ]
        ])
      ]);
      expect(_allText(r.bytes), contains('tc'));
    });
    test('U10-P4 đoạn, ngắt trang, đoạn ⇒ 2 trang', () {
      final r = _docx([_p('A'), const office.DocxPageBreak(), _p('B')]);
      expect(r.pageCount, 2);
    });
    test('U10-P5 2 đoạn ⇒ chỉ báo ở i=0 và cuối', () {
      final rep = <double>[];
      _docx([_p('a'), _p('b')], report: rep.add);
      expect(rep, hasLength(2));
      expect(rep.last, 1);
    });
    test('U10-P6 report null ⇒ không lỗi', () {
      expect(_docx([_p('a')]).pageCount, 1);
    });
  });

  // ---------------------------------------------------------------- U11 xlsxPlainText
  group('U11 xlsxPlainText', () {
    test('U11-P1 1 sheet 1 ô ⇒ tên sheet + chữ ô', () {
      expect(xlsxPlainText(_wb([_sheet({(0, 0): _c('a')})])), 'S\na\n');
    });
    test('U11-P2 không sheet ⇒ ""', () => expect(xlsxPlainText(_wb(const [])), ''));
    test('U11-P3 sheet không ô ⇒ chỉ tên sheet', () => expect(xlsxPlainText(_wb([_sheet({})])), 'S\n'));
  });

  // ---------------------------------------------------------------- U12 partitionColumns
  group('U12 partitionColumns', () {
    test('U12-P1 1 cột ⇒ [[0]]', () => expect(partitionColumns([100], 250), [
          [0]
        ]));
    test('U12-P2 không cột ⇒ []', () => expect(partitionColumns([], 250), isEmpty));
    test('U12-P3 2 cột vừa ⇒ 1 dải; biên +0.005 vẫn vừa', () {
      expect(partitionColumns([100, 100], 250), [
        [0, 1]
      ]);
      expect(partitionColumns([125, 125.005], 250), [
        [0, 1]
      ]);
    });
    test('U12-P4 cột thứ 2 tràn ⇒ 2 dải; cột quá rộng vẫn có dải riêng', () {
      expect(partitionColumns([100, 200], 250), [
        [0],
        [1]
      ]);
      expect(partitionColumns([300], 250), [
        [0]
      ]);
    });
  });

  // ---------------------------------------------------------------- U13 XlsxMergeCursor.covering
  group('U13 XlsxMergeCursor.covering', () {
    const a00 = office.XlsxRange(0, 0, 0, 0);
    test('U13-P1 vùng (0,0) ⇒ trả vùng', () => expect(XlsxMergeCursor([a00]).covering(0, 0), same(a00)));
    test('U13-P2 không vùng ⇒ null', () => expect(XlsxMergeCursor(const []).covering(0, 0), isNull));
    test('U13-P3 hàng giảm ⇒ AssertionError', () {
      final cur = XlsxMergeCursor([a00]);
      cur.covering(1, 0);
      expect(() => cur.covering(0, 0), throwsA(isA<AssertionError>()));
    });
    test('U13-P4 cùng hàng gọi 2 lần ⇒ cùng kết quả', () {
      final cur = XlsxMergeCursor([a00]);
      expect(cur.covering(0, 0), same(a00));
      expect(cur.covering(0, 0), same(a00));
    });
    test('U13-P5 sang hàng mới sau khi đã nạp hết ⇒ null', () {
      final cur = XlsxMergeCursor([a00]);
      cur.covering(0, 0);
      expect(cur.covering(1, 0), isNull);
    });
    test('U13-P6 vùng bắt đầu ở hàng sau ⇒ null, tới hàng đó ⇒ vùng', () {
      const m = office.XlsxRange(2, 0, 2, 0);
      final cur = XlsxMergeCursor([m]);
      expect(cur.covering(0, 0), isNull);
      expect(cur.covering(2, 0), same(m));
    });
    test('U13-P7 vùng đã kết thúc trước hàng đầu tiên hỏi ⇒ null', () {
      expect(XlsxMergeCursor([a00]).covering(1, 0), isNull);
    });
    test('U13-P9 vùng không chứa cột ⇒ null', () => expect(XlsxMergeCursor([a00]).covering(0, 1), isNull));
    test('U13-P10 2 vùng chồng, cùng hàng đầu ⇒ vùng đứng trước trong danh sách', () {
      const a = office.XlsxRange(0, 0, 0, 1), b = office.XlsxRange(0, 0, 0, 0);
      expect(XlsxMergeCursor([a, b]).covering(0, 0), same(a));
    });
    test('U13-P11 vùng đứng trước có hàng đầu lớn hơn ⇒ vẫn chọn vùng đứng trước', () {
      const a = office.XlsxRange(1, 0, 1, 0), b = office.XlsxRange(0, 0, 1, 0);
      expect(XlsxMergeCursor([a, b]).covering(1, 0), same(a));
    });
  });

  // ---------------------------------------------------------------- U14 buildXlsxPdf
  group('U14 buildXlsxPdf', () {
    test('U14-P1 1 sheet 1 ô ⇒ 1 trang có tên sheet và chữ ô; tiến độ kết thúc 1', () {
      final rep = <double>[];
      final r = _xlsx([
        _sheet({(0, 0): _c('a')}, name: 'S1')
      ], report: rep.add);
      expect(rep, hasLength(2));
      expect(rep.last, 1);
      expect(r.pageCount, 1);
      final t = _allText(r.bytes);
      expect(t, contains('S1'));
      expect(t, contains('a'));
    });
    test('U14-P2 chỉ có sheet ẩn ⇒ không xuất sheet ẩn', () {
      final rep = <double>[];
      final r = _xlsx([
        _sheet({(0, 0): _c('secret')}, name: 'H', hidden: true)
      ], report: rep.add);
      expect(rep, [1.0]); // nhánh: vòng sheet chạy 0 lần
      expect(_allText(r.bytes), isNot(contains('secret')));
    });
    test('U14-P3 sheet không ô ⇒ bỏ qua sheet, không lỗi', () {
      final r = _xlsx([_sheet({}, name: 'Empty')]);
      expect(r.pageCount, greaterThanOrEqualTo(1));
      expect(_allText(r.bytes), isNot(contains('Empty'))); // nhánh: lastRow < 0 ⇒ continue
    });
    test('U14-P4 ô trống không nền không kéo dài sheet', () {
      final f = _SpyFonts();
      final r = _xlsx([
        _sheet({(0, 0): _c('a'), (1, 0): _c('')})
      ], fonts: f);
      expect(_allText(r.bytes), contains('a'));
      expect(_content(r.bytes), isNot(contains('1 0 0 rg')));
    });
    test('U14-P5 ô trống có nền ⇒ vẫn vẽ (có màu nền)', () {
      final r = _xlsx([
        _sheet({(0, 0): _c('a'), (1, 0): _c('', style: const office.XlsxStyle(fillArgb: 0xFFFF0000))})
      ]);
      expect(_content(r.bytes), matches(RegExp(r'1(\.0+)? 0(\.0+)? 0(\.0+)? rg')));
    });
    test('U14-P6 hàng ≥ 50.000 bị cắt, có log', () {
      final logs = <String>[];
      final old = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
      try {
        final r = _xlsx([
          _sheet({(0, 0): _c('a'), (50000, 0): _c('far')})
        ]);
        final t = _allText(r.bytes);
        expect(t, contains('a'));
        expect(t, isNot(contains('far')));
        expect(r.pageCount, 1);
      } finally {
        debugPrint = old;
      }
      expect(logs.any((m) => m.contains('50000')), isTrue);
    });
    test('U14-P7 2 ô cùng hàng ⇒ cả hai', () {
      final t = _allText(_xlsx([
        _sheet({(0, 0): _c('a'), (0, 1): _c('b')})
      ]).bytes);
      expect(t, contains('a'));
      expect(t, contains('b'));
    });
    test('U14-P8 2 ô cùng cột ⇒ cả hai', () {
      final r = _xlsx([
        _sheet({(0, 0): _c('a'), (1, 0): _c('b')})
      ]);
      expect(_pos(r.bytes, 'b')!.$2, greaterThan(_pos(r.bytes, 'a')!.$2));
    });
    test('U14-P9 mọi ô đều trống không nền ⇒ bỏ qua sheet', () {
      final r = _xlsx([
        _sheet({(0, 0): _c(''), (2, 3): _c('')}, name: 'Blank')
      ]);
      expect(_allText(r.bytes), isNot(contains('Blank')));
    });
    test('U14-P10 (unit) ô có khoá cột âm ⇒ bỏ qua sheet, không lỗi', () {
      final r = _xlsx([
        _sheet({(0, -1): _c('neg')}, name: 'Neg')
      ]);
      expect(_allText(r.bytes), isNot(contains('Neg')));
    });
    test('U14-P12 có vùng gộp (0,0)-(0,1) ⇒ ô bị gộp không có chữ', () {
      final t = _allText(_xlsx([
        _sheet({(0, 0): _c('m'), (0, 1): _c('hid')}, merges: const [office.XlsxRange(0, 0, 0, 1)])
      ]).bytes);
      expect(t, contains('m'));
      expect(t, isNot(contains('hid')));
    });
    test('U14-P13 mọi cột ẩn ⇒ không xuất chữ của cột ẩn', () {
      final t = _allText(_xlsx([
        _sheet({(0, 0): _c('x')}, colW: const {0: 0})
      ]).bytes);
      expect(t, isNot(contains('x')));
    });
    test('U14-P14 10 cột rộng ⇒ chia dải, tiêu đề "S (1/n)"', () {
      final r = _xlsx([
        _sheet({for (var c = 0; c < 10; c++) (0, c): _c('c$c')}, colW: {for (var c = 0; c < 10; c++) c: 30})
      ]);
      final t = _allText(r.bytes);
      expect(t, contains('S (1/'));
      expect(t, contains('c9'));
      expect(r.pageCount, greaterThan(1));
    });
    test('U14-P15 hàng duy nhất bị ẩn ⇒ có tiêu đề, không có chữ ô', () {
      final t = _allText(_xlsx([
        _sheet({(0, 0): _c('x')}, rowH: const {0: 0})
      ]).bytes);
      expect(t, contains('S'));
      expect(t, isNot(contains('x')));
    });
    test('U14-P16 hàng 0 cao 30 ⇒ hàng sau lùi ~30', () {
      final r = _xlsx([
        _sheet({(0, 0): _c('a'), (1, 0): _c('b')}, rowH: const {0: 30})
      ]);
      expect(_pos(r.bytes, 'b')!.$2 - _pos(r.bytes, 'a')!.$2, closeTo(30, 2));
    });
    test('U14-P17 2 hàng cao mặc định ⇒ cách ~15', () {
      final r = _xlsx([
        _sheet({(0, 0): _c('a'), (1, 0): _c('b')})
      ]);
      expect(_pos(r.bytes, 'b')!.$2 - _pos(r.bytes, 'a')!.$2, closeTo(15, 2));
    });
    test('U14-P18 501 hàng cùng cao ⇒ đủ hàng đầu và cuối', () {
      final r = _xlsx([
        _sheet({for (var i = 0; i <= 500; i++) (i, 0): _c('r$i')})
      ]);
      final t = _allText(r.bytes);
      expect(t, contains('r0'));
      expect(t, contains('r499'));
      expect(t, contains('r500'));
    });
    test('U14-P19 hàng 1 khai báo cao = mặc định ⇒ cách ~15', () {
      final r = _xlsx([
        _sheet({(0, 0): _c('a'), (1, 0): _c('b')}, rowH: const {1: 15})
      ]);
      expect(_pos(r.bytes, 'b')!.$2 - _pos(r.bytes, 'a')!.$2, closeTo(15, 2));
    });
    test('U14-P20 hàng 1 cao 30 (khác hàng 0) ⇒ hàng 2 lùi thêm ~30', () {
      final r = _xlsx([
        _sheet({(0, 0): _c('a'), (1, 0): _c('b'), (2, 0): _c('c')}, rowH: const {1: 30})
      ]);
      expect(_pos(r.bytes, 'b')!.$2 - _pos(r.bytes, 'a')!.$2, closeTo(15, 2));
      expect(_pos(r.bytes, 'c')!.$2 - _pos(r.bytes, 'b')!.$2, closeTo(30, 2));
    });
    test('U14-P21 report null ⇒ không lỗi', () {
      expect(_xlsx([
        _sheet({(0, 0): _c('a')})
      ]).pageCount, 1);
    });
  });

  // ---------------------------------------------------------------- U15 buildRow
  group('U15 buildRow (hàm cục bộ của buildXlsxPdf)', () {
    Uint8List one(office.XlsxCell c, {List<office.XlsxRange> merges = const []}) => _xlsx([
          _sheet({(0, 0): c}, merges: merges)
        ]).bytes;

    test('U15-P1 ô chữ thường ⇒ cỡ 10, không đậm, căn trái, viền xám', () {
      final f = _SpyFonts();
      final r = _xlsx([
        _sheet({(0, 0): _c('a')})
      ], fonts: f);
      final st = f.styleOf('a')!;
      expect(st.size, 10);
      expect(st.bold, isFalse);
      expect(_pos(r.bytes, 'a')!.$1, closeTo(_m + 2, 1.5));
      expect(_content(r.bytes), matches(RegExp(r'0\.78\d* 0\.78\d* 0\.78\d* RG')));
    });
    test('U15-P3 vùng gộp 1 ô neo tại ô ⇒ vẫn có chữ', () {
      expect(_allText(one(_c('m'), merges: const [office.XlsxRange(0, 0, 0, 0)])), contains('m'));
    });
    test('U15-P4 gộp dọc ⇒ ô dưới không có chữ', () {
      final t = _allText(_xlsx([
        _sheet({(0, 0): _c('top'), (1, 0): _c('below')}, merges: const [office.XlsxRange(0, 0, 1, 0)])
      ]).bytes);
      expect(t, contains('top'));
      expect(t, isNot(contains('below')));
    });
    test('U15-P5 gộp ngang vắt qua 2 dải ⇒ ô bị gộp ở dải sau không có chữ', () {
      final t = _allText(_xlsx([
        _sheet({(0, 0): _c('anc'), (0, 1): _c('cov')},
            merges: const [office.XlsxRange(0, 0, 0, 1)], colW: const {0: 90, 1: 90})
      ]).bytes);
      expect(t, contains('anc'));
      expect(t, isNot(contains('cov')));
      expect(t, contains('S (2/2)')); // nhánh: có 2 dải
    });
    test('U15-P6 (unit) 2 vùng chồng nhau trong hàng ⇒ ô còn lại của vùng thuộc ô neo, không có chữ', () {
      final t = _allText(_xlsx([
        _sheet({(0, 0): _c('x'), (0, 1): _c('y'), (0, 2): _c('z')},
            merges: const [office.XlsxRange(0, 0, 0, 0), office.XlsxRange(0, 0, 0, 2)])
      ]).bytes);
      expect(t, contains('x'));
      expect(t, isNot(contains('y')));
      expect(t, isNot(contains('z')));
    });
    test('U15-P7 gộp ngang 2 cột, căn giữa ⇒ chữ ở giữa 2 cột', () {
      final r = _xlsx([
        _sheet({(0, 0): _c('mm', style: const office.XlsxStyle(hAlign: office.XlsxHAlign.center))},
            merges: const [office.XlsxRange(0, 0, 0, 1)])
      ]);
      final p = _pos(r.bytes, 'mm')!;
      expect((p.$1 + p.$3) / 2, closeTo(_m + _colDef, 2));
    });
    test('U15-P8 vùng 1 ô + ô kế bên ⇒ ô kế bên vẫn có chữ', () {
      final t = _allText(_xlsx([
        _sheet({(0, 0): _c('m'), (0, 1): _c('n')}, merges: const [office.XlsxRange(0, 0, 0, 0)])
      ]).bytes);
      expect(t, contains('n'));
    });
    test('U15-P9 ô không tồn tại ở cột 0 ⇒ ô cột 1 đúng chỗ', () {
      final r = _xlsx([
        _sheet({(0, 1): _c('b')})
      ]);
      expect(_pos(r.bytes, 'b')!.$1, closeTo(_m + _colDef + 2, 1.5));
    });
    test('U15-P13 ô số ⇒ căn phải', () {
      final r = _xlsx([
        _sheet({(0, 0): _c('12', type: office.XlsxCellType.number)})
      ]);
      expect(_pos(r.bytes, '12')!.$3, closeTo(_m + _colDef - 2, 2));
    });
    test('U15-P14 ô ngày ⇒ căn phải', () {
      final r = _xlsx([
        _sheet({(0, 0): _c('1/1', type: office.XlsxCellType.date)})
      ]);
      expect(_pos(r.bytes, '1/1')!.$3, closeTo(_m + _colDef - 2, 2));
    });
    test('U15-P15 ô logic ⇒ căn phải', () {
      final r = _xlsx([
        _sheet({(0, 0): _c('TRUE', type: office.XlsxCellType.boolean)})
      ]);
      expect(_pos(r.bytes, 'TRUE')!.$3, closeTo(_m + _colDef - 2, 2));
    });
    for (final (id, al) in [
      ('U15-P17', office.XlsxHAlign.center),
      ('U15-P18', office.XlsxHAlign.centerContinuous),
    ]) {
      test('$id hAlign ${al.name} ⇒ căn giữa ô', () {
        final r = _xlsx([
          _sheet({(0, 0): _c('ab', style: office.XlsxStyle(hAlign: al))})
        ]);
        final p = _pos(r.bytes, 'ab')!;
        expect((p.$1 + p.$3) / 2, closeTo(_m + _colDef / 2, 2));
      });
    }
    test('U15-P19 hAlign right ⇒ căn phải', () {
      final r = _xlsx([
        _sheet({(0, 0): _c('ab', style: const office.XlsxStyle(hAlign: office.XlsxHAlign.right))})
      ]);
      expect(_pos(r.bytes, 'ab')!.$3, closeTo(_m + _colDef - 2, 2));
    });
    test('U15-P20 hAlign left với ô số ⇒ căn trái (khai báo thắng kiểu số)', () {
      final r = _xlsx([
        _sheet({
          (0, 0): _c('12', type: office.XlsxCellType.number, style: const office.XlsxStyle(hAlign: office.XlsxHAlign.left))
        })
      ]);
      expect(_pos(r.bytes, '12')!.$1, closeTo(_m + 2, 1.5));
    });
    test('U15-P23 ô chữ rỗng có nền ⇒ không có chữ, có màu nền', () {
      final r = _xlsx([
        _sheet({(0, 0): _c('', style: const office.XlsxStyle(fillArgb: 0xFF00FF00)), (0, 1): _c('k')})
      ]);
      expect(_content(r.bytes), matches(RegExp(r'0(\.0+)? 1(\.0+)? 0(\.0+)? rg')));
      expect(_allText(r.bytes).trim(), isNot(contains('S\n\n')));
    });
    test('U15-P33 cỡ chữ 14, đậm, nghiêng, màu ⇒ giữ định dạng', () {
      final f = _SpyFonts();
      _xlsx([
        _sheet({
          (0, 0): _c('f',
              style: const office.XlsxStyle(fontSizePt: 14, bold: true, italic: true, fontColorArgb: 0xFF0000FF))
        })
      ], fonts: f);
      final st = f.styleOf('f')!;
      expect(st.size, 14);
      expect(st.bold, isTrue);
      expect(st.italic, isTrue);
      expect(st.colorArgb, 0xFF0000FF);
    });
    test('U15-P40 ô có viền ⇒ viền đen', () {
      final r = _xlsx([
        _sheet({(0, 0): _c('a', style: const office.XlsxStyle(hasBorder: true))})
      ]);
      expect(_content(r.bytes), matches(RegExp(r'(^|\s)0(\.0+)? 0(\.0+)? 0(\.0+)? RG')));
    });
    test('U15-P1b (dữ liệu bổ sung) wrap=true chữ dài ⇒ xuống nhiều dòng', () {
      final long = List.filled(12, 'wrapword').join(' ');
      final r = _xlsx([
        _sheet({(0, 0): _c(long, style: const office.XlsxStyle(wrap: true))}, rowH: const {0: 200})
      ]);
      final words = _pages(r.bytes).expand((p) => p.lines).where((l) => l.text.contains('wrapword')).length;
      expect(words, greaterThan(1));
    });
  });
}
