import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/utils/page_size.dart';

void main() {
  test('kích thước point', () {
    expect(PageSizeOption.letter.portraitPoints, (612.0, 792.0));
    expect(PageSizeOption.a4.portraitPoints.$1, closeTo(595.28, 0.01));
    expect(PageSizeOption.fit.portraitPoints, PageSizeOption.a4.portraitPoints);
  });

  test('fromName', () {
    expect(PageSizeOption.fromName('letter'), PageSizeOption.letter);
    expect(PageSizeOption.fromName(null), PageSizeOption.a4);
    expect(PageSizeOption.fromName('bogus'), PageSizeOption.a4);
  });

  test('pointsToPixels = point / 72 × dpi', () {
    expect(pointsToPixels(72, 150), 150);
    expect(pointsToPixels(595.28, 72), 595);
    expect(pointsToPixels(612, 300), 2550);
  });
}
