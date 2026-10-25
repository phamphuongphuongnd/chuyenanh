import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf_office/core/utils/file_format.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  group('formatFileSize', () {
    test('byte', () {
      expect(formatFileSize(0, 'en'), '0 B');
      expect(formatFileSize(512, 'vi'), '512 B');
      expect(formatFileSize(-5, 'en'), '0 B');
    });

    test('dấu thập phân theo locale', () {
      final bytes = (4.35 * 1024 * 1024).round();
      expect(formatFileSize(bytes, 'vi'), '4,35 MB');
      expect(formatFileSize(bytes, 'en'), '4.35 MB');
      expect(formatFileSize(1024, 'en'), '1.00 KB');
      expect(formatFileSize(1536 * 1024 * 1024, 'en'), '1.50 GB');
    });

    test('locale lạ rơi về en', () {
      expect(formatFileSize(2048, 'xx'), '2.00 KB');
    });
  });

  group('formatFileInfoLine', () {
    final size = (4.35 * 1024 * 1024).round();

    test('cùng ngày → giờ HH:mm', () {
      final modified = DateTime(2026, 10, 25, 7, 23);
      expect(
        formatFileInfoLine(
          size,
          modified,
          'Download',
          'vi',
          now: DateTime(2026, 10, 25, 20),
        ),
        '4,35 MB • 07:23 • Download',
      );
    });

    test('khác ngày → ngày theo locale', () {
      final modified = DateTime(2026, 10, 1, 7, 23);
      expect(
        formatFileInfoLine(
          size,
          modified,
          'Download',
          'en',
          now: DateTime(2026, 10, 25),
        ),
        '4.35 MB • 10/1/2026 • Download',
      );
    });

    test('bỏ folder rỗng', () {
      final m = DateTime(2026, 10, 25, 9, 5);
      expect(formatFileInfoLine(100, m, '', 'en', now: m), '100 B • 09:05');
    });
  });
}
