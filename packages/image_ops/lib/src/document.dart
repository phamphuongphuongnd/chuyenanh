// Document helpers: perspective rectification and simple paper detection.
import 'dart:math' as math;
import 'dart:typed_data';

import 'filters.dart' show otsuThreshold;
import 'models.dart';
import 'raw.dart';

/// Warps the quadrilateral [corners4] (TL, TR, BR, BL, normalised to the
/// EXIF-oriented image) to an upright rectangle.
///
/// Output size: width = mean of top/bottom edge lengths, height = mean of
/// left/right edge lengths (in source pixels), then scaled so the long side is
/// [outLongSide] when given. Encoded like [applyEdit] (JPEG unless real alpha).
Uint8List perspectiveWarp(
  Uint8List encoded,
  List<NormPoint> corners4, {
  int? outLongSide,
  int jpegQuality = 90,
  OutputFormat format = OutputFormat.auto,
}) {
  if (corners4.length != 4) {
    throw ArgumentError.value(corners4, 'corners4', 'needs exactly 4 points');
  }
  final decoded = decodeRaw(encoded);
  var src = applyOrientation(decoded.image, decoded.orientation);

  List<math.Point<double>> px(RawImage s) => [
        for (final c in corners4)
          math.Point(c.x.clamp(0.0, 1.0) * s.width,
              c.y.clamp(0.0, 1.0) * s.height)
      ];
  var p = px(src);
  double dist(math.Point<double> a, math.Point<double> b) => a.distanceTo(b);
  var outW = (dist(p[0], p[1]) + dist(p[3], p[2])) / 2;
  var outH = (dist(p[0], p[3]) + dist(p[1], p[2])) / 2;
  if (outW < 1 || outH < 1) {
    throw ArgumentError.value(corners4, 'corners4', 'degenerate quadrilateral');
  }
  if (outLongSide != null && outLongSide > 0) {
    final s = outLongSide / math.max(outW, outH);
    // Heavy shrink: pre-shrink the source with area averaging to avoid
    // aliasing from bilinear sampling.
    if (s < 0.5) {
      final target = (src.longSide * s * 1.5).ceil();
      src = downscaleToLongSide(src, target);
      p = px(src);
    }
    if (outW >= outH) {
      outW = outLongSide.toDouble();
      outH = outH * s;
    } else {
      outH = outLongSide.toDouble();
      outW = outW * s;
    }
  }
  final w = math.max(1, outW.round());
  final h = math.max(1, outH.round());
  final hm = _squareToQuad(p);
  if (hm == null) {
    throw ArgumentError.value(corners4, 'corners4', 'degenerate quadrilateral');
  }
  final out = _warp(src, hm, w, h);
  return encodeRaw(out, format, jpegQuality);
}

/// Homography mapping the unit square (0,0),(1,0),(1,1),(0,1) to [q]
/// (Heckbert). Returns [a,b,c,d,e,f,g,h] or null if degenerate.
List<double>? _squareToQuad(List<math.Point<double>> q) {
  final x0 = q[0].x, y0 = q[0].y, x1 = q[1].x, y1 = q[1].y;
  final x2 = q[2].x, y2 = q[2].y, x3 = q[3].x, y3 = q[3].y;
  final dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3;
  final dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3;
  final det = dx1 * dy2 - dx2 * dy1;
  if (det.abs() < 1e-9) return null;
  final g = (dx3 * dy2 - dx2 * dy3) / det;
  final h = (dx1 * dy3 - dx3 * dy1) / det;
  return [
    x1 - x0 + g * x1, x3 - x0 + h * x3, x0, //
    y1 - y0 + g * y1, y3 - y0 + h * y3, y0, //
    g, h,
  ];
}

