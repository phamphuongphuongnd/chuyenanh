import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pptx_reader/pptx_reader.dart';
import 'package:test/test.dart';

import 'helpers/pptx_builder.dart';

PptxDeck _read(PptxBuilder b) => readPptx(b.build());

PptxBuilder _deck(List<TestSlide> slides) =>
    PptxBuilder()..slides.addAll(slides);

T _only<T extends PptxShape>(PptxSlide s) => s.shapes.whereType<T>().single;

void main() {
  group('presentation', () {
    test('reads slide size', () {
      final b = _deck([TestSlide('')])
        ..slideWidth = 9144000
        ..slideHeight = 6858000;
      final deck = _read(b);
      expect(deck.slideWidthEmu, 9144000);
      expect(deck.slideHeightEmu, 6858000);
      expect(deck.slides, hasLength(1));
    });

    test('slide order follows presentation.xml, not file names', () {
      final b = _deck([
        for (final t in ['first', 'second', 'third'])
          TestSlide(sp(spPr: xfrm(0, 0, 100, 100), txBody: txBody(para(t)))),
      ])..reverseFileNames = true;
      final deck = _read(b);
      expect(
        deck.slides.map((s) => _only<PptxTextShape>(s).paragraphs.single.text),
        ['first', 'second', 'third'],
      );
      expect(deck.slides.map((s) => s.index), [0, 1, 2]);
    });

    test('hidden slide flag and hidden shapes', () {
      final deck = _read(
        _deck([
          TestSlide(
            sp(spPr: xfrm(0, 0, 1, 1), cNvPrAttrs: ' hidden="1"') +
                sp(id: 3, spPr: xfrm(0, 0, 2, 2)),
            sldAttrs: ' show="0"',
          ),
        ]),
      );
      expect(deck.slides.single.hidden, isTrue);
      expect(deck.slides.single.shapes, hasLength(1));
      expect(
        deck.slides.single.shapes.single.frame,
        const PptxRect(0, 0, 2, 2),
      );
    });
  });

  group('text', () {
    test('run formatting, line break, paragraph properties', () {
      final paragraphs =
          '<a:p><a:pPr algn="r" lvl="1"><a:spcBef><a:spcPts val="600"/></a:spcBef>'
          '<a:spcAft><a:spcPts val="1200"/></a:spcAft><a:lnSpc><a:spcPct val="150000"/></a:lnSpc>'
          '<a:buChar char="o"/></a:pPr>'
          '<a:r><a:rPr lang="en-US" b="1" i="1" u="sng" strike="sngStrike" sz="2000">'
          '${solid('FF0000')}<a:latin typeface="Arial"/></a:rPr><a:t>Bold</a:t></a:r>'
          '<a:br><a:rPr lang="en-US"/></a:br>'
          '<a:r><a:rPr lang="en-US"/><a:t>plain</a:t></a:r></a:p>'
          '<a:p><a:pPr algn="just"><a:buAutoNum type="arabicPeriod"/></a:pPr>'
          '<a:r><a:rPr lang="en-US" sz="1000" baseline="30000"/><a:t>x</a:t></a:r></a:p>';
      final deck = _read(
        _deck([
          TestSlide(
            sp(
              spPr:
                  '${xfrm(10, 20, 300, 400, attrs: ' rot="5400000" flipH="1"')}'
                  '<a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom>${solid('00FF00')}'
                  '<a:ln w="25400">${solid('0000FF')}</a:ln>',
              txBody: txBody(
                paragraphs,
                bodyPr:
                    '<a:bodyPr lIns="0" tIns="1" rIns="2" bIns="3" anchor="b"/>',
              ),
            ),
          ),
        ]),
      );
      final shape = _only<PptxTextShape>(deck.slides.single);
      expect(shape.frame, const PptxRect(10, 20, 300, 400));
      expect(shape.rotationDeg, 90);
      expect(shape.flipH, isTrue);
      expect(shape.flipV, isFalse);
      expect(shape.geometry, PptxGeometry.ellipse);
      expect(shape.fill!.colorArgb, 0xFF00FF00);
      expect(shape.line!.colorArgb, 0xFF0000FF);
      expect(shape.line!.widthEmu, 25400);
      expect(shape.insets.left, 0);
      expect(shape.insets.top, 1);
      expect(shape.insets.right, 2);
      expect(shape.insets.bottom, 3);
      expect(shape.verticalAnchor, PptxAnchor.bottom);

      final p = shape.paragraphs[0];
      expect(p.align, PptxAlign.right);
      expect(p.level, 1);
      expect(p.bulletChar, 'o');
      expect(p.numbered, isFalse);
      expect(p.spaceBeforePt, 6);
      expect(p.spaceAfterPt, 12);
      expect(p.lineSpacingPct, 150);
      expect(p.runs, hasLength(3));
      final r = p.runs[0];
      expect(r.text, 'Bold');
      expect(r.bold, isTrue);
      expect(r.italic, isTrue);
      expect(r.underline, isTrue);
      expect(r.strike, isTrue);
      expect(r.fontSizePt, 20);
      expect(r.colorArgb, 0xFFFF0000);
      expect(r.fontFamily, 'Arial');
      expect(p.runs[1].isLineBreak, isTrue);
      expect(p.runs[1].text, '\n');
      final plain = p.runs[2];
      expect(plain.bold, isFalse);
      expect(plain.underline, isFalse);
      // otherStyle defines only lvl1 -> level 1 falls back to built-in 18pt.
      expect(plain.fontSizePt, 18);
      expect(plain.fontFamily, isNull);

      final p2 = shape.paragraphs[1];
      expect(p2.align, PptxAlign.justify);
      expect(p2.numbered, isTrue);
      expect(p2.numberingScheme, 'arabicPeriod');
      final x = p2.runs.single;
      expect(x.baselineOffsetPct, 30);
      // Non-placeholder shape, level 0: font + colour from master otherStyle.
      expect(x.fontSizePt, 10);
      expect(x.fontFamily, 'Calibri');
      expect(x.colorArgb, 0xFF000000);
    });

    test('normAutofit fontScale and lnSpcReduction', () {
      final deck = _read(
        _deck([
          TestSlide(
            sp(
              spPr: xfrm(0, 0, 10, 10),
              txBody: txBody(
                para('t', rPr: ' sz="4000"'),
                bodyPr:
                    '<a:bodyPr><a:normAutofit fontScale="50000" lnSpcReduction="20000"/></a:bodyPr>',
              ),
            ),
          ),
        ]),
      );
      final p = _only<PptxTextShape>(deck.slides.single).paragraphs.single;
      expect(p.runs.single.fontSizePt, 20);
      expect(p.lineSpacingPct, 80);
    });
  });

  group('placeholder inheritance', () {
    test('title: frame from layout, size/font/bullet from master', () {
      final deck = _read(
        _deck([
          TestSlide(
            sp(
              name: 'Title',
              ph: 'type="title"',
              txBody: txBody(para('Hello')),
            ),
          ),
        ]),
      );
      final shape = _only<PptxTextShape>(deck.slides.single);
      expect(shape.frame, const PptxRect(1000000, 500000, 10000000, 1000000));
      // bodyPr anchor inherited from the master title placeholder.
      expect(shape.verticalAnchor, PptxAnchor.middle);
      final p = shape.paragraphs.single;
      expect(p.bulletChar, isNull);
      expect(p.runs.single.fontSizePt, 44);
      expect(p.runs.single.fontFamily, 'Calibri Light');
      expect(p.runs.single.colorArgb, 0xFF000000);
    });

    test('body: frame from master via layout idx, level styles, lstStyle', () {
      final b =
          _deck([
              TestSlide(
                sp(
                  ph: 'idx="1"',
                  txBody: txBody(
                    para('L1') +
                        para('L2', pPr: '<a:pPr lvl="1"/>') +
                        para('big', rPr: ' sz="1200"'),
                  ),
                ),
              ),
            ])
            ..layoutShapes = sp(
              id: 3,
              name: 'Content',
              ph: 'idx="1"',
              txBody: txBody(
                '<a:p/>',
                lstStyle:
                    '<a:lvl1pPr algn="ctr"><a:defRPr sz="3000"/></a:lvl1pPr>',
              ),
            );
      final shape = _only<PptxTextShape>(_read(b).slides.single);
      expect(shape.frame, const PptxRect(838200, 1825625, 10515600, 4351338));
      final ps = shape.paragraphs;
      expect(ps[0].align, PptxAlign.center); // layout lstStyle
      expect(ps[0].runs.single.fontSizePt, 30); // layout lstStyle beats master
      expect(ps[0].bulletChar, '•'); // master bodyStyle
      expect(ps[0].marginLeftEmu, 228600);
      expect(ps[0].indentEmu, -228600);
      expect(ps[0].spaceBeforePt, 10);
      expect(ps[1].level, 1);
      expect(ps[1].bulletChar, '–');
      expect(ps[1].runs.single.fontSizePt, 24);
      expect(ps[1].align, PptxAlign.left);
      expect(ps[2].runs.single.fontSizePt, 12); // run rPr wins
    });

    test('slide xfrm overrides placeholder xfrm', () {
      final deck = _read(
        _deck([
          TestSlide(
            sp(
              ph: 'type="title"',
              spPr: xfrm(1, 2, 3, 4),
              txBody: txBody(para('x')),
            ),
          ),
        ]),
      );
      expect(
        deck.slides.single.shapes.single.frame,
        const PptxRect(1, 2, 3, 4),
      );
    });

    test('master/layout decorative shapes are included unless showMasterSp=0', () {
      final b = _deck([TestSlide(sp(spPr: xfrm(5, 5, 5, 5)))])
        ..masterShapes =
            '$defaultMasterShapes${sp(id: 9, name: 'MasterDeco', spPr: xfrm(0, 0, 7, 7) + solid('123456'))}'
        ..layoutShapes =
            '$defaultLayoutShapes${sp(id: 9, name: 'LayoutDeco', spPr: xfrm(0, 0, 8, 8))}';
      final shapes = _read(b).slides.single.shapes;
      expect(shapes.map((s) => s.name), ['MasterDeco', 'LayoutDeco', 'Shape']);

      b.layoutAttrs = ' showMasterSp="0"';
      expect(_read(b).slides.single.shapes.map((s) => s.name), [
        'LayoutDeco',
        'Shape',
      ]);
    });
  });

  group('colors', () {
    String colored(String clr) =>
        sp(spPr: '${xfrm(0, 0, 1, 1)}<a:solidFill>$clr</a:solidFill>');

    int fillOf(String clr) {
      final deck = _read(_deck([TestSlide(colored(clr))]));
      return _only<PptxTextShape>(deck.slides.single).fill!.colorArgb!;
    }

    test('schemeClr through clrMap and theme', () {
      expect(fillOf('<a:schemeClr val="accent1"/>'), 0xFF4472C4);
      expect(fillOf('<a:schemeClr val="tx1"/>'), 0xFF000000);
      expect(fillOf('<a:schemeClr val="bg1"/>'), 0xFFFFFFFF);
      expect(fillOf('<a:schemeClr val="tx2"/>'), 0xFF44546A);
    });

    test('lumMod / lumOff match PowerPoint palette', () {
      expect(
        fillOf(
          '<a:schemeClr val="accent1"><a:lumMod val="60000"/><a:lumOff val="40000"/></a:schemeClr>',
        ),
        0xFF8FAADC,
      );
      expect(
        fillOf(
          '<a:schemeClr val="accent1"><a:lumMod val="75000"/></a:schemeClr>',
        ),
        0xFF2F5597,
      );
      expect(
        fillOf(
          '<a:schemeClr val="tx1"><a:lumMod val="65000"/><a:lumOff val="35000"/></a:schemeClr>',
        ),
        0xFF595959,
      );
    });

    test('prstClr, sysClr, alpha, shade, tint', () {
      expect(fillOf('<a:prstClr val="red"/>'), 0xFFFF0000);
      expect(
        fillOf('<a:sysClr val="windowText" lastClr="112233"/>'),
        0xFF112233,
      );
      expect(
        fillOf('<a:srgbClr val="FF0000"><a:alpha val="50000"/></a:srgbClr>'),
        0x80FF0000,
      );
      expect(
        fillOf('<a:srgbClr val="FFFFFF"><a:shade val="50000"/></a:srgbClr>') &
            0xFFFFFF,
        isNot(0xFFFFFF),
      );
      expect(
        fillOf('<a:srgbClr val="000000"><a:tint val="50000"/></a:srgbClr>') &
            0xFFFFFF,
        isNot(0),
      );
    });

    test('p:style fillRef / lnRef / fontRef', () {
      final style =
          '<p:style><a:lnRef idx="2"><a:schemeClr val="accent2"/></a:lnRef>'
          '<a:fillRef idx="1"><a:schemeClr val="accent1"/></a:fillRef>'
          '<a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef>'
          '<a:fontRef idx="minor"><a:schemeClr val="lt1"/></a:fontRef></p:style>';
      final deck = _read(
        _deck([
          TestSlide(
            sp(spPr: xfrm(0, 0, 1, 1), style: style, txBody: txBody(para('w'))),
          ),
        ]),
      );
      final s = _only<PptxTextShape>(deck.slides.single);
      expect(s.fill!.colorArgb, 0xFF4472C4);
      expect(s.line!.colorArgb, 0xFFED7D31);
      expect(s.line!.widthEmu, 12700);
      expect(s.paragraphs.single.runs.single.colorArgb, 0xFFFFFFFF);
    });

    test('noFill is no fill', () {
      final deck = _read(
        _deck([
          TestSlide(
            sp(spPr: '${xfrm(0, 0, 1, 1)}<a:noFill/><a:ln><a:noFill/></a:ln>'),
          ),
        ]),
      );
      final s = _only<PptxTextShape>(deck.slides.single);
      expect(s.fill, isNull);
      expect(s.line, isNull);
    });
  });

  group('pictures', () {
    test('picture bytes, extension and crop', () {
      final pic =
          '<p:pic><p:nvPicPr><p:cNvPr id="4" name="Pic"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>'
          '<p:blipFill><a:blip r:embed="rId5"/><a:srcRect l="10000" t="5000" r="20000"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>'
          '<p:spPr>${xfrm(100, 200, 300, 400)}<a:prstGeom prst="rect"/></p:spPr></p:pic>';
      final b = _deck([
        TestSlide(pic, media: {'rId5': 'image1.png'}),
      ])..media['image1.png'] = kTinyPng;
      final shape = _only<PptxPictureShape>(_read(b).slides.single);
      expect(shape.frame, const PptxRect(100, 200, 300, 400));
      expect(shape.bytes, kTinyPng);
      expect(shape.extension, 'png');
      expect(shape.crop!.left, closeTo(0.1, 1e-9));
      expect(shape.crop!.top, closeTo(0.05, 1e-9));
      expect(shape.crop!.right, closeTo(0.2, 1e-9));
      expect(shape.crop!.bottom, 0);
    });

    test('picture with missing image does not crash', () {
      final pic =
          '<p:pic><p:nvPicPr><p:cNvPr id="4" name="Pic"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>'
          '<p:blipFill><a:blip r:embed="rId99"/></p:blipFill><p:spPr>${xfrm(1, 2, 3, 4)}</p:spPr></p:pic>';
      final shape = _read(_deck([TestSlide(pic)])).slides.single.shapes.single;
      expect(shape, isA<PptxTextShape>());
      expect(shape.frame, const PptxRect(1, 2, 3, 4));
    });
  });

  group('tables', () {
    test('grid, merged cells, fills, text', () {
      String tc(String text, {String attrs = '', String tcPr = '<a:tcPr/>'}) =>
          '<a:tc$attrs><a:txBody><a:bodyPr/><a:lstStyle/>${para(text)}</a:txBody>$tcPr</a:tc>';
      final tbl =
          '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="5" name="Table"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>'
          '<p:xfrm><a:off x="1000" y="2000"/><a:ext cx="3000" cy="800"/></p:xfrm>'
          '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table"><a:tbl>'
          '<a:tblPr firstRow="1"/><a:tblGrid><a:gridCol w="1000"/><a:gridCol w="1000"/><a:gridCol w="1000"/></a:tblGrid>'
          '<a:tr h="400">${tc('A', attrs: ' gridSpan="2"', tcPr: '<a:tcPr anchor="ctr" marL="0">${solid('FFFF00')}</a:tcPr>')}'
          '${tc('', attrs: ' hMerge="1"')}${tc('C', attrs: ' rowSpan="2"')}</a:tr>'
          '<a:tr h="400">${tc('D')}${tc('E')}${tc('', attrs: ' vMerge="1"')}</a:tr>'
          '</a:tbl></a:graphicData></a:graphic></p:graphicFrame>';
      final table = _only<PptxTableShape>(
        _read(_deck([TestSlide(tbl)])).slides.single,
      );
      expect(table.frame, const PptxRect(1000, 2000, 3000, 800));
      expect(table.columnWidthsEmu, [1000, 1000, 1000]);
      expect(table.rows.map((r) => r.heightEmu), [400, 400]);
      final a = table.rows[0].cells[0];
      expect(a.gridSpan, 2);
      expect(a.fill!.colorArgb, 0xFFFFFF00);
      expect(a.verticalAnchor, PptxAnchor.middle);
      expect(a.insets.left, 0);
      expect(a.paragraphs.single.text, 'A');
      expect(a.paragraphs.single.runs.single.fontSizePt, 18);
      expect(table.rows[0].cells[1].hMerge, isTrue);
      expect(table.rows[0].cells[2].rowSpan, 2);
      expect(table.rows[1].cells[2].vMerge, isTrue);
      expect(table.rows[1].cells[1].paragraphs.single.text, 'E');
    });

    test('table style: header row, banding, borders, header text', () {
      String tc(String t) =>
          '<a:tc><a:txBody><a:bodyPr/><a:lstStyle/>${para(t)}</a:txBody><a:tcPr/></a:tc>';
      String tr(String a, String b) => '<a:tr h="100">${tc(a)}${tc(b)}</a:tr>';
      final tbl =
          '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="5" name="T"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>'
          '<p:xfrm><a:off x="0" y="0"/><a:ext cx="200" cy="300"/></p:xfrm>'
          '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table"><a:tbl>'
          '<a:tblPr firstRow="1" bandRow="1"><a:tableStyleId>{S1}</a:tableStyleId></a:tblPr>'
          '<a:tblGrid><a:gridCol w="100"/><a:gridCol w="100"/></a:tblGrid>'
          '${tr('h1', 'h2')}${tr('a', 'b')}${tr('c', 'd')}</a:tbl></a:graphicData></a:graphic></p:graphicFrame>';
      final b = _deck([TestSlide(tbl)])
        ..tableStyles =
            '<a:tblStyle styleId="{S1}" styleName="Test">'
            '<a:wholeTbl><a:tcTxStyle><a:fontRef idx="minor"/><a:schemeClr val="dk1"/></a:tcTxStyle>'
            '<a:tcStyle><a:tcBdr><a:insideH><a:ln w="12700">${solid('FFFFFF')}</a:ln></a:insideH></a:tcBdr>'
            '<a:fill><a:solidFill><a:schemeClr val="accent1"><a:tint val="20000"/></a:schemeClr></a:solidFill></a:fill></a:tcStyle></a:wholeTbl>'
            '<a:band1H><a:tcStyle><a:tcBdr/><a:fill>${solid('CCCCCC')}</a:fill></a:tcStyle></a:band1H>'
            '<a:firstRow><a:tcTxStyle b="on"><a:schemeClr val="lt1"/></a:tcTxStyle>'
            '<a:tcStyle><a:tcBdr/><a:fill><a:solidFill><a:schemeClr val="accent1"/></a:solidFill></a:fill></a:tcStyle></a:firstRow>'
            '</a:tblStyle>';
      final t = _only<PptxTableShape>(_read(b).slides.single);
      final header = t.rows[0].cells[0];
      expect(header.fill!.colorArgb, 0xFF4472C4);
      expect(header.paragraphs.single.runs.single.bold, isTrue);
      expect(header.paragraphs.single.runs.single.colorArgb, 0xFFFFFFFF);
      expect(t.rows[1].cells[0].fill!.colorArgb, 0xFFCCCCCC); // band1H
      final plainRow = t.rows[2].cells[1];
      expect(plainRow.fill!.colorArgb, isNot(0xFFCCCCCC)); // band2H -> wholeTbl
      expect(plainRow.paragraphs.single.runs.single.bold, isFalse);
      expect(plainRow.paragraphs.single.runs.single.colorArgb, 0xFF000000);
      expect(plainRow.borderTop!.colorArgb, 0xFFFFFFFF); // insideH
      expect(plainRow.borderBottom, isNull); // outer edge, no 'bottom' defined
    });

    test('chart / SmartArt frames become empty text shapes', () {
      final chart =
          '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="5" name="Chart"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>'
          '<p:xfrm><a:off x="1" y="2"/><a:ext cx="3" cy="4"/></p:xfrm>'
          '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart"><c:chart xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" r:id="rId7"/></a:graphicData></a:graphic></p:graphicFrame>';
      final s = _only<PptxTextShape>(
        _read(_deck([TestSlide(chart)])).slides.single,
      );
      expect(s.frame, const PptxRect(1, 2, 3, 4));
      expect(s.paragraphs, isEmpty);
      expect(s.unsupportedKind, 'chart');
    });
  });

  group('groups and connectors', () {
    test('group converts child coordinates (nested)', () {
      final grp =
          '<p:grpSp><p:nvGrpSpPr><p:cNvPr id="10" name="G"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
          '<p:grpSpPr><a:xfrm><a:off x="1000" y="1000"/><a:ext cx="2000" cy="2000"/><a:chOff x="0" y="0"/><a:chExt cx="1000" cy="1000"/></a:xfrm></p:grpSpPr>'
          '${sp(id: 11, name: 'child', spPr: xfrm(100, 100, 200, 200))}'
          '<p:grpSp><p:nvGrpSpPr><p:cNvPr id="12" name="G2"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
          '<p:grpSpPr><a:xfrm><a:off x="500" y="500"/><a:ext cx="500" cy="500"/><a:chOff x="5000" y="5000"/><a:chExt cx="1000" cy="1000"/></a:xfrm></p:grpSpPr>'
          '${sp(id: 13, name: 'grandchild', spPr: xfrm(5000, 5200, 1000, 400))}'
          '</p:grpSp></p:grpSp>';
      final g = _only<PptxGroupShape>(
        _read(_deck([TestSlide(grp)])).slides.single,
      );
      expect(g.frame, const PptxRect(1000, 1000, 2000, 2000));
      expect(g.children[0].frame, const PptxRect(1200, 1200, 400, 400));
      final g2 = g.children[1] as PptxGroupShape;
      expect(g2.frame, const PptxRect(2000, 2000, 1000, 1000));
      // grandchild: inner -> (500 + 0*0.5, 500 + 200*0.5, 500, 200) -> outer *2 + 1000
      expect(g2.children.single.frame, const PptxRect(2000, 2200, 1000, 400));
    });

    test('connector becomes a line shape', () {
      final cxn =
          '<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="6" name="Line"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>'
          '<p:spPr>${xfrm(0, 0, 500, 0, attrs: ' flipV="1"')}<a:prstGeom prst="straightConnector1"><a:avLst/></a:prstGeom>'
          '<a:ln w="19050">${solid('00FF00')}</a:ln></p:spPr></p:cxnSp>';
      final s = _only<PptxTextShape>(
        _read(_deck([TestSlide(cxn)])).slides.single,
      );
      expect(s.geometry, PptxGeometry.line);
      expect(s.flipV, isTrue);
      expect(s.line!.colorArgb, 0xFF00FF00);
      expect(s.line!.widthEmu, 19050);
      expect(s.fill, isNull);
    });
  });

  group('background and notes', () {
    test('slide -> layout -> master background', () {
      final b = _deck([
        TestSlide(
          '',
          bg: '<p:bg><p:bgPr>${solid('AABBCC')}<a:effectLst/></p:bgPr></p:bg>',
        ),
        TestSlide(''),
      ])..masterBg = '<p:bg><p:bgPr>${solid('112233')}</p:bgPr></p:bg>';
      var deck = _read(b);
      expect(deck.slides[0].background!.colorArgb, 0xFFAABBCC);
      expect(deck.slides[1].background!.colorArgb, 0xFF112233);

      b.layoutBg =
          '<p:bg><p:bgPr><a:solidFill><a:schemeClr val="accent2"/></a:solidFill></p:bgPr></p:bg>';
      deck = _read(b);
      expect(deck.slides[1].background!.colorArgb, 0xFFED7D31);
    });

    test('default bgRef uses theme colour', () {
      final deck = _read(_deck([TestSlide('')]));
      expect(deck.slides.single.background!.colorArgb, 0xFFFFFFFF);
    });

    test('picture background', () {
      final b = _deck([
        TestSlide(
          '',
          bg: '<p:bg><p:bgPr><a:blipFill><a:blip r:embed="rIdBg"/><a:stretch/></a:blipFill></p:bgPr></p:bg>',
          media: {'rIdBg': 'bg.png'},
        ),
      ])..media['bg.png'] = kTinyPng;
      final bg = _read(b).slides.single.background!;
      expect(bg.isPicture, isTrue);
      expect(bg.imageBytes, kTinyPng);
      expect(bg.imageExtension, 'png');
    });

    test('notes text', () {
      final deck = _read(
        _deck([TestSlide('', notes: 'line one\nline two'), TestSlide('')]),
      );
      expect(deck.slides[0].notesText, 'line one\nline two');
      expect(deck.slides[1].notesText, isNull);
    });
  });

  group('errors and performance', () {
    test('garbage bytes throw PptxFormatException', () {
      expect(
        () => readPptx(Uint8List.fromList(List.generate(200, (i) => i))),
        throwsA(isA<PptxFormatException>()),
      );
      expect(() => readPptx(Uint8List(0)), throwsA(isA<PptxFormatException>()));
    });

    test('runs inside Isolate.run', () async {
      final bytes = _deck([
        TestSlide(sp(spPr: xfrm(0, 0, 1, 1), txBody: txBody(para('iso')))),
      ]).build();
      final deck = await Isolate.run(() => readPptx(bytes));
      expect(
        _only<PptxTextShape>(deck.slides.single).paragraphs.single.text,
        'iso',
      );
    });

    test('zip without presentation throws PptxFormatException', () {
      final a = Archive()
        ..addFile(ArchiveFile.bytes('hello.txt', utf8.encode('hi')));
      expect(
        () => readPptx(ZipEncoder().encodeBytes(a)),
        throwsA(isA<PptxFormatException>()),
      );
    });

    test('malformed slide xml throws PptxFormatException', () {
      final good = _deck([TestSlide('')]).build();
      final src = ZipDecoder().decodeBytes(good);
      final out = Archive();
      for (final f in src.files) {
        out.addFile(
          f.name == 'ppt/slides/slide1.xml'
              ? ArchiveFile.bytes(f.name, utf8.encode('<p:sld><broken'))
              : ArchiveFile.bytes(f.name, f.content),
        );
      }
      expect(
        () => readPptx(ZipEncoder().encodeBytes(out)),
        throwsA(isA<PptxFormatException>()),
      );
    });

    test('50 slides parse in under 1 second', () {
      final b = PptxBuilder()..media['image1.png'] = kTinyPng;
      for (var i = 0; i < 50; i++) {
        final title = sp(ph: 'type="title"', txBody: txBody(para('Slide $i')));
        final body = sp(
          id: 3,
          ph: 'idx="1"',
          txBody: txBody(
            List.generate(8, (j) => para('Bullet $j of slide $i')).join(),
          ),
        );
        b.slides.add(
          TestSlide(
            '$title$body'
            '<p:pic><p:nvPicPr><p:cNvPr id="4" name="Pic"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>'
            '<p:blipFill><a:blip r:embed="rId5"/></p:blipFill><p:spPr>${xfrm(1, 2, 3, 4)}</p:spPr></p:pic>',
            media: {'rId5': 'image1.png'},
            notes: 'notes $i',
          ),
        );
      }
      final bytes = b.build();
      final sw = Stopwatch()..start();
      final deck = readPptx(bytes);
      sw.stop();
      expect(deck.slides, hasLength(50));
      expect(deck.slides.last.shapes, hasLength(3));
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });
}
