// ignore_for_file: prefer_interpolation_to_compose_strings, prefer_function_declarations_over_variables
// Kiểm thử hộp trắng A19b — lib/src/reader.dart đợt 2 (mã bộ R8, R14–R22, xem
// test-output/whitebox/pptx-reader/reader/buoc-5-du-lieu-thu.md mục "Đợt 2").
// Mọi hàm reader là private ⇒ đi qua readPptx(bytes). Không mock; gói dựng bằng
// test/helpers/pptx_builder.dart rồi vá part. Expected chép từ Bước 5 (không chỉnh cho khớp code).
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pptx_reader/pptx_reader.dart';
import 'package:test/test.dart';

import '../helpers/pptx_builder.dart';

const kSlideRels = 'ppt/slides/_rels/slide1.xml.rels';
const kSlide2Rels = 'ppt/slides/_rels/slide2.xml.rels';
const kPresRels = 'ppt/_rels/presentation.xml.rels';
const kLayoutRels = 'ppt/slideLayouts/_rels/slideLayout1.xml.rels';
const kMaster = 'ppt/slideMasters/slideMaster1.xml';
const kMasterRels = 'ppt/slideMasters/_rels/slideMaster1.xml.rels';
const mcNs = 'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"';

String partOf(Uint8List zip, String name) => utf8.decode(
  ZipDecoder().decodeBytes(zip).files.firstWhere((f) => f.name == name).readBytes()!,
);

Uint8List patch(Uint8List zip, Map<String, String?> changes) {
  final a = ZipDecoder().decodeBytes(zip);
  final out = Archive();
  for (final f in a.files) {
    if (!f.isFile || changes.containsKey(f.name)) continue;
    out.addFile(ArchiveFile.bytes(f.name, f.readBytes()!));
  }
  changes.forEach((k, v) {
    if (v != null) out.addFile(ArchiveFile.bytes(k, utf8.encode(v)));
  });
  return ZipEncoder().encodeBytes(out);
}

Uint8List edit(Uint8List zip, String name, String Function(String) f) =>
    patch(zip, {name: f(partOf(zip, name))});

String dropRel(String rels, String id) =>
    rels.replaceFirst(RegExp('<Relationship Id="$id"[^>]*/>'), '');

/// txs: otherStyle 20pt Arial (phân biệt với mặc định 18pt).
final txs = defaultTxStyles.replaceFirst(
  'sz="1800"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/>',
  'sz="2000"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="Arial"/>',
);

PptxBuilder bld(String shapes, {Map<String, String> media = const {}}) => PptxBuilder()
  ..masterTxStyles = txs
  ..slides.add(TestSlide(shapes, media: media));
PptxSlide read1(PptxBuilder b) => readPptx(b.build()).slides.single;
PptxSlide slideOf(String shapes, [void Function(PptxBuilder)? cfg]) {
  final b = bld(shapes);
  cfg?.call(b);
  return read1(b);
}

List<String> names(PptxSlide s) => s.shapes.map((e) => e.name).toList();
PptxShape byName(PptxSlide s, String n) => s.shapes.firstWhere((e) => e.name == n);
PptxTextShape ts(PptxSlide s, String n) => byName(s, n) as PptxTextShape;
PptxRun run0(PptxTextShape t) => t.paragraphs.first.runs.first;
String box(String name, {String extra = '', String style = '', int id = 20}) =>
    sp(id: id, name: name, spPr: xfrm(0, 0, 100, 100) + extra, style: style);

