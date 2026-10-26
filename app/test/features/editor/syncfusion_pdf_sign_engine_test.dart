import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_sign_engine.dart';
import 'package:pdf_office/features/editor/syncfusion_pdf_sign_engine.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Tạo PDF thử: mỗi phần tử [rotations] là một trang cỡ 300x500 với góc xoay tương ứng.
Future<Uint8List> _makePdf(
  List<sf.PdfPageRotateAngle> rotations, {
  String? userPassword,
}) async {
  final doc = sf.PdfDocument();
  doc.compressionLevel = sf.PdfCompressionLevel.none;
  doc.pageSettings.size = const Size(300, 500);
  for (final r in rotations) {
    doc.pageSettings.rotate = r;
    doc.pages.add().graphics.drawString(
      'page',
      sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
    );
  }
  if (userPassword != null) {
    doc.security.userPassword = userPassword;
    doc.security.ownerPassword = userPassword;
  }
  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return bytes;
}

Uint8List _png(int w, int h) {
  final image = img.Image(width: w, height: h, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(200, 0, 0, 255));
  return Uint8List.fromList(img.encodePng(image));
}

/// Các ma trận `a b c d e f cm` đứng ngay trước lệnh `Do` (vẽ ảnh) trong mọi stream nén.
List<List<double>> _imageMatrices(Uint8List pdf) {
  final text = String.fromCharCodes(pdf);
  final result = <List<double>>[];
  for (final m in RegExp(r'stream\r?\n').allMatches(text)) {
    final end = text.indexOf('endstream', m.end);
    if (end < 0) continue;
    String content;
    try {
      content = String.fromCharCodes(
        zlib.decode(pdf.sublist(m.end, end).toList()),
      );
    } catch (_) {
      continue;
    }
    final re = RegExp(
      r'((?:-?[\d.]+\s+){5}-?[\d.]+)\s+cm\s+/\S+\s+Do',
    );
    for (final mm in re.allMatches(content)) {
      result.add(
        mm.group(1)!.trim().split(RegExp(r'\s+')).map(double.parse).toList(),
      );
    }
  }
  return result;
}

