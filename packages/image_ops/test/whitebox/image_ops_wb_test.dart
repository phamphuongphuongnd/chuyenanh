// Kiểm thử hộp trắng (A16, Bước 6) cho lib/image_ops.dart (file chỉ export, 0 nút quyết định).
// Expected chép từ test-output/whitebox/image-ops/image_ops/buoc-5-du-lieu-thu.md.
import 'package:image_ops/image_ops.dart';
import 'package:test/test.dart';

void main() {
  test('EX-1 export MỚI: composeIdCard, idCardFrames, IdCardLayout, IdCardFit, IdCardFrame dùng được từ API gói', () {
    const layout = IdCardLayout(fit: IdCardFit.cover);
    final ({IdCardFrame front, IdCardFrame back}) f = idCardFrames(layout);
    expect(f.front.width, greaterThan(0));
    expect(IdCardFit.values, [IdCardFit.contain, IdCardFit.cover]);
    expect(composeIdCard, isA<Function>());
  });
  test('EX-2 export CŨ vẫn còn: edit, document, layout, models', () {
    expect([applyEdit, renderPreview, probe, perspectiveWarp, detectDocumentCorners,
        placeImageOnPage, estimateJpegBytes, marginPt], everyElement(isA<Function>()));
    expect(pageSizesPt.keys, containsAll([PageSizePreset.a4, PageSizePreset.letter]));
    expect(const ImageEdit().filter, ImageFilter.original);
  });
}
