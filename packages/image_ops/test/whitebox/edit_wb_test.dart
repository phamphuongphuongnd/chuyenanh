// Kiểm thử hộp trắng (A16, Bước 6) cho lib/src/edit.dart.
// Expected chép từ test-output/whitebox/image-ops/edit/buoc-5-du-lieu-thu.md.
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_ops/image_ops.dart';
import 'package:image_ops/src/raw.dart' show decodeRaw;
import 'package:test/test.dart';

import '../helpers.dart';

final garbage = Uint8List.fromList(List.generate(64, (i) => (i * 37) % 251));

/// PNG cắt còn 40 byte: vẫn nhận ra là PNG nhưng giải mã ra null.
Uint8List truncatedPng() =>
    Uint8List.fromList(png(quadrantImage(30, 20)).sublist(0, 40));

Object? run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

void main() {
  group('U1 applyEdit', () {
    test('AE-1 JPEG hợp lệ ⇒ JPEG cùng cỡ (D1 S)', () {
      final out = applyEdit(jpg(quadrantImage(60, 40)), const ImageEdit());
      expect(isJpeg(out), isTrue);
      final d = decode(out);
      expect([d.width, d.height], [60, 40]);
    });
    test('AE-2 dữ liệu rác ⇒ FormatException (D1 Đ)', () {
      expect(img.findDecoderForData(garbage), isNull, reason: 'đi nhánh _decoderFor ném');
      expect(run(() => applyEdit(garbage, const ImageEdit())), isA<FormatException>());
    });
  });

  group('U2 renderPreview', () {
    final src = jpg(quadrantImage(1200, 600));
    test('RP-1 không maxLongSide ⇒ cạnh dài 1024 (D1 Đ)', () {
      final d = decode(renderPreview(src, const ImageEdit()));
      expect([d.width, d.height], [1024, 512]);
    });
    test('RP-2 maxLongSide 300 < 1024 ⇒ cạnh dài 300 (D1 S)', () {
      final d = decode(renderPreview(src, const ImageEdit(maxLongSide: 300)));
      expect([d.width, d.height], [300, 150]);
    });
    test('RP-3 rác ⇒ FormatException (D2 Đ)', () {
      expect(run(() => renderPreview(garbage, const ImageEdit())), isA<FormatException>());
    });
  });

  group('U3 editRaw (qua applyEdit)', () {
    final src = jpg(quadrantImage(200, 100));
    img.Image out(ImageEdit e) => decode(applyEdit(src, e));
    test('ER-1 maxLong 50, không crop ⇒ 50x25', () {
      final d = out(const ImageEdit(maxLongSide: 50));
      expect([d.width, d.height], [50, 25]);
    });
    test('ER-2 không maxLong, không crop ⇒ 200x100', () {
      final d = out(const ImageEdit());
      expect([d.width, d.height], [200, 100]);
    });
    test('ER-3 maxLong 0 ⇒ không thu nhỏ, 200x100 (D2 S, D8 S)', () {
      final d = out(const ImageEdit(maxLongSide: 0));
      expect([d.width, d.height], [200, 100]);
    });
    test('ER-4 crop góc trên-trái 0.5x0.5 + maxLong 50 ⇒ 50x25, toàn đỏ (D3 S, D4 Đ)', () {
      final d = out(const ImageEdit(
          maxLongSide: 50, crop: NormRect(left: 0, top: 0, width: 0.5, height: 0.5)));
      expect([d.width, d.height], [50, 25]);
      expect(isRedAt(d, 25, 12), isTrue);
      expect(isRedAt(d, 48, 23), isTrue);
    });
    test('ER-5 crop rỗng (w = h = 0) + maxLong 50 ⇒ ảnh ≥ 1 px, không ném (D4 S)', () {
      final d = out(const ImageEdit(
          maxLongSide: 50, crop: NormRect(left: 0.2, top: 0.2, width: 0, height: 0)));
      expect([d.width, d.height], [1, 1]);
    });
    test('ER-6 rác ⇒ FormatException (D5 Đ)', () {
      expect(run(() => applyEdit(garbage, const ImageEdit(maxLongSide: 50))),
          isA<FormatException>());
    });
    test('ER-7 không maxLong + crop nửa phải ⇒ 100x100 trắng (D1 S, D6 Đ, D7 S)', () {
      final d = out(const ImageEdit(crop: NormRect(left: 0.5, top: 0, width: 0.5, height: 1)));
      expect([d.width, d.height], [100, 100]);
      expect(isWhiteAt(d, 50, 50), isTrue);
    });
  });

  group('U4 probe', () {
    test('PB-1 JPEG 80x40 EXIF 6 ⇒ 40x80, jpeg, không alpha, exif 6', () {
      final im = quadrantImage(80, 40)..exif.imageIfd.orientation = 6;
      final bytes = jpg(im);
      expect(img.decodeJpgExif(bytes)?.imageIfd.hasOrientation, isTrue, reason: 'D4 Đ, D5 Đ');
      final i = probe(bytes);
      expect([i.width, i.height, i.format, i.hasAlpha, i.exifOrientation],
          [40, 80, ImageSourceFormat.jpeg, false, 6]);
    });
    test('PB-2 rác ⇒ FormatException (D1 Đ)', () {
      expect(run(() => probe(garbage)), isA<FormatException>());
    });
    test('PB-3 PNG 30x20 RGB ⇒ 30x20, png, không alpha, exif 1 (D2 S, D10 S, D11 S)', () {
      final i = probe(png(quadrantImage(30, 20)));
      expect([i.width, i.height, i.format, i.hasAlpha, i.exifOrientation],
          [30, 20, ImageSourceFormat.png, false, 1]);
    });
    test('PB-3b PNG có pixel trong suốt ⇒ hasAlpha true (bổ sung)', () {
      final im = img.Image(width: 4, height: 4, numChannels: 4);
      img.fill(im, color: img.ColorRgba8(10, 20, 30, 255));
      im.setPixelRgba(1, 1, 0, 0, 0, 0);
      expect(probe(png(im)).hasAlpha, isTrue);
    });
    test('PB-5 JPEG không EXIF ⇒ 80x40, exif 1 (D4 S)', () {
      final bytes = jpg(quadrantImage(80, 40));
      expect(img.decodeJpgExif(bytes), isNull, reason: 'D4 S');
      final i = probe(bytes);
      expect([i.width, i.height, i.exifOrientation], [80, 40, 1]);
    });
    test('PB-6 JPEG có EXIF nhưng không có tag orientation ⇒ 80x40, exif 1 (D5 S)', () {
      final im = quadrantImage(80, 40)..exif.imageIfd.software = 'wb';
      final bytes = jpg(im);
      final ex = img.decodeJpgExif(bytes);
      expect(ex, isNotNull, reason: 'D4 Đ');
      expect(ex!.imageIfd.hasOrientation, isFalse, reason: 'D5 S');
      final i = probe(bytes);
      expect([i.width, i.height, i.exifOrientation], [80, 40, 1]);
    });
    test('PB-10 PNG cụt (nhận ra PNG, giải mã hỏng) ⇒ FormatException (D9 Đ)', () {
      final b = truncatedPng();
      expect(img.findDecoderForData(b)?.format, img.ImageFormat.png, reason: 'D1 S, D2 S');
      expect(run(() => probe(b)), isA<FormatException>());
    });
    test('PB-11 WebP 30x20 EXIF 6 ⇒ 20x30, webp, exif 6 (D10 Đ, D11 Đ)', () {
      final im = quadrantImage(30, 20)..exif.imageIfd.orientation = 6;
      final b = img.encodeWebP(im);
      expect(decodeRaw(b).orientation, 6, reason: 'tag còn sau giải mã');
      final i = probe(b);
      expect([i.width, i.height, i.format, i.exifOrientation],
          [20, 30, ImageSourceFormat.webp, 6]);
    });
  });
}
