import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_tools_engine.dart';
import 'package:pdf_office/features/pdf_tools/engine/page_numbers.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// PDF mẫu [pages] trang A4, nội dung KHÔNG có chữ số (để dò số trang vừa vẽ).
Future<String> _makePdf(
  String dir,
  String name,
  int pages, {
  String? password,
  Map<int, sf.PdfPageRotateAngle> rotations = const {},
}) async {
  final doc = sf.PdfDocument();
  doc.pageSettings.margins.all = 0;
  doc.pageSettings.size = const Size(595, 842);
  for (var i = 0; i < pages; i++) {
    doc.pages.add().graphics.drawString(
      'Body text',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 18),
      bounds: const Rect.fromLTWH(40, 300, 250, 30),
    );
  }
  var bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  if (rotations.isNotEmpty) {
    // Góc xoay chỉ đặt được trên trang đã nạp.
    final loaded = sf.PdfDocument(inputBytes: bytes);
    rotations.forEach((i, a) => loaded.pages[i].rotation = a);
    bytes = Uint8List.fromList(await loaded.save());
    loaded.dispose();
  }
  if (password != null) {
    final loaded = sf.PdfDocument(inputBytes: bytes);
    loaded.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    loaded.security.userPassword = password;
    loaded.security.ownerPassword = password;
    bytes = Uint8List.fromList(await loaded.save());
    loaded.dispose();
  }
  final path = p.join(dir, name);
  await File(path).writeAsBytes(bytes);
  return path;
}

sf.PdfDocument _open(String path, {String? password}) =>
    sf.PdfDocument(inputBytes: File(path).readAsBytesSync(), password: password);

String _textOf(sf.PdfDocument d, int page) => sf.PdfTextExtractor(
  d,
).extractText(startPageIndex: page, endPageIndex: page);

/// Dòng chữ đầu tiên của trang [page] khớp [pattern].
sf.TextLine? _lineOf(sf.PdfDocument d, int page, Pattern pattern) {
  final lines = sf.PdfTextExtractor(
    d,
  ).extractTextLines(startPageIndex: page, endPageIndex: page);
  for (final l in lines) {
    if (l.text.contains(pattern)) return l;
  }
  return null;
}

