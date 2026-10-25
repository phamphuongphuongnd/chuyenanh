// Builds minimal but valid OOXML .pptx packages in memory for tests.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const nsA = 'http://schemas.openxmlformats.org/drawingml/2006/main';
const nsR =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const nsP = 'http://schemas.openxmlformats.org/presentationml/2006/main';
const _relBase =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _ns = 'xmlns:a="$nsA" xmlns:r="$nsR" xmlns:p="$nsP"';

/// A 1x1 transparent PNG.
final Uint8List kTinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

// ---------------------------------------------------------------- snippets

String xfrm(int x, int y, int cx, int cy, {String attrs = ''}) =>
    '<a:xfrm$attrs><a:off x="$x" y="$y"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>';

String solid(String hex) =>
    '<a:solidFill><a:srgbClr val="$hex"/></a:solidFill>';

/// A `p:sp`. [ph] is the inner attributes of `p:ph`, e.g. `type="title"`.
String sp({
  int id = 2,
  String name = 'Shape',
  String? ph,
  String spPr = '',
  String? txBody,
  String style = '',
  String cNvPrAttrs = '',
}) {
  final nvPr = ph == null ? '<p:nvPr/>' : '<p:nvPr><p:ph $ph/></p:nvPr>';
  final body = txBody == null ? '' : '<p:txBody>$txBody</p:txBody>';
  return '<p:sp><p:nvSpPr><p:cNvPr id="$id" name="$name"$cNvPrAttrs/>'
      '<p:cNvSpPr/>$nvPr</p:nvSpPr><p:spPr>$spPr</p:spPr>$style$body</p:sp>';
}

/// A `p:txBody` content with given paragraphs (raw `a:p` xml).
String txBody(
  String paragraphs, {
  String bodyPr = '<a:bodyPr/>',
  String lstStyle = '',
}) => '$bodyPr<a:lstStyle>$lstStyle</a:lstStyle>$paragraphs';

String para(String text, {String rPr = '', String pPr = ''}) =>
    '<a:p>$pPr<a:r><a:rPr lang="en-US"$rPr/><a:t>$text</a:t></a:r></a:p>';

String spTree(String shapes) =>
    '<p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/>'
    '</p:nvGrpSpPr><p:grpSpPr/>$shapes</p:spTree>';

// ---------------------------------------------------------------- defaults

