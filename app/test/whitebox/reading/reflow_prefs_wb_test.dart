// Kiểm thử hộp trắng (A15) — reflow_prefs.dart. Mã bộ theo
// test-output/whitebox/reading/reflow_prefs/buoc-5-du-lieu-thu.md.
// Yêu cầu (comment): mỗi nền đọc có màu nền / chữ / chữ phụ riêng, cố định. Giá trị hex cụ thể: (*) cần xác nhận
// ⇒ chỉ khẳng định 3 nền khác nhau và chữ khác nền.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/reading/logic/reflow_prefs.dart';

void main() {
  group('U1 background / U2 foreground / U3 muted', () {
    for (final (u, name, get) in <(int, String, Color Function(ReflowTheme))>[
      (1, 'background', (t) => t.background),
      (2, 'foreground', (t) => t.foreground),
      (3, 'muted', (t) => t.muted),
    ]) {
      final all = {for (final t in ReflowTheme.values) t: get(t)};
      test('$u-1 light ⇒ màu $name riêng của light', () {
        expect(all[ReflowTheme.light], isNot(anyOf(all[ReflowTheme.sepia], all[ReflowTheme.dark])));
      });
      test('$u-2 sepia ⇒ màu $name riêng của sepia', () {
        expect(all[ReflowTheme.sepia], isNot(anyOf(all[ReflowTheme.light], all[ReflowTheme.dark])));
      });
      test('$u-3 dark ⇒ màu $name riêng của dark', () {
        expect(all[ReflowTheme.dark], isNot(anyOf(all[ReflowTheme.light], all[ReflowTheme.sepia])));
      });
    }
    test('chữ khác nền ở cả 3 nền đọc', () {
      for (final t in ReflowTheme.values) {
        expect(t.foreground, isNot(t.background));
        expect(t.muted, isNot(t.background));
      }
    });
  });

  group('U4 copyWith', () {
    const base = ReflowPrefs(fontSize: 20, theme: ReflowTheme.sepia, lineHeight: 2.0);
    test('4-1 không truyền gì ⇒ giữ nguyên cả 3', () {
      final p = base.copyWith();
      expect((p.fontSize, p.theme, p.lineHeight), (20.0, ReflowTheme.sepia, 2.0));
    });
    test('4-2 chỉ fontSize ⇒ đổi cỡ chữ', () {
      final p = base.copyWith(fontSize: 30);
      expect((p.fontSize, p.theme, p.lineHeight), (30.0, ReflowTheme.sepia, 2.0));
    });
    test('4-3 chỉ theme ⇒ đổi nền', () {
      final p = base.copyWith(theme: ReflowTheme.dark);
      expect((p.fontSize, p.theme, p.lineHeight), (20.0, ReflowTheme.dark, 2.0));
    });
    test('4-4 chỉ lineHeight ⇒ đổi giãn dòng', () {
      final p = base.copyWith(lineHeight: 1.3);
      expect((p.fontSize, p.theme, p.lineHeight), (20.0, ReflowTheme.sepia, 1.3));
    });
  });
}
