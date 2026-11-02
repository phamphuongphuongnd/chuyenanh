// Kiểm thử hộp trắng (A05, Bước 6) cho lib/features/convert/text/line_wrap.dart.
// Expected chép từ test-output/whitebox/convert/line_wrap/buoc-5-du-lieu-thu.md — không chỉnh cho khớp code.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/convert/text/line_wrap.dart';
import 'package:pdf_office/features/convert/text/script_runs.dart';

/// Đo giả: mỗi ký tự rộng 10, một dấu cách rộng 5.
class _M implements TextMeasurer {
  @override
  double width(ScriptFace face, StyledSpan style, String text) => text.runes.length * 10.0;
  @override
  double spaceWidth(ScriptFace face, StyledSpan style) => 5;
}

List<LayoutToken> _tok(List<String> spans, {double maxWidth = 100}) =>
    tokenize([for (final s in spans) StyledSpan(s)], _M(), maxWidth: maxWidth);

/// (text, spaces, forceBreak) cho từng token.
List<(String, int, bool)> _sig(List<LayoutToken> ts) => [for (final t in ts) (t.text, t.spaces, t.forceBreak)];

List<WrappedLine> _wrap(List<StyledSpan> spans, double maxWidth, {double indent = 0}) =>
    wrapTokens(tokenize(spans, _M(), maxWidth: maxWidth), maxWidth: maxWidth, firstLineIndent: indent);

