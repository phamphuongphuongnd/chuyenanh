import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/pdf_tools/engine/watermark_layout.dart';
import 'package:pdf_office/features/pdf_tools/logic/tool_rules.dart';

void main() {
  group('mergedDefaultName', () {
    test('một / hai / nhiều file', () {
      expect(mergedDefaultName(['/x/A.pdf']), 'A');
      expect(mergedDefaultName(['/x/A.pdf', '/y/B.PDF']), 'A & B');
      expect(mergedDefaultName(['/a.pdf', '/b.pdf', '/c.pdf', '/d.pdf']), 'a & b (+2)');
    });
    test('tên quá dài bị cắt', () {
      final long = '${'x' * 100}.pdf';
      expect(mergedDefaultName([long]).length, lessThanOrEqualTo(80));
    });
    test('rỗng → merged', () => expect(mergedDefaultName([]), 'merged'));
  });

  test('suffixedName', () {
    expect(suffixedName('/a/b/report.v1.pdf', 'locked'), 'report.v1_locked');
  });

  test('validateNewPassword', () {
    expect(validateNewPassword('', ''), PasswordIssue.empty);
    expect(validateNewPassword('abc', 'abd'), PasswordIssue.mismatch);
    expect(validateNewPassword('abc', 'abc'), isNull);
  });

  test('parseBlankPageCount: 1..1000', () {
    expect(parseBlankPageCount('1'), 1);
    expect(parseBlankPageCount(' 1000 '), 1000);
    expect(parseBlankPageCount('0'), isNull);
    expect(parseBlankPageCount('1001'), isNull);
    expect(parseBlankPageCount('abc'), isNull);
    expect(parseBlankPageCount(''), isNull);
  });

  test('isPngOrJpeg', () {
    expect(isPngOrJpeg(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])), isTrue);
    expect(isPngOrJpeg(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), isTrue);
    expect(isPngOrJpeg(Uint8List.fromList([0x47, 0x49, 0x46, 0x38])), isFalse);
    expect(isPngOrJpeg(Uint8List(0)), isFalse);
  });

  test('splitEveryNFileCount', () {
    expect(splitEveryNFileCount(10, 3), 4);
    expect(splitEveryNFileCount(10, 10), 1);
    expect(splitEveryNFileCount(10, 0), 0);
  });

  group('watermarkCenter', () {
    test('căn giữa khi align = 0', () {
      final c = watermarkCenter(
        pageW: 600, pageH: 800, itemW: 200, itemH: 50, angleDeg: 0,
      );
      expect(c, const Offset(300, 400));
    });
    test('góc trên trái / dưới phải: khung bao cách mép đúng pad', () {
      final tl = watermarkCenter(
        pageW: 600, pageH: 800, itemW: 200, itemH: 50, angleDeg: 0,
        alignX: -1, alignY: -1, pad: 10,
      );
      expect(tl.dx - 100, closeTo(10, 1e-6));
      expect(tl.dy - 25, closeTo(10, 1e-6));
      final br = watermarkCenter(
        pageW: 600, pageH: 800, itemW: 200, itemH: 50, angleDeg: 0,
        alignX: 1, alignY: 1, pad: 10,
      );
      expect(br.dx + 100, closeTo(590, 1e-6));
      expect(br.dy + 25, closeTo(790, 1e-6));
    });
    test('xoay 90 độ đổi chiều khung bao', () {
      final c = watermarkCenter(
        pageW: 600, pageH: 800, itemW: 200, itemH: 50, angleDeg: 90,
        alignX: -1, alignY: -1, pad: 0,
      );
      expect(c.dx, closeTo(25, 1e-6));
      expect(c.dy, closeTo(100, 1e-6));
    });
    test('vật lớn hơn trang → ở giữa; align ngoài -1..1 bị kẹp', () {
      final c = watermarkCenter(
        pageW: 100, pageH: 100, itemW: 500, itemH: 500, angleDeg: 0, alignX: 5, alignY: -5,
      );
      expect(c, const Offset(50, 50));
    });
  });

  test('PlacedWatermarkSpec giữ thông số của WatermarkSpec', () {
    const t = PlacedWatermarkSpec.text('X', fontSize: 30, opacity: 0.5, angle: 10, alignX: 1);
    expect(t.text, 'X');
    expect(t.fontSize, 30);
    expect(t.opacity, 0.5);
    expect(t.angle, 10);
    expect(t.alignX, 1);
    expect(t.imageBytes, isNull);
  });
}