void main() {
  test('kiểm dữ liệu: txs đã thay otherStyle', () => expect(txs, contains('typeface="Arial"')));

  // ============================================================ R8 _shape
  group('R8 _shape', () {
    String ac({String? choice, String? fallback}) =>
        '<mc:AlternateContent $mcNs>${choice == null ? '' : '<mc:Choice Requires="p14">$choice</mc:Choice>'}'
        '${fallback == null ? '' : '<mc:Fallback>$fallback</mc:Fallback>'}</mc:AlternateContent>';
    String rawSp(String nv, String spPr) => '<p:sp>$nv<p:spPr>$spPr</p:spPr></p:sp>';
    PptxRect frameOf(String xf) => slideOf(sp(name: 'A', spPr: xf)).shapes.single.frame;

    test('R8.1 sp đủ thuộc tính xfrm ⇒ 1 shape, khung, xoay 90, lật', () {
      final s = slideOf(sp(name: 'A', spPr: xfrm(10, 20, 100, 200, attrs: ' rot="5400000" flipH="1" flipV="1"')));
      expect(names(s), ['A']);
      final a = s.shapes.single;
      expect(a, isA<PptxTextShape>());
      expect(a.frame, const PptxRect(10, 20, 100, 200));
      expect([a.rotationDeg, a.flipH, a.flipV], [90.0, true, true]);
    });
    test('R8.2 AlternateContent có Fallback ⇒ lấy Fallback', () {
      expect(names(slideOf(ac(choice: box('CH'), fallback: box('FB')))), ['FB']);
    });
    test('R8.3 không Fallback ⇒ Choice', () => expect(names(slideOf(ac(choice: box('CH')))), ['CH']));
    test('R8.4 Fallback rỗng ⇒ Choice', () {
      expect(names(slideOf(ac(choice: box('CH'), fallback: ''))), ['CH']);
    });
    test('R8.5 AlternateContent rỗng ⇒ không shape', () => expect(slideOf(ac()).shapes, isEmpty));
    test('R8.7 Choice rỗng ⇒ không shape', () => expect(slideOf(ac(choice: '')).shapes, isEmpty));
    test('R8.8 phần tử không phải shape ⇒ bỏ qua', () {
      expect(names(slideOf('<p:extLst><p:ext uri="{X}"/></p:extLst>${box('A')}')), ['A']);
    });
    test('R8.9 sp không nvSpPr ⇒ vẫn có, name rỗng', () {
      final s = slideOf(rawSp('', xfrm(0, 0, 1, 1)));
      expect(s.shapes, hasLength(1));
      expect(s.shapes.single.name, '');
    });
    test('R8.10 nvSpPr không cNvPr ⇒ name rỗng', () {
      final s = slideOf(rawSp('<p:nvSpPr><p:cNvSpPr/><p:nvPr/></p:nvSpPr>', xfrm(0, 0, 1, 1)));
      expect(s.shapes.single.name, '');
    });
    test('R8.11 hidden="1" ⇒ bỏ', () {
      final s = slideOf(sp(name: 'H', cNvPrAttrs: ' hidden="1"', spPr: xfrm(0, 0, 1, 1)) + box('B'));
      expect(names(s), ['B']);
    });
    test('R8.12 shape trang trí của master ⇒ có, đứng trước', () {
      final s = slideOf(box('A'), (b) => b.masterShapes = defaultMasterShapes + box('MDeco', id: 50));
      expect(names(s), ['MDeco', 'A']);
    });
    test('R8.13 placeholder của master ⇒ không lọt vào slide', () {
      final n = names(slideOf(box('A')));
      expect(n, isNot(contains('Title Placeholder 1')));
      expect(n, isNot(contains('Text Placeholder 2')));
    });
    test('R8.15 cNvPr không name ⇒ name rỗng', () {
      final s = slideOf(rawSp('<p:nvSpPr><p:cNvPr id="5"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>', xfrm(0, 0, 1, 1)));
      expect(s.shapes.single.name, '');
    });
    test('R8.16 grpSp ⇒ PptxGroupShape', () {
      final s = slideOf('<p:grpSp><p:nvGrpSpPr><p:cNvPr id="10" name="G"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
          '<p:grpSpPr/>${box('c', id: 11)}</p:grpSp>');
      expect(s.shapes.single, isA<PptxGroupShape>());
      expect(s.shapes.single.name, 'G');
    });
    test('R8.17 không xfrm ⇒ không shape', () => expect(slideOf(sp(name: 'N')).shapes, isEmpty));
    test('R8.19 xfrm thiếu off ⇒ không shape', () {
      expect(slideOf(sp(name: 'N', spPr: '<a:xfrm><a:ext cx="1" cy="1"/></a:xfrm>')).shapes, isEmpty);
    });
    test('R8.20 xfrm thiếu ext ⇒ không shape', () {
      expect(slideOf(sp(name: 'N', spPr: '<a:xfrm><a:off x="1" y="1"/></a:xfrm>')).shapes, isEmpty);
    });
    test('R8.21 off thiếu x ⇒ x = 0', () {
      expect(frameOf('<a:xfrm><a:off y="20"/><a:ext cx="100" cy="200"/></a:xfrm>'), const PptxRect(0, 20, 100, 200));
    });
    test('R8.22 off thiếu y ⇒ y = 0', () {
      expect(frameOf('<a:xfrm><a:off x="10"/><a:ext cx="100" cy="200"/></a:xfrm>'), const PptxRect(10, 0, 100, 200));
    });
    test('R8.23 ext thiếu cx ⇒ cx = 0', () {
      expect(frameOf('<a:xfrm><a:off x="10" y="20"/><a:ext cy="200"/></a:xfrm>'), const PptxRect(10, 20, 0, 200));
    });
    test('R8.24 ext thiếu cy ⇒ cy = 0', () {
      expect(frameOf('<a:xfrm><a:off x="10" y="20"/><a:ext cx="100"/></a:xfrm>'), const PptxRect(10, 20, 100, 0));
    });
    test('R8.25 không rot ⇒ 0', () {
      final a = slideOf(sp(name: 'A', spPr: xfrm(0, 0, 1, 1, attrs: ' flipH="1" flipV="1"'))).shapes.single;
      expect(a.rotationDeg, 0);
    });
    test('R8.26 không flipH ⇒ false', () {
      final a = slideOf(sp(name: 'A', spPr: xfrm(0, 0, 1, 1, attrs: ' rot="60000" flipV="1"'))).shapes.single;
      expect([a.flipH, a.flipV], [false, true]);
    });
    test('R8.27 không flipV ⇒ false', () {
      final a = slideOf(sp(name: 'A', spPr: xfrm(0, 0, 1, 1, attrs: ' rot="60000" flipH="1"'))).shapes.single;
      expect([a.flipH, a.flipV], [true, false]);
    });
    test('R8.28 cxnSp ⇒ line', () {
      final s = slideOf('<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="6" name="L"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>'
          '<p:spPr>${xfrm(0, 0, 100, 0)}</p:spPr></p:cxnSp>');
      expect(ts(s, 'L').geometry, PptxGeometry.line);
    });
    test('R8.29 pic ⇒ PptxPictureShape', () {
      final b = bld('<p:pic><p:nvPicPr><p:cNvPr id="30" name="P"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>'
          '<p:blipFill><a:blip r:embed="rId5"/></p:blipFill><p:spPr>${xfrm(0, 0, 1, 1)}</p:spPr></p:pic>', media: {'rId5': 'image1.png'});
      b.media['image1.png'] = kTinyPng;
      expect(read1(b).shapes.single, isA<PptxPictureShape>());
    });
    test('R8.30 graphicFrame chart ⇒ khung rỗng chart', () {
      final s = slideOf('<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="40" name="G"/><p:cNvGraphicFramePr/><p:nvPr/>'
          '</p:nvGraphicFramePr><p:xfrm><a:off x="0" y="0"/><a:ext cx="1" cy="1"/></p:xfrm><a:graphic>'
          '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/chart"/></a:graphic></p:graphicFrame>');
      expect(ts(s, 'G').unsupportedKind, 'chart');
    });
    test('R8.x1 p:contentPart (ink) ⇒ khung rỗng có unsupportedKind (README)', () {
      final s = slideOf('<p:contentPart r:id="rId9"><p:nvContentPartPr><p:cNvPr id="9" name="Ink"/><p:cNvContentPartPr/><p:nvPr/>'
          '</p:nvContentPartPr><p:xfrm><a:off x="0" y="0"/><a:ext cx="10" cy="10"/></p:xfrm></p:contentPart>');
      expect(s.shapes, hasLength(1), reason: 'shape ink bị bỏ hẳn');
      expect(s.shapes.single, isA<PptxTextShape>());
      expect((s.shapes.single as PptxTextShape).unsupportedKind, isNotNull);
    });
  });

  // ============================================================ R14 _group
  group('R14 _group', () {
    final childC = sp(id: 11, name: 'c', spPr: xfrm(100, 100, 200, 200) + '<a:grpFill/>');
    String gxf({
      String attrs = ' rot="5400000" flipH="1" flipV="1"',
      String off = '<a:off x="1000" y="1000"/>',
      String ext = '<a:ext cx="2000" cy="2000"/>',
      String chOff = '<a:chOff x="0" y="0"/>',
      String chExt = '<a:chExt cx="1000" cy="1000"/>',
    }) => '<a:xfrm$attrs>$off$ext$chOff$chExt</a:xfrm>';
    String grpX({String? xf, bool noXf = false, bool spPr = true, String? children, String name = 'G'}) =>
        '<p:grpSp><p:nvGrpSpPr><p:cNvPr id="10" name="$name"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '${spPr ? '<p:grpSpPr>${noXf ? '' : (xf ?? gxf())}${solid('FF0000')}</p:grpSpPr>' : ''}'
        '${children ?? childC}</p:grpSp>';
    PptxGroupShape g1(String x) => slideOf(x).shapes.single as PptxGroupShape;
    PptxRect child(String xf) => g1(grpX(xf: xf)).children.single.frame;

    test('R14.1 nhóm đủ xfrm ⇒ frame, xoay/lật nhóm, con đổi toạ độ + grpFill', () {
      final g = g1(grpX());
      expect(g.frame, const PptxRect(1000, 1000, 2000, 2000));
      expect([g.rotationDeg, g.flipH, g.flipV], [90.0, true, true]);
      final c = g.children.single as PptxTextShape;
      expect(c.frame, const PptxRect(1200, 1200, 400, 400));
      expect(c.fill?.colorArgb, 0xFFFF0000);
      expect(c.rotationDeg, 0);
    });
    test('R14.2 grpSpPr không xfrm ⇒ frame 0, con giữ toạ độ', () {
      final g = g1(grpX(noXf: true));
      expect(g.frame, const PptxRect(0, 0, 0, 0));
      expect([g.rotationDeg, g.flipH, g.flipV], [0.0, false, false]);
      final c = g.children.single as PptxTextShape;
      expect(c.frame, const PptxRect(100, 100, 200, 200));
      expect(c.fill?.colorArgb, 0xFFFF0000);
    });
    test('R14.3 xfrm không off', () {
      final g = g1(grpX(xf: gxf(off: '')));
      expect(g.frame, const PptxRect(0, 0, 2000, 2000));
      expect(g.children.single.frame, const PptxRect(200, 200, 400, 400));
    });
    test('R14.4 off chỉ có y', () {
      final g = g1(grpX(xf: gxf(off: '<a:off y="1000"/>')));
      expect(g.frame, const PptxRect(0, 1000, 2000, 2000));
      expect(g.children.single.frame, const PptxRect(200, 1200, 400, 400));
    });
    test('R14.6 off chỉ có x', () {
      final g = g1(grpX(xf: gxf(off: '<a:off x="1000"/>')));
      expect(g.frame, const PptxRect(1000, 0, 2000, 2000));
      expect(g.children.single.frame, const PptxRect(1200, 200, 400, 400));
    });
    test('R14.7 không ext', () {
      final g = g1(grpX(xf: gxf(ext: '')));
      expect(g.frame, const PptxRect(1000, 1000, 0, 0));
      expect(g.children.single.frame, const PptxRect(1000, 1000, 0, 0));
    });
    test('R14.8 ext chỉ có cy', () {
      final g = g1(grpX(xf: gxf(ext: '<a:ext cy="2000"/>')));
      expect(g.frame, const PptxRect(1000, 1000, 0, 2000));
      expect(g.children.single.frame, const PptxRect(1000, 1200, 0, 400));
    });
    test('R14.10 ext chỉ có cx', () {
      final g = g1(grpX(xf: gxf(ext: '<a:ext cx="2000"/>')));
      expect(g.frame, const PptxRect(1000, 1000, 2000, 0));
      expect(g.children.single.frame, const PptxRect(1200, 1000, 400, 0));
    });
    test('R14.11 không chOff ⇒ coi = off', () => expect(child(gxf(chOff: '')), const PptxRect(-800, -800, 400, 400)));
    test('R14.12 chOff chỉ y', () => expect(child(gxf(chOff: '<a:chOff y="0"/>')), const PptxRect(-800, 1200, 400, 400)));
    test('R14.14 chOff chỉ x', () => expect(child(gxf(chOff: '<a:chOff x="0"/>')), const PptxRect(1200, -800, 400, 400)));
    test('R14.15 không chExt ⇒ tỉ lệ 1', () => expect(child(gxf(chExt: '')), const PptxRect(1100, 1100, 200, 200)));
    test('R14.16 chExt chỉ cy', () => expect(child(gxf(chExt: '<a:chExt cy="1000"/>')), const PptxRect(1100, 1200, 200, 400)));
    test('R14.18 chExt chỉ cx', () => expect(child(gxf(chExt: '<a:chExt cx="1000"/>')), const PptxRect(1200, 1100, 400, 200)));
    test('R14.19 chExt cx=0 ⇒ tỉ lệ x = 1', () {
      expect(child(gxf(chExt: '<a:chExt cx="0" cy="1000"/>')), const PptxRect(1100, 1200, 200, 400));
    });
    test('R14.20 chExt cy=0 ⇒ tỉ lệ y = 1', () {
      expect(child(gxf(chExt: '<a:chExt cx="1000" cy="0"/>')), const PptxRect(1200, 1100, 400, 200));
    });
    test('R14.21 nhóm con không grpSpPr ⇒ kế thừa fill nhóm ngoài', () {
      final g = g1(grpX(children: grpX(spPr: false, name: 'G2')));
      final g2 = g.children.single as PptxGroupShape;
      expect(g2.frame, const PptxRect(0, 0, 0, 0));
      final c = g2.children.single as PptxTextShape;
      expect(c.frame, const PptxRect(1200, 1200, 400, 400));
      expect(c.fill?.colorArgb, 0xFFFF0000);
    });
    test('R14.22 nhóm rỗng ⇒ children rỗng', () => expect(g1(grpX(children: '')).children, isEmpty));
    test('R14.24 không rot ⇒ 0', () => expect(g1(grpX(xf: gxf(attrs: ' flipH="1" flipV="1"'))).rotationDeg, 0));
    test('R14.26 không flipH ⇒ false', () {
      final g = g1(grpX(xf: gxf(attrs: ' rot="5400000" flipV="1"')));
      expect([g.flipH, g.flipV], [false, true]);
    });
    test('R14.28 không flipV ⇒ false', () {
      final g = g1(grpX(xf: gxf(attrs: ' rot="5400000" flipH="1"')));
      expect([g.flipH, g.flipV], [true, false]);
    });
  });

  // ============================================================ R15 _sp (+ R15i ins)
  group('R15 _sp', () {
    const roundRect = '<a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom>';
    const ellipse = '<a:prstGeom prst="ellipse"><a:avLst/></a:prstGeom>';
    const rectG = '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>';
    const refs = '<a:lnRef idx="0"><a:schemeClr val="accent1"/></a:lnRef>';
    const fillRef = '<a:fillRef idx="1"><a:schemeClr val="accent2"/></a:fillRef>';
    const effRef = '<a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef>';
    String fontRef(String idx) => '<a:fontRef idx="$idx"><a:schemeClr val="lt1"/></a:fontRef>';
    final styleMajor = '<p:style>$refs$fillRef$effRef${fontRef('major')}</p:style>';
    String bodyPr(String inner, {String attrs = ' lIns="1" tIns="2" rIns="3" bIns="4" anchor="ctr" wrap="none" vert="vert"'}) =>
        '<a:bodyPr$attrs>$inner</a:bodyPr>';
    const autofit = '<a:normAutofit fontScale="50000" lnSpcReduction="20000"/>';
    final baseBody = txBody(para('x'), bodyPr: bodyPr(autofit));
    String spA({String? ph, String geom = roundRect, String? fill, String? style, String? body, bool noBody = false}) => sp(
      id: 20,
      name: 'A',
      ph: ph,
      spPr: xfrm(0, 0, 100, 100) + geom + (fill ?? solid('FF0000')),
      style: style ?? styleMajor,
      txBody: noBody ? null : (body ?? baseBody),
    );
    PptxTextShape a(PptxSlide s) => ts(s, 'A');
    PptxTextShape aOf(String x, [void Function(PptxBuilder)? cfg]) => a(slideOf(x, cfg));
    final layoutEllipse = sp(id: 2, name: 'Title 1', ph: 'type="title"', spPr: xfrm(1000000, 500000, 10000000, 1000000) + ellipse) +
        sp(id: 3, name: 'Content Placeholder 2', ph: 'idx="1"');
    const rawLayoutTitle = '<p:sp><p:nvSpPr><p:cNvPr id="2" name="Title 1"/><p:cNvSpPr/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr></p:sp>';
    void insetsAre(PptxTextShape t, List<int> v) =>
        expect([t.insets.left, t.insets.top, t.insets.right, t.insets.bottom], v);

    test('R15.1 gốc: geometry, fill, bodyPr, autofit, fontRef major', () {
      final t = aOf(spA());
      expect(t.geometry, PptxGeometry.roundRect);
      expect(t.presetGeometry, 'roundRect');
      expect(t.customPaths, isEmpty);
      expect(t.fill?.colorArgb, 0xFFFF0000);
      insetsAre(t, [1, 2, 3, 4]);
      expect([t.verticalAnchor, t.wrap, t.verticalText], [PptxAnchor.middle, false, true]);
      final r = run0(t);
      expect([r.fontSizePt, r.fontFamily, r.colorArgb], [10.0, 'Calibri Light', 0xFFFFFFFF]);
      expect(t.paragraphs.first.lineSpacingPct, 80);
    });
    test('R15.2 custGeom ⇒ other + customPaths', () {
      final t = aOf(spA(geom: '<a:custGeom><a:pathLst><a:path w="10" h="10"><a:moveTo><a:pt x="0" y="0"/></a:moveTo>'
          '<a:lnTo><a:pt x="10" y="10"/></a:lnTo></a:path></a:pathLst></a:custGeom>'));
      expect([t.geometry, t.presetGeometry], [PptxGeometry.other, null]);
      expect(t.customPaths, hasLength(1));
    });
    test('R15.3 không geometry ⇒ rect', () {
      final t = aOf(spA(geom: ''));
      expect([t.geometry, t.presetGeometry], [PptxGeometry.rect, null]);
    });
    test('R15.4 geometry kế thừa từ layout (vòng geometry lần 2)', () {
      final t = aOf(spA(ph: 'type="title"', geom: ''), (b) => b.layoutShapes = layoutEllipse);
      expect(t.geometry, PptxGeometry.ellipse);
    });
    test('R15.5 placeholder không spPr ⇒ geometry + khung từ layout', () {
      final x = '<p:sp><p:nvSpPr><p:cNvPr id="20" name="A"/><p:cNvSpPr/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>'
          '<p:txBody>$baseBody</p:txBody></p:sp>';
      final t = aOf(x, (b) => b.layoutShapes = layoutEllipse);
      expect(t.geometry, PptxGeometry.ellipse);
      expect(t.frame, const PptxRect(1000000, 500000, 10000000, 1000000));
    });
    test('R15.7 cxnSp ⇒ line, fill null, giữ preset', () {
      final x = '<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="20" name="A"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>'
          '<p:spPr>${xfrm(0, 0, 100, 100)}$roundRect${solid('FF0000')}</p:spPr></p:cxnSp>';
      final t = aOf(x);
      expect([t.geometry, t.fill, t.presetGeometry], [PptxGeometry.line, null, 'roundRect']);
    });
    test('R15.8 fill kế thừa từ layout (vòng fill lần 2)', () {
      final layout = sp(id: 2, name: 'Title 1', ph: 'type="title"', spPr: xfrm(1, 1, 1, 1) + solid('0000FF'));
      final t = aOf(spA(ph: 'type="title"', geom: rectG, fill: '', style: ''), (b) => b.layoutShapes = layout);
      expect(t.fill?.colorArgb, 0xFF0000FF);
    });
    test('R15.9 layout không spPr ⇒ bỏ qua, fill từ master', () {
      final master = sp(id: 2, name: 'Title Placeholder 1', ph: 'type="title"', spPr: xfrm(1, 1, 1, 1) + solid('00FF00'));
      final t = aOf(spA(ph: 'type="title"', geom: rectG, fill: '', style: ''), (b) {
        b.layoutShapes = rawLayoutTitle;
        b.masterShapes = master;
      });
      expect(t.fill?.colorArgb, 0xFF00FF00);
    });
    test('R15.10 không fill ⇒ fillRef qua theme', () => expect(aOf(spA(fill: '')).fill?.colorArgb, 0xFFED7D31));
    test('R15.13 không fill, không p:style ⇒ null', () => expect(aOf(spA(fill: '', style: '')).fill, isNull));
    test('R15.14 p:style không fillRef ⇒ null', () {
      expect(aOf(spA(fill: '', style: '<p:style>$refs$effRef${fontRef('major')}</p:style>')).fill, isNull);
    });
    test('R15.16 bodyPr gộp master → layout → shape', () {
      final layout = sp(id: 2, name: 'Title 1', ph: 'type="title"', spPr: xfrm(1, 1, 1, 1),
          txBody: txBody('<a:p/>', bodyPr: '<a:bodyPr tIns="8"/>'));
      final t = aOf(spA(ph: 'type="title"', body: txBody(para('x'), bodyPr: '<a:bodyPr lIns="7"/>')),
          (b) => b.layoutShapes = layout);
      expect([t.insets.left, t.insets.top], [7, 8]);
      expect([t.verticalAnchor, t.verticalText], [PptxAnchor.middle, false]);
    });
    test('R15.17 txBody không bodyPr ⇒ mặc định', () {
      final t = aOf(spA(body: '<a:lstStyle/>${para('x')}'));
      insetsAre(t, [91440, 45720, 91440, 45720]);
      expect([t.verticalAnchor, t.wrap, t.verticalText], [PptxAnchor.top, true, false]);
      expect(run0(t).fontSizePt, 20);
    });
    test('R15.18 bodyPr rỗng ⇒ mặc định', () {
      final t = aOf(spA(body: txBody(para('x'))));
      insetsAre(t, [91440, 45720, 91440, 45720]);
      expect([t.verticalAnchor, t.wrap, t.verticalText], [PptxAnchor.top, true, false]);
    });
    test('R15.19 không normAutofit ⇒ 20pt, không giảm giãn dòng', () {
      final t = aOf(spA(body: txBody(para('x'), bodyPr: bodyPr(''))));
      expect([run0(t).fontSizePt, t.paragraphs.first.lineSpacingPct], [20.0, null]);
    });
    test('R15.20 normAutofit thiếu fontScale', () {
      final t = aOf(spA(body: txBody(para('x'), bodyPr: bodyPr('<a:normAutofit lnSpcReduction="20000"/>'))));
      expect([run0(t).fontSizePt, t.paragraphs.first.lineSpacingPct], [20.0, 80.0]);
    });
    test('R15.22 normAutofit thiếu lnSpcReduction', () {
      final t = aOf(spA(body: txBody(para('x'), bodyPr: bodyPr('<a:normAutofit fontScale="50000"/>'))));
      expect([run0(t).fontSizePt, t.paragraphs.first.lineSpacingPct], [10.0, null]);
    });
    test('R15.23 placeholder title ⇒ titleStyle 44 × 0,5', () => expect(run0(aOf(spA(ph: 'type="title"'))).fontSizePt, 22));
    test('R15.24 ph không type ⇒ obj ⇒ bodyStyle', () => expect(run0(aOf(spA(ph: 'idx="1"'))).fontSizePt, 14));
    test('R15.25 ph body ⇒ bodyStyle', () => expect(run0(aOf(spA(ph: 'type="body"'))).fontSizePt, 14));
    test('R15.26 ph dt ⇒ otherStyle', () => expect(run0(aOf(spA(ph: 'type="dt"'))).fontSizePt, 10));
    test('R15.27 title, master không txStyles ⇒ 18 × 0,5', () {
      expect(run0(aOf(spA(ph: 'type="title"'), (b) => b.masterTxStyles = '')).fontSizePt, 9);
    });
    test('R15.28 body, master không txStyles', () {
      expect(run0(aOf(spA(ph: 'type="body"'), (b) => b.masterTxStyles = '')).fontSizePt, 9);
    });
    test('R15.29 other, master không txStyles', () {
      expect(run0(aOf(spA(), (b) => b.masterTxStyles = '')).fontSizePt, 9);
    });
    test('R15.30 không p:style ⇒ font/màu từ otherStyle', () {
      final r = run0(aOf(spA(style: '')));
      expect([r.fontFamily, r.colorArgb], ['Arial', 0xFF000000]);
    });
    test('R15.31 p:style không fontRef', () {
      final r = run0(aOf(spA(style: '<p:style>$refs$fillRef$effRef</p:style>')));
      expect([r.fontFamily, r.colorArgb], ['Arial', 0xFF000000]);
    });
    test('R15.32 fontRef minor', () {
      expect(run0(aOf(spA(style: '<p:style>$refs$fillRef$effRef${fontRef('minor')}</p:style>'))).fontFamily, 'Calibri');
    });
    test('R15.33 fontRef none ⇒ font không đổi, màu fontRef', () {
      final r = run0(aOf(spA(style: '<p:style>$refs$fillRef$effRef${fontRef('none')}</p:style>')));
      expect([r.fontFamily, r.colorArgb], ['Arial', 0xFFFFFFFF]);
    });
    test('R15.34 không txBody ⇒ không đoạn, insets mặc định', () {
      final t = aOf(spA(noBody: true));
      expect(t.paragraphs, isEmpty);
      insetsAre(t, [91440, 45720, 91440, 45720]);
    });
    test('R15.36 không vert ⇒ verticalText false', () {
      expect(aOf(spA(body: txBody(para('x'), bodyPr: bodyPr('', attrs: ' anchor="ctr"')))).verticalText, isFalse);
    });
    test('R15.37 vert="horz" ⇒ false', () {
      expect(aOf(spA(body: txBody(para('x'), bodyPr: bodyPr('', attrs: ' vert="horz"')))).verticalText, isFalse);
    });
    test('R15i.1 lIns="1"', () => expect(aOf(spA()).insets.left, 1));
    test('R15i.2 thiếu lIns ⇒ 91440', () {
      expect(aOf(spA(body: txBody(para('x'), bodyPr: bodyPr('', attrs: ' tIns="2"')))).insets.left, 91440);
    });
    test('R15i.3 lIns="abc" ⇒ 91440', () {
      expect(aOf(spA(body: txBody(para('x'), bodyPr: bodyPr('', attrs: ' lIns="abc"')))).insets.left, 91440);
    });
  });

  // ============================================================ R16 _pic (+ R16v v)
  group('R16 _pic', () {
    const blipCrop = '<p:blipFill><a:blip r:embed="rId5"/><a:srcRect l="10000" t="20000" r="30000" b="40000"/><a:stretch/></p:blipFill>';
    final picSpPr = '${xfrm(0, 0, 100, 100)}<a:ln w="12700">${solid('00FF00')}</a:ln>';
    String picX({String blipFill = blipCrop, String? spPr, String nvPr = '<p:nvPr/>', bool noSpPr = false}) =>
        '<p:pic><p:nvPicPr><p:cNvPr id="30" name="Pic"/><p:cNvPicPr/>$nvPr</p:nvPicPr>$blipFill'
        '${noSpPr ? '' : '<p:spPr>${spPr ?? picSpPr}</p:spPr>'}</p:pic>';
    PptxShape picOf(String x) {
      final b = bld(x, media: {'rId5': 'image1.png'});
      b.media['image1.png'] = kTinyPng;
      return read1(b).shapes.single;
    }

    List<double>? cropOf(PptxPictureShape p) =>
        p.crop == null ? null : [p.crop!.left, p.crop!.top, p.crop!.right, p.crop!.bottom];

    test('R16.1 ảnh + crop + viền', () {
      final p = picOf(picX()) as PptxPictureShape;
      expect(p.bytes, kTinyPng);
      expect(p.extension, 'png');
      expect(cropOf(p), [0.1, 0.2, 0.3, 0.4]);
      expect([p.line?.colorArgb, p.line?.widthEmu], [0xFF00FF00, 12700]);
    });
    test('R16.2 không blipFill ⇒ khung rỗng unsupported, giữ viền', () {
      final r = picOf(picX(blipFill: ''));
      expect(r, isA<PptxTextShape>());
      final t = r as PptxTextShape;
      expect(t.unsupportedKind, isNotNull);
      expect(t.frame, const PptxRect(0, 0, 100, 100));
      expect(t.line?.colorArgb, 0xFF00FF00);
    });
    test('R16.3 pic placeholder không spPr ⇒ khung master, không viền', () {
      final r = picOf(picX(nvPr: '<p:nvPr><p:ph type="pic" idx="1"/></p:nvPr>', noSpPr: true));
      expect(r, isA<PptxPictureShape>());
      expect(r.frame, const PptxRect(838200, 1825625, 10515600, 4351338));
      expect((r as PptxPictureShape).line, isNull);
    });
    test('R16.4 blip trỏ rId không có ⇒ khung rỗng unsupported', () {
      final r = picOf(picX(blipFill: '<p:blipFill><a:blip r:embed="rId9"/></p:blipFill>'));
      expect(r, isA<PptxTextShape>());
      expect((r as PptxTextShape).unsupportedKind, isNotNull);
    });
    bool noCrop(PptxPictureShape p) => p.crop == null || cropOf(p)!.every((v) => v == 0);
    test('R16.6 không srcRect ⇒ không cắt', () {
      expect(noCrop(picOf(picX(blipFill: '<p:blipFill><a:blip r:embed="rId5"/></p:blipFill>')) as PptxPictureShape), isTrue);
    });
    test('R16.7 srcRect rỗng ⇒ không cắt', () {
      expect(noCrop(picOf(picX(blipFill: '<p:blipFill><a:blip r:embed="rId5"/><a:srcRect/></p:blipFill>')) as PptxPictureShape), isTrue);
    });
    test('R16v.1 đủ l/t/r/b', () => expect(cropOf(picOf(picX()) as PptxPictureShape), [0.1, 0.2, 0.3, 0.4]));
    test('R16v.2 chỉ l ⇒ các cạnh khác 0', () {
      final p = picOf(picX(blipFill: '<p:blipFill><a:blip r:embed="rId5"/><a:srcRect l="10000"/></p:blipFill>')) as PptxPictureShape;
      expect(cropOf(p), [0.1, 0.0, 0.0, 0.0]);
    });
  });

  // ============================================================ R17 _table (+ closure)
  group('R17 _table', () {
    String bd(String side, String hex, {String w = ' w="12700"'}) => '<a:$side><a:ln$w>${solid(hex)}</a:ln></a:$side>';
    String bdr(String p) =>
        '<a:tcBdr>${bd('left', '${p}1')}${bd('right', '${p}2')}${bd('top', '${p}3')}${bd('bottom', '${p}4')}'
        '${bd('insideH', '${p}5')}${bd('insideV', '${p}6')}</a:tcBdr>';
    String fillPart(String hex) => '<a:tcStyle><a:fill>${solid(hex)}</a:fill></a:tcStyle>';
    const txW = '<a:tcTxStyle b="on" i="on"><a:fontRef idx="major"><a:schemeClr val="accent2"/></a:fontRef><a:srgbClr val="0000F1"/></a:tcTxStyle>';
    Map<String, String> partsS({String tx = txW}) => {
      'wholeTbl': '$tx<a:tcStyle>${bdr('0000A')}<a:fill>${solid('111111')}</a:fill></a:tcStyle>',
      'band1H': '<a:tcTxStyle><a:srgbClr val="000021"/></a:tcTxStyle>',
      'band2H': '<a:tcTxStyle><a:srgbClr val="000031"/></a:tcTxStyle>',
      'band1V': fillPart('444444'),
      'band2V': fillPart('555555'),
      'lastCol': fillPart('777777'),
      'firstCol': fillPart('666666'),
      'lastRow': fillPart('888888'),
      'firstRow': fillPart('999999'),
    };
    String tblStyle(String id, Map<String, String> parts) =>
        '<a:tblStyle styleId="$id" styleName="t">${parts.entries.map((e) => '<a:${e.key}>${e.value}</a:${e.key}>').join()}</a:tblStyle>';
    final styleS = tblStyle('{S}', partsS());
    const allFlags = ' firstRow="1" lastRow="1" firstCol="1" lastCol="1" bandRow="1" bandCol="1"';
    String tblPrX(String flags, {String id = '{S}'}) => '<a:tblPr$flags><a:tableStyleId>$id</a:tableStyleId></a:tblPr>';
    const tcPrBase = '<a:tcPr marL="1" marT="2" marR="3" marB="4" anchor="ctr"/>';
    String tcX(String t, {String attrs = '', String? tcPr = tcPrBase, bool body = true}) =>
        '<a:tc$attrs>${body ? '<a:txBody><a:bodyPr/><a:lstStyle/>${para(t)}</a:txBody>' : ''}${tcPr ?? ''}</a:tc>';
    const mergeAttrs = ' gridSpan="2" rowSpan="2" hMerge="1" vMerge="1"';
    String defCell(int r, int c) => tcX('r${r}c$c', attrs: r == 1 && c == 1 ? mergeAttrs : '');
    String tableXml({
      int rows = 3,
      int cols = 3,
      String? tblPr,
      bool noTblPr = false,
      String? grid,
      String Function(int r, int c)? cell,
      String trH = ' h="100"',
      String? rowsXml,
    }) {
      final g = grid ?? '<a:tblGrid>${List.filled(cols, '<a:gridCol w="100"/>').join()}</a:tblGrid>';
      final cf = cell ?? defCell;
      final rs = rowsXml ??
          [for (var r = 0; r < rows; r++) '<a:tr$trH>${[for (var c = 0; c < cols; c++) cf(r, c)].join()}</a:tr>'].join();
      return '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="5" name="T"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>'
          '<p:xfrm><a:off x="0" y="0"/><a:ext cx="300" cy="300"/></p:xfrm><a:graphic>'
          '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table"><a:tbl>'
          '${noTblPr ? '' : (tblPr ?? tblPrX(allFlags))}$g$rs</a:tbl></a:graphicData></a:graphic></p:graphicFrame>';
    }

    PptxTableShape tableOf(String xml, {String? styles, void Function(PptxBuilder)? cfg}) {
      final b = bld(xml)..tableStyles = styles ?? styleS;
      cfg?.call(b);
      return read1(b).shapes.single as PptxTableShape;
    }

    PptxTableCell at(PptxTableShape t, int r, int c) => t.rows[r].cells[c];
    PptxRun runAt(PptxTableShape t, int r, int c) => at(t, r, c).paragraphs.first.runs.first;
    int? fillAt(PptxTableShape t, int r, int c) => at(t, r, c).fill?.colorArgb;
    List<int?> bordersAt(PptxTableShape t, int r, int c) {
      final x = at(t, r, c);
      return [x.borderLeft?.colorArgb, x.borderRight?.colorArgb, x.borderTop?.colorArgb, x.borderBottom?.colorArgb];
    }

    PptxTableShape flags(String f, {int rows = 3, int cols = 3}) => tableOf(tableXml(tblPr: tblPrX(f), rows: rows, cols: cols));
    PptxTableShape withStyle(String id, Map<String, String> parts, {String f = '', int rows = 3, int cols = 3, String Function(int, int)? cell}) =>
        tableOf(tableXml(tblPr: tblPrX(f, id: id), rows: rows, cols: cols, cell: cell), styles: tblStyle(id, parts));
    PptxTableShape withParts(Map<String, String> parts) => tableOf(tableXml(), styles: tblStyle('{S}', parts));
    final base = () => tableOf(tableXml());

    test('R17.1 gốc, ô (1,1): band1V, viền trong, chữ, gộp ô, lề', () {
      final t = base();
      expect(fillAt(t, 1, 1), 0xFF444444);
      expect(bordersAt(t, 1, 1), [0xFF0000A6, 0xFF0000A6, 0xFF0000A5, 0xFF0000A5]);
      final r = runAt(t, 1, 1);
      expect([r.bold, r.italic, r.colorArgb, r.fontFamily, r.fontSizePt], [true, true, 0xFF000021, 'Calibri Light', 20.0]);
      final c = at(t, 1, 1);
      expect([c.gridSpan, c.rowSpan, c.hMerge, c.vMerge], [2, 2, true, true]);
      expect([c.insets.left, c.insets.top, c.insets.right, c.insets.bottom], [1, 2, 3, 4]);
      expect(c.verticalAnchor, PptxAnchor.middle);
      expect(t.columnWidthsEmu, [100, 100, 100]);
      expect(t.rows.map((r) => r.heightEmu), [100, 100, 100]);
    });
    test('R17.2 không tblGrid ⇒ không cột', () => expect(tableOf(tableXml(grid: '')).columnWidthsEmu, isEmpty));
    test('R17.4 gridCol thiếu w ⇒ 0', () {
      final t = tableOf(tableXml(grid: '<a:tblGrid><a:gridCol/><a:gridCol w="100"/><a:gridCol w="100"/></a:tblGrid>'));
      expect(t.columnWidthsEmu, [0, 100, 100]);
    });
    void noStyle(PptxTableShape t) {
      expect(fillAt(t, 1, 1), isNull);
      expect(bordersAt(t, 1, 1), [null, null, null, null]);
      final r = runAt(t, 1, 1);
      expect([r.bold, r.colorArgb, r.fontFamily], [false, 0xFF000000, 'Arial']);
    }

    test('R17.5 không tblPr ⇒ không style', () => noStyle(tableOf(tableXml(noTblPr: true))));
    test('R17.6 tblPr không tableStyleId ⇒ không style', () => noStyle(tableOf(tableXml(tblPr: '<a:tblPr$allFlags/>'))));
    test('R17.8 không hàng ⇒ rows rỗng', () => expect(tableOf(tableXml(rows: 0)).rows, isEmpty));
    test('R17.9 hàng không ô', () {
      final t = tableOf(tableXml(rowsXml: '<a:tr h="100"/>'));
      expect(t.rows, hasLength(1));
      expect(t.rows.single.cells, isEmpty);
    });
    test('R17.10 tableStyleId không có ⇒ không style', () => noStyle(tableOf(tableXml(tblPr: tblPrX(allFlags, id: '{X}')))));
    test('R17.11 tắt firstRow, ô (0,1) ⇒ band', () {
      final t = flags(' lastRow="1" firstCol="1" lastCol="1" bandRow="1" bandCol="1"');
      expect([fillAt(t, 0, 1), runAt(t, 0, 1).colorArgb], [0xFF444444, 0xFF000021]);
    });
    test('R17.12 ô (0,1) ⇒ firstRow', () {
      final t = base();
      expect([fillAt(t, 0, 1), runAt(t, 0, 1).colorArgb], [0xFF999999, 0xFF0000F1]);
    });
    test('R17.13 tắt lastRow, ô (2,1) ⇒ band2H', () {
      final t = flags(' firstRow="1" firstCol="1" lastCol="1" bandRow="1" bandCol="1"');
      expect([fillAt(t, 2, 1), runAt(t, 2, 1).colorArgb], [0xFF444444, 0xFF000031]);
    });
    test('R17.14 ô (2,1) ⇒ lastRow', () {
      final t = base();
      expect([fillAt(t, 2, 1), runAt(t, 2, 1).colorArgb], [0xFF888888, 0xFF0000F1]);
    });
    test('R17.15 tắt firstCol, ô (1,0) ⇒ band1V', () {
      expect(fillAt(flags(' firstRow="1" lastRow="1" lastCol="1" bandRow="1" bandCol="1"'), 1, 0), 0xFF444444);
    });
    test('R17.16 ô (1,0) ⇒ firstCol', () => expect(fillAt(base(), 1, 0), 0xFF666666));
    test('R17.17 tắt lastCol, ô (1,2) ⇒ band2V', () {
      expect(fillAt(flags(' firstRow="1" lastRow="1" firstCol="1" bandRow="1" bandCol="1"'), 1, 2), 0xFF555555);
    });
    test('R17.18 ô (1,2) ⇒ lastCol', () => expect(fillAt(base(), 1, 2), 0xFF777777));
    test('R17.19 tắt bandRow ⇒ không band H', () {
      final t = flags(' firstRow="1" lastRow="1" firstCol="1" lastCol="1" bandCol="1"');
      expect([runAt(t, 1, 1).colorArgb, fillAt(t, 1, 1)], [0xFF0000F1, 0xFF444444]);
    });
    test('R17.23 4 hàng, ô (2,1) ⇒ band2H', () => expect(runAt(flags(allFlags, rows: 4), 2, 1).colorArgb, 0xFF000031));
    test('R17.24 tắt bandCol ⇒ wholeTbl', () {
      expect(fillAt(flags(' firstRow="1" lastRow="1" firstCol="1" lastCol="1" bandRow="1"'), 1, 1), 0xFF111111);
    });
    test('R17.28 4 cột, ô (1,2) ⇒ band2V', () => expect(fillAt(flags(allFlags, cols: 4), 1, 2), 0xFF555555));
    test('R17.33 style rỗng ⇒ không part', () {
      final t = withStyle('{E}', {}, f: allFlags);
      expect(fillAt(t, 1, 1), isNull);
      final r = runAt(t, 1, 1);
      expect([r.bold, r.colorArgb], [false, 0xFF000000]);
    });
    test('R17.34 part không tcStyle', () {
      final t = withStyle('{T}', {'wholeTbl': '<a:tcTxStyle b="on"/>'});
      expect(fillAt(t, 1, 1), isNull);
      expect(bordersAt(t, 1, 1), [null, null, null, null]);
      expect(runAt(t, 1, 1).bold, isTrue);
    });
    final bOnly = {'wholeTbl': '<a:tcStyle>${bdr('0000A')}</a:tcStyle>'};
    test('R17.35 tcStyle không fill', () {
      final t = withStyle('{B}', bOnly);
      expect(fillAt(t, 1, 1), isNull);
      expect(at(t, 1, 1).borderLeft?.colorArgb, 0xFF0000A6);
    });
    test('R17.36 fill rỗng không đè', () {
      final t = withStyle('{F}', {
        'wholeTbl': fillPart('111111'),
        'band1V': '<a:tcStyle><a:fill/></a:tcStyle>',
        'band2V': '<a:tcStyle><a:fill/></a:tcStyle>',
      }, f: ' bandCol="1"');
      expect(fillAt(t, 0, 0), 0xFF111111);
    });
    PptxTableShape fr(String ref) => withStyle('{R}', {'wholeTbl': '<a:tcStyle>$ref</a:tcStyle>'});
    test('R17.38 fillRef idx 1 ⇒ màu ref', () {
      expect(fillAt(fr('<a:fillRef idx="1"><a:srgbClr val="0000E1"/></a:fillRef>'), 1, 1), 0xFF0000E1);
    });
    test('R17.39 fillRef thiếu idx ⇒ null', () => expect(fillAt(fr('<a:fillRef><a:srgbClr val="0000E1"/></a:fillRef>'), 1, 1), isNull));
    test('R17.40 fillRef idx 0 ⇒ null', () {
      expect(fillAt(fr('<a:fillRef idx="0"><a:srgbClr val="0000E1"/></a:fillRef>'), 1, 1), isNull);
    });
    test('R17.41 fillRef không màu ⇒ null', () => expect(fillAt(fr('<a:fillRef idx="1"/>'), 1, 1), isNull));
    test('R17.43 không tcBdr ⇒ không viền', () {
      expect(bordersAt(withStyle('{N}', {'wholeTbl': fillPart('111111')}), 1, 1), [null, null, null, null]);
    });
    test('R17.44 firstRow có tcBdr, ô (0,1): cạnh dưới vùng hàng tiêu đề', () {
      final t = withStyle('{H}', {'firstRow': '<a:tcStyle>${bdr('00B00')}</a:tcStyle>'}, f: ' firstRow="1"');
      expect(bordersAt(t, 0, 1), [0xFF00B006, 0xFF00B006, 0xFF00B003, 0xFF00B004]);
    });
    test('R17.45 wholeTbl, ô (1,0) ⇒ trái = left', () => expect(at(withStyle('{B}', bOnly), 1, 0).borderLeft?.colorArgb, 0xFF0000A1));
    test('R17.47 ô (1,2) ⇒ phải = right', () => expect(at(withStyle('{B}', bOnly), 1, 2).borderRight?.colorArgb, 0xFF0000A2));
    test('R17.48 firstCol có tcBdr, ô (1,0): vùng 1 cột', () {
      final t = withStyle('{C}', {'firstCol': '<a:tcStyle>${bdr('00C00')}</a:tcStyle>'}, f: ' firstCol="1"');
      expect(bordersAt(t, 1, 0), [0xFF00C001, 0xFF00C002, 0xFF00C005, 0xFF00C005]);
    });
    test('R17.49 ô (0,1) ⇒ trên = top', () => expect(at(withStyle('{B}', bOnly), 0, 1).borderTop?.colorArgb, 0xFF0000A3));
    test('R17.51 ô (2,1) ⇒ dưới = bottom', () => expect(at(withStyle('{B}', bOnly), 2, 1).borderBottom?.colorArgb, 0xFF0000A4));
    final kWhole = '<a:tcStyle><a:tcBdr>${bd('left', '0000A1')}${bd('right', '0000A2')}${bd('top', '0000A3')}${bd('bottom', '0000A4')}</a:tcBdr></a:tcStyle>';
    PptxTableShape k1(String firstRowSides) => withStyle('{K2}', {
      'wholeTbl': kWhole,
      'firstRow': '<a:tcStyle><a:tcBdr>$firstRowSides</a:tcBdr></a:tcStyle>',
    }, f: ' firstRow="1"', rows: 1, cols: 1);
    final l = bd('left', '00B001'), r = bd('right', '00B002'), tp = bd('top', '00B003'), bt = bd('bottom', '00B004');
    test('R17.52 thiếu left ⇒ giữ A1', () => expect(bordersAt(k1('$r$tp$bt'), 0, 0), [0xFF0000A1, 0xFF00B002, 0xFF00B003, 0xFF00B004]));
    test('R17.53 thiếu right ⇒ giữ A2', () => expect(bordersAt(k1('$l$tp$bt'), 0, 0), [0xFF00B001, 0xFF0000A2, 0xFF00B003, 0xFF00B004]));
    test('R17.54 thiếu top ⇒ giữ A3', () => expect(bordersAt(k1('$l$r$bt'), 0, 0), [0xFF00B001, 0xFF00B002, 0xFF0000A3, 0xFF00B004]));
    test('R17.55 thiếu bottom ⇒ giữ A4', () => expect(bordersAt(k1('$l$r$tp'), 0, 0), [0xFF00B001, 0xFF00B002, 0xFF00B003, 0xFF0000A4]));
    test('R17.56 part không tcTxStyle', () {
      final r = runAt(withStyle('{N}', {'wholeTbl': fillPart('111111')}), 1, 1);
      expect([r.bold, r.colorArgb, r.fontFamily], [false, 0xFF000000, 'Arial']);
    });
    test('R17.57 tcTxStyle thiếu b ⇒ không đậm', () {
      expect(runAt(withParts(partsS(tx: txW.replaceFirst('b="on" i="on"', 'i="on"'))), 1, 1).bold, isFalse);
    });
    test('R17.58 tcTxStyle thiếu i ⇒ không nghiêng', () {
      expect(runAt(withParts(partsS(tx: txW.replaceFirst('b="on" i="on"', 'b="on"'))), 1, 1).italic, isFalse);
    });
    test('R17.59 không màu trực tiếp ⇒ màu fontRef, ô (0,1)', () {
      expect(runAt(withParts(partsS(tx: txW.replaceFirst('<a:srgbClr val="0000F1"/>', ''))), 0, 1).colorArgb, 0xFFED7D31);
    });
    test('R17.60 fontRef cũng không màu ⇒ màu otherStyle', () {
      final t = withParts(partsS(tx: '<a:tcTxStyle b="on" i="on"><a:fontRef idx="major"/></a:tcTxStyle>'));
      expect(runAt(t, 0, 1).colorArgb, 0xFF000000);
    });
    test('R17.61 không fontRef ⇒ font otherStyle', () {
      final t = withParts(partsS(tx: '<a:tcTxStyle b="on" i="on"><a:srgbClr val="0000F1"/></a:tcTxStyle>'));
      expect(runAt(t, 1, 1).fontFamily, 'Arial');
    });
    test('R17.62 fontRef minor', () {
      expect(runAt(withParts(partsS(tx: txW.replaceFirst('idx="major"', 'idx="minor"'))), 1, 1).fontFamily, 'Calibri');
    });
    test('R17.63 fontRef none ⇒ font không đổi', () {
      expect(runAt(withParts(partsS(tx: txW.replaceFirst('idx="major"', 'idx="none"'))), 1, 1).fontFamily, 'Arial');
    });
    test('R17.64 ô không tcPr ⇒ lề/neo mặc định', () {
      final t = tableOf(tableXml(cell: (r, c) => tcX('x', tcPr: null)));
      final c = at(t, 1, 1);
      expect([c.insets.left, c.insets.top, c.insets.right, c.insets.bottom], [91440, 45720, 91440, 45720]);
      expect(c.verticalAnchor, PptxAnchor.top);
      expect(c.fill?.colorArgb, 0xFF444444);
    });
    String Function(int, int) only11(String Function() f) => (r, c) => r == 1 && c == 1 ? f() : defCell(r, c);
    test('R17.65 tcPr có fill ⇒ đè style', () {
      final t = tableOf(tableXml(cell: only11(() => tcX('x', tcPr: '<a:tcPr>${solid('FFFF00')}</a:tcPr>'))));
      expect(fillAt(t, 1, 1), 0xFFFFFF00);
    });
    test('R17.66 master không txStyles ⇒ 18pt', () {
      expect(runAt(tableOf(tableXml(), cfg: (b) => b.masterTxStyles = ''), 1, 1).fontSizePt, 18);
    });
    test('R17.68 ô không txBody ⇒ không đoạn', () {
      expect(at(tableOf(tableXml(cell: only11(() => tcX('x', body: false)))), 1, 1).paragraphs, isEmpty);
    });
    PptxTableCell c11(String attrs) => at(tableOf(tableXml(cell: only11(() => tcX('x', attrs: attrs)))), 1, 1);
    test('R17.70 thiếu gridSpan ⇒ 1', () => expect(c11(' rowSpan="2" hMerge="1" vMerge="1"').gridSpan, 1));
    test('R17.71 thiếu rowSpan ⇒ 1', () => expect(c11(' gridSpan="2" hMerge="1" vMerge="1"').rowSpan, 1));
    test('R17.72 thiếu hMerge ⇒ false', () => expect(c11(' gridSpan="2" rowSpan="2" vMerge="1"').hMerge, isFalse));
    test('R17.73 thiếu vMerge ⇒ false', () => expect(c11(' gridSpan="2" rowSpan="2" hMerge="1"').vMerge, isFalse));
    PptxInsets ins11(String tcPr) => at(tableOf(tableXml(cell: only11(() => tcX('x', tcPr: tcPr)))), 1, 1).insets;
    test('R17.75 thiếu marL ⇒ 91440', () => expect(ins11('<a:tcPr marT="2" marR="3" marB="4"/>').left, 91440));
    test('R17.77 thiếu marT ⇒ 45720', () => expect(ins11('<a:tcPr marL="1" marR="3" marB="4"/>').top, 45720));
    test('R17.79 thiếu marR ⇒ 91440', () => expect(ins11('<a:tcPr marL="1" marT="2" marB="4"/>').right, 91440));
    test('R17.81 thiếu marB ⇒ 45720', () => expect(ins11('<a:tcPr marL="1" marT="2" marR="3"/>').bottom, 45720));
    test('R17.83 tr thiếu h ⇒ 0', () => expect(tableOf(tableXml(trH: '')).rows.first.heightEmu, 0));
    test('R17.x2 fillRef idx 2 ⇒ style thứ 2 của theme fillStyleLst (README)', () {
      final t = tableOf(tableXml(tblPr: tblPrX('', id: '{R2}')),
          styles: tblStyle('{R2}', {'wholeTbl': '<a:tcStyle><a:fillRef idx="2"><a:schemeClr val="accent1"/></a:fillRef></a:tcStyle>'}),
          cfg: (b) => b.theme = defaultTheme.replaceFirst(
                '<a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>',
                '<a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill>${solid('010203')}</a:fillStyleLst>',
              ));
      expect(fillAt(t, 1, 1), 0xFF010203);
    });

    // ---- closure border / explicit (tcPr lnL), bảng 1×1
    PptxTableCell one1(String tcPr, {bool style = false}) {
      final x = tableXml(rows: 1, cols: 1, cell: (r, c) => tcX('x', tcPr: tcPr), tblPr: style ? tblPrX('', id: '{K}') : null, noTblPr: !style);
      return at(tableOf(x, styles: tblStyle('{K}', {'wholeTbl': kWhole})), 0, 0);
    }

    test('R17b.1 lnL solid + w', () {
      final c = one1('<a:tcPr><a:lnL w="25400">${solid('0000B1')}</a:lnL></a:tcPr>');
      expect([c.borderLeft?.colorArgb, c.borderLeft?.widthEmu], [0xFF0000B1, 25400]);
    });
    test('R17b.2 không lnL, không style ⇒ null', () => expect(one1('<a:tcPr/>').borderLeft, isNull));
    test('R17b.3 lnL noFill ⇒ bỏ viền style', () => expect(one1('<a:tcPr><a:lnL><a:noFill/></a:lnL></a:tcPr>', style: true).borderLeft, isNull));
    test('R17b.4 lnL không màu ⇒ giữ viền style', () {
      expect(one1('<a:tcPr><a:lnL w="25400"/></a:tcPr>', style: true).borderLeft?.colorArgb, 0xFF0000A1);
    });
    test('R17b.5 lnL thiếu w ⇒ 12700', () => expect(one1('<a:tcPr><a:lnL>${solid('0000B1')}</a:lnL></a:tcPr>').borderLeft?.widthEmu, 12700));
    test('R17e.1 spec ⇒ viền tcPr', () {
      expect(one1('<a:tcPr><a:lnL>${solid('0000B1')}</a:lnL></a:tcPr>', style: true).borderLeft?.colorArgb, 0xFF0000B1);
    });
    test('R17e.2 không spec ⇒ viền style', () => expect(one1('<a:tcPr/>', style: true).borderLeft?.colorArgb, 0xFF0000A1));

    // ---- closure styleBorder (cạnh left của wholeTbl), bảng 1×1
    PptxLine? sbLeft(String tcBdr) =>
        at(withStyle('{L}', {'wholeTbl': '<a:tcStyle>$tcBdr</a:tcStyle>'}, rows: 1, cols: 1), 0, 0).borderLeft;
    String lnRef(String attrs, {bool color = true}) =>
        '<a:tcBdr><a:left><a:lnRef$attrs>${color ? '<a:schemeClr val="accent1"/>' : ''}</a:lnRef></a:left></a:tcBdr>';
    test('R17s.1 left có a:ln', () {
      final ln = sbLeft('<a:tcBdr>${bd('left', '0000C1', w: ' w="25400"')}</a:tcBdr>');
      expect([ln?.colorArgb, ln?.widthEmu], [0xFF0000C1, 25400]);
    });
    test('R17s.2 tcBdr không left ⇒ null', () => expect(sbLeft('<a:tcBdr/>'), isNull));
    test('R17s.3 lnRef idx 3 ⇒ màu ref, độ dày theme', () {
      final ln = sbLeft(lnRef(' idx="3"'));
      expect([ln?.colorArgb, ln?.widthEmu], [0xFF4472C4, 19050]);
    });
    test('R17s.4 left rỗng ⇒ null', () => expect(sbLeft('<a:tcBdr><a:left/></a:tcBdr>'), isNull));
    test('R17s.5 lnRef thiếu idx ⇒ null', () => expect(sbLeft(lnRef('')), isNull));
    test('R17s.6 lnRef không màu ⇒ null', () => expect(sbLeft(lnRef(' idx="2"', color: false)), isNull));
    test('R17s.7 lnRef idx 0 ⇒ null', () => expect(sbLeft(lnRef(' idx="0"')), isNull));
    test('R17s.8 lnRef idx 5 ⇒ 12700', () {
      final ln = sbLeft(lnRef(' idx="5"'));
      expect([ln?.colorArgb, ln?.widthEmu], [0xFF4472C4, 12700]);
    });

    // ---- closure flag / add / side
    test('R17f.1 cờ firstRow có ⇒ áp header', () => expect(fillAt(base(), 0, 1), 0xFF999999));
    test('R17f.2 thiếu thuộc tính ⇒ không áp', () {
      expect(fillAt(flags(' lastRow="1" firstCol="1" lastCol="1" bandRow="1" bandCol="1"'), 0, 1), isNot(0xFF999999));
    });
    test('R17a.1 part có ⇒ thêm', () {
      expect(fillAt(flags(' firstRow="1" lastRow="1" firstCol="1" lastCol="1" bandRow="1"'), 1, 1), 0xFF111111);
    });
    test('R17a.2 style thiếu band1H ⇒ không thêm', () {
      final p = partsS()..remove('band1H')..remove('band2H');
      expect(runAt(withParts(p), 1, 1).colorArgb, 0xFF0000F1);
    });
    test('R17d.1 cạnh ngoài', () => expect(at(withStyle('{B}', bOnly), 1, 0).borderLeft?.colorArgb, 0xFF0000A1));
    test('R17d.2 cạnh trong', () => expect(at(withStyle('{B}', bOnly), 1, 1).borderLeft?.colorArgb, 0xFF0000A6));
  });

  // ============================================================ R18 _line
  group('R18 _line', () {
    String styleLn(String lnRef) =>
        '<p:style>$lnRef<a:fillRef idx="0"><a:schemeClr val="accent1"/></a:fillRef>'
        '<a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="tx1"/></a:fontRef></p:style>';
    String ref(String idx) => '<a:lnRef idx="$idx"><a:schemeClr val="accent1"/></a:lnRef>';
    PptxLine? lineOf(String ln, {String? style}) => ts(slideOf(box('A', extra: ln, style: style ?? styleLn(ref('2')))), 'A').line;
    List<int?> lw(PptxLine? l) => [l?.colorArgb, l?.widthEmu];
    String lnX(String inner, {String w = ' w="25400"'}) => '<a:ln$w>$inner</a:ln>';
    PptxLine? titleLine(String slideLn) {
      final layout = sp(id: 2, name: 'Title 1', ph: 'type="title"', spPr: xfrm(1, 1, 1, 1) + lnX(solid('445566'), w: ' w="50800"'));
      final s = slideOf(sp(id: 20, name: 'A', ph: 'type="title"', spPr: xfrm(0, 0, 1, 1) + slideLn), (b) => b.layoutShapes = layout);
      return ts(s, 'A').line;
    }

    test('R18.1 ln solid + w', () => expect(lw(lineOf(lnX(solid('112233')))), [0xFF112233, 25400]));
    test('R18.2 không ln ⇒ lnRef', () => expect(lw(lineOf('')), [0xFF4472C4, 12700]));
    test('R18.3 shape có w, layout có màu', () => expect(lw(titleLine(lnX(''))), [0xFF445566, 25400]));
    test('R18.4 shape đã có màu ⇒ bỏ ln layout', () => expect(lw(titleLine(lnX(solid('112233')))), [0xFF112233, 25400]));
    test('R18.5 ln noFill ⇒ không viền', () => expect(lineOf(lnX('<a:noFill/>')), isNull));
    test('R18.6 ln chỉ w ⇒ màu lnRef', () => expect(lw(lineOf(lnX(''))), [0xFF4472C4, 25400]));
    test('R18.7 ln gradFill ⇒ stop đầu', () {
      expect(lw(lineOf(lnX('<a:gradFill><a:gsLst><a:gs pos="0"><a:srgbClr val="778899"/></a:gs>'
          '<a:gs pos="100000"><a:srgbClr val="000000"/></a:gs></a:gsLst></a:gradFill>'))), [0xFF778899, 25400]);
    });
    test('R18.8 ln chỉ w, không p:style ⇒ null', () => expect(lineOf(lnX(''), style: ''), isNull));
    test('R18.9 style không lnRef ⇒ null', () => expect(lineOf(lnX(''), style: styleLn('')), isNull));
    test('R18.10 lnRef thiếu idx ⇒ null', () {
      expect(lineOf(lnX(''), style: styleLn('<a:lnRef><a:schemeClr val="accent1"/></a:lnRef>')), isNull);
    });
    test('R18.12 không ln, lnRef idx 0 ⇒ null', () => expect(lineOf('', style: styleLn(ref('0'))), isNull));
    test('R18.13 ln màu không w ⇒ độ dày lnRef', () => expect(lw(lineOf(lnX(solid('112233'), w: ''))), [0xFF112233, 12700]));
    test('R18.14 như .13, idx 0 ⇒ 9525', () {
      expect(lw(lineOf(lnX(solid('112233'), w: ''), style: styleLn(ref('0')))), [0xFF112233, 9525]);
    });
    test('R18.15 như .13, idx 5 ⇒ 9525', () {
      expect(lw(lineOf(lnX(solid('112233'), w: ''), style: styleLn(ref('5')))), [0xFF112233, 9525]);
    });
    test('R18.16 màu không giải được ⇒ null', () {
      expect(lineOf(lnX('<a:solidFill><a:schemeClr val="zz"/></a:solidFill>')), isNull);
    });
  });

  // ============================================================ R19 _customPaths (+ num, pts)
  group('R19 _customPaths', () {
    String pt(String x, String y) => '<a:pt x="$x" y="$y"/>';
    final mv = '<a:moveTo>${pt('0', '0')}</a:moveTo>';
    final ln = '<a:lnTo>${pt('100', '0')}</a:lnTo>';
    final cb = '<a:cubicBezTo>${pt('1', '2')}${pt('3', '4')}${pt('5', '6')}</a:cubicBezTo>';
    final qd = '<a:quadBezTo>${pt('7', '8')}${pt('9', '10')}</a:quadBezTo>';
    String arc({String wR = '10', String hR = '20', String st = '5400000', String sw = '10800000'}) =>
        '<a:arcTo wR="$wR" hR="$hR" stAng="$st" swAng="$sw"/>';
    const cl = '<a:close/>';
    String path(String cmds, {String attrs = ' w="100" h="200" fill="none" stroke="0"'}) => '<a:path$attrs>$cmds</a:path>';
    String cust(String paths) =>
        '<a:custGeom><a:avLst/><a:gdLst/><a:ahLst/><a:cxnLst/><a:rect l="0" t="0" r="r" b="b"/><a:pathLst>$paths</a:pathLst></a:custGeom>';
    PptxTextShape shapeOf(String geom) => ts(slideOf(sp(id: 20, name: 'A', spPr: xfrm(0, 0, 300, 400) + geom)), 'A');
    List<PptxCustomPath> pathsOf(String paths) => shapeOf(cust(paths)).customPaths;
    List<Object> cmd(PptxPathCommand c) => [c.kind, c.args];
    final all = '$mv$ln$cb$qd${arc()}$cl';

    test('R19.1 đủ 6 loại lệnh', () {
      final p = pathsOf(path(all)).single;
      expect([p.widthEmu, p.heightEmu, p.filled, p.stroked], [100, 200, false, false]);
      expect(p.commands.map(cmd).toList(), [
        [PptxPathOp.moveTo, [0.0, 0.0]],
        [PptxPathOp.lineTo, [100.0, 0.0]],
        [PptxPathOp.cubicTo, [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]],
        [PptxPathOp.quadTo, [7.0, 8.0, 9.0, 10.0]],
        [PptxPathOp.arcTo, [10.0, 20.0, 90.0, 180.0]],
        [PptxPathOp.close, <double>[]],
      ]);
    });
    test('R19.2 không pathLst ⇒ rỗng, other', () {
      final t = shapeOf('<a:custGeom><a:avLst/></a:custGeom>');
      expect(t.customPaths, isEmpty);
      expect(t.geometry, PptxGeometry.other);
    });
    test('R19.4 pathLst rỗng ⇒ rỗng', () => expect(pathsOf(''), isEmpty));
    test('R19.5 thiếu w ⇒ = frame cx', () => expect(pathsOf(path(all, attrs: ' h="200"')).single.widthEmu, 300));
    test('R19.6 thiếu h ⇒ = frame cy', () => expect(pathsOf(path(all, attrs: ' w="100"')).single.heightEmu, 400));
    test('R19.7 w=0 ⇒ frame cx', () => expect(pathsOf(path(all, attrs: ' w="0" h="200"')).single.widthEmu, 300));
    test('R19.8 h=0 ⇒ frame cy', () => expect(pathsOf(path(all, attrs: ' w="100" h="0"')).single.heightEmu, 400));
    test('R19.9 path không lệnh ⇒ bỏ', () => expect(pathsOf(path('')), isEmpty));
    List<Object> single(String c) => cmd(pathsOf(path(c)).single.commands.single);
    test('R19.10 chỉ lnTo', () => expect(single(ln), [PptxPathOp.lineTo, [100.0, 0.0]]));
    test('R19.11 chỉ cubicBezTo', () => expect(single(cb), [PptxPathOp.cubicTo, [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]]));
    test('R19.12 chỉ quadBezTo', () => expect(single(qd), [PptxPathOp.quadTo, [7.0, 8.0, 9.0, 10.0]]));
    test('R19.13 chỉ arcTo', () => expect(single(arc()), [PptxPathOp.arcTo, [10.0, 20.0, 90.0, 180.0]]));
    test('R19.14 chỉ close', () => expect(single(cl), [PptxPathOp.close, <double>[]]));
    test('R19.15 phần tử lạ bị bỏ', () => expect(single('$mv<a:foo/>'), [PptxPathOp.moveTo, [0.0, 0.0]]));
    test('R19.16 wR là guide ⇒ bỏ path', () => expect(pathsOf(path('$mv${arc(wR: 'w2')}')), isEmpty));
    test('R19.17 hR là guide ⇒ bỏ path', () => expect(pathsOf(path('$mv${arc(hR: 'h2')}')), isEmpty));
    test('R19.18 stAng là guide ⇒ bỏ path', () => expect(pathsOf(path('$mv${arc(st: 'a1')}')), isEmpty));
    test('R19.19 swAng là guide ⇒ bỏ path', () => expect(pathsOf(path('$mv${arc(sw: 'a2')}')), isEmpty));
    test('R19.21 chỉ phần tử lạ ⇒ bỏ', () => expect(pathsOf(path('<a:foo/>')), isEmpty));
    test('R19.22 thiếu stroke ⇒ true', () => expect(pathsOf(path(all, attrs: ' w="100" h="200"')).single.stroked, isTrue));
    test('R19n.1 toạ độ số ⇒ giữ path', () => expect(pathsOf(path(mv)), hasLength(1)));
    test('R19n.2 pt thiếu x ⇒ bỏ path', () => expect(pathsOf(path('<a:moveTo><a:pt y="0"/></a:moveTo>')), isEmpty));
    test('R19n.3 x là guide ⇒ bỏ path', () => expect(pathsOf(path('<a:moveTo>${pt('w2', '0')}</a:moveTo>')), isEmpty));
    test('R19p.1 pt số ⇒ giữ', () => expect(pathsOf(path('<a:lnTo>${pt('1', '2')}</a:lnTo>')), hasLength(1)));
    test('R19p.2 x guide ⇒ bỏ', () => expect(pathsOf(path('<a:lnTo>${pt('w', '2')}</a:lnTo>')), isEmpty));
    test('R19p.3 y guide ⇒ bỏ', () => expect(pathsOf(path('<a:lnTo>${pt('1', 'h')}</a:lnTo>')), isEmpty));
  });

  // ============================================================ R20 _theme (+ font)
  group('R20 _theme', () {
    final themeBase = defaultTheme
        .replaceFirst('<a:accent1><a:srgbClr val="4472C4"/></a:accent1>', '<a:accent1><a:srgbClr val="123456"/></a:accent1>')
        .replaceFirst('<a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>',
            '<a:fillStyleLst>${solid('010203')}</a:fillStyleLst>')
        .replaceFirst('<a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>',
            '<a:bgFillStyleLst>${solid('040506')}</a:bgFillStyleLst>');
    const runMj = '<a:p><a:r><a:rPr lang="en-US"><a:latin typeface="+mj-lt"/></a:rPr><a:t>x</a:t></a:r></a:p>';
    String style(String lnIdx, String fillIdx) =>
        '<p:style><a:lnRef idx="$lnIdx"><a:schemeClr val="accent1"/></a:lnRef><a:fillRef idx="$fillIdx"><a:schemeClr val="accent2"/></a:fillRef>'
        '<a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef><a:fontRef idx="minor"><a:schemeClr val="tx1"/></a:fontRef></p:style>';
    final shapes = sp(id: 20, name: 'C', spPr: xfrm(0, 0, 1, 1) + '<a:solidFill><a:schemeClr val="accent1"/></a:solidFill>', txBody: txBody(runMj)) +
        box('F', id: 21, style: style('0', '1')) +
        box('L', id: 22, style: style('2', '0'));
    PptxSlide th(String Function(String) f, {bool noThemeRel = false}) {
      // masterTxStyles '' ⇒ font của run chỉ đến từ rPr '+mj-lt' (không lẫn otherStyle).
      final b = bld(shapes)
        ..theme = f(themeBase)
        ..masterTxStyles = '';
      var bytes = b.build();
      if (noThemeRel) bytes = edit(bytes, kMasterRels, (s) => dropRel(s, 'rId2'));
      return readPptx(bytes).slides.single;
    }

    String id(String s) => s;
    String cut(String s, String re) => s.replaceFirst(RegExp(re), '');
    int? fill(PptxSlide s, String n) => ts(s, n).fill?.colorArgb;
    String? font(PptxSlide s) => run0(ts(s, 'C')).fontFamily;

    test('R20.1 theme đủ phần', () {
      final s = th(id);
      expect([fill(s, 'C'), fill(s, 'F'), ts(s, 'L').line?.widthEmu, s.background?.colorArgb],
          [0xFF123456, 0xFF010203, 12700, 0xFF040506]);
      expect(font(s), 'Calibri Light');
    });
    void officeDefaults(PptxSlide s) {
      expect([fill(s, 'C'), fill(s, 'F'), ts(s, 'L').line?.widthEmu, s.background?.colorArgb],
          [0xFF4472C4, 0xFFED7D31, 9525, 0xFFFFFFFF]);
      expect(font(s), isNull);
    }

    test('R20.2 master không rel theme ⇒ mặc định Office', () => officeDefaults(th(id, noThemeRel: true)));
    test('R20.3 theme không themeElements', () => officeDefaults(th((_) => '<?xml version="1.0"?><a:theme xmlns:a="$nsA" name="x"/>')));
    test('R20.4 không clrScheme', () {
      final s = th((t) => cut(t, r'<a:clrScheme[\s\S]*?</a:clrScheme>'));
      expect([fill(s, 'C'), fill(s, 'F')], [0xFF4472C4, 0xFF010203]);
      expect(font(s), 'Calibri Light');
    });
    test('R20.6 clrScheme rỗng', () {
      expect(fill(th((t) => t.replaceFirst(RegExp(r'<a:clrScheme[\s\S]*?</a:clrScheme>'), '<a:clrScheme name="x"/>')), 'C'), 0xFF4472C4);
    });
    test('R20.7 accent1 rỗng ⇒ mặc định', () {
      expect(fill(th((t) => t.replaceFirst('<a:accent1><a:srgbClr val="123456"/></a:accent1>', '<a:accent1/>')), 'C'), 0xFF4472C4);
    });
    test('R20.8 accent1 sysClr lastClr', () {
      final s = th((t) => t.replaceFirst('<a:srgbClr val="123456"/>', '<a:sysClr val="windowText" lastClr="ABCDEF"/>'));
      expect(fill(s, 'C'), 0xFFABCDEF);
    });
    test('R20.9 hex hỏng ⇒ mặc định', () => expect(fill(th((t) => t.replaceFirst('val="123456"', 'val="ZZZZZZ"')), 'C'), 0xFF4472C4));
    test('R20.12 không lnStyleLst ⇒ 9525', () {
      expect(ts(th((t) => cut(t, r'<a:lnStyleLst>[\s\S]*?</a:lnStyleLst>')), 'L').line?.widthEmu, 9525);
    });
    test('R20.14 ln thiếu w ⇒ 9525', () {
      expect(ts(th((t) => t.replaceFirst('<a:ln w="12700">', '<a:ln>')), 'L').line?.widthEmu, 9525);
    });
    test('R20.16 không fillStyleLst ⇒ màu ref', () {
      expect(fill(th((t) => cut(t, r'<a:fillStyleLst>[\s\S]*?</a:fillStyleLst>')), 'F'), 0xFFED7D31);
    });
    test('R20.19 không bgFillStyleLst ⇒ màu ref', () {
      expect(th((t) => cut(t, r'<a:bgFillStyleLst>[\s\S]*?</a:bgFillStyleLst>')).background?.colorArgb, 0xFFFFFFFF);
    });
    test('R20f.1 majorFont có', () => expect(font(th(id)), 'Calibri Light'));
    test('R20f.2 không fontScheme ⇒ null', () => expect(font(th((t) => cut(t, r'<a:fontScheme[\s\S]*?</a:fontScheme>'))), isNull));
    test('R20f.3 majorFont không latin ⇒ null', () {
      expect(font(th((t) => t.replaceFirst('<a:latin typeface="Calibri Light"/>', ''))), isNull);
    });
    test('R20f.4 latin không typeface ⇒ null', () {
      expect(font(th((t) => t.replaceFirst('<a:latin typeface="Calibri Light"/>', '<a:latin/>'))), isNull);
    });
    test('R20f.5 typeface rỗng ⇒ null', () {
      expect(font(th((t) => t.replaceFirst('typeface="Calibri Light"', 'typeface=""'))), isNull);
    });
  });

  // ============================================================ R21 _master
  group('R21 _master', () {
    final shapes = box('A', extra: '<a:solidFill><a:schemeClr val="tx1"/></a:solidFill>') +
        box('B', id: 21, extra: '<a:solidFill><a:schemeClr val="accent1"/></a:solidFill>');
    PptxBuilder mb({int slides = 1}) {
      final b = PptxBuilder()
        ..masterShapes = defaultMasterShapes + box('MDeco', id: 50)
        ..theme = defaultTheme.replaceFirst('val="4472C4"', 'val="123456"');
      for (var i = 0; i < slides; i++) {
        b.slides.add(TestSlide(shapes));
      }
      return b;
    }

    Uint8List bytes(PptxBuilder b) => edit(b.build(), kMaster, (s) => s.replaceFirst('tx1="dk1"', 'tx1="lt1"'));
    int? fill(PptxSlide s, String n) => ts(s, n).fill?.colorArgb;

    test('R21.1 master đủ', () {
      final s = readPptx(bytes(mb())).slides.single;
      expect(names(s), ['MDeco', 'A', 'B']);
      expect([fill(s, 'A'), fill(s, 'B'), s.background?.colorArgb], [0xFFFFFFFF, 0xFF123456, 0xFFFFFFFF]);
    });
    test('R21.2 không đường master ⇒ master rỗng', () {
      var z = edit(bytes(mb()), kSlideRels, (s) => dropRel(s, 'rId1'));
      z = edit(z, kPresRels, (s) => dropRel(s, 'rId1'));
      final s = readPptx(z).slides.single;
      expect(names(s), ['A', 'B']);
      expect([fill(s, 'A'), fill(s, 'B'), s.background], [0xFF000000, 0xFF4472C4, null]);
    });
    test('R21.3 slide 2 dùng lại master (cache)', () {
      final z = edit(bytes(mb(slides: 2)), kSlide2Rels, (s) => dropRel(s, 'rId1'));
      final s2 = readPptx(z).slides[1];
      expect(names(s2), ['MDeco', 'A', 'B']);
      expect([fill(s2, 'A'), s2.background?.colorArgb], [0xFFFFFFFF, 0xFFFFFFFF]);
    });
    test('R21.5 rel master trỏ part không có ⇒ master rỗng', () {
      final z = edit(bytes(mb()), kLayoutRels, (s) => s.replaceFirst('slideMaster1.xml', 'slideMaster9.xml'));
      final s = readPptx(z).slides.single;
      expect(names(s), ['A', 'B']);
      expect([fill(s, 'A'), fill(s, 'B'), s.background], [0xFF000000, 0xFF4472C4, null]);
    });
    test('R21.6 master không rel theme ⇒ màu Office', () {
      final s = readPptx(edit(bytes(mb()), kMasterRels, (s) => dropRel(s, 'rId2'))).slides.single;
      expect(names(s), contains('MDeco'));
      expect([fill(s, 'A'), fill(s, 'B')], [0xFFFFFFFF, 0xFF4472C4]);
    });
    test('R21.7 master không clrMap ⇒ tx1 → dk1', () {
      final s = readPptx(edit(bytes(mb()), kMaster, (s) => s.replaceFirst(RegExp(r'<p:clrMap [^>]*/>'), ''))).slides.single;
      expect(fill(s, 'A'), 0xFF000000);
    });
  });

  // ============================================================ R22 _layout
  group('R22 _layout', () {
    PptxBuilder lb({int slides = 1}) {
      final b = PptxBuilder()
        ..masterShapes = defaultMasterShapes + box('MDeco', id: 50)
        ..layoutShapes = defaultLayoutShapes + box('LDeco', id: 60);
      for (var i = 0; i < slides; i++) {
        b.slides.add(TestSlide(box('A')));
      }
      return b;
    }

    test('R22.1 layout đủ', () => expect(names(readPptx(lb().build()).slides.single), ['MDeco', 'LDeco', 'A']));
    test('R22.2 slide không rel layout', () {
      expect(names(readPptx(edit(lb().build(), kSlideRels, (s) => dropRel(s, 'rId1'))).slides.single), ['MDeco', 'A']);
    });
    test('R22.3 2 slide cùng layout (cache)', () {
      final d = readPptx(lb(slides: 2).build());
      expect(d.slides.map(names).toList(), [
        ['MDeco', 'LDeco', 'A'],
        ['MDeco', 'LDeco', 'A'],
      ]);
    });
    test('R22.5 rel layout trỏ part không có', () {
      final z = edit(lb().build(), kSlideRels, (s) => s.replaceFirst('slideLayout1.xml', 'slideLayout9.xml'));
      expect(names(readPptx(z).slides.single), ['MDeco', 'A']);
    });
    test('R22.6 layout không rel master ⇒ master của presentation', () {
      final z = edit(lb().build(), kLayoutRels, (s) => dropRel(s, 'rId1'));
      expect(names(readPptx(z).slides.single), ['MDeco', 'LDeco', 'A']);
    });
  });
}
