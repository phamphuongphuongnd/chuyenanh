// Kiểm thử hộp trắng (A05, Bước 6) cho lib/features/convert/text/script_runs.dart.
// Expected chép từ test-output/whitebox/convert/script_runs/buoc-5-du-lieu-thu.md — không chỉnh cho khớp code.
// Hàm private (_isHangul…) được quan sát qua hàm public gọi nó (scriptsIn / isBreakableCjk / splitScriptRuns).
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/convert/text/script_runs.dart';

String _c(int cp) => String.fromCharCode(cp);
String _hex(int cp) => 'U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')}';

const _l = ScriptFace.latin, _zh = ScriptFace.chinese, _ja = ScriptFace.japanese, _ko = ScriptFace.korean;

void main() {
  group('U1 ScriptRun ==', () {
    const a = ScriptRun(_l, 'a');
    test('SR-U1-B1 so với String → false (D1 S)', () {
      // ignore: unrelated_type_equality_checks
      expect(a == ('a' as Object), isFalse);
    });
    test('SR-U1-B2 khác face → false (D2 S)', () => expect(a == const ScriptRun(_zh, 'a'), isFalse));
    test('SR-U1-B3 khác text → false (D3 S)', () => expect(a == const ScriptRun(_l, 'b'), isFalse));
    test('SR-U1-B4 cùng face + text → true', () {
      expect(a == const ScriptRun(_l, 'a'), isTrue);
      expect(a.hashCode, const ScriptRun(_l, 'a').hashCode);
    });
  });

  group('U2 _isHangul (qua scriptsIn ∋ korean)', () {
    final cases = <(String, int, bool)>[
      ('SR-U2-B1', 0x41, false),
      ('SR-U2-B2', 0xAC00, true),
      ('SR-U2-B3', 0xD7B0, true),
      ('SR-U2-B4', 0xE000, false),
      ('SR-U2-B5', 0x1100, true),
      ('SR-U2-B6', 0x1200, false),
      ('SR-U2-B7', 0x3131, true),
      ('SR-U2-B8', 0x3200, false),
      ('SR-U2-B9', 0xA960, true),
      ('SR-U2-B10', 0xA980, false),
    ];
    for (final c in cases) {
      test('${c.$1} ${_hex(c.$2)} → Hangul = ${c.$3}', () {
        expect(scriptsIn(_c(c.$2)).contains(_ko), c.$3);
      });
    }
  });

  group('U3 _isKana (qua scriptsIn ∋ japanese, 1 ký tự)', () {
    final cases = <(String, int, bool)>[
      ('SR-U3-B1', 0x41, false),
      ('SR-U3-B2', 0x3042, true),
      ('SR-U3-B3', 0x3100, false),
      ('SR-U3-B4', 0x31F0, true),
      ('SR-U3-B5', 0x3200, false),
      ('SR-U3-B6', 0xFF66, true),
      ('SR-U3-B7', 0xFFA0, false),
    ];
    for (final c in cases) {
      test('${c.$1} ${_hex(c.$2)} → kana = ${c.$3}', () {
        expect(scriptsIn(_c(c.$2)).contains(_ja), c.$3);
      });
    }
  });

  group('U4 _isHan (qua isBreakableCjk — _isHan đứng đầu)', () {
    final cases = <(String, int, bool)>[
      ('SR-U4-B1', 0x41, false),
      ('SR-U4-B2', 0x4E00, true),
      ('SR-U4-B3', 0x3400, true),
      ('SR-U4-B4', 0x4DC0, false),
      ('SR-U4-B5', 0xA000, false),
      ('SR-U4-B6', 0xF900, true),
      ('SR-U4-B7', 0xFB00, false),
      ('SR-U4-B8', 0x20000, true),
      ('SR-U4-B9', 0x2FA20, false),
    ];
    for (final c in cases) {
      test('${c.$1} ${_hex(c.$2)} → Hán = ${c.$3}', () {
        expect(isBreakableCjk(c.$2), c.$3);
        if (c.$3) expect(scriptsIn(String.fromCharCodes([c.$2])), {_zh});
      });
    }
  });

  group('U5 _isCjkPunct (qua scriptsIn, ký tự không Hangul/kana/Hán)', () {
    final cases = <(String, int, bool)>[
      ('SR-U5-B1', 0x41, false),
      ('SR-U5-B2', 0x3001, true),
      ('SR-U5-B3', 0x3100, false),
      ('SR-U5-B4', 0xFF01, true),
      ('SR-U5-B6', 0xFFE0, true),
      ('SR-U5-B7', 0xFFF0, false),
    ];
    for (final c in cases) {
      test('${c.$1} ${_hex(c.$2)} → dấu câu CJK = ${c.$3}', () {
        expect(scriptsIn(_c(c.$2)), c.$3 ? {_zh} : {_l});
      });
    }
  });

  group('U6 _isNeutral (qua splitScriptRuns("中" + c): trung tính ⇒ 1 đoạn)', () {
    final cases = <(String, int, bool)>[
      ('SR-U6-B1', 0x20, true),
      ('SR-U6-B2', 0x41, false),
      ('SR-U6-B3', 0x5B, true),
      ('SR-U6-B4', 0x61, false),
      ('SR-U6-B5', 0x7B, true),
      ('SR-U6-B6', 0xE9, false),
      ('SR-U6-B7', 0xA0, true),
    ];
    for (final c in cases) {
      test('${c.$1} ${_hex(c.$2)} → trung tính = ${c.$3}', () {
        final runs = splitScriptRuns('中${_c(c.$2)}');
        expect(runs.map((r) => r.face), c.$3 ? [_zh] : [_zh, _l]);
      });
    }
  });

  group('U7 scriptsIn', () {
    final cases = <(String, String, Set<ScriptFace>)>[
      ('SR-U7-B1 chuỗi rỗng (D9 Đ)', '', {_l}),
      ('SR-U7-B2 "a" (D5 S)', 'a', {_l}),
      ('SR-U7-B3 "aa" (lặp latin 2 vòng)', 'aa', {_l}),
      ('SR-U7-B4 "한" (D2 Đ)', '한', {_ko}),
      ('SR-U7-B5 "か" (D3 Đ, D6 Đ)', 'か', {_ja}),
      ('SR-U7-B6 "かか" (lặp kana 2 vòng)', 'かか', {_ja}),
      ('SR-U7-B7 "中" (D4 Đ, D7 Đ, D8 S)', '中', {_zh}),
      ('SR-U7-B8 "中中" (lặp Hán 2 vòng)', '中中', {_zh}),
      ('SR-U7-B9 "。" (D5 Đ)', '。', {_zh}),
      ('SR-U7-B10 "か中" (D8 Đ: Hán theo font Nhật)', 'か中', {_ja}),
    ];
    for (final c in cases) {
      test(c.$1, () => expect(scriptsIn(c.$2), c.$3));
    }
  });

  group('U8 splitScriptRuns', () {
    final cases = <(String, String, List<ScriptRun>)>[
      ('SR-U8-B1 "" → [] (D2 S)', '', []),
      ('SR-U8-B2 "a" (D7 S)', 'a', [const ScriptRun(_l, 'a')]),
      ('SR-U8-B3 " " đầu chuỗi → latin (D7 Đ, D8 S)', ' ', [const ScriptRun(_l, ' ')]),
      ('SR-U8-B4 "a " (D8 Đ, D10 S)', 'a ', [const ScriptRun(_l, 'a ')]),
      ('SR-U8-B5 "한" (D3 Đ)', '한', [const ScriptRun(_ko, '한')]),
      ('SR-U8-B6 "か" (D1 Đ, D4 Đ)', 'か', [const ScriptRun(_ja, 'か')]),
      ('SR-U8-B7 "中" (D5 Đ)', '中', [const ScriptRun(_zh, '中')]),
      ('SR-U8-B8 "。" (D6 Đ)', '。', [const ScriptRun(_zh, '。')]),
      ('SR-U8-B9 "a中" (D10 Đ)', 'a中', [const ScriptRun(_l, 'a'), const ScriptRun(_zh, '中')]),
      ('SR-U8-B10 "か中" → Hán theo font Nhật', 'か中', [const ScriptRun(_ja, 'か中')]),
      ('SR-U8-B11 "中 " → dấu cách theo đoạn trước', '中 ', [const ScriptRun(_zh, '中 ')]),
    ];
    for (final c in cases) {
      test(c.$1, () => expect(splitScriptRuns(c.$2), c.$3));
    }
  });

  group('U9 isBreakableCjk', () {
    test('SR-U9-B1 "中" → true (N1 Đ)', () => expect(isBreakableCjk(0x4E2D), isTrue));
    test('SR-U9-B2 "か" → true (N2 Đ)', () => expect(isBreakableCjk(0x304B), isTrue));
    test('SR-U9-B3 "。" → true (N3 Đ)', () => expect(isBreakableCjk(0x3002), isTrue));
    test('SR-U9-B4 "a" → false (N3 S)', () => expect(isBreakableCjk(0x61), isFalse));
  });

  group('Phát hiện', () {
    test('SR-PH-1 Hangul nửa độ rộng U+FFA1 → font Hàn (wiki: Hangul → Noto Sans KR)', () {
      expect(splitScriptRuns('ﾡ').map((r) => r.face), [_ko]);
      expect(scriptsIn('ﾡ'), contains(_ko));
    });
  });
}
