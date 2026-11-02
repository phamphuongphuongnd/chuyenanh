// Kiểm thử hộp trắng A13 — app/lib/features/qr/qr_content.dart
// Thiết kế: test-output/whitebox/qr/qr_content/buoc-1..5. Expected chép từ Bước 5.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/qr/qr_content.dart';

QrContentKind _k(String s, [CodeFormat f = CodeFormat.qrCode]) => classifyQrContent(s, format: f).kind;
QrContent _c(QrContentKind k, String raw) => QrContent(kind: k, raw: raw);

void main() {
  group('U1 isProduct', () {
    for (final (id, f) in [('1-1', CodeFormat.ean13), ('1-2', CodeFormat.ean8), ('1-3', CodeFormat.upca), ('1-4', CodeFormat.upce)]) {
      test('$id ${f.name} ⇒ true', () => expect(f.isProduct, isTrue));
    }
    test('1-5 qrCode ⇒ false', () => expect(CodeFormat.qrCode.isProduct, isFalse));
  });

  group('U2 fromName', () {
    test('2-1 tên có ⇒ đúng loại', () => expect(CodeFormat.fromName('ean8'), CodeFormat.ean8));
    test('2-2 tên lạ / null ⇒ unknown', () {
      expect(CodeFormat.fromName('xx'), CodeFormat.unknown);
      expect(CodeFormat.fromName(null), CodeFormat.unknown);
    });
  });

  group('U3 ScannedCode.==', () {
    const a = ScannedCode(format: CodeFormat.qrCode, raw: 'a');
    test('3-1 bằng', () => expect(a == const ScannedCode(format: CodeFormat.qrCode, raw: 'a'), isTrue));
    test('3-2 khác kiểu', () => expect(a == ('a' as Object), isFalse));
    test('3-3 khác format', () => expect(a == const ScannedCode(format: CodeFormat.ean13, raw: 'a'), isFalse));
    test('3-4 khác raw', () => expect(a == const ScannedCode(format: CodeFormat.qrCode, raw: 'b'), isFalse));
  });

  group('U4 _startsWithIgnoreCase (qua classify)', () {
    test('4-1 wifi: thường ⇒ wifi', () => expect(_k('wifi:S:n;;'), QrContentKind.wifi));
    test('4-2 WIFX: ⇒ text', () => expect(_k('WIFX:S:n;;'), QrContentKind.text));
    test('4-3 chuỗi ngắn WIF ⇒ text', () => expect(_k('WIF'), QrContentKind.text));
  });

  group('U5 classifyQrContent', () {
    final cases = <(String, String, CodeFormat, QrContentKind)>[
      ('5-1', 'hello', CodeFormat.qrCode, QrContentKind.text),
      ('5-2', '   ', CodeFormat.qrCode, QrContentKind.text),
      ('5-3', '8934567890123', CodeFormat.ean13, QrContentKind.product),
      ('5-4', 'ABC', CodeFormat.ean13, QrContentKind.text),
      ('5-6', 'WIFI:;;', CodeFormat.qrCode, QrContentKind.text),
      ('5-7', 'http://a.b', CodeFormat.qrCode, QrContentKind.url),
      ('5-8', 'HTTPS://A.B', CodeFormat.qrCode, QrContentKind.url),
      ('5-9', 'BEGIN:VCARD\nFN:A\nEND:VCARD', CodeFormat.qrCode, QrContentKind.contact),
      ('5-10', 'MECARD:N:A;;', CodeFormat.qrCode, QrContentKind.contact),
      ('5-11', 'BEGIN:VEVENT\nEND:VEVENT', CodeFormat.qrCode, QrContentKind.event),
      ('5-12', 'BEGIN:VCALENDAR\nEND:VCALENDAR', CodeFormat.qrCode, QrContentKind.event),
      ('5-13', 'mailto:a@b.co', CodeFormat.qrCode, QrContentKind.email),
      ('5-14', 'MATMSG:TO:a@b.co;;', CodeFormat.qrCode, QrContentKind.email),
      ('5-15', 'a@b.co', CodeFormat.qrCode, QrContentKind.email),
      ('5-16', 'tel:+84 1', CodeFormat.qrCode, QrContentKind.phone),
      ('5-17', 'SMSTO:123:hi', CodeFormat.qrCode, QrContentKind.sms),
      ('5-18', 'sms:123', CodeFormat.qrCode, QrContentKind.sms),
      ('5-19', 'geo:1,2', CodeFormat.qrCode, QrContentKind.geo),
      ('5-20', '0912 345 678', CodeFormat.qrCode, QrContentKind.phone),
      ('5-21', '------', CodeFormat.qrCode, QrContentKind.text),
    ];
    for (final (id, s, f, k) in cases) {
      test('$id ${s.replaceAll('\n', ' ')} ⇒ ${k.name}', () => expect(_k(s, f), k));
    }
    test('5-5 Wi-Fi hợp lệ ⇒ wifi kèm ssid', () {
      final c = classifyQrContent('WIFI:S:net;T:WPA;P:pw;;');
      expect(c.kind, QrContentKind.wifi);
      expect(c.wifi?.ssid, 'net');
    });
  });

  group('U6 parseWifi', () {
    test('6-1 đủ trường', () {
      final w = parseWifi('WIFI:S:net;T:WPA;P:pw;H:true;;')!;
      expect([w.ssid, w.password, w.security, w.hidden], ['net', 'pw', 'WPA', true]);
    });
    test('6-2 không phải WIFI ⇒ null', () => expect(parseWifi('hello'), isNull));
    test('6-3 ký tự thoát', () => expect(parseWifi(r'WIFI:S:a\;b;;')?.ssid, 'a;b'));
    test('6-4 thiếu S ⇒ null', () => expect(parseWifi('WIFI:T:WPA;P:x;;'), isNull));
    test('6-5 S rỗng trong ngoặc kép ⇒ null', () => expect(parseWifi('WIFI:S:"";;'), isNull));
    test('6-6 thiếu P ⇒ password null', () => expect(parseWifi('WIFI:S:n;;')!.password, isNull));
    test('6-7 P rỗng ⇒ password null', () => expect(parseWifi('WIFI:S:n;P:;;')!.password, isNull));
    test('6-8 thiếu T ⇒ security null', () => expect(parseWifi('WIFI:S:n;;')!.security, isNull));
    test('6-9 T rỗng ⇒ security null', () => expect(parseWifi('WIFI:S:n;T:;;')!.security, isNull));
    test('6-10 thiếu H ⇒ hidden false', () => expect(parseWifi('WIFI:S:n;;')!.hidden, isFalse));
    test('6-11 H:TRUE ⇒ hidden true', () => expect(parseWifi('WIFI:S:n;H:TRUE;;')!.hidden, isTrue));
    test('6-12 thân rỗng ⇒ null', () => expect(parseWifi('WIFI:'), isNull));
    test('6-13 trường cuối không có ;', () {
      final w = parseWifi('WIFI:P:x;S:net')!;
      expect([w.ssid, w.password], ['net', 'x']);
    });
  });

  group('U7 flush', () {
    test('7-1 đoạn có khoá', () => expect(parseWifi('WIFI:S:x;;')?.ssid, 'x'));
    test('7-2 đoạn không khoá bị bỏ', () => expect(parseWifi('WIFI:junk;:y;S:x;;')?.ssid, 'x'));
  });

  group('U8 _unescapedColon', () {
    test('8-1 có dấu :', () => expect(parseWifi('WIFI:S:x;;')?.ssid, 'x'));
    test('8-2 đoạn rỗng', () => expect(parseWifi('WIFI:;S:x;;')?.ssid, 'x'));
    test('8-3 khoá chứa \\:', () => expect(parseWifi(r'WIFI:A\:B:1;S:x;;')?.ssid, 'x'));
    test('8-4 không có :', () => expect(parseWifi('WIFI:abc;S:x;;')?.ssid, 'x'));
  });

  group('U9 _unescape', () {
    test('9-1 không thoát', () => expect(parseWifi('WIFI:S:abc;;')?.ssid, 'abc'));
    test('9-2 giá trị rỗng', () => expect(parseWifi('WIFI:S:x;P:;;')?.password, isNull));
    test('9-3 có \\;', () => expect(parseWifi(r'WIFI:S:a\;b;;')?.ssid, 'a;b'));
  });

  group('U10 _stripQuotes', () {
    test('10-1 "ab" ⇒ ab', () => expect(parseWifi('WIFI:S:"ab";;')?.ssid, 'ab'));
    test('10-2 a ⇒ a', () => expect(parseWifi('WIFI:S:a;;')?.ssid, 'a'));
    test('10-3 ab" giữ nguyên', () => expect(parseWifi('WIFI:S:ab";;')?.ssid, 'ab"'));
    test('10-4 "ab giữ nguyên', () => expect(parseWifi('WIFI:S:"ab;;')?.ssid, '"ab'));
  });

  group('U11 qrOpenUri', () {
    test('11-1 url ⇒ Uri', () => expect(qrOpenUri(_c(QrContentKind.url, 'https://a.b/x')), Uri.parse('https://a.b/x')));
    test('11-2 tel: ⇒ Uri', () => expect(qrOpenUri(_c(QrContentKind.phone, 'tel:+841')), Uri.parse('tel:+841')));
    test('11-3 số trần ⇒ null', () => expect(qrOpenUri(_c(QrContentKind.phone, '0912345678')), isNull));
    test('11-4 mailto ⇒ Uri', () => expect(qrOpenUri(_c(QrContentKind.email, 'mailto:a@b.co')), Uri.parse('mailto:a@b.co')));
    test('11-5 email trần ⇒ mailto:', () => expect(qrOpenUri(_c(QrContentKind.email, 'a@b.co')), Uri.parse('mailto:a@b.co')));
    test('11-6 MATMSG ⇒ null', () => expect(qrOpenUri(_c(QrContentKind.email, 'MATMSG:TO:a@b.co;;')), isNull));
    test('11-7 loại khác ⇒ null', () {
      for (final k in [QrContentKind.text, QrContentKind.wifi, QrContentKind.geo, QrContentKind.sms, QrContentKind.contact]) {
        expect(qrOpenUri(_c(k, 'https://a.b')), isNull, reason: k.name);
      }
    });
    test('11-S scheme nguy hiểm / URL hỏng ⇒ null', () {
      for (final s in [
        'javascript:alert(1)',
        'intent://x#Intent;end',
        'file:///sdcard/a.pdf',
        'content://x/y',
        'https:///x',
        'https://a.b\nc',
        'http://a b',
      ]) {
        expect(qrOpenUri(_c(QrContentKind.url, s)), isNull, reason: s);
      }
      expect(qrOpenUri(_c(QrContentKind.phone, 'tel:')), isNull);
      expect(qrOpenUri(_c(QrContentKind.email, 'mailto:')), isNull);
    });
    test('11-S2 qua classify: scheme lạ không thành url ⇒ null', () {
      for (final s in ['javascript:alert(1)', 'JAVASCRIPT://x', 'data:text/html,x', 'market://details?id=x']) {
        final c = classifyQrContent(s);
        expect(c.kind, isNot(QrContentKind.url), reason: s);
        expect(qrOpenUri(c), isNull, reason: s);
      }
    });
  });
}
