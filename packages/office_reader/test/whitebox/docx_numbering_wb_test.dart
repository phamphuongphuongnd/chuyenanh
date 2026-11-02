// Kiểm thử hộp trắng (agent A17) cho lib/src/docx/docx_numbering.dart.
// Sinh từ Bước 5 (test-output/whitebox/office-reader/docx_numbering/buoc-5-du-lieu-thu.md).
// Expected chép từ Bước 5 — KHÔNG chỉnh cho khớp code. Tên test bắt đầu bằng mã bộ.
import 'package:office_reader/src/docx/docx_numbering.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';
Object? _run(Object? Function() f) {
  try {
    return f();
  } catch (e) {
    return e;
  }
}

DocxNumbering numb(String inner) => DocxNumbering(
  XmlDocument.parse('<w:numbering xmlns:w="u">$inner</w:numbering>'),
);
String lvl(int i, {String fmt = 'decimal', String text = '%1.', String start = '<w:start w:val="1"/>', String extra = ''}) =>
    '<w:lvl w:ilvl="$i">$start<w:numFmt w:val="$fmt"/><w:lvlText w:val="$text"/>$extra</w:lvl>';
String abs(int id, String lvls) => '<w:abstractNum w:abstractNumId="$id">$lvls</w:abstractNum>';
String num(int id, int aid, [String ov = '']) =>
    '<w:num w:numId="$id"><w:abstractNumId w:val="$aid"/>$ov</w:num>';
/// Gọi next nhiều lần, trả nhãn của lần cuối (và cờ ordered).
(String?, bool)? nextN(DocxNumbering n, List<(int, int)> calls) {
  (String?, bool)? r;
  for (final c in calls) {
    r = n.next(c.$1, c.$2);
  }
  return r;
}

