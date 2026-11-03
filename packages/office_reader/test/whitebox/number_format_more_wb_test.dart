// Kiểm thử hộp trắng (agent A17, lượt bổ sung A17b) cho lib/src/xlsx/number_format.dart.
// Sinh từ Bước 5 (test-output/whitebox/office-reader/number_format/buoc-5-du-lieu-thu.md).
// Expected chép từ Bước 5 — KHÔNG chỉnh cho khớp code. Tên test bắt đầu bằng mã bộ.
import 'package:office_reader/office_reader.dart';
import 'package:office_reader/src/xlsx/number_format.dart';
import 'package:test/test.dart';

import '../helpers/ooxml.dart';
Object? _run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

String f(num v, String code) => formatNumber(v.toDouble(), code);

/// Serial Excel của ngày [d] (serial nguyên) lúc h:m:s.ms.
double t(int d, int h, int m, int s, [int ms = 0]) =>
    d + (h * 3600 + m * 60 + s + ms / 1000) / 86400;

/// Ô chuỗi inline với numFmt tuỳ chọn, đọc qua readXlsx.
String strCell(String code) {
  final wb = readXlsx(buildXlsx(
    sheets: [SheetSpec('S', '<sheetData><row r="1"><c r="A1" s="1" t="inlineStr"><is><t>x</t></is></c></row></sheetData>')],
    styles: '<numFmts count="1"><numFmt numFmtId="164" formatCode="${code.replaceAll('"', '&quot;')}"/></numFmts><cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="164"/></cellXfs>',
  ));
  return wb.sheets.single.cell(0, 0)!.display;
}

