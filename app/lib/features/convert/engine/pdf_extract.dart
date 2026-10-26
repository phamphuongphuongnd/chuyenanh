// PDF → TXT / DOCX / XLSX. Đồng bộ, dùng được trong isolate.
import 'dart:typed_data';

import 'package:pdf_layout/pdf_layout.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xio;

import '../../../core/errors/app_error.dart';
import '../text/vietnamese_nfc.dart';

typedef Report = void Function(double progress);

/// PDF không có chữ trích được (thường là bản quét) — UI đổi thành thông báo riêng.
class NoTextFoundException implements Exception {
  const NoTextFoundException();
  @override
  String toString() => 'NoTextFoundException';
}

/// Mở PDF; đổi lỗi Syncfusion thành [AppError].
sf.PdfDocument openPdfDocument(Uint8List bytes, {String? password}) {
  try {
    return sf.PdfDocument(
      inputBytes: bytes,
      password: (password == null || password.isEmpty) ? null : password,
    );
  } on ArgumentError catch (e) {
    if (e.name == 'password' ||
        (e.message?.toString().toLowerCase().contains('password') ?? false)) {
      throw password == null || password.isEmpty
          ? const PasswordRequired()
          : const WrongPassword();
    }
    throw CorruptFile(e.toString());
  } catch (e) {
    throw CorruptFile(e.toString());
  }
}

/// Chuyển dòng chữ Syncfusion thành [LayoutLine] (toạ độ point, gốc trên-trái).
LayoutLine layoutLineFromTextLine(sf.TextLine l) => LayoutLine(
      pageIndex: l.pageIndex,
      text: l.text,
      bounds: LayoutRect(
        left: l.bounds.left,
        top: l.bounds.top,
        width: l.bounds.width,
        height: l.bounds.height,
      ),
      fontSize: l.fontSize,
      words: [
        for (final w in l.wordCollection)
          LayoutWord(
            text: w.text,
            bounds: LayoutRect(
              left: w.bounds.left,
              top: w.bounds.top,
              width: w.bounds.width,
              height: w.bounds.height,
            ),
            fontSize: w.fontSize,
            bold: w.fontStyle.contains(sf.PdfFontStyle.bold),
          ),
      ],
    );

/// Trích chữ cả tài liệu thành [LayoutPage]. Bỏ dòng rỗng.
List<LayoutPage> extractLayoutPages(
  Uint8List bytes, {
  String? password,
  Report? report,
}) {
  final doc = openPdfDocument(bytes, password: password);
  try {
    final extractor = sf.PdfTextExtractor(doc);
    final n = doc.pages.count;
    final pages = <LayoutPage>[];
    for (var i = 0; i < n; i++) {
      final size = doc.pages[i].size;
      final lines = extractor.extractTextLines(startPageIndex: i, endPageIndex: i);
      pages.add(LayoutPage(
        index: i,
        width: size.width,
        height: size.height,
        lines: [
          for (final l in lines)
            if (l.text.trim().isNotEmpty) layoutLineFromTextLine(l),
        ],
      ));
      report?.call((i + 1) / n * 0.8);
    }
    return pages;
  } on AppError {
    rethrow;
  } catch (e) {
    throw CorruptFile(e.toString());
  } finally {
    doc.dispose();
  }
}

bool hasAnyText(List<LayoutPage> pages) => pages.any((p) => p.lines.isNotEmpty);

/// Văn bản thuần: mỗi trang các dòng nối bằng `\n`, các trang cách nhau một dòng trống.
String layoutPagesToText(List<LayoutPage> pages) {
  final parts = <String>[];
  for (final p in pages) {
    final text = p.lines.map((l) => l.text.trimRight()).join('\n');
    parts.add(composeVietnamese(text));
  }
  return parts.join('\n\n');
}

/// PDF → byte DOCX.
Uint8List layoutPagesToDocx(List<LayoutPage> pages) =>
    writeDocx(rebuildDocument(pages));

final _plainNumber = RegExp(r'^-?(0|[1-9]\d{0,14})(\.\d+)?$');

String _sheetName(String raw, Set<String> used) {
  var name = raw.replaceAll(RegExp(r'[\[\]:*?/\\]'), '_').trim();
  if (name.isEmpty) name = 'Sheet';
  if (name.length > 31) name = name.substring(0, 31);
  var candidate = name;
  var i = 2;
  while (used.contains(candidate.toLowerCase())) {
    final suffix = ' ($i)';
    candidate = name.substring(0, name.length > 31 - suffix.length ? 31 - suffix.length : name.length) + suffix;
    i++;
  }
  used.add(candidate.toLowerCase());
  return candidate;
}

/// Ghi các lưới thành byte XLSX; trả về cả số ô đã ghi.
({Uint8List bytes, int cellCount}) sheetGridsToXlsx(List<SheetGrid> grids) {
  final wb = xio.Workbook();
  try {
    final used = <String>{};
    var cellCount = 0;
    final list = grids.isEmpty ? [const SheetGrid(name: 'Sheet1', rows: [])] : grids;
    for (var gi = 0; gi < list.length; gi++) {
      final g = list[gi];
      final xio.Worksheet sheet;
      final name = _sheetName(g.name, used);
      if (gi == 0) {
        sheet = wb.worksheets[0];
        sheet.name = name;
      } else {
        sheet = wb.worksheets.addWithName(name);
      }
      var maxCols = 0;
      for (var r = 0; r < g.rows.length; r++) {
        final row = g.rows[r];
        if (row.length > maxCols) maxCols = row.length;
        for (var c = 0; c < row.length; c++) {
          final text = composeVietnamese(row[c]).trim();
          if (text.isEmpty) continue;
          final cell = sheet.getRangeByIndex(r + 1, c + 1);
          if (_plainNumber.hasMatch(text)) {
            cell.setNumber(double.parse(text));
          } else {
            cell.setText(text);
          }
          cellCount++;
        }
      }
      for (final t in g.tableRanges) {
        if (t.rowCount > 0) {
          sheet.getRangeByIndex(t.firstRow + 1, 1, t.firstRow + 1, t.columnCount).cellStyle.bold = true;
        }
      }
      for (var c = 1; c <= maxCols && c <= 30; c++) {
        // Cột A chứa cả đoạn văn dài nên không tự co giãn; các cột bảng thì có.
        if (c == 1 && g.tableRanges.isEmpty) {
          sheet.setColumnWidthInPixels(1, 480);
        } else if (g.tableRanges.isNotEmpty) {
          sheet.autoFitColumn(c);
        }
      }
    }
    final out = wb.saveAsStream();
    return (bytes: Uint8List.fromList(out), cellCount: cellCount);
  } finally {
    wb.dispose();
  }
}

/// PDF → byte XLSX.
({Uint8List bytes, int cellCount}) layoutPagesToXlsx(List<LayoutPage> pages) =>
    sheetGridsToXlsx(detectSheets(pages));
