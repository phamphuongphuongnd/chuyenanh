import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:office_reader/office_reader.dart' as office;
import 'package:pdf_office/features/convert/engine/pdf_builders.dart';

office.XlsxRange? _linear(List<office.XlsxRange> merges, int r, int c) {
  for (final m in merges) {
    if (m.contains(r, c)) return m;
  }
  return null;
}

void main() {
  group('XlsxMergeCursor', () {
    test('giống bản quét tuyến tính (kể cả vùng chồng nhau)', () {
      final rnd = Random(7);
      final merges = [
        for (var i = 0; i < 60; i++)
          () {
            final r = rnd.nextInt(80);
            final c = rnd.nextInt(15);
            return office.XlsxRange(r, c, r + rnd.nextInt(6), c + rnd.nextInt(4));
          }(),
      ];
      final cur = XlsxMergeCursor(merges);
      for (var r = 0; r < 95; r++) {
        for (var c = 0; c < 22; c++) {
          expect(cur.covering(r, c), same(_linear(merges, r, c)), reason: '($r,$c)');
        }
      }
    });

    test('không có vùng gộp → null', () {
      expect(XlsxMergeCursor(const []).covering(3, 3), isNull);
    });

    test('sheet 20 cột x 50.000 hàng, 600 vùng gộp: tra xong trong ngưỡng hợp lý', () {
      final merges = [
        for (var i = 0; i < 600; i++) office.XlsxRange(i * 80, i % 15, i * 80 + 2, i % 15 + 2),
      ];
      final cur = XlsxMergeCursor(merges);
      final sw = Stopwatch()..start();
      var hits = 0;
      for (var r = 0; r < 50000; r++) {
        for (var c = 0; c < 20; c++) {
          if (cur.covering(r, c) != null) hits++;
        }
      }
      sw.stop();
      expect(hits, greaterThan(0));
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });
  });
}