void main() {
  late Directory tmp;
  // Không nạp font từ assets qua rootBundle trong test.
  const engine = SyncfusionPageNumbers(fontLoader: null);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('page_numbers_test');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('3 trang, kiểu "1 / n" dưới giữa: mỗi trang có số, file gốc nguyên', () async {
    final src = await _makePdf(tmp.path, 'doc.pdf', 3);
    final out = p.join(tmp.path, 'doc_numbered.pdf');
    final progress = <double>[];
    final r = await engine.addPageNumbers(
      src,
      const PageNumberSpec(style: PageNumberStyle.ofTotal),
      out,
      onProgress: progress.add,
    );
    expect(r, out);
    final d = _open(out);
    expect(d.pages.count, 3);
    for (var i = 0; i < 3; i++) {
      expect(_textOf(d, i), matches(RegExp('${i + 1}\\s*/\\s*3')));
      expect(_textOf(d, i), contains('Body text'));
    }
    // Dưới giữa: dòng số nằm nửa dưới trang, quanh giữa chiều ngang.
    final line = _lineOf(d, 1, '2')!;
    expect(line.bounds.top, greaterThan(842 / 2));
    expect(line.bounds.center.dx, closeTo(595 / 2, 40));
    d.dispose();
    expect(progress.last, 1.0);
    expect(File('$out.tmp').existsSync(), isFalse);
    expect(_textOf(_open(src), 0), isNot(contains('1')));
  });

  test('kiểu "Page n", bắt đầu từ 5, bỏ bìa, vị trí trên trái', () async {
    final src = await _makePdf(tmp.path, 'a.pdf', 3);
    final out = p.join(tmp.path, 'a_numbered.pdf');
    await engine.addPageNumbers(
      src,
      const PageNumberSpec(
        style: PageNumberStyle.pageWord,
        pageWordTemplate: 'Page {n}',
        startNumber: 5,
        skipFirstPage: true,
        vAlign: PageNumberVAlign.top,
        hAlign: PageNumberHAlign.left,
      ),
      out,
    );
    final d = _open(out);
    expect(_textOf(d, 0), isNot(contains('Page')));
    expect(_textOf(d, 1), contains('Page 5'));
    expect(_textOf(d, 2), contains('Page 6'));
    final line = _lineOf(d, 2, 'Page')!;
    expect(line.bounds.top, lessThan(842 / 2));
    expect(line.bounds.left, lessThan(595 / 2));
    d.dispose();
  });

  test('chỉ đánh số khoảng trang đã chọn', () async {
    final src = await _makePdf(tmp.path, 'r.pdf', 3);
    final out = p.join(tmp.path, 'r_numbered.pdf');
    await engine.addPageNumbers(
      src,
      const PageNumberSpec(
        style: PageNumberStyle.dashed,
        ranges: [PageRange(2, 3)],
      ),
      out,
    );
    final d = _open(out);
    expect(_textOf(d, 0), isNot(contains('-')));
    expect(_textOf(d, 1), matches(RegExp(r'-\s*1\s*-')));
    expect(_textOf(d, 2), matches(RegExp(r'-\s*2\s*-')));
    d.dispose();
  });

  test('chữ CJK dùng font Noto nạp qua fontLoader', () async {
    final font = File('assets/fonts/NotoSansSC-Regular.ttf');
    final asked = <String>[];
    final cjk = SyncfusionPageNumbers(
      fontLoader: (text) {
        asked.add(text);
        return font.readAsBytesSync();
      },
    );
    final src = await _makePdf(tmp.path, 'c.pdf', 3);
    final out = p.join(tmp.path, 'c_numbered.pdf');
    await cjk.addPageNumbers(
      src,
      const PageNumberSpec(
        style: PageNumberStyle.pageWord,
        pageWordTemplate: '第 {n} 页',
      ),
      out,
    );
    expect(asked, ['第 1 页']);
    final d = _open(out);
    expect(_textOf(d, 2), contains('页'));
    expect(_textOf(d, 2), contains('3'));
    d.dispose();
  }, skip: !File('assets/fonts/NotoSansSC-Regular.ttf').existsSync());

  test('nhãn Latin-1 không nạp font', () async {
    final asked = <String>[];
    final e = SyncfusionPageNumbers(
      fontLoader: (text) {
        asked.add(text);
        return null;
      },
    );
    final src = await _makePdf(tmp.path, 'l.pdf', 1);
    await e.addPageNumbers(
      src,
      const PageNumberSpec(
        style: PageNumberStyle.pageWord,
        pageWordTemplate: 'Trang {n}',
      ),
      p.join(tmp.path, 'l_numbered.pdf'),
    );
    expect(asked, isEmpty);
  });

  test('trang xoay: vẫn có số, giữ góc xoay', () async {
    final src = await _makePdf(
      tmp.path,
      'rot.pdf',
      3,
      rotations: {
        1: sf.PdfPageRotateAngle.rotateAngle90,
        2: sf.PdfPageRotateAngle.rotateAngle270,
      },
    );
    final out = p.join(tmp.path, 'rot_numbered.pdf');
    await engine.addPageNumbers(
      src,
      const PageNumberSpec(style: PageNumberStyle.dashed),
      out,
    );
    final d = _open(out);
    expect(d.pages[1].rotation, sf.PdfPageRotateAngle.rotateAngle90);
    expect(d.pages[2].rotation, sf.PdfPageRotateAngle.rotateAngle270);
    for (var i = 0; i < 3; i++) {
      expect(_textOf(d, i), matches(RegExp('-\\s*${i + 1}\\s*-')));
    }
    d.dispose();
  });

  group('mật khẩu', () {
    test('đúng mật khẩu → kết quả mở được không cần mật khẩu', () async {
      final src = await _makePdf(tmp.path, 'lock.pdf', 2, password: 'pw');
      final out = p.join(tmp.path, 'lock_numbered.pdf');
      await engine.addPageNumbers(
        src,
        const PageNumberSpec(),
        out,
        password: 'pw',
      );
      final d = _open(out);
      expect(_textOf(d, 1), contains('2'));
      d.dispose();
    });

    test('thiếu / sai mật khẩu → lỗi tương ứng', () async {
      final src = await _makePdf(tmp.path, 'lock.pdf', 1, password: 'pw');
      final out = p.join(tmp.path, 'x.pdf');
      await expectLater(
        engine.addPageNumbers(src, const PageNumberSpec(), out),
        throwsA(isA<PasswordRequired>()),
      );
      await expectLater(
        engine.addPageNumbers(
          src,
          const PageNumberSpec(),
          out,
          password: 'nope',
        ),
        throwsA(isA<WrongPassword>()),
      );
      expect(File(out).existsSync(), isFalse);
    });
  });

  group('tham số sai / huỷ', () {
    test('không ghi đè file gốc', () async {
      final src = await _makePdf(tmp.path, 's.pdf', 1);
      expect(
        () => engine.addPageNumbers(src, const PageNumberSpec(), src),
        throwsArgumentError,
      );
    });

    test('cỡ chữ / số bắt đầu ngoài giới hạn', () async {
      final src = await _makePdf(tmp.path, 's.pdf', 1);
      final out = p.join(tmp.path, 'o.pdf');
      expect(
        () => engine.addPageNumbers(
          src,
          const PageNumberSpec(fontSize: 30),
          out,
        ),
        throwsArgumentError,
      );
      expect(
        () => engine.addPageNumbers(
          src,
          const PageNumberSpec(startNumber: 0),
          out,
        ),
        throwsRangeError,
      );
    });

    test('bỏ bìa trên PDF 1 trang → không còn trang để đánh số', () async {
      final src = await _makePdf(tmp.path, 'one.pdf', 1);
      final out = p.join(tmp.path, 'one_numbered.pdf');
      await expectLater(
        engine.addPageNumbers(
          src,
          const PageNumberSpec(skipFirstPage: true),
          out,
        ),
        throwsArgumentError,
      );
      expect(File(out).existsSync(), isFalse);
    });

    test('khoảng trang vượt số trang → FormatException', () async {
      final src = await _makePdf(tmp.path, 'two.pdf', 2);
      await expectLater(
        engine.addPageNumbers(
          src,
          const PageNumberSpec(ranges: [PageRange(1, 5)]),
          p.join(tmp.path, 'two_numbered.pdf'),
        ),
        throwsFormatException,
      );
    });

    test('đã huỷ trước khi chạy → Cancelled, không tạo file', () async {
      final src = await _makePdf(tmp.path, 'c.pdf', 2);
      final out = p.join(tmp.path, 'c_numbered.pdf');
      final token = CancelToken()..cancel();
      await expectLater(
        engine.addPageNumbers(
          src,
          const PageNumberSpec(),
          out,
          cancelToken: token,
        ),
        throwsA(isA<Cancelled>()),
      );
      expect(File(out).existsSync(), isFalse);
    });
  });
}
