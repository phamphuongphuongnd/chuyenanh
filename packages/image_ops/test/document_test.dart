import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('detectDocumentCorners', () {
    void expectCorners(List<NormPoint>? found, List<math.Point<double>> truth,
        int w, int h) {
      expect(found, isNotNull);
      expect(found, hasLength(4));
      for (var i = 0; i < 4; i++) {
        expect(found![i].x, closeTo(truth[i].x / w, 0.03), reason: 'corner $i x');
        expect(found[i].y, closeTo(truth[i].y / h, 0.03), reason: 'corner $i y');
      }
    }

    test('finds a grey tilted sheet on a white background', () {
      final s = paperScene();
      expectCorners(detectDocumentCorners(jpg(s.image, quality: 85)),
          s.corners, 1000, 750);
    });

    test('finds a white sheet on a dark background', () {
      final s = paperScene(darkBackground: true, seed: 11);
      expectCorners(detectDocumentCorners(jpg(s.image, quality: 85)),
          s.corners, 1000, 750);
    });

    test('works on a portrait image', () {
      final s = paperScene(w: 600, h: 900, seed: 5);
      expectCorners(
          detectDocumentCorners(png(s.image)), s.corners, 600, 900);
    });

    test('corners follow the EXIF-oriented frame', () {
      final s = paperScene(w: 800, h: 600);
      // Store the scene rotated 90° CCW with orientation 6 (display = rotate
      // 90° CW), so the displayed image equals the original scene.
      final stored = img.copyRotate(s.image, angle: -90);
      stored.exif.imageIfd.orientation = 6;
      expectCorners(
          detectDocumentCorners(jpg(stored, quality: 90)), s.corners, 800, 600);
    });

    for (final seed in [1, 2, 3]) {
      test('returns null for pure noise (seed $seed)', () {
        expect(detectDocumentCorners(png(noiseImage(640, 480, seed: seed))),
            isNull);
      });
    }

    test('returns null for a blank image', () {
      final blank = img.Image(width: 300, height: 200);
      img.fill(blank, color: white);
      expect(detectDocumentCorners(png(blank)), isNull);
    });
  });

  group('perspectiveWarp', () {
    // A 600x300 rectangle rotated by 15° drawn on a white background.
    ({img.Image image, List<NormPoint> corners}) rotatedRect() {
      const w = 1000, h = 800;
      final im = img.Image(width: w, height: h);
      img.fill(im, color: white);
      const a = 15 * math.pi / 180;
      final c = math.Point(500.0, 400.0);
      math.Point<double> rot(double x, double y) => math.Point(
          c.x + x * math.cos(a) - y * math.sin(a),
          c.y + x * math.sin(a) + y * math.cos(a));
      final pts = [rot(-300, -150), rot(300, -150), rot(300, 150), rot(-300, 150)];
      img.fillPolygon(im,
          vertices: [for (final p in pts) img.Point(p.x, p.y)],
          color: img.ColorRgb8(30, 90, 200));
      return (
        image: im,
        corners: [for (final p in pts) NormPoint(p.x / w, p.y / h)]
      );
    }

    test('outputs a rectangle with the right aspect ratio and content', () {
      final r = rotatedRect();
      final out = decode(perspectiveWarp(jpg(r.image), r.corners));
      expect(out.width / out.height, closeTo(2.0, 0.02));
      expect(out.width, closeTo(600, 6));
      // Content is the blue rectangle everywhere, including near the corners.
      for (final (x, y) in [
        (out.width ~/ 2, out.height ~/ 2),
        (8, 8),
        (out.width - 9, 8),
        (out.width - 9, out.height - 9),
        (8, out.height - 9),
      ]) {
        final p = out.getPixel(x, y);
        expect(p.b, greaterThan(150), reason: 'at $x,$y');
        expect(p.r, lessThan(90), reason: 'at $x,$y');
      }
    });

    test('outLongSide sets the long side', () {
      final r = rotatedRect();
      final out =
          decode(perspectiveWarp(jpg(r.image), r.corners, outLongSide: 400));
      expect(out.width, 400);
      expect(out.height, closeTo(200, 2));
    });

    test('a true perspective quad is rectified', () {
      final s = paperScene();
      final corners = [
        for (final c in s.corners) NormPoint(c.x / 1000, c.y / 750)
      ];
      final out = decode(perspectiveWarp(png(s.image), corners));
      // Sheet is grey (150) everywhere near the border of the output.
      for (final (x, y) in [(6, 6), (out.width - 7, out.height - 7)]) {
        expect(out.getPixel(x, y).r, closeTo(150, 25));
      }
    });

    test('requires exactly four corners', () {
      final r = rotatedRect();
      expect(() => perspectiveWarp(jpg(r.image), r.corners.sublist(0, 3)),
          throwsArgumentError);
    });
  });
}
