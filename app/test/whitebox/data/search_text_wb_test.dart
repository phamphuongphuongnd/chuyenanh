// Kiểm thử hộp trắng A12 — app/lib/features/content_index/logic/search_text.dart
// Lưu ý: nhóm U2 (_foldUnit) đặt ĐẦU file vì `_foldCache` là biến toàn cục trong isolate test —
// ký tự "lần đầu" phải chưa xuất hiện ở test nào chạy trước.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/content_index/logic/search_text.dart';

void _ex(Excerpt e, String text, int start, int len) {
  expect((e.text, e.matchStart, e.matchLength), (text, start, len));
}

void main() {
  group('U2 _foldUnit (qua foldForSearch)', () {
    test('F2 chữ có dấu ngoài ASCII, lần đầu ⇒ bỏ dấu, thường (Đ→d)', () {
      expect(foldForSearch('Đ'), 'd');
    });
    test('F10 cùng ký tự lần hai (đã đệm) ⇒ vẫn đúng', () {
      expect(foldForSearch('ĐĐ'), 'dd');
    });
    test('F11 khoảng trắng Unicode (U+3000) lần đầu ⇒ dấu cách', () {
      expect(foldForSearch('　'), ' ');
    });
    test('F12 cặp surrogate (emoji) ⇒ giữ nguyên, cùng độ dài', () {
      expect(foldForSearch('😀'), '😀');
    });
    test('F13 chữ toàn khổ Ａ (≥ U+E000) ⇒ chữ thường ａ', () {
      expect(foldForSearch('Ａ'), 'ａ');
    });
    test('F14 İ ⇒ chữ thường, vẫn đổi 1:1 (một ký tự)', () {
      // Đã sửa test (lần chạy 1): Dart VM thường hoá İ thành 'i' (1 ký tự) nên dữ liệu này
      // không vào nhánh lower.length != 1 — nhánh đó không khả thi trên VM (xem buoc-6).
      final f = foldForSearch('İ');
      expect(f.length, 1);
      expect(f, 'i');
    });
    test('F15 chữ không có trong bảng bỏ dấu (Ж) ⇒ chỉ thường hoá', () {
      expect(foldForSearch('Ж'), 'ж');
    });
    test('F1 chữ ASCII thường ⇒ giữ', () => expect(foldForSearch('b'), 'b'));
    test('F3 ký tự < 0x41 (chữ số) ⇒ giữ', () => expect(foldForSearch('1'), '1'));
    test('F4 A–Z ⇒ a–z', () => expect(foldForSearch('B'), 'b'));
    test('F5–F9 \\t \\n \\r \\v \\f ⇒ dấu cách', () {
      for (final c in ['\t', '\n', '\r', '\u000B', '\u000C']) {
        expect(foldForSearch('x${c}y'), 'x y', reason: c.codeUnitAt(0).toString());
      }
    });
  });

  group('U3 foldForSearch / U4 normalizeForSearch / U5 normalizeQuery', () {
    test('U3.1 chuỗi rỗng ⇒ rỗng', () => expect(foldForSearch(''), ''));
    test('U3.2 chuỗi thường ⇒ đổi từng ký tự, cùng độ dài', () {
      const s = 'Hợp ĐỒNG mua-bán';
      final f = foldForSearch(s);
      expect(f, 'hop dong mua-ban');
      expect(f.length, s.length);
    });
    test('U4.1 NFD được gộp NFC trước rồi bỏ dấu', () {
      expect(normalizeForSearch('Hợp'), 'hop');
    });
    test('U5.1 từ khoá: gộp khoảng trắng, bỏ hai đầu', () {
      expect(normalizeQuery('  Hợp   ĐỒNG '), 'hop dong');
    });
  });

  group('U1 _isSpace (qua prepareContent)', () {
    String prep(String c) => prepareContent('p${c}q').content;
    test('S1 chữ thường ⇒ không phải khoảng trắng', () => expect(prep('a'), 'paq'));
    test('S2 U+0020 ⇒ khoảng trắng', () => expect(prep(' '), 'p q'));
    test('S3 < U+0009 (U+0001) ⇒ không phải khoảng trắng (bị bỏ như ký tự điều khiển)', () {
      expect(prep('\u0001'), 'pq');
    });
    test('S4 \\t ⇒ khoảng trắng', () => expect(prep('\t'), 'p q'));
    test('S5 U+00A0 ⇒ khoảng trắng', () => expect(prep(' '), 'p q'));
    test('S6 U+1680 ⇒ khoảng trắng', () => expect(prep(' '), 'p q'));
    test('S7 U+2000 ⇒ khoảng trắng', () => expect(prep(' '), 'p q'));
    test('S8 U+2010 (> U+200A) ⇒ không phải khoảng trắng', () => expect(prep('‐'), 'p‐q'));
    test('S9 U+2028 ⇒ khoảng trắng (xuống dòng)', () => expect(prep(' '), 'p\nq'));
    test('S10 U+2029 ⇒ khoảng trắng (xuống dòng)', () => expect(prep(' '), 'p\nq'));
    test('S11 U+202F ⇒ khoảng trắng', () => expect(prep(' '), 'p q'));
    test('S12 U+205F ⇒ khoảng trắng', () => expect(prep(' '), 'p q'));
    test('S13 U+3000 ⇒ khoảng trắng', () => expect(prep('　'), 'p q'));
  });

  group('U6 prepareContent', () {
    void ok(String raw, String content, {int? maxChars}) {
      final r = maxChars == null
          ? prepareContent(raw)
          : prepareContent(raw, maxChars: maxChars);
      expect(r.content, content);
      expect(r.normalized, foldForSearch(content));
      expect(r.normalized.length, r.content.length);
    }

    test('C1 một chữ ⇒ giữ', () => ok('a', 'a'));
    test('C2 rỗng ⇒ rỗng', () => ok('', ''));
    test('C3 chỉ khoảng trắng / khoảng trắng cuối ⇒ bỏ', () {
      ok(' ', '');
      ok('a ', 'a');
    });
    test('C4 \\n ⇒ giữ một xuống dòng', () => ok('a\nb', 'a\nb'));
    test('C5 \\r ⇒ xuống dòng', () => ok('a\rb', 'a\nb'));
    test('C6 U+2028 ⇒ xuống dòng', () => ok('a b', 'a\nb'));
    test('C7 U+2029 ⇒ xuống dòng', () => ok('a b', 'a\nb'));
    test('C8 cụm có xuống dòng + dấu cách ⇒ một \\n', () {
      ok('a\n b', 'a\nb');
      ok('a \n\r\n  b', 'a\nb');
    });
    test('C9 ký tự điều khiển < 0x20 ⇒ bỏ', () => ok('a\u0001b', 'ab'));
    test('C10 DEL 0x7F ⇒ bỏ', () => ok('a\u007Fb', 'ab'));
    test('C11 điều khiển C1 (0x80–0x9F) ⇒ bỏ', () => ok('a\u0085b', 'ab'));
    test('C12 chữ Latin-1 có dấu (≥ 0xA0) ⇒ giữ', () => ok('é', 'é'));
    test('C13 BOM U+FEFF ⇒ bỏ', () => ok('﻿ab', 'ab'));
    test('C14 zero-width U+200B–U+200F ⇒ bỏ', () {
      ok('a​b', 'ab');
      ok('a‏b', 'ab');
    });
    test('C15 ký tự > U+200F (€) ⇒ giữ', () => ok('a€', 'a€'));
    test('C16 emoji (ngoài BMP) ⇒ giữ đủ cặp', () => ok('😀', '😀'));
    test('C17 khoảng trắng đầu ⇒ bỏ', () => ok(' a', 'a'));
    test('C18 cụm dấu cách giữa chữ ⇒ một dấu cách', () {
      ok('a b', 'a b');
      ok('a  \t b', 'a b');
    });
    test('C19 vượt maxChars ⇒ cắt, không tách đôi emoji, không để dấu cách thừa', () {
      ok('abc', 'ab', maxChars: 2);
      ok('a😀', 'a', maxChars: 2);
      ok('a b', 'a', maxChars: 2);
    });
    test('C20 NFD tiếng Việt ⇒ gộp NFC', () => ok('Hợp', 'Hợp'));
  });

  group('U7–U10 Excerpt', () {
    test('E1 có chỗ khớp ⇒ hasMatch, before/match/after', () {
      const e = Excerpt('xabcx', 1, 3);
      expect(e.hasMatch, isTrue);
      expect((e.before, e.match, e.after), ('x', 'abc', 'x'));
    });
    test('E2 matchStart −1 ⇒ không khớp; before = cả chữ', () {
      const e = Excerpt('xyz', -1, 0);
      expect(e.hasMatch, isFalse);
      expect((e.before, e.match, e.after), ('xyz', '', ''));
    });
    test('E3 matchStart ≥ 0 nhưng độ dài 0 ⇒ không khớp', () {
      const e = Excerpt('xyz', 0, 0);
      expect(e.hasMatch, isFalse);
      expect((e.before, e.match, e.after), ('xyz', '', ''));
    });
  });

  group('U11 _isWs (qua buildExcerpt, phần bỏ khoảng trắng đầu)', () {
    test('W1–W4 dấu cách / \\n / \\t / \\r ở đầu ⇒ bị bỏ', () {
      for (final c in [' ', '\n', '\t', '\r']) {
        _ex(buildExcerpt('${c}abc', 'abc', atStart: false), '…abc', 1, 3);
      }
    });
    test('W5 chữ thường ở đầu ⇒ giữ', () {
      _ex(buildExcerpt('xabc', 'abc', atStart: false), '…xabc', 2, 3);
    });
  });

  const l0 = 'aaaa bbbb cccc dddd key eeee ffff gggg hhhh';

  group('U14 buildExcerpt (+ U12 _isHigh, U13 _isLow)', () {
    test('B1 chữ ngắn có khớp ⇒ cả đoạn, không …', () => _ex(buildExcerpt('abc', 'b'), 'abc', 1, 1));
    test('B2 từ khoá rỗng ⇒ đầu đoạn, không tô', () => _ex(buildExcerpt('abc', ''), 'abc', -1, 0));
    test('B3 không khớp ⇒ đầu đoạn, không tô', () => _ex(buildExcerpt('abc', 'zz'), 'abc', -1, 0));
    test('B5 không khớp, dài hơn maxLength ⇒ maxLength ký tự đầu + …', () {
      _ex(buildExcerpt('abcdef', 'zz', maxLength: 4), 'abcd…', -1, 0);
    });
    test('B6 từ khoá dài hơn maxLength ⇒ hiện đủ từ khoá, … hai phía', () {
      _ex(buildExcerpt('xxabcdxx', 'abcd', maxLength: 3), '…abcd…', 1, 4);
    });
    test('B7 khớp giữa chữ dài ⇒ cắt quanh từ khoá, bám ranh giới từ', () {
      _ex(buildExcerpt(l0, 'key', maxLength: 12), '…key eeee…', 1, 3);
    });
    test('B8 khớp ở cuối ⇒ dời cửa sổ sang trái, không … phía sau', () {
      _ex(buildExcerpt(l0, 'hhhh', maxLength: 12), '…gggg hhhh', 6, 4);
    });
    test('B9 chữ ngắn hơn maxLength, khớp gần cuối ⇒ cả đoạn', () {
      _ex(buildExcerpt('abcdefghijk', 'k', maxLength: 20), 'abcdefghijk', 10, 1);
    });
    test('B10 khớp ở đầu ⇒ không … phía trước, cắt sau ở ranh giới từ', () {
      _ex(buildExcerpt(l0, 'aaaa', maxLength: 12), 'aaaa bbbb…', 0, 4);
    });
    test('B11 điểm cắt đầu đã ở ranh giới từ ⇒ giữ nguyên', () {
      _ex(buildExcerpt(l0, 'key', maxLength: 14), '…dddd key eeee…', 6, 3);
    });
    test('B12 chữ dính liền tới từ khoá ⇒ không tìm được ranh giới phía trước', () {
      _ex(buildExcerpt('abcdefghijkey tail', 'key', maxLength: 9), '…hijkey…', 4, 3);
    });
    test('B13 từ dài hơn 15 ký tự trước từ khoá ⇒ không bám ranh giới (mất quá nhiều)', () {
      _ex(
        buildExcerpt('${'z' * 40}key end', 'key', maxLength: 40),
        '…${'z' * 33}key end',
        34,
        3,
      );
    });
    test('B14 ranh giới từ ngay tại điểm cắt ⇒ cắt sát từ khoá', () {
      _ex(buildExcerpt(l0, 'key', maxLength: 6), '…key…', 1, 3);
    });
    test('B15 khớp chạm cuối, maxLength = độ dài từ khoá ⇒ chỉ từ khoá', () {
      _ex(buildExcerpt(l0, 'hhhh', maxLength: 4), '…hhhh', 1, 4);
    });
    test('B16 chữ vừa bằng maxLength ⇒ cả đoạn', () {
      _ex(buildExcerpt('ab cd', 'cd', maxLength: 5), 'ab cd', 3, 2);
    });
    test('B17 chữ dính liền sau từ khoá ⇒ không tìm được ranh giới phía sau', () {
      _ex(buildExcerpt('head keyabcdefghij', 'key', maxLength: 9), '…keyabc…', 1, 3);
    });
    test('B18 từ dài hơn 15 ký tự sau từ khoá ⇒ không bám ranh giới', () {
      _ex(
        buildExcerpt('key${'q' * 40}', 'key', maxLength: 40),
        'key${'q' * 37}…',
        0,
        3,
      );
    });
    test('B22 / L1 điểm cắt đầu rơi vào nửa sau emoji ⇒ bỏ cả emoji', () {
      _ex(buildExcerpt('😀abc', 'bc', maxLength: 4), '…abc', 2, 2);
    });
    test('B23 window rỗng ⇒ rỗng', () => _ex(buildExcerpt('', 'zz'), '', -1, 0));
    test('B25 / H1 điểm cắt cuối rơi vào nửa đầu emoji ⇒ bỏ cả emoji', () {
      _ex(buildExcerpt('ab😀cd', 'zz', maxLength: 3), 'ab…', -1, 0);
    });
    test('B28 khoảng trắng đầu, không phải đầu nội dung ⇒ bỏ khoảng trắng, có …', () {
      _ex(buildExcerpt(' abc', 'abc', atStart: false), '…abc', 1, 3);
    });
    test('B31 khoảng trắng cuối, không phải cuối nội dung ⇒ bỏ khoảng trắng, có …', () {
      _ex(buildExcerpt('abc ', 'abc', atEnd: false), 'abc…', 0, 3);
    });
    test('B33 atStart false ⇒ … phía trước dù đủ ngắn', () {
      _ex(buildExcerpt('abc', 'b', atStart: false), '…abc', 2, 1);
    });
    test('B35 atEnd false ⇒ … phía sau dù đủ ngắn', () {
      _ex(buildExcerpt('abc', 'b', atEnd: false), 'abc…', 1, 1);
    });
    test('B37 hai khoảng trắng đầu ⇒ bỏ cả hai', () {
      _ex(buildExcerpt('  abc', 'abc', atStart: false), '…abc', 1, 3);
    });
    test('B38 không khớp, khoảng trắng đầu ⇒ bỏ', () {
      _ex(buildExcerpt('  ab', 'zz', atStart: false), '…ab', -1, 0);
    });
    test('B39 không khớp, khoảng trắng cuối ⇒ bỏ', () {
      _ex(buildExcerpt('ab  ', 'zz', atEnd: false), 'ab…', -1, 0);
    });
    test('B40 xuống dòng trong đoạn ⇒ hiện thành dấu cách', () {
      _ex(buildExcerpt('a\nb', 'b'), 'a b', 2, 1);
    });
    test('B41 / H3 điểm cắt cuối ngay sau emoji (nửa sau) ⇒ giữ emoji', () {
      _ex(buildExcerpt('ab😀cd', 'zz', maxLength: 4), 'ab😀…', -1, 0);
    });
    test('B42 / L2 điểm cắt đầu ở nửa đầu emoji ⇒ giữ emoji', () {
      _ex(buildExcerpt('x😀abc', 'bc', maxLength: 5), '…😀abc', 4, 2);
    });
    test('B43 / L3 điểm cắt đầu ở ký tự ≥ U+E000 ⇒ không coi là nửa emoji', () {
      _ex(buildExcerpt('zａbc', 'bc', maxLength: 3), '…ａbc', 2, 2);
    });
    test('B44 (bổ sung) từ khoá rỗng, chữ dài ⇒ maxLength ký tự đầu + …', () {
      _ex(buildExcerpt('abcdef', '', maxLength: 4), 'abcd…', -1, 0);
    });
    test('BX (mức unit) chỉ khoảng trắng bị cắt ở đầu/cuối nội dung ⇒ không thêm …', () {
      // Yêu cầu (comment :151): "thêm … ở phía còn chữ"; atStart/atEnd = đầu/cuối nội dung.
      _ex(buildExcerpt(' abc', 'abc'), 'abc', 0, 3);
      _ex(buildExcerpt('abc ', 'abc'), 'abc', 0, 3);
    });
  });
}