void main() {
  group('Đơn vị 18 — _parseSection — lượt 1 (nhận dạng ngày)', () {
    // Đường: P1Đ P2S P4S P5S P6S P7S P8S P11S P12S P13S P15S P16S P1S → R1
    test('18-1 isDateFormat(\'0\')', () {
      final res = _run(() => isDateFormat(r'0'));
      expect(res, false);
    });
    // Đường: P1S → R1
    test('18-2 isDateFormat(\'\')', () {
      final res = _run(() => isDateFormat(r''));
      expect(res, false);
    });
    // Đường: P1Đ P2Đ P3S P1S → R1
    test('18-3 isDateFormat(\'"d"0\')', () {
      final res = _run(() => isDateFormat(r'"d"0'));
      expect(res, false);
    });
    // Đường: P1Đ P2S P4Đ P1S → R1
    test('18-4 isDateFormat(\'"y"\')', () {
      final res = _run(() => isDateFormat(r'"y"'));
      expect(res, false);
    });
    // Đường: P1Đ P2S P4S P5Đ P1S → R1
    test('18-5 isDateFormat(\'\\d0\')', () {
      final res = _run(() => isDateFormat(r'\d0'));
      expect(res, false);
    });
    // Đường: P1Đ P2S P4S P5S P6Đ P1S → R1
    test('18-6 isDateFormat(\'_d0\')', () {
      final res = _run(() => isDateFormat(r'_d0'));
      expect(res, false);
    });
    // Đường: P1Đ P2S P4S P5S P6S P7Đ P1S → R1
    test('18-7 isDateFormat(\'*d0\')', () {
      final res = _run(() => isDateFormat(r'*d0'));
      expect(res, false);
    });
    // Đường: P1Đ P2S P4S P5S P6S P7S P8Đ P9S P10S P1S → R1
    test('18-8 isDateFormat(\'[Red]0\')', () {
      final res = _run(() => isDateFormat(r'[Red]0'));
      expect(res, false);
    });
    // Đường: P1Đ P2S P4S P5S P6S P7S P8S P11Đ P1S → R1
    test('18-9 isDateFormat(\'d\')', () {
      final res = _run(() => isDateFormat(r'd'));
      expect(res, true);
    });
    // Đường: P1Đ P2S P4S P5S P6S P7S P8S P11S P12Đ P14S P1S → R1
    test('18-10 isDateFormat(\'G0\')', () {
      final res = _run(() => isDateFormat(r'G0'));
      expect(res, false);
    });
    // Đường: P1Đ P2S P4S P5S P6S P7S P8S P11S P12S P13Đ P14S P1S → R1
    test('18-11 isDateFormat(\'g0\')', () {
      final res = _run(() => isDateFormat(r'g0'));
      expect(res, false);
    });
    // Đường: P1Đ P2S P4S P5S P6S P7S P8S P11S P12S P13S P15Đ P1S → R1
    test('18-12 isDateFormat(\'0E+0\')', () {
      final res = _run(() => isDateFormat(r'0E+0'));
      expect(res, false);
    });
    // Đường: P1Đ P2S P4S P5S P6S P7S P8S P11S P12S P13S P15S P16Đ P1S → R1
    test('18-13 isDateFormat(\'0e+0\')', () {
      final res = _run(() => isDateFormat(r'0e+0'));
      expect(res, false);
    });
    // Đường: P1Đ P2Đ P3Đ P1S → R1
    test('18-14 isDateFormat(\'"x"d\')', () {
      final res = _run(() => isDateFormat(r'"x"d'));
      expect(res, true);
    });
    // Đường: P1Đ P2S P4S P5S P6S P7S P8Đ P9Đ → R1
    test('18-15 isDateFormat(\'[d\')', () {
      final res = _run(() => isDateFormat(r'[d'));
      expect(res, false);
    });
    // Đường: P1Đ P2S P4S P5S P6S P7S P8Đ P9S P10Đ P1S → R1
    test('18-16 isDateFormat(\'[h]\')', () {
      final res = _run(() => isDateFormat(r'[h]'));
      expect(res, true);
    });
    // Đường: P1Đ P2S P4S P5S P6S P7S P8S P11S P12Đ P14Đ P1S → R1
    test('18-17 isDateFormat(\'General\')', () {
      final res = _run(() => isDateFormat(r'General'));
      expect(res, false);
    });
  });
  group('Đơn vị 19 — _parseSection — lượt 2 (tách token)', () {
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34S Q35S Q36S Q37S Q38S Q39S Q40S Q44S Q1S → R1
    test('19-1 formatNumber(5, \'0-\')', () {
      final res = _run(() => f(5, r'0-'));
      expect(res, r'5-');
    });
    // Đường: Q1S → R1
    test('19-2 formatNumber(0, \'0;;\') — section thứ 3 (số 0) rỗng', () {
      final res = _run(() => f(0, r'0;;'));
      expect(res, r'');
    });
    // Đường: Q1Đ Q2Đ Q3S Q1S → R1
    test('19-3 formatNumber(5, \'0" kg"\')', () {
      final res = _run(() => f(5, r'0" kg"'));
      expect(res, r'5 kg');
    });
    // Đường: Q1Đ Q2S Q4Đ Q5Đ Q1S → R1
    test('19-4 formatNumber(5, \'0\\k\')', () {
      final res = _run(() => f(5, r'0\k'));
      expect(res, r'5k');
    });
    // Đường: Q1Đ Q2S Q4S Q6Đ Q1S → R1
    test('19-5 formatNumber(5, \'0_)\')', () {
      final res = _run(() => f(5, r'0_)'));
      expect(res, r'5 ');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7Đ Q1S → R1
    test('19-6 formatNumber(5, \'0*-\')', () {
      final res = _run(() => f(5, r'0*-'));
      expect(res, r'5');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8Đ Q9S Q10S Q11S Q14S Q1S → R1
    test('19-7 formatNumber(5, \'[Red]0\')', () {
      final res = _run(() => f(5, r'[Red]0'));
      expect(res, r'5');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15Đ Q1S → R1
    test('19-8 formatNumber(1.5, \'general\')', () {
      final res = _run(() => f(1.5, r'general'));
      expect(res, r'1.5');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18S Q19S Q22S Q30S Q1S → R1
    test('19-9 formatNumber(15/03/2023 13:05:09, \'d-m\')', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'd-m'));
      expect(res, r'15-3');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31Đ Q1S → R1
    test('19-10 formatNumber(5, \'0\')', () {
      final res = _run(() => f(5, r'0'));
      expect(res, r'5');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32Đ Q1S → R1
    test('19-11 formatNumber(5, \'#\')', () {
      final res = _run(() => f(5, r'#'));
      expect(res, r'5');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33Đ Q1S → R1
    test('19-12 formatNumber(5, \'?\')', () {
      final res = _run(() => f(5, r'?'));
      expect(res, r'5');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34Đ Q1S → R1
    test('19-13 formatNumber(5, \'0.0\')', () {
      final res = _run(() => f(5, r'0.0'));
      expect(res, r'5.0');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34S Q35Đ Q1S → R1
    test('19-14 formatNumber(1234, \'#,##0\')', () {
      final res = _run(() => f(1234, r'#,##0'));
      expect(res, r'1,234');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34S Q35S Q36Đ Q1S → R1
    test('19-15 formatNumber(0.5, \'0%\')', () {
      final res = _run(() => f(0.5, r'0%'));
      expect(res, r'50%');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34S Q35S Q36S Q37Đ Q1S → R1
    test('19-16 formatNumber(1.5, \'# ?/?\')', () {
      final res = _run(() => f(1.5, r'# ?/?'));
      expect(res, r'1 1/2');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34S Q35S Q36S Q37S Q38Đ Q1S → R1
    test('19-17 formatText(\'x\', \'"a"@\')', () {
      final res = _run(() => formatText('x', r'"a"@'));
      expect(res, 'ax');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34S Q35S Q36S Q37S Q38S Q39Đ Q41Đ Q42S Q43S Q1S → R1
    test('19-18 formatNumber(5, \'0E \')', () {
      final res = _run(() => f(5, r'0E '));
      expect(res, r'5E ');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34S Q35S Q36S Q37S Q38S Q39S Q40Đ Q41Đ Q42S Q43S Q1S → R1
    test('19-19 formatNumber(5, \'0e \')', () {
      final res = _run(() => f(5, r'0e '));
      expect(res, r'5e ');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34S Q35S Q36S Q37S Q38S Q39S Q40S Q44Đ Q45Đ Q46S Q1S → R1
    test('19-20 formatNumber(5, \'0 1\')', () {
      final res = _run(() => f(5, r'0 1'));
      expect(res, r'5 1');
    });
    // Đường: Q1Đ Q2Đ Q3Đ Q1S → R1
    test('19-21 formatNumber(5, \'0"kg\')', () {
      final res = _run(() => f(5, r'0"kg'));
      expect(res, r'5kg');
    });
    // Đường: Q1Đ Q2S Q4Đ Q5S Q1S → R1
    test('19-22 formatNumber(5, \'0\\\')', () {
      final res = _run(() => f(5, r'0\'));
      expect(res, r'5');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8Đ Q9Đ Q10S Q11S Q14S Q1S → R1
    test('19-23 formatNumber(5, \'0[Red\')', () {
      final res = _run(() => f(5, r'0[Red'));
      expect(res, r'5');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8Đ Q9S Q10Đ Q1S → R1
    test('19-24 formatNumber(20, \'[>10]"big";0\')', () {
      final res = _run(() => f(20, r'[>10]"big";0'));
      expect(res, r'big');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8Đ Q9S Q10S Q11Đ Q12S Q13Đ Q1S → R1
    test('19-25 formatNumber(5, \'[\$€-407]0\')', () {
      final res = _run(() => f(5, r'[$€-407]0'));
      expect(res, r'€5');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8Đ Q9S Q10S Q11S Q14Đ Q1S → R1
    test('19-26 formatNumber(1 ngày 1:05, \'[H]:mm\')', () {
      final res = _run(() => f(t(1, 1, 5, 0), r'[H]:mm'));
      expect(res, r'25:05');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17Đ Q1S → R1
    test('19-27 13:05:09, \'h AM/PM\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h AM/PM'));
      expect(res, r'1 PM');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18Đ Q1S → R1
    test('19-28 13:05:09, \'h A/P\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h A/P'));
      expect(res, r'1 P');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18S Q19Đ Q20Đ Q21Đ Q20S Q1S → R1
    test('19-29 15/03/2023, \'yy\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'yy'));
      expect(res, r'23');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18S Q19S Q22Đ Q23Đ Q24Đ Q25Đ Q26Đ Q27Đ Q28Đ Q29Đ Q28S Q1S → R1
    test('19-30 …:09.120, \'ss.00\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9, 120), r'ss.00'));
      expect(res, r'09.12');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18S Q19S Q22S Q30Đ Q1S → R1
    test('19-31 formatText(\'x\', \'d @\')', () {
      final res = _run(() => formatText('x', 'd @'));
      expect(res, ' x');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34S Q35S Q36S Q37S Q38S Q39Đ Q41S Q1S → R1
    test('19-32 formatNumber(5, \'0E\')', () {
      final res = _run(() => f(5, r'0E'));
      expect(res, r'5E');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34S Q35S Q36S Q37S Q38S Q39Đ Q41Đ Q42Đ Q1S → R1
    test('19-33 formatNumber(12345, \'0.00E+00\')', () {
      final res = _run(() => f(12345, r'0.00E+00'));
      expect(res, r'1.23E+04');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34S Q35S Q36S Q37S Q38S Q39Đ Q41Đ Q42S Q43Đ Q1S → R1
    test('19-34 formatNumber(12345, \'0.00E-00\')', () {
      final res = _run(() => f(12345, r'0.00E-00'));
      expect(res, r'1.23E04');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34S Q35S Q36S Q37S Q38S Q39S Q40S Q44Đ Q45S Q1S → R1
    test('19-35 formatNumber(5, \'10\')', () {
      final res = _run(() => f(5, r'10'));
      expect(res, r'15');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16S Q31S Q32S Q33S Q34S Q35S Q36S Q37S Q38S Q39S Q40S Q44Đ Q45Đ Q46Đ Q1S → R1
    test('19-36 formatNumber(1.5, \'# ?/4\')', () {
      final res = _run(() => f(1.5, r'# ?/4'));
      expect(res, r'1 2/4');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8Đ Q9S Q10S Q11Đ Q12Đ Q13Đ Q1S → R1
    test('19-37 formatNumber(5, \'[\$€]0\')', () {
      final res = _run(() => f(5, r'[$€]0'));
      expect(res, r'€5');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8Đ Q9S Q10S Q11Đ Q12S Q13S Q1S → R1
    test('19-38 formatNumber(5, \'[\$-409]0\')', () {
      final res = _run(() => f(5, r'[$-409]0'));
      expect(res, r'5');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18S Q19Đ Q20S Q1S → R1
    test('19-39 13:05:09, \'h\' (vòng while dừng vì hết chuỗi)', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h'));
      expect(res, r'13');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18S Q19Đ Q20Đ Q21S Q1S → R1
    test('19-40 13:05:09, \'h:m\' (vòng while dừng ở \':\')', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h:m'));
      expect(res, r'13:5');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18S Q19S Q22Đ Q23S Q30S Q1S → R1
    test('19-41 13:05:09, \'ss.\' (dấu chấm cuối)', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'ss.'));
      expect(res, r'09.');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18S Q19S Q22Đ Q23Đ Q24S Q30S Q1S → R1
    test('19-42 13:05:09, \'ss."x"\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'ss."x"'));
      expect(res, r'09.x');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18S Q19S Q22Đ Q23Đ Q24Đ Q25S Q30S Q1S → R1
    test('19-43 13:05:09, \'.0ss\' (.0 đứng đầu)', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'.0ss'));
      expect(res, r'.009');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18S Q19S Q22Đ Q23Đ Q24Đ Q25Đ Q26S Q30S Q1S → R1
    test('19-44 13:05:09, \'ss".".0\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'ss".".0'));
      expect(res, r'09..0');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18S Q19S Q22Đ Q23Đ Q24Đ Q25Đ Q26Đ Q27S Q30S Q1S → R1
    test('19-45 13:05:09, \'h:mm.0\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h:mm.0'));
      expect(res, r'13:05.0');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18S Q19S Q22Đ Q23Đ Q24Đ Q25Đ Q26Đ Q27Đ Q28S Q1S → R1
    test('19-46 …:09.120, \'ss.0\' (vòng while dừng vì hết chuỗi)', () {
      final res = _run(() => f(t(45000, 13, 5, 9, 120), r'ss.0'));
      expect(res, r'09.1');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8S Q15S Q16Đ Q17S Q18S Q19S Q22Đ Q23Đ Q24Đ Q25Đ Q26Đ Q27Đ Q28Đ Q29S Q1S → R1
    test('19-47 …:09.120, \'ss.0"s"\' (vòng while dừng ở ngoặc kép)', () {
      final res = _run(() => f(t(45000, 13, 5, 9, 120), r'ss.0"s"'));
      expect(res, r'09.1s');
    });
    // Đường: Q1Đ Q2S Q4S Q6S Q7S Q8Đ Q9Đ (ký tự [ cuối section ⇒ inner = substring(i + 1, i) ném RangeError) → R1 (bổ sung)
    test('19-b1 formatText(\'x\', \'0[\')', () {
      final res = _run(() => formatText('x', '0['));
      expect(res, 'x');
    });
    // Đường: như 19-b1, qua readXlsx: ô chuỗi inline có numFmt "0[" (formatText không có try/catch ở xlsx_reader.dart:340) (bổ sung)
    test('19-b2 readXlsx — ô chuỗi "x", numFmt 0[', () {
      final res = _run(() => strCell('0['));
      expect(res, 'x');
    });
    // Đường: Q1Đ … Q39S Q40Đ Q41Đ Q42Đ → R1 (e thường + dấu +) (bổ sung)
    test('19-b3 formatNumber(12345, \'0.00e+00\')', () {
      final res = _run(() => f(12345, r'0.00e+00'));
      expect(res, r'1.23e+04');
    });
  });
  group('Đơn vị 20 — _formatDate', () {
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14Đ F19S F2S → R1
    test('20-1 15/03/2023, \'yyyy\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'yyyy'));
      expect(res, r'2023');
    });
    // Đường: F1S F2Đ F3S F4S F5S F8S F9S F11S F14Đ F19S F2S → R1
    test('20-2 15/03/2023 13:05:09, \'yyyy ss.0\' (subDigits = 1)', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'yyyy ss.0'));
      expect(res, r'2023 09.0');
    });
    // Đường: F1Đ F2S → R1
    test('20-3 15/03/2023, \'d\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'd'));
      expect(res, r'15');
    });
    // Đường: F1Đ F2Đ F3Đ F2S → R1
    test('20-4 15/03/2023, \'"Y"yyyy\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'"Y"yyyy'));
      expect(res, r'Y2023');
    });
    // Đường: F1Đ F2Đ F3S F4Đ F2S → R1
    test('20-5 15/03/2023, \'yyyy General\' (token General trong section ngày)', () {
      final res = _run(() => f(t(45000, 13, 5, 9), 'yyyy General'));
      expect(res, startsWith('2023'));
    });
    // Đường: F1Đ F2Đ F3S F4S F5Đ F6S F7S F2S → R1
    test('20-6 1 ngày 1:00, \'[ss]\'', () {
      final res = _run(() => f(t(1, 1, 0, 0), r'[ss]'));
      expect(res, r'90000');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8Đ F2S → R1
    test('20-7 …:09.120, \'ss.00\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9, 120), r'ss.00'));
      expect(res, r'09.12');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9Đ F10S F2S → R1
    test('20-8 13:05:09, \'h AM/PM\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h AM/PM'));
      expect(res, r'1 PM');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11Đ F12S F13S F2S → R1
    test('20-9 13:05:09, \'h a/p\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h a/p'));
      expect(res, r'1 p');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15S F16S F17S F18Đ F33S F2S → R1
    test('20-10 13:05:09, \'ss\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'ss'));
      expect(res, r'09');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14Đ F19Đ F2S → R1
    test('20-11 15/03/2023, \'yy\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'yy'));
      expect(res, r'23');
    });
    // Đường: F1Đ F2Đ F3S F4S F5Đ F6Đ F2S → R1
    test('20-12 1 ngày 1:00, \'[h]\'', () {
      final res = _run(() => f(t(1, 1, 0, 0), r'[h]'));
      expect(res, r'25');
    });
    // Đường: F1Đ F2Đ F3S F4S F5Đ F6S F7Đ F2S → R1
    test('20-13 1 ngày 1:00, \'[mm]\'', () {
      final res = _run(() => f(t(1, 1, 0, 0), r'[mm]'));
      expect(res, r'1500');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9Đ F10Đ F2S → R1
    test('20-14 09:05:09, \'h AM/PM\'', () {
      final res = _run(() => f(t(45000, 9, 5, 9), r'h AM/PM'));
      expect(res, r'9 AM');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11Đ F12Đ F13S F2S → R1
    test('20-15 09:05:09, \'h a/p\'', () {
      final res = _run(() => f(t(45000, 9, 5, 9), r'h a/p'));
      expect(res, r'9 a');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11Đ F12S F13Đ F2S → R1
    test('20-16 13:05:09, \'h A/P\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h A/P'));
      expect(res, r'1 P');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15Đ F20Đ F21S F23S F24Đ F2S → R1
    test('20-17 15/03/2023, \'mm\' (đứng riêng ⇒ tháng)', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'mm'));
      expect(res, r'03');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15S F16Đ F27S F28S F29S F2S → R1
    test('20-18 05/03/2023, \'dddd\'', () {
      final res = _run(() => f(t(44990, 9, 5, 9), r'dddd'));
      expect(res, r'Sunday');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15S F16S F17Đ F30S F32S F2S → R1
    test('20-19 09:05:09, \'hh\'', () {
      final res = _run(() => f(t(44990, 9, 5, 9), r'hh'));
      expect(res, r'09');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15S F16S F17S F18Đ F33Đ F2S → R1
    test('20-21 13:05:09, \'s\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r's'));
      expect(res, r'9');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15Đ F20S F23S F24S F25S F26S F2S → R1
    test('20-22 15/03/2023, \'mmmm\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'mmmm'));
      expect(res, r'March');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15Đ F20Đ F21Đ F22S F2S → R1
    test('20-23 13:05:09, \'h:mm\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h:mm'));
      expect(res, r'13:05');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15Đ F20Đ F21S F23Đ F2S → R1
    test('20-24 15/03/2023, \'m\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'm'));
      expect(res, r'3');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15S F16Đ F27Đ F2S → R1
    test('20-26 05/03/2023, \'d\'', () {
      final res = _run(() => f(t(44990, 9, 5, 9), r'd'));
      expect(res, r'5');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15S F16Đ F27S F28Đ F2S → R1
    test('20-27 05/03/2023, \'dd\'', () {
      final res = _run(() => f(t(44990, 9, 5, 9), r'dd'));
      expect(res, r'05');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15S F16Đ F27S F28S F29Đ F2S → R1
    test('20-28 05/03/2023, \'ddd\'', () {
      final res = _run(() => f(t(44990, 9, 5, 9), r'ddd'));
      expect(res, r'Sun');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15S F16S F17Đ F30Đ F31S F32S F2S → R1
    test('20-29 13:05:09, \'hh AM/PM\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'hh AM/PM'));
      expect(res, r'01 PM');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15S F16S F17Đ F30S F32Đ F2S → R1
    test('20-30 09:05:09, \'h\'', () {
      final res = _run(() => f(t(44990, 9, 5, 9), r'h'));
      expect(res, r'9');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15Đ F20S F23S F24S F25Đ F2S → R1
    test('20-31 15/03/2023, \'mmm\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'mmm'));
      expect(res, r'Mar');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15Đ F20S F23S F24S F25S F26Đ F2S → R1
    test('20-32 15/03/2023, \'mmmmm\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'mmmmm'));
      expect(res, r'M');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15Đ F20Đ F21Đ F22Đ F2S → R1
    test('20-33 13:05:09, \'h:m\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h:m'));
      expect(res, r'13:5');
    });
    // Đường: F1Đ F2Đ F3S F4S F5S F8S F9S F11S F14S F15S F16S F17Đ F30Đ F31Đ F32S F2S → R1
    test('20-34 00:30, \'hh AM/PM\'', () {
      final res = _run(() => f(t(45000, 0, 30, 0), r'hh AM/PM'));
      expect(res, r'12 AM');
    });
  });
  group('Đơn vị 21 — _formatDate — isMinute (hàm cục bộ)', () {
    // Đường: M1S M5Đ M6Đ M7S M8S → R2
    test('21-1 15/03/2023, \'mm dd\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'mm dd'));
      expect(res, r'03 15');
    });
    // Đường: M1Đ M2S M3S M4S M5Đ M6Đ M7S M8S → R2
    test('21-2 15/03/2023, \'yyyy mm dd\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'yyyy mm dd'));
      expect(res, r'2023 03 15');
    });
    // Đường: M1S M5Đ M6S → R2
    test('21-4 15/03/2023, \'mm\' (token ngày duy nhất)', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'mm'));
      expect(res, r'03');
    });
    // Đường: M1S M5Đ M6Đ M7Đ → R1
    test('21-5 13:05:09, \'mm:ss\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'mm:ss'));
      expect(res, r'05:09');
    });
    // Đường: M1S M5Đ M6Đ M7S M8Đ → R1
    test('21-6 00:05:09, \'mm [ss]\'', () {
      final res = _run(() => f(t(0, 0, 5, 9), r'mm [ss]'));
      expect(res, r'05 309');
    });
    // Đường: M1Đ M2Đ → R1
    test('21-7 13:05:09, \'h:mm\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h:mm'));
      expect(res, r'13:05');
    });
    // Đường: M1Đ M2S M3Đ → R1
    test('21-8 1 ngày 1:05, \'[h]:mm\'', () {
      final res = _run(() => f(t(1, 1, 5, 0), r'[h]:mm'));
      expect(res, r'25:05');
    });
    // Đường: M1Đ M2S M3S M4Đ → R1
    test('21-9 1 ngày 1:05, \'[hh]:mm\'', () {
      final res = _run(() => f(t(1, 1, 5, 0), r'[hh]:mm'));
      expect(res, r'25:05');
    });
  });
  group('Đơn vị 22 — _formatDate — lambda ampm (toks.any)', () {
    // Đường: A1Đ A2S A3S → R2
    test('22-1 13:05:09, \'h\' (không có AM/PM ⇒ 24 giờ)', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h'));
      expect(res, r'13');
    });
    // Đường: A1S → R2
    test('22-2 13:05:09, \'h "AM/PM"\' (AM/PM trong ngoặc kép là chữ)', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h "AM/PM"'));
      expect(res, r'13 AM/PM');
    });
    // Đường: A1Đ A2Đ → R1
    test('22-3 13:05:09, \'h AM/PM\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h AM/PM'));
      expect(res, r'1 PM');
    });
    // Đường: A1Đ A2S A3Đ → R1
    test('22-4 13:05:09, \'h A/P\'', () {
      final res = _run(() => f(t(45000, 13, 5, 9), r'h A/P'));
      expect(res, r'1 P');
    });
  });
  group('Đơn vị 23 — _formatDate — lambda lọc subDigits (toks.where)', () {
    // Đường: W1Đ W2S → R2
    test('23-1 9,6 giây, \'ss\' (làm tròn tới giây)', () {
      final res = _run(() => f(t(0, 0, 0, 9, 600), r'ss'));
      expect(res, r'10');
    });
    // Đường: W1S → R2
    test('23-2 9,6 giây, \'ss".00"\' (.00 là chữ)', () {
      final res = _run(() => f(t(0, 0, 0, 9, 600), r'ss".00"'));
      expect(res, r'10.00');
    });
    // Đường: W1Đ W2Đ → R1
    test('23-3 9,6 giây, \'ss.00\'', () {
      final res = _run(() => f(t(0, 0, 0, 9, 600), r'ss.00'));
      expect(res, r'09.60');
    });
  });
}
