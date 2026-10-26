// Synthetic test images, generated in code (no downloaded fixtures).
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

final img.Color white = img.ColorRgb8(255, 255, 255);
final img.Color red = img.ColorRgb8(230, 20, 20);
final img.Color blue = img.ColorRgb8(20, 40, 220);

/// A [w]x[h] white image whose top-left quadrant is red.
img.Image quadrantImage(int w, int h) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: white);
  img.fillRect(im, x1: 0, y1: 0, x2: w ~/ 2 - 1, y2: h ~/ 2 - 1, color: red);
  return im;
}

Uint8List jpg(img.Image im, {int quality = 95}) =>
    img.encodeJpg(im, quality: quality);

Uint8List png(img.Image im) => img.encodePng(im);

img.Image decode(Uint8List bytes) => img.decodeImage(bytes)!;

bool isJpeg(Uint8List b) => b.length > 3 && b[0] == 0xFF && b[1] == 0xD8;

bool isPng(Uint8List b) =>
    b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E;

/// True when the pixel at (x, y) is clearly red (tolerant to JPEG noise).
bool isRedAt(img.Image im, int x, int y) {
  final p = im.getPixel(x, y);
  return p.r > 150 && p.g < 100 && p.b < 100;
}

bool isWhiteAt(img.Image im, int x, int y) {
  final p = im.getPixel(x, y);
  return p.r > 200 && p.g > 200 && p.b > 200;
}

/// A colourful, detailed photo-like image (gradients, shapes, mild noise).
img.Image photoLike(int w, int h, {int seed = 1}) {
  final rnd = math.Random(seed);
  final im = img.Image(width: w, height: h);
  final data = im.toUint8List();
  var i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final n = rnd.nextInt(24) - 12;
      data[i++] = (x * 255 ~/ w + n).clamp(0, 255);
      data[i++] = (y * 255 ~/ h + n).clamp(0, 255);
      data[i++] = (((x + y) * 128 ~/ (w + h)) + 60 + n).clamp(0, 255);
    }
  }
  for (var k = 0; k < 12; k++) {
    final cx = rnd.nextInt(w), cy = rnd.nextInt(h);
    img.fillCircle(im,
        x: cx,
        y: cy,
        radius: math.max(4, w ~/ 20),
        color: img.ColorRgb8(rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256)));
  }
  return im;
}

/// White-ish background with a grey tilted quadrilateral ("sheet of paper")
/// that carries a few dark "text" lines. Returns the image and the four
/// corners (TL, TR, BR, BL) in pixel coordinates.
({img.Image image, List<math.Point<double>> corners}) paperScene({
  int w = 1000,
  int h = 750,
  int seed = 7,
  bool darkBackground = false,
}) {
  final rnd = math.Random(seed);
  final im = img.Image(width: w, height: h);
  final data = im.toUint8List();
  final bg = darkBackground ? 60 : 240;
  for (var i = 0; i < data.length; i++) {
    data[i] = (bg + rnd.nextInt(11) - 5).clamp(0, 255);
  }
  final corners = <math.Point<double>>[
    math.Point(0.18 * w, 0.16 * h),
    math.Point(0.82 * w, 0.22 * h),
    math.Point(0.78 * w, 0.86 * h),
    math.Point(0.15 * w, 0.80 * h),
  ];
  final paper = darkBackground ? 235 : 150;
  img.fillPolygon(im,
      vertices: [for (final c in corners) img.Point(c.x, c.y)],
      color: img.ColorRgb8(paper, paper, paper));
  // "Text" lines inside the sheet.
  final ink = darkBackground ? 40 : 70;
  for (var k = 0; k < 8; k++) {
    final t = 0.25 + k * 0.06;
    final y0 = (corners[0].y + (corners[3].y - corners[0].y) * t).round();
    final y1 = (corners[1].y + (corners[2].y - corners[1].y) * t).round();
    final x0 = (corners[0].x + (corners[3].x - corners[0].x) * t + 0.12 * w).round();
    final x1 = (corners[1].x + (corners[2].x - corners[1].x) * t - 0.12 * w).round();
    img.drawLine(im,
        x1: x0,
        y1: y0,
        x2: x1,
        y2: y1,
        thickness: 4,
        color: img.ColorRgb8(ink, ink, ink));
  }
  return (image: im, corners: corners);
}

/// Pure random noise.
img.Image noiseImage(int w, int h, {int seed = 3}) {
  final rnd = math.Random(seed);
  final im = img.Image(width: w, height: h);
  final data = im.toUint8List();
  for (var i = 0; i < data.length; i++) {
    data[i] = rnd.nextInt(256);
  }
  return im;
}