RawImage _warp(RawImage src, List<double> m, int w, int h) {
  final ch = src.channels;
  final sw = src.width, sh = src.height;
  final s = src.data;
  final out = Uint8List(w * h * ch);
  final a = m[0], b = m[1], c = m[2], d = m[3], e = m[4], f = m[5];
  final g = m[6], hh = m[7];
  var o = 0;
  for (var oy = 0; oy < h; oy++) {
    final v = (oy + 0.5) / h;
    for (var ox = 0; ox < w; ox++) {
      final u = (ox + 0.5) / w;
      final den = g * u + hh * v + 1;
      // Continuous source coords -> pixel-centre space.
      var fx = (a * u + b * v + c) / den - 0.5;
      var fy = (d * u + e * v + f) / den - 0.5;
      if (fx < 0) fx = 0;
      if (fy < 0) fy = 0;
      if (fx > sw - 1) fx = (sw - 1).toDouble();
      if (fy > sh - 1) fy = (sh - 1).toDouble();
      final ix = fx.floor(), iy = fy.floor();
      final tx = fx - ix, ty = fy - iy;
      final ix1 = ix + 1 < sw ? ix + 1 : ix;
      final iy1 = iy + 1 < sh ? iy + 1 : iy;
      final i00 = (iy * sw + ix) * ch, i10 = (iy * sw + ix1) * ch;
      final i01 = (iy1 * sw + ix) * ch, i11 = (iy1 * sw + ix1) * ch;
      final w00 = (1 - tx) * (1 - ty), w10 = tx * (1 - ty);
      final w01 = (1 - tx) * ty, w11 = tx * ty;
      for (var k = 0; k < ch; k++) {
        final val = s[i00 + k] * w00 +
            s[i10 + k] * w10 +
            s[i01 + k] * w01 +
            s[i11 + k] * w11;
        out[o++] = (val + 0.5).toInt().clamp(0, 255);
      }
    }
  }
  return RawImage(w, h, ch, out);
}

/// Finds the sheet of paper in a photo: returns its corners (TL, TR, BR, BL,
/// normalised to the EXIF-oriented image), or null when not confident.
///
/// Method (on a ~400 px working copy): blur -> Otsu split into dark/light ->
/// for the largest connected regions of each class: fill holes (text), convex
/// hull, largest inscribed quadrilateral. A region is accepted only if it is
/// nearly convex, well approximated by its quad, covers 10..95% of the frame
/// and the two classes differ clearly in brightness. The largest accepted
/// quad wins.
List<NormPoint>? detectDocumentCorners(Uint8List encoded) {
  const work = 400;
  final decoded = decodeRaw(encoded, targetLongSide: work);
  var raw = applyOrientation(decoded.image, decoded.orientation);
  raw = downscaleToLongSide(raw, work);
  final w = raw.width, h = raw.height;
  if (w < 16 || h < 16) return null;

  final luma = _boxBlur(lumaOf(raw), w, h, 2);
  final hist = Int32List(256);
  for (final v in luma) {
    hist[v]++;
  }
  final t = otsuThreshold(hist);
  var n0 = 0, n1 = 0;
  var s0 = 0.0, s1 = 0.0;
  for (var i = 0; i < 256; i++) {
    if (i <= t) {
      n0 += hist[i];
      s0 += i * hist[i];
    } else {
      n1 += hist[i];
      s1 += i * hist[i];
    }
  }
  if (n0 == 0 || n1 == 0) return null;
  if (s1 / n1 - s0 / n0 < 30) return null; // no clear paper/background split

  final total = w * h;
  List<math.Point<double>>? best;
  var bestArea = 0.0;
  for (final light in const [false, true]) {
    final mask = Uint8List(total);
    for (var i = 0; i < total; i++) {
      mask[i] = ((luma[i] > t) == light) ? 1 : 0;
    }
    for (final comp in _largestComponents(mask, w, h, 2, total ~/ 20)) {
      final quad = _quadFromRegion(comp, w, h);
      if (quad != null && quad.area > bestArea) {
        bestArea = quad.area;
        best = quad.corners;
      }
    }
  }
  if (best == null) return null;
  return [for (final p in _orderCorners(best)) NormPoint(p.x / w, p.y / h)];
}

/// Separable box blur of radius [r] (clamped edges).
Uint8List _boxBlur(Uint8List src, int w, int h, int r) {
  final tmp = Uint8List(w * h);
  final out = Uint8List(w * h);
  final n = 2 * r + 1;
  for (var y = 0; y < h; y++) {
    final row = y * w;
    for (var x = 0; x < w; x++) {
      var acc = 0;
      for (var k = -r; k <= r; k++) {
        acc += src[row + (x + k).clamp(0, w - 1)];
      }
      tmp[row + x] = acc ~/ n;
    }
  }
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var acc = 0;
      for (var k = -r; k <= r; k++) {
        acc += tmp[(y + k).clamp(0, h - 1) * w + x];
      }
      out[y * w + x] = acc ~/ n;
    }
  }
  return out;
}

