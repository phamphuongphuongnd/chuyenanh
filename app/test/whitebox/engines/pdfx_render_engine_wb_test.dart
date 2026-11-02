// Kiểm thử hộp trắng A11 — lib/engines/pdf/pdfx_render_engine.dart.
// Mã bộ = mã ở test-output/whitebox/engines/pdfx_render_engine/buoc-5-du-lieu-thu.md.
// pdfx là plugin: phần plugin (PdfDocument/PdfPage) được mock; hàm thuần kiểm trực tiếp.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/engines/pdf/pdf_security.dart';
import 'package:pdf_office/engines/pdf/pdfx_render_engine.dart';
import 'package:pdf_office/engines/pdf/syncfusion_pdf_security.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class _MockDoc extends Mock implements pdfx.PdfDocument {}

class _MockPage extends Mock implements pdfx.PdfPage {}

class _FakeImage extends Fake implements pdfx.PdfPageImage {
  _FakeImage(this.bytes);
  @override
  final Uint8List bytes;
}

/// Bọc SyncfusionPdfSecurity thật, ghi lại lời gọi + lỗi để khẳng định nhánh đã đi.
class _SpySecurity implements PdfSecurityEngine {
  final _real = const SyncfusionPdfSecurity();
  final calls = <String>[];
  Object? isEncryptedError;
  bool? isEncryptedResult;

  @override
  Future<bool> isEncrypted(Uint8List bytes) async {
    calls.add('isEncrypted');
    try {
      return isEncryptedResult = await _real.isEncrypted(bytes);
    } catch (e) {
      isEncryptedError = e;
      rethrow;
    }
  }

  @override
  Future<Uint8List> decrypt(Uint8List bytes, String password) {
    calls.add('decrypt');
    return _real.decrypt(bytes, password);
  }

  @override
  Future<Uint8List> encrypt(
    Uint8List bytes,
    String userPassword, {
    String? ownerPassword,
  }) => _real.encrypt(bytes, userPassword, ownerPassword: ownerPassword);
}

Future<Uint8List> _samplePdf({String? userPassword}) async {
  final doc = sf.PdfDocument();
  doc.pages.add().graphics.drawString(
    'Hello',
    sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14),
  );
  if (userPassword != null) {
    doc.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    doc.security.userPassword = userPassword;
    doc.security.ownerPassword = userPassword;
  }
  final bytes = Uint8List.fromList(await doc.save());
  doc.dispose();
  return bytes;
}

