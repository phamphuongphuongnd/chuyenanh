// Kiểm thử hộp trắng A14 — syncfusion_pdf_sign_engine.dart.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_sign_engine.dart';
import 'package:pdf_office/features/editor/syncfusion_pdf_sign_engine.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// PDF thử: mỗi phần tử là một trang 300×500 với góc xoay tương ứng.
Future<Uint8List> _makePdf(List<sf.PdfPageRotateAngle> rotations, {String? pw}) async {
  final doc = sf.PdfDocument();
  doc.compressionLevel = sf.PdfCompressionLevel.none;
  doc.pageSettings.size = const Size(300, 500);
  for (final r in rotations) {
    doc.pageSettings.rotate = r;
    doc.pages.add().graphics.drawString('page', sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12));
  }
  if (pw != null) {
    doc.security.userPassword = pw;
    doc.security.ownerPassword = pw;
  }
  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return bytes;
}

/// PDF thử nhiều section: mỗi trang một section riêng nên góc xoay từng trang khác nhau thật.
/// (Đã sửa test: `doc.pageSettings.rotate` đổi cả section chung nên `_makePdf([_rot0, _rot90])` ra 2 trang cùng xoay 90.)
Future<Uint8List> _makeMixed(List<sf.PdfPageRotateAngle> rotations) async {
  final doc = sf.PdfDocument();
  doc.compressionLevel = sf.PdfCompressionLevel.none;
  for (final r in rotations) {
    final sec = doc.sections!.add();
    sec.pageSettings.size = const Size(300, 500);
    sec.pageSettings.rotate = r;
    sec.pages.add().graphics.drawString('page', sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12));
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

/// Ma trận `a b c d e f cm` ngay trước lệnh vẽ ảnh `Do`.
List<List<double>> _imageMatrices(Uint8List pdf) {
  final text = String.fromCharCodes(pdf);
  final result = <List<double>>[];
  for (final m in RegExp(r'stream\r?\n').allMatches(text)) {
    final end = text.indexOf('endstream', m.end);
    if (end < 0) continue;
    String content;
    try {
      content = String.fromCharCodes(zlib.decode(pdf.sublist(m.end, end).toList()));
    } catch (_) {
      continue;
    }
    final re = RegExp(r'((?:-?[\d.]+\s+){5}-?[\d.]+)\s+cm\s+/\S+\s+Do');
    for (final mm in re.allMatches(content)) {
      result.add(mm.group(1)!.trim().split(RegExp(r'\s+')).map(double.parse).toList());
    }
  }
  return result;
}

const _rot0 = sf.PdfPageRotateAngle.rotateAngle0;
const _rot90 = sf.PdfPageRotateAngle.rotateAngle90;
const _rot180 = sf.PdfPageRotateAngle.rotateAngle180;
const _rot270 = sf.PdfPageRotateAngle.rotateAngle270;
const _pw = 'wb-test-pw'; // mật khẩu của PDF thử do test tự tạo

void main() {
  late Directory dir;
  const engine = SyncfusionPdfSignEngine();

  setUp(() {
    dir = Directory.systemTemp.createTempSync('wb_sign_');
    SyncfusionPdfSignEngine.debugClearPageSizeCache();
  });
  tearDown(() {
    SyncfusionPdfSignEngine.debugClearPageSizeCache();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<String> input(Uint8List bytes, [String name = 'in.pdf']) async {
    final path = p.join(dir.path, name);
    await File(path).writeAsBytes(bytes);
    return path;
  }

  String out([String name = 'out.pdf']) => p.join(dir.path, name);

  SignaturePlacement place(int page, Rect r, [Uint8List? png]) =>
      SignaturePlacement(pageIndex: page, bounds: r, pngBytes: png ?? _png(40, 20));

  Future<Object> apply(String inPath, List<SignaturePlacement> pl, String outPath, {String? password}) =>
      engine.applySignatures(inPath, pl, outPath, password: password).then<Object>((v) => v, onError: (Object e) => e);

  Future<Object> size(String inPath, int page, {String? password}) =>
      engine.pageSize(inPath, page, password: password).then<Object>((v) => v, onError: (Object e) => e);

  group('U1 applySignatures', () {
    test('U1.P1 trang thẳng ⇒ ghi file mới, ảnh đúng khung', () async {
      final i = await input(await _makePdf([_rot0]));
      final r = await apply(i, [place(0, const Rect.fromLTWH(20, 30, 100, 50))], out());
      expect(r, out());
      final m = _imageMatrices(await File(out()).readAsBytes()).single;
      expect(m[0], closeTo(100, 1e-6));
      expect(m[3], closeTo(50, 1e-6));
      expect(m[4], closeTo(20, 1e-6));
      expect(m[5], closeTo(-80, 1e-6));
    });
    test('U1.P2 file vào không tồn tại ⇒ AppError, không tạo file ra', () async {
      final r = await apply(p.join(dir.path, 'none.pdf'), const [], out());
      expect(r, isA<AppError>());
      expect(File(out()).existsSync(), isFalse);
    });
    test('U1.P3 trang không tồn tại ⇒ CorruptFile (AppError rethrow)', () async {
      final i = await input(await _makePdf([_rot0]));
      final r = await apply(i, [place(3, const Rect.fromLTWH(0, 0, 10, 10))], out());
      expect(r, isA<CorruptFile>());
      expect(File(out()).existsSync(), isFalse);
    });
    test('U1.P4 ảnh chữ ký hỏng trên trang thẳng ⇒ AppError (không văng lỗi lạ), không tạo file', () async {
      final i = await input(await _makePdf([_rot0]));
      final r = await apply(i, [place(0, const Rect.fromLTWH(0, 0, 10, 10), Uint8List.fromList([1, 2, 3]))], out());
      expect(r, isA<AppError>());
      expect(File(out()).existsSync(), isFalse);
    });
    test('U1.P5 thư mục cha của file ra là một file ⇒ AppError, không có file ra', () async {
      final i = await input(await _makePdf([_rot0]));
      final bad = p.join(i, 'out.pdf');
      final r = await apply(i, [place(0, const Rect.fromLTWH(0, 0, 10, 10))], bad);
      expect(r, isA<AppError>());
      expect(File(bad).existsSync(), isFalse);
    });
  });

  group('U2/U3/U4 pageSize', () {
    test('U2.P1 lần đầu ⇒ parse 1 lần, trả cỡ trang', () async {
      final i = await input(await _makeMixed([_rot0, _rot90]));
      expect(await size(i, 0), const Size(300, 500));
      expect(SyncfusionPdfSignEngine.debugPageSizeParseCount, 1);
    });
    test('U2.P2 file không tồn tại ⇒ AppError, không parse', () async {
      final r = await size(p.join(dir.path, 'none.pdf'), 0);
      expect(SyncfusionPdfSignEngine.debugPageSizeParseCount, 0);
      expect(r, isA<AppError>());
    });
    test('U2.P3 / U4.P1 gọi lại cùng file ⇒ dùng cache; trang xoay 90 hoán đổi', () async {
      final i = await input(await _makeMixed([_rot0, _rot90]));
      await size(i, 0);
      expect(await size(i, 1), const Size(500, 300));
      expect(SyncfusionPdfSignEngine.debugPageSizeParseCount, 1);
    });
    test('U2.P4 5 file khác nhau ⇒ cache giữ tối đa 4, file đầu bị parse lại', () async {
      final bytes = await _makePdf([_rot0]);
      final paths = [for (var k = 0; k < 5; k++) await input(bytes, 'f$k.pdf')];
      for (final x in paths) {
        await size(x, 0);
      }
      expect(SyncfusionPdfSignEngine.debugPageSizeParseCount, 5);
      await size(paths.last, 0); // còn trong cache
      expect(SyncfusionPdfSignEngine.debugPageSizeParseCount, 5);
      await size(paths.first, 0); // đã bị đẩy ra
      expect(SyncfusionPdfSignEngine.debugPageSizeParseCount, 6);
    });
    test('U2.P5 / U3.P3 PDF có mật khẩu, thiếu mật khẩu ⇒ PasswordRequired; lỗi không bị cache', () async {
      final i = await input(await _makePdf([_rot0], pw: _pw));
      final r = await size(i, 0);
      expect(r, isA<PasswordRequired>());
      expect(await size(i, 0, password: _pw), const Size(300, 500));
      expect(SyncfusionPdfSignEngine.debugPageSizeParseCount, 2);
    });
    test('U2.P6 pageIndex âm ⇒ CorruptFile', () async {
      final i = await input(await _makePdf([_rot0]));
      expect(await size(i, -1), isA<CorruptFile>());
    });
    test('U2.P7 pageIndex vượt số trang ⇒ CorruptFile', () async {
      final i = await input(await _makePdf([_rot0]));
      expect(await size(i, 5), isA<CorruptFile>());
    });
    test('U3.P2 đường dẫn là thư mục ⇒ đọc bytes lỗi ⇒ AppError', () async {
      final d = Directory(p.join(dir.path, 'folder.pdf'))..createSync();
      final r = await size(d.path, 0);
      expect(SyncfusionPdfSignEngine.debugPageSizeParseCount, 1);
      expect(r, isA<AppError>());
    });
  });

  group('U5 _apply / U9 _rotationDegrees', () {
    test('U5.P2 không có chữ ký nào ⇒ vẫn ghi file, không vẽ ảnh', () async {
      final i = await input(await _makePdf([_rot0, _rot0]));
      final r = await apply(i, const [], out());
      expect(r, out());
      final bytes = await File(out()).readAsBytes();
      expect(_imageMatrices(bytes), isEmpty);
      final d = sf.PdfDocument(inputBytes: bytes);
      expect(d.pages.count, 2);
      d.dispose();
    });
    test('U5.P5 trang xoay 90 + PNG hỏng ⇒ CorruptFile, không tạo file', () async {
      final i = await input(await _makePdf([_rot90]));
      final r = await apply(i, [place(0, const Rect.fromLTWH(0, 0, 10, 10), Uint8List.fromList([7, 7]))], out());
      expect(r, isA<CorruptFile>());
      expect(File(out()).existsSync(), isFalse);
    });
    test('U5.P4b trang xoay lẫn lộn (0° rồi 90°): ký trang 2 ⇒ đổi khung theo góc của chính trang đó', () async {
      final i = await input(await _makeMixed([_rot0, _rot90]));
      await apply(i, [place(1, const Rect.fromLTWH(100, 50, 200, 100))], out());
      final m = _imageMatrices(await File(out()).readAsBytes()).single;
      expect(m[0], closeTo(100, 1e-6));
      expect(m[3], closeTo(200, 1e-6));
      expect(m[4], closeTo(50, 1e-6));
      expect(m[5], closeTo(-400, 1e-6));
    });
    test('U9.P2 trang xoay 180 ⇒ khung đối xứng qua tâm (raw 180,420 100×50)', () async {
      final i = await input(await _makePdf([_rot180]));
      expect(await size(i, 0), const Size(300, 500));
      await apply(i, [place(0, const Rect.fromLTWH(20, 30, 100, 50))], out());
      final m = _imageMatrices(await File(out()).readAsBytes()).single;
      expect(m[0], closeTo(100, 1e-6));
      expect(m[3], closeTo(50, 1e-6));
      expect(m[4], closeTo(180, 1e-6));
      expect(m[5], closeTo(-470, 1e-6));
    });
    test('U9.P3 trang xoay 270 ⇒ cỡ nhìn thấy 500×300, khung raw (150,100) 100×200', () async {
      final i = await input(await _makePdf([_rot270]));
      expect(await size(i, 0), const Size(500, 300));
      await apply(i, [place(0, const Rect.fromLTWH(100, 50, 200, 100))], out());
      final m = _imageMatrices(await File(out()).readAsBytes()).single;
      expect(m[0], closeTo(100, 1e-6));
      expect(m[3], closeTo(200, 1e-6));
      expect(m[4], closeTo(150, 1e-6));
      expect(m[5], closeTo(-300, 1e-6));
    });
  });

  group('U6 rotatePngCounterClockwise', () {
    test('U6.P1 90 ⇒ hoán đổi rộng/cao', () {
      final r = img.decodePng(rotatePngCounterClockwise(_png(40, 20), 90))!;
      expect((r.width, r.height), (20, 40));
    });
    test('U6.P2 360 (chuẩn hoá về 0) ⇒ trả đúng đối tượng gốc', () {
      final src = _png(4, 2);
      expect(rotatePngCounterClockwise(src, 360), same(src));
    });
    test('U6.P3 bytes không phải PNG ⇒ CorruptFile', () {
      expect(() => rotatePngCounterClockwise(Uint8List.fromList([1, 2, 3]), 270), throwsA(isA<CorruptFile>()));
    });
  });

  group('U7 _open / U8 _page', () {
    test('U7.P2 có mật khẩu, không truyền ⇒ PasswordRequired', () async {
      final i = await input(await _makePdf([_rot0], pw: _pw));
      expect(await apply(i, [place(0, const Rect.fromLTWH(0, 0, 9, 9))], out()), isA<PasswordRequired>());
    });
    test('U7.P3 mật khẩu sai ⇒ WrongPassword', () async {
      final i = await input(await _makePdf([_rot0], pw: _pw));
      expect(await apply(i, [place(0, const Rect.fromLTWH(0, 0, 9, 9))], out(), password: 'sai'), isA<WrongPassword>());
    });
    test('U7.P4 mật khẩu rỗng ⇒ PasswordRequired', () async {
      final i = await input(await _makePdf([_rot0], pw: _pw));
      expect(await apply(i, [place(0, const Rect.fromLTWH(0, 0, 9, 9))], out(), password: ''), isA<PasswordRequired>());
    });
    test('U7.P5/P9 bytes rác ⇒ CorruptFile (ghi nhận loại lỗi gốc trong detail)', () async {
      for (final junk in [
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList('%PDF-1.4\n1 0 obj\n'.codeUnits),
      ]) {
        final i = await input(junk, 'junk${junk.length}.pdf');
        final r = await apply(i, [place(0, const Rect.fromLTWH(0, 0, 9, 9))], out());
        expect(r, isA<CorruptFile>());
        // ignore: avoid_print
        print('WB-A14 _open junk ${junk.length}B → detail: ${(r as CorruptFile).detail}');
      }
    });
    test('U8.P2 pageIndex âm ⇒ CorruptFile', () async {
      final i = await input(await _makePdf([_rot0]));
      expect(await apply(i, [place(-1, const Rect.fromLTWH(0, 0, 9, 9))], out()), isA<CorruptFile>());
    });
  });
}
