// Kiểm thử hộp trắng A19 — lib/pptx_reader.dart (mã bộ L*, xem
// test-output/whitebox/pptx-reader/pptx_reader/buoc-5-du-lieu-thu.md).
// File chỉ có export: 1 đường (V(G)=1) — bề mặt API công khai.
import 'dart:typed_data';

import 'package:pptx_reader/pptx_reader.dart';
import 'package:test/test.dart';

import '../helpers/pptx_builder.dart';

void main() {
  test('L1.1 thư viện công khai xuất readPptx + model, đọc được deck tối thiểu', () {
    final deck = readPptx((PptxBuilder()..slides.add(TestSlide(''))).build());
    expect(deck, isA<PptxDeck>());
    expect(deck.slides, hasLength(1));
    expect(
      () => readPptx(Uint8List.fromList([1, 2, 3, 4, 5])),
      throwsA(isA<PptxFormatException>()),
    );
  });
}
