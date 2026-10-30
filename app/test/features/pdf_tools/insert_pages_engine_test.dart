import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/insert_pages.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// PDF mẫu: trang i có chữ `<tag> page <i+1>`, khổ lấy từ [sizes] (xoay vòng).
Future<String> _makePdf(
  String dir,
  String name,
  int pages, {
  String tag = 'Doc',
  List<Size> sizes = const [Size(595, 842)],
  String? password,
}) async {
  final doc = sf.PdfDocument();
  for (var i = 0; i < pages; i++) {
    final section = doc.sections!.add();
    section.pageSettings.margins.all = 0;
    final size = sizes[i % sizes.length];
    section.pageSettings.orientation = size.width > size.height
        ? sf.PdfPageOrientation.landscape
        : sf.PdfPageOrientation.portrait;
    section.pageSettings.size = size;
    section.pages.add().graphics.drawString(
      '$tag page ${i + 1}',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 18),
      bounds: const Rect.fromLTWH(20, 20, 250, 30),
    );
  }
  if (password != null) {
    doc.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    doc.security.userPassword = password;
    doc.security.ownerPassword = password;
  }
  final path = p.join(dir, name);
  await File(path).writeAsBytes(await doc.save());
  doc.dispose();
  return path;
}

sf.PdfDocument _open(String path) =>
    sf.PdfDocument(inputBytes: File(path).readAsBytesSync());

String _text(sf.PdfDocument d, int page) => sf.PdfTextExtractor(
  d,
).extractText(startPageIndex: page, endPageIndex: page);

/// Nhãn từng trang: chữ `X page N` tìm được, hoặc `-` (trang không có chữ).
List<String> _labels(sf.PdfDocument d) => [
  for (var i = 0; i < d.pages.count; i++)
    RegExp(r'\w+ page \d+').firstMatch(_text(d, i))?.group(0) ?? '-',
];

Uint8List _png(int w, int h) => Uint8List.fromList(
  img.encodePng(img.Image(width: w, height: h)..clear(img.ColorRgb8(200, 30, 30))),
);

