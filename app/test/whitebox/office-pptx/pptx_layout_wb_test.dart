// ignore_for_file: unnecessary_import
// Kiểm thử hộp trắng A14 — pptx_layout.dart.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/office_pptx/pptx_layout.dart';
import 'package:pptx_reader/pptx_reader.dart';

PptxParagraph _p({
  int level = 0,
  bool numbered = false,
  String? scheme,
  String? bullet,
  String? font,
}) => PptxParagraph(
  level: level,
  numbered: numbered,
  numberingScheme: scheme,
  bulletChar: bullet,
  bulletFontFamily: font,
  runs: const [PptxRun(text: 'x')],
);

double _len(Path path) =>
    path.computeMetrics().fold<double>(0, (s, m) => s + m.length);

void _near(Rect r, Rect e, {double tol = 0.5}) {
  expect(r.left, closeTo(e.left, tol), reason: 'left $r');
  expect(r.top, closeTo(e.top, tol), reason: 'top $r');
  expect(r.right, closeTo(e.right, tol), reason: 'right $r');
  expect(r.bottom, closeTo(e.bottom, tol), reason: 'bottom $r');
}

const _cmd = PptxPathCommand.new;

void main() {
  group('U1 textAlignOf / U2 alignmentOfAnchor', () {
    test('U1.P1–P4 left/center/right/justify', () {
      expect(textAlignOf(PptxAlign.left), TextAlign.left);
      expect(textAlignOf(PptxAlign.center), TextAlign.center);
      expect(textAlignOf(PptxAlign.right), TextAlign.right);
      expect(textAlignOf(PptxAlign.justify), TextAlign.justify);
    });
    test('U2.P1–P3 top/middle/bottom', () {
      expect(alignmentOfAnchor(PptxAnchor.top), Alignment.topCenter);
      expect(alignmentOfAnchor(PptxAnchor.middle), Alignment.center);
      expect(alignmentOfAnchor(PptxAnchor.bottom), Alignment.bottomCenter);
    });
  });

  group('U3 lineHeightFactor', () {
    test('U3.P1 giãn dòng 30pt, chữ 20pt ⇒ 1.5', () {
      expect(lineHeightFactor(const PptxParagraph(lineSpacingPt: 30), 20), 1.5);
    });
    test('U3.P2 không pt, 90% ⇒ 0.9 × 1.2', () {
      expect(lineHeightFactor(const PptxParagraph(lineSpacingPct: 90), 20), closeTo(1.08, 1e-9));
    });
    test('U3.P3 có pt nhưng cỡ chữ 0 ⇒ không chia 0, dùng 1.2', () {
      expect(lineHeightFactor(const PptxParagraph(lineSpacingPt: 30), 0), 1.2);
    });
    test('U3.P4 không pt, không % ⇒ 1.2 (single)', () {
      expect(lineHeightFactor(const PptxParagraph(), 20), 1.2);
    });
  });

  group('U4 cropImageRect', () {
    const fr = Size(100, 50);
    test('U4.P1 cắt 25% trái phải ⇒ ảnh gốc rộng 200, lệch -50', () {
      expect(cropImageRect(fr, const PptxCrop(left: 0.25, right: 0.25)),
          const Rect.fromLTWH(-50, 0, 200, 50));
    });
    test('U4.P2 không crop ⇒ khung', () {
      expect(cropImageRect(fr, null), const Rect.fromLTWH(0, 0, 100, 50));
    });
    test('U4.P3 giữ lại bề ngang ≤ 0.001 ⇒ khung', () {
      expect(cropImageRect(fr, const PptxCrop(left: 0.5, right: 0.5)), const Rect.fromLTWH(0, 0, 100, 50));
    });
    test('U4.P4 giữ lại bề dọc ≤ 0.001 ⇒ khung', () {
      expect(cropImageRect(fr, const PptxCrop(top: 0.6, bottom: 0.6)), const Rect.fromLTWH(0, 0, 100, 50));
    });
  });

  group('U5 bulletLabels', () {
    test('U5.P1 một đoạn đánh số ⇒ "1."', () {
      expect(bulletLabels([_p(numbered: true)]), ['1.']);
    });
    test('U5.P2 danh sách rỗng ⇒ []', () {
      expect(bulletLabels(const []), isEmpty);
    });
    test('U5.P3 đoạn bullet thường ⇒ ký tự bullet', () {
      expect(bulletLabels([_p(bullet: '•')]), ['•']);
    });
    test('U5.P4 đánh số liên tiếp, cấp sâu đếm riêng, đoạn thường cùng cấp đếm lại', () {
      expect(
        bulletLabels([
          _p(numbered: true),
          _p(numbered: true),
          _p(numbered: true, level: 1),
          _p(numbered: true),
          _p(),
          _p(numbered: true),
        ]),
        ['1.', '2.', '1.', '3.', null, '1.'],
      );
    });
  });

  group('U6 numberLabel', () {
    test('U6.P1 alphaLcParenR, 2 ⇒ "b)"', () => expect(numberLabel(2, 'alphaLcParenR'), 'b)'));
    test('U6.P2 scheme null ⇒ arabicPeriod "2."', () => expect(numberLabel(2, null), '2.'));
    test('U6.P3* kiểu lạ (hebrew2Minus) ⇒ mặc định "2."', () => expect(numberLabel(2, 'hebrew2Minus'), '2.'));
    test('U6.P6 alphaLc không hậu tố ⇒ "b."', () => expect(numberLabel(2, 'alphaLc'), 'b.'));
    test('U6.P7 alphaUcParenR ⇒ "B)"', () => expect(numberLabel(2, 'alphaUcParenR'), 'B)'));
    test('U6.P8 romanLcParenR 4 ⇒ "iv)"', () => expect(numberLabel(4, 'romanLcParenR'), 'iv)'));
    test('U6.P9 romanUcParenR 4 ⇒ "IV)"', () => expect(numberLabel(4, 'romanUcParenR'), 'IV)'));
    test('U6.P10 arabicParenR 2 ⇒ "2)"', () => expect(numberLabel(2, 'arabicParenR'), '2)'));
    test('U6.P11 alphaLcParenBoth ⇒ "(b)"', () => expect(numberLabel(2, 'alphaLcParenBoth'), '(b)'));
    test('U6.P12 alphaLcPlain ⇒ "b"', () => expect(numberLabel(2, 'alphaLcPlain'), 'b'));
    test('U6.P13 alphaLcPeriod ⇒ "b."', () => expect(numberLabel(2, 'alphaLcPeriod'), 'b.'));
  });

  group('U7 alphaNumber / U8 romanNumber', () {
    test('U7.P1 1→a, 26→z, 27→aa, 0→a (kẹp ≥1)', () {
      expect(alphaNumber(1), 'a');
      expect(alphaNumber(26), 'z');
      expect(alphaNumber(27), 'aa');
      expect(alphaNumber(0), 'a');
    });
    test('U8.P1 1994 ⇒ MCMXCIV; 0 ⇒ I; 5000 ⇒ MMMCMXCIX (kẹp 1..3999)', () {
      expect(romanNumber(1994), 'MCMXCIV');
      expect(romanNumber(0), 'I');
      expect(romanNumber(5000), 'MMMCMXCIX');
    });
  });

  group('U9 bulletGlyph', () {
    test('U9.P1 "•" font Arial ⇒ giữ nguyên', () => expect(bulletGlyph(_p(bullet: '•', font: 'Arial')), '•'));
    test('U9.P2 không bullet ⇒ null', () => expect(bulletGlyph(_p()), isNull));
    test('U9.P3 bullet rỗng ⇒ null', () => expect(bulletGlyph(_p(bullet: '')), isNull));
    test('U9.P4 không tên font ⇒ giữ nguyên', () => expect(bulletGlyph(_p(bullet: '–')), '–'));
    test('U9.P5 Wingdings "§" (0xA7) ⇒ "▪"', () => expect(bulletGlyph(_p(bullet: '§', font: 'Wingdings')), '▪'));
    test('U9.P6 Symbol "·" (0xB7) ⇒ "•"', () => expect(bulletGlyph(_p(bullet: '·', font: 'Symbol')), '•'));
    test('U9.P7 Webdings "v" ⇒ đổi sang ký tự Unicode (không giữ "v")', () {
      final g = bulletGlyph(_p(bullet: 'v', font: 'Webdings'));
      expect(g, isNotNull);
      expect(g, isNot('v'));
    });
    test('U9.P8 U+F0A7 font Arial ⇒ "▪"', () {
      expect(bulletGlyph(_p(bullet: String.fromCharCode(0xF0A7), font: 'Arial')), '▪');
    });
    test('U9.P9 U+F100 (ngoài F000–F0FF) font Arial ⇒ giữ nguyên', () {
      final c = String.fromCharCode(0xF100);
      expect(bulletGlyph(_p(bullet: c, font: 'Arial')), c);
    });
    test('U9.P13 Wingdings "A" (không có trong bảng) ⇒ "•"', () {
      expect(bulletGlyph(_p(bullet: 'A', font: 'Wingdings 3')), '•');
    });
  });

  group('U10 layoutTable', () {
    const plain = PptxTableCell();
    PptxTableShape t(List<int> cols, List<PptxTableRow> rows) =>
        PptxTableShape(frame: const PptxRect(0, 0, 0, 0), columnWidthsEmu: cols, rows: rows);
    test('U10.P1 2 cột × 1 hàng ⇒ 2 ô đúng vị trí', () {
      final b = layoutTable(t(const [127000, 254000], const [PptxTableRow(heightEmu: 127000, cells: [plain, plain])]));
      expect(b.map((e) => e.rect), const [Rect.fromLTRB(0, 0, 10, 10), Rect.fromLTRB(10, 0, 30, 10)]);
    });
    test('U10.P2 không có cột ⇒ không ô nào', () {
      expect(layoutTable(t(const [], const [PptxTableRow(heightEmu: 127000, cells: [plain])])), isEmpty);
    });
    test('U10.P3* không có hàng ⇒ rỗng', () {
      expect(layoutTable(t(const [127000], const [])), isEmpty);
    });
    test('U10.P5 hàng 0 ô ⇒ bỏ qua hàng đó', () {
      final b = layoutTable(t(const [127000], const [
        PptxTableRow(heightEmu: 127000, cells: []),
        PptxTableRow(heightEmu: 127000, cells: [plain]),
      ]));
      expect(b.single.row, 1);
      expect(b.single.rect, const Rect.fromLTRB(0, 10, 10, 20));
    });
    test('U10.P6 hàng nhiều ô hơn số cột ⇒ ô thừa bị bỏ', () {
      final b = layoutTable(t(const [127000], const [PptxTableRow(heightEmu: 127000, cells: [plain, plain, plain])]));
      expect(b, hasLength(1));
    });
    test('U10.P7 ô hMerge ⇒ không vẽ, ô gốc phủ 2 cột', () {
      final b = layoutTable(t(const [127000, 127000], const [
        PptxTableRow(heightEmu: 127000, cells: [PptxTableCell(gridSpan: 2), PptxTableCell(hMerge: true)]),
      ]));
      expect(b.single.rect, const Rect.fromLTRB(0, 0, 20, 10));
    });
    test('U10.P8 ô vMerge ⇒ không vẽ, ô gốc phủ 2 hàng', () {
      final b = layoutTable(t(const [127000], const [
        PptxTableRow(heightEmu: 127000, cells: [PptxTableCell(rowSpan: 2)]),
        PptxTableRow(heightEmu: 127000, cells: [PptxTableCell(vMerge: true)]),
      ]));
      expect(b.single.rect, const Rect.fromLTRB(0, 0, 10, 20));
    });
  });

  group('U11 customPathToFlutter', () {
    const target = Size(200, 50);
    Path run(List<PptxPathCommand> c, {int w = 100, int h = 100}) =>
        customPathToFlutter(PptxCustomPath(widthEmu: w, heightEmu: h, commands: c), target);
    final base = [_cmd(PptxPathOp.moveTo, [10, 20]), _cmd(PptxPathOp.lineTo, [50, 60])];

    test('U11.P1 moveTo + lineTo co theo khung (sx 2, sy 0.5)', () {
      _near(run(base).getBounds(), const Rect.fromLTRB(20, 10, 100, 30));
    });
    test('U11.P2 widthEmu 0 ⇒ sx = 1', () {
      _near(run(base, w: 0).getBounds(), const Rect.fromLTRB(10, 10, 50, 30));
    });
    test('U11.P3 heightEmu 0 ⇒ sy = 1', () {
      _near(run(base, h: 0).getBounds(), const Rect.fromLTRB(20, 20, 100, 60));
    });
    test('U11.P4 không lệnh ⇒ đường rỗng', () {
      expect(_len(run(const [])), 0);
    });
    test('U11.P5 lệnh đầu là lineTo ⇒ vẽ từ gốc', () {
      _near(run([_cmd(PptxPathOp.lineTo, [100, 100])]).getBounds(), const Rect.fromLTRB(0, 0, 200, 50));
    });
    test('U11.P6 cubicTo ⇒ phủ khung', () {
      _near(run([_cmd(PptxPathOp.moveTo, [0, 0]), _cmd(PptxPathOp.cubicTo, [0, 0, 100, 100, 100, 100])]).getBounds(),
          const Rect.fromLTRB(0, 0, 200, 50));
    });
    test('U11.P7 quadTo ⇒ phủ khung', () {
      _near(run([_cmd(PptxPathOp.moveTo, [0, 0]), _cmd(PptxPathOp.quadTo, [100, 0, 100, 100])]).getBounds(),
          const Rect.fromLTRB(0, 0, 200, 50));
    });
    test('U11.P8 arcTo nửa elip ⇒ (0,0)-(200,25)', () {
      _near(run([_cmd(PptxPathOp.moveTo, [0, 50]), _cmd(PptxPathOp.arcTo, [50, 50, 180, 180])]).getBounds(),
          const Rect.fromLTRB(0, 0, 200, 25));
    });
    test('U11.P9 close đưa điểm hiện tại về điểm đầu (arc sau close bắt đầu tại moveTo)', () {
      final b = run([
        _cmd(PptxPathOp.moveTo, [0, 50]),
        _cmd(PptxPathOp.lineTo, [100, 50]),
        _cmd(PptxPathOp.close),
        _cmd(PptxPathOp.arcTo, [50, 50, 180, 180]),
      ]).getBounds();
      _near(b, const Rect.fromLTRB(0, 0, 200, 25));
    });
    test('U11.P10–P14 lệnh thiếu tham số ⇒ bỏ qua, không ném', () {
      // moveTo thiếu ⇒ lineTo vẽ từ gốc
      _near(run([_cmd(PptxPathOp.moveTo, [5]), _cmd(PptxPathOp.lineTo, [100, 100])]).getBounds(),
          const Rect.fromLTRB(0, 0, 200, 50));
      for (final c in [
        _cmd(PptxPathOp.lineTo, [1]),
        _cmd(PptxPathOp.cubicTo, [1, 2, 3, 4]),
        _cmd(PptxPathOp.quadTo, [1, 2]),
        _cmd(PptxPathOp.arcTo, [1, 2]),
      ]) {
        expect(_len(run([_cmd(PptxPathOp.moveTo, [0, 0]), c])), 0, reason: '${c.kind}');
      }
    });
  });

  group('U12 _arcTo (qua customPathToFlutter, khung 100×100 không co)', () {
    Path arc(List<double> start, List<double> args) => customPathToFlutter(
      PptxCustomPath(
        widthEmu: 100,
        heightEmu: 100,
        commands: [_cmd(PptxPathOp.moveTo, start), _cmd(PptxPathOp.arcTo, args)],
      ),
      const Size(100, 100),
    );
    test('U12.P1 từ (0,50) góc 180 quét 180 ⇒ nửa trên, dài π·50', () {
      final p = arc([0, 50], [50, 50, 180, 180]);
      _near(p.getBounds(), const Rect.fromLTRB(0, 0, 100, 50));
      expect(_len(p), closeTo(math.pi * 50, 1));
    });
    test('U12.P2 wR = 0 ⇒ không vẽ', () => expect(_len(arc([0, 50], [0, 50, 180, 180])), 0));
    test('U12.P3 hR = 0 ⇒ không vẽ', () => expect(_len(arc([0, 50], [50, 0, 180, 180])), 0));
    test('U12.P4 quét 360 ⇒ cả vòng, dài 2π·50', () {
      final p = arc([0, 50], [50, 50, 180, 360]);
      _near(p.getBounds(), const Rect.fromLTRB(0, 0, 100, 100));
      expect(_len(p), closeTo(2 * math.pi * 50, 2));
    });
    test('U12.P5 quét -90 từ (100,50) ⇒ ngược chiều kim đồng hồ lên đỉnh', () {
      final p = arc([100, 50], [50, 50, 0, -90]);
      _near(p.getBounds(), const Rect.fromLTRB(50, 0, 100, 50));
      expect(_len(p), closeTo(math.pi * 25, 1));
    });
    test('U12.P6 quét +90 từ (100,50) ⇒ xuôi chiều xuống đáy', () {
      final p = arc([100, 50], [50, 50, 0, 90]);
      _near(p.getBounds(), const Rect.fromLTRB(50, 50, 100, 100));
    });
    test('U12.P7 quét 0 ⇒ không thêm độ dài', () => expect(_len(arc([100, 50], [50, 50, 0, 0])), closeTo(0, 1e-6)));
    test('U12.P8 quét -270 ⇒ 3/4 vòng ngược chiều', () {
      final p = arc([100, 50], [50, 50, 0, -270]);
      _near(p.getBounds(), const Rect.fromLTRB(0, 0, 100, 100));
      expect(_len(p), closeTo(1.5 * math.pi * 50, 1.5));
    });
  });

  group('U13 presetPath / U14 _extraPreset', () {
    const size = Size(100, 40);
    Path pre(PptxGeometry g, [String? n]) => presetPath(g, n, size);
    test('U13.P1 rect chứa góc (1,1)', () => expect(pre(PptxGeometry.rect).contains(const Offset(1, 1)), isTrue));
    test('U13.P2 roundRect bo góc ⇒ không chứa (0.5,0.5), chứa tâm', () {
      final p = pre(PptxGeometry.roundRect);
      expect(p.contains(const Offset(0.5, 0.5)), isFalse);
      expect(p.contains(const Offset(50, 20)), isTrue);
    });
    test('U13.P3 ellipse ⇒ không chứa góc, chứa tâm', () {
      final p = pre(PptxGeometry.ellipse);
      expect(p.contains(const Offset(1, 1)), isFalse);
      expect(p.contains(const Offset(50, 20)), isTrue);
    });
    test('U13.P4 triangle ⇒ đỉnh giữa trên, không chứa góc trên-trái', () {
      final p = pre(PptxGeometry.triangle);
      expect(p.contains(const Offset(2, 2)), isFalse);
      expect(p.contains(const Offset(50, 35)), isTrue);
    });
    test('U13.P5 line ⇒ đường chéo (0,0)-(100,40)', () {
      _near(pre(PptxGeometry.line).getBounds(), const Rect.fromLTRB(0, 0, 100, 40));
      expect(_len(pre(PptxGeometry.line)), closeTo(math.sqrt(100 * 100 + 40 * 40), 0.01));
    });
    test('U14.P1 diamond ⇒ không chứa góc, chứa tâm', () {
      final p = pre(PptxGeometry.other, 'diamond');
      expect(p.contains(const Offset(1, 1)), isFalse);
      expect(p.contains(const Offset(50, 20)), isTrue);
    });
    test('U14.P2 rightArrow ⇒ đầu mũi tên bên phải', () {
      final p = pre(PptxGeometry.other, 'rightArrow');
      expect(p.contains(const Offset(82, 3)), isTrue);
      expect(p.contains(const Offset(18, 3)), isFalse);
    });
    test('U14.P3 leftArrow ⇒ đầu mũi tên bên trái', () {
      final p = pre(PptxGeometry.other, 'leftArrow');
      expect(p.contains(const Offset(18, 3)), isTrue);
      expect(p.contains(const Offset(82, 3)), isFalse);
    });
    test('U14.P4 downArrow ⇒ đầu mũi tên ở dưới', () {
      final p = pre(PptxGeometry.other, 'downArrow');
      expect(p.contains(const Offset(5, 21)), isTrue);
      expect(p.contains(const Offset(5, 19)), isFalse);
    });
    test('U14.P5 upArrow ⇒ đầu mũi tên ở trên', () {
      final p = pre(PptxGeometry.other, 'upArrow');
      expect(p.contains(const Offset(5, 19)), isTrue);
      expect(p.contains(const Offset(5, 21)), isFalse);
    });
    test('U14.P6 hexagon ⇒ không chứa góc, chứa tâm', () {
      final p = pre(PptxGeometry.other, 'hexagon');
      expect(p.contains(const Offset(1, 1)), isFalse);
      expect(p.contains(const Offset(50, 20)), isTrue);
    });
    test('U14.P7 parallelogram ⇒ không chứa góc trên-trái, chứa góc trên-phải', () {
      final p = pre(PptxGeometry.other, 'parallelogram');
      expect(p.contains(const Offset(1, 1)), isFalse);
      expect(p.contains(const Offset(99, 1)), isTrue);
    });
    test('U14.P8 tên lạ / null ⇒ chữ nhật', () {
      expect(pre(PptxGeometry.other, 'wave').contains(const Offset(1, 1)), isTrue);
      expect(pre(PptxGeometry.other).contains(const Offset(1, 1)), isTrue);
    });
  });
}
