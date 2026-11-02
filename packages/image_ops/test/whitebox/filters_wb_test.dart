// Kiểm thử hộp trắng (A16, Bước 6) cho lib/src/filters.dart.
// Expected chép từ test-output/whitebox/image-ops/filters/buoc-5-du-lieu-thu.md.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image_ops/image_ops.dart';
import 'package:image_ops/src/filters.dart';
import 'package:image_ops/src/raw.dart';
import 'package:test/test.dart';

import '../helpers.dart';

RawImage copy(RawImage r) =>
    RawImage(r.width, r.height, r.channels, Uint8List.fromList(r.data));

/// Công thức trong doc-comment models.dart:103-107: v' = (v − 128)(1 + c) + 128 + b·255, kẹp 0..255.
int bcRef(int v, double b, double c) =>
    ((v - 128) * (1 + c) + 128 + b * 255).round().clamp(0, 255);

/// Áp công thức BC lên R, G, B (giữ alpha) — tham chiếu độc lập với code.
RawImage bc(RawImage r, double b, double c) {
  final o = copy(r);
  for (var i = 0; i < o.data.length; i++) {
    if (o.channels == 4 && i % 4 == 3) continue;
    o.data[i] = bcRef(o.data[i], b, c);
  }
  return o;
}

RawImage solid(int w, int h, List<int> px) {
  final d = Uint8List(w * h * px.length);
  for (var i = 0; i < d.length; i++) {
    d[i] = px[i % px.length];
  }
  return RawImage(w, h, px.length, d);
}

RawImage run(RawImage src, ImageEdit e) {
  final o = copy(src);
  applyFilters(o, e);
  return o;
}

double std(Uint8List d) {
  final m = d.reduce((a, b) => a + b) / d.length;
  return math.sqrt(d.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) / d.length);
}

