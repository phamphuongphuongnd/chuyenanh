// Kiểm thử hộp trắng A08 — data/text_decoder.dart. Mã bộ theo
// test-output/whitebox/office-viewer/text_decoder/buoc-5-du-lieu-thu.md. Expected chép từ Bước 5.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/office_viewer/data/text_decoder.dart';
import 'package:pdf_office/features/office_viewer/logic/text_search.dart';

Uint8List _b(List<int> v) => Uint8List.fromList(v);

List<int> _le(String s) => [for (final u in s.codeUnits) ...[u & 0xFF, u >> 8]];
List<int> _be(String s) => [for (final u in s.codeUnits) ...[u >> 8, u & 0xFF]];

void main() {
  group('U1 decodeText', () {
    test('U1-P1 "abc" ⇒ UTF-8', () {
      final r = decodeText(_b(utf8.encode('abc')));
      expect(r.encoding, TextEncoding.utf8);
      expect(r.text, 'abc');
    });
    test('U1-P2 "ab" (n < 3) ⇒ UTF-8', () {
      final r = decodeText(_b(utf8.encode('ab')));
      expect(r.encoding, TextEncoding.utf8);
      expect(r.text, 'ab');
    });
    test('U1-P3 EF B8 80 (không phải BOM) ⇒ UTF-8 U+FE00', () {
      final r = decodeText(_b([0xEF, 0xB8, 0x80]));
      expect(r.encoding, TextEncoding.utf8);
      expect(r.text, '︀');
    });
    test('U1-P4 EF BB BE (gần BOM) ⇒ UTF-8 U+FEFE', () {
      final r = decodeText(_b([0xEF, 0xBB, 0xBE]));
      expect(r.encoding, TextEncoding.utf8);
      expect(r.text, '﻾');
    });
    test('U1-P5 BOM UTF-8 + "A" ⇒ UTF-8 BOM, bỏ BOM', () {
      final r = decodeText(_b([0xEF, 0xBB, 0xBF, 0x41]));
      expect(r.encoding, TextEncoding.utf8Bom);
      expect(r.text, 'A');
    });
    test('U1-P6 "a" (n = 1) ⇒ UTF-8', () {
      final r = decodeText(_b([0x61]));
      expect(r.encoding, TextEncoding.utf8);
      expect(r.text, 'a');
    });
    test('U1-P7 FF 41 ⇒ Windows-1252 "ÿA"', () {
      final r = decodeText(_b([0xFF, 0x41]));
      expect(r.encoding, TextEncoding.windows1252);
      expect(r.text, 'ÿA');
    });
    test('U1-P8 BOM FF FE + "A" LE ⇒ UTF-16 LE', () {
      final r = decodeText(_b([0xFF, 0xFE, 0x41, 0x00]));
      expect(r.encoding, TextEncoding.utf16le);
      expect(r.text, 'A');
    });
    test('U1-P9 FE 41 ⇒ Windows-1252 "þA"', () {
      final r = decodeText(_b([0xFE, 0x41]));
      expect(r.encoding, TextEncoding.windows1252);
      expect(r.text, 'þA');
    });
    test('U1-P10 BOM FE FF + "A" BE ⇒ UTF-16 BE', () {
      final r = decodeText(_b([0xFE, 0xFF, 0x00, 0x41]));
      expect(r.encoding, TextEncoding.utf16be);
      expect(r.text, 'A');
    });
    test('U1-P11 "Hello" LE không BOM ⇒ UTF-16 LE', () {
      final r = decodeText(_b(_le('Hello')));
      expect(r.encoding, TextEncoding.utf16le);
      expect(r.text, 'Hello');
    });
    test('U1-P12 "Hello" BE không BOM ⇒ UTF-16 BE', () {
      final r = decodeText(_b(_be('Hello')));
      expect(r.encoding, TextEncoding.utf16be);
      expect(r.text, 'Hello');
    });
    test('U1-P13 "abc" truncated ⇒ UTF-8, cờ truncated', () {
      final r = decodeText(_b(utf8.encode('abc')), truncated: true);
      expect(r.encoding, TextEncoding.utf8);
      expect(r.text, 'abc');
      expect(r.truncated, isTrue);
    });
    test('U1-P14 "ab" + 2 byte đầu của "ạ", truncated ⇒ bỏ byte dở, "ab"', () {
      final r = decodeText(_b([0x61, 0x62, 0xE1, 0xBA]), truncated: true);
      expect(r.encoding, TextEncoding.utf8);
      expect(r.text, 'ab');
      expect(r.truncated, isTrue);
    });
    test('U1-P15 UTF-8 tiếng Việt + 1 byte rác ⇒ vẫn UTF-8', () {
      final good = utf8.encode('Tiếng Việt có dấu đầy đủ ở đây nhé. ');
      final r = decodeText(_b([...good, 0xFF, ...good]));
      expect(r.encoding, TextEncoding.utf8);
      expect(r.text, contains('đầy đủ ở đây'));
    });
    test('U1-P16 "caf" + E9 (1252 thật) ⇒ Windows-1252 "café"', () {
      final r = decodeText(_b([0x63, 0x61, 0x66, 0xE9]));
      expect(r.encoding, TextEncoding.windows1252);
      expect(r.text, 'café');
    });
    test('U1-P18 truncated, byte lỗi ở đầu (cắt 3 byte vẫn lỗi) ⇒ Windows-1252', () {
      final r = decodeText(_b([0xE9, 0x61, 0x62, 0x63, 0x64]), truncated: true);
      expect(r.encoding, TextEncoding.windows1252);
      expect(r.text, 'éabcd');
      expect(r.truncated, isTrue);
    });
  });

  group('U2 _lenientUtf8 (qua decodeText)', () {
    final e = utf8.encode('é');
    List<int> rep(int k) => [for (var i = 0; i < k; i++) ...e];
    test('U2-P1 10 ký tự ngoài ASCII + 1 byte rác ⇒ UTF-8', () {
      final r = decodeText(_b([...rep(10), 0xFF]));
      expect(r.encoding, TextEncoding.utf8);
      expect(r.text, startsWith('é' * 10));
    });
    test('U2-P2 9 ký tự ngoài ASCII + 1 byte rác ⇒ Windows-1252', () {
      final r = decodeText(_b([...rep(9), 0xFF]));
      expect(r.encoding, TextEncoding.windows1252);
    });
    test('U2-P3 FF + "a" (valid = 0) ⇒ Windows-1252', () {
      final r = decodeText(_b([0xFF, 0x61]));
      expect(r.encoding, TextEncoding.windows1252);
      expect(r.text, 'ÿa');
    });
    test('U2-P4 chỉ FF ⇒ Windows-1252 "ÿ"', () {
      final r = decodeText(_b([0xFF]));
      expect(r.encoding, TextEncoding.windows1252);
      expect(r.text, 'ÿ');
    });
    test('U2-P5 10 é + "a" + FF ⇒ UTF-8 (ASCII không tính)', () {
      final r = decodeText(_b([...rep(10), 0x61, 0xFF]));
      expect(r.encoding, TextEncoding.utf8);
      expect(r.text, startsWith('${'é' * 10}a'));
    });
  });

  group('U3 _guessUtf16WithoutBom (qua decodeText)', () {
    test('U3-P1 "Hello" LE ⇒ LE', () {
      expect(decodeText(_b(_le('Hello'))).encoding, TextEncoding.utf16le);
    });
    test('U3-P2 LE dài 4200 byte (> 4096) ⇒ LE, giải mã đủ', () {
      final s = 'abcdefghij' * 210;
      final r = decodeText(_b(_le(s)));
      expect(r.encoding, TextEncoding.utf16le);
      expect(r.text, s);
    });
    test('U3-P3 "abc" (len < 4) ⇒ không phải UTF-16 ⇒ UTF-8', () {
      expect(decodeText(_b(utf8.encode('abc'))).encoding, TextEncoding.utf8);
    });
    test('U3-P4 9×(41 00) + (00 00) ⇒ không phải UTF-16 ⇒ UTF-8', () {
      final r = decodeText(_b([for (var i = 0; i < 9; i++) ...[0x41, 0x00], 0x00, 0x00]));
      expect(r.encoding, TextEncoding.utf8);
    });
    test('U3-P5 "abcdef" ASCII ⇒ UTF-8', () {
      expect(decodeText(_b(utf8.encode('abcdef'))).encoding, TextEncoding.utf8);
    });
    test('U3-P6 "Hello" BE ⇒ BE', () {
      expect(decodeText(_b(_be('Hello'))).encoding, TextEncoding.utf16be);
    });
    test('U3-P7 9×(00 41) + (00 00) ⇒ không phải UTF-16 ⇒ UTF-8', () {
      final r = decodeText(_b([for (var i = 0; i < 9; i++) ...[0x00, 0x41], 0x00, 0x00]));
      expect(r.encoding, TextEncoding.utf8);
    });
    test('U3-P9 "Helloếế" LE (cặp không byte 0) ⇒ LE', () {
      final r = decodeText(_b(_le('Helloếế')));
      expect(r.encoding, TextEncoding.utf16le);
      expect(r.text, 'Helloếế');
    });
    test('U3-P10 "Helloế" BE ⇒ BE', () {
      final r = decodeText(_b(_be('Helloế')));
      expect(r.encoding, TextEncoding.utf16be);
      expect(r.text, 'Helloế');
    });
  });

  group('U4 _utf16', () {
    test('U4-P1 LE BOM "A" ⇒ "A"', () {
      expect(decodeText(_b([0xFF, 0xFE, 0x41, 0x00])).text, 'A');
    });
    test('U4-P2 BE BOM "A" ⇒ "A"', () {
      expect(decodeText(_b([0xFE, 0xFF, 0x00, 0x41])).text, 'A');
    });
    test('U4-P3 chỉ BOM LE ⇒ chuỗi rỗng, UTF-16 LE', () {
      final r = decodeText(_b([0xFF, 0xFE]));
      expect(r.encoding, TextEncoding.utf16le);
      expect(r.text, '');
    });
  });

  group('U5 _windows1252', () {
    test('U5-P1 0x80 ⇒ "€"', () {
      final r = decodeText(_b([0x80]));
      expect(r.encoding, TextEncoding.windows1252);
      expect(r.text, '€');
    });
    test('U5-P2 0xE9 ⇒ "é"', () {
      expect(decodeText(_b([0xE9])).text, 'é');
    });
    test('U5-P3 0xE9 0x41 ⇒ "éA"', () {
      expect(decodeText(_b([0xE9, 0x41])).text, 'éA');
    });
  });

  group('U6 splitLinesCapped', () {
    test('U6-P1 "ab", maxLen 3 ⇒ ["ab"]', () {
      expect(splitLinesCapped('ab', maxLen: 3), ['ab']);
    });
    test('U6-P3 "abcde", maxLen 3 ⇒ ["abc","de"]', () {
      expect(splitLinesCapped('abcde', maxLen: 3), ['abc', 'de']);
    });
    test('U6-P5 "ab😀c", maxLen 3 ⇒ không cắt giữa cặp surrogate', () {
      expect(splitLinesCapped('ab😀c', maxLen: 3), ['ab', '😀c']);
    });
    test('U6-P6 "a😀bc", maxLen 3 (ký tự cuối là low surrogate) ⇒ ["a😀","bc"]', () {
      expect(splitLinesCapped('a😀bc', maxLen: 3), ['a😀', 'bc']);
    });
    test('U6-P7 "abcd\\nx", maxLen 3 ⇒ ["abc","d","x"]', () {
      expect(splitLinesCapped('abcd\nx', maxLen: 3), ['abc', 'd', 'x']);
    });
  });

  group('U7 findHitsLimited', () {
    test('U7-P1 "a b a" tìm "a" ⇒ 2 kết quả, không cắt', () {
      final r = findHitsLimited(['a b a'], 'a', limit: 5);
      expect(r.hits, const [SearchHit(0, 0, 1), SearchHit(0, 4, 1)]);
      expect(r.truncated, isFalse);
    });
    test('U7-P2 truy vấn chỉ khoảng trắng ⇒ rỗng', () {
      final r = findHitsLimited(['a'], '  ');
      expect(r.hits, isEmpty);
      expect(r.truncated, isFalse);
    });
    test('U7-P3 không khối ⇒ rỗng', () {
      final r = findHitsLimited(const [], 'a');
      expect(r.hits, isEmpty);
      expect(r.truncated, isFalse);
    });
    test('U7-P4 khối không khớp ⇒ rỗng', () {
      final r = findHitsLimited(['xyz'], 'a');
      expect(r.hits, isEmpty);
      expect(r.truncated, isFalse);
    });
    test('U7-P5 "aaa", limit 2 ⇒ 2 kết quả, truncated', () {
      final r = findHitsLimited(['aaa'], 'a', limit: 2);
      expect(r.hits.length, 2);
      expect(r.truncated, isTrue);
    });
    test('U7-P5b mặc định: 5.001 chỗ khớp ⇒ giữ 5.000, truncated', () {
      final r = findHitsLimited(['a' * 5001], 'a');
      expect(r.hits.length, 5000);
      expect(r.truncated, isTrue);
    });
  });

  group('U8 readTextFile', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('wb_a08_txt'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('U8-P1 file nhỏ ⇒ đọc hết, không truncated', () async {
      final f = File('${dir.path}/a.txt')..writeAsBytesSync(utf8.encode('xin chào'));
      final r = await readTextFile(f.path);
      expect(r.text, 'xin chào');
      expect(r.truncated, isFalse);
    });
    test('U8-P2 file > 20 MB ⇒ chỉ đọc 20 MB đầu, truncated', () async {
      final f = File('${dir.path}/big.txt')
        ..writeAsBytesSync(Uint8List(maxTextBytes + 10)..fillRange(0, maxTextBytes + 10, 0x61));
      final r = await readTextFile(f.path);
      expect(r.truncated, isTrue);
      expect(r.text.length, maxTextBytes);
    });
  });
}
