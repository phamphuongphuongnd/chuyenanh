// Two-sided ID card on one page: front on the upper half, back on the lower
// half of a white A4-proportioned canvas (CCCD, driving licence, student card,
// business card). Pure and synchronous, so it can run inside `Isolate.run`.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'models.dart';
import 'raw.dart';

/// How a card photo is placed inside its card-shaped frame.
enum IdCardFit {
  /// Whole photo visible, centred; letterbox stays white.
  contain,

  /// Photo fills the frame; the overflowing edges are cropped (centred).
  cover,
}

/// Page and frame geometry for [composeIdCard].
class IdCardLayout {
  const IdCardLayout({
    this.pageWidthPx = 2480,
    this.pageHeightPx = 3508,
    this.pageWidthMm = 210,
    this.cardWidthMm = 85.6,
    this.cardHeightMm = 54,
    this.scale = 1.0,
    this.marginMm = 10,
    this.fit = IdCardFit.contain,
    this.jpegQuality = 90,
    this.watermarkPng,
    this.watermarkOpacity = 1.0,
  });

  /// Canvas size. Default = A4 at 300 dpi.
  final int pageWidthPx, pageHeightPx;

  /// Physical page width, used to turn millimetres into pixels.
  final double pageWidthMm;

  /// Frame aspect / real size (ID-1 card: 85.6 x 54 mm).
  final double cardWidthMm, cardHeightMm;

  /// 1.0 = true card size on the printed page; larger enlarges the frame
  /// (clamped so the frame stays inside the margins of its half page).
  final double scale;

  /// Minimum white border around each frame.
  final double marginMm;

  final IdCardFit fit;

  /// 1..100.
  final int jpegQuality;

  /// Optional overlay (PNG with alpha, e.g. "For … only" text) blended over
  /// each card, scaled to cover the frame and centred.
  final Uint8List? watermarkPng;

  /// Extra opacity multiplier for [watermarkPng] (0..1).
  final double watermarkOpacity;

  double get pxPerMm => pageWidthPx / pageWidthMm;
}

/// Pixel rectangle of a frame on the canvas.
typedef IdCardFrame = ({int left, int top, int width, int height});

/// The two frames (front = upper half, back = lower half) for [layout].
/// Pure — exposed for tests and for drawing a matching preview.
({IdCardFrame front, IdCardFrame back}) idCardFrames(IdCardLayout layout) {
  final pw = layout.pageWidthPx, ph = layout.pageHeightPx;
  if (pw <= 0 || ph <= 0) {
    throw ArgumentError('page size must be positive');
  }
  final ppm = layout.pxPerMm;
  final aspect = layout.cardWidthMm / layout.cardHeightMm;
  final margin = layout.marginMm * ppm;
  final halfH = ph / 2;
  // Largest frame that fits a half page inside the margins.
  final maxW = math.max(1.0, pw - 2 * margin);
  final maxH = math.max(1.0, halfH - 2 * margin);
  var w = layout.cardWidthMm * ppm * (layout.scale <= 0 ? 1 : layout.scale);
  var h = w / aspect;
  if (w > maxW) {
    w = maxW;
    h = w / aspect;
  }
  if (h > maxH) {
    h = maxH;
    w = h * aspect;
  }
  final fw = math.max(1, w.round()), fh = math.max(1, h.round());
  final left = ((pw - fw) / 2).round();
  IdCardFrame at(double centreY) =>
      (left: left, top: (centreY - fh / 2).round(), width: fw, height: fh);
  return (front: at(halfH / 2), back: at(halfH + halfH / 2));
}

/// Composes [front] and [back] (any format package:image decodes) onto one
/// white page and encodes it as JPEG.
///
/// Each side is first made upright (EXIF), then rotated clockwise by
/// [frontTurns] / [backTurns] quarter turns, then scaled to its frame keeping
/// its aspect ratio ([IdCardLayout.fit]). Throws [FormatException] for
/// unreadable data.
Uint8List composeIdCard(
  Uint8List front,
  Uint8List back, {
  IdCardLayout layout = const IdCardLayout(),
  int frontTurns = 0,
  int backTurns = 0,
}) {
  final frames = idCardFrames(layout);
  final canvas = RawImage(
    layout.pageWidthPx,
    layout.pageHeightPx,
    3,
    Uint8List(layout.pageWidthPx * layout.pageHeightPx * 3)..fillRange(
      0,
      layout.pageWidthPx * layout.pageHeightPx * 3,
      255,
    ),
  );
  final overlay = layout.watermarkPng == null
      ? null
      : _decodeOverlay(layout.watermarkPng!);
  for (final (bytes, turns, frame) in [
    (front, frontTurns, frames.front),
    (back, backTurns, frames.back),
  ]) {
    final side = _loadSide(bytes, turns, frame, layout.fit);
    _blit(canvas, side.image, frame.left + side.dx, frame.top + side.dy);
    if (overlay != null) {
      _blendOverlay(canvas, overlay, frame, layout.watermarkOpacity);
    }
  }
  return encodeRaw(canvas, OutputFormat.jpeg, layout.jpegQuality);
}

