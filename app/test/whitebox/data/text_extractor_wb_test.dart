// Kiểm thử hộp trắng A12 — app/lib/features/content_index/data/text_extractor.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/content_index/data/text_extractor.dart';
import 'package:pptx_reader/pptx_reader.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../features/office_viewer/office_test_helpers.dart';

Uint8List _pdf(String text, {String? password}) {
  final d = sf.PdfDocument();
  d.pages.add().graphics.drawString(
    text,
    sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 18),
  );
  if (password != null) {
    d.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    d.security.userPassword = password;
    d.security.ownerPassword = password;
  }
  final b = Uint8List.fromList(d.saveSync());
  d.dispose();
  return b;
}

const _frame = PptxRect(0, 0, 10, 10);

PptxParagraph _para(List<PptxRun> runs) => PptxParagraph(runs: runs);
PptxRun _t(String s) => PptxRun(text: s);
const _br = PptxRun(text: '', isLineBreak: true);
PptxTextShape _text(String s) =>
    PptxTextShape(frame: _frame, paragraphs: [_para([_t(s)])]);
PptxDeck _deck(List<PptxShape> shapes, {String? notes}) => PptxDeck(
  slideWidthEmu: 10,
  slideHeightEmu: 10,
  slides: [
    PptxSlide(index: 0, background: null, shapes: shapes, notesText: notes),
  ],
);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('wb_a12_extract_'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows giữ handle chậm.
    }
  });

  String put(String name, List<int> bytes) {
    final f = File(p.join(dir.path, name))..writeAsBytesSync(bytes);
    return f.path;
  }

  group('U1 extractRawText', () {
    test('U1.1 pdf ⇒ chữ của trang', () {
      final path = put('a.pdf', _pdf('Hop dong mua ban'));
      expect(extractRawText(path, 'pdf'), contains('Hop dong mua ban'));
    });
    test('U1.1b pdf có mật khẩu ⇒ ném PasswordRequired', () {
      final path = put('k.pdf', _pdf('bi mat', password: 'abc'));
      final r = (() {
        try {
          return extractRawText(path, 'pdf');
        } catch (e) {
          return e;
        }
      })();
      expect(r, isA<PasswordRequired>());
    });
    test('U1.2 docx ⇒ chữ các đoạn', () {
      final path = put('a.docx', buildDocx(wPara('Xin chao') + wPara('Bao cao')));
      final t = extractRawText(path, 'docx');
      expect(t, contains('Xin chao'));
      expect(t, contains('Bao cao'));
    });
    test('U1.3 xlsx ⇒ chữ các ô', () {
      final path = put('a.xlsx', buildXlsx({'A1': 'Doanh thu', 'B2': 'Quy 3'}));
      final t = extractRawText(path, 'xlsx');
      expect(t, contains('Doanh thu'));
      expect(t, contains('Quy 3'));
    });
    test('U1.4 pptx hỏng ⇒ ném lỗi (bên gọi coi như không có chữ)', () {
      final path = put('a.pptx', [1, 2, 3, 4, 5]);
      Object? err;
      try {
        extractRawText(path, 'pptx');
      } catch (e) {
        err = e;
      }
      expect(err, isNotNull);
    });
    test('U1.5 txt nhỏ ⇒ đọc hết, giải mã UTF-8', () {
      final path = put('a.txt', utf8.encode('Hợp đồng\nmua bán'));
      expect(extractRawText(path, 'txt'), 'Hợp đồng\nmua bán');
    });
    test('U1.6 txt > 800000 byte ⇒ chỉ đọc phần đầu, vẫn đủ ≥ 200000 ký tự', () {
      final bytes = <int>[...List.filled(900000, 0x62), ...utf8.encode('ENDMARK')];
      final path = put('big.txt', bytes);
      final t = extractRawText(path, 'txt');
      expect(t.startsWith('bbbb'), isTrue);
      expect(t.contains('ENDMARK'), isFalse);
      expect(t.length, greaterThanOrEqualTo(200000));
      expect(t.length, lessThanOrEqualTo(800000));
    });
    test('U1.7 đuôi không hỗ trợ (doc) ⇒ chuỗi rỗng', () {
      final path = put('a.doc', [1, 2, 3]);
      expect(extractRawText(path, 'doc'), '');
    });
  });

  group('U2 pptxPlainText (vòng slide + ghi chú)', () {
    test('U2.1 một slide, không ghi chú ⇒ chữ hộp chữ', () {
      expect(pptxPlainText(_deck([_text('Tieu de')])), 'Tieu de\n');
    });
    test('U2.2 không có slide ⇒ rỗng', () {
      expect(
        pptxPlainText(const PptxDeck(slideWidthEmu: 1, slideHeightEmu: 1, slides: [])),
        '',
      );
    });
    test('U2.3 có ghi chú ⇒ thêm ghi chú người trình bày', () {
      expect(pptxPlainText(_deck([_text('A')], notes: 'Ghi chu')), 'A\nGhi chu\n');
    });
    test('U2.4 ghi chú rỗng ⇒ không thêm dòng', () {
      expect(pptxPlainText(_deck([_text('A')], notes: '')), 'A\n');
    });
  });

  group('U3 paragraphs', () {
    test('U3.1 đoạn có chữ ⇒ một dòng ghép các run', () {
      final s = PptxTextShape(frame: _frame, paragraphs: [_para([_t('Xin'), _t(' chao')])]);
      expect(pptxPlainText(_deck([s])), 'Xin chao\n');
    });
    test('U3.2 hộp chữ không có đoạn ⇒ không có dòng', () {
      expect(pptxPlainText(_deck([const PptxTextShape(frame: _frame)])), '');
    });
    test('U3.3 run xuống dòng ⇒ "\\n"', () {
      final s = PptxTextShape(frame: _frame, paragraphs: [_para([_t('a'), _br, _t('b')])]);
      expect(pptxPlainText(_deck([s])), 'a\nb\n');
    });
  });

  group('U4 shapes', () {
    PptxTableShape table(List<PptxTableRow> rows) =>
        PptxTableShape(frame: _frame, columnWidthsEmu: const [10], rows: rows);
    test('U4.1 hộp chữ ⇒ lấy chữ', () {
      expect(pptxPlainText(_deck([_text('X')])), 'X\n');
    });
    test('U4.2 slide không có hình ⇒ rỗng', () {
      expect(pptxPlainText(_deck(const [])), '');
    });
    test('U4.3 bảng 1×2 ⇒ chữ từng ô', () {
      final t = table([
        PptxTableRow(
          heightEmu: 1,
          cells: [
            PptxTableCell(paragraphs: [_para([_t('o1')])]),
            PptxTableCell(paragraphs: [_para([_t('o2')])]),
          ],
        ),
      ]);
      expect(pptxPlainText(_deck([t])), 'o1\no2\n');
    });
    test('U4.4 nhóm lồng nhóm ⇒ lấy chữ đệ quy', () {
      final g = PptxGroupShape(
        frame: _frame,
        children: [
          _text('ngoai'),
          PptxGroupShape(frame: _frame, children: [_text('trong')]),
        ],
      );
      expect(pptxPlainText(_deck([g])), 'ngoai\ntrong\n');
    });
    test('U4.5 ảnh ⇒ bỏ qua', () {
      final pic = PptxPictureShape(frame: _frame, bytes: Uint8List(0), extension: 'png');
      expect(pptxPlainText(_deck([pic, _text('sau anh')])), 'sau anh\n');
    });
    test('U4.6 bảng không có hàng ⇒ rỗng', () {
      expect(pptxPlainText(_deck([table(const [])])), '');
    });
    test('U4.7 hàng không có ô ⇒ rỗng', () {
      expect(pptxPlainText(_deck([table(const [PptxTableRow(heightEmu: 1, cells: [])])])), '');
    });
  });

  group('U5 extractTextInIsolate', () {
    test('U5.1 đọc được ⇒ PreparedText (content gốc + normalized)', () async {
      final path = put('a.txt', utf8.encode('Hợp   đồng\nmua bán'));
      final r = await extractTextInIsolate(path, 'txt');
      expect(r, isNotNull);
      expect(r!.content, 'Hợp đồng\nmua bán');
      expect(r.normalized, 'hop dong mua ban');
    });
    test('U5.2 file không có / PDF có mật khẩu ⇒ null', () async {
      expect(await extractTextInIsolate(p.join(dir.path, 'khong-co.pdf'), 'pdf'), isNull);
      final k = put('k.pdf', _pdf('bi mat', password: 'abc'));
      expect(await extractTextInIsolate(k, 'pdf'), isNull);
    });
  });
}

