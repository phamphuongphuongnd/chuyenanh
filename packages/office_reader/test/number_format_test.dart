import 'package:office_reader/src/xlsx/number_format.dart';
import 'package:test/test.dart';

void main() {
  String f(num v, String code) => formatNumber(v.toDouble(), code);

  group('numbers', () {
    test('general', () {
      expect(f(0, 'General'), '0');
      expect(f(-42, 'General'), '-42');
      expect(f(1e20, 'General'), '1E+20');
      expect(f(0.000000000123, 'General'), '1.23E-10');
      expect(f(123456789012, 'General'), '1.23457E+11');
    });
    test('placeholders, grouping, decimals', () {
      expect(f(1234567.891, '#,##0'), '1,234,568');
      expect(f(0.5, '#,##0.00'), '0.50');
      expect(f(5, '000'), '005');
      expect(f(1.5, '0.##'), '1.5');
      expect(f(2, '0.##'), '2.');
      expect(f(0.25, '#.00'), '.25');
      expect(f(1234567, '#,##0,"K"'), '1,235K');
    });
    test('sections, colors, literals, currency', () {
      expect(f(-5, '#,##0;[Red](#,##0)'), '(5)');
      expect(f(0, '0.00;-0.00;"zero"'), 'zero');
      expect(f(12.5, r'"$"#,##0.00'), r'$12.50');
      expect(f(12.5, r'[$€-x-euro2] #,##0.00'), '€ 12.50');
      expect(f(1000, r'#,##0 [$₫-42A]'), '1,000 ₫');
      expect(f(12, r'0_);\(0\)'), '12 ');
      expect(f(-3, '0'), '-3');
    });
    test('percent and scientific', () {
      expect(f(0.5, '0%'), '50%');
      expect(f(-0.123, '0.0%'), '-12.3%');
      expect(f(12345, '0.00E+00'), '1.23E+04');
      expect(f(0.00012, '0.0E+0'), '1.2E-4');
    });
    test('fractions', () {
      expect(f(1.5, '# ?/?'), '1 1/2');
      expect(f(0.25, '?/?'), '1/4');
      expect(f(2, '# ?/?'), '2');
      expect(f(0.3333, '# ??/??'), '1/3');
    });
  });

  group('dates', () {
    test('tokens', () {
      // 45000.75 = 2023-03-15 18:00 (Wednesday)
      expect(f(45000.75, 'dddd, mmmm d, yyyy'), 'Wednesday, March 15, 2023');
      expect(f(45000.75, 'ddd dd-mmm-yy'), 'Wed 15-Mar-23');
      expect(f(45000.75, 'h:mm AM/PM'), '6:00 PM');
      expect(f(45000.25, 'h:mm a/p'), '6:00 a');
      expect(f(45000.75, 'm/d/yyyy h:mm'), '3/15/2023 18:00');
      expect(f(45000.75, 'mmmmm'), 'M');
    });
    test('minutes vs months', () {
      expect(f(0.5 + 5 / 1440, 'hh:mm'), '12:05');
      expect(f(5 / 1440 + 7 / 86400, 'mm:ss'), '05:07');
    });
    test('elapsed time and fractional seconds', () {
      expect(f(1.5, '[h]:mm:ss'), '36:00:00');
      expect(f(1.25 / 86400, 'ss.00'), '01.25');
      expect(f(1 / 1440 * 90, '[mm]:ss'), '90:00');
    });
    test('rounds to the nearest second', () {
      expect(f(0.99999999, 'hh:mm:ss'), '00:00:00');
      expect(f(0.5 + 0.4 / 86400, 'hh:mm:ss'), '12:00:00');
    });
    test('isDateFormat', () {
      expect(isDateFormat('yyyy-mm-dd'), isTrue);
      expect(isDateFormat('[h]:mm'), isTrue);
      expect(isDateFormat('0.00'), isFalse);
      expect(isDateFormat('"d"0'), isFalse);
      expect(isDateFormat('[Red]0.0'), isFalse);
      expect(isDateFormat('General'), isFalse);
    });
    test('serial conversion', () {
      expect(excelSerialToDate(1), DateTime.utc(1900, 1, 1));
      expect(excelSerialToDate(59), DateTime.utc(1900, 2, 28));
      expect(excelSerialToDate(61), DateTime.utc(1900, 3, 1));
      expect(excelSerialToDate(0, date1904: true), DateTime.utc(1904, 1, 1));
    });
  });

  test('text section', () {
    expect(formatText('abc', '0;0;0;"<"@">"'), '<abc>');
    expect(formatText('abc', '0.00'), 'abc');
  });
}
