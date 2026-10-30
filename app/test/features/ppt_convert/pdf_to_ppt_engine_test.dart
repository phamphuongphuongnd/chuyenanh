import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/engines/pdf/pdf_render_engine.dart';
import 'package:pdf_office/features/ppt_convert/engine/pdf_to_ppt.dart';
import 'package:pptx_reader/pptx_reader.dart';

import 'pdf_to_ppt_test_fakes.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('pdf_to_ppt'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('mỗi trang thành 1 slide ảnh, cỡ slide theo trang 1, ghi trong isolate', () async {
    final render = FakePptRender(
      sizes: const [
        PdfPageSize(595, 842),
        PdfPageSize(842, 595),
        PdfPageSize(595, 842),
      ],
    );
    final out = p.join(tmp.path, 'report.pptx');
    final progress = <double>[];
    // Bộ ghi mặc định: Isolate.run thật.
    final converter = PdfToPptConverter(render: render);
    final saved = await converter.convert(
      inputPath: '/x/report.pdf',
      outputPath: out,
      password: 'pw',
      dpi: 200,
      onProgress: progress.add,
    );

    expect(saved, out);
    expect(render.openedPasswords, ['pw']);
    expect(render.closed, 1);
    expect(render.renders.map((r) => r.page), [0, 1, 2]);
    expect(render.renders.every((r) => r.dpi == 200), isTrue);
    expect(render.renders.every((r) => r.format == RenderFormat.jpg), isTrue);
    expect(progress.first, 0);
    expect(progress.last, 1);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
    }

    final deck = readPptx(File(out).readAsBytesSync());
    expect(deck.slides, hasLength(3));
    expect(deck.slideWidthEmu, 595 * 12700);
    expect(deck.slideHeightEmu, 842 * 12700);
    for (var i = 0; i < 3; i++) {
      final pic = deck.slides[i].shapes.whereType<PptxPictureShape>().single;
      expect(pic.bytes, fakeJpeg(i + 1));
    }
    // Trang 2 nằm ngang → vừa khít chiều rộng, nằm giữa theo chiều dọc.
    final landscape = deck.slides[1].shapes.whereType<PptxPictureShape>().single;
    expect(landscape.frame.cx, 595 * 12700);
    expect(landscape.frame.y, greaterThan(0));
    expect(File('$out.tmp').existsSync(), isFalse);
  });

  test('huỷ giữa chừng → Cancelled, không để lại file, vẫn đóng tài liệu', () async {
    final token = CancelToken();
    final render = FakePptRender(
      onRender: (page) {
        if (page == 0) token.cancel();
      },
    );
    final out = p.join(tmp.path, 'a.pptx');
    final converter = PdfToPptConverter(
      render: render,
      encode: syncPptxEncoder,
    );
    await expectLater(
      converter.convert(
        inputPath: '/x/a.pdf',
        outputPath: out,
        cancelToken: token,
      ),
      throwsA(isA<Cancelled>()),
    );
    expect(render.closed, 1);
    expect(render.renders, hasLength(1));
    expect(File(out).existsSync(), isFalse);
  });

  test('PDF không có trang → CorruptFile', () async {
    final render = FakePptRender(sizes: const []);
    final converter = PdfToPptConverter(
      render: render,
      encode: syncPptxEncoder,
    );
    await expectLater(
      converter.convert(
        inputPath: '/x/a.pdf',
        outputPath: p.join(tmp.path, 'a.pptx'),
      ),
      throwsA(isA<CorruptFile>()),
    );
    expect(render.closed, 1);
  });
}
