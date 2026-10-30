import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/qr/qr_content.dart';
import 'package:pdf_office/features/qr/qr_history.dart';

void main() {
  group('classifyQrContent', () {
    QrContentKind kind(String raw, [CodeFormat f = CodeFormat.qrCode]) =>
        classifyQrContent(raw, format: f).kind;

    test('URL http/https (không phân biệt hoa thường)', () {
      expect(kind('https://example.com/a?b=1'), QrContentKind.url);
      expect(kind('HTTP://EXAMPLE.COM'), QrContentKind.url);
    });

    test('scheme lạ không phải URL', () {
      expect(kind('javascript:alert(1)'), QrContentKind.text);
      expect(kind('file:///etc/passwd'), QrContentKind.text);
    });

    test('Wi‑Fi tách tên, kiểu bảo mật, mật khẩu', () {
      final c = classifyQrContent('WIFI:S:Nha Minh;T:WPA;P:matkhau123;;');
      expect(c.kind, QrContentKind.wifi);
      expect(c.wifi!.ssid, 'Nha Minh');
      expect(c.wifi!.security, 'WPA');
      expect(c.wifi!.password, 'matkhau123');
      expect(c.wifi!.hidden, isFalse);
    });

    test('Wi‑Fi: thứ tự tuỳ ý, ký tự thoát, mạng ẩn', () {
      final w = parseWifi(r'WIFI:T:WPA;P:a\;b\:c\\d;S:Cafe\,1;H:true;;')!;
      expect(w.ssid, 'Cafe,1');
      expect(w.password, r'a;b:c\d');
      expect(w.hidden, isTrue);
    });

    test('Wi‑Fi mạng mở và thiếu tên', () {
      final open = parseWifi('WIFI:S:Free;T:nopass;P:;;')!;
      expect(open.password, isNull);
      expect(parseWifi('WIFI:T:WPA;P:x;;'), isNull);
      expect(kind('WIFI:T:WPA;P:x;;'), QrContentKind.text);
    });

    test('tel:, mailto:, email trần, số điện thoại trần', () {
      expect(kind('tel:+84901234567'), QrContentKind.phone);
      expect(kind('mailto:a@b.com?subject=Hi'), QrContentKind.email);
      expect(kind('MATMSG:TO:a@b.com;SUB:x;;'), QrContentKind.email);
      expect(kind('a.b@example.vn'), QrContentKind.email);
      expect(kind('+84 90 123 4567'), QrContentKind.phone);
    });

    test('liên hệ, SMS, vị trí, sự kiện', () {
      expect(kind('BEGIN:VCARD\nFN:An\nEND:VCARD'), QrContentKind.contact);
      expect(kind('MECARD:N:An;TEL:090;;'), QrContentKind.contact);
      expect(kind('SMSTO:0901:hello'), QrContentKind.sms);
      expect(kind('geo:21.0,105.8'), QrContentKind.geo);
      expect(kind('BEGIN:VEVENT\nSUMMARY:x\nEND:VEVENT'), QrContentKind.event);
    });

    test('mã sản phẩm chỉ khi là EAN/UPC toàn số', () {
      expect(kind('8934567890123', CodeFormat.ean13), QrContentKind.product);
      expect(kind('12345', CodeFormat.code128), QrContentKind.text);
    });

    test('văn bản thường và chuỗi rỗng', () {
      expect(kind('Xin chào thế giới'), QrContentKind.text);
      expect(kind('   '), QrContentKind.text);
    });
  });

  group('qrOpenUri (quyết định hiện nút Mở)', () {
    Uri? open(String raw) => qrOpenUri(classifyQrContent(raw));

    test('http/https/mailto/tel được mở', () {
      expect(open('https://example.com'), Uri.parse('https://example.com'));
      expect(open('tel:+84901234567')?.scheme, 'tel');
      expect(open('mailto:a@b.com')?.scheme, 'mailto');
      expect(open('a@b.com'), Uri.parse('mailto:a@b.com'));
    });

    test('không mở Wi‑Fi, văn bản, số trần, scheme nguy hiểm, URL thiếu host', () {
      expect(open('WIFI:S:x;T:WPA;P:y;;'), isNull);
      expect(open('Xin chào'), isNull);
      expect(open('0901234567'), isNull);
      expect(open('javascript:alert(1)'), isNull);
      expect(open('intent://x#Intent;end'), isNull);
      expect(open('https://'), isNull);
      expect(open('https://exa mple.com'), isNull);
      expect(open('MATMSG:TO:a@b.com;;'), isNull);
    });
  });

  group('mergeQrHistory', () {
    const a = ScannedCode(format: CodeFormat.qrCode, raw: 'a');
    const b = ScannedCode(format: CodeFormat.qrCode, raw: 'b');
    const c = ScannedCode(format: CodeFormat.ean13, raw: '123');

    test('mới nhất lên đầu, mã trùng được đưa lên đầu', () {
      expect(mergeQrHistory([a, b], [b, c]), [b, c, a]);
    });

    test('cắt còn giới hạn', () {
      final old = [
        for (var i = 0; i < 25; i++)
          ScannedCode(format: CodeFormat.qrCode, raw: '$i'),
      ];
      final merged = mergeQrHistory(old, [a]);
      expect(merged.length, kQrHistoryLimit);
      expect(merged.first, a);
    });
  });
}
