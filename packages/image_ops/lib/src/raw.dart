// Internal raw-pixel helpers: decode/encode via package:image, and fast
// geometry (orient, rotate, crop, area resize) on interleaved uint8 buffers.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'models.dart';

/// Interleaved 8-bit RGB (3 channels) or RGBA (4 channels), no row padding.
class RawImage {
  final int width, height, channels;
  final Uint8List data;

  RawImage(this.width, this.height, this.channels, this.data)
      : assert(data.length == width * height * channels);

  factory RawImage.blank(int width, int height, int channels) =>
      RawImage(width, height, channels, Uint8List(width * height * channels));

  int get longSide => math.max(width, height);

  /// True when at least one pixel is not fully opaque.
  bool get hasRealAlpha {
    if (channels != 4) return false;
    final d = data;
    for (var i = 3; i < d.length; i += 4) {
      if (d[i] != 255) return true;
    }
    return false;
  }
}

/// A decoded source plus what we learned about its container.
class Decoded {
  final RawImage image;
  final ImageSourceFormat format;
  final int orientation;

  Decoded(this.image, this.format, this.orientation);
}

ImageSourceFormat _mapFormat(img.ImageFormat f) => switch (f) {
      img.ImageFormat.jpg => ImageSourceFormat.jpeg,
      img.ImageFormat.png => ImageSourceFormat.png,
      img.ImageFormat.webp => ImageSourceFormat.webp,
      img.ImageFormat.bmp => ImageSourceFormat.bmp,
      img.ImageFormat.gif => ImageSourceFormat.gif,
      _ => ImageSourceFormat.other,
    };

FormatException _bad() =>
    const FormatException('Unsupported or corrupt image data');

img.Decoder _decoderFor(Uint8List bytes) {
  final d = img.findDecoderForData(bytes);
  if (d == null) throw _bad();
  return d;
}

/// Decodes the first frame of [bytes]. When [targetLongSide] is given and the
/// source is a large JPEG, the DCT-domain reduced-scale decode is used so the
/// result is still at least [targetLongSide] on its long side.
///
/// The EXIF orientation is reported but NOT yet applied.
Decoded decodeRaw(Uint8List bytes, {int? targetLongSide}) {
  final decoder = _decoderFor(bytes);
  final format = _mapFormat(decoder.format);
  img.Image? im;
  var orientation = 1;
  try {
    if (format == ImageSourceFormat.jpeg) {
      var scale = 1;
      if (targetLongSide != null && targetLongSide > 0) {
        final info = img.JpegDecoder().startDecode(bytes);
        if (info != null) {
          final long = math.max(info.width, info.height);
          for (final s in const [8, 4, 2]) {
            if ((long + s - 1) ~/ s >= targetLongSide) {
              scale = s;
              break;
            }
          }
        }
      }
      im = img.JpegDecoder(scale: scale).decode(bytes);
    } else {
      im = decoder.decode(bytes, frame: 0);
    }
    // package:image's JPEG decoder already bakes the EXIF orientation and
    // clears the tag; whatever tag is left on the decoded image (any format)
    // still has to be applied.
    if (im != null && im.exif.imageIfd.hasOrientation) {
      orientation = im.exif.imageIfd.orientation ?? 1;
    }
  } on FormatException {
    rethrow;
  } catch (_) {
    throw _bad();
  }
  if (im == null || im.width == 0 || im.height == 0) throw _bad();
  return Decoded(toRaw(im), format, orientation);
}

/// Converts a package:image [img.Image] to a tightly packed RGB/RGBA buffer.
RawImage toRaw(img.Image src) {
  final ch = src.hasAlpha ? 4 : 3;
  var im = src;
  if (im.format != img.Format.uint8 || im.numChannels != ch || im.hasPalette) {
    im = im.convert(format: img.Format.uint8, numChannels: ch);
  }
  final w = im.width, h = im.height;
  final bytes = im.toUint8List();
  if (bytes.length == w * h * ch) {
    return RawImage(w, h, ch, bytes);
  }
  // Padded rows or an unexpected layout: copy pixel by pixel.
  final out = Uint8List(w * h * ch);
  var i = 0;
  for (final p in im) {
    out[i++] = p.r.toInt();
    out[i++] = p.g.toInt();
    out[i++] = p.b.toInt();
    if (ch == 4) out[i++] = p.a.toInt();
  }
  return RawImage(w, h, ch, out);
}

