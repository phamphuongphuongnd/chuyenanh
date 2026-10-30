import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_office/core/errors/app_error.dart';
import 'package:pdf_office/features/editor/signature_image.dart';

/// "Ảnh chụp" giấy gần trắng [w]x[h]; [stroke] = vẽ một nét đen đặc 100x20 ở (100, 60).
img.Image paper({int w = 300, int h = 150, bool stroke = true}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(250, 248, 245));
  if (stroke) {
    img.fillRect(
      image,
      x1: 100,
      y1: 60,
      x2: 199,
      y2: 79,
      color: img.ColorRgb8(20, 20, 30),
    );
  }
  return image;
}

Uint8List png(img.Image image) => Uint8List.fromList(img.encodePng(image));

void main() {
  group('signaturePngFromPhoto', () {
    test('nen trang thanh trong suot, net giu lai, cat sat net', () {
      final out = signaturePngFromPhoto(png(paper()));
      expect(out, isNotNull);
      final image = img.decodePng(out!)!;
      // Nét 100x20 + lề 4 px mỗi cạnh của trimSignaturePng.
      expect(image.width, 108);
      expect(image.height, 28);
      // Góc (lề) là nền → trong suốt; giữa là nét → đặc.
      expect(image.getPixel(0, 0).a, 0);
      expect(image.getPixel(image.width - 1, image.height - 1).a, 0);
      final mid = image.getPixel(54, 14);
      expect(mid.a, greaterThan(200));
      // Không ép màu → giữ màu mực gốc.
      expect(mid.r, 20);
      expect(mid.b, 30);
    });

    test('ep mau muc', () {
      const ink = Color(0xFF1A3FA8);
      final out = signaturePngFromPhoto(png(paper()), ink: ink);
      final mid = img.decodePng(out!)!.getPixel(54, 14);
      expect([mid.r, mid.g, mid.b], [0x1A, 0x3F, 0xA8]);
      expect(mid.a, greaterThan(200));
    });

    test('anh JPG van tach duoc net', () {
      final jpg = Uint8List.fromList(img.encodeJpg(paper(), quality: 85));
      final out = signaturePngFromPhoto(jpg);
      expect(out, isNotNull);
      final image = img.decodePng(out!)!;
      expect(image.width, inInclusiveRange(104, 116));
      expect(image.height, inInclusiveRange(24, 36));
    });

    test('anh trang tinh -> null', () {
      final white = img.Image(width: 200, height: 100);
      img.fill(white, color: img.ColorRgb8(255, 255, 255));
      expect(signaturePngFromPhoto(png(white)), isNull);
    });

    test('giay trang chi co nhieu nho -> null', () {
      final noisy = paper(w: 200, h: 100, stroke: false);
      for (var i = 0; i < 200; i += 7) {
        noisy.setPixelRgb(i, (i * 3) % 100, 232, 232, 232);
      }
      expect(signaturePngFromPhoto(png(noisy)), isNull);
    });

    test('nguong qua thap (nguoi dung keo het) -> khong con net -> null', () {
      expect(signaturePngFromPhoto(png(paper()), threshold: 5), isNull);
    });

    test('anh lon duoc thu ve canh dai <= 1200', () {
      final big = img.Image(width: 3000, height: 1000);
      img.fill(big, color: img.ColorRgb8(250, 250, 250));
      img.fillRect(
        big,
        x1: 0,
        y1: 400,
        x2: 2999,
        y2: 499,
        color: img.ColorRgb8(0, 0, 0),
      );
      final photo = decodeSignaturePhoto(png(big));
      expect(photo.width, 1200);
      expect(photo.height, 400);
      final out = signaturePngFromDecodedPhoto(photo);
      expect(img.decodePng(out!)!.width, lessThanOrEqualTo(1200));
    });

    test('byte hong -> CorruptFile', () {
      expect(
        () => signaturePngFromPhoto(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<CorruptFile>()),
      );
    });
  });

  group('otsuThreshold', () {
    test('hai dinh tach biet -> nguong o giua', () {
      final h = List<int>.filled(256, 0);
      h[30] = 100;
      h[220] = 900;
      final t = otsuThreshold(h)!;
      expect(t, greaterThanOrEqualTo(30));
      expect(t, lessThan(220));
      expect(t, closeTo(125, 1));
    });

    test('mot mau / chenh lech nho -> null', () {
      final one = List<int>.filled(256, 0)..[200] = 50;
      expect(otsuThreshold(one), isNull);
      final close = List<int>.filled(256, 0)
        ..[230] = 10
        ..[250] = 500;
      expect(otsuThreshold(close), isNull);
      expect(otsuThreshold(List<int>.filled(256, 0)), isNull);
    });
  });
}
