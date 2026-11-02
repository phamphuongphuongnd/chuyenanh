// Kiểm thử hộp trắng (A05, Bước 6) cho lib/features/convert/text/vietnamese_nfc.dart.
// Expected chép từ test-output/whitebox/convert/vietnamese_nfc/buoc-5-du-lieu-thu.md — không chỉnh cho khớp code.
// Chuỗi NFD viết bằng mã \u để không bị trình soạn thảo tự chuẩn hoá.
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/convert/text/vietnamese_nfc.dart';

void main() {
  group('U1 _isShape (qua composeVietnamese)', () {
    test('VN-U1-B1 a + U+0302 → â (N1 Đ)', () => expect(composeVietnamese('â'), 'â'));
    test('VN-U1-B2 a + U+0306 → ă (N2 Đ)', () => expect(composeVietnamese('ă'), 'ă'));
    test('VN-U1-B3 o + U+031B → ơ (N3 Đ)', () => expect(composeVietnamese('ơ'), 'ơ'));
    test('VN-U1-B4 a + U+0301 (không phải dấu hình) → á (N3 S)', () {
      expect(composeVietnamese('á'), 'á');
    });
  });

  group('U2 composeVietnamese', () {
    final cases = <(String, String, String)>[
      ('VN-U2-P1 rỗng → "" (D1 S, D4 Đ)', '', ''),
      ('VN-U2-P2 "ab" không dấu rời → nguyên (D3 S, D4 Đ)', 'ab', 'ab'),
      ('VN-U2-P3 a + sắc → á (D8 Đ, D9 S, D11 Đ, D12 S)', 'á', 'á'),
      ('VN-U2-P4 a + mũ → â (D7 Đ, D9 Đ, D10 S, D11 S)', 'â', 'â'),
      ('VN-U2-P5 b + mũ → giữ nguyên (D10 Đ)', 'b̂', 'b̂'),
      ('VN-U2-P6 b + sắc → giữ nguyên (D12 Đ)', 'b́', 'b́'),
      ('VN-U2-P7 a + sắc + b → áb (D8 S)', 'áb', 'áb'),
      ('VN-U2-P8 a + mũ + sắc → ấ', 'ấ', 'ấ'),
      ('VN-U2-P9 a + sắc + mũ → ấ (thứ tự bất kỳ)', 'á̂', 'ấ'),
      ('VN-U2-P10 b a + sắc → bá (D1 lần 2, D2 S → D3 Đ)', 'bá', 'bá'),
      ('VN-U2-P11 Nguye + mũ + ngã + n → Nguyễn (D5 nhiều vòng)', 'Nguyễn', 'Nguyễn'),
      ('VN-U2-P12 u + râu + nặng → ự', 'ự', 'ự'),
      ('VN-U2-P13 A + trăng + ngã → Ẵ', 'Ẵ', 'Ẵ'),
    ];
    for (final c in cases) {
      test(c.$1, () => expect(composeVietnamese(c.$2), c.$3));
    }
  });

  group('U3 normalizeForPdf', () {
    final cases = <(String, String, String)>[
      ('VN-U3-P1 rỗng (D1 S)', '', ''),
      ('VN-U3-P2 "a" giữ (D11 S)', 'a', 'a'),
      ('VN-U3-P3 LF giữ (D2 Đ)', 'a\nb', 'a\nb'),
      ('VN-U3-P4 tab → 4 dấu cách (D3 Đ)', 'a\tb', 'a    b'),
      ('VN-U3-P5 U+0007 bỏ (D4 Đ)', 'a\u0007b', 'ab'),
      ('VN-U3-P6 U+007F bỏ (D5 Đ)', 'a\u007Fb', 'ab'),
      ('VN-U3-P7 U+0085 (C1) bỏ (D7 Đ)', 'a\u0085b', 'ab'),
      ('VN-U3-P8 é giữ (D7 S)', 'aéb', 'aéb'),
      ('VN-U3-P9 U+2028 → LF (D8 Đ) (*)', 'a b', 'a\nb'),
      ('VN-U3-P10 U+2029 → LF (D9 Đ) (*)', 'a b', 'a\nb'),
      ('VN-U3-P11 BOM U+FEFF bỏ (D10 Đ)', 'a﻿b', 'ab'),
      ('VN-U3-P12 U+200B zero-width bỏ (D12 Đ)', 'a​b', 'ab'),
      ('VN-U3-P13 U+2010 gạch nối giữ (D12 S)', 'a‐b', 'a‐b'),
    ];
    for (final c in cases) {
      test(c.$1, () => expect(normalizeForPdf(c.$2), c.$3));
    }
  });

  group('Phát hiện', () {
    test('VN-PH-1 a + sắc + huyền (2 dấu thanh) → không làm mất dấu nào', () {
      final r = composeVietnamese('á̀');
      expect(r, anyOf('á̀', 'á̀'), reason: 'thực: ${r.runes.map((c) => c.toRadixString(16))}');
    });
  });
}