/// Bắt kết quả trước (giá trị hoặc lỗi) để khẳng định nhánh rồi mới khẳng định kết quả.
Future<Object?> _capture(Future<Object?> f) => f.then((v) => v, onError: (Object e) => e);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late _MockDoc doc;
  late _MockPage page;
  late _SpySecurity security;
  late List<String> openFileCalls;
  late List<Uint8List> openDataCalls;

  setUpAll(() {
    registerFallbackValue(pdfx.PdfPageImageFormat.jpeg);
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('wb_a11_pdfx_');
    doc = _MockDoc();
    page = _MockPage();
    security = _SpySecurity();
    openFileCalls = [];
    openDataCalls = [];
    when(() => doc.pagesCount).thenReturn(3);
    when(() => doc.close()).thenAnswer((_) async {});
    when(() => doc.getPage(any())).thenAnswer((_) async => page);
    when(() => page.width).thenReturn(595.28);
    when(() => page.height).thenReturn(841.89);
    when(() => page.isClosed).thenReturn(false);
    when(() => page.close()).thenAnswer((_) async {});
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  PdfxRenderEngine engineWith({
    Future<pdfx.PdfDocument> Function(String)? openFile,
    Future<pdfx.PdfDocument> Function(Uint8List)? openData,
  }) => PdfxRenderEngine(
    security: security,
    openFile:
        openFile ??
        (path) async {
          openFileCalls.add(path);
          return doc;
        },
    openData:
        openData ??
        (d) async {
          openDataCalls.add(d);
          return doc;
        },
  );

  Future<String> writePdf(String name, Uint8List bytes) async {
    final f = File(p.join(tmp.path, name));
    await f.writeAsBytes(bytes);
    return f.path;
  }

  void stubRender(Future<pdfx.PdfPageImage?> Function() answer) {
    when(
      () => page.render(
        width: any(named: 'width'),
        height: any(named: 'height'),
        format: any(named: 'format'),
        backgroundColor: any(named: 'backgroundColor'),
        quality: any(named: 'quality'),
        forPrint: any(named: 'forPrint'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<PdfRenderDocument> openDoc() => engineWith().openBytes(Uint8List(1));

  // ---------------- U1 isRenderOutOfMemory ----------------
  group('U1 isRenderOutOfMemory', () {
    test('OOM-1 OutOfMemoryError ⇒ true (M1 Đ)', () {
      expect(isRenderOutOfMemory(OutOfMemoryError()), isTrue);
    });
    test('OOM-2 PlatformException message chứa OutOfMemory ⇒ true (M3 Đ)', () {
      expect(
        isRenderOutOfMemory(
          PlatformException(code: 'render', message: 'java.lang.OutOfMemoryError'),
        ),
        isTrue,
      );
    });
    test('OOM-3 PlatformException details "out of memory" ⇒ true (M3 S, M4 Đ)', () {
      expect(
        isRenderOutOfMemory(
          PlatformException(code: 'render', details: 'Bitmap: Out Of Memory'),
        ),
        isTrue,
      );
    });
    test('OOM-4 PlatformException không nói bộ nhớ ⇒ false (M4 S)', () {
      expect(
        isRenderOutOfMemory(PlatformException(code: 'x', message: 'closed')),
        isFalse,
      );
    });
    test('OOM-5 lỗi khác loại ⇒ false (M2 S)', () {
      expect(isRenderOutOfMemory(StateError('oom')), isFalse);
    });
  });

  // ---------------- U2 computeRenderSize ----------------
  group('U2 computeRenderSize', () {
    const a4 = PdfPageSize(595.28, 841.89);
    test('RS-1 dpi 300 hữu hạn > 0, dưới trần ⇒ 2480×3508 (C1 Đ, C2 Đ, C3 S)', () {
      final s = computeRenderSize(a4, 300);
      expect((s.width, s.height), (2480, 3508));
    });
    test('RS-2 dpi vô hạn / NaN ⇒ coi như 72 dpi (C1 S)', () {
      final inf = computeRenderSize(a4, double.infinity);
      final nan = computeRenderSize(a4, double.nan);
      expect((inf.width, inf.height), (595, 842));
      expect((nan.width, nan.height), (595, 842));
    });
    test('RS-3 dpi 0 / âm ⇒ coi như 72 dpi (C2 S)', () {
      final zero = computeRenderSize(a4, 0);
      final neg = computeRenderSize(a4, -150);
      expect((zero.width, zero.height), (595, 842));
      expect((neg.width, neg.height), (595, 842));
    });
    test('RS-4 vượt trần ⇒ thu nhỏ giữ tỉ lệ, ≤ trần, mỗi cạnh ≥ 1 (C3 Đ)', () {
      final s = computeRenderSize(const PdfPageSize(2384, 3370), 300);
      expect(s.width * s.height, lessThanOrEqualTo(kMaxRenderPixels));
      expect(s.width / s.height, closeTo(2384 / 3370, 0.01));
      final thin = computeRenderSize(
        const PdfPageSize(10000, 0.01),
        72,
        maxPixels: 100,
      );
      expect(thin.width, greaterThanOrEqualTo(1));
      expect(thin.height, greaterThanOrEqualTo(1));
    });
  });

  // ---------------- U3 computeThumbnailSize ----------------
  group('U3 computeThumbnailSize', () {
    test('TS-1 trang 0×0 ⇒ maxSide × maxSide (T1 Đ)', () {
      final s = computeThumbnailSize(const PdfPageSize(0, 0), 300);
      expect((s.width, s.height), (300, 300));
    });
    test('TS-2 trang dọc ⇒ cạnh dài = maxSide, giữ tỉ lệ (T1 S)', () {
      final s = computeThumbnailSize(const PdfPageSize(600, 800), 300);
      expect((s.width, s.height), (225, 300));
    });
  });

  // ---------------- U4 constructor ----------------
  group('U4 PdfxRenderEngine()', () {
    test('CT-1 không tiêm openFile/openData ⇒ dùng pdfx mặc định (O1 Đ, O2 Đ)', () async {
      final e = PdfxRenderEngine(security: security);
      final rBytes = await _capture(e.openBytes(Uint8List.fromList([1, 2])));
      final path = await writePdf('a.pdf', await _samplePdf());
      final rFile = await _capture(e.openFile(path));
      // Nhánh: không có hàm tiêm nào được gọi; pdfx mặc định không có plugin trong test.
      expect(openFileCalls, isEmpty);
      expect(openDataCalls, isEmpty);
      expect(security.calls, ['isEncrypted']);
      expect(rBytes, isA<CorruptFile>());
      expect(rFile, isA<CorruptFile>());
    });
    test('CT-2 chỉ tiêm openFile ⇒ openFile tiêm, openData mặc định (O1 S, O2 Đ)', () async {
      final e = PdfxRenderEngine(
        security: security,
        openFile: (path) async {
          openFileCalls.add(path);
          return doc;
        },
      );
      final path = await writePdf('a.pdf', await _samplePdf());
      final d = await e.openFile(path);
      final rBytes = await _capture(e.openBytes(Uint8List.fromList([1])));
      expect(openFileCalls, [path]);
      expect(d.pageCount, 3);
      expect(rBytes, isA<CorruptFile>());
    });
    test('CT-3 tiêm cả hai ⇒ cả hai hàm tiêm được dùng (O1 S, O2 S)', () async {
      final e = engineWith();
      final path = await writePdf('a.pdf', await _samplePdf());
      await e.openFile(path);
      await e.openBytes(Uint8List.fromList([7]));
      expect(openFileCalls, [path]);
      expect(openDataCalls.single, [7]);
    });
  });

  // ---------------- U5 openFile ----------------
  group('U5 openFile', () {
    test('OF-1 không mật khẩu, mở được ⇒ trả tài liệu (D1 S, D7 S)', () async {
      final path = await writePdf('a.pdf', await _samplePdf());
      final r = await _capture(engineWith().openFile(path));
      expect(openFileCalls, [path]);
      expect(openDataCalls, isEmpty);
      expect(security.calls, isEmpty);
      expect(r, isA<PdfRenderDocument>());
      expect((r as PdfRenderDocument).pageCount, 3);
    });
    test('OF-2 đúng mật khẩu ⇒ giải mã rồi openData (D1 Đ, D2 Đ, D3 S, D5 S, D6 S)', () async {
      final path = await writePdf('l.pdf', await _samplePdf(userPassword: 'secret'));
      final r = await _capture(engineWith().openFile(path, password: 'secret'));
      expect(security.calls, ['decrypt']);
      expect(openFileCalls, isEmpty);
      expect(openDataCalls, hasLength(1));
      expect(r, isA<PdfRenderDocument>());
      final plain = sf.PdfDocument(inputBytes: openDataCalls.single);
      expect(plain.pages.count, 1);
      plain.dispose();
    });
    test('OF-3 mật khẩu rỗng ⇒ coi như không mật khẩu (D2 S)', () async {
      final path = await writePdf('a.pdf', await _samplePdf());
      final r = await _capture(engineWith().openFile(path, password: ''));
      expect(security.calls, isEmpty);
      expect(openFileCalls, [path]);
      expect(r, isA<PdfRenderDocument>());
    });
    test('OF-4 có mật khẩu, file không tồn tại ⇒ CorruptFile (D3 Đ, D4 Đ)', () async {
      final r = await _capture(
        engineWith().openFile(p.join(tmp.path, 'missing.pdf'), password: 'secret'),
      );
      expect(security.calls, isEmpty);
      expect(r, isA<CorruptFile>());
    });
    test('OF-5 có mật khẩu, không đọc được do thiếu quyền ⇒ AppError tương ứng, không phải Unknown (D4 S)', () async {
      // Windows: đọc một thư mục như file ⇒ errno 5 (Access denied).
      final r = await _capture(engineWith().openFile(tmp.path, password: 'secret'));
      expect(security.calls, isEmpty);
      expect(r, isA<PermissionDenied>());
    });
    test('OF-6 sai mật khẩu ⇒ WrongPassword, không openData (D5 Đ)', () async {
      final path = await writePdf('l.pdf', await _samplePdf(userPassword: 'secret'));
      final r = await _capture(engineWith().openFile(path, password: 'nope'));
      expect(security.calls, ['decrypt']);
      expect(openDataCalls, isEmpty);
      expect(r, isA<WrongPassword>());
    });
    test('OF-7 giải mã xong nhưng pdfx không mở được bytes ⇒ CorruptFile (D6 Đ)', () async {
      final path = await writePdf('l.pdf', await _samplePdf(userPassword: 'secret'));
      final e = engineWith(openData: (_) async => throw StateError('pdfx data'));
      final r = await _capture(e.openFile(path, password: 'secret'));
      expect(security.calls, ['decrypt']);
      expect(r, isA<CorruptFile>());
    });
    test('OF-8 pdfx từ chối, file có mật khẩu ⇒ PasswordRequired (D7 Đ, D8 S, D9 S, D10 Đ)', () async {
      final path = await writePdf('l.pdf', await _samplePdf(userPassword: 'secret'));
      final e = engineWith(openFile: (_) async => throw StateError('boom'));
      final r = await _capture(e.openFile(path));
      expect(security.calls, ['isEncrypted']);
      expect(security.isEncryptedResult, isTrue);
      expect(r, isA<PasswordRequired>());
    });
    test('OF-9 pdfx từ chối, file không mật khẩu ⇒ CorruptFile (D10 S)', () async {
      final path = await writePdf('a.pdf', await _samplePdf());
      final e = engineWith(openFile: (_) async => throw StateError('boom'));
      final r = await _capture(e.openFile(path));
      expect(security.calls, ['isEncrypted']);
      expect(security.isEncryptedResult, isFalse);
      expect(r, isA<CorruptFile>());
      expect((r as CorruptFile).detail, contains('boom'));
    });
    test('OF-10 pdfx từ chối, bytes rác ⇒ CorruptFile từ isEncrypted (D9 Đ)', () async {
      final path = await writePdf('bad.pdf', Uint8List.fromList([1, 2, 3, 4]));
      final e = engineWith(openFile: (_) async => throw StateError('boom'));
      final r = await _capture(e.openFile(path));
      expect(security.calls, ['isEncrypted']);
      expect(security.isEncryptedError, isA<CorruptFile>());
      expect(r, isA<CorruptFile>());
    });
    test('OF-11 pdfx từ chối, file không tồn tại ⇒ CorruptFile, không gọi isEncrypted (D8 Đ)', () async {
      final e = engineWith(openFile: (_) async => throw StateError('boom'));
      final r = await _capture(e.openFile(p.join(tmp.path, 'missing.pdf')));
      expect(security.calls, isEmpty);
      expect(r, isA<CorruptFile>());
    });
  });

  // ---------------- U6 openBytes ----------------
  group('U6 openBytes', () {
    test('OB-1 openData mở được ⇒ trả tài liệu (B1 S)', () async {
      final r = await _capture(engineWith().openBytes(Uint8List.fromList([5])));
      expect(openDataCalls, hasLength(1));
      expect(r, isA<PdfRenderDocument>());
    });
    test('OB-2 openData ném ⇒ CorruptFile (B1 Đ)', () async {
      final e = engineWith(openData: (_) async => throw StateError('x'));
      final r = await _capture(e.openBytes(Uint8List.fromList([5])));
      expect(r, isA<CorruptFile>());
    });
  });

  // ---------------- U7 _locked ----------------
  group('U7 _locked', () {
    test('LK-1 thao tác xếp hàng: trang 2 chỉ mở sau khi trang 1 xong (L1 S)', () async {
      final gate = Completer<pdfx.PdfPage>();
      when(() => doc.getPage(1)).thenAnswer((_) => gate.future);
      final d = await openDoc();
      final f1 = d.pageSize(0);
      final f2 = d.pageSize(1);
      await pumpEventQueue();
      verify(() => doc.getPage(1)).called(1);
      verifyNever(() => doc.getPage(2));
      gate.complete(page);
      final s1 = await f1;
      await f2;
      verify(() => doc.getPage(2)).called(1);
      expect(s1.width, 595.28);
    });
    test('LK-2 thao tác ném lỗi ⇒ lỗi về đúng người gọi, hàng đợi vẫn chạy tiếp (L1 Đ)', () async {
      final d = await openDoc();
      final bad = _capture(d.pageSize(9));
      final good = _capture(d.pageSize(0));
      expect(await bad, isA<RangeError>());
      expect(await good, isA<PdfPageSize>());
    });
  });

  // ---------------- U8 _withPage ----------------
  group('U8 _withPage', () {
    test('WP-1 trang hợp lệ ⇒ chạy action, đóng trang (W1 S, W2 S, W3 S, W4 Đ)', () async {
      final d = await openDoc();
      final s = await d.pageSize(0);
      verify(() => doc.getPage(1)).called(1);
      verify(() => page.close()).called(1);
      expect((s.width, s.height), (595.28, 841.89));
    });
    test('WP-2 tài liệu đã đóng ⇒ CorruptFile, không mở trang (W1 Đ)', () async {
      final d = await openDoc();
      await d.close();
      final r = await _capture(d.pageSize(0));
      verifyNever(() => doc.getPage(any()));
      expect(r, isA<CorruptFile>());
    });
    test('WP-3 chỉ số âm ⇒ RangeError (W2 Đ)', () async {
      final d = await openDoc();
      final r = await _capture(d.pageSize(-1));
      verifyNever(() => doc.getPage(any()));
      expect(r, isA<RangeError>());
    });
    test('WP-4 chỉ số = pageCount ⇒ RangeError (W3 Đ)', () async {
      final d = await openDoc();
      final r = await _capture(d.pageSize(3));
      verifyNever(() => doc.getPage(any()));
      expect(r, isA<RangeError>());
    });
    test('WP-5 trang đã tự đóng ⇒ không gọi close lần nữa (W4 S)', () async {
      when(() => page.isClosed).thenReturn(true);
      final d = await openDoc();
      await d.pageSize(2);
      verify(() => doc.getPage(3)).called(1);
      verifyNever(() => page.close());
    });
  });

  // ---------------- U9 _render ----------------
  group('U9 _render', () {
    test('RD-1 thumbnail (token null) ⇒ bytes JPEG 80, kích thước thumbnail (R1 Đ, R3 S, R4 Đ, R6 S, R8 S)', () async {
      stubRender(() async => _FakeImage(Uint8List.fromList([1])));
      final d = await openDoc();
      final r = await _capture(d.renderThumbnail(0, maxSide: 300));
      verify(
        () => page.render(
          width: 212,
          height: 300,
          format: pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
          quality: 80,
          forPrint: true,
        ),
      ).called(1);
      expect(r, [1]);
    });
    test('RD-2 renderPage có token chưa huỷ ⇒ bytes (R1 S, R2 S, R4 S, R5 S)', () async {
      stubRender(() async => _FakeImage(Uint8List.fromList([2])));
      final d = await openDoc();
      final r = await _capture(d.renderPage(0, cancelToken: CancelToken()));
      verify(() => doc.getPage(1)).called(1);
      expect(r, [2]);
    });
    test('RD-3 token đã huỷ trước ⇒ Cancelled, không mở trang (R2 Đ)', () async {
      final d = await openDoc();
      final r = await _capture(d.renderPage(0, cancelToken: CancelToken()..cancel()));
      verifyNever(() => doc.getPage(any()));
      expect(r, isA<Cancelled>());
    });
    test('RD-4 thumbnail ngoài phạm vi ⇒ RangeError, không render (R3 Đ)', () async {
      stubRender(() async => _FakeImage(Uint8List.fromList([1])));
      final d = await openDoc();
      final r = await _capture(d.renderThumbnail(5));
      verifyNever(() => doc.getPage(any()));
      expect(r, isA<RangeError>());
    });
    test('RD-5 huỷ trong lúc chờ hàng đợi ⇒ Cancelled, không render, trang vẫn được đóng (R5 Đ)', () async {
      stubRender(() async => _FakeImage(Uint8List.fromList([1])));
      final d = await openDoc();
      final token = CancelToken();
      final f = _capture(d.renderPage(0, cancelToken: token));
      token.cancel();
      final r = await f;
      verifyNever(
        () => page.render(
          width: any(named: 'width'),
          height: any(named: 'height'),
          format: any(named: 'format'),
          backgroundColor: any(named: 'backgroundColor'),
          quality: any(named: 'quality'),
          forPrint: any(named: 'forPrint'),
        ),
      );
      verify(() => page.close()).called(1);
      expect(r, isA<Cancelled>());
    });
    test('RD-6 render hết bộ nhớ ⇒ NoSpace (R6 Đ, R7 Đ)', () async {
      stubRender(() async => throw OutOfMemoryError());
      final d = await openDoc();
      final r = await _capture(d.renderPage(0));
      verify(() => page.close()).called(1);
      expect(r, isA<NoSpace>());
    });
    test('RD-7 render lỗi khác ⇒ ném lại nguyên lỗi gốc (R7 S)', () async {
      final boom = StateError('render boom');
      stubRender(() async => throw boom);
      final d = await openDoc();
      final r = await _capture(d.renderPage(0));
      expect(r, same(boom));
    });
    test('RD-8 render trả null ⇒ CorruptFile (R8 Đ)', () async {
      stubRender(() async => null);
      final d = await openDoc();
      final r = await _capture(d.renderPage(0));
      expect(r, isA<CorruptFile>());
    });
  });

  // ---------------- U10 renderPage ----------------
  group('U10 renderPage', () {
    test('RP-1 PNG ⇒ định dạng png, quality kẹp về 1–100 (F1 Đ)', () async {
      stubRender(() async => _FakeImage(Uint8List.fromList([3])));
      final d = await openDoc();
      await d.renderPage(0, dpi: 72, format: RenderFormat.png, jpgQuality: 0);
      verify(
        () => page.render(
          width: 595,
          height: 842,
          format: pdfx.PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
          quality: 1,
          forPrint: true,
        ),
      ).called(1);
    });
    test('RP-2 JPG ⇒ định dạng jpeg, quality > 100 kẹp về 100 (F1 S)', () async {
      stubRender(() async => _FakeImage(Uint8List.fromList([3])));
      final d = await openDoc();
      await d.renderPage(0, dpi: 72, format: RenderFormat.jpg, jpgQuality: 500);
      verify(
        () => page.render(
          width: 595,
          height: 842,
          format: pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
          quality: 100,
          forPrint: true,
        ),
      ).called(1);
    });
  });

  // ---------------- U11 close ----------------
  group('U11 close', () {
    test('CL-1 lần đầu ⇒ đóng tài liệu pdfx (C1 S)', () async {
      final d = await openDoc();
      await d.close();
      verify(() => doc.close()).called(1);
    });
    test('CL-2 lần hai ⇒ không đóng lại (C1 Đ)', () async {
      final d = await openDoc();
      await d.close();
      await d.close();
      verify(() => doc.close()).called(1);
    });
  });
}