/// Decoded, rotated, scaled side plus its offset inside the frame.
({RawImage image, int dx, int dy}) _loadSide(
  Uint8List bytes,
  int turns,
  IdCardFrame frame,
  IdCardFit fit,
) {
  final dec = decodeRaw(bytes, targetLongSide: math.max(frame.width, frame.height));
  var im = applyOrientation(dec.image, dec.orientation);
  if (im.channels == 4) im = flattenOnWhite(im);
  im = rotateCw(im, turns);

  final sx = frame.width / im.width, sy = frame.height / im.height;
  if (fit == IdCardFit.contain) {
    final s = math.min(sx, sy);
    final w = math.max(1, math.min(frame.width, (im.width * s).round()));
    final h = math.max(1, math.min(frame.height, (im.height * s).round()));
    final scaled = _resize(im, w, h);
    return (
      image: scaled,
      dx: (frame.width - w) ~/ 2,
      dy: (frame.height - h) ~/ 2,
    );
  }
  // cover: crop the source to the frame aspect first, then scale.
  final s = math.max(sx, sy);
  final cw = math.max(1, math.min(im.width, (frame.width / s).round()));
  final ch = math.max(1, math.min(im.height, (frame.height / s).round()));
  final x0 = (im.width - cw) ~/ 2, y0 = (im.height - ch) ~/ 2;
  final cropped = cropPx(im, x0, y0, x0 + cw, y0 + ch);
  return (image: _resize(cropped, frame.width, frame.height), dx: 0, dy: 0);
}

/// Area average when shrinking; bilinear when enlarging (small photos).
RawImage _resize(RawImage src, int w, int h) {
  if (w == src.width && h == src.height) return src;
  if (w <= src.width && h <= src.height) return resizeArea(src, w, h);
  final im = img.Image.fromBytes(
    width: src.width,
    height: src.height,
    bytes: src.data.buffer,
    bytesOffset: src.data.offsetInBytes,
    numChannels: src.channels,
  );
  return toRaw(
    img.copyResize(
      im,
      width: w,
      height: h,
      interpolation: img.Interpolation.linear,
    ),
  );
}

/// Copies RGB [src] onto RGB [dst] at (x, y), clipped to [dst].
void _blit(RawImage dst, RawImage src, int x, int y) {
  final x0 = math.max(0, x), y0 = math.max(0, y);
  final x1 = math.min(dst.width, x + src.width);
  final y1 = math.min(dst.height, y + src.height);
  if (x1 <= x0 || y1 <= y0) return;
  final rowLen = (x1 - x0) * 3;
  for (var yy = y0; yy < y1; yy++) {
    final si = ((yy - y) * src.width + (x0 - x)) * 3;
    final di = (yy * dst.width + x0) * 3;
    dst.data.setRange(di, di + rowLen, src.data, si);
  }
}

RawImage _decodeOverlay(Uint8List png) {
  final dec = decodeRaw(png);
  final im = dec.image;
  if (im.channels == 4) return im;
  // No alpha channel: treat as fully opaque.
  final n = im.width * im.height;
  final out = Uint8List(n * 4);
  for (var i = 0, j = 0; i < n * 3; i += 3, j += 4) {
    out[j] = im.data[i];
    out[j + 1] = im.data[i + 1];
    out[j + 2] = im.data[i + 2];
    out[j + 3] = 255;
  }
  return RawImage(im.width, im.height, 4, out);
}

/// Alpha-blends [overlay] (RGBA) over [frame], scaled to cover it, centred.
void _blendOverlay(
  RawImage canvas,
  RawImage overlay,
  IdCardFrame frame,
  double opacity,
) {
  final o = (opacity.isNaN ? 1.0 : opacity.clamp(0.0, 1.0));
  if (o == 0) return;
  final s = math.max(frame.width / overlay.width, frame.height / overlay.height);
  final ow = math.max(1, (overlay.width * s).round());
  final oh = math.max(1, (overlay.height * s).round());
  final scaled = _resize(overlay, ow, oh);
  final ox = frame.left + (frame.width - ow) ~/ 2;
  final oy = frame.top + (frame.height - oh) ~/ 2;
  final mul = (o * 256).round();
  final x0 = math.max(frame.left, ox), y0 = math.max(frame.top, oy);
  final x1 = math.min(frame.left + frame.width, ox + ow);
  final y1 = math.min(frame.top + frame.height, oy + oh);
  final d = canvas.data, sd = scaled.data;
  for (var y = math.max(0, y0); y < math.min(canvas.height, y1); y++) {
    for (var x = math.max(0, x0); x < math.min(canvas.width, x1); x++) {
      final si = ((y - oy) * ow + (x - ox)) * 4;
      final a = (sd[si + 3] * mul) >> 8;
      if (a == 0) continue;
      final ia = 255 - a;
      final di = (y * canvas.width + x) * 3;
      d[di] = (sd[si] * a + d[di] * ia + 127) ~/ 255;
      d[di + 1] = (sd[si + 1] * a + d[di + 1] * ia + 127) ~/ 255;
      d[di + 2] = (sd[si + 2] * a + d[di + 2] * ia + 127) ~/ 255;
    }
  }
}
