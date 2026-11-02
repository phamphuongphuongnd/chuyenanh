// Kiểm thử hộp trắng A14 — slide_rasterizer.dart (OverlaySlideRasterizer.renderSlide).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/office_pptx/slide_view.dart';
import 'package:pdf_office/features/ppt_convert/engine/slide_rasterizer.dart';
import 'package:pptx_reader/pptx_reader.dart';

/// Slide 100 × 50 pt.
const _deckW = 1270000;
const _deckH = 635000;

Uint8List _pngBytes(int shade) => Uint8List.fromList(
  img.encodePng(img.Image(width: 8, height: 4)..clear(img.ColorRgb8(shade, 10, 10))),
);

PptxDeck _deck(PptxSlide s) =>
    PptxDeck(slideWidthEmu: _deckW, slideHeightEmu: _deckH, slides: [s]);

PptxSlide _slide({PptxFill? bg}) =>
    PptxSlide(index: 0, background: bg, shapes: const [], notesText: null);

class _Run {
  Uint8List? png;
  Object? error;
  bool done = false;
}

_Run _start(OverlaySlideRasterizer r, PptxDeck d, PptxSlide s, int dpi) {
  final run = _Run();
  r.renderSlide(d, s, dpi: dpi).then(
    (v) {
      run.png = v;
      run.done = true;
    },
    onError: (Object e) {
      run.error = e;
      run.done = true;
    },
  );
  return run;
}

Future<void> _drive(WidgetTester tester, _Run run, {int rounds = 80}) async {
  for (var i = 0; i < rounds && !run.done; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
  }
  await tester.pump();
}

Future<OverlayState> _app(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  return tester.state<OverlayState>(find.byType(Overlay).first);
}

void main() {
  testWidgets('U1.P1 slide có ảnh nền ⇒ PNG 200×100 ở 144 dpi, gỡ entry sau khi chụp', (tester) async {
    final overlay = await _app(tester);
    final s = _slide(bg: PptxFill.picture(_pngBytes(200), 'png'));
    final run = _start(OverlaySlideRasterizer(overlay), _deck(s), s, 144);
    await _drive(tester, run);
    expect(run.done, isTrue);
    expect(run.error, isNull);
    final png = img.decodePng(run.png!)!;
    expect((png.width, png.height), (200, 100));
    expect(find.byType(SlideView), findsNothing);
  });

  testWidgets('U1.P2 overlay đã gỡ trước khi gọi ⇒ Cancelled, không chèn entry', (tester) async {
    final overlay = await _app(tester);
    await tester.pumpWidget(const SizedBox());
    final s = _slide();
    final run = _start(OverlaySlideRasterizer(overlay), _deck(s), s, 72);
    await tester.pump();
    expect(run.done, isTrue);
    expect(run.error, isA<Cancelled>());
  });

  testWidgets('U1.P3 gỡ overlay trước khung hình đầu ⇒ ctx null ⇒ Cancelled', (tester) async {
    final overlay = await _app(tester);
    final s = _slide();
    final run = _start(OverlaySlideRasterizer(overlay), _deck(s), s, 72);
    await tester.pumpWidget(const SizedBox());
    await _drive(tester, run, rounds: 10);
    expect(run.done, isTrue);
    expect(run.error, isA<Cancelled>());
  });

  testWidgets('U1.P5 slide không ảnh ⇒ bỏ chờ ảnh, PNG 100×50 ở 72 dpi', (tester) async {
    final overlay = await _app(tester);
    final s = _slide(bg: const PptxFill.solid(0xFF3366CC));
    final run = _start(OverlaySlideRasterizer(overlay), _deck(s), s, 72);
    await _drive(tester, run);
    expect(run.error, isNull);
    final png = img.decodePng(run.png!)!;
    expect((png.width, png.height), (100, 50));
    // Màu nền slide được vẽ vào ảnh.
    final px = png.getPixel(50, 25);
    expect((px.r, px.g, px.b), (0x33, 0x66, 0xCC));
  });

  testWidgets('U1.P6 gỡ overlay trong lúc chờ ảnh giải mã ⇒ Cancelled', (tester) async {
    final overlay = await _app(tester);
    final s = _slide(bg: PptxFill.picture(_pngBytes(120), 'png'));
    final run = _start(OverlaySlideRasterizer(overlay), _deck(s), s, 72);
    await tester.pump(); // khung đầu: dựng slide, gom ImageProvider, bắt đầu precache
    await tester.pumpWidget(const SizedBox());
    await _drive(tester, run);
    expect(run.done, isTrue);
    expect(run.error, isA<Cancelled>());
  });
}
