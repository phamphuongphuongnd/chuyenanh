// Kiểm thử hộp trắng (A10, chủ đề core) — lib/core/utils/url_safety.dart.
// Bộ dữ liệu + kết quả mong đợi: test-output/whitebox/core/url_safety/buoc-5-du-lieu-thu.md
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/utils/url_safety.dart';

void main() {
  group('U1 safeLinkUri — đường cơ sở', () {
    const allowed = <(String, String)>[
      ('1.1', 'https://a.com/x'),
      ('1.8', 'http://a.com'),
      ('1.10', 'mailto:a@b.com'),
      ('1.11', 'tel:+84123456789'),
    ];
    for (final (code, url) in allowed) {
      test('$code "$url" ⇒ cho mở (trả Uri)', () {
        final u = safeLinkUri(url);
        expect(u, isNotNull);
        expect(u.toString(), url);
        expect(isSafeLink(url), isTrue);
      });
    }

    const blocked = <(String, String?, String)>[
      ('1.2', null, 'null'),
      ('1.3', '   ', 'rỗng sau trim'),
      ('1.4', 'https://a.com/ b', 'khoảng trắng bên trong'),
      ('1.5', 'https://a.com:xx', 'Uri không parse được (cổng sai)'),
      ('1.6', 'www.a.com', 'thiếu scheme'),
      ('1.7', 'javascript:alert(1)', 'scheme ngoài danh sách'),
      ('1.9', 'https:a.com', 'https không có host'),
      ('1.12', 'mailto:', 'mailto rỗng'),
      ('1.13', 'tel:', 'tel rỗng'),
    ];
    for (final (code, url, why) in blocked) {
      test('$code ${url == null ? 'null' : '"$url"'} ($why) ⇒ chặn (null)', () {
        expect(safeLinkUri(url), isNull);
        expect(isSafeLink(url), isFalse);
      });
    }
  });

  group('U1 safeLinkUri — bộ bảo mật bổ sung', () {
    const blocked = <(String, String)>[
      ('S1', 'file:///data/data/com.phuong.pdfoffice/databases/pdf_office.sqlite'),
      ('S2', 'content://com.android.providers.downloads/1'),
      ('S3', 'intent://scan/#Intent;scheme=zxing;package=com.x;end'),
      ('S4', 'JAVASCRIPT:alert(1)'),
      ('S5', 'java\tscript:alert(1)'),
      ('S6', 'data:text/html;base64,PHNjcmlwdD4='),
      ('S7', 'http:/evil.com'),
      ('S8', 'https://a.com\u0000.evil'),
      ('S9', 'sms:+84123'),
      ('S10', 'vbscript:msgbox(1)'),
    ];
    for (final (code, url) in blocked) {
      test('$code ${url.replaceAll(RegExp(r'[\x00-\x1f]'), '?')} ⇒ chặn', () {
        expect(safeLinkUri(url), isNull);
      });
    }
  });
}
