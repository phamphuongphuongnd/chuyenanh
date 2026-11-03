// Lớp chữ vô hình khi nén: PDF có CMap ToUnicode lệch chuẩn (đích bfrange 5 chữ số hex, kiểu MuPDF)
// trước đây trích lỗi → mất cả lớp chữ; giờ vẫn lấy được chữ gốc từng trang.
// Fixture: xem test/features/convert/tounicode_repair_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/pdf_tools/engine/compress_text_layer.dart';
import 'package:pdf_office/features/pdf_tools/engine/isolate_job.dart';

void main() {
  test('compressExtractTextJob đọc được chữ Việt từ PDF có CMap đích 5 chữ số', () async {
    final r = await runIsolateJob(compressExtractTextJob, {
      'input': 'test/fixtures/pdf/tounicode_5digit_bfrange.pdf',
      'password': null,
    });
    final pages = [
      for (final page in (r! as List))
        [for (final l in (page as List)) (l as List).cast<Object>()],
    ];
    expect(pages, hasLength(2));
    for (var p = 0; p < 2; p++) {
      final text = pages[p].map((l) => l[0] as String).join('\n');
      expect(text, contains('Xin chào thế giới ${p + 1}'), reason: 'trang ${p + 1}');
      expect(text, contains('Đọc to và dàn chữ ${p + 1}'), reason: 'trang ${p + 1}');
      for (final l in pages[p]) {
        expect((l[3] as num) > 0 && (l[4] as num) > 0, isTrue);
      }
    }
  });
}
