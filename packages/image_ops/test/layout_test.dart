import 'package:image_ops/image_ops.dart';
import 'package:test/test.dart';

const _sizes = <PageSizePreset, (double, double)>{
  PageSizePreset.a4: (595.28, 841.89),
  PageSizePreset.letter: (612, 792),
  PageSizePreset.legal: (612, 1008),
  PageSizePreset.a3: (841.89, 1190.55),
  PageSizePreset.a5: (419.53, 595.28),
};

const _margins = <MarginPreset, double>{
  MarginPreset.none: 0,
  MarginPreset.small: 18,
  MarginPreset.large: 36,
};

void main() {
  // (width px, height px) — big landscape, big portrait, square, small.
  const shapes = <(int, int)>[(4000, 3000), (3000, 4000), (2000, 2000), (300, 200)];

  group('placeImageOnPage: every preset x orientation x margin', () {
    for (final size in _sizes.keys) {
      for (final orient in PageOrientation.values) {
        for (final margin in MarginPreset.values) {
          for (final (pw, ph) in shapes) {
            test('$size $orient $margin ${pw}x$ph', () {
              final p = placeImageOnPage(
                  imagePxWidth: pw,
                  imagePxHeight: ph,
                  size: size,
                  orientation: orient,
                  margin: margin);
              final (short, long) = _sizes[size]!;
              final landscape = switch (orient) {
                PageOrientation.landscape => true,
                PageOrientation.portrait => false,
                PageOrientation.auto => pw > ph,
              };
              expect(p.pageWidth, closeTo(landscape ? long : short, 0.01));
              expect(p.pageHeight, closeTo(landscape ? short : long, 0.01));

              final m = _margins[margin]!;
              // Inside the margins.
              expect(p.imageLeft, greaterThanOrEqualTo(m - 1e-6));
              expect(p.imageTop, greaterThanOrEqualTo(m - 1e-6));
              expect(p.imageLeft + p.imageWidth,
                  lessThanOrEqualTo(p.pageWidth - m + 1e-6));
              expect(p.imageTop + p.imageHeight,
                  lessThanOrEqualTo(p.pageHeight - m + 1e-6));
              // Aspect ratio preserved (< 0.5 pt).
              expect((p.imageHeight - p.imageWidth * ph / pw).abs(),
                  lessThan(0.5));
              // Centred.
              expect(
                  (p.imageLeft - (p.pageWidth - p.imageLeft - p.imageWidth))
                      .abs(),
                  lessThan(1e-6));
              expect(
                  (p.imageTop - (p.pageHeight - p.imageTop - p.imageHeight))
                      .abs(),
                  lessThan(1e-6));
              // Never larger than its natural size at 150 dpi.
              expect(p.imageWidth, lessThanOrEqualTo(pw * 72 / 150 + 1e-6));
              // Big images fill one dimension of the printable area.
              if (pw >= 2000) {
                final fillsW = (p.imageWidth - (p.pageWidth - 2 * m)).abs() < 1e-6;
                final fillsH = (p.imageHeight - (p.pageHeight - 2 * m)).abs() < 1e-6;
                expect(fillsW || fillsH, isTrue);
              }
            });
          }
        }
      }
    }
  });

  test('landscape image on A4 auto gives a landscape page', () {
    final p = placeImageOnPage(
        imagePxWidth: 1600, imagePxHeight: 1200, size: PageSizePreset.a4);
    expect(p.pageWidth, greaterThan(p.pageHeight));
  });

  test('small image is kept at its natural size and centred', () {
    final p = placeImageOnPage(
        imagePxWidth: 300,
        imagePxHeight: 150,
        size: PageSizePreset.a4,
        orientation: PageOrientation.portrait);
    expect(p.imageWidth, closeTo(144, 1e-9)); // 300 px @150 dpi = 2 in
    expect(p.imageHeight, closeTo(72, 1e-9));
    expect(p.imageLeft, closeTo((595.28 - 144) / 2, 1e-9));
  });

  test('dpiForFit changes the natural size', () {
    final p = placeImageOnPage(
        imagePxWidth: 300,
        imagePxHeight: 150,
        size: PageSizePreset.a4,
        dpiForFit: 300);
    expect(p.imageWidth, closeTo(72, 1e-9));
  });

  group('fitImage', () {
    for (final margin in MarginPreset.values) {
      test('page equals the image at dpiForFit plus $margin', () {
        final m = _margins[margin]!;
        final p = placeImageOnPage(
            imagePxWidth: 1500,
            imagePxHeight: 900,
            size: PageSizePreset.fitImage,
            margin: margin);
        expect(p.imageWidth, closeTo(720, 1e-9));
        expect(p.imageHeight, closeTo(432, 1e-9));
        expect(p.pageWidth, closeTo(720 + 2 * m, 1e-9));
        expect(p.pageHeight, closeTo(432 + 2 * m, 1e-9));
        expect(p.imageLeft, closeTo(m, 1e-9));
        expect(p.imageTop, closeTo(m, 1e-9));
      });
    }
  });

  test('invalid pixel sizes throw', () {
    expect(
        () => placeImageOnPage(
            imagePxWidth: 0, imagePxHeight: 10, size: PageSizePreset.a4),
        throwsArgumentError);
  });
}
