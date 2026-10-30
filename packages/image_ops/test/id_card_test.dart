import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Bounding box of the non-white pixels of [im] inside rows [y0, y1).
({int left, int top, int right, int bottom})? inkBox(
  img.Image im,
  int y0,
  int y1, {
  int step = 2,
}) {
  int? l, t, r, b;
  for (var y = y0; y < y1; y += step) {
    for (var x = 0; x < im.width; x += step) {
      final p = im.getPixel(x, y);
      if (p.r < 200 || p.g < 200 || p.b < 200) {
        l = l == null || x < l ? x : l;
        r = r == null || x > r ? x : r;
        t ??= y;
        b = y;
      }
    }
  }
  if (l == null) return null;
  return (left: l, top: t!, right: r!, bottom: b!);
}

img.Image solid(int w, int h, img.Color c) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: c);
  return im;
}

void main() {
  // Small canvas keeps the tests fast; geometry is proportional.
  const small = IdCardLayout(pageWidthPx: 620, pageHeightPx: 877);

  test('default layout is A4 at 300 dpi, true card size', () {
    const l = IdCardLayout();
    expect(l.pageWidthPx / l.pageHeightPx, closeTo(210 / 297, 0.001));
    final f = idCardFrames(l);
    expect(f.front.width, closeTo(85.6 / 25.4 * 300, 2));
    expect(f.front.height, closeTo(54 / 25.4 * 300, 2));
    expect(f.front.top + f.front.height, lessThanOrEqualTo(l.pageHeightPx ~/ 2));
    expect(f.back.top, greaterThanOrEqualTo(l.pageHeightPx ~/ 2));
  });

  test('scale is clamped inside the margins of each half page', () {
    final f = idCardFrames(const IdCardLayout(scale: 10));
    final mm = 2480 / 210;
    expect(f.front.left, greaterThanOrEqualTo((10 * mm).floor()));
    expect(f.front.top, greaterThanOrEqualTo((10 * mm).floor()));
    expect(f.front.top + f.front.height, lessThanOrEqualTo(3508 ~/ 2));
    expect(f.back.top + f.back.height, lessThanOrEqualTo(3508));
    expect(f.front.width / f.front.height, closeTo(85.6 / 54, 0.01));
  });

  test('JPEG with A4 proportions and two inked areas (upper / lower half)',
      () {
    final front = jpg(solid(856, 540, red));
    final back = png(solid(856, 540, blue));
    final out = composeIdCard(front, back, layout: small);
    expect(isJpeg(out), isTrue);
    final im = decode(out);
    expect(im.width, 620);
    expect(im.height, 877);
    expect(im.width / im.height, closeTo(210 / 297, 0.002));

    final half = im.height ~/ 2;
    final top = inkBox(im, 0, half);
    final bottom = inkBox(im, half, im.height);
    expect(top, isNotNull);
    expect(bottom, isNotNull);
    // Front is red, back is blue.
    final fc = im.getPixel((top!.left + top.right) ~/ 2, (top.top + top.bottom) ~/ 2);
    expect(fc.r > 150 && fc.b < 100, isTrue);
    final bc = im.getPixel(
        (bottom!.left + bottom.right) ~/ 2, (bottom.top + bottom.bottom) ~/ 2);
    expect(bc.b > 150 && bc.r < 100, isTrue);
    // White margins: corners and the middle line stay white.
    expect(isWhiteAt(im, 2, 2), isTrue);
    expect(isWhiteAt(im, im.width - 3, im.height - 3), isTrue);
    expect(isWhiteAt(im, im.width ~/ 2, half), isTrue);
    // Card aspect preserved (85.6 x 54).
    final w = top.right - top.left, h = top.bottom - top.top;
    expect(w / h, closeTo(85.6 / 54, 0.06));
  });

  test('contain keeps the photo aspect (no distortion), centred in frame', () {
    // Square photo inside a wide frame: square ink, full frame height.
    final out = composeIdCard(jpg(solid(400, 400, red)),
        jpg(solid(400, 400, blue)),
        layout: small);
    final im = decode(out);
    final box = inkBox(im, 0, im.height ~/ 2, step: 1)!;
    final f = idCardFrames(small).front;
    final w = box.right - box.left + 1, h = box.bottom - box.top + 1;
    expect(w / h, closeTo(1, 0.05));
    expect(h, closeTo(f.height, 3));
    expect((box.left + box.right) / 2, closeTo(f.left + f.width / 2, 3));
  });

  test('cover fills the whole frame', () {
    final out = composeIdCard(jpg(solid(400, 400, red)),
        jpg(solid(400, 400, blue)),
        layout: const IdCardLayout(
            pageWidthPx: 620, pageHeightPx: 877, fit: IdCardFit.cover));
    final im = decode(out);
    final box = inkBox(im, 0, im.height ~/ 2, step: 1)!;
    final f = idCardFrames(small).front;
    expect(box.right - box.left + 1, closeTo(f.width, 3));
    expect(box.bottom - box.top + 1, closeTo(f.height, 3));
  });

  test('quarter turn rotates the side before fitting', () {
    // Portrait photo, left half red / right half white → after 1 CW turn the
    // red half is on top.
    final p = solid(300, 480, white);
    img.fillRect(p, x1: 0, y1: 0, x2: 149, y2: 479, color: red);
    final out = composeIdCard(jpg(p), jpg(solid(300, 480, blue)),
        layout: small, frontTurns: 1);
    final im = decode(out);
    final f = idCardFrames(small).front;
    final box = inkBox(im, 0, im.height ~/ 2, step: 1)!;
    // Landscape after rotation: wider than tall, fills the frame.
    expect(box.right - box.left, greaterThan(box.bottom - box.top));
    final cx = f.left + f.width ~/ 2;
    expect(isRedAt(im, cx, f.top + f.height ~/ 4), isTrue);
    expect(isWhiteAt(im, cx, f.top + f.height * 3 ~/ 4), isTrue);
  });

  test('small photos are enlarged to the frame', () {
    final out = composeIdCard(jpg(solid(60, 38, red)), jpg(solid(60, 38, blue)),
        layout: small);
    final im = decode(out);
    final f = idCardFrames(small).front;
    final box = inkBox(im, 0, im.height ~/ 2, step: 1)!;
    expect(box.right - box.left + 1, closeTo(f.width, 4));
  });

  test('watermark overlay is blended over both cards only', () {
    // Semi-transparent black overlay.
    final o = img.Image(width: 100, height: 60, numChannels: 4);
    img.fill(o, color: img.ColorRgba8(0, 0, 0, 128));
    final layout = IdCardLayout(
        pageWidthPx: 620,
        pageHeightPx: 877,
        watermarkPng: Uint8List.fromList(img.encodePng(o)));
    final out = composeIdCard(jpg(solid(856, 540, white)),
        jpg(solid(856, 540, white)),
        layout: layout);
    final im = decode(out);
    final f = idCardFrames(layout);
    for (final fr in [f.front, f.back]) {
      final p = im.getPixel(fr.left + fr.width ~/ 2, fr.top + fr.height ~/ 2);
      expect(p.r, inInclusiveRange(100, 160));
    }
    expect(isWhiteAt(im, 3, 3), isTrue);
    expect(isWhiteAt(im, im.width ~/ 2, im.height ~/ 2), isTrue);
  });

  test('corrupt data throws FormatException', () {
    expect(
        () => composeIdCard(Uint8List.fromList([1, 2, 3]),
            jpg(solid(10, 10, red)),
            layout: small),
        throwsFormatException);
  });

  test('full-size default canvas', () {
    final out = composeIdCard(jpg(photoLike(1600, 1000)),
        jpg(photoLike(1600, 1000, seed: 2)));
    final im = decode(out);
    expect(im.width, 2480);
    expect(im.height, 3508);
    expect(inkBox(im, 0, 1754, step: 8), isNotNull);
    expect(inkBox(im, 1754, 3508, step: 8), isNotNull);
  });
}