void main() {
  late Directory dir;
  const engine = SyncfusionPdfSignEngine();

  setUp(() => dir = Directory.systemTemp.createTempSync('sign_engine_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<String> writeInput(Uint8List bytes) async {
    final path = '${dir.path}${Platform.pathSeparator}in.pdf';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  test('trang thang: dat anh dung khung, file moi, giu nguyen goc', () async {
    final input = await writeInput(
      await _makePdf([sf.PdfPageRotateAngle.rotateAngle0]),
    );
    final before = await File(input).readAsBytes();
    final out = '${dir.path}${Platform.pathSeparator}out.pdf';

    final result = await engine.applySignatures(input, [
      SignaturePlacement(
        pageIndex: 0,
        bounds: const Rect.fromLTWH(20, 30, 100, 50),
        pngBytes: _png(40, 20),
      ),
    ], out);

    expect(result, out);
    expect(await File(input).readAsBytes(), before); // không ghi đè gốc
    final bytes = await File(out).readAsBytes();
    final reopened = sf.PdfDocument(inputBytes: bytes);
    expect(reopened.pages.count, 1);
    reopened.dispose();

    final matrices = _imageMatrices(bytes);
    expect(matrices, hasLength(1));
    final m = matrices.single;
    // w 0 0 h x y: gốc dưới-trái sau khi lật → y = -(top + h) trong hệ đã tịnh tiến.
    expect(m[0], closeTo(100, 1e-6));
    expect(m[3], closeTo(50, 1e-6));
    expect(m[4], closeTo(20, 1e-6));
    expect(m[5], closeTo(-80, 1e-6));
  });

  test('chu ky o trang 2 khong anh huong trang 1', () async {
    final input = await writeInput(
      await _makePdf([
        sf.PdfPageRotateAngle.rotateAngle0,
        sf.PdfPageRotateAngle.rotateAngle0,
      ]),
    );
    final out = '${dir.path}${Platform.pathSeparator}out.pdf';
    await engine.applySignatures(input, [
      SignaturePlacement(
        pageIndex: 1,
        bounds: const Rect.fromLTWH(10, 10, 60, 30),
        pngBytes: _png(30, 15),
      ),
    ], out);
    final bytes = await File(out).readAsBytes();
    // Chỉ có đúng một ảnh vẽ ra trong toàn tài liệu.
    expect(_imageMatrices(bytes), hasLength(1));
    final doc = sf.PdfDocument(inputBytes: bytes);
    expect(doc.pages.count, 2);
    doc.dispose();
  });

  test('trang xoay 90: khung nhin thay doi sang khung chua xoay', () async {
    final input = await writeInput(
      await _makePdf([sf.PdfPageRotateAngle.rotateAngle90]),
    );
    // Trang thật 300x500, xoay 90 → nhìn thấy 500x300.
    expect(await engine.pageSize(input, 0), const Size(500, 300));

    final out = '${dir.path}${Platform.pathSeparator}out.pdf';
    await engine.applySignatures(input, [
      SignaturePlacement(
        pageIndex: 0,
        bounds: const Rect.fromLTWH(100, 50, 200, 100),
        pngBytes: _png(40, 20),
      ),
    ], out);
    final m = _imageMatrices(await File(out).readAsBytes()).single;
    // Khung visual (100,50)-(300,150) → raw: trái 50, trên 200, rộng 100, cao 200.
    expect(m[0], closeTo(100, 1e-6));
    expect(m[3], closeTo(200, 1e-6));
    expect(m[4], closeTo(50, 1e-6));
    expect(m[5], closeTo(-400, 1e-6));
  });

  test('khung tran ra ngoai trang bi keo vao trong', () async {
    final input = await writeInput(
      await _makePdf([sf.PdfPageRotateAngle.rotateAngle0]),
    );
    final out = '${dir.path}${Platform.pathSeparator}out.pdf';
    await engine.applySignatures(input, [
      SignaturePlacement(
        pageIndex: 0,
        bounds: const Rect.fromLTWH(250, 480, 100, 50),
        pngBytes: _png(40, 20),
      ),
    ], out);
    final m = _imageMatrices(await File(out).readAsBytes()).single;
    expect(m[4], closeTo(200, 1e-6)); // 300 - 100
    expect(m[5], closeTo(-500, 1e-6)); // top 450 + h 50
  });

  test('pageSize trang thang', () async {
    final input = await writeInput(
      await _makePdf([sf.PdfPageRotateAngle.rotateAngle0]),
    );
    expect(await engine.pageSize(input, 0), const Size(300, 500));
  });

  test('trang khong ton tai -> CorruptFile', () async {
    final input = await writeInput(
      await _makePdf([sf.PdfPageRotateAngle.rotateAngle0]),
    );
    await expectLater(
      engine.applySignatures(input, [
        SignaturePlacement(
          pageIndex: 3,
          bounds: const Rect.fromLTWH(0, 0, 10, 10),
          pngBytes: _png(4, 4),
        ),
      ], '${dir.path}${Platform.pathSeparator}out.pdf'),
      throwsA(isA<CorruptFile>()),
    );
    expect(File('${dir.path}${Platform.pathSeparator}out.pdf').existsSync(),
        isFalse);
  });

  test('file khong ton tai -> AppError', () async {
    await expectLater(
      engine.applySignatures(
        '${dir.path}${Platform.pathSeparator}none.pdf',
        const [],
        '${dir.path}${Platform.pathSeparator}out.pdf',
      ),
      throwsA(isA<AppError>()),
    );
  });

  test('PDF co mat khau: thieu / sai / dung', () async {
    final input = await writeInput(
      await _makePdf([
        sf.PdfPageRotateAngle.rotateAngle0,
      ], userPassword: 'abc'),
    );
    final out = '${dir.path}${Platform.pathSeparator}out.pdf';
    final placements = [
      SignaturePlacement(
        pageIndex: 0,
        bounds: const Rect.fromLTWH(10, 10, 50, 25),
        pngBytes: _png(20, 10),
      ),
    ];
    await expectLater(
      engine.applySignatures(input, placements, out),
      throwsA(isA<PasswordRequired>()),
    );
    await expectLater(
      engine.applySignatures(input, placements, out, password: 'sai'),
      throwsA(isA<WrongPassword>()),
    );
    await engine.applySignatures(input, placements, out, password: 'abc');
    // Kết quả vẫn mở được bằng mật khẩu cũ.
    final doc = sf.PdfDocument(
      inputBytes: await File(out).readAsBytes(),
      password: 'abc',
    );
    expect(doc.pages.count, 1);
    doc.dispose();
  });

  group('rotatePngCounterClockwise', () {
    test('xoay 90 doi rong/cao, 0 giu nguyen', () {
      final png = _png(40, 20);
      final r90 = img.decodePng(rotatePngCounterClockwise(png, 90))!;
      expect((r90.width, r90.height), (20, 40));
      expect(rotatePngCounterClockwise(png, 0), same(png));
      final r180 = img.decodePng(rotatePngCounterClockwise(png, 180))!;
      expect((r180.width, r180.height), (40, 20));
    });

    test('xoay nguoc chieu kim dong ho: goc tren-trai ve goc duoi-trai', () {
      final src = img.Image(width: 4, height: 2, numChannels: 4);
      img.fill(src, color: img.ColorRgba8(0, 0, 0, 0));
      src.setPixelRgba(0, 0, 255, 0, 0, 255); // chấm đỏ ở trên-trái
      final out = img.decodePng(
        rotatePngCounterClockwise(Uint8List.fromList(img.encodePng(src)), 90),
      )!;
      expect((out.width, out.height), (2, 4));
      expect(out.getPixel(0, 3).r, 255); // dưới-trái
      expect(out.getPixel(0, 3).a, 255);
      expect(out.getPixel(0, 0).a, 0);
    });

    test('PNG hong -> CorruptFile', () {
      expect(
        () => rotatePngCounterClockwise(Uint8List.fromList([1, 2, 3]), 90),
        throwsA(isA<CorruptFile>()),
      );
    });
  });
}