/// The [count] largest 4-connected components of [mask] with at least
/// [minArea] pixels, each returned as its own 0/1 mask.
List<Uint8List> _largestComponents(
    Uint8List mask, int w, int h, int count, int minArea) {
  final labels = Int32List(w * h);
  final stack = Int32List(w * h);
  final sizes = <int>[0];
  var next = 1;
  for (var start = 0; start < mask.length; start++) {
    if (mask[start] == 0 || labels[start] != 0) continue;
    var sp = 0;
    stack[sp++] = start;
    labels[start] = next;
    var size = 0;
    while (sp > 0) {
      final i = stack[--sp];
      size++;
      final x = i % w;
      if (x > 0 && mask[i - 1] == 1 && labels[i - 1] == 0) {
        labels[i - 1] = next;
        stack[sp++] = i - 1;
      }
      if (x < w - 1 && mask[i + 1] == 1 && labels[i + 1] == 0) {
        labels[i + 1] = next;
        stack[sp++] = i + 1;
      }
      if (i >= w && mask[i - w] == 1 && labels[i - w] == 0) {
        labels[i - w] = next;
        stack[sp++] = i - w;
      }
      if (i + w < mask.length && mask[i + w] == 1 && labels[i + w] == 0) {
        labels[i + w] = next;
        stack[sp++] = i + w;
      }
    }
    sizes.add(size);
    next++;
  }
  final order = [for (var l = 1; l < sizes.length; l++) l]
    ..sort((a, b) => sizes[b].compareTo(sizes[a]));
  final result = <Uint8List>[];
  for (final l in order.take(count)) {
    if (sizes[l] < minArea) break;
    final m = Uint8List(w * h);
    for (var i = 0; i < m.length; i++) {
      if (labels[i] == l) m[i] = 1;
    }
    result.add(m);
  }
  return result;
}

/// Fills holes of [m] in place (pixels not reachable from the border through
/// background). Returns the filled area.
int _fillHoles(Uint8List m, int w, int h) {
  final reach = Uint8List(w * h);
  final stack = Int32List(w * h);
  var sp = 0;
  void seed(int i) {
    if (m[i] == 0 && reach[i] == 0) {
      reach[i] = 1;
      stack[sp++] = i;
    }
  }

  for (var x = 0; x < w; x++) {
    seed(x);
    seed((h - 1) * w + x);
  }
  for (var y = 0; y < h; y++) {
    seed(y * w);
    seed(y * w + w - 1);
  }
  while (sp > 0) {
    final i = stack[--sp];
    final x = i % w;
    if (x > 0) seed(i - 1);
    if (x < w - 1) seed(i + 1);
    if (i >= w) seed(i - w);
    if (i + w < m.length) seed(i + w);
  }
  var area = 0;
  for (var i = 0; i < m.length; i++) {
    if (reach[i] == 0) {
      m[i] = 1;
      area++;
    }
  }
  return area;
}

double _cross(math.Point<double> o, math.Point<double> a, math.Point<double> b) =>
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

/// Andrew's monotone chain; returns hull vertices in order.
List<math.Point<double>> _convexHull(List<math.Point<double>> pts) {
  final p = [...pts]..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  if (p.length < 3) return p;
  final lower = <math.Point<double>>[];
  for (final q in p) {
    while (lower.length >= 2 && _cross(lower[lower.length - 2], lower.last, q) <= 0) {
      lower.removeLast();
    }
    lower.add(q);
  }
  final upper = <math.Point<double>>[];
  for (final q in p.reversed) {
    while (upper.length >= 2 && _cross(upper[upper.length - 2], upper.last, q) <= 0) {
      upper.removeLast();
    }
    upper.add(q);
  }
  lower.removeLast();
  upper.removeLast();
  return [...lower, ...upper];
}

double _polyArea(List<math.Point<double>> p) {
  var s = 0.0;
  for (var i = 0; i < p.length; i++) {
    final a = p[i], b = p[(i + 1) % p.length];
    s += a.x * b.y - b.x * a.y;
  }
  return s.abs() / 2;
}

