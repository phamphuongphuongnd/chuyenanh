// Kiểm thử hộp trắng (A04, chủ đề convert) — lib/features/convert/engine/pdf_extract.dart.
// Mã bộ = mã đường Bước 4/5: test-output/whitebox/convert/pdf_extract/buoc-5-du-lieu-thu.md.
// Expected chép từ Bước 5 (nguồn yêu cầu), KHÔNG chỉnh theo code.
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as office;
import 'package:pdf_layout/pdf_layout.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/convert/engine/pdf_extract.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

Uint8List _pdf(List<String> lines, {int pages = 1, String? password}) {
  final doc = sf.PdfDocument();
  for (var p = 0; p < pages; p++) {
    final page = doc.pages.add();
    for (var i = 0; i < lines.length; i++) {
      page.graphics.drawString('${lines[i]}${pages > 1 ? ' p$p' : ''}',
          sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
          bounds: Rect.fromLTWH(40, 40 + i * 20.0, 400, 20));
    }
  }
  if (password != null) {
    doc.security.userPassword = password;
    doc.security.ownerPassword = password;
  }
  final b = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return b;
}

final _garbage = Uint8List.fromList([1, 2, 3, 4]);

Object? _try(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

LayoutLine _line(int page, String text, double top) => LayoutLine(
    pageIndex: page,
    text: text,
    bounds: LayoutRect(left: 0, top: top, width: 100, height: 10),
    fontSize: 10);

void main() {
  group('U1 openPdfDocument', () {
    final plain = _pdf(['Hello']);
    final enc = _pdf(['Secret'], password: 'secret');

    test('U1-P1 PDF thường, không mật khẩu ⇒ mở được', () {
      final r = _try(() => openPdfDocument(plain));
      expect(r, isA<sf.PdfDocument>());
      expect((r as sf.PdfDocument).pages.count, 1);
      r.dispose();
    });

    test('U1-P2 PDF thường, có mật khẩu "abc" ⇒ vẫn mở được', () {
      final r = _try(() => openPdfDocument(plain, password: 'abc'));
      expect(r, isA<sf.PdfDocument>());
      (r as sf.PdfDocument).dispose();
    });

    test('U1-P3 PDF thường, mật khẩu rỗng ⇒ coi như không có, mở được', () {
      final r = _try(() => openPdfDocument(plain, password: ''));
      expect(r, isA<sf.PdfDocument>());
      (r as sf.PdfDocument).dispose();
    });

    test('U1-P4 PDF mã hoá, không mật khẩu ⇒ PasswordRequired', () {
      expect(_try(() => openPdfDocument(enc)), isA<PasswordRequired>());
    });

    test('U1-P6 byte rác ⇒ CorruptFile', () {
      expect(_try(() => openPdfDocument(_garbage)), isA<CorruptFile>());
    });

    test('U1-P10 PDF mã hoá, sai mật khẩu ⇒ WrongPassword', () {
      expect(_try(() => openPdfDocument(enc, password: 'nope')), isA<WrongPassword>());
    });

    test('U1-P11 PDF mã hoá, mật khẩu rỗng ⇒ PasswordRequired', () {
      expect(_try(() => openPdfDocument(enc, password: '')), isA<PasswordRequired>());
    });

    test('U1-P4b PDF mã hoá, đúng mật khẩu ⇒ mở được', () {
      final r = _try(() => openPdfDocument(enc, password: 'secret'));
      expect(r, isA<sf.PdfDocument>());
      (r as sf.PdfDocument).dispose();
    });
  });

  group('U2 extractLayoutPages', () {
    test('U2-P1 PDF 2 trang có chữ, có report ⇒ 2 LayoutPage đúng thứ tự, report tăng dần trong (0,1]', () {
      final progress = <double>[];
      final r = _try(() => extractLayoutPages(_pdf(['Line A', 'Line B'], pages: 2), report: progress.add));
      expect(progress, hasLength(2)); // nhánh: vòng chạy 2 lần, mỗi lần báo tiến độ
      expect(progress.first, greaterThan(0));
      expect(progress.last, lessThanOrEqualTo(1));
      expect(progress, orderedEquals([...progress]..sort()));
      expect(r, isA<List<LayoutPage>>());
      final pages = r as List<LayoutPage>;
      expect(pages.map((p) => p.index), [0, 1]);
      expect(pages[0].lines.map((l) => l.text).join('|'), contains('Line A p0'));
      expect(pages[1].lines.map((l) => l.text).join('|'), contains('Line B p1'));
    });

    test('U2-P2 byte rác ⇒ CorruptFile (từ openPdfDocument)', () {
      final progress = <double>[];
      final r = _try(() => extractLayoutPages(_garbage, report: progress.add));
      expect(progress, isEmpty);
      expect(r, isA<CorruptFile>());
    });

    test('U2-P5 không truyền report ⇒ vẫn trích được', () {
      final r = _try(() => extractLayoutPages(_pdf(['Only'])));
      expect((r as List<LayoutPage>).single.lines.single.text, contains('Only'));
    });

    test('U2-P6 report ném Cancelled ⇒ Cancelled lan ra nguyên loại', () {
      var calls = 0;
      final r = _try(() => extractLayoutPages(_pdf(['x'], pages: 2), report: (_) {
            calls++;
            throw const Cancelled();
          }));
      expect(calls, 1); // dừng ngay trang đầu
      expect(r, isA<Cancelled>());
    });

    // Sau khi sửa (PH): lỗi lập trình (callback report) không còn bị đổi thành CorruptFile.
    test('PH-U2-P7 report ném StateError ⇒ StateError nổi lên nguyên dạng (không thành AppError)', () {
      final r = _try(() => extractLayoutPages(_pdf(['x']), report: (_) => throw StateError('bug')));
      expect(r, isA<StateError>());
      expect(r, isNot(isA<AppError>()));
    });
  });

  group('U3 layoutPagesToText', () {
    test('U3-P1 2 trang ⇒ dòng nối \\n, bỏ khoảng trắng cuối dòng, trang cách một dòng trống, chữ Việt NFC', () {
      final r = layoutPagesToText([
        LayoutPage(index: 0, width: 100, height: 100, lines: [_line(0, 'Tiếng  ', 0), _line(0, 'b', 20)]),
        LayoutPage(index: 1, width: 100, height: 100, lines: [_line(1, 'c', 0)]),
      ]);
      expect(r, 'Tiếng\nb\n\nc');
    });

    test('U3-P2 không có trang ⇒ chuỗi rỗng', () {
      expect(layoutPagesToText(const []), '');
    });
  });

  group('U4 _sheetName (qua sheetGridsToXlsx)', () {
    List<String> names(List<String> raw) => office
        .readXlsx(sheetGridsToXlsx([for (final n in raw) SheetGrid(name: n, rows: const [['x']])]).bytes)
        .sheets
        .map((s) => s.name)
        .toList();

    test('U4-P1 tên hợp lệ giữ nguyên', () => expect(names(['Data']), ['Data']));
    test('U4-P2 tên toàn khoảng trắng ⇒ "Sheet"', () => expect(names(['   ']), ['Sheet']));
    test('U4-P3 tên 40 ký tự ⇒ cắt còn 31', () => expect(names(['A' * 40]), ['A' * 31]));
    test('U4-P4 trùng không phân biệt hoa thường ⇒ thêm " (2)"',
        () => expect(names(['Data', 'data']), ['Data', 'data (2)']));
    test('U4-P5 trùng tên dài 31 ⇒ cắt để tổng ≤ 31 rồi thêm " (2)"',
        () => expect(names(['B' * 31, 'B' * 31]), ['B' * 31, '${'B' * 27} (2)']));
    test('U4-P1b ký tự cấm []:*?/\\ được thay bằng _', () => expect(names(['a[b]:c*d?e/f\\g']), ['a_b__c_d_e_f_g']));
  });

  group('U5 sheetGridsToXlsx', () {
    office.XlsxWorkbook read(({Uint8List bytes, int cellCount}) r) => office.readXlsx(r.bytes);

    test('U5-P1 1 lưới [Name, 12], không bảng ⇒ chữ + số, 2 ô, cột A rộng 480px, cột B không đặt', () {
      final r = sheetGridsToXlsx(const [
        SheetGrid(name: 'S', rows: [
          ['Name', '12']
        ])
      ]);
      expect(r.cellCount, 2);
      final s = read(r).sheets.single;
      expect(s.cell(0, 0)!.display, 'Name');
      expect(s.cell(0, 0)!.type, office.XlsxCellType.string);
      expect(s.cell(0, 1)!.type, office.XlsxCellType.number);
      expect(s.columnWidthsChars[0], greaterThan(50)); // 480px
      expect(s.columnWidthsChars.containsKey(1), isFalse); // U5-P16: D15 S
    });

    test('U5-P2 danh sách rỗng ⇒ 1 sheet "Sheet1", 0 ô', () {
      final r = sheetGridsToXlsx(const []);
      expect(r.cellCount, 0);
      expect(read(r).sheets.map((s) => s.name), ['Sheet1']);
    });

    test('U5-P4 2 lưới ⇒ 2 sheet đúng thứ tự', () {
      final r = sheetGridsToXlsx(const [
        SheetGrid(name: 'One', rows: [['a']]),
        SheetGrid(name: 'Two', rows: [['b']]),
      ]);
      final wb = read(r);
      expect(wb.sheets.map((s) => s.name), ['One', 'Two']);
      expect(wb.sheets[1].cell(0, 0)!.display, 'b');
      expect(r.cellCount, 2);
    });

    test('U5-P5 lưới không có hàng ⇒ sheet trống, 0 ô', () {
      final r = sheetGridsToXlsx(const [SheetGrid(name: 'Empty', rows: [])]);
      expect(r.cellCount, 0);
      expect(read(r).sheets.single.cells, isEmpty);
    });

    test('U5-P6 hàng sau ngắn hơn ⇒ vẫn ghi đủ ô', () {
      final r = sheetGridsToXlsx(const [
        SheetGrid(name: 'S', rows: [
          ['a', 'b'],
          ['c']
        ])
      ]);
      expect(r.cellCount, 3);
      expect(read(r).sheets.single.cell(1, 0)!.display, 'c');
    });

    test('U5-P7 hàng rỗng ⇒ bỏ qua, hàng sau vẫn ở đúng chỉ số', () {
      final r = sheetGridsToXlsx(const [
        SheetGrid(name: 'S', rows: [
          [],
          ['z']
        ])
      ]);
      expect(r.cellCount, 1);
      expect(read(r).sheets.single.cell(1, 0)!.display, 'z');
    });

    test('U5-P8 ô chỉ khoảng trắng ⇒ không ghi, không đếm', () {
      final r = sheetGridsToXlsx(const [
        SheetGrid(name: 'S', rows: [
          ['  ', 'x']
        ])
      ]);
      expect(r.cellCount, 1);
      expect(read(r).sheets.single.cell(0, 0), isNull);
    });

    test('U5-P9 số thuần ("-3", "1.50") thành số; "007", "1e5" giữ chữ', () {
      final r = sheetGridsToXlsx(const [
        SheetGrid(name: 'S', rows: [
          ['-3', '1.50', '007', '1e5']
        ])
      ]);
      final s = read(r).sheets.single;
      expect(s.cell(0, 0)!.type, office.XlsxCellType.number);
      expect(s.cell(0, 1)!.type, office.XlsxCellType.number);
      expect(s.cell(0, 2)!.display, '007');
      expect(s.cell(0, 2)!.type, office.XlsxCellType.string);
      expect(s.cell(0, 3)!.type, office.XlsxCellType.string);
    });

    test('U5-P10 / U5-P15 có bảng ⇒ hàng đầu bảng in đậm, cột A tự co (không 480px)', () {
      final r = sheetGridsToXlsx(const [
        SheetGrid(name: 'S', rows: [
          ['H1', 'H2'],
          ['a', 'b'],
        ], tableRanges: [
          SheetTableRange(firstRow: 0, rowCount: 2, columnCount: 2)
        ])
      ]);
      final s = read(r).sheets.single;
      expect(s.cell(0, 0)!.style.bold, isTrue);
      expect(s.cell(1, 0)!.style.bold, isFalse);
      expect(s.columnWidthsChars[0] ?? 0, lessThan(50));
    });

    test('U5-P11 bảng 0 hàng ⇒ không in đậm', () {
      final r = sheetGridsToXlsx(const [
        SheetGrid(name: 'S', rows: [
          ['H1']
        ], tableRanges: [
          SheetTableRange(firstRow: 0, rowCount: 0, columnCount: 1)
        ])
      ]);
      expect(read(r).sheets.single.cell(0, 0)!.style.bold, isFalse);
    });

    test('U5-P13 có bảng, 31 cột ⇒ chỉ tự co tới cột 30, không lỗi', () {
      final row = [for (var i = 0; i < 31; i++) 'c$i'];
      final r = sheetGridsToXlsx([
        SheetGrid(name: 'S', rows: [row], tableRanges: const [SheetTableRange(firstRow: 0, rowCount: 1, columnCount: 31)])
      ]);
      expect(r.cellCount, 31);
      final s = read(r).sheets.single;
      expect(s.cell(0, 30)!.display, 'c30');
      expect(s.columnWidthsChars.containsKey(30), isFalse); // cột 31 không được đặt độ rộng
    });
  });
}
