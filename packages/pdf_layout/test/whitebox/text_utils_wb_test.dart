// Kiểm thử hộp trắng (A18) — lib/src/text_utils.dart.
// Mã bộ và kết quả mong đợi chép từ test-output/whitebox/pdf-layout/text_utils/buoc-5-du-lieu-thu.md.
import 'package:pdf_layout/src/text_utils.dart';
import 'package:test/test.dart';

void main() {
  group('U1 isNoSpaceScript', () {
    final cases = <String, (int, bool)>{
      'U1-P1': (0x41, false),
      'U1-P2': (0x0E01, true),
      'U1-P3': (0x0F00, false),
      'U1-P4': (0x1000, true),
      'U1-P5': (0x10A0, false),
      'U1-P6': (0x1780, true),
      'U1-P7': (0x1800, false),
      'U1-P8': (0x3042, true),
      'U1-P9': (0x3130, false),
      'U1-P10': (0x4E2D, true),
      'U1-P11': (0xA000, false),
      'U1-P12': (0xF900, true),
      'U1-P13': (0xFB00, false),
      'U1-P14': (0xFE30, true),
      'U1-P15': (0xFE50, false),
      'U1-P16': (0xFF01, true),
      'U1-P17': (0xFFF0, false),
      'U1-P18': (0x20000, true),
      'U1-P19': (0x40000, false),
    };
    cases.forEach((id, c) {
      test('$id rune 0x${c.$1.toRadixString(16)} ⇒ ${c.$2}', () {
        expect(isNoSpaceScript(c.$1), c.$2);
      });
    });
  });

  group('U2 _isLatin (qua isLowerLatin)', () {
    final cases = <String, (int, bool)>{
      'U2-P1': (0x41, false),
      'U2-P2': (0x61, true),
      'U2-P3': (0x7B, false),
      'U2-P4': (0xE0, true),
      'U2-P5': (0x3B1, false),
      'U2-P6': (0xD7, false),
      'U2-P7': (0xF7, false),
      'U2-P8': (0x1EA1, true),
      'U2-P9': (0x1F00, false),
    };
    cases.forEach((id, c) {
      test('$id rune 0x${c.$1.toRadixString(16)} ⇒ ${c.$2}', () {
        expect(isLowerLatin(c.$1), c.$2);
      });
    });
  });

  group('U3 isLowerLatin', () {
    test('U3-P1 a ⇒ true', () => expect(isLowerLatin(0x61), isTrue));
    test('U3-P2 A ⇒ false', () => expect(isLowerLatin(0x41), isFalse));
    test('U3-P3 À ⇒ false', () => expect(isLowerLatin(0xC0), isFalse));
    test('U3-P4 ĸ (chữ thường không có dạng hoa) ⇒ true', () {
      // nhánh: _isLatin đúng, toLowerCase()==s đúng; điều cần đo là toUpperCase()!=s
      expect(String.fromCharCode(0x138).toLowerCase(), 'ĸ');
      expect(isLowerLatin(0x138), isTrue);
    });
  });

  group('U4 _isSpace (qua lineJoin)', () {
    final cases = <String, (int, String)>{
      'U4-P1': (0x61, ' '),
      'U4-P2': (0x20, ''),
      'U4-P3': (0x09, ''),
      'U4-P4': (0xA0, ''),
      'U4-P5': (0x3000, ''),
    };
    cases.forEach((id, c) {
      test('$id ký tự cuối 0x${c.$1.toRadixString(16)} ⇒ "${c.$2}"', () {
        final j = lineJoin('x${String.fromCharCode(c.$1)}', 'y');
        expect(j.trimEnd, 0);
        expect(j.separator, c.$2);
      });
    });
  });

  group('U5 lineJoin', () {
    final cases = <String, (String, String, int, String)>{
      'U5-P1': ('ab', 'cd', 0, ' '),
      'U5-P2': ('', 'cd', 0, ''),
      'U5-P3': ('ab', '', 0, ''),
      'U5-P4': ('a', 'cd', 0, ' '),
      'U5-P5': ('infor-', 'mation', 1, ''),
      'U5-P6': ('a -', 'cd', 0, ' '),
      'U5-P7': ('well-', 'Known', 0, ' '),
      'U5-P8': ('a ', 'cd', 0, ''),
      'U5-P9': ('ab', ' cd', 0, ''),
      'U5-P10': ('ab中', 'cd', 0, ''),
      'U5-P11': ('ab', '中d', 0, ''),
    };
    cases.forEach((id, c) {
      test('$id "${c.$1}" + "${c.$2}" ⇒ (${c.$3},"${c.$4}")', () {
        final j = lineJoin(c.$1, c.$2);
        expect((j.trimEnd, j.separator), (c.$3, c.$4));
      });
    });
  });

  group('U6 wordSeparator', () {
    final cases = <String, (String, String, double, String)>{
      'U6-P1': ('ab', 'cd', 1, ' '),
      'U6-P2': ('', 'cd', 1, ''),
      'U6-P3': ('ab', '', 1, ''),
      'U6-P4': ('中', '文', 1, ''),
      'U6-P5': ('中', '文', 5, ' '),
      'U6-P6': ('ab', '文', 1, ''),
    };
    cases.forEach((id, c) {
      test('$id "${c.$1}","${c.$2}" gap ${c.$3} ⇒ "${c.$4}"', () {
        expect(wordSeparator(c.$1, c.$2, c.$3, 10), c.$4);
      });
    });
  });

  group('U7 matchListMarker', () {
    test('U7-P1 có dấu đầu dòng ⇒ (marker, độ dài tiền tố)', () {
      expect(matchListMarker('• item'), ('•', 2));
      expect(matchListMarker('12) abc'), ('12)', 4));
      expect(matchListMarker('b. x'), ('b.', 3));
    });
    test('U7-P2 không có dấu / thiếu khoảng trắng ⇒ null', () {
      expect(matchListMarker('abc'), isNull);
      expect(matchListMarker('•abc'), isNull);
    });
  });
}
