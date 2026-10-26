import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/editor/signature_overlay_model.dart';

void main() {
  const a4 = Size(595, 842);

  group('initialNormRect', () {
    test('nam giua trang, dung ti le anh', () {
      final r = initialNormRect(3, a4); // anh rong gap 3 lan cao
      expect(r.center.dx, closeTo(0.5, 1e-9));
      expect(r.center.dy, closeTo(0.5, 1e-9));
      expect(r.width, closeTo(kDefaultSignatureWidthFraction, 1e-9));
      // Kiem tra ti le theo point: (w*595)/(h*842) == 3
      expect((r.width * a4.width) / (r.height * a4.height), closeTo(3, 1e-9));
    });

    test('anh qua cao: thu nho de khong qua nua trang', () {
      final r = initialNormRect(0.2, a4);
      expect(r.height, lessThanOrEqualTo(0.5 + 1e-9));
      expect((r.width * a4.width) / (r.height * a4.height), closeTo(0.2, 1e-9));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(1));
    });
  });

  group('moveNormRect', () {
    test('dich binh thuong', () {
      final r = moveNormRect(
        const Rect.fromLTWH(0.2, 0.2, 0.3, 0.1),
        const Offset(0.1, -0.05),
      );
      expect(r.left, closeTo(0.3, 1e-9));
      expect(r.top, closeTo(0.15, 1e-9));
      expect(r.width, closeTo(0.3, 1e-9));
      expect(r.height, closeTo(0.1, 1e-9));
    });

    test('khong vuot ra ngoai trang (4 mep)', () {
      const r0 = Rect.fromLTWH(0.2, 0.2, 0.3, 0.1);
      expect(moveNormRect(r0, const Offset(-5, 0)).left, 0);
      expect(moveNormRect(r0, const Offset(5, 0)).right, closeTo(1, 1e-9));
      expect(moveNormRect(r0, const Offset(0, -5)).top, 0);
      expect(moveNormRect(r0, const Offset(0, 5)).bottom, closeTo(1, 1e-9));
    });
  });

  group('resizeNormRect', () {
    test('giu ti le anh va neo tren-trai', () {
      final r0 = initialNormRect(2, a4);
      final r = resizeNormRect(r0, 0.5, a4, 2);
      expect(r.left, r0.left);
      expect(r.top, r0.top);
      expect(r.width, closeTo(0.5, 1e-9));
      expect((r.width * a4.width) / (r.height * a4.height), closeTo(2, 1e-9));
    });

    test('khong nho hon toi thieu', () {
      final r = resizeNormRect(
        const Rect.fromLTWH(0.1, 0.1, 0.3, 0.1),
        0.0,
        a4,
        2,
      );
      expect(r.width, closeTo(kMinSignatureWidthFraction, 1e-9));
    });

    test('khong vuot mep phai / mep duoi trang', () {
      const r0 = Rect.fromLTWH(0.7, 0.9, 0.2, 0.05);
      final r = resizeNormRect(r0, 0.9, a4, 4);
      expect(r.right, lessThanOrEqualTo(1 + 1e-9));
      expect(r.bottom, lessThanOrEqualTo(1 + 1e-9));
      expect((r.width * a4.width) / (r.height * a4.height), closeTo(4, 1e-9));
    });
  });

  group('normToPdfRect / pdfRectToNorm', () {
    test('quy doi sang point', () {
      final r = normToPdfRect(const Rect.fromLTWH(0.5, 0.25, 0.2, 0.1), a4);
      expect(r.left, closeTo(297.5, 1e-9));
      expect(r.top, closeTo(210.5, 1e-9));
      expect(r.width, closeTo(119, 1e-9));
      expect(r.height, closeTo(84.2, 1e-9));
    });

    test('hai chieu tra ve cung gia tri', () {
      const n = Rect.fromLTWH(0.1, 0.3, 0.4, 0.15);
      final back = pdfRectToNorm(normToPdfRect(n, a4), a4);
      expect(back.left, closeTo(n.left, 1e-9));
      expect(back.bottom, closeTo(n.bottom, 1e-9));
    });

    test('trang xoay: dung kich thuoc nhin thay (da hoan doi)', () {
      // Trang 300x500 xoay 90 → nhìn thấy 500x300.
      final r = normToPdfRect(
        const Rect.fromLTWH(0.2, 0.5, 0.4, 0.2),
        const Size(500, 300),
      );
      expect(r.left, closeTo(100, 1e-9));
      expect(r.top, closeTo(150, 1e-9));
      expect(r.width, closeTo(200, 1e-9));
      expect(r.height, closeTo(60, 1e-9));
    });
  });
}
