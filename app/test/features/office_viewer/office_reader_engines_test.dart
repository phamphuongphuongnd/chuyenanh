import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/office/docx_engine.dart';
import 'package:pdf_office/engines/office/xlsx_engine.dart';
import 'package:pdf_office/features/office_viewer/data/office_reader_engines.dart';

import 'office_test_helpers.dart';

const _real = '../packages/office_reader/test/fixtures/real';

void main() {
  const docx = OfficeReaderDocxEngine();
  const xlsx = OfficeReaderXlsxEngine();

  group('DocxEngine', () {
    test('parseBytes: đoạn thường + đậm + heading', () async {
      final bytes = buildDocx(
        '${wPara('Xin chào', bold: true)}'
        '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Tiêu đề</w:t></w:r></w:p>',
      );
      final doc = await docx.parseBytes(bytes);
      final paras = doc.blocks.whereType<DocxParagraph>().toList();
      expect(paras.first.plainText, 'Xin chào');
      expect(paras.first.runs.single.bold, isTrue);
      expect(paras.length, 2);
    });

    test('bảng có ô gộp: colSpan và ô vMerge tiếp theo có rowSpan 0', () async {
      final bytes = buildDocx(
        '<w:tbl><w:tblGrid><w:gridCol w:w="2000"/><w:gridCol w:w="2000"/></w:tblGrid>'
        '<w:tr><w:tc><w:tcPr><w:gridSpan w:val="2"/></w:tcPr>${wPara('A')}</w:tc></w:tr>'
        '<w:tr><w:tc><w:tcPr><w:vMerge w:val="restart"/></w:tcPr>${wPara('B')}</w:tc><w:tc>${wPara('C')}</w:tc></w:tr>'
        '<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr>${wPara('')}</w:tc><w:tc>${wPara('D')}</w:tc></w:tr>'
        '</w:tbl>${wPara('sau bảng')}',
      );
      final doc = await docx.parseBytes(bytes);
      final table = doc.blocks.whereType<DocxTable>().single;
      expect(table.rows.length, 3);
      expect(table.rows[0].single.colSpan, 2);
      expect(table.rows[1][0].rowSpan, 2);
      expect(table.rows[2][0].rowSpan, 0);
      expect(table.columnWidths, [100.0, 100.0]);
    });

    test('file không phải zip → CorruptFile', () async {
      await expectLater(
        docx.parseBytes(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(isA<CorruptFile>()),
      );
    });

    test('file không tồn tại → CorruptFile', () async {
      await expectLater(
        docx.parseFile('khong_ton_tai_${DateTime.now().microsecond}.docx'),
        throwsA(isA<CorruptFile>()),
      );
    });

    test('file Word thật: parseFile ra nhiều khối', () async {
      final path = '$_real/word_full.docx';
      if (!File(path).existsSync()) {
        markTestSkipped('thiếu fixture');
        return;
      }
      final doc = await docx.parseFile(path);
      expect(doc.blocks, isNotEmpty);
      expect(doc.blocks.whereType<DocxParagraph>(), isNotEmpty);
    });
  });

  group('XlsxEngine', () {
    test('parseBytes: ô, vùng gộp, độ rộng cột đủ mọi cột', () async {
      final bytes = buildXlsx(
        {'A1': 'Tên', 'B1': 'Điểm', 'A2': 'An', 'B2': '9'},
        merges: '<mergeCells count="1"><mergeCell ref="A3:B4"/></mergeCells>',
      );
      final wb = await xlsx.parseBytes(bytes);
      final s = wb.sheets.single;
      expect(s.name, 'Data');
      expect(s.cellAt(0, 0)?.text, 'Tên');
      expect(s.cellAt(1, 1)?.text, '9');
      expect(s.merges.single.firstRow, 2);
      expect(s.merges.single.lastCol, 1);
      expect(s.colCount, 2);
      expect(s.columnWidths.keys, containsAll([0, 1]));
      expect(s.columnWidths[0], closeTo(8.43 * 7 + 5, 0.01));
    });

    test('file hỏng → CorruptFile', () async {
      await expectLater(
        xlsx.parseBytes(Uint8List.fromList(List.filled(20, 7))),
        throwsA(isA<CorruptFile>()),
      );
    });

    test('file Excel thật: có sheet và ô', () async {
      final path = '$_real/excel_full.xlsx';
      if (!File(path).existsSync()) {
        markTestSkipped('thiếu fixture');
        return;
      }
      final wb = await xlsx.parseFile(path);
      expect(wb.sheets, isNotEmpty);
      expect(wb.sheets.first.cells, isNotEmpty);
    });
  });
}
