// Dàn chữ / Đọc to với PDF có CMap ToUnicode lệch chuẩn (đích bfrange 5 chữ số hex, kiểu MuPDF):
// trước đây cả tài liệu thành CorruptFile; giờ CMap được sửa trong bộ nhớ và đọc được chữ Việt.
// Fixture: xem test/features/convert/tounicode_repair_test.dart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/reading/data/reflow_loader.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('reflow_tounicode_'));
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('PDF có CMap đích 5 chữ số → dàn chữ đủ 2 trang, đúng chữ Việt', () async {
    final f = File('${tmp.path}/mupdf.pdf')
      ..writeAsBytesSync(File('test/fixtures/pdf/tounicode_5digit_bfrange.pdf').readAsBytesSync());
    final doc = await loadReflowDocument(f.path, cacheDir: tmp);
    expect(doc.pageCount, 2);
    expect(doc.hasText, isTrue);
    for (var p = 0; p < 2; p++) {
      final text = doc.paragraphsOfPage(p).join('\n');
      expect(text, contains('Xin chào thế giới'), reason: 'trang ${p + 1}');
      expect(text, contains('Tiếng Việt có dấu: ắ ằ ẳ ẵ ặ ệ ữ ỹ'), reason: 'trang ${p + 1}');
      expect(text, contains('Đọc to và dàn chữ'), reason: 'trang ${p + 1}');
    }
  });
}
