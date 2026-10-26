// Colour filters working in place on [RawImage] buffers (alpha untouched).
import 'dart:math' as math;
import 'dart:typed_data';

import 'models.dart';
import 'raw.dart';

/// Applies [edit]'s filter and brightness/contrast to [img] in place.
///
/// Brightness/contrast are applied BEFORE grayscale/blackWhite (so they move
/// the threshold, which is what a user expects from the sliders) and AFTER the
/// auto-levelling filters (enhance/brighten/magicColor), which would otherwise
/// undo them.
void applyFilters(RawImage img, ImageEdit edit) {
  final hasBc = edit.brightness != 0 || edit.contrast != 0;
  switch (edit.filter) {
    case ImageFilter.original:
      if (hasBc) _applyBrightnessContrast(img, edit.brightness, edit.contrast);
    case ImageFilter.grayscale:
      if (hasBc) _applyBrightnessContrast(img, edit.brightness, edit.contrast);
      grayscale(img);
    case ImageFilter.blackWhite:
      if (hasBc) _applyBrightnessContrast(img, edit.brightness, edit.contrast);
      blackWhite(img, adaptive: edit.adaptiveThreshold);
    case ImageFilter.enhance:
      enhance(img);
      if (hasBc) _applyBrightnessContrast(img, edit.brightness, edit.contrast);
    case ImageFilter.brighten:
      brighten(img);
      if (hasBc) _applyBrightnessContrast(img, edit.brightness, edit.contrast);
    case ImageFilter.magicColor:
      magicColor(img);
      if (hasBc) _applyBrightnessContrast(img, edit.brightness, edit.contrast);
  }
}

int _clamp255(num v) {
  final i = v.round();
  return i < 0 ? 0 : (i > 255 ? 255 : i);
}

/// Applies one LUT to R, G and B.
void _applyLut(RawImage img, Uint8List lut) {
  final d = img.data;
  final ch = img.channels;
  if (ch == 3) {
    for (var i = 0; i < d.length; i++) {
      d[i] = lut[d[i]];
    }
  } else {
    for (var i = 0; i < d.length; i += 4) {
      d[i] = lut[d[i]];
      d[i + 1] = lut[d[i + 1]];
      d[i + 2] = lut[d[i + 2]];
    }
  }
}

void _applyBrightnessContrast(RawImage img, double brightness, double contrast) {
  final b = brightness.clamp(-1.0, 1.0) * 255;
  final k = 1 + contrast.clamp(-1.0, 1.0);
  final lut = Uint8List(256);
  for (var v = 0; v < 256; v++) {
    lut[v] = _clamp255((v - 128) * k + 128 + b);
  }
  _applyLut(img, lut);
}

void grayscale(RawImage img) {
  final d = img.data;
  final ch = img.channels;
  for (var i = 0; i < d.length; i += ch) {
    final l = (77 * d[i] + 150 * d[i + 1] + 29 * d[i + 2] + 128) >> 8;
    d[i] = l;
    d[i + 1] = l;
    d[i + 2] = l;
  }
}

Int32List _histogram(Uint8List values) {
  final h = Int32List(256);
  for (var i = 0; i < values.length; i++) {
    h[values[i]]++;
  }
  return h;
}

/// Otsu threshold: values <= T are the dark class.
int otsuThreshold(Int32List hist) {
  var total = 0;
  var sumAll = 0.0;
  for (var i = 0; i < 256; i++) {
    total += hist[i];
    sumAll += i * hist[i];
  }
  if (total == 0) return 127;
  var wB = 0;
  var sumB = 0.0;
  var best = -1.0;
  var t = 127;
  for (var i = 0; i < 256; i++) {
    wB += hist[i];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += i * hist[i];
    final mB = sumB / wB;
    final mF = (sumAll - sumB) / wF;
    final between = wB * wF * (mB - mF) * (mB - mF);
    if (between > best) {
      best = between;
      t = i;
    }
  }
  return t;
}

int _percentile(Int32List hist, int total, double p) {
  final target = total * p;
  var acc = 0;
  for (var i = 0; i < 256; i++) {
    acc += hist[i];
    if (acc >= target) return i;
  }
  return 255;
}

/// Pure black/white. Adaptive: Bradley-Roth local mean threshold (window
/// ~1/16 of the long side) plus a global "very dark" rule so large solid dark
/// areas stay black. Non-adaptive: global Otsu.
void blackWhite(RawImage img, {bool adaptive = true}) {
  final w = img.width, h = img.height, ch = img.channels;
  final luma = lumaOf(img);
  final otsu = otsuThreshold(_histogram(luma));
  final out = Uint8List(w * h); // 0 = black, 1 = white

  if (!adaptive) {
    for (var i = 0; i < luma.length; i++) {
      out[i] = luma[i] > otsu ? 1 : 0;
    }
  } else {
    final r = math.max(7, math.max(w, h) ~/ 32);
    const k = 0.15;
    final darkCut = otsu * 0.4;
    // Horizontal running sums (clamped window), then vertical running sums.
    final hs = Uint32List(w * h);
    for (var y = 0; y < h; y++) {
      final row = y * w;
      var acc = 0;
      // Window [x - r, x + r] clamped.
      for (var x = 0; x <= math.min(r, w - 1); x++) {
        acc += luma[row + x];
      }
      for (var x = 0; x < w; x++) {
        hs[row + x] = acc;
        final add = x + r + 1;
        final rem = x - r;
        if (add < w) acc += luma[row + add];
        if (rem >= 0) acc -= luma[row + rem];
      }
    }
    final col = Uint32List(w);
    for (var y = 0; y <= math.min(r, h - 1); y++) {
      final row = y * w;
      for (var x = 0; x < w; x++) {
        col[x] += hs[row + x];
      }
    }
    for (var y = 0; y < h; y++) {
      final y0 = math.max(0, y - r), y1 = math.min(h - 1, y + r);
      final rows = y1 - y0 + 1;
      final row = y * w;
      for (var x = 0; x < w; x++) {
        final x0 = math.max(0, x - r), x1 = math.min(w - 1, x + r);
        final area = rows * (x1 - x0 + 1);
        final l = luma[row + x];
        final dark = l * area < col[x] * (1 - k) || l < darkCut;
        out[row + x] = dark ? 0 : 1;
      }
      final add = y + r + 1;
      final rem = y - r;
      if (add < h) {
        final ar = add * w;
        for (var x = 0; x < w; x++) {
          col[x] += hs[ar + x];
        }
      }
      if (rem >= 0) {
        final rr = rem * w;
        for (var x = 0; x < w; x++) {
          col[x] -= hs[rr + x];
        }
      }
    }
  }

  final d = img.data;
  for (var i = 0, j = 0; j < out.length; i += ch, j++) {
    final v = out[j] == 1 ? 255 : 0;
    d[i] = v;
    d[i + 1] = v;
    d[i + 2] = v;
  }
}

