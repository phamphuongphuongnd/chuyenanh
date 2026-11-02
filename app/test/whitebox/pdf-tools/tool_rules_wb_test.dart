// Kiểm thử hộp trắng (A03) cho lib/features/pdf_tools/logic/tool_rules.dart.
// Thiết kế: test-output/whitebox/pdf-tools/tool_rules/buoc-5-du-lieu-thu.md — expected chép từ Bước 5.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/pdf_tools/logic/tool_rules.dart';

Uint8List b(List<int> x) => Uint8List.fromList(x);

void main() {
  group('U1 mergedDefaultName', () {
    test('U1.1 hai tệp ⇒ A & B; đúng 80 ký tự giữ nguyên', () {
      expect(mergedDefaultName(['/x/A.pdf', '/y/B.PDF']), 'A & B');
      final a = 'a' * 38, bb = 'b' * 39;
      final r = mergedDefaultName(['/p/$a.pdf', '/p/$bb.pdf']);
      expect(r, '$a & $bb');
      expect(r.length, 80);
    });
    test('U1.2 N1Đ: rỗng ⇒ tên không rỗng', () {
      final r = mergedDefaultName([]);
      expect(r, isNotEmpty);
    });
    test('U1.3 N2Đ: một tệp ⇒ tên tệp đó', () {
      expect(mergedDefaultName(['/x/A.pdf']), 'A');
    });
    test('U1.4 N3Đ: ≥ 3 tệp ⇒ A & B (+N)', () {
      expect(mergedDefaultName(['/a.pdf', '/b.pdf', '/c.pdf']), 'a & b (+1)');
      expect(
        mergedDefaultName(['/a.pdf', '/b.pdf', '/c.pdf', '/d.pdf']),
        'a & b (+2)',
      );
    });
    test('U1.5 N4Đ: hai tên dài ⇒ ≤ 80 ký tự, giữ phần đầu', () {
      final r = mergedDefaultName(['/p/${'x' * 50}.pdf', '/p/${'y' * 50}.pdf']);
      expect(r.length, lessThanOrEqualTo(80));
      expect(r, startsWith('${'x' * 50} & '));
    });
  });

  test('U2.1 suffixedName', () {
    expect(suffixedName('/a/b/report.v1.pdf', 'locked'), 'report.v1_locked');
  });

  group('U3 validateNewPassword', () {
    test('U3.1 hợp lệ ⇒ null', () {
      expect(validateNewPassword('abc', 'abc'), isNull);
    });
    test('U3.2 W1Đ: rỗng ⇒ empty', () {
      expect(validateNewPassword('', 'x'), PasswordIssue.empty);
    });
    test('U3.3 W2Đ: không khớp ⇒ mismatch', () {
      expect(validateNewPassword('abc', 'abd'), PasswordIssue.mismatch);
    });
  });

  group('U4 parseBlankPageCount', () {
    test('U4.1 trong 1..1000', () {
      expect(parseBlankPageCount(' 7 '), 7);
      expect(parseBlankPageCount('1'), 1);
      expect(parseBlankPageCount('1000'), 1000);
    });
    test('U4.2 B1Đ: không phải số ⇒ null', () {
      expect(parseBlankPageCount('abc'), isNull);
      expect(parseBlankPageCount(''), isNull);
    });
    test('U4.3 B2Đ: 0 ⇒ null', () => expect(parseBlankPageCount('0'), isNull));
    test('U4.4 B3Đ: 1001 ⇒ null', () {
      expect(parseBlankPageCount('1001'), isNull);
    });
  });

  group('U5 splitEveryNFileCount', () {
    test('U5.1 làm tròn lên', () {
      expect(splitEveryNFileCount(10, 3), 4);
      expect(splitEveryNFileCount(10, 10), 1);
      expect(splitEveryNFileCount(1, 5), 1);
    });
    test('U5.2 S1Đ: n = 0 ⇒ 0', () => expect(splitEveryNFileCount(10, 0), 0));
    test('U5.3 S2Đ: 0 trang ⇒ 0', () => expect(splitEveryNFileCount(0, 2), 0));
  });

  group('U6 isPngOrJpeg', () {
    test('U6.1 PNG 8 byte ⇒ true', () {
      expect(isPngOrJpeg(b([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])), isTrue);
    });
    test('U6.2 G1S: JPEG 4 byte ⇒ true', () {
      expect(isPngOrJpeg(b([0xFF, 0xD8, 0xFF, 0xE0])), isTrue);
    });
    test('U6.3 G2S: JPEG ≥ 8 byte ⇒ true', () {
      expect(isPngOrJpeg(b([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46])), isTrue);
    });
    test('U6.4 G3S ⇒ false', () {
      expect(isPngOrJpeg(b([0x89, 0x00, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])), isFalse);
    });
    test('U6.5 G4S ⇒ false', () {
      expect(isPngOrJpeg(b([0x89, 0x50, 0x00, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])), isFalse);
    });
    test('U6.6 G5S ⇒ false', () {
      expect(isPngOrJpeg(b([0x89, 0x50, 0x4E, 0x00, 0x0D, 0x0A, 0x1A, 0x0A])), isFalse);
    });
    test('U6.7 J1S: 2 byte ⇒ false', () {
      expect(isPngOrJpeg(b([0xFF, 0xD8])), isFalse);
    });
    test('U6.8 J2S: GIF ⇒ false', () {
      expect(isPngOrJpeg(b([0x47, 0x49, 0x46, 0x38])), isFalse);
    });
    test('U6.9 J3S ⇒ false', () {
      expect(isPngOrJpeg(b([0xFF, 0x00, 0xFF])), isFalse);
    });
    test('U6.10 J4S ⇒ false', () {
      expect(isPngOrJpeg(b([0xFF, 0xD8, 0x00])), isFalse);
    });
  });
}
