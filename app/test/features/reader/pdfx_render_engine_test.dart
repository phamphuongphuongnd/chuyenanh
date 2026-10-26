import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/engines/pdf/syncfusion_pdf_security.dart';
import 'package:pdf_office/engines/pdf/pdfx_render_engine.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class _MockDoc extends Mock implements pdfx.PdfDocument {}

class _MockPage extends Mock implements pdfx.PdfPage {}

class _FakeImage extends Fake implements pdfx.PdfPageImage {
  _FakeImage(this.bytes);
  @override
  final Uint8List bytes;
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

void main() {
  late Directory tmp;
  late _MockDoc doc;
  late _MockPage page;
  late PdfxRenderEngine engine;
  var openFileCalls = 0;
  Uint8List? openedData;

  setUpAll(() {
    registerFallbackValue(pdfx.PdfPageImageFormat.jpeg);
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('reader_engine_');
    doc = _MockDoc();
    page = _MockPage();
    openFileCalls = 0;
    openedData = null;
    when(() => doc.pagesCount).thenReturn(3);
    when(() => doc.close()).thenAnswer((_) async {});
    when(() => doc.getPage(any())).thenAnswer((_) async => page);
    when(() => page.width).thenReturn(595.28);
    when(() => page.height).thenReturn(841.89);
    when(() => page.isClosed).thenReturn(false);
    when(() => page.close()).thenAnswer((_) async {});
    engine = PdfxRenderEngine(
      security: const SyncfusionPdfSecurity(),
      openFile: (path) async {
        openFileCalls++;
        return doc;
      },
      openData: (d) async {
        openedData = d;
        return doc;
      },
    );
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<String> writePdf(String name, Uint8List bytes) async {
    final f = File(p.join(tmp.path, name));
    await f.writeAsBytes(bytes);
    return f.path;
  }

  test('mở PDF thường: gọi openFile, không giải mã', () async {
    final path = await writePdf('a.pdf', await _samplePdf());
    final d = await engine.openFile(path);
    expect(d.pageCount, 3);
    expect(openFileCalls, 1);
    expect(openedData, isNull);
  });

  test('PDF có mật khẩu: không mật khẩu → PasswordRequired', () async {
    final path = await writePdf(
      'locked.pdf',
      await _samplePdf(userPassword: 'secret'),
    );
    final fail = PdfxRenderEngine(
      security: const SyncfusionPdfSecurity(),
      openFile: (_) async => throw StateError('PdfRenderer: password'),
    );
    await expectLater(fail.openFile(path), throwsA(isA<PasswordRequired>()));
  });

  test('PDF có mật khẩu: sai mật khẩu → WrongPassword', () async {
    final path = await writePdf(
      'locked.pdf',
      await _samplePdf(userPassword: 'secret'),
    );
    await expectLater(
      engine.openFile(path, password: 'nope'),
      throwsA(isA<WrongPassword>()),
    );
  });

  test('PDF có mật khẩu: đúng mật khẩu → mở bằng bytes đã giải mã', () async {
    final path = await writePdf(
      'locked.pdf',
      await _samplePdf(userPassword: 'secret'),
    );
    await engine.openFile(path, password: 'secret');
    expect(openFileCalls, 0);
    expect(openedData, isNotNull);
    // Bytes đã giải mã mở được không cần mật khẩu.
    expect(sf.PdfDocument(inputBytes: openedData).pages.count, 1);
  });

  test('file hỏng → CorruptFile', () async {
    final path = await writePdf('bad.pdf', Uint8List.fromList([1, 2, 3, 4]));
    final fail = PdfxRenderEngine(
      security: const SyncfusionPdfSecurity(),
      openFile: (_) async => throw StateError('boom'),
    );
    await expectLater(fail.openFile(path), throwsA(isA<CorruptFile>()));
  });

  test('file không tồn tại → CorruptFile', () async {
    final fail = PdfxRenderEngine(
      security: const SyncfusionPdfSecurity(),
      openFile: (_) async => throw StateError('boom'),
    );
    await expectLater(
      fail.openFile(p.join(tmp.path, 'missing.pdf')),
      throwsA(isA<CorruptFile>()),
    );
  });

  test('renderPage: đúng kích thước theo DPI, nền trắng, đóng trang', () async {
    when(
      () => page.render(
        width: any(named: 'width'),
        height: any(named: 'height'),
        format: any(named: 'format'),
        backgroundColor: any(named: 'backgroundColor'),
        quality: any(named: 'quality'),
        forPrint: any(named: 'forPrint'),
      ),
    ).thenAnswer((_) async => _FakeImage(Uint8List.fromList([9, 9])));

    final path = await writePdf('a.pdf', await _samplePdf());
    final d = await engine.openFile(path);
    final bytes = await d.renderPage(
      1,
      dpi: 300,
      format: RenderFormat.jpg,
      jpgQuality: 70,
    );
    expect(bytes, [9, 9]);
    verify(() => doc.getPage(2)).called(1);
    verify(
      () => page.render(
        width: 2480,
        height: 3508,
        format: pdfx.PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
        quality: 70,
        forPrint: true,
      ),
    ).called(1);
    verify(() => page.close()).called(1);
  });

  test('renderPage: đã huỷ → ném Cancelled, không mở trang', () async {
    final path = await writePdf('a.pdf', await _samplePdf());
    final d = await engine.openFile(path);
    final token = CancelToken()..cancel();
    await expectLater(
      d.renderPage(0, cancelToken: token),
      throwsA(isA<Cancelled>()),
    );
    verifyNever(() => doc.getPage(any()));
  });

  test('chỉ số trang ngoài phạm vi → RangeError', () async {
    final path = await writePdf('a.pdf', await _samplePdf());
    final d = await engine.openFile(path);
    await expectLater(d.pageSize(3), throwsA(isA<RangeError>()));
  });

  test('pageSize trả về point của trang', () async {
    final path = await writePdf('a.pdf', await _samplePdf());
    final d = await engine.openFile(path);
    final s = await d.pageSize(0);
    expect(s.width, 595.28);
    expect(s.height, 841.89);
  });

  test('close đóng tài liệu một lần', () async {
    final path = await writePdf('a.pdf', await _samplePdf());
    final d = await engine.openFile(path);
    await d.close();
    await d.close();
    verify(() => doc.close()).called(1);
  });
}