void main() {
  late Directory tmp;
  const engine = SyncfusionInsertPages();

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('insert_pages_test');
  });
  tearDown(() async {
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // Windows: isolate vừa bị kill (ca huỷ) có thể chưa nhả handle file → bỏ qua.
    }
  });

  test('3 trang, chèn 2 trang trắng sau trang 1 → 5 trang đúng thứ tự, gốc không đổi', () async {
    final src = await _makePdf(tmp.path, 'doc.pdf', 3);
    final before = File(src).readAsBytesSync();
    final out = p.join(tmp.path, 'doc_inserted.pdf');
    final progress = <double>[];
    final r = await engine.insertPages(
      src,
      1,
      const InsertBlank(2),
      out,
      onProgress: progress.add,
    );
    expect(r, out);
    final d = _open(out);
    expect(d.pages.count, 5);
    expect(_labels(d), ['Doc page 1', '-', '-', 'Doc page 2', 'Doc page 3']);
    expect(d.pages[1].size.width, closeTo(595, 0.5));
    expect(d.pages[1].size.height, closeTo(842, 0.5));
    d.dispose();
    expect(progress.last, 1);
    expect(File(src).readAsBytesSync(), before);
    expect(File('$out.tmp').existsSync(), isFalse);
  });

  test('trang trắng lấy khổ trang kề bên (trang trước chỗ chèn / trang đầu)', () async {
    final src = await _makePdf(
      tmp.path,
      'mixed.pdf',
      2,
      sizes: const [Size(595, 842), Size(842, 595)],
    );
    final atEnd = p.join(tmp.path, 'end.pdf');
    await engine.insertPages(src, 2, const InsertBlank(1), atEnd);
    final d = _open(atEnd);
    expect(_labels(d), ['Doc page 1', 'Doc page 2', '-']);
    expect(d.pages[2].size.width, closeTo(842, 0.5)); // như trang 2 (ngang)
    d.dispose();

    final atStart = p.join(tmp.path, 'start.pdf');
    await engine.insertPages(src, 0, const InsertBlank(1), atStart);
    final s = _open(atStart);
    expect(_labels(s), ['-', 'Doc page 1', 'Doc page 2']);
    expect(s.pages[0].size.width, closeTo(595, 0.5)); // như trang 1 (dọc)
    s.dispose();
  });

  test('trang từ PDF khác có mật khẩu: khoảng 2-3 chèn vào đầu', () async {
    final src = await _makePdf(tmp.path, 'doc.pdf', 2);
    final other = await _makePdf(tmp.path, 'other.pdf', 4, tag: 'B', password: 'pw');
    final out = p.join(tmp.path, 'out.pdf');
    await engine.insertPages(
      src,
      0,
      InsertPdfPages(other, password: 'pw', ranges: const [PageRange(2, 3)]),
      out,
    );
    final d = _open(out);
    expect(_labels(d), ['B page 2', 'B page 3', 'Doc page 1', 'Doc page 2']);
    d.dispose();

    // sai mật khẩu file nguồn trang → WrongPassword
    await expectLater(
      engine.insertPages(
        src,
        0,
        InsertPdfPages(other, password: 'nope'),
        p.join(tmp.path, 'bad.pdf'),
      ),
      throwsA(isA<WrongPassword>()),
    );
  });

  test('tất cả trang của PDF khác, chèn cuối', () async {
    final src = await _makePdf(tmp.path, 'doc.pdf', 1);
    final other = await _makePdf(tmp.path, 'b.pdf', 2, tag: 'B');
    final out = p.join(tmp.path, 'out.pdf');
    await engine.insertPages(src, 1, InsertPdfPages(other), out);
    final d = _open(out);
    expect(_labels(d), ['Doc page 1', 'B page 1', 'B page 2']);
    d.dispose();
  });

  test('ảnh: A4 theo hướng ảnh hoặc khổ trang kề bên', () async {
    final src = await _makePdf(tmp.path, 'doc.pdf', 2, sizes: const [Size(400, 600)]);
    final a4 = p.join(tmp.path, 'a4.pdf');
    await engine.insertPages(
      src,
      1,
      InsertImages([_png(40, 20), _png(20, 40)]),
      a4,
    );
    final d = _open(a4);
    expect(d.pages.count, 4);
    expect(_labels(d), ['Doc page 1', '-', '-', 'Doc page 2']);
    expect(d.pages[1].size.width, closeTo(841.89, 0.5)); // ảnh ngang → A4 ngang
    expect(d.pages[2].size.width, closeTo(595.28, 0.5));
    d.dispose();

    final nb = p.join(tmp.path, 'nb.pdf');
    await engine.insertPages(
      src,
      2,
      InsertImages([_png(40, 20)], fit: InsertImageFit.neighbor),
      nb,
    );
    final n = _open(nb);
    expect(n.pages.count, 3);
    expect(n.pages[2].size.width, closeTo(400, 0.5));
    expect(n.pages[2].size.height, closeTo(600, 0.5));
    n.dispose();
  });

  test('ảnh hỏng → CorruptFile, không để lại file', () async {
    final src = await _makePdf(tmp.path, 'doc.pdf', 1);
    final out = p.join(tmp.path, 'out.pdf');
    await expectLater(
      engine.insertPages(src, 1, InsertImages([Uint8List.fromList([1, 2, 3])]), out),
      throwsA(isA<CorruptFile>()),
    );
    expect(File(out).existsSync(), isFalse);
  });

  test('tham số sai: ghi đè gốc, số trang trắng, vị trí ngoài phạm vi', () async {
    final src = await _makePdf(tmp.path, 'doc.pdf', 2);
    await expectLater(
      engine.insertPages(src, 1, const InsertBlank(1), src),
      throwsArgumentError,
    );
    await expectLater(
      engine.insertPages(src, 1, const InsertBlank(51), p.join(tmp.path, 'x.pdf')),
      throwsRangeError,
    );
    await expectLater(
      engine.insertPages(src, 1, const InsertImages([]), p.join(tmp.path, 'x.pdf')),
      throwsArgumentError,
    );
    await expectLater(
      engine.insertPages(src, 3, const InsertBlank(1), p.join(tmp.path, 'x.pdf')),
      throwsRangeError,
    );
  });

  test('huỷ giữa chừng → Cancelled, không để lại file', () async {
    final src = await _makePdf(tmp.path, 'doc.pdf', 3);
    final out = p.join(tmp.path, 'out.pdf');
    final token = CancelToken();
    final f = engine.insertPages(src, 1, const InsertBlank(50), out, cancelToken: token);
    token.cancel();
    await expectLater(f, throwsA(isA<Cancelled>()));
    expect(File(out).existsSync(), isFalse);
  });
}
