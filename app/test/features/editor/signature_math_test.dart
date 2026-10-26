import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/editor/signature_math.dart';

void main() {
  group('viewRectToPdfRect (co dan thuan)', () {
    test('zoom 1x: viewSize == pageSize giu nguyen', () {
      final r = viewRectToPdfRect(
        const Rect.fromLTWH(10, 20, 100, 50),
        const Size(595, 842),
        const Size(595, 842),
      );
      expect(r, const Rect.fromLTWH(10, 20, 100, 50));
    });

    test('zoom 2x: widget gap doi trang -> toa do PDF giam mot nua', () {
      final r = viewRectToPdfRect(
        const Rect.fromLTWH(200, 400, 300, 100),
        const Size(1190, 1684),
        const Size(595, 842),
      );
      expect(r.left, closeTo(100, 1e-9));
      expect(r.top, closeTo(200, 1e-9));
      expect(r.width, closeTo(150, 1e-9));
      expect(r.height, closeTo(50, 1e-9));
    });

    test('zoom 0.5x: widget nho hon trang -> toa do PDF tang gap doi', () {
      final r = viewRectToPdfRect(
        const Rect.fromLTWH(10, 10, 40, 20),
        const Size(297.5, 421),
        const Size(595, 842),
      );
      expect(r, const Rect.fromLTWH(20, 20, 80, 40));
    });
  });

  group('screenRectToPageRect (cuon + zoom)', () {
    test('zoom 2x, cuon xuong 300px: tru goc trang roi doi ti le', () {
      const pageOnScreen = Rect.fromLTWH(0, -300, 1190, 1684);
      // Chu ky tren man hinh tai (200, 100): cach dinh trang 400px.
      const sigOnScreen = Rect.fromLTWH(200, 100, 300, 100);
      final r = screenRectToPageRect(
        sigOnScreen,
        pageOnScreen,
        const Size(595, 842),
      );
      expect(r.left, closeTo(100, 1e-9));
      expect(r.top, closeTo(200, 1e-9));
      expect(r.width, closeTo(150, 1e-9));
      expect(r.height, closeTo(50, 1e-9));
    });

    test('cuon ngang: trang lech trai 50px', () {
      const pageOnScreen = Rect.fromLTWH(-50, 20, 595, 842);
      final r = screenRectToPageRect(
        const Rect.fromLTWH(0, 20, 100, 40),
        pageOnScreen,
        const Size(595, 842),
      );
      expect(r, const Rect.fromLTWH(50, 0, 100, 40));
    });

    test('ket qua bi kep trong trang', () {
      final r = screenRectToPageRect(
        const Rect.fromLTWH(-100, -50, 300, 200),
        const Rect.fromLTWH(0, 0, 595, 842),
        const Size(595, 842),
      );
      expect(r.left, 0);
      expect(r.top, 0);
      expect(r.right, 200);
      expect(r.bottom, 150);
    });

    test('trang xoay 90: pageSize la kich thuoc nhin thay (da hoan doi)', () {
      // Raw 600x800 xoay 90 -> nhin thay 800x600; hien o zoom 1.5 (1200x900).
      final visual = visualPageSize(const Size(600, 800), 90);
      final r = screenRectToPageRect(
        const Rect.fromLTWH(150, 90, 300, 150),
        const Rect.fromLTWH(0, 0, 1200, 900),
        visual,
      );
      expect(r, const Rect.fromLTWH(100, 60, 200, 100));
    });
  });

  group('visualRectToRawRect (trang xoay)', () {
    // Trang raw 600x800 (W x H).
    const raw = Size(600, 800);
    // Khung o goc tren-trai cua anh nhin thay, 100 x 40.
    const topLeftVisual = Rect.fromLTWH(0, 0, 100, 40);

    test('0 do: giu nguyen', () {
      expect(visualRectToRawRect(topLeftVisual, raw, 0), topLeftVisual);
    });

    test('90 do (xoay thuan): tren-trai nhin thay = duoi-trai cua raw', () {
      final r = visualRectToRawRect(topLeftVisual, raw, 90);
      expect(r.left, closeTo(0, 1e-9));
      expect(r.right, closeTo(40, 1e-9));
      expect(r.bottom, closeTo(800, 1e-9));
      expect(r.top, closeTo(700, 1e-9));
    });

    test('180 do: doi xung qua tam', () {
      final r = visualRectToRawRect(topLeftVisual, raw, 180);
      expect(r, const Rect.fromLTRB(500, 760, 600, 800));
    });

    test('270 do: tren-trai nhin thay = tren-phai cua raw', () {
      final r = visualRectToRawRect(topLeftVisual, raw, 270);
      expect(r.right, closeTo(600, 1e-9));
      expect(r.left, closeTo(560, 1e-9));
      expect(r.top, closeTo(0, 1e-9));
      expect(r.bottom, closeTo(100, 1e-9));
    });

    test('raw -> visual -> raw tra ve cung khung (4 huong)', () {
      const rect = Rect.fromLTWH(123, 45, 67, 89);
      for (final deg in [0, 90, 180, 270]) {
        final v = rawRectToVisualRect(rect, raw, deg);
        final back = visualRectToRawRect(v, raw, deg);
        expect(back.left, closeTo(rect.left, 1e-9), reason: '$deg');
        expect(back.top, closeTo(rect.top, 1e-9), reason: '$deg');
        expect(back.right, closeTo(rect.right, 1e-9), reason: '$deg');
        expect(back.bottom, closeTo(rect.bottom, 1e-9), reason: '$deg');
      }
    });

    test('khung nhin thay luon nam trong kich thuoc nhin thay', () {
      for (final deg in [90, 270]) {
        final visual = visualPageSize(raw, deg);
        final rawRect = visualRectToRawRect(
          Rect.fromLTWH(0, 0, visual.width, visual.height),
          raw,
          deg,
        );
        expect(rawRect, const Rect.fromLTWH(0, 0, 600, 800), reason: '$deg');
      }
    });

    test('visualPageSize: 90/270 hoan doi rong/cao', () {
      expect(visualPageSize(raw, 0), raw);
      expect(visualPageSize(raw, 90), const Size(800, 600));
      expect(visualPageSize(raw, 180), raw);
      expect(visualPageSize(raw, 270), const Size(800, 600));
    });
  });

  test('normalizeRotation chuan hoa ve 0/90/180/270', () {
    expect(normalizeRotation(0), 0);
    expect(normalizeRotation(90), 90);
    expect(normalizeRotation(360), 0);
    expect(normalizeRotation(450), 90);
    expect(normalizeRotation(-90), 270);
    expect(normalizeRotation(-180), 180);
  });

  test('clampRectInside giu khung trong trang', () {
    const bounds = Size(100, 200);
    expect(
      clampRectInside(const Rect.fromLTWH(90, 190, 30, 30), bounds),
      const Rect.fromLTWH(70, 170, 30, 30),
    );
    expect(
      clampRectInside(const Rect.fromLTWH(-5, -5, 30, 30), bounds),
      const Rect.fromLTWH(0, 0, 30, 30),
    );
    // Khung lon hon trang -> thu nho vua trang.
    expect(
      clampRectInside(const Rect.fromLTWH(10, 10, 500, 50), bounds),
      const Rect.fromLTWH(0, 10, 100, 50),
    );
  });
}
