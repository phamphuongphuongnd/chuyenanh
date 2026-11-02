// Kiểm thử hộp trắng A08 — data/docx_mapping.dart. Mã bộ = <đơn vị>-<đường> theo
// test-output/whitebox/office-viewer/docx_mapping/buoc-5-du-lieu-thu.md. Expected chép từ Bước 5.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as rd;
import 'package:pdf_office/engines/office/docx_engine.dart' as eng;
import 'package:pdf_office/features/office_viewer/data/docx_mapping.dart';

List<eng.DocxBlock> _map(List<rd.DocxBlock> blocks) =>
    mapDocx(rd.DocxDocument(blocks: blocks, page: rd.DocxPageSetup.a4)).blocks;

rd.DocxParagraph _p(
  List<rd.DocxInline> inlines, {
  int? heading,
  rd.DocxAlign align = rd.DocxAlign.left,
  int? listLevel,
  bool listOrdered = false,
}) => rd.DocxParagraph(
  inlines: inlines,
  headingLevel: heading,
  align: align,
  listLevel: listLevel,
  listOrdered: listOrdered,
);

rd.DocxImage _img([String ext = 'png']) => rd.DocxImage(
  bytes: Uint8List(0),
  extension: ext,
  widthEmu: 12700,
  heightEmu: 25400,
);

rd.DocxTable _table(rd.DocxTableCell cell, {List<int> widths = const [2000]}) =>
    rd.DocxTable(
      columnWidthsTwips: widths,
      rows: [rd.DocxTableRow(cells: [cell])],
    );

String _text(eng.DocxBlock b) => (b as eng.DocxParagraph).plainText;