/// Encodes [raw] according to [format] (auto = JPEG unless real alpha).
/// Metadata (EXIF, GPS…) is not written.
Uint8List encodeRaw(RawImage raw, OutputFormat format, int jpegQuality) {
  final alpha = raw.hasRealAlpha;
  final usePng = format == OutputFormat.png ||
      (format == OutputFormat.auto && alpha);
  var r = raw;
  if (usePng) {
    if (r.channels == 4 && !alpha) r = dropAlpha(r);
    return img.encodePng(_toImage(r), level: 6);
  }
  if (r.channels == 4) r = flattenOnWhite(r);
  return img.encodeJpg(_toImage(r),
      quality: jpegQuality.clamp(1, 100), chroma: img.JpegChroma.yuv420);
}

img.Image _toImage(RawImage r) => img.Image.fromBytes(
      width: r.width,
      height: r.height,
      bytes: r.data.buffer,
      bytesOffset: r.data.offsetInBytes,
      numChannels: r.channels,
    );

RawImage dropAlpha(RawImage src) {
  final n = src.width * src.height;
  final out = Uint8List(n * 3);
  final d = src.data;
  for (var i = 0, j = 0; i < n * 4; i += 4, j += 3) {
    out[j] = d[i];
    out[j + 1] = d[i + 1];
    out[j + 2] = d[i + 2];
  }
  return RawImage(src.width, src.height, 3, out);
}

RawImage flattenOnWhite(RawImage src) {
  final n = src.width * src.height;
  final out = Uint8List(n * 3);
  final d = src.data;
  for (var i = 0, j = 0; i < n * 4; i += 4, j += 3) {
    final a = d[i + 3];
    final ia = 255 - a;
    out[j] = (d[i] * a + 255 * ia + 127) ~/ 255;
    out[j + 1] = (d[i + 1] * a + 255 * ia + 127) ~/ 255;
    out[j + 2] = (d[i + 2] * a + 255 * ia + 127) ~/ 255;
  }
  return RawImage(src.width, src.height, 3, out);
}

/// Rotates clockwise by [turns] quarter turns (0..3).
RawImage rotateCw(RawImage src, int turns) {
  turns %= 4;
  if (turns == 0) return src;
  final sw = src.width, sh = src.height, ch = src.channels;
  final s = src.data;
  final dw = turns == 2 ? sw : sh;
  final dh = turns == 2 ? sh : sw;
  final out = Uint8List(dw * dh * ch);
  var o = 0;
  for (var y = 0; y < dh; y++) {
    for (var x = 0; x < dw; x++) {
      final int sx, sy;
      switch (turns) {
        case 1:
          sx = y;
          sy = sh - 1 - x;
        case 2:
          sx = sw - 1 - x;
          sy = sh - 1 - y;
        default:
          sx = sw - 1 - y;
          sy = x;
      }
      var si = (sy * sw + sx) * ch;
      out[o++] = s[si++];
      out[o++] = s[si++];
      out[o++] = s[si++];
      if (ch == 4) out[o++] = s[si];
    }
  }
  return RawImage(dw, dh, ch, out);
}

RawImage flipHorizontal(RawImage src) {
  final w = src.width, h = src.height, ch = src.channels;
  final s = src.data;
  final out = Uint8List(s.length);
  for (var y = 0; y < h; y++) {
    final row = y * w * ch;
    for (var x = 0; x < w; x++) {
      final si = row + x * ch;
      final di = row + (w - 1 - x) * ch;
      for (var c = 0; c < ch; c++) {
        out[di + c] = s[si + c];
      }
    }
  }
  return RawImage(w, h, ch, out);
}

