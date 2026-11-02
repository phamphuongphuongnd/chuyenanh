// Kiểm thử hộp trắng A14 — signature_math.dart.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/editor/signature_math.dart';

void main() {
  group('U1 normalizeRotation', () {
    test('U1.P1 450 ⇒ 90; -90 ⇒ 270; -450 ⇒ 270; 360 ⇒ 0', () {
      expect(normalizeRotation(450), 90);
      expect(normalizeRotation(-90), 270);
      expect(normalizeRotation(-450), 270);
      expect(normalizeRotation(360), 0);
    });
  });

  group('U2 visualPageSize', () {
    const raw = Size(300, 500);
    test('U2.P1 0° ⇒ giữ nguyên; 180° ⇒ giữ nguyên', () {
      expect(visualPageSize(raw, 0), raw);
      expect(visualPageSize(raw, 180), raw);
    });
    test('U2.P2 90° ⇒ hoán đổi', () => expect(visualPageSize(raw, 90), const Size(500, 300)));
    test('U2.P3 270° (và -90°) ⇒ hoán đổi', () {
      expect(visualPageSize(raw, 270), const Size(500, 300));
      expect(visualPageSize(raw, -90), const Size(500, 300));
    });
  });

  group('U3 visualRectToRawRect', () {
    const raw = Size(300, 500);
    test('U3.P1 0° ⇒ giữ nguyên', () {
      expect(visualRectToRawRect(const Rect.fromLTRB(10, 20, 60, 40), raw, 0),
          const Rect.fromLTRB(10, 20, 60, 40));
    });
    test('U3.P2 90° ⇒ (100,50)-(300,150) thành (50,200)-(150,400)', () {
      expect(visualRectToRawRect(const Rect.fromLTRB(100, 50, 300, 150), raw, 90),
          const Rect.fromLTRB(50, 200, 150, 400));
    });
    test('U3.P3 180° ⇒ đối xứng qua tâm', () {
      expect(visualRectToRawRect(const Rect.fromLTRB(10, 20, 60, 40), raw, 180),
          const Rect.fromLTRB(240, 460, 290, 480));
    });
    test('U3.P4 270° ⇒ (10,20)-(60,40) thành (260,10)-(280,60)', () {
      expect(visualRectToRawRect(const Rect.fromLTRB(10, 20, 60, 40), raw, 270),
          const Rect.fromLTRB(260, 10, 280, 60));
    });
  });

  group('U4 rawRectToVisualRect', () {
    const raw = Size(300, 500);
    test('U4.P1 0° ⇒ giữ nguyên', () {
      expect(rawRectToVisualRect(const Rect.fromLTRB(10, 20, 60, 40), raw, 0),
          const Rect.fromLTRB(10, 20, 60, 40));
    });
    test('U4.P2 90° ⇒ ngược U3.P2', () {
      expect(rawRectToVisualRect(const Rect.fromLTRB(50, 200, 150, 400), raw, 90),
          const Rect.fromLTRB(100, 50, 300, 150));
    });
    test('U4.P3 180° ⇒ ngược U3.P3', () {
      expect(rawRectToVisualRect(const Rect.fromLTRB(240, 460, 290, 480), raw, 180),
          const Rect.fromLTRB(10, 20, 60, 40));
    });
    test('U4.P4 270° ⇒ ngược U3.P4; góc trên-trái raw (0,0) hiện ở dưới-trái', () {
      expect(rawRectToVisualRect(const Rect.fromLTRB(260, 10, 280, 60), raw, 270),
          const Rect.fromLTRB(10, 20, 60, 40));
      final corner = rawRectToVisualRect(const Rect.fromLTWH(0, 0, 1, 1), raw, 270);
      expect(corner.bottomLeft, const Offset(0, 300));
    });
  });
}