void main() {
  group('U1 StyledSpan.sameStyle', () {
    const base = StyledSpan('x');
    final cases = <(String, StyledSpan, bool)>[
      ('LW-U1-B1 cùng mọi thuộc tính, khác chữ → true', const StyledSpan('khác chữ'), true),
      ('LW-U1-B2 khác bold → false (D1 S)', const StyledSpan('x', bold: true), false),
      ('LW-U1-B3 khác italic → false (D2 S)', const StyledSpan('x', italic: true), false),
      ('LW-U1-B4 khác underline → false (D3 S)', const StyledSpan('x', underline: true), false),
      ('LW-U1-B5 khác strike → false (D4 S)', const StyledSpan('x', strike: true), false),
      ('LW-U1-B6 khác size → false (D5 S)', const StyledSpan('x', size: 12), false),
      ('LW-U1-B7 khác colorArgb → false (D6 S)', const StyledSpan('x', colorArgb: 0xFF000000), false),
      ('LW-U1-B8 khác highlightArgb → false (D7 S)', const StyledSpan('x', highlightArgb: 0xFFFFFF00), false),
      ('LW-U1-B9 khác rise → false (D8 S)', const StyledSpan('x', rise: 1), false),
    ];
    for (final c in cases) {
      test(c.$1, () => expect(base.sameStyle(c.$2), c.$3));
    }
  });

  group('U2 _isSpace (qua tokenize "a?b")', () {
    test('LW-U2-B1 U+0020 là dấu cách → 2 token, token đầu có 1 dấu cách (D1 Đ)', () {
      expect(_sig(_tok(['a b'])), [('a', 1, false), ('b', 0, false)]);
    });
    test('LW-U2-B2 U+00A0 (NBSP) → nhánh D2 Đ: tách token (*)', () {
      expect(_sig(_tok(['a b'])), [('a', 1, false), ('b', 0, false)]);
    });
    test('LW-U2-B3 U+3000 (dấu cách CJK) → 2 token (D3 Đ)', () {
      expect(_sig(_tok(['a　b'])), [('a', 1, false), ('b', 0, false)]);
    });
    test('LW-U2-B4 chữ thường x → không phải dấu cách, 1 token (D3 S)', () {
      expect(_sig(_tok(['axb'])), [('axb', 0, false)]);
    });
  });

  group('U3 tokenize', () {
    test('LW-U3-P1 không span → [] (D1 S)', () => expect(_tok([]), isEmpty));
    test('LW-U3-P2 span rỗng → [] (D2 S)', () => expect(_tok(['']), isEmpty));
    test('LW-U3-P3 "a" → 1 token rộng 10 (D3..D17 nhánh từ)', () {
      final ts = _tok(['a']);
      expect(_sig(ts), [('a', 0, false)]);
      expect(ts.single.width, 10);
    });
    test('LW-U3-P4 "\\n" → 1 token forceBreak rỗng (D4 Đ)', () {
      final ts = _tok(['\n']);
      expect(_sig(ts), [('', 0, true)]);
      expect(ts.single.width, 0);
    });
    test('LW-U3-P5 "中" → 1 token CJK, font Trung (D12 Đ)', () {
      final ts = _tok(['中']);
      expect(_sig(ts), [('中', 0, false)]);
      expect(ts.single.face, ScriptFace.chinese);
    });
    test('LW-U3-P6 "中中" → mỗi chữ CJK 1 token (D3 lần 2 Đ)', () {
      expect(_sig(_tok(['中中'])), [('中', 0, false), ('中', 0, false)]);
    });
    test('LW-U3-P7 " " → 1 token chỉ dấu cách, rộng dấu cách 5 (D5 Đ, D8 S)', () {
      final ts = _tok([' ']);
      expect(_sig(ts), [('', 1, false)]);
      expect(ts.single.spaceWidth, 5);
    });
    test('LW-U3-P8 "  " → 1 token 2 dấu cách (D6 lần 2 Đ)', () {
      expect(_sig(_tok(['  '])), [('', 2, false)]);
    });
    test('LW-U3-P9 " a" → token dấu cách rồi "a" (D7 S)', () {
      expect(_sig(_tok([' a'])), [('', 1, false), ('a', 0, false)]);
    });
    test('LW-U3-P10 "a " → dấu cách gắn vào "a" (D8..D11 Đ)', () {
      expect(_sig(_tok(['a '])), [('a', 1, false)]);
    });
    test('LW-U3-P11 "\\n " → forceBreak rồi token dấu cách (D9 S)', () {
      expect(_sig(_tok(['\n '])), [('', 0, true), ('', 1, false)]);
    });
    test('LW-U3-P12 span " " + span " " → 2 token dấu cách (D10 S) (*)', () {
      expect(_sig(_tok([' ', ' '])), [('', 1, false), ('', 1, false)]);
    });
    test('LW-U3-P13 span "a " + span " " → "a"+1 cách, rồi token dấu cách (D11 S) (*)', () {
      expect(_sig(_tok(['a ', ' '])), [('a', 1, false), ('', 1, false)]);
    });
    test('LW-U3-P14 "a\\n" → "a" rồi forceBreak (D15 S)', () {
      expect(_sig(_tok(['a\n'])), [('a', 0, false), ('', 0, true)]);
    });
    test('LW-U3-P15 "中1中" → 3 token, cùng font Trung (D16 S)', () {
      final ts = _tok(['中1中']);
      expect(_sig(ts), [('中', 0, false), ('1', 0, false), ('中', 0, false)]);
      expect(ts.map((t) => t.face).toSet(), {ScriptFace.chinese});
    });
    test('LW-U3-P16 "ab" maxWidth 0 → không cắt (D17 S, D18 Đ) (*)', () {
      expect(_sig(_tok(['ab'], maxWidth: 0)), [('ab', 0, false)]);
    });
    test('LW-U3-P17 "abc" maxWidth 20 → cắt theo ký tự (D18 S, D19)', () {
      expect(_sig(_tok(['abc'], maxWidth: 20)), [('a', 0, false), ('b', 0, false), ('c', 0, false)]);
    });
    test('LW-U3-P18 "a" maxWidth 5 → cắt còn đúng 1 ký tự (D19 1 vòng)', () {
      expect(_sig(_tok(['a'], maxWidth: 5)), [('a', 0, false)]);
    });
    test('LW-U3-P19 "a中" → 2 đoạn hệ chữ → 2 token khác font (D2 lần 2 Đ)', () {
      final ts = _tok(['a中']);
      expect(_sig(ts), [('a', 0, false), ('中', 0, false)]);
      expect(ts.map((t) => t.face), [ScriptFace.latin, ScriptFace.chinese]);
    });
    test('LW-U3-P20 span "a" + span "b" → 2 token (D1 lần 2 Đ)', () {
      expect(_sig(_tok(['a', 'b'])), [('a', 0, false), ('b', 0, false)]);
    });
  });

  group('U4 wrapTokens', () {
    test('LW-U4-P1 không token → đúng 1 dòng rỗng (D10 S, D11 Đ)', () {
      final ls = wrapTokens(const [], maxWidth: 100);
      expect(ls, hasLength(1));
      expect(ls.single.text, '');
      expect(ls.single.runs, isEmpty);
    });
    test('LW-U4-P2 "a" → 1 dòng, run tại x 0, rộng 10 (D3 S, D5 S, D10 Đ)', () {
      final l = _wrap([const StyledSpan('a')], 100).single;
      expect(l.text, 'a');
      expect(l.runs.single.x, 0);
      expect(l.width, 10);
    });
    test('LW-U4-P3 "a\\n" → forceBreak kết thúc dòng, không thêm dòng (D8 S, D9 Đ, D11 S) (*)', () {
      expect(_wrap([const StyledSpan('a\n')], 100).map((l) => l.text), ['a']);
    });
    test('LW-U4-P4 "aa bb" → gộp 1 run có dấu cách (D5 Đ, D6 Đ, D7 Đ)', () {
      final l = _wrap([const StyledSpan('aa bb')], 1000).single;
      expect(l.runs.single.text, 'aa bb');
      expect(l.width, 45);
    });
    test('LW-U4-P5 "aaa bbb ccc" max 70 → xuống dòng theo từ (D4 Đ)', () {
      expect(_wrap([const StyledSpan('aaa bbb ccc')], 70).map((l) => l.text), ['aaa bbb', 'ccc']);
    });
    test('LW-U4-P6 span "a " + " " + "b" cùng định dạng → 1 run "a  b" (D8 Đ rồi D5 S)', () {
      final l = _wrap([const StyledSpan('a '), const StyledSpan(' '), const StyledSpan('b')], 1000).single;
      final branch = l.runs.length; // nhánh thực đi: số run
      expect(l.text, 'a  b', reason: 'số run thực = $branch');
      expect(l.runs, hasLength(1));
    });
    test('LW-U4-P7 "Hà 河" → 2 run khác font (D6 S)', () {
      final l = _wrap([const StyledSpan('Hà 河')], 1000).single;
      expect(l.runs.map((r) => r.face), [ScriptFace.latin, ScriptFace.chinese]);
    });
    test('LW-U4-P8 "aa " thường + "bb" đậm → 2 run, run 2 tại x 25 (D7 S)', () {
      final l = _wrap([const StyledSpan('aa '), const StyledSpan('bb', bold: true)], 1000).single;
      expect(l.runs.map((r) => r.text), ['aa', 'bb']);
      expect(l.runs[1].x, 25);
    });
    test('LW-U4-P9 "ab\\n\\ncd" → ["ab", "", "cd"] (D9 Đ hai lần)', () {
      expect(_wrap([const StyledSpan('ab\n\ncd')], 100).map((l) => l.text), ['ab', '', 'cd']);
    });
    test('LW-U4-P10 thụt dòng đầu 40, max 70 → ["aaa", "bbb"]', () {
      expect(_wrap([const StyledSpan('aaa bbb')], 70, indent: 40).map((l) => l.text), ['aaa', 'bbb']);
    });
    test('LW-U4-P11 1 token rộng 200 > max 100 → đứng một mình trên 1 dòng (D3 S dù quá rộng)', () {
      const t = LayoutToken(text: 'W', face: ScriptFace.latin, style: StyledSpan('W'), width: 200);
      final ls = wrapTokens(const [t], maxWidth: 100);
      expect(ls, hasLength(1));
      expect(ls.single.width, 200);
    });
    test('LW-U4-P12 " a" → dấu cách đầu dòng giữ làm thụt: run "a" tại x 5 (D8 Đ, D3 S) (*)', () {
      final l = _wrap([const StyledSpan(' a')], 100).single;
      expect(l.runs.single.text, 'a');
      expect(l.runs.single.x, 5);
      expect(l.width, 15);
    });
  });

  group('Phát hiện', () {
    test('LW-PH-1 10 dấu cách + "ab", max 50 → mọi dòng rộng <= maxWidth', () {
      final ls = _wrap([const StyledSpan('          ab')], 50);
      final widths = ls.map((l) => l.width).toList();
      expect(widths.every((w) => w <= 50 + 0.01), isTrue, reason: 'bề rộng dòng thực: $widths');
    });
  });
}
