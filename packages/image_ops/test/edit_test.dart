import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart';
import 'package:test/test.dart';

import 'helpers.dart';

double meanLuma(img.Image im) {
  var s = 0.0;
  for (final p in im) {
    s += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  }
  return s / (im.width * im.height);
}

double stdLuma(img.Image im) {
  final m = meanLuma(im);
  var s = 0.0;
  for (final p in im) {
    final l = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    s += (l - m) * (l - m);
  }
  return math.sqrt(s / (im.width * im.height));
}

void main() {
  group('rotation (clockwise quarter turns)', () {
    final src = jpg(quadrantImage(80, 40));
    // Where the red quadrant ends up after n clockwise quarter turns.
    final expectations = <int, ({int w, int h, int rx, int ry})>{
      0: (w: 80, h: 40, rx: 10, ry: 10),
      1: (w: 40, h: 80, rx: 30, ry: 10),
      2: (w: 80, h: 40, rx: 70, ry: 30),
      3: (w: 40, h: 80, rx: 10, ry: 70),
    };
    for (final e in expectations.entries) {
      test('${e.key} turn(s)', () {
        final out =
            decode(applyEdit(src, ImageEdit(rotationQuarterTurns: e.key)));
        expect(out.width, e.value.w);
        expect(out.height, e.value.h);
        expect(isRedAt(out, e.value.rx, e.value.ry), isTrue);
        // The opposite corner stays white.
        expect(
            isWhiteAt(out, e.value.w - 1 - e.value.rx,
                e.value.h - 1 - e.value.ry),
            isTrue);
      });
    }

    test('negative and >3 turns are normalised', () {
      final a = decode(applyEdit(src, const ImageEdit(rotationQuarterTurns: -1)));
      final b = decode(applyEdit(src, const ImageEdit(rotationQuarterTurns: 7)));
      expect(a.width, 40);
      expect(isRedAt(a, 10, 70), isTrue);
      expect(b.width, 40);
      expect(isRedAt(b, 10, 70), isTrue);
    });
  });

  group('crop', () {
    test('NormRect is applied in the rotated frame', () {
      final src = jpg(quadrantImage(100, 50));
      // After 1 turn: 50x100, red occupies x 25..50, y 0..50.
      final out = decode(applyEdit(
          src,
          const ImageEdit(
              rotationQuarterTurns: 1,
              crop: NormRect(left: 0.5, top: 0, width: 0.5, height: 0.5))));
      expect(out.width, 25);
      expect(out.height, 50);
      expect(isRedAt(out, 12, 25), isTrue);
      expect(isRedAt(out, 3, 3), isTrue);
      expect(isRedAt(out, 21, 46), isTrue);
    });

    test('crop without rotation picks the white half', () {
      final src = jpg(quadrantImage(100, 50));
      final out = decode(applyEdit(
          src,
          const ImageEdit(
              crop: NormRect(left: 0.5, top: 0.0, width: 0.5, height: 1.0))));
      expect(out.width, 50);
      expect(out.height, 50);
      expect(isWhiteAt(out, 25, 25), isTrue);
    });

    test('out-of-range crop is clamped to the image', () {
      final src = jpg(quadrantImage(100, 50));
      final out = decode(applyEdit(
          src,
          const ImageEdit(
              crop: NormRect(left: -0.2, top: 0.5, width: 2, height: 2))));
      expect(out.width, 100);
      expect(out.height, 25);
    });
  });

  group('EXIF orientation', () {
    for (final o in [3, 6, 8]) {
      test('orientation $o is baked before editing', () {
        final im = quadrantImage(80, 40);
        im.exif.imageIfd.orientation = o;
        final bytes = jpg(im);
        final info = probe(bytes);
        final out = decode(applyEdit(bytes, const ImageEdit()));
        final rotated = o == 6 || o == 8;
        expect(out.width, rotated ? 40 : 80);
        expect(info.width, out.width);
        expect(info.height, out.height);
        // 6 = rotate 90 CW, 8 = rotate 90 CCW, 3 = 180.
        final (rx, ry) = switch (o) {
          6 => (30, 10),
          8 => (10, 70),
          _ => (70, 30),
        };
        expect(isRedAt(out, rx, ry), isTrue);
        // Output carries no orientation tag any more.
        final outExif = img.decodeJpgExif(applyEdit(bytes, const ImageEdit()));
        expect(outExif?.imageIfd.orientation ?? 1, 1);
      });
    }

    test('orientation survives reduced-scale JPEG decoding', () {
      final im = quadrantImage(1600, 800);
      im.exif.imageIfd.orientation = 6;
      final out =
          decode(applyEdit(jpg(im), const ImageEdit(maxLongSide: 200)));
      expect(out.width, 100);
      expect(out.height, 200);
      expect(isRedAt(out, 75, 25), isTrue);
      expect(isWhiteAt(out, 25, 175), isTrue);
    });
  });

  group('filters', () {
    final src = jpg(photoLike(240, 180));
    for (final f in ImageFilter.values) {
      test('$f produces a valid image of the same size', () {
        final out = applyEdit(src, ImageEdit(filter: f));
        expect(isJpeg(out), isTrue);
        final im = decode(out);
        expect(im.width, 240);
        expect(im.height, 180);
      });
    }

    test('grayscale has R = G = B', () {
      final out = decode(applyEdit(src, const ImageEdit(filter: ImageFilter.grayscale),
          format: OutputFormat.png));
      for (final p in out) {
        expect(p.r, p.g);
        expect(p.g, p.b);
      }
    });

    test('blackWhite contains only 0 and 255, both present', () {
      final scene = paperScene(w: 400, h: 300).image;
      final out = decode(applyEdit(
          png(scene), const ImageEdit(filter: ImageFilter.blackWhite),
          format: OutputFormat.png));
      var black = 0, whiteCount = 0;
      for (final p in out) {
        expect(p.r == 0 || p.r == 255, isTrue);
        expect(p.g, p.r);
        expect(p.b, p.r);
        if (p.r == 0) {
          black++;
        } else {
          whiteCount++;
        }
      }
      expect(black, greaterThan(0));
      expect(whiteCount, greaterThan(black));
    });

    test('blackWhite in Otsu mode is also binary', () {
      final out = decode(applyEdit(
          src,
          const ImageEdit(
              filter: ImageFilter.blackWhite, adaptiveThreshold: false),
          format: OutputFormat.png));
      for (final p in out) {
        expect(p.r == 0 || p.r == 255, isTrue);
      }
    });

    test('brighten raises mean luminance', () {
      final base = decode(applyEdit(src, const ImageEdit()));
      final out = decode(applyEdit(src, const ImageEdit(filter: ImageFilter.brighten)));
      expect(meanLuma(out), greaterThan(meanLuma(base) + 5));
    });

    test('enhance raises contrast on a flat image', () {
      final flat = img.Image(width: 120, height: 90);
      img.fill(flat, color: img.ColorRgb8(120, 120, 120));
      img.fillRect(flat, x1: 30, y1: 20, x2: 90, y2: 70,
          color: img.ColorRgb8(150, 150, 150));
      final b = png(flat);
      final base = decode(applyEdit(b, const ImageEdit(), format: OutputFormat.png));
      final out = decode(applyEdit(b, const ImageEdit(filter: ImageFilter.enhance),
          format: OutputFormat.png));
      expect(stdLuma(out), greaterThan(stdLuma(base) * 1.5));
    });

    test('magicColor whitens a tinted, dim paper', () {
      final tinted = img.Image(width: 120, height: 90);
      img.fill(tinted, color: img.ColorRgb8(190, 170, 140)); // yellowish paper
      img.fillRect(tinted, x1: 20, y1: 40, x2: 100, y2: 46,
          color: img.ColorRgb8(50, 45, 40)); // text line
      final out = decode(applyEdit(
          png(tinted), const ImageEdit(filter: ImageFilter.magicColor),
          format: OutputFormat.png));
      final p = out.getPixel(5, 5);
      expect(p.r, greaterThan(235));
      expect(p.g, greaterThan(235));
      expect(p.b, greaterThan(235));
      final t = out.getPixel(60, 43);
      expect(t.r, lessThan(90));
    });
  });

  group('brightness / contrast', () {
    final src = jpg(photoLike(160, 120));
    test('brightness > 0 brightens, < 0 darkens', () {
      final base = meanLuma(decode(applyEdit(src, const ImageEdit())));
      final up = meanLuma(decode(applyEdit(src, const ImageEdit(brightness: 0.3))));
      final down =
          meanLuma(decode(applyEdit(src, const ImageEdit(brightness: -0.3))));
      expect(up, greaterThan(base + 20));
      expect(down, lessThan(base - 20));
    });
    test('contrast > 0 widens the spread', () {
      final base = stdLuma(decode(applyEdit(src, const ImageEdit())));
      final up = stdLuma(decode(applyEdit(src, const ImageEdit(contrast: 0.5))));
      expect(up, greaterThan(base * 1.2));
    });
  });

  group('maxLongSide', () {
    final src = jpg(photoLike(400, 300));
    test('downscales keeping the aspect ratio', () {
      final out = decode(applyEdit(src, const ImageEdit(maxLongSide: 200)));
      expect(out.width, 200);
      expect(out.height, 150);
    });
    test('applies to the long side of a portrait result', () {
      final out = decode(applyEdit(
          src, const ImageEdit(maxLongSide: 200, rotationQuarterTurns: 1)));
      expect(out.width, 150);
      expect(out.height, 200);
    });
    test('never upscales', () {
      final out = decode(applyEdit(src, const ImageEdit(maxLongSide: 1000)));
      expect(out.width, 400);
      expect(out.height, 300);
    });
    test('large JPEG uses reduced-scale decoding and still hits the size', () {
      final big = jpg(photoLike(1600, 1200), quality: 85);
      final out = decode(applyEdit(big, const ImageEdit(maxLongSide: 300)));
      expect(out.width, 300);
      expect(out.height, 225);
    });
  });

  group('encoding', () {
    test('JPEG quality changes the output size', () {
      final src = jpg(photoLike(320, 240), quality: 100);
      final lo = applyEdit(src, const ImageEdit(), jpegQuality: 30);
      final hi = applyEdit(src, const ImageEdit(), jpegQuality: 95);
      expect(lo.length, lessThan(hi.length * 0.7));
    });

    test('PNG with real alpha stays PNG and keeps alpha', () {
      final im = img.Image(width: 60, height: 40, numChannels: 4);
      img.fill(im, color: img.ColorRgba8(255, 0, 0, 255));
      img.fillRect(im, x1: 0, y1: 0, x2: 29, y2: 39,
          color: img.ColorRgba8(0, 0, 255, 100), alphaBlend: false);
      final out = applyEdit(png(im), const ImageEdit(rotationQuarterTurns: 2));
      expect(isPng(out), isTrue);
      final d = decode(out);
      expect(d.numChannels, 4);
      expect(d.getPixel(50, 20).a, closeTo(100, 1));
      expect(d.getPixel(5, 20).a, 255);
      expect(probe(png(im)).hasAlpha, isTrue);
    });

    test('PNG with an opaque alpha channel becomes JPEG', () {
      final im = img.Image(width: 60, height: 40, numChannels: 4);
      img.fill(im, color: img.ColorRgba8(10, 200, 10, 255));
      final bytes = png(im);
      expect(isJpeg(applyEdit(bytes, const ImageEdit())), isTrue);
      expect(probe(bytes).hasAlpha, isFalse);
    });

    test('BMP input is accepted', () {
      final bytes = img.encodeBmp(quadrantImage(50, 30));
      expect(probe(bytes).format, ImageSourceFormat.bmp);
      final out = decode(applyEdit(bytes, const ImageEdit()));
      expect(out.width, 50);
      expect(isRedAt(out, 5, 5), isTrue);
    });

    test('GIF input uses the first frame', () {
      final f0 = quadrantImage(50, 30);
      final f1 = img.Image(width: 50, height: 30);
      img.fill(f1, color: blue);
      f0.addFrame(f1);
      final bytes = img.encodeGif(f0);
      expect(probe(bytes).format, ImageSourceFormat.gif);
      final out = decode(applyEdit(bytes, const ImageEdit()));
      expect(out.width, 50);
      expect(isRedAt(out, 5, 5), isTrue);
      expect(isWhiteAt(out, 45, 25), isTrue);
    });

    test('WebP input is accepted', () {
      Uint8List bytes;
      try {
        bytes = img.encodeWebP(quadrantImage(50, 30));
      } catch (e) {
        markTestSkipped('WebP encoder unavailable: $e');
        return;
      }
      final info = probe(bytes);
      expect(info.format, ImageSourceFormat.webp);
      expect(info.width, 50);
      final out = decode(applyEdit(bytes, const ImageEdit()));
      expect(out.width, 50);
      expect(isRedAt(out, 5, 5), isTrue);
    });

    test('garbage input throws FormatException', () {
      final junk = Uint8List.fromList(List.generate(100, (i) => i));
      expect(() => applyEdit(junk, const ImageEdit()), throwsFormatException);
      expect(() => probe(junk), throwsFormatException);
    });
  });

  group('probe', () {
    test('JPEG size, format, no alpha', () {
      final info = probe(jpg(quadrantImage(64, 48)));
      expect(info.width, 64);
      expect(info.height, 48);
      expect(info.format, ImageSourceFormat.jpeg);
      expect(info.hasAlpha, isFalse);
    });
    test('PNG format', () {
      expect(probe(png(quadrantImage(10, 12))).format, ImageSourceFormat.png);
    });
  });

  group('renderPreview', () {
    test('limits the long side', () {
      final src = jpg(photoLike(1200, 600));
      final out = decode(renderPreview(src, const ImageEdit(), maxSide: 256));
      expect(out.width, 256);
      expect(out.height, 128);
    });
    test('respects a smaller maxLongSide in the edit', () {
      final src = jpg(photoLike(1200, 600));
      final out = decode(renderPreview(src, const ImageEdit(maxLongSide: 100)));
      expect(out.width, 100);
    });
  });

  group('estimateJpegBytes', () {
    test('grows with quality and with pixel count', () {
      expect(estimateJpegBytes(1000, 1000, 50),
          lessThan(estimateJpegBytes(1000, 1000, 90)));
      expect(estimateJpegBytes(2000, 1000, 80),
          closeTo(2 * estimateJpegBytes(1000, 1000, 80), 2000));
    });
    test('is in a plausible range for a 12 MP photo', () {
      final b = estimateJpegBytes(4000, 3000, 90);
      expect(b, greaterThan(1500000));
      expect(b, lessThan(8000000));
    });
    test('clamps quality and handles empty images', () {
      expect(estimateJpegBytes(0, 100, 80), 0);
      expect(estimateJpegBytes(100, 100, 500),
          estimateJpegBytes(100, 100, 100));
    });
  });
}
