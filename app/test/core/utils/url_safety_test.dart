import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/core/utils/url_safety.dart';

void main() {
  group('safeLinkUri', () {
    test('cho phep http/https/mailto/tel', () {
      expect(isSafeLink('http://a.com'), isTrue);
      expect(isSafeLink('https://a.com/x?y=1#z'), isTrue);
      expect(isSafeLink('mailto:a@b.com'), isTrue);
      expect(isSafeLink('tel:+84123456789'), isTrue);
    });

    test('khong phan biet hoa thuong, cat khoang trang hai dau', () {
      expect(isSafeLink('HTTPS://A.com'), isTrue);
      expect(isSafeLink('MailTo:a@b.com'), isTrue);
      expect(isSafeLink('  https://a.com  '), isTrue);
      expect(safeLinkUri('  https://a.com\n').toString(), 'https://a.com');
    });

    test('chan scheme nguy hiem', () {
      for (final u in [
        'file:///sdcard/a.txt',
        'javascript:alert(1)',
        'JavaScript:alert(1)',
        'content://com.x/y',
        'intent://x#Intent;scheme=a;end',
        'data:text/html,hi',
        'ftp://a.com',
        'market://details?id=a',
      ]) {
        expect(isSafeLink(u), isFalse, reason: u);
      }
    });

    test('chan rong, null, thieu scheme, chuoi la', () {
      expect(isSafeLink(null), isFalse);
      expect(isSafeLink(''), isFalse);
      expect(isSafeLink('   '), isFalse);
      expect(isSafeLink('www.a.com'), isFalse);
      expect(isSafeLink('a.com/path'), isFalse);
      expect(isSafeLink('khong phai url'), isFalse);
      expect(isSafeLink('https://'), isFalse);
      expect(isSafeLink('mailto:'), isFalse);
      expect(isSafeLink('java script:x'), isFalse);
      expect(isSafeLink('https://a.com/ b'), isFalse);
      expect(isSafeLink('https://a.com\n/b'), isFalse);
    });
  });
}