/// Contrast stretch on the 1%..99% luma range (gain capped at 2.5) followed by
/// a light unsharp mask (3x3 box, amount 0.6).
void enhance(RawImage img) {
  final luma = lumaOf(img);
  final hist = _histogram(luma);
  final lo = _percentile(hist, luma.length, 0.01);
  final hi = _percentile(hist, luma.length, 0.99);
  final range = math.max(1, hi - lo);
  final gain = math.min(2.5, 255 / range);
  final mid = (lo + hi) / 2;
  final lut = Uint8List(256);
  for (var v = 0; v < 256; v++) {
    lut[v] = _clamp255((v - mid) * gain + 127.5);
  }
  _applyLut(img, lut);
  sharpen(img, amount: 0.6);
}

/// Unsharp mask with a 3x3 box blur; edges use clamped neighbours.
void sharpen(RawImage img, {double amount = 0.5}) {
  final w = img.width, h = img.height, ch = img.channels;
  if (w < 3 || h < 3) return;
  final d = img.data;
  final stride = w * ch;
  // Horizontal 3-sums.
  final hs = Uint16List(d.length);
  for (var y = 0; y < h; y++) {
    final row = y * stride;
    for (var x = 0; x < w; x++) {
      final xl = x == 0 ? 0 : x - 1, xr = x == w - 1 ? w - 1 : x + 1;
      final i = row + x * ch, il = row + xl * ch, ir = row + xr * ch;
      hs[i] = d[il] + d[i] + d[ir];
      hs[i + 1] = d[il + 1] + d[i + 1] + d[ir + 1];
      hs[i + 2] = d[il + 2] + d[i + 2] + d[ir + 2];
    }
  }
  final a = (amount * 256).round();
  final orig = Uint8List.fromList(d);
  for (var y = 0; y < h; y++) {
    final up = (y == 0 ? 0 : y - 1) * stride;
    final row = y * stride;
    final dn = (y == h - 1 ? h - 1 : y + 1) * stride;
    for (var x = 0; x < w; x++) {
      final o = x * ch;
      for (var c = 0; c < 3; c++) {
        final i = row + o + c;
        final blur9 = hs[up + o + c] + hs[i] + hs[dn + o + c];
        final v = orig[i];
        // v + amount * (v - blur), integer maths: blur = blur9 / 9.
        final nv = v + ((a * (9 * v - blur9)) ~/ (9 * 256));
        d[i] = nv < 0 ? 0 : (nv > 255 ? 255 : nv);
      }
    }
  }
}

/// Gamma lift (0.7) plus a small offset.
void brighten(RawImage img) {
  final lut = Uint8List(256);
  for (var v = 0; v < 256; v++) {
    lut[v] = _clamp255(255 * math.pow(v / 255, 0.7) + 6);
  }
  _applyLut(img, lut);
}

/// "Document scan" colour: per-channel white point at the 97th percentile
/// (white-balances the paper), black point at the 2nd percentile, then a
/// little contrast and saturation.
void magicColor(RawImage img) {
  final d = img.data;
  final ch = img.channels;
  final n = img.width * img.height;
  final hists = [Int32List(256), Int32List(256), Int32List(256)];
  for (var i = 0; i < d.length; i += ch) {
    hists[0][d[i]]++;
    hists[1][d[i + 1]]++;
    hists[2][d[i + 2]]++;
  }
  final luts = <Uint8List>[];
  for (var c = 0; c < 3; c++) {
    var white = _percentile(hists[c], n, 0.97);
    var black = _percentile(hists[c], n, 0.02);
    if (white - black < 48) {
      black = math.max(0, white - 48);
      if (white - black < 48) white = black + 48;
    }
    final lut = Uint8List(256);
    for (var v = 0; v < 256; v++) {
      final t = ((v - black) / (white - black)).clamp(0.0, 1.0);
      // Mild contrast curve on the normalised value.
      final s = (t - 0.5) * 1.15 + 0.5;
      lut[v] = _clamp255(s * 255);
    }
    luts.add(lut);
  }
  final lr = luts[0], lg = luts[1], lb = luts[2];
  const sat = 1.25;
  for (var i = 0; i < d.length; i += ch) {
    final r = lr[d[i]], g = lg[d[i + 1]], b = lb[d[i + 2]];
    final l = (77 * r + 150 * g + 29 * b) >> 8;
    d[i] = _clamp255(l + (r - l) * sat);
    d[i + 1] = _clamp255(l + (g - l) * sat);
    d[i + 2] = _clamp255(l + (b - l) * sat);
  }
}