/// Drops hull vertices that are within [eps] px of the line through their
/// neighbours (digitisation staircase).
List<math.Point<double>> _simplify(List<math.Point<double>> hull, double eps) {
  final p = [...hull];
  var changed = true;
  while (changed && p.length > 4) {
    changed = false;
    for (var i = 0; i < p.length && p.length > 4; i++) {
      final a = p[(i - 1 + p.length) % p.length];
      final b = p[i];
      final c = p[(i + 1) % p.length];
      final len = a.distanceTo(c);
      if (len == 0 || _cross(a, c, b).abs() / len < eps) {
        p.removeAt(i);
        changed = true;
        i--;
      }
    }
  }
  return p;
}

({List<math.Point<double>> corners, double area})? _quadFromRegion(
    Uint8List m, int w, int h) {
  final filled = _fillHoles(m, w, h);
  final pts = <math.Point<double>>[];
  for (var y = 0; y < h; y++) {
    final row = y * w;
    var x0 = -1, x1 = -1;
    for (var x = 0; x < w; x++) {
      if (m[row + x] == 1) {
        if (x0 < 0) x0 = x;
        x1 = x;
      }
    }
    if (x0 < 0) continue;
    pts
      ..add(math.Point(x0.toDouble(), y.toDouble()))
      ..add(math.Point(x0.toDouble(), y + 1.0))
      ..add(math.Point(x1 + 1.0, y.toDouble()))
      ..add(math.Point(x1 + 1.0, y + 1.0));
  }
  if (pts.length < 8) return null;
  final hull = _convexHull(pts);
  final hullArea = _polyArea(hull);
  if (hullArea <= 0 || filled / hullArea < 0.9) return null;
  final simple = _simplify(hull, 0.75);
  if (simple.length < 4 || simple.length > 150) return null;

  // Largest-area quadrilateral with vertices on the (simplified) hull.
  final n = simple.length;
  double tri(int i, int j, int k) =>
      _cross(simple[i % n], simple[j % n], simple[k % n]).abs() / 2;
  var bestArea = -1.0;
  var bi = 0, bj = 1, bk = 2, bl = 3;
  for (var i = 0; i < n; i++) {
    for (var k = i + 2; k < i + n - 1; k++) {
      var aj = -1.0, jj = i + 1;
      for (var j = i + 1; j < k; j++) {
        final a = tri(i, j, k);
        if (a > aj) {
          aj = a;
          jj = j;
        }
      }
      var al = -1.0, ll = k + 1;
      for (var l = k + 1; l < i + n; l++) {
        final a = tri(k, l, i);
        if (a > al) {
          al = a;
          ll = l;
        }
      }
      if (aj + al > bestArea) {
        bestArea = aj + al;
        bi = i;
        bj = jj;
        bk = k;
        bl = ll;
      }
    }
  }
  final quad = [simple[bi % n], simple[bj % n], simple[bk % n], simple[bl % n]];
  final total = (w * h).toDouble();
  if (bestArea / hullArea < 0.9) return null;
  if (bestArea < 0.10 * total || bestArea > 0.95 * total) return null;
  // Reject slivers: shortest edge at least 15% of the longest.
  final edges = [
    for (var i = 0; i < 4; i++) quad[i].distanceTo(quad[(i + 1) % 4])
  ];
  final maxE = edges.reduce(math.max), minE = edges.reduce(math.min);
  if (minE < 0.15 * maxE) return null;
  return (corners: quad, area: bestArea);
}

/// Orders four points as TL, TR, BR, BL (clockwise on screen, TL = min x+y).
List<math.Point<double>> _orderCorners(List<math.Point<double>> q) {
  final cx = q.fold(0.0, (s, p) => s + p.x) / 4;
  final cy = q.fold(0.0, (s, p) => s + p.y) / 4;
  final sorted = [...q]
    ..sort((a, b) => math
        .atan2(a.y - cy, a.x - cx)
        .compareTo(math.atan2(b.y - cy, b.x - cx)));
  // atan2 ascending with y down = clockwise on screen.
  var start = 0;
  for (var i = 1; i < 4; i++) {
    if (sorted[i].x + sorted[i].y < sorted[start].x + sorted[start].y) {
      start = i;
    }
  }
  return [for (var i = 0; i < 4; i++) sorted[(start + i) % 4]];
}