void main() {
  final photo = toRaw(photoLike(40, 30));
  // Ảnh dải hẹp 120..136 (để enhance không chạm 0/255 rồi cộng 51 không bị kẹp).
  final narrow = RawImage(17, 8, 3, Uint8List.fromList([
    for (var y = 0; y < 8; y++)
      for (var x = 0; x < 17; x++) ...[120 + x, 120 + x, 120 + x]
  ]));

  group('U1 applyFilters', () {
    test('AF-1 original + brightness 0.2 ⇒ mỗi kênh = công thức BC (D1 Đ, D3 Đ, D8 Đ)', () {
      expect(run(photo, const ImageEdit(brightness: 0.2)).data, bc(photo, 0.2, 0).data);
    });
    test('AF-2 original + contrast 0.5 ⇒ công thức BC (D1 S, D2 Đ)', () {
      expect(run(photo, const ImageEdit(contrast: 0.5)).data, bc(photo, 0, 0.5).data);
    });
    test('AF-3 original, không BC ⇒ không đổi (D2 S, D8 S)', () {
      expect(run(photo, const ImageEdit()).data, photo.data);
    });
    test('AF-4 grayscale + brightness ⇒ BC trước rồi mới xám (D4 Đ, D9 Đ)', () {
      final ref = bc(photo, 0.2, 0);
      grayscale(ref);
      expect(run(photo, const ImageEdit(filter: ImageFilter.grayscale, brightness: 0.2)).data,
          ref.data);
      final px = run(solid(1, 1, [250, 10, 10]),
          const ImageEdit(filter: ImageFilter.grayscale, brightness: 0.2));
      expect(px.data[0], closeTo(119, 1.5), reason: 'BC trước: luma(255,61,61) ≈ 119; xám trước sẽ ≈ 133');
    });
    test('AF-5 blackWhite + BC ⇒ BC trước ngưỡng; contrast −1 vẫn chỉ ra 0/255 (D5 Đ, D10 Đ)', () {
      for (final adaptive in [true, false]) {
        final ref = bc(photo, 0.3, 0.2);
        blackWhite(ref, adaptive: adaptive);
        expect(
            run(photo, ImageEdit(
                    filter: ImageFilter.blackWhite,
                    brightness: 0.3,
                    contrast: 0.2,
                    adaptiveThreshold: adaptive))
                .data,
            ref.data,
            reason: 'adaptive $adaptive');
      }
      final flat = run(photo, const ImageEdit(filter: ImageFilter.blackWhite, contrast: -1));
      expect(flat.data.every((v) => v == 0 || v == 255), isTrue);
    });
    test('AF-6 enhance + brightness ⇒ BC sau enhance (D6 Đ, D11 Đ)', () {
      final ref = copy(narrow);
      enhance(ref);
      final out = run(narrow, const ImageEdit(filter: ImageFilter.enhance, brightness: 0.2));
      expect(out.data, bc(ref, 0.2, 0).data);
    });
    test('AF-7 brighten + brightness ⇒ BC sau brighten (D7 Đ, D12 Đ)', () {
      final ref = copy(photo);
      brighten(ref);
      expect(run(photo, const ImageEdit(filter: ImageFilter.brighten, brightness: 0.2)).data,
          bc(ref, 0.2, 0).data);
    });
    test('AF-8 magicColor + brightness ⇒ BC sau magicColor (D7 S, D13 Đ)', () {
      final ref = copy(photo);
      magicColor(ref);
      expect(run(photo, const ImageEdit(filter: ImageFilter.magicColor, brightness: 0.2)).data,
          bc(ref, 0.2, 0).data);
    });
    final noBc = <String, (ImageFilter, void Function(RawImage))>{
      'AF-10 grayscale (D9 S)': (ImageFilter.grayscale, grayscale),
      'AF-11 blackWhite (D10 S)': (ImageFilter.blackWhite, (r) => blackWhite(r)),
      'AF-12 enhance (D11 S)': (ImageFilter.enhance, enhance),
      'AF-13 brighten (D12 S)': (ImageFilter.brighten, brighten),
      'AF-14 magicColor (D13 S)': (ImageFilter.magicColor, magicColor),
    };
    for (final e in noBc.entries) {
      test('${e.key} không BC ⇒ đúng bằng bộ lọc riêng', () {
        final ref = copy(photo);
        e.value.$2(ref);
        expect(run(photo, ImageEdit(filter: e.value.$1)).data, ref.data);
      });
    }
  });

  group('U2 _clamp255 (qua BC)', () {
    final mid = solid(2, 1, [10, 128, 250]);
    test('CL-1 brightness −1 ⇒ 0 (D1 Đ)',
        () => expect(run(mid, const ImageEdit(brightness: -1)).data.toSet(), {0}));
    test('CL-2 brightness 1 ⇒ 255 (D2 Đ)',
        () => expect(run(mid, const ImageEdit(brightness: 1)).data.toSet(), {255}));
    test('CL-3 brightness 0.1 ⇒ trong khoảng, +25.5 làm tròn (D2 S)', () {
      expect(run(mid, const ImageEdit(brightness: 0.1)).data.sublist(0, 3), [36, 154, 255]);
    });
  });

  group('U3 _applyLut', () {
    test('LT-1 RGB: mọi byte qua LUT (D1 Đ)',
        () => expect(run(solid(1, 1, [100, 100, 100]), const ImageEdit(brightness: 0.2)).data, [151, 151, 151]));
    test('LT-2 RGBA: alpha giữ nguyên (D1 S)', () {
      expect(run(solid(2, 1, [100, 100, 100, 77]), const ImageEdit(brightness: 0.2)).data,
          [151, 151, 151, 77, 151, 151, 151, 77]);
    });
  });

  Int32List hist(Map<int, int> m) {
    final h = Int32List(256);
    m.forEach((k, v) => h[k] = v);
    return h;
  }

  group('U4 otsuThreshold', () {
    test('OT-1 {0:5, 255:5} ⇒ T tách hai lớp: 0 ≤ T < 255 (D3 S, D4 Đ, D5 Đ/S)', () {
      expect(otsuThreshold(hist({0: 5, 255: 5})), inInclusiveRange(0, 254));
    });
    test('OT-2 histogram rỗng ⇒ 127 (D1 Đ)', () => expect(otsuThreshold(Int32List(256)), 127));
    test('OT-3 {100:4, 200:4} ⇒ 100 ≤ T < 200 (D3 Đ ở các bin trống đầu)', () {
      expect(otsuThreshold(hist({100: 4, 200: 4})), inInclusiveRange(100, 199));
    });
    test('OT-4 chỉ 1 bin {0:10} ⇒ không ném, T trong 0..255 (D4 Đ ngay lượt đầu)', () {
      expect(otsuThreshold(hist({0: 10})), inInclusiveRange(0, 255));
    });
    test('OT-5 {10:1, 20:1, 250:8} ⇒ 20 ≤ T < 250 (D5 S ở các lượt sau)', () {
      expect(otsuThreshold(hist({10: 1, 20: 1, 250: 8})), inInclusiveRange(20, 249));
    });
  });

  group('U5 _percentile (qua enhance)', () {
    test('PC-1 nửa đen nửa trắng (1 % thấp = 0 ⇒ D2 Đ ngay i = 0) ⇒ không kéo giãn: vùng phẳng giữ 0 / 255', () {
      final r = RawImage(20, 20, 3, Uint8List.fromList([
        for (var y = 0; y < 20; y++)
          for (var x = 0; x < 20; x++) ...(x < 10 ? [0, 0, 0] : [255, 255, 255])
      ]));
      enhance(r);
      expect(r.data[(10 * 20 + 3) * 3], 0);
      expect(r.data[(10 * 20 + 16) * 3], 255);
    });
    test('PC-2 dải hẹp 120..136 (D2 S nhiều lượt) ⇒ độ lệch chuẩn tăng ≥ 2 lần', () {
      final r = copy(narrow);
      enhance(r);
      expect(std(r.data), greaterThanOrEqualTo(2 * std(narrow.data)));
    });
  });

  group('U6 blackWhite', () {
    test('BW-1 Otsu: luma [10,10,240,240] ⇒ [0,0,255,255] (D1 Đ, D2 Đ/S, D9 Đ/S)', () {
      final r = RawImage(4, 1, 3, Uint8List.fromList([10, 10, 10, 10, 10, 10, 240, 240, 240, 240, 240, 240]));
      blackWhite(r, adaptive: false);
      expect([for (var i = 0; i < 4; i++) r.data[i * 3]], [0, 0, 255, 255]);
    });
    test('BW-3 adaptive: nét chữ xám mảnh ⇒ đen, nền trắng ⇒ trắng, mảng đen lớn ⇒ đen, chỉ 0/255 (D1 S, D3..D8)', () {
      const w = 64, h = 64;
      final d = Uint8List(w * h * 3)..fillRange(0, w * h * 3, 255);
      void set(int x, int y, int v) => d.fillRange((y * w + x) * 3, (y * w + x) * 3 + 3, v);
      for (var x = 10; x <= 30; x++) {
        set(x, 10, 100); // nét chữ 1 px
      }
      for (var y = 36; y < 60; y++) {
        for (var x = 36; x < 60; x++) {
          set(x, y, 0); // mảng đen 24x24
        }
      }
      final r = RawImage(w, h, 3, d);
      blackWhite(r);
      int at(int x, int y) => r.data[(y * w + x) * 3];
      expect(at(20, 10), 0, reason: 'nét chữ (D5 Đ)');
      expect(at(5, 5), 255, reason: 'nền (D6 S)');
      expect(at(47, 47), 0, reason: 'giữa mảng đen lớn (D5 S, D6 Đ)');
      expect(r.data.every((v) => v == 0 || v == 255), isTrue);
    });
  });

  group('U7 sharpen', () {
    RawImage grid(int w, int h, int centre, int other) => RawImage(w, h, 3, Uint8List.fromList([
          for (var y = 0; y < h; y++)
            for (var x = 0; x < w; x++)
              ...List.filled(3, x == w ~/ 2 && y == h ~/ 2 ? centre : other)
        ]));
    test('SH-1 3x3 tâm 200 nền 100 ⇒ tâm ≈ 244,4, góc ≈ 94,4 (D3..D6 Đ/S, D7 S, D8 S)', () {
      final r = grid(3, 3, 200, 100);
      sharpen(r);
      expect(r.data[4 * 3], closeTo(244.4, 1));
      expect(r.data[0], closeTo(94.4, 1));
    });
    test('SH-2 rộng 2 ⇒ không đổi (D1 Đ)', () {
      final r = grid(2, 3, 200, 100);
      final before = Uint8List.fromList(r.data);
      sharpen(r);
      expect(r.data, before);
    });
    test('SH-3 cao 2 ⇒ không đổi (D2 Đ)', () {
      final r = grid(3, 2, 200, 100);
      final before = Uint8List.fromList(r.data);
      sharpen(r);
      expect(r.data, before);
    });
    test('SH-7 tâm 0 nền 255 ⇒ tâm kẹp 0 (D7 Đ)', () {
      final r = grid(3, 3, 0, 255);
      sharpen(r);
      expect(r.data[4 * 3], 0);
    });
    test('SH-8 tâm 255 nền 0 ⇒ tâm kẹp 255 (D8 Đ)', () {
      final r = grid(3, 3, 255, 0);
      sharpen(r);
      expect(r.data[4 * 3], 255);
    });
  });

  group('U8 magicColor', () {
    test('MC-1 dải xám 0..255 ⇒ 0 → 0, 255 → 255, đơn điệu (D1 S)', () {
      final r = RawImage(256, 1, 3, Uint8List.fromList([for (var v = 0; v < 256; v++) ...[v, v, v]]));
      magicColor(r);
      final g = [for (var i = 0; i < 256; i++) r.data[i * 3]];
      expect(g.first, 0);
      expect(g.last, 255);
      for (var i = 1; i < 256; i++) {
        expect(g[i], greaterThanOrEqualTo(g[i - 1]));
      }
    });
    test('MC-2 phẳng 128 ⇒ không ném, mọi pixel bằng nhau (D1 Đ, D2 S)', () {
      final r = solid(4, 4, [128, 128, 128]);
      magicColor(r);
      expect(r.data.toSet().length, 1);
    });
    test('MC-3 phẳng 20 ⇒ không ném, mọi pixel bằng nhau (D2 Đ)', () {
      final r = solid(4, 4, [20, 20, 20]);
      magicColor(r);
      expect(r.data.toSet().length, 1);
    });
  });
}
