// Kiểm thử hộp trắng (A15) — reflow_loader.dart. Mã bộ theo
// test-output/whitebox/reading/reflow_loader/buoc-5-du-lieu-thu.md. PDF tạo bằng Syncfusion trong thư mục tạm
// (không dùng PDF có mật khẩu).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/reading/data/reflow_loader.dart';
import 'package:pdf_office/features/reading/logic/reflow_document.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

Future<Uint8List> _pdf({String? text}) async {
  final doc = sf.PdfDocument();
  final page = doc.pages.add();
  if (text != null) {
    page.graphics.drawString(
      text,
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
    );
  }
  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return bytes;
}

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('wb_reflow_'));
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<Object> run(String path) =>
      loadReflowDocument(path).then((d) => d as Object, onError: (Object e) => e);

  test('1-1 PDF có chữ ⇒ ReflowDocument có đoạn chữ', () async {
    final f = File('${tmp.path}/text.pdf')
      ..writeAsBytesSync(await _pdf(text: 'Hello PDF Office'));
    final r = await run(f.path);
    expect(r, isA<ReflowDocument>());
    final doc = r as ReflowDocument;
    expect(doc.hasText, isTrue); // nhánh D4 S (có chữ ⇒ dựng khối)
    expect(doc.paragraphs.join(' '), contains('Hello PDF Office'));
  });

  test('1-2 file không tồn tại ⇒ CorruptFile', () async {
    final r = await run('${tmp.path}/khong-co.pdf');
    expect(r, isA<CorruptFile>());
  });

  test('1-3 đường dẫn là thư mục (Windows: Access denied, errno 5) ⇒ PermissionDenied', () async {
    final dir = Directory('${tmp.path}/thu-muc')..createSync();
    final r = await run(dir.path);
    expect(r, isA<PermissionDenied>());
  });

  test('1-4 bytes không phải PDF ⇒ CorruptFile', () async {
    final f = File('${tmp.path}/rac.pdf')..writeAsStringSync('không phải pdf');
    final r = await run(f.path);
    expect(r, isA<CorruptFile>());
  });

  test('1-5 PDF trang trắng (như bản quét) ⇒ ReflowDocument.empty giữ số trang', () async {
    final f = File('${tmp.path}/blank.pdf')..writeAsBytesSync(await _pdf());
    final r = await run(f.path);
    expect(r, isA<ReflowDocument>());
    final doc = r as ReflowDocument;
    expect(doc.items, isEmpty); // nhánh D4 Đ
    expect(doc.hasText, isFalse);
    expect(doc.pageCount, 1);
  });
}
