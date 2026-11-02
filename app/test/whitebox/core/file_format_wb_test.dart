// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/utils/file_format.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/file_format/buoc-5-du-lieu-thu.md
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf_office/core/utils/file_format.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  group('U1 formatFileSize', () {
    test('1.1 512 B (vi) ⇒ "512 B"', () {
      expect(formatFileSize(512, 'vi'), '512 B');
    });
    test('1.2 số âm ⇒ "0 B"', () {
      expect(formatFileSize(-5, 'en'), '0 B');
    });
    test('1.3 2048 B (en) ⇒ "2.00 KB"', () {
      expect(formatFileSize(2048, 'en'), '2.00 KB');
    });
    test('1.4 4,35 MB (vi) ⇒ "4,35 MB"', () {
      expect(formatFileSize((4.35 * 1024 * 1024).round(), 'vi'), '4,35 MB');
    });
    test('1.5 1024^5 B ⇒ dừng ở TB: "1024.00 TB"', () {
      expect(formatFileSize(1024 * 1024 * 1024 * 1024 * 1024, 'en'), '1024.00 TB');
    });
  });

  group('U2 formatFileInfoLine', () {
    final now = DateTime(2026, 10, 29, 18, 0);
    test('2.1 cùng ngày, có thư mục ⇒ "2.00 KB • 07:23 • Download"', () {
      expect(
        formatFileInfoLine(2048, DateTime(2026, 10, 29, 7, 23), 'Download', 'en', now: now),
        '2.00 KB • 07:23 • Download',
      );
    });
    test('2.2 không truyền now, sửa lúc này ⇒ giờ HH:mm', () {
      final m = DateTime.now();
      expect(
        formatFileInfoLine(2048, m, 'Download', 'en'),
        '2.00 KB • ${DateFormat('HH:mm', 'en').format(m)} • Download',
      );
    });
    test('2.3 khác năm ⇒ ngày yMd (en: 10/29/2025)', () {
      expect(
        formatFileInfoLine(2048, DateTime(2025, 10, 29, 7, 23), 'Download', 'en', now: now),
        '2.00 KB • 10/29/2025 • Download',
      );
    });
    test('2.4 khác tháng ⇒ ngày yMd (en: 9/29/2026)', () {
      expect(
        formatFileInfoLine(2048, DateTime(2026, 9, 29, 7, 23), 'Download', 'en', now: now),
        '2.00 KB • 9/29/2026 • Download',
      );
    });
    test('2.5 khác ngày ⇒ ngày yMd (en: 10/28/2026)', () {
      expect(
        formatFileInfoLine(2048, DateTime(2026, 10, 28, 7, 23), 'Download', 'en', now: now),
        '2.00 KB • 10/28/2026 • Download',
      );
    });
    test('2.6 thư mục rỗng ⇒ bỏ phần thư mục', () {
      expect(
        formatFileInfoLine(2048, DateTime(2026, 10, 29, 7, 23), '', 'en', now: now),
        '2.00 KB • 07:23',
      );
    });
  });

  group('U3 _safeLocale (qua formatFileSize)', () {
    test('3.1 locale có (vi) ⇒ dấu thập phân ","', () {
      expect(formatFileSize(2048, 'vi'), '2,00 KB');
    });
    test('3.2 locale lạ (xx) ⇒ rơi về en "."', () {
      expect(formatFileSize(2048, 'xx'), '2.00 KB');
    });
  });
}
