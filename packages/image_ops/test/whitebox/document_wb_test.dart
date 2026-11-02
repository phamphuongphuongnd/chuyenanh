// Kiểm thử hộp trắng (A16, Bước 6) cho lib/src/document.dart.
// Expected chép từ test-output/whitebox/image-ops/document/buoc-5-du-lieu-thu.md.
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart';
import 'package:test/test.dart';

import '../helpers.dart';

final garbage = Uint8List.fromList(List.generate(64, (i) => (i * 37) % 251));
final ink = img.ColorRgb8(30, 30, 30);

Object? run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

img.Image canvas(int w, int h, [int v = 245]) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(v, v, v));
  return im;
}

const full = [NormPoint(0, 0), NormPoint(1, 0), NormPoint(1, 1), NormPoint(0, 1)];

void expectRect(List<NormPoint>? c, int x0, int y0, int x1, int y1, int w, int h,
    {double tol = 0.02}) {
  expect(c, isNotNull);
  final want = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]; // TL, TR, BR, BL
  for (var i = 0; i < 4; i++) {
    expect(c![i].x, closeTo(want[i].$1 / w, tol), reason: 'góc $i x');
    expect(c[i].y, closeTo(want[i].$2 / h, tol), reason: 'góc $i y');
  }
}

void main() {
  final src = png(quadrantImage(200, 100));

  group('U1 perspectiveWarp (+ U2 _squareToQuad, U3 _warp)', () {
    test('PW-1 4 góc khung, outLongSide 120 ⇒ 120x60, góc trên-trái đỏ (D7 S, D8 Đ, D9 S)', () {
      final o = decode(perspectiveWarp(src, full, outLongSide: 120));
      expect([o.width, o.height], [120, 60]);
      expect(isRedAt(o, 10, 10), isTrue);
      expect(isWhiteAt(o, 100, 50), isTrue);
    });
    test('PW-2 3 góc ⇒ ArgumentError (D1 Đ)', () {
      expect(run(() => perspectiveWarp(src, full.sublist(0, 3))), isA<ArgumentError>());
    });
    test('PW-3 rác ⇒ FormatException (D2 Đ)', () {
      expect(run(() => perspectiveWarp(garbage, full)), isA<FormatException>());
    });
    test('PW-4 4 góc cùng x ⇒ ArgumentError (D3 Đ)', () {
      const q = [NormPoint(0.5, 0), NormPoint(0.5, 0), NormPoint(0.5, 1), NormPoint(0.5, 1)];
      expect(run(() => perspectiveWarp(src, q)), isA<ArgumentError>());
    });
    test('PW-5 4 góc cùng y ⇒ ArgumentError (D4 Đ)', () {
      const q = [NormPoint(0, 0.5), NormPoint(1, 0.5), NormPoint(1, 0.5), NormPoint(0, 0.5)];
      expect(run(() => perspectiveWarp(src, q)), isA<ArgumentError>());
    });
    test('PW-6 không outLongSide, 4 góc khung, PNG ⇒ 200x100 trùng ảnh gốc (D5 S; U3 D1..D6 Đ/S)', () {
      final o = decode(perspectiveWarp(src, full, format: OutputFormat.png));
      final s = decode(src);
      expect([o.width, o.height], [200, 100]);
      for (final (x, y) in [(0, 0), (99, 49), (100, 50), (199, 99), (150, 20), (20, 80)]) {
        expect(o.getPixel(x, y).r, s.getPixel(x, y).r, reason: '($x,$y)');
        expect(o.getPixel(x, y).g, s.getPixel(x, y).g, reason: '($x,$y)');
      }
    });
    test('PW-7 outLongSide 0 ⇒ cỡ tự nhiên 200x100 (D6 S)', () {
      final o = decode(perspectiveWarp(src, full, outLongSide: 0));
      expect([o.width, o.height], [200, 100]);
    });
    test('PW-8 outLongSide 40 (thu < 0,5) ⇒ 40x20, góc trên-trái đỏ (D7 Đ)', () {
      final o = decode(perspectiveWarp(src, full, outLongSide: 40, format: OutputFormat.png));
      expect([o.width, o.height], [40, 20]);
      expect(isRedAt(o, 5, 5), isTrue);
    });
    test('PW-9 tứ giác dọc 50x100, outLongSide 60 ⇒ 30x60 (D8 S)', () {
      const q = [NormPoint(0, 0), NormPoint(0.25, 0), NormPoint(0.25, 1), NormPoint(0, 1)];
      final o = decode(perspectiveWarp(src, q, outLongSide: 60));
      expect([o.width, o.height], [30, 60]);
    });
    test('PW-10 TR, BR, BL thẳng hàng (det = 0) ⇒ ArgumentError (D9 Đ, U2 D1 Đ)', () {
      final sq = png(quadrantImage(100, 100));
      const q = [NormPoint(0, 0), NormPoint(1, 0), NormPoint(0.5, 0.5), NormPoint(0, 1)];
      expect(run(() => perspectiveWarp(sq, q)), isA<ArgumentError>());
    });
    test('WP-1 tứ giác bên trong (0,25..0,75) ⇒ 100x50, không kẹp biên, đúng vùng (U3 D1..D4 S)', () {
      const q = [NormPoint(0.25, 0.25), NormPoint(0.75, 0.25), NormPoint(0.75, 0.75), NormPoint(0.25, 0.75)];
      final o = decode(perspectiveWarp(src, q, format: OutputFormat.png));
      expect([o.width, o.height], [100, 50]);
      expect(isRedAt(o, 10, 10), isTrue);
      expect(isWhiteAt(o, 90, 40), isTrue);
    });
  });

  group('U4 detectDocumentCorners', () {
    test('DC-1 tờ giấy xám nghiêng trên nền trắng 400x300 ⇒ đúng 4 góc TL, TR, BR, BL', () {
      final s = paperScene(w: 400, h: 300);
      final c = detectDocumentCorners(png(s.image));
      expect(c, hasLength(4));
      for (var i = 0; i < 4; i++) {
        expect(c![i].x, closeTo(s.corners[i].x / 400, 0.03));
        expect(c[i].y, closeTo(s.corners[i].y / 300, 0.03));
      }
    });
    test('DC-1b tờ giấy trắng có chữ trên nền tối (lỗ chữ được lấp) ⇒ đúng 4 góc', () {
      final s = paperScene(w: 400, h: 300, darkBackground: true, seed: 11);
      final c = detectDocumentCorners(png(s.image));
      expect(c, hasLength(4));
      for (var i = 0; i < 4; i++) {
        expect(c![i].x, closeTo(s.corners[i].x / 400, 0.03));
        expect(c[i].y, closeTo(s.corners[i].y / 300, 0.03));
      }
    });
    test('DC-2 rác ⇒ FormatException (D1 Đ)', () {
      expect(run(() => detectDocumentCorners(garbage)), isA<FormatException>());
    });
    test('DC-3 ảnh rộng 10 ⇒ null (D2 Đ)', () => expect(detectDocumentCorners(png(canvas(10, 40))), isNull));
    test('DC-4 ảnh cao 10 ⇒ null (D3 Đ)', () => expect(detectDocumentCorners(png(canvas(100, 10))), isNull));
    test('DC-5 ảnh trắng trơn ⇒ null (D5 Đ)', () => expect(detectDocumentCorners(png(canvas(100, 100, 255))), isNull));
    test('DC-6 ảnh đen trơn ⇒ null (D6 Đ)', () => expect(detectDocumentCorners(png(canvas(100, 100, 0))), isNull));
    test('DC-7 hai nửa xám 100 / 120 (chênh < 30) ⇒ null (D7 Đ)', () {
      final im = canvas(100, 100, 100);
      img.fillRect(im, x1: 50, y1: 0, x2: 99, y2: 99, color: img.ColorRgb8(120, 120, 120));
      expect(detectDocumentCorners(png(im)), isNull);
    });
    test('DC-10 hình tròn đen ⇒ null (D9 S; U10 D12 Đ)', () {
      final im = canvas(400, 300);
      img.fillCircle(im, x: 200, y: 150, radius: 100, color: ink);
      expect(detectDocumentCorners(png(im)), isNull);
    });
    test('DC-11 hai hình chữ nhật cùng đạt ⇒ chọn hình lớn hơn (D10 Đ rồi S)', () {
      final im = canvas(400, 300);
      img.fillRect(im, x1: 20, y1: 20, x2: 219, y2: 169, color: ink); // 25 %
      img.fillRect(im, x1: 250, y1: 180, x2: 379, y2: 279, color: ink); // 10,8 %
      expectRect(detectDocumentCorners(png(im)), 20, 20, 220, 170, 400, 300);
    });
  });

  group('U5 _largestComponents', () {
    test('LC-17 hình lớn + đốm nhỏ < 5 % ⇒ bỏ đốm, ra hình lớn (D17 Đ)', () {
      final im = canvas(400, 300);
      img.fillRect(im, x1: 40, y1: 40, x2: 239, y2: 189, color: ink);
      img.fillRect(im, x1: 330, y1: 230, x2: 344, y2: 244, color: ink);
      expectRect(detectDocumentCorners(png(im)), 40, 40, 240, 190, 400, 300);
    });
  });

  group('U10 _quadFromRegion', () {
    test('QF-6 hình chữ L (không đủ lồi) ⇒ null (D6 Đ)', () {
      final im = canvas(400, 300);
      img.fillRect(im, x1: 40, y1: 40, x2: 339, y2: 99, color: ink);
      img.fillRect(im, x1: 40, y1: 40, x2: 99, y2: 259, color: ink);
      expect(detectDocumentCorners(png(im)), isNull);
    });
    test('QF-13 hình chữ nhật 7 % khung ⇒ null (D13 Đ)', () {
      final im = canvas(400, 300);
      img.fillRect(im, x1: 100, y1: 100, x2: 219, y2: 169, color: ink);
      expect(detectDocumentCorners(png(im)), isNull);
    });
    test('QF-15 dải mảnh 380x45 (cạnh ngắn < 15 % cạnh dài) ⇒ null (D15 Đ)', () {
      final im = canvas(400, 400);
      img.fillRect(im, x1: 10, y1: 170, x2: 389, y2: 214, color: ink);
      expect(detectDocumentCorners(png(im)), isNull);
    });
  });
}
