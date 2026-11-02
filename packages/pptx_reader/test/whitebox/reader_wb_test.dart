// Kiểm thử hộp trắng A19 — lib/src/reader.dart (mã bộ R*, xem
// test-output/whitebox/pptx-reader/reader/buoc-5-du-lieu-thu.md).
// Mọi hàm reader là private ⇒ đi qua readPptx(bytes). Gói pptx dựng bằng
// test/helpers/pptx_builder.dart (chỉ import) rồi vá từng part bằng package:archive.
// Không mock; nhánh đã đi khẳng định qua kết quả phân biệt theo nhánh (shape có/không,
// khung, màu, loại shape).
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pptx_reader/pptx_reader.dart';
import 'package:test/test.dart';

import '../helpers/pptx_builder.dart';

const kSlide = 'ppt/slides/slide1.xml';
const kSlideRels = 'ppt/slides/_rels/slide1.xml.rels';
const kPres = 'ppt/presentation.xml';
const kPresRels = 'ppt/_rels/presentation.xml.rels';
const kLayout = 'ppt/slideLayouts/slideLayout1.xml';
const kNotes = 'ppt/notesSlides/notesSlide1.xml';

String partOf(Uint8List zip, String name) => utf8.decode(
  ZipDecoder().decodeBytes(zip).files.firstWhere((f) => f.name == name).readBytes()!,
);

/// Thay (chuỗi) / xoá (null) part trong gói.
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

/// Sửa nội dung 1 part bằng hàm biến đổi chuỗi.
Uint8List edit(Uint8List zip, String name, String Function(String) f) =>
    patch(zip, {name: f(partOf(zip, name))});

PptxBuilder one(String shapes, {String bg = '', String? notes, Map<String, String> media = const {}, String sldAttrs = ''}) =>
    PptxBuilder()..slides.add(TestSlide(shapes, bg: bg, notes: notes, media: media, sldAttrs: sldAttrs));

Object errOf(Object? Function() f) {
  try {
    return f() ?? 'null';
  } catch (e) {
    return e;
  }
}

List<String> names(PptxSlide s) => s.shapes.map((e) => e.name).toList();
PptxShape byName(PptxSlide s, String n) => s.shapes.firstWhere((e) => e.name == n);
int? fillOf(PptxSlide s, String n) => (byName(s, n) as PptxTextShape).fill?.colorArgb;

String box(String name, {String extra = '', String style = '', int id = 20}) =>
    sp(id: id, name: name, spPr: xfrm(0, 0, 100, 100) + extra, style: style);
String styleFill(String idx, {String clr = '<a:schemeClr val="accent2"/>'}) =>
    '<p:style><a:lnRef idx="0"><a:schemeClr val="accent1"/></a:lnRef>'
    '<a:fillRef idx="$idx">$clr</a:fillRef><a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef>'
    '<a:fontRef idx="minor"><a:schemeClr val="lt1"/></a:fontRef></p:style>';
String styleNoIdx() =>
    '<p:style><a:lnRef idx="0"><a:schemeClr val="accent1"/></a:lnRef>'
    '<a:fillRef><a:schemeClr val="accent2"/></a:fillRef><a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef>'
    '<a:fontRef idx="minor"><a:schemeClr val="lt1"/></a:fontRef></p:style>';
String pic(String blip, {String name = 'Pic'}) =>
    '<p:pic><p:nvPicPr><p:cNvPr id="30" name="$name"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>'
    '<p:blipFill>$blip</p:blipFill><p:spPr>${xfrm(0, 0, 100, 100)}</p:spPr></p:pic>';
String gframe(String? data, {String name = 'G'}) =>
    '<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="40" name="$name"/><p:cNvGraphicFramePr/><p:nvPr/>'
    '</p:nvGraphicFramePr><p:xfrm><a:off x="0" y="0"/><a:ext cx="100" cy="100"/></p:xfrm>'
    '${data == null ? '' : '<a:graphic>$data</a:graphic>'}</p:graphicFrame>';

