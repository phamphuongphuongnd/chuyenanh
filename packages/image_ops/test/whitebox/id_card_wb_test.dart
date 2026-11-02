// Kiểm thử hộp trắng (A16, Bước 6) cho lib/src/id_card.dart.
// Expected chép từ test-output/whitebox/image-ops/id_card/buoc-5-du-lieu-thu.md.
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart';
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

img.Image solid(int w, int h, img.Color c) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: c);
  return im;
}

/// Hộp bao các pixel không trắng trong hàng [y0, y1).
({int left, int top, int right, int bottom})? inkBox(img.Image im, int y0, int y1) {
  int? l, t, r, b;
  for (var y = y0; y < y1; y++) {
    for (var x = 0; x < im.width; x++) {
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

void main() {
  const small = IdCardLayout(pageWidthPx: 620, pageHeightPx: 877);
  final f = idCardFrames(small).front;
  final redJpg = jpg(solid(856, 540, red));
  final bluePng = png(solid(856, 540, blue));

  group('U1 idCardFrames', () {
    test('IF-1 trang 620x877, scale 1 ⇒ khung đúng cỡ thẻ 85,6x54 mm, mặt trước nửa trên, mặt sau nửa dưới', () {
      final fr = idCardFrames(small);
      const ppm = 620 / 210;
      expect(fr.front.width, closeTo(85.6 * ppm, 1));
      expect(fr.front.height, closeTo(54 * ppm, 1));
      expect(fr.front.top + fr.front.height, lessThanOrEqualTo(877 ~/ 2));
      expect(fr.back.top, greaterThanOrEqualTo(877 ~/ 2));
      expect(fr.front.left, fr.back.left);
      expect(fr.front.left * 2 + fr.front.width, closeTo(620, 1), reason: 'căn giữa ngang');
    });
    test('IF-2 pageWidthPx 0 ⇒ ArgumentError (D1 Đ)', () {
      expect(run(() => idCardFrames(const IdCardLayout(pageWidthPx: 0))), isA<ArgumentError>());
    });
    test('IF-3 pageHeightPx −1 ⇒ ArgumentError (D2 Đ)', () {
      expect(run(() => idCardFrames(const IdCardLayout(pageHeightPx: -1))), isA<ArgumentError>());
    });
    test('IF-4 scale 0 và −2 ⇒ như scale 1 (D3 Đ)', () {
      for (final s in [0.0, -2.0]) {
        final fr = idCardFrames(IdCardLayout(pageWidthPx: 620, pageHeightPx: 877, scale: s)).front;
        expect([fr.left, fr.top, fr.width, fr.height], [f.left, f.top, f.width, f.height],
            reason: 'scale $s');
      }
    });
    test('IF-5 trang rất cao, scale 10 ⇒ khung bị chặn theo chiều ngang trong lề, giữ tỉ lệ (D4 Đ, D5 S)', () {
      final fr = idCardFrames(const IdCardLayout(pageWidthPx: 620, pageHeightPx: 5000, scale: 10)).front;
      const margin = 10 * 620 / 210;
      expect(fr.width, closeTo(620 - 2 * margin, 1));
      expect(fr.left, greaterThanOrEqualTo(margin.floor()));
      expect(fr.width / fr.height, closeTo(85.6 / 54, 0.01));
    });
    test('IF-6 trang thấp 2480x700 ⇒ khung bị chặn theo chiều cao nửa trang trừ lề, giữ tỉ lệ (D4 S, D5 Đ)', () {
      final fr = idCardFrames(const IdCardLayout(pageHeightPx: 700)).front;
      const margin = 10 * 2480 / 210;
      expect(fr.height, closeTo(350 - 2 * margin, 1));
      expect(fr.width / fr.height, closeTo(85.6 / 54, 0.02));
      expect(fr.top, greaterThanOrEqualTo(margin - 1));
      expect(fr.top + fr.height, lessThanOrEqualTo(350 - margin + 1));
    });
  });

  group('U2 composeIdCard', () {
    test('CI-1 mặt trước JPEG đỏ, mặt sau PNG xanh, không watermark ⇒ JPEG 620x877, đỏ nửa trên, xanh nửa dưới (D2 Đ, D4 S, D5 S)', () {
      final out = composeIdCard(redJpg, bluePng, layout: small);
      expect(isJpeg(out), isTrue);
      final im = decode(out);
      expect([im.width, im.height], [620, 877]);
      expect(isRedAt(im, f.left + f.width ~/ 2, f.top + f.height ~/ 2), isTrue);
      final b = idCardFrames(small).back;
      final p = im.getPixel(b.left + b.width ~/ 2, b.top + b.height ~/ 2);
      expect(p.b > 150 && p.r < 100, isTrue);
      expect(isWhiteAt(im, 3, 3), isTrue);
    });
    test('CI-2 pageWidthPx 0 ⇒ ArgumentError (D1 Đ)', () {
      expect(run(() => composeIdCard(redJpg, bluePng, layout: const IdCardLayout(pageWidthPx: 0))),
          isA<ArgumentError>());
    });
    test('CI-3 watermark PNG đen alpha 128 ⇒ chỉ thẻ bị tối đi, lề vẫn trắng (D2 S, D3 S, D5 Đ)', () {
      final wm = img.Image(width: 100, height: 60, numChannels: 4);
      img.fill(wm, color: img.ColorRgba8(0, 0, 0, 128));
      final plain = decode(composeIdCard(redJpg, bluePng, layout: small));
      final out = decode(composeIdCard(redJpg, bluePng,
          layout: IdCardLayout(pageWidthPx: 620, pageHeightPx: 877, watermarkPng: png(wm))));
      final cx = f.left + f.width ~/ 2, cy = f.top + f.height ~/ 2;
      expect(out.getPixel(cx, cy).r, lessThan(plain.getPixel(cx, cy).r - 50));
      expect(isWhiteAt(out, 3, 3), isTrue);
      expect(isWhiteAt(out, 310, 877 ~/ 2), isTrue);
    });
    test('CI-4 watermark rác ⇒ FormatException (D3 Đ)', () {
      expect(
          run(() => composeIdCard(redJpg, bluePng,
              layout: IdCardLayout(pageWidthPx: 620, pageHeightPx: 877, watermarkPng: garbage))),
          isA<FormatException>());
    });
    test('CI-5 mặt trước rác / mặt sau rác ⇒ FormatException (D4 Đ ở lượt 1 và lượt 2)', () {
      expect(run(() => composeIdCard(garbage, bluePng, layout: small)), isA<FormatException>());
      expect(run(() => composeIdCard(redJpg, garbage, layout: small)), isA<FormatException>());
    });
  });

  group('U3 _loadSide', () {
    test('LS-3 PNG trong suốt hoàn toàn ⇒ vùng thẻ trắng (D2 Đ)', () {
      final t = img.Image(width: 200, height: 120, numChannels: 4); // đen, alpha 0
      final im = decode(composeIdCard(png(t), bluePng, layout: small));
      expect(inkBox(im, 0, 877 ~/ 2), isNull);
    });
    test('LS-4 cover: ảnh vuông 400x400 ⇒ phủ kín khung (D3 S)', () {
      final im = decode(composeIdCard(jpg(solid(400, 400, red)), bluePng,
          layout: const IdCardLayout(pageWidthPx: 620, pageHeightPx: 877, fit: IdCardFit.cover)));
      final box = inkBox(im, 0, 877 ~/ 2)!;
      expect(box.right - box.left + 1, closeTo(f.width, 3));
      expect(box.bottom - box.top + 1, closeTo(f.height, 3));
    });
  });

  group('U4 _resize', () {
    test('RZ-2 ảnh đúng bằng khung ⇒ đặt nguyên, hộp mực = khung (D1 Đ, D2 Đ)', () {
      final im = decode(composeIdCard(png(solid(f.width, f.height, red)), bluePng, layout: small));
      final box = inkBox(im, 0, 877 ~/ 2)!;
      expect([box.left, box.top], [closeTo(f.left, 1), closeTo(f.top, 1)]);
      expect(box.right - box.left + 1, closeTo(f.width, 1));
      expect(box.bottom - box.top + 1, closeTo(f.height, 1));
    });
    test('RZ-3 ảnh 40 x (cao khung + 1) ⇒ rộng giữ 40, cao = khung (D1 Đ, D2 S, D3 Đ, D4 Đ)', () {
      final h = f.height + 1;
      expect((40 * f.height / h).round(), 40, reason: 'tiền điều kiện: w == src.width');
      final im = decode(composeIdCard(png(solid(40, h, red)), bluePng, layout: small));
      final box = inkBox(im, 0, 877 ~/ 2)!;
      expect(box.right - box.left + 1, closeTo(40, 2));
      expect(box.bottom - box.top + 1, closeTo(f.height, 2));
    });
    test('RZ-4 ảnh nhỏ 60x38 ⇒ phóng to vừa khung (D1 S, D3 S)', () {
      final im = decode(composeIdCard(png(solid(60, 38, red)), bluePng, layout: small));
      final box = inkBox(im, 0, 877 ~/ 2)!;
      expect(box.bottom - box.top + 1, closeTo(f.height, 3));
    });
    test('RZ-5 ảnh 2 x (cao khung − 19) ⇒ rộng vẫn 2, cao phóng = khung (D3 Đ, D4 S)', () {
      final h = f.height - 19;
      final s = f.height / h;
      expect((2 * s).round(), 2, reason: 'tiền điều kiện: w <= src.width, h > src.height');
      final im = decode(composeIdCard(png(solid(2, h, red)), bluePng, layout: small));
      final box = inkBox(im, 0, 877 ~/ 2)!;
      expect(box.right - box.left + 1, lessThanOrEqualTo(6));
      expect(box.bottom - box.top + 1, closeTo(f.height, 3));
    });
  });

  group('U6 _decodeOverlay', () {
    test('DO-3 watermark JPEG (không alpha) ⇒ coi như đục: tâm thẻ ra màu watermark (D2 S)', () {
      final green = img.ColorRgb8(20, 200, 20);
      final im = decode(composeIdCard(redJpg, bluePng,
          layout: IdCardLayout(
              pageWidthPx: 620, pageHeightPx: 877, watermarkPng: jpg(solid(100, 60, green)))));
      final p = im.getPixel(f.left + f.width ~/ 2, f.top + f.height ~/ 2);
      expect(p.g > 150 && p.r < 100, isTrue);
      expect(isWhiteAt(im, 3, 3), isTrue);
    });
  });

  group('U7 _blendOverlay', () {
    // Watermark đúng cỡ khung: nửa trái trong suốt, nửa phải đen đục.
    Uint8List halfMark() {
      final wm = img.Image(width: f.width, height: f.height, numChannels: 4);
      img.fillRect(wm, x1: f.width ~/ 2, y1: 0, x2: f.width - 1, y2: f.height - 1,
          color: img.ColorRgba8(0, 0, 0, 255));
      return png(wm);
    }

    img.Image compose(double opacity) => decode(composeIdCard(redJpg, bluePng,
        layout: IdCardLayout(
            pageWidthPx: 620, pageHeightPx: 877, watermarkPng: halfMark(), watermarkOpacity: opacity)));
    final yc = f.top + f.height ~/ 2;
    final xl = f.left + f.width ~/ 4, xr = f.left + f.width * 3 ~/ 4;

    test('BO-1 opacity 0.5 ⇒ nửa trong suốt giữ đỏ, nửa đục tối ~50 % (D1 S, D2 S, D3 Đ/S)', () {
      final im = compose(0.5);
      expect(isRedAt(im, xl, yc), isTrue);
      expect(im.getPixel(xr, yc).r, inInclusiveRange(90, 140));
    });
    test('BO-2 opacity NaN ⇒ coi như 1: nửa đục ra đen (D1 Đ)', () {
      expect(compose(double.nan).getPixel(xr, yc).r, lessThan(40));
    });
    test('BO-3 opacity 0 ⇒ như không có watermark (D2 Đ)', () {
      final plain = decode(composeIdCard(redJpg, bluePng, layout: small));
      final im = compose(0);
      expect(im.getPixel(xr, yc).r, closeTo(plain.getPixel(xr, yc).r, 3));
      expect(isRedAt(im, xr, yc), isTrue);
    });
  });
}
