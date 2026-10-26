import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/convert/text/line_wrap.dart';
import 'package:pdf_office/features/convert/text/script_runs.dart';
import 'package:pdf_office/features/convert/text/text_decoder.dart';
import 'package:pdf_office/features/convert/text/vietnamese_nfc.dart';

/// Đo giả: mỗi ký tự rộng 10, dấu cách rộng 5.
class _FakeMeasurer implements TextMeasurer {
  @override
  double width(ScriptFace face, StyledSpan style, String text) => text.runes.length * 10.0;

  @override
  double spaceWidth(ScriptFace face, StyledSpan style) => 5;
}

List<String> _wrap(String text, double maxWidth, {double firstLineIndent = 0}) {
  final tokens = tokenize([StyledSpan(text)], _FakeMeasurer(), maxWidth: maxWidth);
  return wrapTokens(tokens, maxWidth: maxWidth, firstLineIndent: firstLineIndent)
      .map((l) => l.text)
      .toList();
}

void main() {
  group('composeVietnamese', () {
    test('NFD -> NFC', () {
      expect(composeVietnamese('ặ'), 'ặ');
      expect(composeVietnamese('ặ'), 'ặ');
      expect(composeVietnamese('ỗ'), 'ỗ');
      expect(composeVietnamese('ữ'), 'ữ');
      expect(composeVietnamese('ẫ'), 'ẫ');
      expect(composeVietnamese('ậ'), 'ậ');
      expect(composeVietnamese('ề'), 'ề');
      expect(composeVietnamese('ở'), 'ở');
      expect(composeVietnamese('Nguyễn Thị'), 'Nguyễn Thị');
      expect(composeVietnamese('Đại'), 'Đại');
      expect(composeVietnamese('Ấ'), 'Ấ');
    });

    test('chuỗi đã NFC / không phải tiếng Việt giữ nguyên', () {
      expect(composeVietnamese('Tiếng Việt ặ ỗ'), 'Tiếng Việt ặ ỗ');
      expect(composeVietnamese('Hello 中文 abc 한국어'), 'Hello 中文 abc 한국어');
      expect(composeVietnamese(''), '');
    });

    test('dấu rời không ghép được thì giữ nguyên', () {
      expect(composeVietnamese('b́'), 'b́');
    });
  });

  group('normalizeForPdf', () {
    test('xuống dòng, tab, ký tự điều khiển, BOM', () {
      expect(normalizeForPdf('a\r\nb\rc'), 'a\nb\nc');
      expect(normalizeForPdf('a\tb'), 'a    b');
      expect(normalizeForPdf('﻿x​y\u0007z'), 'xyz');
      expect(normalizeForPdf('a b'), 'a\nb');
    });

    test('gộp NFC', () {
      expect(normalizeForPdf('Việt'), 'Việt');
    });
  });

  group('splitScriptRuns', () {
    test('Latin/Việt một đoạn', () {
      expect(splitScriptRuns('Hà Nội 2026'), [const ScriptRun(ScriptFace.latin, 'Hà Nội 2026')]);
    });

    test('trộn Việt + Hán + Hangul + kana', () {
      final runs = splitScriptRuns('Hà Nội 河内 하노이 ハノイ');
      expect(runs.map((r) => r.face), [
        ScriptFace.latin,
        ScriptFace.japanese, // câu có kana: Hán tự dùng font Nhật
        ScriptFace.korean,
        ScriptFace.japanese,
      ]);
      expect(runs.map((r) => r.text).join(), 'Hà Nội 河内 하노이 ハノイ');
    });

    test('Hán không có kana dùng font Trung; dấu cách theo đoạn trước', () {
      final runs = splitScriptRuns('abc 中文 def');
      expect(runs, [
        const ScriptRun(ScriptFace.latin, 'abc '),
        const ScriptRun(ScriptFace.chinese, '中文 '),
        const ScriptRun(ScriptFace.latin, 'def'),
      ]);
    });

    test('scriptsIn', () {
      expect(scriptsIn('Xin chào'), {ScriptFace.latin});
      expect(scriptsIn(''), {ScriptFace.latin});
      expect(scriptsIn('中文'), {ScriptFace.chinese});
      expect(scriptsIn('かな 漢字'), {ScriptFace.latin, ScriptFace.japanese});
      expect(scriptsIn('한글'), {ScriptFace.korean});
    });
  });

  group('wrapTokens', () {
    test('xuống dòng theo từ, bỏ dấu cách cuối dòng', () {
      // "aaa bbb ccc" mỗi từ 30, dấu cách 5: 30+5+30=65 <= 70, thêm 5+30 > 70
      expect(_wrap('aaa bbb ccc', 70), ['aaa bbb', 'ccc']);
    });

    test('từ quá dài bị cắt theo ký tự', () {
      final lines = _wrap('abcdefghij', 50); // 10 ký tự = 100 > 50 -> mỗi dòng 5 ký tự
      expect(lines, ['abcde', 'fghij']);
    });

    test('đoạn rỗng cho một dòng rỗng', () {
      expect(_wrap('', 100), ['']);
    });

    test('xuống dòng cứng', () {
      expect(_wrap('ab\n\ncd', 100), ['ab', '', 'cd']);
    });

    test('CJK ngắt giữa các chữ', () {
      expect(_wrap('一二三四五六', 30), ['一二三', '四五六']);
    });

    test('thụt dòng đầu', () {
      // thụt 40: dòng đầu còn 30 -> chỉ vừa "aaa"
      expect(_wrap('aaa bbb', 70, firstLineIndent: 40), ['aaa', 'bbb']);
    });

    test('gộp từ cùng định dạng thành một run có dấu cách', () {
      final tokens = tokenize([const StyledSpan('aa bb  cc')], _FakeMeasurer(), maxWidth: 1000);
      final lines = wrapTokens(tokens, maxWidth: 1000);
      expect(lines, hasLength(1));
      expect(lines.single.runs, hasLength(1));
      expect(lines.single.runs.single.text, 'aa bb  cc');
      expect(lines.single.width, 20 + 5 + 20 + 10 + 20);
    });

    test('khác định dạng thì tách run', () {
      final tokens = tokenize(
        [const StyledSpan('aa '), const StyledSpan('bb', bold: true)],
        _FakeMeasurer(),
        maxWidth: 1000,
      );
      final line = wrapTokens(tokens, maxWidth: 1000).single;
      expect(line.runs.map((r) => r.text), ['aa', 'bb']);
      expect(line.runs[1].x, 25); // 20 + dấu cách 5
    });

    test('chữ Latin + CJK trên cùng dòng thành hai run, đúng font', () {
      final tokens = tokenize([const StyledSpan('Hà 河')], _FakeMeasurer(), maxWidth: 1000);
      final line = wrapTokens(tokens, maxWidth: 1000).single;
      expect(line.runs.map((r) => r.face), [ScriptFace.latin, ScriptFace.chinese]);
    });
  });

  group('decodeTextBytes', () {
    test('UTF-8 có và không BOM', () {
      final raw = utf8.encode('Tiếng Việt');
      expect(decodeTextBytes(Uint8List.fromList(raw)), 'Tiếng Việt');
      expect(decodeTextBytes(Uint8List.fromList([0xEF, 0xBB, 0xBF, ...raw])), 'Tiếng Việt');
    });

    test('UTF-16 LE/BE có BOM', () {
      final units = 'Việt 中'.codeUnits;
      final le = <int>[0xFF, 0xFE];
      final be = <int>[0xFE, 0xFF];
      for (final u in units) {
        le.addAll([u & 0xFF, u >> 8]);
        be.addAll([u >> 8, u & 0xFF]);
      }
      expect(decodeTextBytes(Uint8List.fromList(le)), 'Việt 中');
      expect(decodeTextBytes(Uint8List.fromList(be)), 'Việt 中');
    });

    test('UTF-16 LE không BOM với chữ ASCII', () {
      final bytes = <int>[];
      for (final u in 'hello world'.codeUnits) {
        bytes.addAll([u, 0]);
      }
      expect(decodeTextBytes(Uint8List.fromList(bytes)), 'hello world');
    });

    test('rỗng và UTF-8 lỗi không ném', () {
      expect(decodeTextBytes(Uint8List(0)), '');
      expect(decodeTextBytes(Uint8List.fromList([0x61, 0xFF, 0x62])), contains('a'));
    });
  });
}
