// Kiểm thử hộp trắng (A05, Bước 6) cho lib/features/convert/text/text_decoder.dart.
// Expected chép từ test-output/whitebox/convert/text_decoder/buoc-5-du-lieu-thu.md — không chỉnh cho khớp code.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/convert/text/text_decoder.dart';

String _d(List<int> b) => decodeTextBytes(Uint8List.fromList(b));

List<int> _le(String s, {bool bom = false}) =>
    [if (bom) ...[0xFF, 0xFE], for (final u in s.codeUnits) ...[u & 0xFF, u >> 8]];
List<int> _be(String s, {bool bom = false}) =>
    [if (bom) ...[0xFE, 0xFF], for (final u in s.codeUnits) ...[u >> 8, u & 0xFF]];

const _fffd = '�';
const _nfd = 'Cà phe'; // "Cà phe" dạng NFD: U+0300 có byte thấp 0x00

void main() {
  group('U1 decodeTextBytes', () {
    test('TD-U1-P1 rỗng → "" (D1 Đ)', () => expect(_d([]), ''));
    test('TD-U1-P2 BOM UTF-8 + "A" → "A" (D5 Đ)', () => expect(_d([0xEF, 0xBB, 0xBF, 0x41]), 'A'));
    test('TD-U1-P3 1 byte "A" → UTF-8 (D2 S, D6 S, D9 S, D12 S)', () => expect(_d([0x41]), 'A'));
    test('TD-U1-P4 "ABC" 3 byte → UTF-8 (D3 S, D7 S, D10 S, D12 S)', () => expect(_d([0x41, 0x42, 0x43]), 'ABC'));
    test('TD-U1-P5 EF 41 42 → U+FFFD + "AB", không ném (D4 S)', () {
      expect(_d([0xEF, 0x41, 0x42]), '${_fffd}AB');
    });
    test('TD-U1-P6 EF BB 41 → có U+FFFD, kết thúc "A", không ném (D5 S)', () {
      final r = _d([0xEF, 0xBB, 0x41]);
      expect(r, contains(_fffd));
      expect(r, endsWith('A'));
    });
    test('TD-U1-P7 BOM UTF-16 LE + "A" → "A" (D8 Đ)', () => expect(_d([0xFF, 0xFE, 0x41, 0x00]), 'A'));
    test('TD-U1-P8 FF 41 → không phải BOM, UTF-8 lỗi → U+FFFD "A" (D8 S)', () {
      expect(_d([0xFF, 0x41]), '${_fffd}A');
    });
    test('TD-U1-P9 BOM UTF-16 BE + "A" → "A" (D11 Đ)', () => expect(_d([0xFE, 0xFF, 0x00, 0x41]), 'A'));
    test('TD-U1-P10 FE 41 → UTF-8 lỗi → U+FFFD "A" (D11 S)', () {
      expect(_d([0xFE, 0x41]), '${_fffd}A');
    });
    test('TD-U1-P12 "abcd" không byte 0 → UTF-8 (D12 Đ, D13 Đ, D15 S, D17 S, D19 S)', () {
      expect(_d([0x61, 0x62, 0x63, 0x64]), 'abcd');
    });
    test('TD-U1-P13 "ab" UTF-16 LE không BOM → "ab" (D16 S, D17 Đ, D18 Đ)', () {
      expect(_d(_le('ab')), 'ab');
    });
    test('TD-U1-P14 "ab" UTF-16 BE không BOM → "ab" (D16 Đ, D19 Đ, D20 Đ)', () {
      expect(_d(_be('ab')), 'ab');
    });
    test('TD-U1-P15 NFD "Cà phe" UTF-16 LE không BOM (6/7 byte lẻ = 0) → đoán UTF-16 LE (D18 S)', () {
      final r = _d(_le(_nfd));
      expect(r.contains('\u0000'), isFalse, reason: 'thực: ${r.codeUnits}');
      expect(r, _nfd);
    });
    test('TD-U1-P16 NFD "Cà phe" UTF-16 BE không BOM (6/7 byte chẵn = 0) → đoán UTF-16 BE (D20 S)', () {
      final r = _d(_be(_nfd));
      expect(r.contains('\u0000'), isFalse, reason: 'thực: ${r.codeUnits}');
      expect(r, _nfd);
    });
    test('TD-U1-P17 4200 byte UTF-16 LE không BOM → chỉ xét 4096 byte đầu, vẫn đúng (D13 S)', () {
      final s = 'a' * 2100;
      expect(_d(_le(s)), s);
    });
    test('TD-U1-P18 chỉ BOM UTF-16 LE → "" (D2 S, D8 Đ)', () => expect(_d([0xFF, 0xFE]), ''));
    test('TD-U1-P19 chỉ BOM UTF-16 BE → "" (D2 S, D11 Đ)', () => expect(_d([0xFE, 0xFF]), ''));
    test('TD-U1-P20 EF BB (BOM thiếu byte) → U+FFFD, không ném (D2 S, D10 S, D12 S)', () {
      expect(_d([0xEF, 0xBB]), contains(_fffd));
    });
  });

  group('U2 _utf16 (qua BOM)', () {
    test('TD-U2-B1 chỉ BOM → vòng lặp 0 lần → "" (D1 S)', () => expect(_d([0xFF, 0xFE]), ''));
    test('TD-U2-B2 LE "AB" (D1 Đ, D2 Đ)', () => expect(_d(_le('AB', bom: true)), 'AB'));
    test('TD-U2-B3 BE "AB" (D2 S)', () => expect(_d(_be('AB', bom: true)), 'AB'));
  });
}