const defaultTheme =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme $_ns name="Office Theme"><a:themeElements>
<a:clrScheme name="Office">
<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
<a:dk2><a:srgbClr val="44546A"/></a:dk2>
<a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>
<a:accent1><a:srgbClr val="4472C4"/></a:accent1>
<a:accent2><a:srgbClr val="ED7D31"/></a:accent2>
<a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>
<a:accent4><a:srgbClr val="FFC000"/></a:accent4>
<a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>
<a:accent6><a:srgbClr val="70AD47"/></a:accent6>
<a:hlink><a:srgbClr val="0563C1"/></a:hlink>
<a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
</a:clrScheme>
<a:fontScheme name="Office">
<a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
</a:fontScheme>
<a:fmtScheme name="Office"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>
<a:lnStyleLst><a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
<a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
<a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>
<a:effectStyleLst/><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>
</a:fmtScheme></a:themeElements></a:theme>''';

final defaultMasterShapes =
    sp(
      id: 2,
      name: 'Title Placeholder 1',
      ph: 'type="title"',
      spPr: xfrm(838200, 365125, 10515600, 1325563),
      txBody: txBody(
        '<a:p><a:endParaRPr lang="en-US"/></a:p>',
        bodyPr:
            '<a:bodyPr vert="horz" lIns="91440" tIns="45720" rIns="91440" bIns="45720" anchor="ctr"/>',
      ),
    ) +
    sp(
      id: 3,
      name: 'Text Placeholder 2',
      ph: 'type="body" idx="1"',
      spPr: xfrm(838200, 1825625, 10515600, 4351338),
      txBody: txBody('<a:p><a:endParaRPr lang="en-US"/></a:p>'),
    );

const defaultTxStyles = '''<p:txStyles>
<p:titleStyle><a:lvl1pPr algn="l"><a:buNone/><a:defRPr sz="4400" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mj-lt"/></a:defRPr></a:lvl1pPr></p:titleStyle>
<p:bodyStyle>
<a:lvl1pPr marL="228600" indent="-228600" algn="l"><a:spcBef><a:spcPts val="1000"/></a:spcBef><a:buFont typeface="Arial"/><a:buChar char="&#8226;"/><a:defRPr sz="2800" kern="1200"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/></a:defRPr></a:lvl1pPr>
<a:lvl2pPr marL="685800" indent="-228600" algn="l"><a:buFont typeface="Arial"/><a:buChar char="&#8211;"/><a:defRPr sz="2400"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/></a:defRPr></a:lvl2pPr>
</p:bodyStyle>
<p:otherStyle><a:lvl1pPr algn="l"><a:defRPr sz="1800"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill><a:latin typeface="+mn-lt"/></a:defRPr></a:lvl1pPr></p:otherStyle>
</p:txStyles>''';

const defaultMasterBg =
    '<p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>';

final defaultLayoutShapes =
    sp(
      id: 2,
      name: 'Title 1',
      ph: 'type="title"',
      spPr: xfrm(1000000, 500000, 10000000, 1000000),
    ) +
    sp(id: 3, name: 'Content Placeholder 2', ph: 'idx="1"');

class TestSlide {
  TestSlide(
    this.shapes, {
    this.bg = '',
    this.notes,
    this.media = const {},
    this.sldAttrs = '',
  });

  /// Raw shape xml placed inside `p:spTree`.
  final String shapes;

  /// Raw `p:bg` element or ''.
  final String bg;
  final String? notes;

  /// rId -> media file name (under ppt/media/).
  final Map<String, String> media;
  final String sldAttrs;
}

class PptxBuilder {
  int slideWidth = 12192000;
  int slideHeight = 6858000;
  String theme = defaultTheme;
  String masterShapes = defaultMasterShapes;
  String masterTxStyles = defaultTxStyles;
  String masterBg = defaultMasterBg;
  String layoutShapes = defaultLayoutShapes;
  String layoutBg = '';
  String layoutAttrs = '';
  String defaultTextStyle = '';

  /// Raw `a:tblStyle` elements for ppt/tableStyles.xml ('' = no part).
  String tableStyles = '';

  /// When true, slide part names are reversed relative to presentation order,
  /// so a reader that sorts by file name gets the wrong order.
  bool reverseFileNames = false;

  final List<TestSlide> slides = [];
  final Map<String, Uint8List> media = {};

  Uint8List build() {
    final archive = Archive();
    void add(String name, String content) =>
        archive.addFile(ArchiveFile.bytes(name, utf8.encode(content)));

    final n = slides.length;
    String slideFile(int i) => 'slide${reverseFileNames ? n - i : i + 1}.xml';

    final overrides = StringBuffer()
      ..write(
        '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>',
      );
    for (var i = 0; i < n; i++) {
      overrides.write(
        '<Override PartName="/ppt/slides/${slideFile(i)}" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
      );
    }
    add(
      '[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Default Extension="png" ContentType="image/png"/>$overrides</Types>',
    );
    add(
      '_rels/.rels',
      _rels({'rId1': ('officeDocument', 'ppt/presentation.xml')}),
    );

    // presentation
    final presRels = <String, (String, String)>{
      'rId1': ('slideMaster', 'slideMasters/slideMaster1.xml'),
    };
    final sldIds = StringBuffer();
    for (var i = 0; i < n; i++) {
      final rid = 'rId${i + 10}';
      presRels[rid] = ('slide', 'slides/${slideFile(i)}');
      sldIds.write('<p:sldId id="${256 + i}" r:id="$rid"/>');
    }
    if (tableStyles.isNotEmpty) {
      presRels['rIdTs'] = ('tableStyles', 'tableStyles.xml');
      add(
        'ppt/tableStyles.xml',
        '<?xml version="1.0" encoding="UTF-8"?><a:tblStyleLst xmlns:a="$nsA" def="{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}">$tableStyles</a:tblStyleLst>',
      );
    }
    add('ppt/_rels/presentation.xml.rels', _rels(presRels));
    add(
      'ppt/presentation.xml',
      '<?xml version="1.0" encoding="UTF-8"?><p:presentation $_ns>'
          '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
          '<p:sldIdLst>$sldIds</p:sldIdLst>'
          '<p:sldSz cx="$slideWidth" cy="$slideHeight"/><p:notesSz cx="6858000" cy="9144000"/>'
          '${defaultTextStyle.isEmpty ? '' : '<p:defaultTextStyle>$defaultTextStyle</p:defaultTextStyle>'}'
          '</p:presentation>',
    );

    // master, layout, theme
    add(
      'ppt/slideMasters/slideMaster1.xml',
      '<?xml version="1.0" encoding="UTF-8"?><p:sldMaster $_ns><p:cSld>$masterBg${spTree(masterShapes)}</p:cSld>'
          '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" '
          'accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
          '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>'
          '$masterTxStyles</p:sldMaster>',
    );
    add(
      'ppt/slideMasters/_rels/slideMaster1.xml.rels',
      _rels({
        'rId1': ('slideLayout', '../slideLayouts/slideLayout1.xml'),
        'rId2': ('theme', '../theme/theme1.xml'),
        for (final e in media.keys) 'rIdM_$e': ('image', '../media/$e'),
      }),
    );
    add('ppt/theme/theme1.xml', theme);
    add(
      'ppt/slideLayouts/slideLayout1.xml',
      '<?xml version="1.0" encoding="UTF-8"?><p:sldLayout $_ns$layoutAttrs><p:cSld name="Title and Content">'
          '$layoutBg${spTree(layoutShapes)}</p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>',
    );
    add(
      'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
      _rels({'rId1': ('slideMaster', '../slideMasters/slideMaster1.xml')}),
    );

    // slides
    for (var i = 0; i < n; i++) {
      final s = slides[i];
      final file = slideFile(i);
      final rels = <String, (String, String)>{
        'rId1': ('slideLayout', '../slideLayouts/slideLayout1.xml'),
        for (final e in s.media.entries)
          e.key: ('image', '../media/${e.value}'),
      };
      if (s.notes != null) {
        final notesFile = 'notesSlide${i + 1}.xml';
        rels['rIdN'] = ('notesSlide', '../notesSlides/$notesFile');
        add(
          'ppt/notesSlides/$notesFile',
          '<?xml version="1.0" encoding="UTF-8"?><p:notes $_ns><p:cSld>${spTree(sp(id: 2, name: 'Slide Image', ph: 'type="sldImg"') + sp(id: 3, name: 'Notes', ph: 'type="body" idx="1"', txBody: txBody(s.notes!.split('\n').map((l) => para(l)).join())))}</p:cSld></p:notes>',
        );
      }
      add('ppt/slides/_rels/$file.rels', _rels(rels));
      add(
        'ppt/slides/$file',
        '<?xml version="1.0" encoding="UTF-8"?><p:sld $_ns${s.sldAttrs}><p:cSld>${s.bg}${spTree(s.shapes)}</p:cSld>'
            '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>',
      );
    }
    for (final e in media.entries) {
      archive.addFile(ArchiveFile.bytes('ppt/media/${e.key}', e.value));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  static String _rels(Map<String, (String, String)> rels) {
    final b = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    );
    rels.forEach((id, r) {
      b.write(
        '<Relationship Id="$id" Type="$_relBase/${r.$1}" Target="${r.$2}"/>',
      );
    });
    b.write('</Relationships>');
    return b.toString();
  }
}