void main() {
  group('U1 _mapBlocks', () {
    test('U1-P1 1 đoạn ⇒ 1 DocxParagraph', () {
      final out = _map([_p([const rd.DocxRun(text: 'A')])]);
      expect(out.map((b) => b.runtimeType).toList(), [eng.DocxParagraph]);
      expect(_text(out.single), 'A');
    });
    test('U1-P2 không khối ⇒ danh sách rỗng', () {
      expect(_map(const []), isEmpty);
    });
    test('U1-P3 bảng ⇒ DocxTable', () {
      final out = _map([_table(const rd.DocxTableCell(blocks: []))]);
      expect(out.single, isA<eng.DocxTable>());
    });
    test('U1-P4 ngắt trang ⇒ DocxPageBreak', () {
      final out = _map(const [rd.DocxPageBreak()]);
      expect(out.single, isA<eng.DocxPageBreak>());
    });
  });

  group('U2 _align', () {
    eng.DocxAlignment al(rd.DocxAlign a) =>
        (_map([_p(const [rd.DocxRun(text: 'x')], align: a)]).single
                as eng.DocxParagraph)
            .alignment;
    test('U2-P1 left ⇒ left', () => expect(al(rd.DocxAlign.left), eng.DocxAlignment.left));
    test('U2-P2 center ⇒ center', () => expect(al(rd.DocxAlign.center), eng.DocxAlignment.center));
    test('U2-P3 right ⇒ right', () => expect(al(rd.DocxAlign.right), eng.DocxAlignment.right));
    test('U2-P4 justify ⇒ justify', () => expect(al(rd.DocxAlign.justify), eng.DocxAlignment.justify));
  });

  group('U3 _mapParagraph', () {
    test('U3-P1 [Run A] ⇒ 1 đoạn chữ A', () {
      final out = _map([_p(const [rd.DocxRun(text: 'A')])]);
      expect(out.length, 1);
      expect(_text(out.single), 'A');
    });
    test('U3-P2 đoạn rỗng ⇒ vẫn giữ 1 đoạn trống', () {
      final out = _map([_p(const [])]);
      expect(out.length, 1);
      expect((out.single as eng.DocxParagraph).runs, isEmpty);
    });
    test('U3-P3 [Break] ⇒ 1 đoạn chữ "\\n"', () {
      final out = _map([_p(const [rd.DocxBreak()])]);
      expect(_text(out.single), '\n');
    });
    test('U3-P4 [Image] ⇒ chỉ khối ảnh, không đoạn chữ', () {
      final out = _map([_p([_img()])]);
      expect(out.map((b) => b.runtimeType).toList(), [eng.DocxImage]);
      final img = out.single as eng.DocxImage;
      expect(img.width, 1);
      expect(img.height, 2);
    });
    test('U3-P5 [Run A, Image] ⇒ đoạn A rồi ảnh', () {
      final out = _map([_p([const rd.DocxRun(text: 'A'), _img()])]);
      expect(out.map((b) => b.runtimeType).toList(), [eng.DocxParagraph, eng.DocxImage]);
      expect(_text(out[0]), 'A');
    });
    test('U3-P6 [Image, Run B] ⇒ ảnh rồi đoạn B', () {
      final out = _map([_p([_img(), const rd.DocxRun(text: 'B')])]);
      expect(out.map((b) => b.runtimeType).toList(), [eng.DocxImage, eng.DocxParagraph]);
      expect(_text(out[1]), 'B');
    });
    test('U3-P7 [Break, Image] ⇒ đoạn "\\n" rồi ảnh', () {
      final out = _map([_p([const rd.DocxBreak(), _img()])]);
      expect(out.map((b) => b.runtimeType).toList(), [eng.DocxParagraph, eng.DocxImage]);
      expect(_text(out[0]), '\n');
    });
  });

  group('U4 flush', () {
    eng.DocxParagraph one(rd.DocxParagraph p) => _map([p]).single as eng.DocxParagraph;
    test('U4-P1 heading 2, list 1 có số ⇒ giữ cả 3', () {
      final r = one(_p(const [rd.DocxRun(text: 'H')], heading: 2, listLevel: 1, listOrdered: true));
      expect(r.headingLevel, 2);
      expect(r.listLevel, 1);
      expect(r.listOrdered, isTrue);
    });
    test('U4-P2 headingLevel null ⇒ 0 (đoạn thường)', () {
      final r = one(_p(const [rd.DocxRun(text: 'H')], listLevel: 1, listOrdered: true));
      expect(r.headingLevel, 0);
    });
    test('U4-P3 list chấm (listOrdered false) ⇒ false', () {
      final r = one(_p(const [rd.DocxRun(text: 'H')], heading: 2, listLevel: 1));
      expect(r.listOrdered, isFalse);
      expect(r.listLevel, 1);
    });
    test('U4-P4 mảnh sau ảnh (first = false) ⇒ khối ảnh tách riêng, mảnh chữ còn lại là đoạn', () {
      final out = _map([
        _p([const rd.DocxRun(text: 'A'), _img(), const rd.DocxRun(text: 'B')],
            heading: 1, listLevel: 0, listOrdered: true),
      ]);
      // Nhánh: flush lần 2 chạy với first = false.
      expect(out.map((b) => b.runtimeType).toList(),
          [eng.DocxParagraph, eng.DocxImage, eng.DocxParagraph]);
      expect(_text(out[2]), 'B');
      // Đoạn đầu giữ heading/list (mảnh có first = true).
      expect((out[0] as eng.DocxParagraph).headingLevel, 1);
    });
  });

  group('U5 _contentType', () {
    String? ct(String ext) => (_map([_p([_img(ext)])]).single as eng.DocxImage).contentType;
    test('U5-P1 png ⇒ image/png', () => expect(ct('png'), 'image/png'));
    test('U5-P2 JPG ⇒ image/jpeg', () => expect(ct('JPG'), 'image/jpeg'));
    test('U5-P3 jpeg ⇒ image/jpeg', () => expect(ct('jpeg'), 'image/jpeg'));
    test('U5-P4 svg ⇒ image/svg+xml', () => expect(ct('svg'), 'image/svg+xml'));
    test('U5-P5 tif ⇒ image/tiff', () => expect(ct('tif'), 'image/tiff'));
    test('U5-P6 tiff ⇒ image/tiff', () => expect(ct('tiff'), 'image/tiff'));
  });

  group('U6 _mapTable', () {
    eng.DocxTableCell cell(rd.DocxTableCell c) =>
        (_map([_table(c)]).single as eng.DocxTable).rows.single.single;
    test('U6-P1 gridSpan 2, rowSpan 3 ⇒ colSpan 2, rowSpan 3; độ rộng twips/20', () {
      final t = _map([_table(const rd.DocxTableCell(blocks: [], gridSpan: 2, rowSpan: 3))]).single
          as eng.DocxTable;
      expect(t.rows.single.single.colSpan, 2);
      expect(t.rows.single.single.rowSpan, 3);
      expect(t.columnWidths, [100]);
    });
    test('U6-P2 gridSpan 0 ⇒ colSpan 1', () {
      expect(cell(const rd.DocxTableCell(blocks: [], gridSpan: 0)).colSpan, 1);
    });
    test('U6-P3 vMergeContinue ⇒ rowSpan 0', () {
      expect(cell(const rd.DocxTableCell(blocks: [], vMergeContinue: true, rowSpan: 2)).rowSpan, 0);
    });
    test('U6-P4 rowSpan 0 ⇒ rowSpan 1', () {
      expect(cell(const rd.DocxTableCell(blocks: [], rowSpan: 0)).rowSpan, 1);
    });
  });
}
