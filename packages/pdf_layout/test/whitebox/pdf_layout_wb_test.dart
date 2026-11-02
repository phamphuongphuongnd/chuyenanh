// Kiểm thử hộp trắng (A18) — lib/pdf_layout.dart (bề mặt export). Mong đợi chép từ buoc-5-du-lieu-thu.md.
import 'dart:typed_data';

import 'package:pdf_layout/pdf_layout.dart';
import 'package:test/test.dart';

void main() {
  test('U1-P1 chỉ import pdf_layout.dart là dùng được đủ 4 điểm vào và API pptx', () {
    const page = LayoutPage(index: 0, width: 595, height: 842, lines: []);
    expect(rebuildDocument([page]), isEmpty);
    expect(detectSheets([page]), hasLength(1));
    expect(writeDocx(const <DocBlock>[]), isNotEmpty);
    expect(emuPerPt, 12700);
    expect(PptxImageFormat.values, containsAll([PptxImageFormat.png, PptxImageFormat.jpeg]));
    expect(slideSizeEmu(720, 405), (9144000, 5143500));
    expect(fitImageEmu(1, 1, 100, 100), (0, 0, 100, 100));
    final bytes = writeImagePptx([
      PptxImageSlide(bytes: Uint8List.fromList([1, 2, 3]), widthPt: 720, heightPt: 405),
    ]);
    expect(bytes.sublist(0, 2), [0x50, 0x4B]); // "PK" — gói zip
    expect(const RebuildOptions(), isA<RebuildOptions>());
    expect(const DocxWriteOptions(), isA<DocxWriteOptions>());
  });
}