/// Applies an EXIF orientation value (1..8) so the pixels are upright.
RawImage applyOrientation(RawImage src, int orientation) => switch (orientation) {
      2 => flipHorizontal(src),
      3 => rotateCw(src, 2),
      4 => flipHorizontal(rotateCw(src, 2)),
      5 => flipHorizontal(rotateCw(src, 1)),
      6 => rotateCw(src, 1),
      7 => flipHorizontal(rotateCw(src, 3)),
      8 => rotateCw(src, 3),
      _ => src,
    };

/// Whether [orientation] swaps width and height.
bool orientationSwaps(int orientation) => orientation >= 5 && orientation <= 8;

/// Crops the pixel rectangle [x0, x1) x [y0, y1).
RawImage cropPx(RawImage src, int x0, int y0, int x1, int y1) {
  if (x0 == 0 && y0 == 0 && x1 == src.width && y1 == src.height) return src;
  final ch = src.channels;
  final w = x1 - x0, h = y1 - y0;
  final out = Uint8List(w * h * ch);
  final rowLen = w * ch;
  for (var y = 0; y < h; y++) {
    final si = ((y0 + y) * src.width + x0) * ch;
    out.setRange(y * rowLen, (y + 1) * rowLen, src.data, si);
  }
  return RawImage(w, h, ch, out);
}

/// Crops by a normalised rectangle (clamped, at least 1 px).
RawImage cropNorm(RawImage src, NormRect r) {
  double c(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0);
  final l = c(r.left), t = c(r.top), rr = c(r.left + r.width), b = c(r.top + r.height);
  var x0 = (l * src.width).round(), x1 = (rr * src.width).round();
  var y0 = (t * src.height).round(), y1 = (b * src.height).round();
  x0 = x0.clamp(0, src.width - 1);
  y0 = y0.clamp(0, src.height - 1);
  x1 = x1.clamp(x0 + 1, src.width);
  y1 = y1.clamp(y0 + 1, src.height);
  return cropPx(src, x0, y0, x1, y1);
}

/// Maps a rect given in the frame rotated clockwise by [turns] back to the
/// unrotated frame.
NormRect unrotateRect(NormRect r, int turns) => switch (turns % 4) {
      1 => NormRect(
          left: r.top, top: 1 - r.right, width: r.height, height: r.width),
      2 => NormRect(
          left: 1 - r.right, top: 1 - r.bottom, width: r.width, height: r.height),
      3 => NormRect(
          left: 1 - r.bottom, top: r.left, width: r.height, height: r.width),
      _ => r,
    };

/// Area-averaging (box) downscale so the long side is at most [maxLong].
/// Never upscales.
RawImage downscaleToLongSide(RawImage src, int maxLong) {
  if (maxLong <= 0 || src.longSide <= maxLong) return src;
  final s = maxLong / src.longSide;
  final dw = math.max(1, (src.width * s).round());
  final dh = math.max(1, (src.height * s).round());
  return resizeArea(src, dw, dh);
}

/// Separable area-average resample to [dw] x [dh] (intended for shrinking).
RawImage resizeArea(RawImage src, int dw, int dh) {
  if (dw == src.width && dh == src.height) return src;
  final ch = src.channels;
  // Horizontal pass: src.width -> dw, rows unchanged.
  final tmp = Uint8List(dw * src.height * ch);
  _resample1d(src.data, tmp, src.width, dw, src.height, ch, true);
  final out = Uint8List(dw * dh * ch);
  _resample1d(tmp, out, src.height, dh, dw, ch, false);
  return RawImage(dw, dh, ch, out);
}

