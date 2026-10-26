// Tests against REAL .pptx files written by Microsoft PowerPoint.
// Regenerate with tool/make_real_fixtures.ps1 (needs desktop PowerPoint).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pptx_reader/pptx_reader.dart';
import 'package:test/test.dart';

import 'helpers/pptx_builder.dart';

PptxDeck _load(String name) =>
    readPptx(File('test/fixtures/real/$name').readAsBytesSync());

T _byName<T extends PptxShape>(PptxSlide s, String name) =>
    s.shapes.whereType<T>().firstWhere(
      (e) => e.name == name,
      orElse: () => throw StateError('no ${T.toString()} named $name'),
    );

/// Title/body placeholders are named "Title 1", "Content Placeholder 2"...
PptxTextShape _title(PptxSlide s) => _byName<PptxTextShape>(s, 'Title 1');

double _size(PptxTextShape t) => t.paragraphs.first.runs.first.fontSizePt!;

List<PptxShape> _flatten(Iterable<PptxShape> shapes) => [
  for (final s in shapes) ...[s, if (s is PptxGroupShape) ..._flatten(s.children)],
];

void main() {
  group('deck_16x9.pptx (PowerPoint, default theme)', () {
    late PptxDeck deck;
    setUpAll(() => deck = _load('deck_16x9.pptx'));

    test('slide size and count', () {
      expect(deck.slideWidthEmu, 12192000);
      expect(deck.slideHeightEmu, 6858000);
      expect(deck.slides, hasLength(12));
      expect([for (final s in deck.slides) s.index], List.generate(12, (i) => i));
    });

    test('title slide: text, inherited frames, title bigger than subtitle', () {
      final s = deck.slides[0];
      final title = _title(s);
      final sub = _byName<PptxTextShape>(s, 'Subtitle 2');
      expect(title.paragraphs.single.text, 'Real Deck Title');
      expect(sub.paragraphs.single.text, 'Subtitle line made by PowerPoint');
      // The slide XML has an empty <p:spPr/>: frames come from the layout.
      for (final t in [title, sub]) {
        expect(t.frame.x, greaterThan(0));
        expect(t.frame.y, greaterThan(0));
        expect(t.frame.cx, greaterThan(0));
        expect(t.frame.cy, greaterThan(0));
        expect(t.frame.x + t.frame.cx, lessThanOrEqualTo(deck.slideWidthEmu));
        expect(t.frame.y + t.frame.cy, lessThanOrEqualTo(deck.slideHeightEmu));
      }
      expect(_size(title), 60);
      expect(_size(sub), 24);
      expect(_size(title), greaterThan(_size(sub)));
      expect(title.paragraphs.single.align, PptxAlign.center);
      expect(title.verticalAnchor, PptxAnchor.bottom);
      expect(title.paragraphs.single.runs.single.fontFamily, 'Calibri Light');
      expect(sub.paragraphs.single.runs.single.fontFamily, 'Calibri');
      expect(title.frame.y, lessThan(sub.frame.y));
    });

    test('theme colours resolve to real values', () {
      final title = _title(deck.slides[0]);
      expect(title.paragraphs.single.runs.single.colorArgb, 0xFF000000); // tx1
      final sh = _byName<PptxTextShape>(deck.slides[5], 'EllipseShape');
      // fontRef lt1 -> white
      expect(sh.paragraphs.single.runs.single.colorArgb, 0xFFFFFFFF);
      // table header fill = accent1 (4472C4) from the table style
      final table = _byName<PptxTableShape>(deck.slides[4], 'MergedTable');
      expect(table.rows.first.cells.first.fill?.colorArgb, 0xFF4472C4);
      expect(table.rows[1].cells.first.fill?.colorArgb, isNotNull);
    });

    test('bullets with several levels', () {
      final body = _byName<PptxTextShape>(deck.slides[1], 'Content Placeholder 2');
      final p = body.paragraphs;
      expect(p.map((e) => e.text), [
        'Level one A',
        'Level two A1',
        'Level three A11',
        'Level two A2',
        'Level one B',
      ]);
      expect(p.map((e) => e.level), [0, 1, 2, 1, 0]);
      expect(p.every((e) => e.bulletChar == '•'), isTrue);
      expect(p.map((e) => e.runs.single.fontSizePt), [28, 24, 20, 24, 28]);
      expect(p[0].marginLeftEmu, lessThan(p[1].marginLeftEmu));
      expect(p[1].marginLeftEmu, lessThan(p[2].marginLeftEmu));
      expect(p[0].indentEmu, lessThan(0));
      // title (44pt) bigger than body (28pt)
      expect(_size(_title(deck.slides[1])), 44);
      expect(_size(_title(deck.slides[1])), greaterThan(_size(body)));
      expect(body.frame.y, greaterThan(_title(deck.slides[1]).frame.y));
    });

    test('two content: two placeholders side by side', () {
      final s = deck.slides[2];
      final l = _byName<PptxTextShape>(s, 'Content Placeholder 2');
      final r = _byName<PptxTextShape>(s, 'Content Placeholder 3');
      expect(l.paragraphs.map((e) => e.text), ['Left one', 'Left two']);
      expect(r.paragraphs.map((e) => e.text), ['Right one', 'Right two']);
      expect(l.frame.x, greaterThan(0));
      expect(r.frame.x, greaterThan(l.frame.x + l.frame.cx - 1));
      expect(r.frame.cx, l.frame.cx);
      expect(r.frame.y, l.frame.y);
    });

    test('pictures: bytes, png signature and crop', () {
      final s = deck.slides[3];
      final plain = _byName<PptxPictureShape>(s, 'PlainPicture');
      final cropped = _byName<PptxPictureShape>(s, 'CroppedPicture');
      for (final p in [plain, cropped]) {
        expect(p.extension, 'png');
        expect(p.bytes.length, greaterThan(1000));
        expect(
          Uint8List.sublistView(p.bytes, 0, 8),
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
        );
        expect(p.frame.cx, greaterThan(0));
        expect(p.frame.cy, greaterThan(0));
      }
      expect(plain.crop, isNull);
      expect(cropped.crop, isNotNull);
      expect(cropped.crop!.left, closeTo(0.2, 0.01)); // 60pt of 300pt
      expect(cropped.crop!.top, closeTo(0.1333, 0.01)); // 30pt of 225pt
      expect(cropped.crop!.right, 0);
      expect(cropped.crop!.bottom, 0);
      // the same image is shared: identical bytes
      expect(cropped.bytes, plain.bytes);
    });

    test('table 3x4 with merges', () {
      final t = _byName<PptxTableShape>(deck.slides[4], 'MergedTable');
      expect(t.rows, hasLength(3));
      expect(t.columnWidthsEmu, hasLength(4));
      expect(t.columnWidthsEmu.every((w) => w > 0), isTrue);
      expect(t.rows.every((r) => r.cells.length == 4 && r.heightEmu > 0), isTrue);
      final c = t.rows.map((r) => r.cells).toList();
      expect(c[0][0].paragraphs.map((p) => p.text), ['r1c1', 'r1c2']); // merge keeps both texts
      expect(c[0][0].gridSpan, 2);
      expect(c[0][1].hMerge, isTrue);
      expect(c[0][2].paragraphs.single.text, 'r1c3');
      expect(c[1][3].rowSpan, 2);
      expect(c[1][3].paragraphs.first.text, 'r2c4');
      expect(c[2][3].vMerge, isTrue);
      expect(c[1][0].paragraphs.single.text, 'r2c1');
      expect(c[2][2].paragraphs.single.text, 'r3c3');
      // plain cells are not merged
      expect(c[1][1].gridSpan, 1);
      expect(c[1][1].rowSpan, 1);
      expect(c[1][1].hMerge || c[1][1].vMerge, isFalse);
    });

    test('filled shapes with outline and text', () {
      final s = deck.slides[5];
      final rect = _byName<PptxTextShape>(s, 'RectShape');
      final oval = _byName<PptxTextShape>(s, 'EllipseShape');
      final round = _byName<PptxTextShape>(s, 'RoundShape');
      expect(rect.geometry, PptxGeometry.rect);
      expect(oval.geometry, PptxGeometry.ellipse);
      expect(round.geometry, PptxGeometry.roundRect);
      expect(rect.fill?.colorArgb, 0xFFFFC000);
      expect(oval.fill?.colorArgb, 0xFF00B050);
      expect(round.fill?.colorArgb, 0xFF7030A0);
      expect(rect.line?.colorArgb, 0xFF000080);
      expect(rect.line?.widthEmu, 38100); // 3pt
      expect(oval.line?.colorArgb, 0xFFFF0000);
      expect(oval.line?.widthEmu, 25400);
      expect(round.line, isNull);
      expect(rect.paragraphs.single.text, 'Rect text');
      expect(oval.paragraphs.single.text, 'Ellipse text');
      expect(round.paragraphs.single.text, 'Round text');
      expect(round.paragraphs.single.runs.single.bold, isTrue);
      expect(round.paragraphs.single.runs.single.fontSizePt, 24);
      expect(rect.paragraphs.single.align, PptxAlign.center);
      expect(rect.verticalAnchor, PptxAnchor.middle);
      expect(rect.frame, const PptxRect(762000, 2032000, 3048000, 1778000));
    });

    test('shape style outline uses shade in linear RGB like PowerPoint', () {
      final g = _byName<PptxGroupShape>(deck.slides[6], 'TwoShapeGroup');
      final a = g.children.whereType<PptxTextShape>().first;
      // accent1 4472C4 with <a:shade val="15000"/> (lnRef of default shape style)
      int enc(double lin) {
        final v = lin <= 0.0031308
            ? 12.92 * lin
            : 1.055 * math.pow(lin, 1 / 2.4) - 0.055;
        return (v * 255).round();
      }

      double dec(int c) {
        final v = c / 255;
        return v <= 0.04045
            ? v / 12.92
            : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      }

      final want = [0x44, 0x72, 0xC4].map((c) => enc(dec(c) * 0.15)).toList();
      final got = a.line!.colorArgb;
      expect((got >> 16) & 0xFF, closeTo(want[0], 1));
      expect((got >> 8) & 0xFF, closeTo(want[1], 1));
      expect(got & 0xFF, closeTo(want[2], 1));
    });

    test('group: children in slide coordinates and inside the slide', () {
      final g = _byName<PptxGroupShape>(deck.slides[6], 'TwoShapeGroup');
      expect(g.children, hasLength(2));
      final a = g.children[0] as PptxTextShape;
      final b = g.children[1] as PptxTextShape;
      expect(a.paragraphs.single.text, 'In group A');
      expect(b.paragraphs.single.text, 'In group B');
      expect(a.fill?.colorArgb, 0xFFFF0000);
      expect(b.fill?.colorArgb, 0xFF0000FF);
      expect(b.geometry, PptxGeometry.ellipse);
      for (final c in g.children) {
        expect(c.frame.x, greaterThanOrEqualTo(0));
        expect(c.frame.y, greaterThanOrEqualTo(0));
        expect(c.frame.x + c.frame.cx, lessThanOrEqualTo(deck.slideWidthEmu));
        expect(c.frame.y + c.frame.cy, lessThanOrEqualTo(deck.slideHeightEmu));
        // and inside the group's own frame
        expect(c.frame.x, greaterThanOrEqualTo(g.frame.x));
        expect(c.frame.y, greaterThanOrEqualTo(g.frame.y));
        expect(c.frame.x + c.frame.cx, lessThanOrEqualTo(g.frame.x + g.frame.cx));
        expect(c.frame.y + c.frame.cy, lessThanOrEqualTo(g.frame.y + g.frame.cy));
      }
      expect(b.frame.x, greaterThan(a.frame.x));
    });

    test('own background colour', () {
      expect(deck.slides[7].background?.colorArgb, 0xFF002060);
      expect(_title(deck.slides[7]).paragraphs.single.text, 'Navy background');
      expect(
        _title(deck.slides[7]).paragraphs.single.runs.single.colorArgb,
        0xFFFFFFFF,
      );
      // other slides keep the master background (white)
      expect(deck.slides[0].background?.colorArgb, 0xFFFFFFFF);
    });

    test('speaker notes', () {
      expect(deck.slides[8].notesText, 'First note line\nSecond note line');
      expect(deck.slides[0].notesText, isNull);
    });

    test('hidden slide', () {
      expect([for (final s in deck.slides) s.hidden], [
        for (var i = 0; i < 12; i++) i == 9,
      ]);
      expect(_title(deck.slides[9]).paragraphs.single.text, 'Hidden slide');
    });

    test('Vietnamese stacked diacritics and Chinese survive intact', () {
      final s = deck.slides[10];
      expect(
        _title(s).paragraphs.single.text,
        'Tiếng Việt 中文',
      );
      final body = _byName<PptxTextShape>(s, 'Content Placeholder 2');
      expect(body.paragraphs.map((p) => p.text), [
        'Cộng hòa xã hội chủ nghĩa Việt Nam',
        'Những đường ống dầu, ngặt nghèo, rực rỡ',
        '你好，世界。这是中文测试',
      ]);
    });

    test('chart is reported as unsupported with a frame', () {
      final c = _byName<PptxTextShape>(deck.slides[11], 'SalesChart');
      expect(c.unsupportedKind, 'chart');
      expect(c.frame.cx, greaterThan(0));
      expect(c.frame.cy, greaterThan(0));
      expect(c.frame.x, greaterThan(0));
      expect(c.paragraphs, isEmpty);
    });

    test('every shape frame is sane', () {
      for (final s in deck.slides) {
        for (final sh in _flatten(s.shapes)) {
          expect(sh.frame.cx, greaterThanOrEqualTo(0), reason: sh.name);
          expect(sh.frame.cy, greaterThanOrEqualTo(0), reason: sh.name);
          expect(sh.frame.x.abs(), lessThan(deck.slideWidthEmu * 2));
          expect(sh.frame.y.abs(), lessThan(deck.slideHeightEmu * 2));
        }
      }
    });
  });

  group('deck_4x3_theme.pptx (PowerPoint, Facet design theme)', () {
    late PptxDeck deck;
    setUpAll(() => deck = _load('deck_4x3_theme.pptx'));

    test('4:3 size and slide count', () {
      expect(deck.slideWidthEmu, 9144000);
      expect(deck.slideHeightEmu, 6858000);
      expect(deck.slides, hasLength(2));
    });

    test('texts, theme colour and fonts come from the Facet theme', () {
      final t0 = _title(deck.slides[0]);
      expect(t0.paragraphs.single.text, 'Themed 4:3 title');
      expect(t0.paragraphs.single.runs.single.colorArgb, 0xFF90C226); // accent1
      expect(t0.paragraphs.single.runs.single.fontFamily, 'Trebuchet MS');
      expect(t0.paragraphs.single.align, PptxAlign.right);
      final sub = _byName<PptxTextShape>(deck.slides[0], 'Subtitle 2');
      expect(sub.paragraphs.single.text, 'Applied theme: Facet');
      expect(_size(t0), greaterThan(_size(sub)));

      final t1 = _title(deck.slides[1]);
      final body = _byName<PptxTextShape>(deck.slides[1], 'Content Placeholder 2');
      expect(t1.paragraphs.single.text, 'Themed content');
      expect(body.paragraphs.map((p) => p.text), [
        'Point one',
        'Sub point',
        'Point two',
      ]);
      expect(body.paragraphs.map((p) => p.level), [0, 1, 0]);
      expect(_size(t1), greaterThan(_size(body)));
      expect(body.paragraphs.first.runs.single.colorArgb, isNot(0));
      expect(body.paragraphs.first.bulletChar, isNotNull);
    });

    test('placeholder frames are inherited from the layout inside the slide', () {
      for (final s in deck.slides) {
        for (final name in ['Title 1']) {
          final t = _byName<PptxTextShape>(s, name);
          expect(t.frame.x, greaterThan(0));
          expect(t.frame.y, greaterThan(0));
          expect(t.frame.cx, greaterThan(0));
          expect(t.frame.x + t.frame.cx, lessThanOrEqualTo(deck.slideWidthEmu));
          expect(t.frame.y + t.frame.cy, lessThanOrEqualTo(deck.slideHeightEmu));
        }
      }
    });

    test('master decoration group is prepended and drawn behind the text', () {
      for (final s in deck.slides) {
        final groupIdx = s.shapes.indexWhere((e) => e is PptxGroupShape);
        final titleIdx = s.shapes.indexWhere((e) => e.name == 'Title 1');
        expect(groupIdx, greaterThanOrEqualTo(0));
        expect(groupIdx, lessThan(titleIdx));
        final g = s.shapes[groupIdx] as PptxGroupShape;
        expect(g.children.length, greaterThan(5));
        // semi transparent accent fills keep their alpha
        final alphas = g.children
            .whereType<PptxTextShape>()
            .map((c) => c.fill?.colorArgb)
            .whereType<int>()
            .map((c) => c >>> 24);
        expect(alphas.any((a) => a > 0 && a < 255), isTrue);
      }
    });

    test('freeform (custGeom) decoration keeps its outline path', () {
      final g = deck.slides[0].shapes.whereType<PptxGroupShape>().first;
      final free = g.children
          .whereType<PptxTextShape>()
          .where((c) => c.geometry == PptxGeometry.other)
          .toList();
      expect(free, isNotEmpty);
      for (final f in free) {
        expect(f.customPaths, isNotEmpty, reason: f.name);
        final path = f.customPaths.first;
        expect(path.widthEmu, greaterThan(0));
        expect(path.commands.first.kind, PptxPathOp.moveTo);
        expect(path.commands.any((c) => c.kind == PptxPathOp.lineTo), isTrue);
      }
    });
  });

  group('deck_extras.pptx (PowerPoint, text box / transforms / fills / footer)', () {
    late PptxDeck deck;
    setUpAll(() => deck = _load('deck_extras.pptx'));

    test('text box: character formatting, hyperlink, numbering, alignment', () {
      final box = _byName<PptxTextShape>(deck.slides[0], 'FormatBox');
      expect(box.paragraphs, hasLength(5));
      final first = box.paragraphs[0].runs.single;
      expect(first.bold, isTrue);
      expect(first.italic, isTrue);
      expect(first.underline, isTrue);
      expect(first.colorArgb, 0xFFED7D31); // accent2
      expect(first.fontSizePt, 20);
      final link = box.paragraphs[1].runs.where((r) => r.hyperlink != null);
      expect(link.map((r) => r.text), ['site']);
      expect(link.single.hyperlink, 'https://example.com/');
      expect(box.paragraphs[2].numbered, isTrue);
      expect(box.paragraphs[2].numberingScheme, 'arabicPeriod');
      expect(box.paragraphs[2].marginLeftEmu, greaterThan(0));
      expect(box.paragraphs[3].numbered, isTrue);
      expect(box.paragraphs[4].align, PptxAlign.right);
      expect(box.paragraphs[4].numbered, isFalse);
      expect(box.paragraphs[0].bulletChar, isNull);
    });

    test('subscript and superscript baseline offsets', () {
      final box = _byName<PptxTextShape>(deck.slides[0], 'ScriptBox');
      final runs = box.paragraphs.single.runs;
      expect(runs.map((r) => r.text).join(), 'H2O and x2');
      expect(runs.firstWhere((r) => r.text == '2').baselineOffsetPct, -25);
      expect(runs.last.text, '2');
      expect(runs.last.baselineOffsetPct, 30);
      expect(runs.first.baselineOffsetPct, 0);
    });

    test('rotation, flip, preset names, line, gradient, picture fill', () {
      final s = deck.slides[1];
      expect(_byName<PptxTextShape>(s, 'Rotated').rotationDeg, 30);
      final tri = _byName<PptxTextShape>(s, 'FlippedTriangle');
      expect(tri.flipH, isTrue);
      expect(tri.flipV, isFalse);
      expect(tri.geometry, PptxGeometry.triangle);
      final arrow = _byName<PptxTextShape>(s, 'RightArrow');
      expect(arrow.geometry, PptxGeometry.other);
      expect(arrow.presetGeometry, 'rightArrow');
      final line = _byName<PptxTextShape>(s, 'DiagLine');
      expect(line.geometry, PptxGeometry.line);
      expect(line.line?.colorArgb, 0xFFC00000);
      expect(line.line?.widthEmu, 50800);
      expect(line.fill, isNull);
      // gradient approximated by the first stop
      expect(
        _byName<PptxTextShape>(s, 'GradientRect').fill?.colorArgb,
        0xFFFF0000,
      );
      final pf = _byName<PptxTextShape>(s, 'PictureFillRect').fill;
      expect(pf?.isPicture, isTrue);
      expect(pf?.imageExtension, 'png');
      expect(pf?.imageBytes?.length, greaterThan(1000));
    });

    test('default outline is PowerPoint 172C51 (lnRef accent1 shade 15%)', () {
      final r = _byName<PptxTextShape>(deck.slides[1], 'Rotated');
      expect(r.line?.colorArgb, 0xFF172C51);
      expect(r.line?.widthEmu, 12700);
    });

    test('footer and slide number placeholders come from the layout', () {
      final s = deck.slides[2];
      final f = _byName<PptxTextShape>(s, 'Footer Placeholder 3');
      final n = _byName<PptxTextShape>(s, 'Slide Number Placeholder 4');
      expect(f.paragraphs.single.text, 'My footer text');
      expect(n.paragraphs.single.text, '3');
      expect(f.frame.y, greaterThan(deck.slideHeightEmu * 0.85));
      expect(n.frame.x, greaterThan(f.frame.x));
      expect(f.paragraphs.single.align, PptxAlign.center);
      expect(n.paragraphs.single.align, PptxAlign.right);
      expect(_size(f), 12);
      expect(f.paragraphs.single.runs.single.colorArgb, isNot(0xFF000000));
    });

    test('long list keeps all 30 paragraphs', () {
      final body = _byName<PptxTextShape>(
        deck.slides[3],
        'Content Placeholder 2',
      );
      expect(body.paragraphs, hasLength(30));
      expect(body.paragraphs.last.text, startsWith('Line number 30'));
    });
  });

  // deck_organic.pptx is not committed (1 MB texture background); regenerate
  // it with tool/make_real_fixtures.ps1 to run these.
  group('deck_organic.pptx (PowerPoint, texture background via bgRef 1003)', () {
    final file = File('test/fixtures/real/deck_organic.pptx');
    final skip = file.existsSync() ? null : 'run tool/make_real_fixtures.ps1';

    test('theme texture background is extracted as a picture', () {
      final deck = _load('deck_organic.pptx');
      for (final s in deck.slides) {
        expect(s.background?.isPicture, isTrue);
        expect(s.background?.imageBytes?.length, greaterThan(10000));
      }
    }, skip: skip);

    test('decoration group (pictures + frame) is behind the text', () {
      final deck = _load('deck_organic.pptx');
      final s = deck.slides[0];
      final g = s.shapes.whereType<PptxGroupShape>().first;
      expect(g.children.whereType<PptxPictureShape>(), isNotEmpty);
      final titleIdx = s.shapes.indexWhere((e) => e.name == 'Title 1');
      expect(s.shapes.indexOf(g), lessThan(titleIdx));
      expect(_title(s).paragraphs.single.runs.single.fontFamily, 'Garamond');
    }, skip: skip);
  });

  group('theme fill styles (synthetic)', () {
    PptxDeck read(String bgFillStyles, String masterBg) {
      final b = PptxBuilder()
        ..slides.add(TestSlide(''))
        ..masterBg = masterBg
        ..theme = defaultTheme.replaceFirst(
          RegExp(r'<a:bgFillStyleLst>.*</a:bgFillStyleLst>', dotAll: true),
          '<a:bgFillStyleLst>$bgFillStyles</a:bgFillStyleLst>',
        );
      return readPptx(b.build());
    }

    test('bgRef 1002 uses the 2nd theme background style (first stop)', () {
      final deck = read(
        '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
        '<a:gradFill><a:gsLst>'
        '<a:gs pos="0"><a:schemeClr val="phClr"><a:shade val="50000"/></a:schemeClr></a:gs>'
        '<a:gs pos="100000"><a:schemeClr val="phClr"/></a:gs></a:gsLst></a:gradFill>',
        '<p:bg><p:bgRef idx="1002"><a:srgbClr val="FFFFFF"/></p:bgRef></p:bg>',
      );
      final c = deck.slides.single.background!.colorArgb!;
      // shade 50% of white in linear RGB = 0xBC (not 0x80)
      expect(c & 0xFF, closeTo(0xBC, 1));
      expect(c >>> 24, 0xFF);
    });

    test('bgRef 1001 and a missing style fall back to the reference colour', () {
      final one = read(
        '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>',
        '<p:bg><p:bgRef idx="1001"><a:srgbClr val="123456"/></p:bgRef></p:bg>',
      );
      expect(one.slides.single.background!.colorArgb, 0xFF123456);
      final missing = read(
        '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>',
        '<p:bg><p:bgRef idx="1003"><a:srgbClr val="654321"/></p:bgRef></p:bg>',
      );
      expect(missing.slides.single.background!.colorArgb, 0xFF654321);
    });
  });
}
