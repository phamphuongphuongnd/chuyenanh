// Kiểm thử hộp trắng (agent A17) cho lib/src/xlsx/number_format.dart.
// Sinh từ Bước 5 (test-output/whitebox/office-reader/number_format/buoc-5-du-lieu-thu.md).
// Expected chép từ Bước 5 — KHÔNG chỉnh cho khớp code. Tên test bắt đầu bằng mã bộ.
import 'package:office_reader/src/xlsx/number_format.dart';
import 'package:test/test.dart';
Object? _run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

String f(num v, String code) => formatNumber(v.toDouble(), code);

void main() {
  group('Đơn vị 1 — builtInFormat', () {
    // Đường: D1S D2Đ D3Đ → R2
    test('1-1 id 28', () {
      final res = _run(() => builtInFormat(28));
      expect(res, 'yyyy-mm-dd');
    });
    // Đường: D1Đ → R1
    test('1-2 id 14', () {
      final res = _run(() => builtInFormat(14));
      expect(res, 'd/m/yyyy');
    });
    // Đường: D1S D2S D6S → R4
    test('1-3 id 26', () {
      final res = _run(() => builtInFormat(26));
      expect(res, 'General');
    });
    // Đường: D1S D2Đ D3S D4S D6Đ D7S → R4
    test('1-4 id 36', () {
      final res = _run(() => builtInFormat(36));
      expect(res, 'General');
    });
    // Đường: D1S D2Đ D3S D4Đ D5S D6Đ D7S → R4
    test('1-6 id 60', () {
      final res = _run(() => builtInFormat(60));
      expect(res, 'General');
    });
    // Đường: D1S D2Đ D3S D4S D6Đ D7Đ → R3
    test('1-7 id 33', () {
      final res = _run(() => builtInFormat(33));
      expect(res, 'h:mm:ss');
    });
    // Đường: D1S D2Đ D3S D4Đ D5Đ → R2
    test('1-8 id 55', () {
      final res = _run(() => builtInFormat(55));
      expect(res, 'yyyy-mm-dd');
    });
  });
  group('Đơn vị 2 — excelSerialToDate', () {
    // Đường: D1S D2S D3S → R1
    test('2-1 45000.75', () {
      final res = _run(() => excelSerialToDate(45000.75));
      expect(res, DateTime.utc(2023, 3, 15, 18));
    });
    // Đường: D1Đ → R1
    test('2-2 1.5, date1904', () {
      final res = _run(() => excelSerialToDate(1.5, date1904: true));
      expect(res, DateTime.utc(1904, 1, 2, 12));
    });
    // Đường: D1S D2Đ → R1
    test('2-3 1', () {
      final res = _run(() => excelSerialToDate(1));
      expect(res, DateTime.utc(1900, 1, 1));
    });
    // Đường: D1S D2S D3Đ → R2
    test('2-4 60.5', () {
      final res = _run(() => excelSerialToDate(60.5));
      expect(res, DateTime.utc(1900, 2, 28, 12));
    });
  });
  group('Đơn vị 3 — dateToExcelSerial', () {
    // Đường: D1S D2Đ D3S → R1
    test('3-1 2023-03-15 18:00', () {
      final res = _run(() => dateToExcelSerial(DateTime.utc(2023, 3, 15, 18)));
      expect(res, 45000.75);
    });
    // Đường: D1Đ D2S → R1
    test('3-2 1904-01-02 12:00, date1904', () {
      final res = _run(() => dateToExcelSerial(DateTime.utc(1904, 1, 2, 12), date1904: true));
      expect(res, 1.5);
    });
    // Đường: D1S D2Đ D3Đ → R1
    test('3-4 1900-01-01', () {
      final res = _run(() => dateToExcelSerial(DateTime.utc(1900, 1, 1)));
      expect(res, 1.0);
    });
  });
  group('Đơn vị 4 — _splitSections', () {
    // Đường: D1Đ D2S D4S D6S D7S D8S D10S D11S D12S D1S → R1
    test('4-1 f(-5, \'0;(0)\') — 2 section', () {
      final res = _run(() => f(-5, r'0;(0)'));
      expect(res, r'(5)');
    });
    // Đường: D1S → R1
    test('4-2 formatText(\'x\', \'\') — mã rỗng', () {
      final res = _run(() => formatText('x', ''));
      expect(res, 'x');
    });
    // Đường: D1Đ D2Đ D3S D1S → R1
    test('4-3 dấu ; trong ngoặc kép', () {
      final res = _run(() => f(5, r'"a;b"0'));
      expect(res, r'a;b5');
    });
    // Đường: D1Đ D2S D4Đ D5S D1S → R1
    test('4-4 ký tự trong [ ] (màu)', () {
      final res = _run(() => f(-5, r'[Red]0;[Blue]-0'));
      expect(res, r'-5');
    });
    // Đường: D1Đ D2S D4S D6Đ D9Đ D1S → R1
    test('4-5 escape \\; ở đầu… (lượt có \\)', () {
      final res = _run(() => f(5, r'0\;'));
      expect(res, r'5;');
    });
    // Đường: D1Đ D2S D4S D6S D7Đ D9Đ D1S → R1
    test('4-6 _; (chừa chỗ)', () {
      final res = _run(() => f(5, r'0_;'));
      expect(res, r'5 ');
    });
    // Đường: D1Đ D2S D4S D6S D7S D8Đ D9Đ D1S → R1
    test('4-7 *; (ký tự lấp đầy)', () {
      final res = _run(() => f(5, r'0*;'));
      expect(res, r'5');
    });
    // Đường: D1Đ D2S D4S D6S D7S D8S D10Đ D11S D12S D1S → R1
    test('4-8 mở ngoặc kép', () {
      final res = _run(() => f(5, r'"x"0'));
      expect(res, r'x5');
    });
    // Đường: D1Đ D2S D4S D6S D7S D8S D10S D11Đ D12S D1S → R1
    test('4-9 mở [ ]', () {
      final res = _run(() => f(5, r'[Red]0'));
      expect(res, r'5');
    });
    // Đường: D1Đ D2S D4S D6S D7S D8S D10S D11S D12Đ D1S → R1
    test('4-10 section dương rỗng', () {
      final res = _run(() => f(5, r';0'));
      expect(res, r'');
    });
    // Đường: D1Đ D2Đ D3Đ D1S → R1
    test('4-11 đóng ngoặc kép', () {
      final res = _run(() => f(5, r'"ab"0'));
      expect(res, r'ab5');
    });
    // Đường: D1Đ D2S D4Đ D5Đ D1S → R1
    test('4-12 đóng ]', () {
      final res = _run(() => f(5, r'[Blue]0'));
      expect(res, r'5');
    });
    // Đường: D1Đ D2S D4S D6Đ D9S D1S → R1
    test('4-13 \\ ở cuối mã', () {
      final res = _run(() => f(5, r'0\'));
      expect(res, r'5');
    });
  });
  group('Đơn vị 5 — _sections', () {
    // Đường: D1Đ → R1
    test('5-1 mã gặp lần đầu', () {
      final res = _run(() => f(1, r'0.0"u1"'));
      expect(res, r'1.0u1');
    });
    // Đường: D1S → R2
    test('5-2 gọi 2 lần cùng mã', () {
      final res = _run(() => (() { f(2, '0.0"u2"'); return f(2, '0.0"u2"'); })());
      expect(res, '2.0u2');
    });
  });
  group('Đơn vị 6 — isDateFormat', () {
    // Đường: D1Đ D2Đ → R2
    test('6-1 \'yyyy-mm-dd\'', () {
      final res = _run(() => isDateFormat('yyyy-mm-dd'));
      expect(res, isTrue);
    });
    // Đường: D1Đ D2S → R1
    test('6-3 \'0.00\'', () {
      final res = _run(() => isDateFormat('0.00'));
      expect(res, isFalse);
    });
  });
  group('Đơn vị 7 — _cond', () {
    // Đường: D1Đ → R1
    test('7-2 f(5, \'[<10]"small";"big"\')', () {
      final res = _run(() => f(5, r'[<10]"small";"big"'));
      expect(res, r'small');
    });
    // Đường: D1S D2Đ → R2
    test('7-3 f(10, \'[<=10]"a";"b"\')', () {
      final res = _run(() => f(10, r'[<=10]"a";"b"'));
      expect(res, r'a');
    });
    // Đường: D1S D2S D3Đ → R3
    test('7-4 f(11, \'[>10]"a";"b"\')', () {
      final res = _run(() => f(11, r'[>10]"a";"b"'));
      expect(res, r'a');
    });
    // Đường: D1S D2S D3S D4Đ → R4
    test('7-5 f(10, \'[>=10]"a";"b"\')', () {
      final res = _run(() => f(10, r'[>=10]"a";"b"'));
      expect(res, r'a');
    });
    // Đường: D1S D2S D3S D4S D5Đ → R5
    test('7-6 f(0, \'[=0]"zero";0\')', () {
      final res = _run(() => f(0, r'[=0]"zero";0'));
      expect(res, r'zero');
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ → R6
    test('7-7 f(3, \'[<>0]"nz";"z"\')', () {
      final res = _run(() => f(3, r'[<>0]"nz";"z"'));
      expect(res, r'nz');
    });
  });
  group('Đơn vị 8 — formatNumber', () {
    // Đường: D1S D2S D3S D4S D5S D10Đ D14S D15S → R6
    test('8-1 f(1234.5, \'0.0\')', () {
      final res = _run(() => f(1234.5, r'0.0'));
      expect(res, r'1234.5');
    });
    // Đường: D1Đ → R1
    test('8-2 NaN', () {
      final res = _run(() => formatNumber(double.nan, '0'));
      expect(res, '#NUM!');
    });
    // Đường: D1S D2Đ → R1
    test('8-3 Infinity', () {
      final res = _run(() => formatNumber(double.infinity, '0'));
      expect(res, '#NUM!');
    });
    // Đường: D1S D2S D3Đ D4S D5S D10Đ D14S D15S → R6
    test('8-4 mã rỗng ⇒ General', () {
      final res = _run(() => f(1.5, r''));
      expect(res, r'1.5');
    });
    // Đường: D1S D2S D3S D4Đ → R2
    test('8-5 số với mã \'@\'', () {
      final res = _run(() => f(5, r'@'));
      expect(res, r'5');
    });
    // Đường: D1S D2S D3S D4S D5Đ D6S D8S D14S D15S → R6
    test('8-6 f(5, \'[<10]"s";"b"\')', () {
      final res = _run(() => f(5, r'[<10]"s";"b"'));
      expect(res, r's');
    });
    // Đường: D1S D2S D3S D4S D5S D10S D11S D12S D13S D14S D15S → R6
    test('8-7 2 section, v = 0', () {
      final res = _run(() => f(0, r'0;-0'));
      expect(res, r'0');
    });
    // Đường: D1S D2S D3S D4S D5S D10Đ D14Đ → R3
    test('8-8 section chỉ có màu (không token)', () {
      final res = _run(() => f(5, r'[Red]'));
      expect(res, r'');
    });
    // Đường: D1S D2S D3S D4S D5S D10Đ D14S D15Đ D16S → R5
    test('8-9 f(45000.75, \'yyyy-mm-dd\')', () {
      final res = _run(() => f(45000.75, r'yyyy-mm-dd'));
      expect(res, r'2023-03-15');
    });
    // Đường: D1S D2S D3S D4S D5Đ D6Đ D7S D8S D14S D15S → R6
    test('8-10 section đầu không điều kiện, section 2 có điều kiện không khớp', () {
      final res = _run(() => f(5, r'0;[<-100]"x"'));
      expect(res, r'5');
    });
    // Đường: D1S D2S D3S D4S D5Đ D6S D8Đ D9S D14S D15S → R6
    test('8-11 điều kiện không khớp ⇒ section không điều kiện cuối', () {
      final res = _run(() => f(50, r'[<10]"s";"b"'));
      expect(res, r'b');
    });
    // Đường: D1S D2S D3S D4S D5S D10S D11Đ D14S D15S → R6
    test('8-12 f(5, \'0;(0)\')', () {
      final res = _run(() => f(5, r'0;(0)'));
      expect(res, r'5');
    });
    // Đường: D1S D2S D3S D4S D5S D10S D11S D12Đ D14S D15S → R6
    test('8-13 f(-5, \'0;(0)\')', () {
      final res = _run(() => f(-5, r'0;(0)'));
      expect(res, r'(5)');
    });
    // Đường: D1S D2S D3S D4S D5S D10S D11S D12S D13Đ D14S D15S → R6
    test('8-14 f(0, \'0;(0);"zero"\')', () {
      final res = _run(() => f(0, r'0;(0);"zero"'));
      expect(res, r'zero');
    });
    // Đường: D1S D2S D3S D4S D5S D10Đ D14S D15Đ D16Đ → R4
    test('8-15 f(-1, \'yyyy-mm-dd\') — ngày âm', () {
      final res = _run(() => f(-1, 'yyyy-mm-dd'));
      expect(res, isNot(contains('189')));
    });
    // Đường: D1S D2S D3S D4S D5Đ D6Đ D7Đ D8S D14S D15S → R6
    test('8-16 f(5, \'[<0]"neg";[>100]"big"\') — không section nào khớp', () {
      final res = _run(() => f(5, '[<0]"neg";[>100]"big"'));
      expect(res, isA<String>());
    });
    // Đường: D1S D2S D3S D4S D5Đ D6S D8Đ D9Đ D14S D15S → R6
    test('8-17 section 2 (điều kiện <0) với v âm ⇒ bỏ dấu trừ', () {
      final res = _run(() => f(-5, r'[>0]0;[<0]"neg "0'));
      expect(res, r'neg 5');
    });
  });
  group('Đơn vị 9 — formatNumber — điều kiện firstWhere (lambda)', () {
    // Đường: D1Đ D2S D3Đ → R1
    test('9-1 f(5, \'[<10]"s";"b"\')', () {
      final res = _run(() => f(5, r'[<10]"s";"b"'));
      expect(res, r's');
    });
    // Đường: D1S → R2
    test('9-2 section đầu không có điều kiện bị bỏ qua khi tìm', () {
      final res = _run(() => f(-5, r'0;[<-1]"n"'));
      expect(res, r'n');
    });
    // Đường: D1Đ D2Đ D3Đ → R1
    test('9-3 giá trị điều kiện "." (không parse được ⇒ 0)', () {
      final res = _run(() => f(-1, r'[<.]"a";"b"'));
      expect(res, endsWith('a'));
    });
    // Đường: D1Đ D2S D3S → R2
    test('9-4 f(50, \'[<10]"s";"b"\')', () {
      final res = _run(() => f(50, r'[<10]"s";"b"'));
      expect(res, r'b');
    });
  });
  group('Đơn vị 10 — formatText', () {
    // Đường: D1S D2Đ D3Đ D4S D5Đ → R2
    test('10-1 formatText(\'abc\', \'@\')', () {
      final res = _run(() => formatText('abc', '@'));
      expect(res, 'abc');
    });
    // Đường: D1Đ D4S D5Đ → R2
    test('10-2 formatText(\'abc\', \'0;0;0;@" !"\')', () {
      final res = _run(() => formatText('abc', '0;0;0;@" !"'));
      expect(res, 'abc !');
    });
    // Đường: D1S D2S D4S D5Đ → R2
    test('10-3 formatText(\'abc\', \'0;@\')', () {
      final res = _run(() => formatText('abc', '0;@'));
      expect(res, 'abc');
    });
    // Đường: D1S D2Đ D3S D4Đ → R1
    test('10-4 formatText(\'abc\', \'0.00\')', () {
      final res = _run(() => formatText('abc', '0.00'));
      expect(res, 'abc');
    });
    // Đường: D1S D2Đ D3Đ D4S D5S D6S → R2
    test('10-6 formatText(\'abc\', \'0;0;0;0@\')', () {
      final res = _run(() => formatText('abc', '0;0;0;0@'));
      expect(res, 'abc');
    });
    // Đường: D1S D2Đ D3Đ D4S D5S D6Đ → R2
    test('10-7 formatText(\'abc\', \'0;0;0;"<"@">"\')', () {
      final res = _run(() => formatText('abc', '0;0;0;"<"@">"'));
      expect(res, '<abc>');
    });
  });
  group('Đơn vị 11 — _round15', () {
    // Đường: D1S → R2
    test('11-1 f(1.005, \'0.00\')', () {
      final res = _run(() => f(1.005, r'0.00'));
      expect(res, r'1.01');
    });
    // Đường: D1Đ → R1
    test('11-2 f(0, \'0.00\')', () {
      final res = _run(() => f(0, r'0.00'));
      expect(res, r'0.00');
    });
  });
  group('Đơn vị 12 — _stripZeros', () {
    // Đường: D1S D2S → R2
    test('12-1 f(1.5, \'General\')', () {
      final res = _run(() => f(1.5, r'General'));
      expect(res, r'1.5');
    });
    // Đường: D1Đ → R1
    test('12-2 f(1234567890.5, \'General\')', () {
      final res = _run(() => f(1234567890.5, r'General'));
      expect(res, r'1234567891');
    });
    // Đường: D1S D2Đ → R2
    test('12-3 f(2.0000000001, \'General\')', () {
      final res = _run(() => f(2.0000000001, r'General'));
      expect(res, r'2');
    });
  });
  group('Đơn vị 13 — _general', () {
    // Đường: D1S D2S D3S D7Đ D8S → R2
    test('13-1 f(42, \'General\')', () {
      final res = _run(() => f(42, r'General'));
      expect(res, r'42');
    });
    // Đường: D1Đ → R1
    test('13-2 f(0, \'General\')', () {
      final res = _run(() => f(0, r'General'));
      expect(res, r'0');
    });
    // Đường: D1S D2Đ D4S D5S D6S D8S → R2
    test('13-3 f(123456789012, \'General\')', () {
      final res = _run(() => f(123456789012, r'General'));
      expect(res, r'1.23457E+11');
    });
    // Đường: D1S D2S D3Đ D4S D5S D6Đ D8S → R2
    test('13-4 f(1.23e-10, \'General\')', () {
      final res = _run(() => f(1.23e-10, r'General'));
      expect(res, r'1.23E-10');
    });
    // Đường: D1S D2S D3S D7S D8S → R2
    test('13-5 f(1234.56789012345, \'General\')', () {
      final res = _run(() => f(1234.56789012345, r'General'));
      expect(res, r'1234.56789');
    });
    // Đường: D1S D2S D3S D7Đ D8Đ D9Đ → R3
    test('13-6 f(-42, \'General\')', () {
      final res = _run(() => f(-42, r'General'));
      expect(res, r'-42');
    });
    // Đường: D1S D2Đ D4Đ D6S D8S → R2
    test('13-7 f(999999900000, \'General\')', () {
      final res = _run(() => f(999999900000, r'General'));
      expect(res, r'1E+12');
    });
    // Đường: D1S D2Đ D4S D5Đ D6S D8S → R2
    test('13-8 f(99999999999999.98, \'General\')', () {
      final res = _run(() => f(99999999999999.98, r'General'));
      expect(res, r'1E+14');
    });
    // Đường: D1S D2S D3S D7S D8S → R2 (bổ sung)
    test('13-b1 f(0.00001, \'General\')', () {
      final res = _run(() => f(0.00001, 'General'));
      expect(res, '1E-05');
    });
    // Đường: D1S D2S D3Đ D4S D5Đ D6Đ D8S → R2 (bổ sung)
    test('13-b2 f(9.99999999999999e-11, \'General\')', () {
      final res = _run(() => f(9.99999999999999e-11, 'General'));
      expect(res, '1E-10');
    });
  });
  group('Đơn vị 14 — _formatNum', () {
    // Đường: D1S D5Đ D5S D6S D8S D9S D10S → R3
    test('14-1 f(0.5, \'0%\')', () {
      final res = _run(() => f(0.5, r'0%'));
      expect(res, r'50%');
    });
    // Đường: D1Đ D2S D3S D4S → R1
    test('14-2 f(5, \'%General\') — token đầu không phải General/literal', () {
      final res = _run(() => f(5, '%General'));
      expect(res, contains('5'));
    });
    // Đường: D1S D5S D6S D8S D9S D10S → R3
    test('14-3 f(5, \'0\')', () {
      final res = _run(() => f(5, r'0'));
      expect(res, r'5');
    });
    // Đường: D1S D5Đ D5S D6Đ D7S → R2
    test('14-4 f(5, \'"-"\')', () {
      final res = _run(() => f(5, r'"-"'));
      expect(res, r'-');
    });
    // Đường: D1S D5Đ D5S D6S D8Đ D10S → R3
    test('14-5 f(12345, \'0.00E+00\')', () {
      final res = _run(() => f(12345, r'0.00E+00'));
      expect(res, r'1.23E+04');
    });
    // Đường: D1S D5Đ D5S D6S D8S D9Đ D10S → R3
    test('14-6 f(0.25, \'?/?\')', () {
      final res = _run(() => f(0.25, r'?/?'));
      expect(res, r'1/4');
    });
    // Đường: D1S D5Đ D5S D6S D8S D9S D10Đ D11Đ → R4
    test('14-7 f(-3, \'0\')', () {
      final res = _run(() => f(-3, r'0'));
      expect(res, r'-3');
    });
    // Đường: D1Đ D2Đ D3S D4S → R1
    test('14-8 f(1.5, \'General\')', () {
      final res = _run(() => f(1.5, r'General'));
      expect(res, r'1.5');
    });
    // Đường: D1Đ D2S D3Đ D4S → R1
    test('14-9 f(5, \'"x"General\')', () {
      final res = _run(() => f(5, r'"x"General'));
      expect(res, r'x5');
    });
    // Đường: D1Đ D2S D3S D4Đ → R1
    test('14-10 f(-1.5, \'General\')', () {
      final res = _run(() => f(-1.5, r'General'));
      expect(res, r'-1.5');
    });
    // Đường: D1S D5Đ D5S D6Đ D7Đ → R2
    test('14-11 f(-5, \'"-"\')', () {
      final res = _run(() => f(-5, r'"-"'));
      expect(res, r'--');
    });
    // Đường: D1S D5Đ D5S D6S D8S D9S D10Đ D11S → R3
    test('14-12 f(-0.001, \'0.00\')', () {
      final res = _run(() => f(-0.001, r'0.00'));
      expect(res, r'0.00');
    });
  });
  group('Đơn vị 15 — _fixed', () {
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-1 f(1.5, \'0.0\')', () {
      final res = _run(() => f(1.5, r'0.0'));
      expect(res, r'1.5');
    });
    // Đường: D1Đ D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13S D14S D15S D19S D24S D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-2 f(5, \'0\')', () {
      final res = _run(() => f(5, r'0'));
      expect(res, r'5');
    });
    // Đường: D1S D2Đ D3S D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-4 f(1.5, \'"\$"0.0\')', () {
      final res = _run(() => f(1.5, r'"$"0.0'));
      expect(res, r'$1.5');
    });
    // Đường: D1S D2Đ D3Đ D4S D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-5 lượt của chữ số sau dấu chấm', () {
      final res = _run(() => f(1.5, r'0.0'));
      expect(res, r'1.5');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6S D7Đ D8Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-7 dấu phẩy giữa chữ số nguyên ⇒ nhóm nghìn', () {
      final res = _run(() => f(1234.5, r'#,##0.0'));
      expect(res, r'1,234.5');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12Đ D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-8 dấu phẩy cuối ⇒ chia 1000', () {
      final res = _run(() => f(1500, r'0.0,'));
      expect(res, r'1.5');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13S D14S D15S D19S D24S D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-9 f(2, \'0.\')', () {
      final res = _run(() => f(2, r'0.'));
      expect(res, r'2.');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14Đ D15S D19S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-10 f(0.5, \'#.0\')', () {
      final res = _run(() => f(0.5, r'#.0'));
      expect(res, r'.5');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15Đ D16Đ D17S D18S D16S D19S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-11 f(5, \'##0.0\')', () {
      final res = _run(() => f(5, r'##0.0'));
      expect(res, r'5.0');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19Đ D20Đ D21Đ D22S D21S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-12 f(1234.5, \'#,##0.0\')', () {
      final res = _run(() => f(1234.5, r'#,##0.0'));
      expect(res, r'1,234.5');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25S D26S D27S D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-14 f(2, \'0.0\')', () {
      final res = _run(() => f(2, r'0.0'));
      expect(res, r'2.0');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29S D33S D35S D36S D28S → R1
    test('15-16 token đầu là dấu phẩy', () {
      final res = _run(() => f(1.5, r',0.0'));
      expect(res, r'1.5');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29Đ D30S D32Đ D28S → R1
    test('15-17 lượt chữ số thập phân', () {
      final res = _run(() => f(1.5, r'0.0'));
      expect(res, r'1.5');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29Đ D30Đ D31S D28S → R1
    test('15-18 lượt chữ số nguyên thứ 2 (phần nguyên đã ghi)', () {
      final res = _run(() => f(15, r'00.0'));
      expect(res, r'15.0');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6S D7S D9S D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-19 dấu phẩy không có chữ số trước', () {
      final res = _run(() => f(5, r',0'));
      expect(res, r'5');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6S D7Đ D8S D9Đ D10Đ D11Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-20 phẩy sau chữ số nguyên cuối ⇒ chia 1000 (1.5 ⇒ 2)', () {
      final res = _run(() => f(1500, r'0,'));
      expect(res, r'2');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15Đ D16Đ D17Đ D18S D16S D19S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-22 f(5, \'00.0\')', () {
      final res = _run(() => f(5, r'00.0'));
      expect(res, r'05.0');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15Đ D16Đ D17S D18Đ D16S D19S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-23 f(5, \'??.0\')', () {
      final res = _run(() => f(5, r'??.0'));
      expect(res, r' 5.0');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19Đ D20S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-24 nhóm nghìn nhưng phần nguyên rỗng', () {
      final res = _run(() => f(0.5, r'#,###.0'));
      expect(res, r'.5');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19Đ D20Đ D21Đ D22Đ D23S D21S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-26 lượt i ≥ 1 của vòng chèn dấu phẩy', () {
      final res = _run(() => f(12345, r'#,##0'));
      expect(res, r'12,345');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25S D26Đ D24S D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-27 f(1.5, \'0.0#\')', () {
      final res = _run(() => f(1.5, r'0.0#'));
      expect(res, r'1.5');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25S D26S D27Đ D24S D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-28 f(1.5, \'0.0?\')', () {
      final res = _run(() => f(1.5, r'0.0?'));
      expect(res, r'1.5 ');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29S D33Đ D34Đ D28S → R1
    test('15-29 token đầu là dấu chấm', () {
      final res = _run(() => f(0.5, r'.0'));
      expect(res, r'.5');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29S D33S D35Đ D28S → R1
    test('15-30 f(5, \'"Tổng: "0\')', () {
      final res = _run(() => f(5, r'"Tổng: "0'));
      expect(res, r'Tổng: 5');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29S D33S D35S D36Đ D28S → R1
    test('15-31 f(0.5, \'%0\')', () {
      final res = _run(() => f(0.5, r'%0'));
      expect(res, r'%50');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29Đ D30S D32S D28S → R1
    test('15-32 lượt chữ số thập phân thứ 2 (phần thập phân đã ghi)', () {
      final res = _run(() => f(1.25, r'0.00'));
      expect(res, r'1.25');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6S D7Đ D8S D9Đ D10S D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-34 phẩy sau chữ số thập phân, không có chữ số nguyên', () {
      final res = _run(() => f(1500, r'.0,'));
      expect(res, r'1.5');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19Đ D20Đ D21Đ D22Đ D23Đ D21S D24Đ D25Đ D28Đ D29Đ D30Đ D31Đ D28S → R1
    test('15-36 lượt vị trí chia hết cho 3 ⇒ chèn phẩy', () {
      final res = _run(() => f(1234, r'#,##0'));
      expect(res, r'1,234');
    });
    // Đường: D1S D2Đ D3Đ D4Đ D2S D5Đ D6Đ D5S D12S D13Đ D14S D15S D19S D24Đ D25Đ D28Đ D29S D33Đ D34S D28S → R1
    test('15-37 f(1.5, \'0..0\') — dấu chấm thứ 2', () {
      final res = _run(() => f(1.5, '0..0'));
      expect(res, contains('1'));
    });
    // Đường: D28 lượt có literal giữa các chữ số nguyên (D35Đ giữa D29Đ) (bổ sung)
    test('15-b1 f(123456789, \'000-00-0000\') — mã SSN', () {
      final res = _run(() => f(123456789, '000-00-0000'));
      expect(res, '123-45-6789');
    });
    // Đường: như trên (bổ sung)
    test('15-b2 f(1234567890, \'(000) 000-0000\') — số điện thoại', () {
      final res = _run(() => f(1234567890, '(000) 000-0000'));
      expect(res, '(123) 456-7890');
    });
  });
  group('Đơn vị 16 — _scientific', () {
    // Đường: D1S D2S D3Đ D4S D6S D9S D10Đ → R1
    test('16-1 f(12345, \'0.00E+00\')', () {
      final res = _run(() => f(12345, r'0.00E+00'));
      expect(res, r'1.23E+04');
    });
    // Đường: D1Đ D2Đ D3Đ D4S D6S D9S D10Đ → R1
    test('16-2 f(12345, \'0E+00\')', () {
      final res = _run(() => f(12345, r'0E+00'));
      expect(res, r'1E+04');
    });
    // Đường: D1S D2S D3S D9S D10Đ → R1
    test('16-4 f(0, \'0.00E+00\')', () {
      final res = _run(() => f(0, r'0.00E+00'));
      expect(res, r'0.00E+00');
    });
    // Đường: D1S D2S D3Đ D4Đ D5S D6S D9S D10Đ → R1
    test('16-5 f(12345, \'00.0E+0\') — 2 chữ số nguyên, không #', () {
      final res = _run(() => f(12345, '00.0E+0'));
      expect(res, matches(RegExp(r'^\d+\.\dE\+\d$')));
    });
    // Đường: D1S D2S D3Đ D4S D6Đ D7S D8S D9S D10Đ → R1
    test('16-6 f(99999, \'.00E+00\') — không có chữ số nguyên', () {
      final res = _run(() => f(99999, '.00E+00'));
      expect(res, contains('E+'));
    });
    // Đường: D1S D2S D3Đ D4S D6S D9Đ → R1
    test('16-7 f(0.00012, \'0.0E+0\')', () {
      final res = _run(() => f(0.00012, r'0.0E+0'));
      expect(res, r'1.2E-4');
    });
    // Đường: D1S D2S D3Đ D4S D6S D9S D10S → R1
    test('16-8 f(12345, \'0.00E-00\')', () {
      final res = _run(() => f(12345, r'0.00E-00'));
      expect(res, r'1.23E04');
    });
    // Đường: D1S D2S D3Đ D4Đ D5Đ D6S D9S D10Đ → R1
    test('16-9 f(12345, \'##0.0E+0\')', () {
      final res = _run(() => f(12345, r'##0.0E+0'));
      expect(res, r'12.3E+3');
    });
    // Đường: D1S D2S D3Đ D4S D6Đ D7Đ D8S D9S D10Đ → R1
    test('16-10 f(99999, \'0.00E+00\')', () {
      final res = _run(() => f(99999, r'0.00E+00'));
      expect(res, r'1.00E+05');
    });
    // Đường: D1S D2S D3Đ D4Đ D5Đ D6Đ D7S D8Đ D9S D10Đ → R1 (bổ sung)
    test('16-b1 f(999999, \'##0.0E+0\')', () {
      final res = _run(() => f(999999, '##0.0E+0'));
      expect(res, '1.0E+6');
    });
  });
  group('Đơn vị 17 — _fraction', () {
    // Đường: D1Đ D2Đ D3Đ D4S D6Đ D7Đ D6S D8Đ D9S D10Đ D11Đ D13Đ → R1
    test('17-1 f(1.5, \'# ?/?\')', () {
      final res = _run(() => f(1.5, r'# ?/?'));
      expect(res, r'1 1/2');
    });
    // Đường: D1S D3S D4S D6Đ D7Đ D6S D8S D10S D13Đ → R1
    test('17-2 f(0.25, \'?/?\')', () {
      final res = _run(() => f(0.25, r'?/?'));
      expect(res, r'1/4');
    });
    // Đường: D1Đ D2S D3S D4S D6Đ D7Đ D6S D8S D10S D13Đ → R1
    test('17-3 f(0.25, \'"x"?/?\')', () {
      final res = _run(() => f(0.25, r'"x"?/?'));
      expect(res, r'x1/4');
    });
    // Đường: D1Đ D2Đ D3Đ D4Đ D5Đ D8Đ D9S D10Đ D11Đ D13Đ → R1
    test('17-5 f(1.5, \'# ?/8\')', () {
      final res = _run(() => f(1.5, r'# ?/8'));
      expect(res, r'1 4/8');
    });
    // Đường: D1Đ D2Đ D3Đ D4S D6S D8Đ D9S D10Đ D11Đ D13Đ → R1
    test('17-6 f(1.5, \'# ?/\') — không có mẫu số', () {
      final res = _run(() => f(1.5, '# ?/'));
      expect(res, startsWith('1'));
    });
    // Đường: D1Đ D2Đ D3Đ D4S D6Đ D7S D6S D8Đ D9S D10Đ D11Đ D13Đ → R1
    test('17-7 lượt d không cải thiện sai số', () {
      final res = _run(() => f(1.5, r'# ?/?'));
      expect(res, r'1 1/2');
    });
    // Đường: D1Đ D2Đ D3Đ D4S D6Đ D7Đ D6S D8Đ D9Đ D10Đ D11Đ D13Đ → R1
    test('17-9 f(1.99, \'# ?/?\')', () {
      final res = _run(() => f(1.99, r'# ?/?'));
      expect(res, r'2');
    });
    // Đường: D1Đ D2Đ D3Đ D4S D6Đ D7Đ D6S D8Đ D9S D10Đ D11S D12S D13Đ → R1
    test('17-11 f(0.5, \'# ?/?\')', () {
      final res = _run(() => f(0.5, r'# ?/?'));
      expect(res, r'1/2');
    });
    // Đường: D1Đ D2Đ D3Đ D4S D6Đ D7Đ D6S D8Đ D9S D10Đ D11Đ D13S D14S → R1
    test('17-12 f(2, \'# ?/?\')', () {
      final res = _run(() => f(2, r'# ?/?'));
      expect(res, r'2');
    });
    // Đường: D1Đ D2Đ D3Đ D4Đ D5S D6Đ D7Đ D6S D8Đ D9S D10Đ D11Đ D13Đ → R1
    test('17-13 f(1.5, \'# ?/0\') — mẫu số 0', () {
      final res = _run(() => f(1.5, '# ?/0'));
      expect(res, startsWith('1'));
    });
    // Đường: D1Đ D2Đ D3Đ D4S D6Đ D7Đ D6S D8Đ D9S D10Đ D11S D12Đ D13Đ → R1
    test('17-14 f(0, \'# ?/?\')', () {
      final res = _run(() => f(0, r'# ?/?'));
      expect(res, r'0');
    });
    // Đường: D1S D3S D4S D6Đ D7Đ D6S D8S D10S D13S D14Đ → R1 (bổ sung)
    test('17-b1 f(0, \'?/?\')', () {
      final res = _run(() => f(0, '?/?'));
      expect(res, '0/1');
    });
  });
}