void main() {
  group('Đơn vị 1 — _Level.parse', () {
    // Đường: D1S D2S D3S → R1
    test('1-1 lvl 0: start 3, lowerLetter, "%1)"', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'lowerLetter', text: '%1)', start: '<w:start w:val="3"/>'))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('c)', true)));
    });
    // Đường: D1Đ D2S D3S → R1
    test('1-2 lvl 0 không có w:start, decimal "%1."', () {
      final res = _run(() => numb('${abs(1, lvl(0, start: ''))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('1.', true)));
    });
    // Đường: D1S D2Đ D3S → R1
    test('1-3 lvl 0 start 2, không có w:numFmt', () {
      final res = _run(() => numb('${abs(1, '<w:lvl w:ilvl="0"><w:start w:val="2"/><w:lvlText w:val="%1."/></w:lvl>')}${num(1, 1)}').next(1, 0));
      expect(res, equals(('2.', true)));
    });
    // Đường: D1S D2S D3Đ → R1
    test('1-4 lvl 0 decimal không có w:lvlText', () {
      final res = _run(() => numb('${abs(1, '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/></w:lvl>')}${num(1, 1)}').next(1, 0));
      expect(res, equals((null, true)));
    });
  });
  group('Đơn vị 2 — DocxNumbering (constructor)', () {
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10S → R2
    test('2-1 abstract 1 (lvl 0 decimal "%1.") + num 1 có lvlOverride ilvl 0 chỉ có startOverride 5', () {
      final res = _run(() => numb('${abs(1, lvl(0))}${num(1, 1, '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="5"/></w:lvlOverride>')}').next(1, 0));
      expect(res, equals(('5.', true)));
    });
    // Đường: D1Đ → R1
    test('2-2 DocxNumbering(null) — không có numbering.xml', () {
      final res = _run(() => DocxNumbering(null).next(1, 0));
      expect(res, isNull);
    });
    // Đường: D1S D2Đ D4S D5S D6S D7S D8S D9S D10S → R2
    test('2-3 abstractNum thiếu abstractNumId (bị bỏ) + abstract 1 + num 1 startOverride 5', () {
      final res = _run(() => numb('<w:abstractNum>${lvl(0, fmt: 'upperRoman')}</w:abstractNum>${abs(1, lvl(0))}${num(1, 1, '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="5"/></w:lvlOverride>')}').next(1, 0));
      expect(res, equals(('5.', true)));
    });
    // Đường: D1S D2S D3Đ D4S D5S D6S D7S D8S D9S D10S → R2
    test('2-4 lvl không có w:ilvl (⇒ cấp 0), upperRoman; num 1 startOverride 4', () {
      final res = _run(() => numb('${abs(1, '<w:lvl><w:start w:val="1"/><w:numFmt w:val="upperRoman"/><w:lvlText w:val="%1."/></w:lvl>')}${num(1, 1, '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="4"/></w:lvlOverride>')}').next(1, 0));
      expect(res, equals(('IV.', true)));
    });
    // Đường: D1S D2S D3S D4Đ → R2
    test('2-5 w:num thiếu numId', () {
      final res = _run(() => numb('${abs(1, lvl(0))}<w:num><w:abstractNumId w:val="1"/></w:num>').exists(1));
      expect(res, isFalse);
    });
    // Đường: D1S D2S D3S D4S D5Đ → R2
    test('2-6 w:num 1 thiếu abstractNumId', () {
      final res = _run(() => numb('${abs(1, lvl(0))}<w:num w:numId="1"/>').exists(1));
      expect(res, isFalse);
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ D7S D8S D9S D10S → R2
    test('2-7 lvlOverride không có w:ilvl (⇒ 0), startOverride 7', () {
      final res = _run(() => numb('${abs(1, lvl(0))}${num(1, 1, '<w:lvlOverride><w:startOverride w:val="7"/></w:lvlOverride>')}').next(1, 0));
      expect(res, equals(('7.', true)));
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7Đ D10S → R2
    test('2-8 lvlOverride có w:lvl (upperLetter "%1)" start 1) + startOverride 3', () {
      final res = _run(() => numb('${abs(1, lvl(0))}${num(1, 1, '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="3"/>${lvl(0, fmt: 'upperLetter', text: '%1)')}</w:lvlOverride>')}').next(1, 0));
      expect(res, equals(('C)', true)));
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8Đ D9Đ D10S → R2
    test('2-9 num 1 trỏ abstract 9 không tồn tại; override ilvl 0 chỉ có startOverride 2', () {
      final res = _run(() => numb('${num(1, 9, '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="2"/></w:lvlOverride>')}').next(1, 0));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9Đ D10S → R2
    test('2-10 abstract 1 chỉ có cấp 0; override ilvl 3 chỉ có startOverride 2; next(1, 3)', () {
      final res = _run(() => numb('${abs(1, lvl(0))}${num(1, 1, '<w:lvlOverride w:ilvl="3"><w:startOverride w:val="2"/></w:lvlOverride>')}').next(1, 3));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3S D4S D5S D6S D7S D8S D9S D10Đ → R2
    test('2-11 lvlOverride ilvl 0 rỗng (không lvl, không startOverride)', () {
      final res = _run(() => numb('${abs(1, lvl(0))}${num(1, 1, '<w:lvlOverride w:ilvl="0"/>')}').next(1, 0));
      expect(res, equals(('1.', true)));
    });
  });
  group('Đơn vị 3 — DocxNumbering._level', () {
    // Đường: D1S D2S → R2
    test('3-1 override ilvl 0 có w:lvl với pPr ind left 720', () {
      final res = _run(() => numb('${abs(1, lvl(0))}${num(1, 1, '<w:lvlOverride w:ilvl="0">${lvl(0, extra: '<w:pPr><w:ind w:left="720"/></w:pPr>')}</w:lvlOverride>')}').levelProps(1, 0).indLeft);
      expect(res, 36.0);
    });
    // Đường: D1Đ → R1
    test('3-2 levelProps(9, 0) — numId lạ', () {
      final res = _run(() => numb('${abs(1, lvl(0))}${num(1, 1)}').levelProps(9, 0).indLeft);
      expect(res, isNull);
    });
    // Đường: D1S D2Đ D3S → R4
    test('3-3 không có override, abstract lvl 0 ind left 360', () {
      final res = _run(() => numb('${abs(1, lvl(0, extra: '<w:pPr><w:ind w:left="360"/></w:pPr>'))}${num(1, 1)}').levelProps(1, 0).indLeft);
      expect(res, 18.0);
    });
    // Đường: D1S D2Đ D3Đ → R3
    test('3-4 num 1 trỏ abstract 9 không có, không override', () {
      final res = _run(() => numb('${num(1, 9)}').levelProps(1, 0).indLeft);
      expect(res, isNull);
    });
  });
  group('Đơn vị 4 — DocxNumbering.levelProps', () {
    // Đường: D1S D2S → R1
    test('4-1 cấp có pPr ind left 720', () {
      final res = _run(() => numb('${abs(1, lvl(0, extra: '<w:pPr><w:ind w:left="720"/></w:pPr>'))}${num(1, 1)}').levelProps(1, 0).indLeft);
      expect(res, 36.0);
    });
    // Đường: D1Đ D2Đ → R1
    test('4-2 cấp không có (ilvl 5)', () {
      final res = _run(() => numb('${abs(1, lvl(0))}${num(1, 1)}').levelProps(1, 5).indLeft);
      expect(res, isNull);
    });
  });
  group('Đơn vị 5 — DocxNumbering.next', () {
    // Đường: D1S D2Đ D3Đ D3S D4Đ D5Đ D6S D8S D11S → R7
    test('5-1 decimal "%1." — lần đầu', () {
      final res = _run(() => numb('${abs(1, lvl(0))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('1.', true)));
    });
    // Đường: D1Đ → R1
    test('5-2 next(9, 0) — numId lạ', () {
      final res = _run(() => numb('${abs(1, lvl(0))}${num(1, 1)}').next(9, 0));
      expect(res, isNull);
    });
    // Đường: D1S D2S D3Đ D3S D4Đ D5Đ D6S D8S D11S → R7
    test('5-3 gọi next(1,0) 2 lần', () {
      final res = _run(() => nextN(numb('${abs(1, lvl(0))}${num(1, 1)}'), [(1, 0), (1, 0)]));
      expect(res, equals(('2.', true)));
    });
    // Đường: D1S D2Đ D3S D4Đ D5Đ D6S D8S D11S → R7
    test('5-4 cấp 8 (không còn cấp con để xoá) "%9."', () {
      final res = _run(() => numb('${abs(1, lvl(8, text: '%9.'))}${num(1, 1)}').next(1, 8));
      expect(res, equals(('1.', true)));
    });
    // Đường: D1S D2Đ D3Đ D3S D4S D6Đ D7S → R3
    test('5-5 bullet, lvlText "-"', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'bullet', text: '-'))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('-', false)));
    });
    // Đường: D1S D2Đ D3Đ D3S D4Đ D5S D6S D8Đ D9Đ D10S → R5
    test('5-6 numFmt none, lvlText "Ghi chú:" (không có %)', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'none', text: 'Ghi chú:'))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('Ghi chú:', false)));
    });
    // Đường: D1S D2Đ D3Đ D3S D4Đ D5Đ D6S D8S D11Đ → R6
    test('5-9 decimal, lvlText rỗng ""', () {
      final res = _run(() => numb('${abs(1, lvl(0, text: ''))}${num(1, 1)}').next(1, 0));
      expect(res, equals((null, true)));
    });
    // Đường: D1S D2Đ D3Đ D3S D4Đ D5S D6S D8Đ D9S D11S → R7
    test('5-11 numFmt none, lvlText "Bước %1"', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'none', text: 'Bước %1'))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('Bước ', false)));
    });
    // Đường: D1S D2Đ D3Đ D3S D4Đ D5S D6S D8Đ D9Đ D10Đ → R4
    test('5-12 numFmt none, lvlText rỗng', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'none', text: ''))}${num(1, 1)}').next(1, 0));
      expect(res, equals((null, false)));
    });
  });
  group('Đơn vị 6 — next — lambda thay %n (replaceAllMapped)', () {
    // Đường: D1S D4S D5S D6S → R1
    test('6-1 cấp 0 "%1." rồi cấp 1 "%1.%2." (cả 2 đã đếm)', () {
      final res = _run(() => nextN(numb('${abs(1, lvl(0) + lvl(1, text: '%1.%2.'))}${num(1, 1)}'), [(1, 0), (1, 1)]));
      expect(res, equals(('1.1.', true)));
    });
    // Đường: D1Đ D2S D3S D4S D5S D6S → R1
    test('6-2 gọi thẳng cấp 1 "%1.%2." khi cấp 0 (start 3) chưa đếm', () {
      final res = _run(() => numb('${abs(1, lvl(0, start: '<w:start w:val="3"/>') + lvl(1, text: '%1.%2.'))}${num(1, 1)}').next(1, 1));
      expect(res, equals(('3.1.', true)));
    });
    // Đường: D1S D4Đ D6S → R1
    test('6-3 cấp 0 upperRoman, cấp 1 isLgl "%1.%2"', () {
      final res = _run(() => nextN(numb('${abs(1, lvl(0, fmt: 'upperRoman') + lvl(1, text: '%1.%2', extra: '<w:isLgl/>'))}${num(1, 1)}'), [(1, 0), (1, 1)]));
      expect(res, equals(('1.1', true)));
    });
    // Đường: D1S D4S D5Đ D6Đ → R1
    test('6-4 abstract chỉ có cấp 12 "%9." (cấp 8 không định nghĩa); next(1, 12)', () {
      final res = _run(() => numb('${abs(1, lvl(12, text: '%9.'))}${num(1, 1)}').next(1, 12));
      expect(res, equals(('1.', true)));
    });
    // Đường: D1Đ D2Đ D3Đ D4S D5Đ D6Đ → R1
    test('6-6 cấp 0 "%2." tham chiếu cấp 1 không định nghĩa', () {
      final res = _run(() => numb('${abs(1, lvl(0, text: '%2.'))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('1.', true)));
    });
  });
  group('Đơn vị 7 — _bulletText', () {
    // Đường: D1S D2Đ D3Đ D4S D5S D6S D7S D8S → R2
    test('7-1 bullet "\\uF0B7" (Symbol, ngoài bảng ánh xạ)', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'bullet', text: '\uF0B7'))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('•', false)));
    });
    // Đường: D1Đ → R1
    test('7-2 bullet lvlText rỗng', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'bullet', text: ''))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('•', false)));
    });
    // Đường: D1S D2S → R2
    test('7-3 bullet "-"', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'bullet', text: '-'))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('-', false)));
    });
    // Đường: D1S D2Đ D3S → R2
    test('7-4 bullet "\\uF100" (PUA ngoài F000–F0FF)', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'bullet', text: '\uF100'))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('\uF100', false)));
    });
    // Đường: D1S D2Đ D3Đ D4Đ → R2
    test('7-5 bullet "\\uF0A7" (Wingdings §)', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'bullet', text: '\uF0A7'))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('▪', false)));
    });
    // Đường: D1S D2Đ D3Đ D4S D5Đ → R2
    test('7-6 bullet "\\uF0D8"', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'bullet', text: '\uF0D8'))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('➢', false)));
    });
    // Đường: D1S D2Đ D3Đ D4S D5S D6Đ → R2
    test('7-7 bullet "\\uF076"', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'bullet', text: '\uF076'))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('❖', false)));
    });
    // Đường: D1S D2Đ D3Đ D4S D5S D6S D7Đ → R2
    test('7-8 bullet "\\uF0FC"', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'bullet', text: '\uF0FC'))}${num(1, 1)}').next(1, 0));
      expect(res, equals(('✓', false)));
    });
    // Đường: D1S D2Đ D3Đ D4S D5S D6S D7S D8Đ → R2
    test('7-9 bullet "\\uF06F"', () {
      final res = _run(() => numb('${abs(1, lvl(0, fmt: 'bullet', text: '\uF06F'))}${num(1, 1)}').next(1, 0));
      expect(res, isA<(String?, bool)>().having((r) => r.$1!.runes.single, 'rune', isNot(inInclusiveRange(0xF000, 0xF0FF))).having((r) => r.$2, 'ordered', isFalse));
    });
  });
  group('Đơn vị 8 — formatListNumber', () {
    // Đường: D1S D2S D3S D4S D5S D6S → R8
    test('8-1 (12, \'decimal\')', () {
      final res = _run(() => formatListNumber(12, 'decimal'));
      expect(res, '12');
    });
    // Đường: D1Đ D7S → R2
    test('8-2 (12, \'decimalZero\')', () {
      final res = _run(() => formatListNumber(12, 'decimalZero'));
      expect(res, '12');
    });
    // Đường: D1S D2Đ → R3
    test('8-3 (14, \'upperRoman\')', () {
      final res = _run(() => formatListNumber(14, 'upperRoman'));
      expect(res, 'XIV');
    });
    // Đường: D1S D2S D3Đ → R4
    test('8-4 (9, \'lowerRoman\')', () {
      final res = _run(() => formatListNumber(9, 'lowerRoman'));
      expect(res, 'ix');
    });
    // Đường: D1S D2S D3S D4Đ → R5
    test('8-5 (28, \'upperLetter\')', () {
      final res = _run(() => formatListNumber(28, 'upperLetter'));
      expect(res, 'BB');
    });
    // Đường: D1S D2S D3S D4S D5Đ → R6
    test('8-6 (3, \'lowerLetter\')', () {
      final res = _run(() => formatListNumber(3, 'lowerLetter'));
      expect(res, 'c');
    });
    // Đường: D1S D2S D3S D4S D5S D6Đ → R7
    test('8-7 (3, \'none\')', () {
      final res = _run(() => formatListNumber(3, 'none'));
      expect(res, '');
    });
    // Đường: D1Đ D7Đ → R1
    test('8-8 (5, \'decimalZero\')', () {
      final res = _run(() => formatListNumber(5, 'decimalZero'));
      expect(res, '05');
    });
  });
  group('Đơn vị 9 — _roman', () {
    // Đường: D1S D2S D3Đ D4Đ D4S D3S → R2
    test('9-1 1987 upperRoman', () {
      final res = _run(() => formatListNumber(1987, 'upperRoman'));
      expect(res, 'MCMLXXXVII');
    });
    // Đường: D1Đ → R1
    test('9-2 0 upperRoman', () {
      final res = _run(() => formatListNumber(0, 'upperRoman'));
      expect(res, isNotEmpty);
    });
    // Đường: D1S D2Đ → R1
    test('9-3 4000 upperRoman', () {
      final res = _run(() => formatListNumber(4000, 'upperRoman'));
      expect(res, isNotEmpty);
    });
    // Đường: D1S D2S D3Đ D4S D3S → R2
    test('9-5 4 upperRoman (lượt đầu x < 1000)', () {
      final res = _run(() => formatListNumber(4, 'upperRoman'));
      expect(res, 'IV');
    });
  });
  group('Đơn vị 10 — _letters', () {
    // Đường: D1S → R2
    test('10-1 27 upperLetter', () {
      final res = _run(() => formatListNumber(27, 'upperLetter'));
      expect(res, 'AA');
    });
    // Đường: D1Đ → R1
    test('10-2 0 upperLetter', () {
      final res = _run(() => formatListNumber(0, 'upperLetter'));
      expect(res, isNotEmpty);
    });
  });
}