/// Resamples along one axis. [horizontal]: lines are rows of length [sn]
/// (count [lines]); otherwise lines are columns. Weights are 14-bit fixed
/// point, stored flat ([maxTaps] slots per destination index).
void _resample1d(Uint8List s, Uint8List d, int sn, int dn, int lines, int ch,
    bool horizontal) {
  const shift = 14;
  const one = 1 << shift;
  const half = 1 << (shift - 1);
  final scale = sn / dn;
  final maxTaps = math.max(2, scale.ceil() + 2);
  final starts = Int32List(dn);
  final counts = Int32List(dn);
  final weights = Int32List(dn * maxTaps);
  final tmpW = Float64List(maxTaps);
  for (var i = 0; i < dn; i++) {
    final double a, b;
    if (scale >= 1) {
      a = i * scale;
      b = math.min(sn.toDouble(), (i + 1) * scale);
    } else {
      // Upscaling (not used by the pipeline): one-pixel window.
      final c = (i + 0.5) * scale - 0.5;
      a = c.clamp(0.0, sn - 1.0);
      b = math.min(sn.toDouble(), a + 1);
    }
    final first = a.floor();
    final last = math.min(sn - 1, b.ceil() - 1);
    final n = math.min(maxTaps, math.max(1, last - first + 1));
    var total = 0.0;
    for (var k = 0; k < n; k++) {
      final p = first + k;
      final ov = math.min(b, p + 1.0) - math.max(a, p.toDouble());
      tmpW[k] = ov > 0 ? ov : 0;
      total += tmpW[k];
    }
    if (total <= 0) {
      tmpW[0] = 1;
      total = 1;
    }
    // Integer weights summing exactly to `one`.
    var sum = 0;
    for (var k = 0; k < n; k++) {
      final wk = (tmpW[k] / total * one).round();
      weights[i * maxTaps + k] = wk;
      sum += wk;
    }
    weights[i * maxTaps] += one - sum;
    starts[i] = first;
    counts[i] = n;
  }

  if (horizontal) {
    for (var y = 0; y < lines; y++) {
      final sRow = y * sn * ch;
      final dRow = y * dn * ch;
      for (var i = 0; i < dn; i++) {
        final n = counts[i];
        final wBase = i * maxTaps;
        final si = sRow + starts[i] * ch;
        final di = dRow + i * ch;
        if (ch == 3) {
          var r = half, g = half, bb = half;
          var p = si;
          for (var k = 0; k < n; k++, p += 3) {
            final wk = weights[wBase + k];
            r += s[p] * wk;
            g += s[p + 1] * wk;
            bb += s[p + 2] * wk;
          }
          d[di] = r >> shift;
          d[di + 1] = g >> shift;
          d[di + 2] = bb >> shift;
        } else {
          for (var c = 0; c < ch; c++) {
            var acc = half;
            var p = si + c;
            for (var k = 0; k < n; k++, p += ch) {
              acc += s[p] * weights[wBase + k];
            }
            d[di + c] = acc >> shift;
          }
        }
      }
    }
  } else {
    // Columns: lines = width; process destination rows, accumulating whole
    // source rows for cache friendliness.
    final rowLen = lines * ch;
    final acc = Int32List(rowLen);
    for (var i = 0; i < dn; i++) {
      acc.fillRange(0, rowLen, half);
      final n = counts[i];
      for (var k = 0; k < n; k++) {
        final wk = weights[i * maxTaps + k];
        final sRow = (starts[i] + k) * rowLen;
        for (var x = 0; x < rowLen; x++) {
          acc[x] += s[sRow + x] * wk;
        }
      }
      final dRow = i * rowLen;
      for (var x = 0; x < rowLen; x++) {
        d[dRow + x] = acc[x] >> shift;
      }
    }
  }
}

/// Rec.601 luma (0..255) of every pixel.
Uint8List lumaOf(RawImage src) {
  final n = src.width * src.height;
  final out = Uint8List(n);
  final d = src.data;
  final ch = src.channels;
  for (var i = 0, j = 0; j < n; i += ch, j++) {
    out[j] = (77 * d[i] + 150 * d[i + 1] + 29 * d[i + 2] + 128) >> 8;
  }
  return out;
}
