// Kiểm thử hộp trắng (A16, Bước 6) cho lib/src/raw.dart.
// Expected chép từ test-output/whitebox/image-ops/raw/buoc-5-du-lieu-thu.md.
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart';
import 'package:image_ops/src/raw.dart';
import 'package:test/test.dart';

import '../helpers.dart';

final garbage = Uint8List.fromList(List.generate(64, (i) => (i * 37) % 251));

Object? run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

/// w x h RGB (hoặc RGBA) với R = 10 * (y * w + x) + 10 để nhận ra từng pixel.
RawImage tagged(int w, int h, {int ch = 3}) {
  final d = Uint8List(w * h * ch);
  for (var i = 0; i < w * h; i++) {
    d[i * ch] = 10 * i + 10;
    d[i * ch + 1] = 1;
    d[i * ch + 2] = 2;
    if (ch == 4) d[i * ch + 3] = 100 + i;
  }
  return RawImage(w, h, ch, d);
}

int rAt(RawImage r, int x, int y) => r.data[(y * r.width + x) * r.channels];
int aAt(RawImage r, int x, int y) => r.data[(y * r.width + x) * r.channels + 3];

/// Kiểm toàn bộ pixel: out(x, y) phải là src(map(x, y)).
void expectMapping(RawImage out, RawImage src, int ow, int oh,
    (int, int) Function(int x, int y) map) {
  expect([out.width, out.height], [ow, oh], reason: 'kích thước');
  for (var y = 0; y < oh; y++) {
    for (var x = 0; x < ow; x++) {
      final (sx, sy) = map(x, y);
      expect(rAt(out, x, y), rAt(src, sx, sy), reason: 'pixel ($x,$y) ← ($sx,$sy)');
    }
  }
}

int findSos(Uint8List b) {
  for (var i = 2; i + 1 < b.length; i++) {
    if (b[i] == 0xFF && b[i + 1] == 0xDA) return i;
  }
  return -1;
}

