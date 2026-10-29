import 'dart:io';

import 'package:flutter/material.dart' show Rect;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_layout/pdf_layout.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xio;

/// Đường dẫn các file mẫu do test tự sinh (không cần file nhị phân trong repo).
class Fixtures {
  const Fixtures({
    required this.pdf,
    required this.docx,
    required this.xlsx,
    required this.txt,
    required this.png,
    required this.jpg,
  });

  final String pdf;
  final String docx;
  final String xlsx;
  final String txt;
  final String png;
  final String jpg;
}

Future<Fixtures> makeFixtures() async {
  final base = await getTemporaryDirectory();
  final dir = Directory(p.join(base.path, 'ios_sim_fixtures'));
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  String at(String name) => p.join(dir.path, name);

  // PDF 2 trang, chữ Latin cơ bản (có font chuẩn nên không cần font Noto).
  final doc = PdfDocument();
  final font = PdfStandardFont(PdfFontFamily.helvetica, 20);
  for (var i = 1; i <= 2; i++) {
    final page = doc.pages.add();
    page.graphics.drawString(
      'Sample PDF - page $i',
      font,
      bounds: const Rect.fromLTWH(40, 40, 480, 40),
    );
    page.graphics.drawString(
      'Hello from PDF Office on iOS simulator',
      font,
      bounds: const Rect.fromLTWH(40, 90, 480, 40),
    );
  }
  File(at('sample.pdf')).writeAsBytesSync(doc.saveSync());
  doc.dispose();

  // DOCX: tiêu đề + 2 đoạn.
  File(at('sample.docx')).writeAsBytesSync(
    writeDocx(const [
      DocHeading(level: 1, spans: [DocSpan('Sample Word document')]),
      DocParagraph(spans: [DocSpan('First paragraph of the sample document.')]),
      DocParagraph(spans: [DocSpan('Second paragraph, with bold text.', bold: true)]),
    ]),
  );

  // XLSX: 3 dòng.
  final wb = xio.Workbook();
  final sheet = wb.worksheets[0];
  sheet.getRangeByName('A1').setText('Item');
  sheet.getRangeByName('B1').setText('Price');
  sheet.getRangeByName('A2').setText('Apple');
  sheet.getRangeByName('B2').setNumber(12);
  sheet.getRangeByName('A3').setText('Pear');
  sheet.getRangeByName('B3').setNumber(30);
  File(at('sample.xlsx')).writeAsBytesSync(wb.saveAsStream());
  wb.dispose();

  File(at('sample.txt')).writeAsStringSync(
    'Sample text file. Line one. Line two. PDF Office on iOS simulator.',
  );

  // 2 ảnh có hình khối để dễ nhìn trong ảnh chụp.
  img.Image photo(int r, int g, int b) {
    final image = img.Image(width: 600, height: 800);
    img.fill(image, color: img.ColorRgb8(r, g, b));
    img.fillRect(
      image,
      x1: 100,
      y1: 150,
      x2: 500,
      y2: 450,
      color: img.ColorRgb8(255, 255, 255),
    );
    return image;
  }

  File(at('photo1.png')).writeAsBytesSync(img.encodePng(photo(200, 60, 60)));
  File(at('photo2.jpg')).writeAsBytesSync(img.encodeJpg(photo(60, 90, 200)));

  return Fixtures(
    pdf: at('sample.pdf'),
    docx: at('sample.docx'),
    xlsx: at('sample.xlsx'),
    txt: at('sample.txt'),
    png: at('photo1.png'),
    jpg: at('photo2.jpg'),
  );
}