void main() {
  // ------------------------------------------------------------ R1 readPptx
  group('R1 readPptx', () {
    test('R1.1 gói hợp lệ ⇒ PptxDeck', () {
      final d = readPptx(one(box('A')).build());
      expect(names(d.slides.single), ['A']);
    });
    test('R1.2 PptxFormatException bên trong ⇒ ném lại nguyên', () {
      final r = errOf(() => readPptx(Uint8List.fromList([0, 1, 2, 3, 4])));
      expect(r, isA<PptxFormatException>());
      expect((r as PptxFormatException).message, isNot(startsWith('Cannot read pptx')));
    });
    test('R1.3 lỗi loại khác (số 1e400 trong xfrm) ⇒ bọc thành PptxFormatException', () {
      final bytes = one(sp(name: 'Big', spPr: '<a:xfrm><a:off x="1e400" y="0"/><a:ext cx="1" cy="1"/></a:xfrm>')).build();
      final r = errOf(() => readPptx(bytes));
      expect(r, isA<PptxFormatException>());
      expect((r as PptxFormatException).message, startsWith('Cannot read pptx'));
    });
  });

  // ------------------------------------------------------------ R2 _part
  group('R2 _part', () {
    test('R2.1 part có ⇒ đọc slide', () => expect(readPptx(one(box('A')).build()).slides, hasLength(1)));
    test('R2.2 XML part hỏng ⇒ PptxFormatException', () {
      final b = patch(one(box('A')).build(), {kSlide: '<p:sld'});
      expect(errOf(() => readPptx(b)), isA<PptxFormatException>());
    });
    test('R2.3 part không có ⇒ null (slide bị bỏ)', () {
      final b = patch(one(box('A')).build(), {kSlide: null});
      expect(readPptx(b).slides, isEmpty);
    });
    test('R2.4 rels của part hỏng ⇒ PptxFormatException', () {
      final b = patch(one(box('A')).build(), {kSlideRels: '<Relationships'});
      expect(errOf(() => readPptx(b)), isA<PptxFormatException>());
    });
  });

  // ------------------------------------------------------------ R3 read
  group('R3 read', () {
    Uint8List base() => one(box('A')).build();
    PptxDeck pres(String Function(String) f) => readPptx(edit(base(), kPres, f));
    test('R3.1 đường gốc: kích thước + slide theo sldIdLst', () {
      final b = PptxBuilder()
        ..reverseFileNames = true
        ..slides.addAll([TestSlide(box('first')), TestSlide(box('second'))]);
      final d = readPptx(b.build());
      expect([d.slideWidthEmu, d.slideHeightEmu], [12192000, 6858000]);
      expect(d.slides.map((s) => s.shapes.single.name).toList(), ['first', 'second']);
    });
    test('R3.2 rels gói không có officeDocument ⇒ dùng ppt/presentation.xml', () {
      final b = patch(base(), {'_rels/.rels': '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>'});
      expect(names(readPptx(b).slides.single), ['A']);
    });
    test('R3.4 không có presentation.xml ⇒ PptxFormatException', () {
      expect(errOf(() => readPptx(patch(base(), {kPres: null}))), isA<PptxFormatException>());
    });
    test('R3.5 gốc không phải presentation ⇒ PptxFormatException', () {
      final b = patch(base(), {kPres: '<p:sld xmlns:p="$nsP"/>'});
      expect(errOf(() => readPptx(b)), isA<PptxFormatException>());
    });
    test('R3.6 presentation không có rel slideMaster ⇒ vẫn đọc (master lấy qua layout)', () {
      final b = edit(base(), kPresRels, (s) => s.replaceFirst(RegExp(r'<Relationship Id="rId1"[^>]*/>'), ''));
      final d = readPptx(b);
      expect(names(d.slides.single), ['A']);
      expect(d.slides.single.background?.colorArgb, 0xFFFFFFFF);
    });
    test('R3.7 có tableStyles ⇒ đọc bình thường', () {
      final b = one(box('A'))..tableStyles = '<a:tblStyle styleId="{X}" styleName="s"/>';
      expect(names(readPptx(b.build()).slides.single), ['A']);
    });
    test('R3.8 không có sldSz ⇒ 9144000 x 6858000', () {
      final d = pres((s) => s.replaceFirst(RegExp(r'<p:sldSz[^>]*/>'), ''));
      expect([d.slideWidthEmu, d.slideHeightEmu], [9144000, 6858000]);
    });
    test('R3.10 sldSz thiếu cx ⇒ rộng 9144000, cao giữ', () {
      final d = pres((s) => s.replaceFirst(RegExp(r'<p:sldSz[^>]*/>'), '<p:sldSz cy="5000000"/>'));
      expect([d.slideWidthEmu, d.slideHeightEmu], [9144000, 5000000]);
    });
    test('R3.11 cx = 0 ⇒ 9144000', () {
      final d = readPptx((one(box('A'))..slideWidth = 0).build());
      expect(d.slideWidthEmu, 9144000);
    });
    test('R3.12 sldSz thiếu cy ⇒ cao 6858000', () {
      final d = pres((s) => s.replaceFirst(RegExp(r'<p:sldSz[^>]*/>'), '<p:sldSz cx="5000000"/>'));
      expect([d.slideWidthEmu, d.slideHeightEmu], [5000000, 6858000]);
    });
    test('R3.13 cy = 0 ⇒ 6858000', () {
      final d = readPptx((one(box('A'))..slideHeight = 0).build());
      expect(d.slideHeightEmu, 6858000);
    });
    test('R3.14 không có sldIdLst ⇒ 0 slide', () {
      expect(pres((s) => s.replaceFirst(RegExp(r'<p:sldIdLst>.*</p:sldIdLst>'), '')).slides, isEmpty);
    });
    test('R3.16 sldIdLst rỗng ⇒ 0 slide', () => expect(readPptx(PptxBuilder().build()).slides, isEmpty));
    test('R3.17 sldId trỏ rId không có ⇒ slide bị bỏ, slide sau index 0', () {
      final b = PptxBuilder()..slides.addAll([TestSlide(box('first')), TestSlide(box('second'))]);
      final d = readPptx(edit(b.build(), kPres, (s) => s.replaceFirst('r:id="rId10"', 'r:id="rIdX"')));
      expect(d.slides.map((s) => [s.index, s.shapes.single.name]).toList(), [
        [0, 'second'],
      ]);
    });
    test('R3.18 rel slide External ⇒ bị bỏ', () {
      final b = edit(base(), kPresRels,
          (s) => s.replaceFirst('Target="slides/slide1.xml"', 'Target="slides/slide1.xml" TargetMode="External"'));
      expect(readPptx(b).slides, isEmpty);
    });
    test('R3.19 rel slide trỏ part không có ⇒ bị bỏ', () {
      expect(readPptx(patch(base(), {kSlide: null})).slides, isEmpty);
    });
  });

  // ------------------------------------------------------------ R4 _slide
  group('R4 _slide', () {
    PptxBuilder deco({String sldAttrs = '', String layoutAttrs = ''}) => one(
      sp(id: 9, name: 'S', spPr: xfrm(0, 0, 10, 10) + '<a:solidFill><a:schemeClr val="tx1"/></a:solidFill>'),
      sldAttrs: sldAttrs,
    )
      ..masterShapes = '$defaultMasterShapes${box('MDeco', id: 50)}'
      ..layoutShapes = '$defaultLayoutShapes${box('LDeco', id: 51)}'
      ..layoutAttrs = layoutAttrs;
    const ovr = '<p:clrMapOvr><a:overrideClrMapping bg1="dk1" tx1="lt1" bg2="lt2" tx2="dk2" accent1="accent1" '
        'accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" '
        'folHlink="folHlink"/></p:clrMapOvr>';
    const master = '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>';
    test('R4.1 đường gốc: shape master + layout + slide, màu qua clrMap master', () {
      final s = readPptx(deco().build()).slides.single;
      expect(names(s), ['MDeco', 'LDeco', 'S']);
      expect(fillOf(s, 'S'), 0xFF000000);
    });
    test('R4.2 slide không có rel layout ⇒ layout rỗng, vẫn có shape master', () {
      final b = edit(deco().build(), kSlideRels, (s) => s.replaceFirst(RegExp(r'<Relationship Id="rId1"[^>]*/>'), ''));
      expect(names(readPptx(b).slides.single), ['MDeco', 'S']);
    });
    test('R4.3 slide có overrideClrMapping ⇒ dùng map của slide', () {
      final b = edit(deco().build(), kSlide, (s) => s.replaceFirst(master, ovr));
      expect(fillOf(readPptx(b).slides.single, 'S'), 0xFFFFFFFF);
    });
    test('R4.4 layout có overrideClrMapping ⇒ dùng map của layout', () {
      final b = edit(deco().build(), kLayout, (s) => s.replaceFirst(master, ovr));
      expect(fillOf(readPptx(b).slides.single, 'S'), 0xFFFFFFFF);
    });
    test('R4.5 slide showMasterSp="1" ⇒ như gốc', () {
      expect(names(readPptx(deco(sldAttrs: ' showMasterSp="1"').build()).slides.single), ['MDeco', 'LDeco', 'S']);
    });
    test('R4.6 slide showMasterSp="0" ⇒ không có shape master và layout', () {
      expect(names(readPptx(deco(sldAttrs: ' showMasterSp="0"').build()).slides.single), ['S']);
    });
    test('R4.7 layout showMasterSp="0" ⇒ bỏ shape master, giữ shape layout', () {
      expect(names(readPptx(deco(layoutAttrs: ' showMasterSp="0"').build()).slides.single), ['LDeco', 'S']);
    });
  });

  // ------------------------------------------------------------ R5 _background
  group('R5 _background', () {
    PptxFill? bgOf(PptxBuilder b) => readPptx(b.build()).slides.single.background;
    test('R5.1 slide/layout không bg ⇒ bgRef của master (bg1 = trắng)', () {
      expect(bgOf(one(''))?.colorArgb, 0xFFFFFFFF);
    });
    test('R5.2 không part nào có bg ⇒ null', () => expect(bgOf(one('')..masterBg = ''), isNull));
    test('R5.3 slide bgPr solidFill ⇒ màu slide', () {
      expect(bgOf(one('', bg: '<p:bg><p:bgPr>${solid('FF0000')}<a:effectLst/></p:bgPr></p:bg>'))?.colorArgb, 0xFFFF0000);
    });
    test('R5.4 master bgPr solidFill ⇒ màu master', () {
      expect(bgOf(one('')..masterBg = '<p:bg><p:bgPr>${solid('0000FF')}<a:effectLst/></p:bgPr></p:bg>')?.colorArgb, 0xFF0000FF);
    });
    test('R5.5 slide bgPr không có fill, không bgRef ⇒ đi tiếp xuống master', () {
      expect(bgOf(one('', bg: '<p:bg><p:bgPr><a:effectLst/></p:bgPr></p:bg>'))?.colorArgb, 0xFFFFFFFF);
    });
    test('R5.6 slide bgPr không fill nhưng có bgRef ⇒ dùng bgRef của slide', () {
      final bg = '<p:bg><p:bgPr><a:effectLst/></p:bgPr><p:bgRef idx="1001"><a:srgbClr val="00FF00"/></p:bgRef></p:bg>';
      expect(bgOf(one('', bg: bg))?.colorArgb, 0xFF00FF00);
    });
    test('R5.x slide bgPr noFill ⇒ không nền (null), không lấy master', () {
      expect(bgOf(one('', bg: '<p:bg><p:bgPr><a:noFill/><a:effectLst/></p:bgPr></p:bg>')), isNull);
    });
  });

  // ------------------------------------------------------------ R6 _notes
  group('R6 _notes', () {
    Uint8List withNotes() => one('', notes: 'Line1\nLine2').build();
    String? notesOf(Uint8List b) => readPptx(b).slides.single.notesText;
    String notesXml(String tree) => '<p:notes xmlns:a="$nsA" xmlns:r="$nsR" xmlns:p="$nsP"><p:cSld>$tree</p:cSld></p:notes>';
    test('R6.1 ghi chú 2 dòng nối bằng \\n', () => expect(notesOf(withNotes()), 'Line1\nLine2'));
    test('R6.2 không có notesSlide ⇒ null', () => expect(notesOf(one('').build()), isNull));
    test('R6.3 notes XML hỏng ⇒ PptxFormatException', () {
      expect(errOf(() => readPptx(patch(withNotes(), {kNotes: '<p:notes'}))), isA<PptxFormatException>());
    });
    test('R6.4 rel notes trỏ part không có ⇒ null', () => expect(notesOf(patch(withNotes(), {kNotes: null})), isNull));
    test('R6.5 notes không có cSld/spTree ⇒ null', () {
      expect(notesOf(patch(withNotes(), {kNotes: notesXml('')})), isNull);
    });
    test('R6.6 spTree rỗng ⇒ null', () {
      expect(notesOf(patch(withNotes(), {kNotes: notesXml('<p:spTree/>')})), isNull);
    });
    test('R6.7 shape thường (không ph) bị bỏ, chỉ lấy body', () {
      final tree = spTree(sp(id: 5, name: 'Other', txBody: txBody(para('X'))) +
          sp(id: 6, name: 'Notes', ph: 'type="body" idx="1"', txBody: txBody(para('Y'))));
      expect(notesOf(patch(withNotes(), {kNotes: notesXml(tree)})), 'Y');
    });
    test('R6.8 chỉ có placeholder sldImg ⇒ null', () {
      final tree = spTree(sp(id: 2, name: 'Img', ph: 'type="sldImg"'));
      expect(notesOf(patch(withNotes(), {kNotes: notesXml(tree)})), isNull);
    });
    test('R6.9 body không có txBody ⇒ null', () {
      final tree = spTree(sp(id: 6, name: 'Notes', ph: 'type="body" idx="1"'));
      expect(notesOf(patch(withNotes(), {kNotes: notesXml(tree)})), isNull);
    });
    test('R6.11 body txBody không có đoạn ⇒ null', () {
      final tree = spTree(sp(id: 6, name: 'Notes', ph: 'type="body" idx="1"', txBody: txBody('')));
      expect(notesOf(patch(withNotes(), {kNotes: notesXml(tree)})), isNull);
    });
    test('R6.12 chỉ khoảng trắng ⇒ null', () {
      expect(notesOf(one('', notes: '   ').build()), isNull);
    });
  });

  // ------------------------------------------------------------ R7 _chain
  group('R7 _chain', () {
    PptxSlide slideOf(String shapes, {String? layoutShapes}) {
      final b = one(shapes);
      if (layoutShapes != null) b.layoutShapes = layoutShapes;
      return readPptx(b.build()).slides.single;
    }
    PptxTextShape only(PptxSlide s) => s.shapes.single as PptxTextShape;
    const masterBody = PptxRect(838200, 1825625, 10515600, 4351338);
    const layoutTitle = PptxRect(1000000, 500000, 10000000, 1000000);
    test('R7.1 body idx=1 ⇒ khớp layout theo idx, khung từ master body', () {
      final s = only(slideOf(sp(name: 'B', ph: 'type="body" idx="1"')));
      expect(s.frame, masterBody);
      expect(s.verticalAnchor, PptxAnchor.top);
    });
    test('R7.2 shape không placeholder, không xfrm ⇒ không kế thừa, bị bỏ', () {
      expect(slideOf(sp(name: 'N')).shapes, isEmpty);
    });
    test('R7.4 ph chỉ có idx (type mặc định obj) ⇒ như R7.1', () {
      expect(only(slideOf(sp(name: 'B', ph: 'idx="1"'))).frame, masterBody);
    });
    test('R7.5 ph title không idx ⇒ khớp layout theo type; master title (anchor ctr)', () {
      final s = only(slideOf(sp(name: 'T', ph: 'type="title"')));
      expect([s.frame, s.verticalAnchor], [layoutTitle, PptxAnchor.middle]);
    });
    test('R7.6 idx không khớp ⇒ khớp theo type', () {
      expect(only(slideOf(sp(name: 'T', ph: 'type="title" idx="9"'))).frame, layoutTitle);
    });
    test('R7.7 ctrTitle idx lạ ⇒ khớp theo nhóm (title)', () {
      expect(only(slideOf(sp(name: 'T', ph: 'type="ctrTitle" idx="9"'))).frame, layoutTitle);
    });
    test('R7.8 ph dt không có ở layout và master ⇒ không kế thừa, bị bỏ', () {
      expect(slideOf(sp(name: 'D', ph: 'type="dt" idx="10"')).shapes, isEmpty);
    });
    test('R7.12 layout có sldNum, master không ⇒ khung từ layout', () {
      final ls = defaultLayoutShapes + sp(id: 4, name: 'SN', ph: 'type="sldNum" idx="12"', spPr: xfrm(1, 2, 3, 4));
      expect(only(slideOf(sp(name: 'N', ph: 'type="sldNum" idx="12"'), layoutShapes: ls)).frame, const PptxRect(1, 2, 3, 4));
    });
  });

  // ------------------------------------------------------------ R9 _fillOf
  group('R9 _fillOf (qua spPr của sp)', () {
    final media = {'rId2': 'img.png'};
    PptxSlide slide(String extra, {String style = '', Map<String, String> m = const {}}) {
      final b = one(box('X', extra: extra, style: style), media: m);
      b.media['img.png'] = kTinyPng;
      return readPptx(b.build()).slides.single;
    }
    PptxFill? f(String extra, {String style = '', Map<String, String> m = const {}}) =>
        (byName(slide(extra, style: style, m: m), 'X') as PptxTextShape).fill;
    test('R9.1 solidFill', () => expect(f(solid('FF0000'))?.colorArgb, 0xFFFF0000));
    test('R9.2 noFill ⇒ null dù có fillRef', () => expect(f('<a:noFill/>', style: styleFill('1')), isNull));
    test('R9.3 solidFill màu hỏng ⇒ null (đã chỉ định), không lấy fillRef', () {
      expect(f('<a:solidFill><a:srgbClr val="ZZ"/></a:solidFill>', style: styleFill('1')), isNull);
    });
    test('R9.4 gradFill ⇒ màu stop đầu', () {
      expect(f('<a:gradFill><a:gsLst><a:gs pos="0"><a:srgbClr val="00FF00"/></a:gs>'
          '<a:gs pos="100000"><a:srgbClr val="0000FF"/></a:gs></a:gsLst></a:gradFill>')?.colorArgb, 0xFF00FF00);
    });
    test('R9.5 gradFill không stop ⇒ null', () => expect(f('<a:gradFill/>', style: styleFill('1')), isNull));
    test('R9.6 pattFill ⇒ màu fgClr', () {
      expect(f('<a:pattFill prst="pct5"><a:fgClr><a:srgbClr val="0000FF"/></a:fgClr>'
          '<a:bgClr><a:srgbClr val="FFFFFF"/></a:bgClr></a:pattFill>')?.colorArgb, 0xFF0000FF);
    });
    test('R9.7 pattFill không fgClr ⇒ null', () => expect(f('<a:pattFill/>', style: styleFill('1')), isNull));
    test('R9.8 grpFill ⇒ fill của group', () {
      final grp = '<p:grpSp><p:nvGrpSpPr><p:cNvPr id="60" name="Grp"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
          '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="100" cy="100"/><a:chOff x="0" y="0"/>'
          '<a:chExt cx="100" cy="100"/></a:xfrm>${solid('00FFFF')}</p:grpSpPr>'
          '${box('Child', extra: '<a:grpFill/>', id: 61)}</p:grpSp>';
      final g = readPptx(one(grp).build()).slides.single.shapes.single as PptxGroupShape;
      expect((g.children.single as PptxTextShape).fill?.colorArgb, 0xFF00FFFF);
    });
    test('R9.9 blipFill ⇒ fill ảnh', () {
      final fill = f('<a:blipFill><a:blip r:embed="rId2"/><a:stretch/></a:blipFill>', m: media);
      expect([fill?.isPicture, fill?.imageExtension], [true, 'png']);
    });
    test('R9.10 blipFill thiếu ảnh ⇒ null', () {
      expect(f('<a:blipFill><a:blip r:embed="rId9"/></a:blipFill>', style: styleFill('1')), isNull);
    });
    test('R9.11 không có phần tử fill ⇒ không chỉ định, dùng fillRef (accent2)', () {
      expect(f('<a:ln w="100"/>', style: styleFill('1'))?.colorArgb, 0xFFED7D31);
    });
  });

  // ------------------------------------------------------------ R10 _refFill
  group('R10 _refFill', () {
    const theme3 = '<a:fillStyleLst><a:solidFill><a:srgbClr val="ABCDEF"/></a:solidFill><a:noFill/>'
        '<a:effectLst/><a:solidFill><a:srgbClr val="ZZ"/></a:solidFill></a:fillStyleLst>';
    String theme() => defaultTheme.replaceFirst(
      '<a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>', theme3);
    int? refFill(String style) {
      final b = one(box('X', style: style))..theme = theme();
      return fillOf(readPptx(b.build()).slides.single, 'X');
    }
    Object? r(String idx, {String clr = '<a:schemeClr val="accent2"/>'}) {
      final v = refFill(styleFill(idx, clr: clr));
      return v == null ? null : v.toRadixString(16).toUpperCase();
    }
    test('R10.1 fillRef idx 1 ⇒ style 1 của theme', () => expect(r('1'), 'FFABCDEF'));
    test('R10.2 fillRef thiếu idx ⇒ không fill', () => expect(refFill(styleNoIdx()), isNull));
    test('R10.3 fillRef idx 0 ⇒ không fill', () => expect(r('0'), isNull));
    test('R10.4 bgRef 1001 ⇒ bgFillStyleLst[0] với phClr = màu ref', () {
      final bg = '<p:bg><p:bgRef idx="1001"><a:srgbClr val="123456"/></p:bgRef></p:bg>';
      final b = one('', bg: bg)..theme = theme();
      expect(readPptx(b.build()).slides.single.background?.colorArgb, 0xFF123456);
    });
    test('R10.6 idx âm ⇒ ngoài danh sách ⇒ màu ref đặc', () => expect(r('-1'), 'FFED7D31'));
    test('R10.7 idx vượt số style ⇒ màu ref đặc', () => expect(r('9'), 'FFED7D31'));
    test('R10.9 style không phải fill (effectLst) ⇒ màu ref đặc', () => expect(r('3'), 'FFED7D31'));
    test('R10.10 style solidFill màu hỏng ⇒ màu ref đặc', () => expect(r('4'), 'FFED7D31'));
    test('R10.11 style noFill ⇒ không fill', () => expect(r('2'), isNull));
    test('R10.12 ngoài danh sách và ref không màu ⇒ null', () => expect(r('9', clr: ''), isNull));
  });

  // ------------------------------------------------------------ R11 _image
  group('R11 _image (qua p:pic)', () {
    PptxShape picOf(String blip, {Map<String, String> m = const {'rId2': 'image1.PNG'},
        Map<String, Uint8List>? files, Uint8List Function(Uint8List)? post}) {
      final b = one(pic(blip), media: m);
      b.media.addAll(files ?? {'image1.PNG': kTinyPng});
      var bytes = b.build();
      if (post != null) bytes = post(bytes);
      return readPptx(bytes).slides.single.shapes.single;
    }
    bool unsupported(PptxShape s) => s is PptxTextShape && s.unsupportedKind != null;
    test('R11.1 ảnh nhúng ⇒ PptxPictureShape, đuôi chữ thường', () {
      final s = picOf('<a:blip r:embed="rId2"/>') as PptxPictureShape;
      expect([s.extension, s.bytes.length], ['png', kTinyPng.length]);
    });
    test('R11.2 không có blip ⇒ khung không hỗ trợ', () => expect(unsupported(picOf('')), isTrue));
    test('R11.3 blip thiếu r:embed ⇒ khung không hỗ trợ', () => expect(unsupported(picOf('<a:blip/>')), isTrue));
    test('R11.4 rId không có ⇒ khung không hỗ trợ', () {
      expect(unsupported(picOf('<a:blip r:embed="rId9"/>')), isTrue);
    });
    test('R11.5 rel External ⇒ khung không hỗ trợ', () {
      final s = picOf('<a:blip r:embed="rId2"/>',
          post: (z) => edit(z, kSlideRels, (x) => x.replaceFirst('Target="../media/image1.PNG"',
              'Target="https://example.com/a.png" TargetMode="External"')));
      expect(unsupported(s), isTrue);
    });
    test('R11.6 file ảnh không có ⇒ khung không hỗ trợ', () {
      expect(unsupported(picOf('<a:blip r:embed="rId2"/>', files: {})), isTrue);
    });
    test('R11.7 file ảnh rỗng ⇒ khung không hỗ trợ', () {
      expect(unsupported(picOf('<a:blip r:embed="rId2"/>', files: {'image1.PNG': Uint8List(0)})), isTrue);
    });
    test("R11.8 tên file không đuôi ⇒ extension ''", () {
      final s = picOf('<a:blip r:embed="rId2"/>', m: {'rId2': 'image1'}, files: {'image1': kTinyPng});
      expect((s as PptxPictureShape).extension, '');
    });
  });

  // ------------------------------------------------------------ R12 _graphicFrame
  group('R12 _graphicFrame', () {
    PptxShape g(String? data) => readPptx(one(gframe(data)).build()).slides.single.shapes.single;
    String? kind(String? data) => (g(data) as PptxTextShape).unsupportedKind;
    String gd(String uri, [String inner = '']) => '<a:graphicData uri="$uri">$inner</a:graphicData>';
    test('R12.1 chart (uri .../chart)', () => expect(kind(gd('http://schemas.openxmlformats.org/drawingml/2006/chart')), 'chart'));
    test('R12.2 không có graphic ⇒ graphic', () => expect(kind(null), 'graphic'));
    test('R12.3 có tbl ⇒ bảng', () {
      final tbl = '<a:tbl><a:tblGrid><a:gridCol w="100"/></a:tblGrid><a:tr h="50"><a:tc><a:txBody><a:bodyPr/>'
          '<a:p><a:r><a:t>c</a:t></a:r></a:p></a:txBody></a:tc></a:tr></a:tbl>';
      final t = g(gd('http://schemas.openxmlformats.org/drawingml/2006/table', tbl)) as PptxTableShape;
      expect([t.columnWidthsEmu, t.rows.single.cells.single.paragraphs.single.text], [[100], 'c']);
    });
    test('R12.5 graphicData thiếu uri ⇒ graphic', () => expect(kind('<a:graphicData/>'), 'graphic'));
    test('R12.6 uri chứa chart nhưng không kết thúc /chart (chartex) ⇒ chart', () {
      expect(kind(gd('http://schemas.microsoft.com/office/drawing/2014/chartex')), 'chart');
    });
    test('R12.7 SmartArt ⇒ diagram', () => expect(kind(gd('http://schemas.openxmlformats.org/drawingml/2006/diagram')), 'diagram'));
    test('R12.8 OLE ⇒ ole', () => expect(kind(gd('http://schemas.openxmlformats.org/presentationml/2006/ole')), 'ole'));
    test('R12.9 uri khác ⇒ graphic', () {
      expect(kind(gd('http://schemas.openxmlformats.org/drawingml/2006/lockedCanvas')), 'graphic');
    });
  });

  // ------------------------------------------------------------ R13 _geometry
  group('R13 _geometry', () {
    PptxTextShape shapeWith(String prstGeom) =>
        readPptx(one(box('X', extra: prstGeom)).build()).slides.single.shapes.single as PptxTextShape;
    PptxGeometry geo(String prst) => shapeWith('<a:prstGeom prst="$prst"><a:avLst/></a:prstGeom>').geometry;
    test("R13.1 'rect'", () => expect(geo('rect'), PptxGeometry.rect));
    test('R13.2 prstGeom thiếu prst ⇒ rect', () => expect(shapeWith('<a:prstGeom/>').geometry, PptxGeometry.rect));
    test("R13.3 'roundRect'", () => expect(geo('roundRect'), PptxGeometry.roundRect));
    test("R13.4 'ellipse'", () => expect(geo('ellipse'), PptxGeometry.ellipse));
    test("R13.5 'triangle'", () => expect(geo('triangle'), PptxGeometry.triangle));
    test("R13.6 'rtTriangle'", () => expect(geo('rtTriangle'), PptxGeometry.triangle));
    test("R13.7 'line'", () => expect(geo('line'), PptxGeometry.line));
    test("R13.8 'straightConnector1'", () => expect(geo('straightConnector1'), PptxGeometry.line));
    test("R13.9 'bentConnector3' (chứa Connector) ⇒ line", () => expect(geo('bentConnector3'), PptxGeometry.line));
    test("R13.10 'rightArrow' ⇒ other + giữ tên", () {
      final s = shapeWith('<a:prstGeom prst="rightArrow"/>');
      expect([s.geometry, s.presetGeometry], [PptxGeometry.other, 'rightArrow']);
    });
  });
}
