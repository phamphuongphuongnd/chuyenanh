// Kiểm thử hộp trắng (A16, Bước 6) cho lib/src/models.dart.
// Expected chép từ test-output/whitebox/image-ops/models/buoc-5-du-lieu-thu.md.
import 'package:image_ops/image_ops.dart';
import 'package:test/test.dart';

void main() {
  const r = NormRect(left: 0.1, top: 0.2, width: 0.3, height: 0.4);
  const r2 = NormRect(left: 0.5, top: 0.5, width: 0.25, height: 0.25);

  group('U1 NormRect ==', () {
    test('NR-1 cùng 4 trường ⇒ true (D1..D5 Đ)', () {
      expect(r == const NormRect(left: 0.1, top: 0.2, width: 0.3, height: 0.4), isTrue);
      expect(r.hashCode,
          const NormRect(left: 0.1, top: 0.2, width: 0.3, height: 0.4).hashCode);
    });
    test('NR-2 khác kiểu ⇒ false (D1 S)', () {
      expect(r == (const NormPoint(0.1, 0.2) as Object), isFalse);
    });
    test('NR-3 khác left ⇒ false (D2 S)', () {
      expect(r == const NormRect(left: 0.5, top: 0.2, width: 0.3, height: 0.4), isFalse);
    });
    test('NR-4 khác top ⇒ false (D3 S)', () {
      expect(r == const NormRect(left: 0.1, top: 0.5, width: 0.3, height: 0.4), isFalse);
    });
    test('NR-5 khác width ⇒ false (D4 S)', () {
      expect(r == const NormRect(left: 0.1, top: 0.2, width: 0.5, height: 0.4), isFalse);
    });
    test('NR-6 khác height ⇒ false (D5 S)', () {
      expect(r == const NormRect(left: 0.1, top: 0.2, width: 0.3, height: 0.5), isFalse);
    });
  });

  group('U2 NormPoint ==', () {
    const p = NormPoint(0.25, 0.75);
    test('NP-1 cùng x, y ⇒ true', () {
      expect(p == const NormPoint(0.25, 0.75), isTrue);
      expect(p.hashCode, const NormPoint(0.25, 0.75).hashCode);
    });
    test('NP-2 khác kiểu ⇒ false (D1 S)', () {
      expect(p == (r as Object), isFalse);
    });
    test('NP-3 khác x ⇒ false (D2 S)', () {
      expect(p == const NormPoint(0.3, 0.75), isFalse);
    });
    test('NP-4 khác y ⇒ false (D3 S)', () {
      expect(p == const NormPoint(0.25, 0.8), isFalse);
    });
  });

  const e = ImageEdit(
    rotationQuarterTurns: 1,
    crop: r,
    filter: ImageFilter.grayscale,
    maxLongSide: 500,
    brightness: 0.1,
    contrast: 0.2,
    adaptiveThreshold: false,
  );

  void expectFields(ImageEdit x,
      {int rot = 1,
      NormRect? crop = r,
      ImageFilter filter = ImageFilter.grayscale,
      int? maxLong = 500,
      double b = 0.1,
      double c = 0.2,
      bool adaptive = false}) {
    expect(x.rotationQuarterTurns, rot, reason: 'rotationQuarterTurns');
    expect(x.crop, crop, reason: 'crop');
    expect(x.filter, filter, reason: 'filter');
    expect(x.maxLongSide, maxLong, reason: 'maxLongSide');
    expect(x.brightness, b, reason: 'brightness');
    expect(x.contrast, c, reason: 'contrast');
    expect(x.adaptiveThreshold, adaptive, reason: 'adaptiveThreshold');
  }

  group('U3 ImageEdit.copyWith', () {
    test('CW-1 không đối số ⇒ giữ nguyên mọi trường', () => expectFields(e.copyWith()));
    test('CW-2 rotationQuarterTurns: 3 (D1 S)',
        () => expectFields(e.copyWith(rotationQuarterTurns: 3), rot: 3));
    test('CW-3 clearCrop: true thắng crop mới (D2 Đ)',
        () => expectFields(e.copyWith(clearCrop: true, crop: r2), crop: null));
    test('CW-4 crop mới (D3 S)', () => expectFields(e.copyWith(crop: r2), crop: r2));
    test('CW-5 filter mới (D4 S)',
        () => expectFields(e.copyWith(filter: ImageFilter.magicColor),
            filter: ImageFilter.magicColor));
    test('CW-6 clearMaxLongSide (D5 Đ)',
        () => expectFields(e.copyWith(clearMaxLongSide: true, maxLongSide: 9), maxLong: null));
    test('CW-7 maxLongSide mới (D6 S)',
        () => expectFields(e.copyWith(maxLongSide: 800), maxLong: 800));
    test('CW-8 brightness mới (D7 S)',
        () => expectFields(e.copyWith(brightness: -0.5), b: -0.5));
    test('CW-9 contrast mới (D8 S)', () => expectFields(e.copyWith(contrast: 0.7), c: 0.7));
    test('CW-10 adaptiveThreshold mới (D9 S)',
        () => expectFields(e.copyWith(adaptiveThreshold: true), adaptive: true));
  });

  group('U4 ImageEdit ==', () {
    test('IE-1 cùng giá trị, góc 5 ≡ 1 (mod 4) ⇒ true, hashCode bằng nhau', () {
      const o = ImageEdit(
          rotationQuarterTurns: 5,
          crop: NormRect(left: 0.1, top: 0.2, width: 0.3, height: 0.4),
          filter: ImageFilter.grayscale,
          maxLongSide: 500,
          brightness: 0.1,
          contrast: 0.2,
          adaptiveThreshold: false);
      expect(e == o, isTrue);
      expect(e.hashCode, o.hashCode);
    });
    test('IE-2 khác kiểu ⇒ false (D1 S)', () => expect(e == ('x' as Object), isFalse));
    test('IE-3 khác góc ⇒ false (D2 S)',
        () => expect(e == e.copyWith(rotationQuarterTurns: 2), isFalse));
    test('IE-4 khác crop ⇒ false (D3 S)',
        () => expect(e == e.copyWith(clearCrop: true), isFalse));
    test('IE-5 khác filter ⇒ false (D4 S)',
        () => expect(e == e.copyWith(filter: ImageFilter.original), isFalse));
    test('IE-6 khác maxLongSide ⇒ false (D5 S)',
        () => expect(e == e.copyWith(clearMaxLongSide: true), isFalse));
    test('IE-7 khác brightness ⇒ false (D6 S)',
        () => expect(e == e.copyWith(brightness: 0.3), isFalse));
    test('IE-8 khác contrast ⇒ false (D7 S)',
        () => expect(e == e.copyWith(contrast: 0.3), isFalse));
    test('IE-9 khác adaptiveThreshold ⇒ false (D8 S)',
        () => expect(e == e.copyWith(adaptiveThreshold: true), isFalse));
  });
}