void main() {
  group('U1 RawImage.hasRealAlpha', () {
    test('HA-1 RGBA, pixel đầu alpha 0 ⇒ true (D3 Đ lượt đầu)', () {
      final r = RawImage(2, 1, 4, Uint8List.fromList([1, 2, 3, 0, 1, 2, 3, 255]));
      expect(r.hasRealAlpha, isTrue);
    });
    test('HA-2 RGB ⇒ false (D1 Đ)', () => expect(tagged(2, 2).hasRealAlpha, isFalse));
    test('HA-3 RGBA, pixel đầu đục, pixel 2 alpha 10 ⇒ true (D3 S rồi Đ)', () {
      final r = RawImage(2, 1, 4, Uint8List.fromList([1, 2, 3, 255, 1, 2, 3, 10]));
      expect(r.hasRealAlpha, isTrue);
    });
    test('HA-4 RGBA 1 pixel đục ⇒ false (D3 S, D2 S)', () {
      expect(RawImage(1, 1, 4, Uint8List.fromList([1, 2, 3, 255])).hasRealAlpha, isFalse);
    });
  });

  group('U2 _mapFormat (qua decodeRaw.format)', () {
    final base = quadrantImage(8, 6);
    final cases = <String, (Uint8List, ImageSourceFormat)>{
      'MF-1 jpg': (jpg(base), ImageSourceFormat.jpeg),
      'MF-2 png': (png(base), ImageSourceFormat.png),
      'MF-3 webp': (img.encodeWebP(base), ImageSourceFormat.webp),
      'MF-4 bmp': (img.encodeBmp(base), ImageSourceFormat.bmp),
      'MF-5 gif': (img.encodeGif(base), ImageSourceFormat.gif),
      'MF-6 tga ⇒ other': (img.encodeTga(base), ImageSourceFormat.other),
    };
    for (final c in cases.entries) {
      test(c.key, () => expect(decodeRaw(c.value.$1).format, c.value.$2));
    }
  });

  group('U3 _decoderFor', () {
    test('DF-1 rác ⇒ FormatException (D1 Đ)', () {
      expect(img.findDecoderForData(garbage), isNull);
      expect(run(() => decodeRaw(garbage)), isA<FormatException>());
    });
    test('DF-2 PNG hợp lệ ⇒ giải mã được (D1 S)',
        () => expect(decodeRaw(png(quadrantImage(4, 4))).image.width, 4));
  });

  group('U4 decodeRaw', () {
    final j = jpg(quadrantImage(64, 48));
    test('DR-1 JPEG 64x48, target 8 ⇒ giải mã 1/8: 8x6 (D7 Đ ở s = 8)', () {
      final d = decodeRaw(j, targetLongSide: 8);
      expect([d.image.width, d.image.height], [8, 6]);
      expect(d.format, ImageSourceFormat.jpeg);
    });
    test('DR-2 rác ⇒ FormatException (D1 Đ)',
        () => expect(run(() => decodeRaw(garbage, targetLongSide: 8)), isA<FormatException>()));
    test('DR-3 PNG ⇒ đủ cỡ, format png (D2 S)', () {
      final d = decodeRaw(png(quadrantImage(30, 20)), targetLongSide: 4);
      expect([d.image.width, d.image.height, d.format], [30, 20, ImageSourceFormat.png]);
    });
    test('DR-4 JPEG không target ⇒ 64x48 (D3 S)', () {
      final d = decodeRaw(j);
      expect([d.image.width, d.image.height], [64, 48]);
    });
    test('DR-5 JPEG target 0 ⇒ 64x48 (D4 S, chỉ mức unit)', () {
      final d = decodeRaw(j, targetLongSide: 0);
      expect([d.image.width, d.image.height], [64, 48]);
    });
    test('DR-7 JPEG target 10 ⇒ 1/4: 16x12 (D7 S ở s = 8, Đ ở s = 4)', () {
      final d = decodeRaw(j, targetLongSide: 10);
      expect([d.image.width, d.image.height], [16, 12]);
    });
    test('DR-8 JPEG target 64 ⇒ không thu nhỏ 64x48 (D6 S, hết vòng)', () {
      final d = decodeRaw(j, targetLongSide: 64);
      expect([d.image.width, d.image.height], [64, 48]);
    });
    test('DR-10 JPEG cắt sau SOS 4 byte ⇒ FormatException (D9 Đ: ImageException bị đổi)', () {
      final t = Uint8List.fromList(j.sublist(0, findSos(j) + 4));
      expect(img.findDecoderForData(t)?.format, img.ImageFormat.jpg, reason: 'D1 S, D2 Đ');
      expect(run(() => img.JpegDecoder().decode(t)), isA<img.ImageException>(),
          reason: 'decode ném lỗi không phải FormatException');
      expect(run(() => decodeRaw(t)), isA<FormatException>());
    });
    test('DR-11 PNG cụt 40 byte ⇒ decode null ⇒ FormatException (D10 S, D13 Đ)', () {
      final t = Uint8List.fromList(png(quadrantImage(30, 20)).sublist(0, 40));
      expect(img.findDecoderForData(t)?.decode(t), isNull, reason: 'im == null');
      expect(run(() => decodeRaw(t)), isA<FormatException>());
    });
    test('DR-12 WebP EXIF 6 ⇒ báo orientation 6, chưa xoay 30x20 (D11 Đ, D12 S)', () {
      final im = quadrantImage(30, 20)..exif.imageIfd.orientation = 6;
      final d = decodeRaw(img.encodeWebP(im));
      expect([d.orientation, d.image.width, d.image.height], [6, 30, 20]);
    });
  });

  group('U5 toRaw', () {
    test('TR-1 RGB uint8 3 kênh ⇒ 3 kênh, giữ dữ liệu (D1 S, D2 S, D3 S, D4 S, D5 Đ)', () {
      final im = img.Image(width: 3, height: 2);
      im.setPixelRgb(2, 1, 9, 8, 7);
      final r = toRaw(im);
      expect([r.channels, r.data.length], [3, 18]);
      expect(r.data.sublist(15), [9, 8, 7]);
    });
    test('TR-2 RGBA ⇒ 4 kênh (D1 Đ)', () {
      final im = img.Image(width: 2, height: 2, numChannels: 4);
      im.setPixelRgba(0, 0, 1, 2, 3, 4);
      final r = toRaw(im);
      expect(r.channels, 4);
      expect(r.data.sublist(0, 4), [1, 2, 3, 4]);
    });
    test('TR-3 uint16 ⇒ đổi về uint8, 3 kênh (D2 Đ)', () {
      final im = img.Image(width: 2, height: 1, format: img.Format.uint16);
      im.setPixelRgb(0, 0, 65535, 0, 32896);
      final r = toRaw(im);
      expect(r.channels, 3);
      expect(r.data[0], 255);
      expect(r.data[1], 0);
      expect(r.data[2], closeTo(128, 1));
    });
    test('TR-4 1 kênh xám ⇒ 3 kênh R = G = B (D3 Đ)', () {
      final im = img.Image(width: 2, height: 1, numChannels: 1);
      im.setPixelR(1, 0, 77);
      final r = toRaw(im);
      expect(r.channels, 3);
      expect(r.data.sublist(3), [77, 77, 77]);
    });
    test('TR-5 GIF có bảng màu ⇒ 3 kênh màu thật (D4 Đ)', () {
      final g = img.decodeGif(img.encodeGif(quadrantImage(8, 6)))!;
      expect(g.hasPalette, isTrue, reason: 'D4 Đ');
      final r = toRaw(g);
      expect(r.channels, 3);
      expect(r.data[0], greaterThan(150), reason: 'góc đỏ');
      expect(r.data[1], lessThan(100));
    });
  });

  group('U6 encodeRaw', () {
    RawImage rgba({int a0 = 255}) =>
        RawImage(2, 1, 4, Uint8List.fromList([0, 0, 0, a0, 200, 10, 10, 255]));
    test('EN-1 png + RGB ⇒ PNG 3 kênh (D1 Đ, D4 S)', () {
      final b = encodeRaw(tagged(2, 2), OutputFormat.png, 90);
      expect(isPng(b), isTrue);
      expect(decode(b).numChannels, 3);
    });
    test('EN-2 jpeg + RGB ⇒ JPEG (D2 S, D6 S)',
        () => expect(isJpeg(encodeRaw(tagged(2, 2), OutputFormat.jpeg, 90)), isTrue));
    test('EN-3 auto + RGB ⇒ JPEG (D2 Đ, D3 S)',
        () => expect(isJpeg(encodeRaw(tagged(2, 2), OutputFormat.auto, 90)), isTrue));
    test('EN-4 auto + RGBA có alpha thật ⇒ PNG giữ alpha (D3 Đ, D4 Đ, D5 S)', () {
      final b = encodeRaw(rgba(a0: 0), OutputFormat.auto, 90);
      expect(isPng(b), isTrue);
      expect(decode(b).getPixel(0, 0).a, 0);
    });
    test('EN-5 png + RGBA đục ⇒ PNG bỏ kênh alpha, 3 kênh (D5 Đ)', () {
      final b = encodeRaw(rgba(), OutputFormat.png, 90);
      expect(isPng(b), isTrue);
      expect(decode(b).numChannels, 3);
    });
    test('EN-6 png + RGBA alpha thật ⇒ PNG 4 kênh (D4 Đ, D5 S)', () {
      final b = encodeRaw(rgba(a0: 0), OutputFormat.png, 90);
      expect(decode(b).numChannels, 4);
    });
    test('EN-7 jpeg + RGBA: pixel trong suốt thành trắng (D6 Đ)', () {
      final b = encodeRaw(
          RawImage(8, 8, 4, Uint8List(8 * 8 * 4)), OutputFormat.jpeg, 95); // đen, alpha 0
      expect(isJpeg(b), isTrue);
      expect(isWhiteAt(decode(b), 4, 4), isTrue);
    });
  });

  group('U7 rotateCw', () {
    final src = tagged(3, 2);
    test('RC-1 1 lượt, RGB ⇒ 2x3, quay 90° CW', () {
      expectMapping(rotateCw(src, 1), src, 2, 3, (x, y) => (y, 1 - x));
    });
    test('RC-2 0 lượt ⇒ trả nguyên ảnh (D1 Đ)', () => expect(identical(rotateCw(src, 0), src), isTrue));
    test('RC-3 −1 lượt (≡ 3) ⇒ 2x3, quay 90° CCW (D4 S, D5 S)', () {
      expectMapping(rotateCw(src, -1), src, 2, 3, (x, y) => (2 - y, x));
    });
    test('RC-4 2 lượt ⇒ 3x2, quay 180° (D2 Đ, D3 Đ, D5 Đ)', () {
      expectMapping(rotateCw(src, 2), src, 3, 2, (x, y) => (2 - x, 1 - y));
    });
    test('RC-7 1 lượt, RGBA ⇒ alpha đi theo pixel (D6 Đ)', () {
      final s4 = tagged(3, 2, ch: 4);
      final o = rotateCw(s4, 1);
      expectMapping(o, s4, 2, 3, (x, y) => (y, 1 - x));
      expect(aAt(o, 0, 0), aAt(s4, 0, 1));
    });
  });

  group('U8 applyOrientation (EXIF 1..8)', () {
    final src = tagged(3, 2);
    // Định nghĩa EXIF: cách đưa pixel lưu trữ về đúng chiều.
    final spec = <int, (int, int, (int, int) Function(int, int))>{
      2: (3, 2, (x, y) => (2 - x, y)), // lật ngang
      3: (3, 2, (x, y) => (2 - x, 1 - y)), // 180°
      4: (3, 2, (x, y) => (x, 1 - y)), // lật dọc
      5: (2, 3, (x, y) => (y, x)), // transpose
      6: (2, 3, (x, y) => (y, 1 - x)), // 90° CW
      7: (2, 3, (x, y) => (2 - y, 1 - x)), // transverse
      8: (2, 3, (x, y) => (2 - y, x)), // 270° CW
    };
    for (final e in spec.entries) {
      test('AO-${e.key} orientation ${e.key}', () {
        final (w, h, map) = e.value;
        expectMapping(applyOrientation(src, e.key), src, w, h, map);
      });
    }
    test('AO-1 orientation 1 (nhánh còn lại) ⇒ giữ nguyên',
        () => expectMapping(applyOrientation(src, 1), src, 3, 2, (x, y) => (x, y)));
  });

  group('U9 orientationSwaps', () {
    test('OS-1 6 ⇒ true (D1 Đ, D2 Đ)', () => expect(orientationSwaps(6), isTrue));
    test('OS-2 2 ⇒ false (D1 S)', () => expect(orientationSwaps(2), isFalse));
    test('OS-3 9 ⇒ false (D2 S)', () => expect(orientationSwaps(9), isFalse));
    test('OS-1b biên 5 và 8 ⇒ true, 4 ⇒ false (bổ sung)', () {
      expect([orientationSwaps(5), orientationSwaps(8), orientationSwaps(4)], [true, true, false]);
    });
  });

  group('U10 cropPx', () {
    final src = tagged(4, 3);
    test('CP-1 toàn ảnh ⇒ trả nguyên ảnh (D1..D4 Đ)',
        () => expect(identical(cropPx(src, 0, 0, 4, 3), src), isTrue));
    test('CP-2 x0 = 1 ⇒ 3x3 bắt đầu từ cột 1 (D1 S)',
        () => expectMapping(cropPx(src, 1, 0, 4, 3), src, 3, 3, (x, y) => (x + 1, y)));
    test('CP-3 y0 = 1 ⇒ 4x2 (D2 S)',
        () => expectMapping(cropPx(src, 0, 1, 4, 3), src, 4, 2, (x, y) => (x, y + 1)));
    test('CP-4 x1 = 3 ⇒ 3x3 (D3 S)',
        () => expectMapping(cropPx(src, 0, 0, 3, 3), src, 3, 3, (x, y) => (x, y)));
    test('CP-5 y1 = 2 ⇒ 4x2 (D4 S)',
        () => expectMapping(cropPx(src, 0, 0, 4, 2), src, 4, 2, (x, y) => (x, y)));
  });

  group('U11 cropNorm.c', () {
    final src = tagged(4, 2);
    test('CN-1 left NaN ⇒ không ném, ít nhất 1 px (D1 Đ)', () {
      final r = run(() => cropNorm(
          src, const NormRect(left: double.nan, top: 0, width: 0.5, height: 1)));
      expect(r, isA<RawImage>());
      final o = r as RawImage;
      expect(o.width, inInclusiveRange(1, 4));
      expect(o.height, 2);
    });
    test('CN-2 (0.25, 0, 0.5, 1) trên 4x2 ⇒ 2x2 từ cột 1 (D1 S)', () {
      expectMapping(cropNorm(src, const NormRect(left: 0.25, top: 0, width: 0.5, height: 1)),
          src, 2, 2, (x, y) => (x + 1, y));
    });
  });

  group('U12 unrotateRect', () {
    const r = NormRect(left: 0.1, top: 0.2, width: 0.3, height: 0.4);
    void near(NormRect a, List<double> e) {
      expect([a.left, a.top, a.width, a.height],
          [for (final v in e) closeTo(v, 1e-9)]);
    }

    test('UR-1 1 lượt ⇒ (0.2, 0.6, 0.4, 0.3)', () => near(unrotateRect(r, 1), [0.2, 0.6, 0.4, 0.3]));
    test('UR-2 2 lượt ⇒ (0.6, 0.4, 0.3, 0.4)', () => near(unrotateRect(r, 2), [0.6, 0.4, 0.3, 0.4]));
    test('UR-3 3 lượt ⇒ (0.4, 0.1, 0.4, 0.3)', () => near(unrotateRect(r, 3), [0.4, 0.1, 0.4, 0.3]));
    test('UR-4 0 lượt ⇒ giữ nguyên', () => near(unrotateRect(r, 0), [0.1, 0.2, 0.3, 0.4]));
  });

  group('U13 downscaleToLongSide', () {
    final src = RawImage.blank(100, 50, 3);
    test('DS-1 maxLong 0 ⇒ trả nguyên (D1 Đ, chỉ mức unit)',
        () => expect(identical(downscaleToLongSide(src, 0), src), isTrue));
    test('DS-2 maxLong 100 ≥ cạnh dài ⇒ không phóng to (D2 Đ)',
        () => expect(identical(downscaleToLongSide(src, 100), src), isTrue));
    test('DS-3 maxLong 10 ⇒ 10x5 (D2 S)', () {
      final o = downscaleToLongSide(src, 10);
      expect([o.width, o.height], [10, 5]);
    });
  });

  RawImage row(List<int> r, {int ch = 3, bool column = false}) {
    final d = Uint8List(r.length * ch);
    for (var i = 0; i < r.length; i++) {
      for (var c = 0; c < ch; c++) {
        d[i * ch + c] = c == 3 ? 255 - r[i] : r[i];
      }
    }
    return column ? RawImage(1, r.length, ch, d) : RawImage(r.length, 1, ch, d);
  }

  group('U14 resizeArea', () {
    test('RA-1 cùng cỡ ⇒ trả nguyên (D1 Đ, D2 Đ, chỉ mức unit)', () {
      final s = row([0, 100]);
      expect(identical(resizeArea(s, 2, 1), s), isTrue);
    });
    test('RA-2 4x1 → 2x1 ⇒ trung bình vùng [50, 120] (D1 S)', () {
      final o = resizeArea(row([0, 100, 200, 40]), 2, 1);
      expect([o.width, o.height, o.data[0], o.data[3]], [2, 1, 50, 120]);
    });
    test('RA-3 1x4 → 1x2 (cùng rộng, khác cao) ⇒ [50, 120] (D1 Đ, D2 S)', () {
      final o = resizeArea(row([0, 100, 200, 40], column: true), 1, 2);
      expect([o.width, o.height, o.data[0], o.data[3]], [1, 2, 50, 120]);
    });
  });

  group('U15 _resample1d (qua resizeArea)', () {
    test('RS-2 phóng to 2x1 → 4x1 (cửa sổ 1 pixel) ⇒ ≈ [0, 25, 75, 100] (D1 S, chỉ mức unit)', () {
      final o = resizeArea(row([0, 100]), 4, 1);
      expect([for (var i = 0; i < 4; i++) o.data[i * 3]],
          [0, closeTo(25, 1), closeTo(75, 1), 100]);
    });
    test('RS-6 RGBA 4x1 → 2x1 ⇒ mọi kênh kể cả alpha được trung bình (D5 S)', () {
      final o = resizeArea(row([0, 100, 200, 40], ch: 4), 2, 1);
      expect(o.data, [50, 50, 50, 205, 120, 120, 120, 135]);
    });
  });
}
