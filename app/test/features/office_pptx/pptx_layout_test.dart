import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/office_pptx/pptx_layout.dart';
import 'package:pptx_reader/pptx_reader.dart';

PptxParagraph _p(
  String text, {
  int level = 0,
  bool numbered = false,
  String? scheme,
  String? bullet,
  String? bulletFont,
}) => PptxParagraph(
  level: level,
  numbered: numbered,
  numberingScheme: scheme,
  bulletChar: bullet,
  bulletFontFamily: bulletFont,
  runs: [PptxRun(text: text)],
);

void main() {
  group('EMU', () {
    test('emuToPt', () {
      expect(emuToPt(12700), 1);
      expect(emuToPt(914400), 72);
    });

    test('slideCanvasSize 16:9', () {
      const deck = PptxDeck(
        slideWidthEmu: 12192000,
        slideHeightEmu: 6858000,
        slides: [],
      );
      final s = slideCanvasSize(deck);
      expect(s.width, closeTo(960, 0.001));
      expect(s.height, closeTo(540, 0.001));
    });

    test('rectOfFrame', () {
      final r = rectOfFrame(const PptxRect(127000, 254000, 1270000, 635000));
      expect(r, const Rect.fromLTWH(10, 20, 100, 50));
    });

    test('rotationRadians', () {
      const s = PptxTextShape(
        frame: PptxRect(0, 0, 1, 1),
        rotationDeg: 180,
      );
      expect(rotationRadians(s), closeTo(3.14159265, 1e-6));
    });
  });

  group('căn lề / anchor / insets', () {
    test('textAlignOf', () {
      expect(textAlignOf(PptxAlign.left), TextAlign.left);
      expect(textAlignOf(PptxAlign.center), TextAlign.center);
      expect(textAlignOf(PptxAlign.right), TextAlign.right);
      expect(textAlignOf(PptxAlign.justify), TextAlign.justify);
    });

    test('alignmentOfAnchor', () {
      expect(alignmentOfAnchor(PptxAnchor.top), Alignment.topCenter);
      expect(alignmentOfAnchor(PptxAnchor.middle), Alignment.center);
      expect(alignmentOfAnchor(PptxAnchor.bottom), Alignment.bottomCenter);
    });

    test('insetsOf mặc định = 7.2pt / 3.6pt', () {
      final i = insetsOf(const PptxInsets());
      expect(i.left, closeTo(7.2, 1e-9));
      expect(i.top, closeTo(3.6, 1e-9));
    });

    test('lineHeightFactor', () {
      expect(lineHeightFactor(const PptxParagraph(), 20), 1.2);
      expect(
        lineHeightFactor(const PptxParagraph(lineSpacingPct: 90), 20),
        closeTo(1.08, 1e-9),
      );
      expect(
        lineHeightFactor(const PptxParagraph(lineSpacingPt: 30), 20),
        1.5,
      );
    });
  });

  test('visibleSlideIndexes bỏ slide ẩn', () {
    PptxSlide s(int i, {bool hidden = false}) => PptxSlide(
      index: i,
      background: null,
      shapes: const [],
      notesText: null,
      hidden: hidden,
    );
    final deck = PptxDeck(
      slideWidthEmu: 1,
      slideHeightEmu: 1,
      slides: [s(0), s(1, hidden: true), s(2)],
    );
    expect(visibleSlideIndexes(deck), [0, 2]);
    expect(visibleSlideIndexes(deck, showHidden: true), [0, 1, 2]);
  });

  group('crop ảnh', () {
    test('không crop', () {
      expect(
        cropImageRect(const Size(100, 50), null),
        const Rect.fromLTWH(0, 0, 100, 50),
      );
    });

    test('cắt 25% trái và 25% phải → ảnh gốc rộng gấp đôi, lệch -25%', () {
      final r = cropImageRect(
        const Size(100, 50),
        const PptxCrop(left: 0.25, right: 0.25),
      );
      expect(r.width, closeTo(200, 1e-9));
      expect(r.left, closeTo(-50, 1e-9));
      expect(r.height, 50);
      expect(r.top, 0);
    });

    test('crop quá tay không chia cho 0', () {
      final r = cropImageRect(
        const Size(100, 50),
        const PptxCrop(left: 0.6, right: 0.6),
      );
      expect(r, const Rect.fromLTWH(0, 0, 100, 50));
    });
  });

  group('bullet', () {
    test('đánh số liên tiếp và đếm lại sau đoạn không đánh số', () {
      final labels = bulletLabels([
        _p('a', numbered: true),
        _p('b', numbered: true),
        _p('c', numbered: true, level: 1, scheme: 'alphaLcParenR'),
        _p('d', numbered: true, level: 1, scheme: 'alphaLcParenR'),
        _p('e', numbered: true),
        _p('f'),
        _p('g', numbered: true),
      ]);
      expect(labels, ['1.', '2.', 'a)', 'b)', '3.', null, '1.']);
    });

    test('numberLabel các kiểu', () {
      expect(numberLabel(4, 'romanUcPeriod'), 'IV.');
      expect(numberLabel(9, 'romanLcParenBoth'), '(ix)');
      expect(numberLabel(27, 'alphaUcPeriod'), 'AA.');
      expect(numberLabel(3, 'arabicPlain'), '3');
      expect(numberLabel(3, null), '3.');
    });

    test('bulletGlyph: ký tự thường giữ nguyên, Wingdings đổi sang Unicode', () {
      expect(bulletGlyph(_p('x', bullet: '•')), '•');
      expect(bulletGlyph(_p('x', bullet: '', bulletFont: 'Wingdings')), '▪');
      expect(bulletGlyph(_p('x', bullet: 'Ø', bulletFont: 'Wingdings')), '➢');
      expect(bulletGlyph(_p('x', bullet: '')), '•');
      expect(bulletGlyph(_p('x')), isNull);
    });
  });

  group('bảng', () {
    test('ô gộp ngang + dọc', () {
      const cell = PptxTableCell();
      final t = PptxTableShape(
        frame: const PptxRect(0, 0, 0, 0),
        columnWidthsEmu: const [127000, 254000, 127000],
        rows: const [
          PptxTableRow(
            heightEmu: 127000,
            cells: [
              PptxTableCell(gridSpan: 2, rowSpan: 2),
              PptxTableCell(hMerge: true),
              cell,
            ],
          ),
          PptxTableRow(
            heightEmu: 254000,
            cells: [
              PptxTableCell(vMerge: true),
              PptxTableCell(hMerge: true, vMerge: true),
              cell,
            ],
          ),
        ],
      );
      final boxes = layoutTable(t);
      expect(boxes, hasLength(3));
      expect(boxes[0].rect, const Rect.fromLTRB(0, 0, 30, 30));
      expect(boxes[1].rect, const Rect.fromLTRB(30, 0, 40, 10));
      expect(boxes[2].rect, const Rect.fromLTRB(30, 10, 40, 30));
      expect(tableSize(t), const Size(40, 30));
    });

    test('gridSpan vượt số cột bị chặn', () {
      final t = PptxTableShape(
        frame: const PptxRect(0, 0, 0, 0),
        columnWidthsEmu: const [127000, 127000],
        rows: const [
          PptxTableRow(
            heightEmu: 127000,
            cells: [PptxTableCell(gridSpan: 5, rowSpan: 9)],
          ),
        ],
      );
      expect(layoutTable(t).single.rect, const Rect.fromLTRB(0, 0, 20, 10));
    });
  });

  group('đường vẽ', () {
    test('customPath co theo khung', () {
      const cp = PptxCustomPath(
        widthEmu: 100,
        heightEmu: 100,
        commands: [
          PptxPathCommand(PptxPathOp.moveTo, [0, 0]),
          PptxPathCommand(PptxPathOp.lineTo, [100, 0]),
          PptxPathCommand(PptxPathOp.lineTo, [100, 100]),
          PptxPathCommand(PptxPathOp.close),
        ],
      );
      final b = customPathToFlutter(cp, const Size(200, 50)).getBounds();
      expect(b, const Rect.fromLTRB(0, 0, 200, 50));
    });

    test('arcTo nửa đường tròn', () {
      // Bắt đầu tại (0, 50), bán kính 50, góc 180° quét 180° → qua đỉnh tới (100, 50)...
      const cp = PptxCustomPath(
        widthEmu: 100,
        heightEmu: 100,
        commands: [
          PptxPathCommand(PptxPathOp.moveTo, [0, 50]),
          PptxPathCommand(PptxPathOp.arcTo, [50, 50, 180, 180]),
        ],
      );
      final b = customPathToFlutter(cp, const Size(100, 100)).getBounds();
      expect(b.left, closeTo(0, 0.5));
      expect(b.right, closeTo(100, 0.5));
      expect(b.top, closeTo(0, 0.5));
      expect(b.bottom, closeTo(50, 0.5));
    });

    test('cubic/quad/close không ném lỗi', () {
      const cp = PptxCustomPath(
        widthEmu: 10,
        heightEmu: 10,
        commands: [
          PptxPathCommand(PptxPathOp.moveTo, [0, 0]),
          PptxPathCommand(PptxPathOp.cubicTo, [2, 0, 4, 10, 10, 10]),
          PptxPathCommand(PptxPathOp.quadTo, [5, 5, 0, 10]),
          PptxPathCommand(PptxPathOp.lineTo, [1]), // thiếu tham số → bỏ qua
          PptxPathCommand(PptxPathOp.close),
        ],
      );
      expect(customPathToFlutter(cp, const Size(10, 10)).getBounds().isEmpty,
          isFalse);
    });

    test('presetPath các hình cơ bản', () {
      const size = Size(100, 40);
      expect(presetPath(PptxGeometry.rect, null, size).getBounds(),
          const Rect.fromLTWH(0, 0, 100, 40));
      expect(presetPath(PptxGeometry.ellipse, null, size).getBounds(),
          const Rect.fromLTWH(0, 0, 100, 40));
      expect(presetPath(PptxGeometry.roundRect, null, size).getBounds(),
          const Rect.fromLTWH(0, 0, 100, 40));
      expect(presetPath(PptxGeometry.triangle, null, size).getBounds(),
          const Rect.fromLTWH(0, 0, 100, 40));
      expect(presetPath(PptxGeometry.line, null, size).getBounds(),
          const Rect.fromLTWH(0, 0, 100, 40));
    });

    test('presetPath other: mũi tên, tên lạ → chữ nhật', () {
      const size = Size(100, 40);
      for (final n in [
        'rightArrow',
        'leftArrow',
        'upArrow',
        'downArrow',
        'diamond',
        'hexagon',
        'parallelogram',
      ]) {
        final b = presetPath(PptxGeometry.other, n, size).getBounds();
        expect(b.left, greaterThanOrEqualTo(-0.001), reason: n);
        expect(b.right, lessThanOrEqualTo(100.001), reason: n);
        expect(b.top, greaterThanOrEqualTo(-0.001), reason: n);
        expect(b.bottom, lessThanOrEqualTo(40.001), reason: n);
      }
      expect(presetPath(PptxGeometry.other, 'wave', size).getBounds(),
          const Rect.fromLTWH(0, 0, 100, 40));
      expect(presetPath(PptxGeometry.other, null, size).getBounds(),
          const Rect.fromLTWH(0, 0, 100, 40));
    });
  });
}
