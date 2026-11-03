import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'docx_writer.dart' show cleanXmlText;

// Ghi PresentationML (.pptx) tối thiểu: mỗi slide là MỘT ảnh phủ vừa khít giữa slide
// (dùng cho "PDF → PowerPoint": mỗi trang PDF render thành một slide ảnh), kèm tuỳ chọn các
// hộp chữ trong suốt đặt đúng chỗ chữ trên ảnh để PowerPoint tìm / chọn được chữ.

const _nsA = 'http://schemas.openxmlformats.org/drawingml/2006/main';
const _nsR =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _nsP = 'http://schemas.openxmlformats.org/presentationml/2006/main';
const _nsPkgRel =
    'http://schemas.openxmlformats.org/package/2006/relationships';
const _relBase =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _ctBase = 'application/vnd.openxmlformats-officedocument';
const _ctPml = '$_ctBase.presentationml';

/// 1 pt = 12700 EMU.
const int emuPerPt = 12700;

/// Giới hạn cỡ slide của PowerPoint: 1 inch … 56 inch mỗi cạnh.
const int _minSlideEmu = 914400;
const int _maxSlideEmu = 51206400;

/// Cỡ mặc định khi không có gì để suy ra: 16:9 (10 × 5,625 inch).
const double _defaultWidthPt = 720;
const double _defaultHeightPt = 405;

/// Định dạng ảnh nhúng.
enum PptxImageFormat {
  jpeg('jpg', 'image/jpeg'),
  png('png', 'image/png');

  const PptxImageFormat(this.extension, this.contentType);

  /// Đuôi file trong `ppt/media/` (không dấu chấm).
  final String extension;
  final String contentType;
}

/// Một dòng chữ vô hình đặt trên slide ảnh. Toạ độ theo cùng hệ với cỡ nội dung của
/// [PptxImageSlide] (`widthPt` × `heightPt`, gốc trên-trái): writer tự quy đổi sang slide.
class PptxTextBox {
  const PptxTextBox({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.fontSizePt = 12,
    this.visible = false,
    this.colorRgb,
    this.bold = false,
    this.italic = false,
    this.fontFamily,
  });

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;
  final double fontSizePt;

  /// `false` (mặc định): chữ vô hình (alpha 0%) chỉ để chọn / tìm. `true`: chữ hiển thị,
  /// sửa được trong PowerPoint (dùng khi ảnh nền đã được xoá chữ).
  final bool visible;

  /// Màu chữ 0xRRGGBB khi [visible]; null = đen.
  final int? colorRgb;
  final bool bold;
  final bool italic;

  /// Tên font khi [visible] (vd. 'Noto Sans'); null = để PowerPoint mặc định.
  final String? fontFamily;
}

/// Một slide ảnh: [bytes] là ảnh đã mã hoá ([format]); [widthPt] × [heightPt] là cỡ "tự nhiên"
/// của nội dung (vd. cỡ trang PDF) — chỉ dùng tỉ lệ để đặt ảnh vừa khít giữa slide.
class PptxImageSlide {
  const PptxImageSlide({
    required this.bytes,
    required this.widthPt,
    required this.heightPt,
    this.format = PptxImageFormat.jpeg,
    this.textBoxes = const [],
  });

  /// Hộp chữ trong suốt (chọn / tìm được trong PowerPoint); rỗng = slide chỉ có ảnh.
  final List<PptxTextBox> textBoxes;

  final Uint8List bytes;
  final double widthPt;
  final double heightPt;
  final PptxImageFormat format;
}

/// Ghi [slides] thành gói .pptx tối thiểu nhưng đầy đủ part chuẩn (mở được bằng PowerPoint,
/// Google Slides, Keynote, LibreOffice).
///
/// Cỡ slide = [slideWidthPt] × [slideHeightPt] (mặc định: cỡ của slide đầu). Cỡ ngoài giới hạn
/// của PowerPoint (1–56 inch) được co/giãn giữ tỉ lệ. Ảnh của mỗi slide được thu/phóng giữ tỉ lệ,
/// nằm giữa, nền slide trắng.
///
/// Thuần và đồng bộ; chạy được trong `Isolate.run`. [slides] rỗng → [ArgumentError].
Uint8List writeImagePptx(
  List<PptxImageSlide> slides, {
  double? slideWidthPt,
  double? slideHeightPt,
  String? title,
  String author = 'pdf_layout',
  DateTime? created,
}) {
  if (slides.isEmpty) {
    throw ArgumentError.value(slides, 'slides', 'must not be empty');
  }
  final (cx, cy) = slideSizeEmu(
    slideWidthPt ?? slides.first.widthPt,
    slideHeightPt ?? slides.first.heightPt,
  );

  final parts = <String, String>{
    '[Content_Types].xml': _contentTypes(slides),
    '_rels/.rels': _rootRels(),
    'docProps/core.xml': _core(title, author, created),
    'docProps/app.xml': _app(slides.length),
    'ppt/presentation.xml': _presentation(slides.length, cx, cy),
    'ppt/_rels/presentation.xml.rels': _presentationRels(slides.length),
    'ppt/presProps.xml': _presProps,
    'ppt/viewProps.xml': _viewProps,
    'ppt/tableStyles.xml': _tableStyles,
    'ppt/theme/theme1.xml': _theme,
    'ppt/slideMasters/slideMaster1.xml': _slideMaster,
    'ppt/slideMasters/_rels/slideMaster1.xml.rels': _rels([
      ('rId1', '$_relBase/slideLayout', '../slideLayouts/slideLayout1.xml'),
      ('rId2', '$_relBase/theme', '../theme/theme1.xml'),
    ]),
    'ppt/slideLayouts/slideLayout1.xml': _slideLayout,
    'ppt/slideLayouts/_rels/slideLayout1.xml.rels': _rels([
      ('rId1', '$_relBase/slideMaster', '../slideMasters/slideMaster1.xml'),
    ]),
  };
  for (var i = 0; i < slides.length; i++) {
    final n = i + 1;
    final s = slides[i];
    parts['ppt/slides/slide$n.xml'] = _slide(n, s, cx, cy);
    parts['ppt/slides/_rels/slide$n.xml.rels'] = _rels([
      ('rId1', '$_relBase/slideLayout', '../slideLayouts/slideLayout1.xml'),
      ('rId2', '$_relBase/image', '../media/image$n.${s.format.extension}'),
    ]);
  }

  final archive = Archive();
  parts.forEach((name, xml) {
    archive.addFile(ArchiveFile.bytes(name, utf8.encode(xml)));
  });
  for (var i = 0; i < slides.length; i++) {
    final s = slides[i];
    final name = 'ppt/media/image${i + 1}.${s.format.extension}';
    // Ảnh JPEG/PNG đã nén sẵn: lưu thẳng (store), không nén lại cho đỡ tốn CPU.
    archive.addFile(ArchiveFile.noCompress(name, s.bytes.length, s.bytes));
  }
  return ZipEncoder().encodeBytes(archive);
}

/// Cỡ slide (EMU) từ cỡ point, ép vào giới hạn 1–56 inch của PowerPoint, giữ tỉ lệ khi được.
/// Giá trị không hợp lệ (≤ 0, NaN, vô cực) → 16:9 mặc định.
(int, int) slideSizeEmu(double widthPt, double heightPt) {
  bool ok(double v) => v.isFinite && v > 0;
  final valid = ok(widthPt) && ok(heightPt);
  final wPt = valid ? widthPt : _defaultWidthPt;
  final hPt = valid ? heightPt : _defaultHeightPt;
  // Tính qua tỉ lệ cạnh ngắn/cạnh dài (0–1) và kẹp trước khi round, để cỡ cực trị
  // (1e308, 1e-320…) không tràn thành vô cực/NaN.
  final ratio = math.min(wPt, hPt) / math.max(wPt, hPt);
  // Cạnh dài quá 56 inch thì co lại (vô cực sau khi nhân cũng về 56 inch).
  var longSide = (math.max(wPt, hPt) * emuPerPt)
      .clamp(_minSlideEmu, _maxSlideEmu)
      .toDouble();
  var shortSide = longSide * ratio;
  if (shortSide < _minSlideEmu) {
    longSide = _minSlideEmu / ratio; // ratio = 0 ⇒ vô cực, kẹp ở dưới
    shortSide = _minSlideEmu.toDouble();
  }
  // Tỉ lệ quá dài (> 56:1) thì không giữ được tỉ lệ nữa — ép từng cạnh.
  final l = longSide.clamp(_minSlideEmu, _maxSlideEmu).round();
  final s = shortSide.clamp(_minSlideEmu, _maxSlideEmu).round();
  return wPt >= hPt ? (l, s) : (s, l);
}

/// Khung ảnh (x, y, cx, cy) EMU: ảnh tỉ lệ [wPt]:[hPt] thu/phóng vừa khít giữa slide
/// [slideCx] × [slideCy]. Tỉ lệ không hợp lệ → phủ kín slide.
(int, int, int, int) fitImageEmu(
  double wPt,
  double hPt,
  int slideCx,
  int slideCy,
) {
  if (!(wPt.isFinite && wPt > 0 && hPt.isFinite && hPt > 0)) {
    return (0, 0, slideCx, slideCy);
  }
  // So tỉ lệ thay vì nhân hệ số co/giãn: cỡ cực nhỏ/cực lớn không ra vô cực.
  final fitWidth = wPt / hPt >= slideCx / slideCy;
  final cx = (fitWidth ? slideCx : slideCy * (wPt / hPt)).round().clamp(
    1,
    slideCx,
  );
  final cy = (fitWidth ? slideCx * (hPt / wPt) : slideCy).round().clamp(
    1,
    slideCy,
  );
  return ((slideCx - cx) ~/ 2, (slideCy - cy) ~/ 2, cx, cy);
}

// --- helpers ---------------------------------------------------------------

const _xmlDecl =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

XmlBuilder _newDoc() =>
    XmlBuilder()
      ..processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');

String _build(XmlBuilder b) => b.buildDocument().toXmlString();

void _el(XmlBuilder b, String name, [Map<String, String> attrs = const {}]) =>
    b.element(name, attributes: attrs);

const _pmlNs = {'xmlns:a': _nsA, 'xmlns:r': _nsR, 'xmlns:p': _nsP};

// --- package parts ---------------------------------------------------------

String _contentTypes(List<PptxImageSlide> slides) {
  final b = _newDoc();
  final formats = {for (final s in slides) s.format};
  b.element(
    'Types',
    attributes: {
      'xmlns': 'http://schemas.openxmlformats.org/package/2006/content-types',
    },
    nest: () {
      _el(b, 'Default', {
        'Extension': 'rels',
        'ContentType':
            'application/vnd.openxmlformats-package.relationships+xml',
      });
      _el(b, 'Default', {'Extension': 'xml', 'ContentType': 'application/xml'});
      for (final f in PptxImageFormat.values) {
        if (!formats.contains(f)) continue;
        _el(b, 'Default', {'Extension': f.extension, 'ContentType': f.contentType});
      }
      void override(String part, String type) =>
          _el(b, 'Override', {'PartName': part, 'ContentType': type});
      override('/ppt/presentation.xml', '$_ctPml.presentation.main+xml');
      override('/ppt/presProps.xml', '$_ctPml.presProps+xml');
      override('/ppt/viewProps.xml', '$_ctPml.viewProps+xml');
      override('/ppt/tableStyles.xml', '$_ctPml.tableStyles+xml');
      override('/ppt/theme/theme1.xml', '$_ctBase.theme+xml');
      override(
        '/ppt/slideMasters/slideMaster1.xml',
        '$_ctPml.slideMaster+xml',
      );
      override(
        '/ppt/slideLayouts/slideLayout1.xml',
        '$_ctPml.slideLayout+xml',
      );
      for (var i = 1; i <= slides.length; i++) {
        override('/ppt/slides/slide$i.xml', '$_ctPml.slide+xml');
      }
      override(
        '/docProps/core.xml',
        'application/vnd.openxmlformats-package.core-properties+xml',
      );
      override('/docProps/app.xml', '$_ctBase.extended-properties+xml');
    },
  );
  return _build(b);
}

String _rels(List<(String, String, String)> rels) {
  final b = _newDoc();
  b.element(
    'Relationships',
    attributes: {'xmlns': _nsPkgRel},
    nest: () {
      for (final (id, type, target) in rels) {
        _el(b, 'Relationship', {'Id': id, 'Type': type, 'Target': target});
      }
    },
  );
  return _build(b);
}

String _rootRels() => _rels([
  ('rId1', '$_relBase/officeDocument', 'ppt/presentation.xml'),
  (
    'rId2',
    'http://schemas.openxmlformats.org/package/2006/relationships/'
        'metadata/core-properties',
    'docProps/core.xml',
  ),
  ('rId3', '$_relBase/extended-properties', 'docProps/app.xml'),
]);

/// rId1 = master, rId2…rId(n+1) = slide, sau đó các part phụ.
String _presentationRels(int slideCount) {
  final n = slideCount;
  return _rels([
    ('rId1', '$_relBase/slideMaster', 'slideMasters/slideMaster1.xml'),
    for (var i = 1; i <= n; i++)
      ('rId${i + 1}', '$_relBase/slide', 'slides/slide$i.xml'),
    ('rId${n + 2}', '$_relBase/presProps', 'presProps.xml'),
    ('rId${n + 3}', '$_relBase/viewProps', 'viewProps.xml'),
    ('rId${n + 4}', '$_relBase/theme', 'theme/theme1.xml'),
    ('rId${n + 5}', '$_relBase/tableStyles', 'tableStyles.xml'),
  ]);
}

String _core(String? title, String author, DateTime? created) {
  final at = (created ?? DateTime.now()).toUtc();
  final stamp = '${at.toIso8601String().split('.').first}Z';
  final b = _newDoc();
  b.element(
    'cp:coreProperties',
    attributes: {
      'xmlns:cp':
          'http://schemas.openxmlformats.org/package/2006/metadata/'
          'core-properties',
      'xmlns:dc': 'http://purl.org/dc/elements/1.1/',
      'xmlns:dcterms': 'http://purl.org/dc/terms/',
      'xmlns:dcmitype': 'http://purl.org/dc/dcmitype/',
      'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
    },
    nest: () {
      if (title != null) b.element('dc:title', nest: cleanXmlText(title));
      b.element('dc:creator', nest: cleanXmlText(author));
      b.element('cp:lastModifiedBy', nest: cleanXmlText(author));
      for (final name in ['dcterms:created', 'dcterms:modified']) {
        b.element(
          name,
          attributes: {'xsi:type': 'dcterms:W3CDTF'},
          nest: stamp,
        );
      }
    },
  );
  return _build(b);
}

String _app(int slideCount) {
  final b = _newDoc();
  b.element(
    'Properties',
    attributes: {
      'xmlns':
          'http://schemas.openxmlformats.org/officeDocument/2006/'
          'extended-properties',
      'xmlns:vt':
          'http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes',
    },
    nest: () {
      b.element('Application', nest: 'pdf_layout');
      b.element('Slides', nest: '$slideCount');
    },
  );
  return _build(b);
}

String _presentation(int slideCount, int cx, int cy) {
  final b = _newDoc();
  b.element(
    'p:presentation',
    attributes: {..._pmlNs, 'saveSubsetFonts': '1'},
    nest: () {
      b.element(
        'p:sldMasterIdLst',
        // id của master/layout phải ≥ 2^31 và không trùng nhau.
        nest: () => _el(b, 'p:sldMasterId', {'id': '2147483648', 'r:id': 'rId1'}),
      );
      b.element(
        'p:sldIdLst',
        nest: () {
          for (var i = 0; i < slideCount; i++) {
            // id của slide: 256 … (2^31 − 1).
            _el(b, 'p:sldId', {'id': '${256 + i}', 'r:id': 'rId${i + 2}'});
          }
        },
      );
      _el(b, 'p:sldSz', {'cx': '$cx', 'cy': '$cy'});
      _el(b, 'p:notesSz', {'cx': '6858000', 'cy': '9144000'});
    },
  );
  return _build(b);
}

/// Nhóm gốc `p:spTree` bắt buộc: `nvGrpSpPr` + `grpSpPr`.
void _spTreeRoot(XmlBuilder b) {
  b.element(
    'p:nvGrpSpPr',
    nest: () {
      _el(b, 'p:cNvPr', {'id': '1', 'name': ''});
      _el(b, 'p:cNvGrpSpPr');
      _el(b, 'p:nvPr');
    },
  );
  b.element(
    'p:grpSpPr',
    nest: () => b.element(
      'a:xfrm',
      nest: () {
        _el(b, 'a:off', {'x': '0', 'y': '0'});
        _el(b, 'a:ext', {'cx': '0', 'cy': '0'});
        _el(b, 'a:chOff', {'x': '0', 'y': '0'});
        _el(b, 'a:chExt', {'cx': '0', 'cy': '0'});
      },
    ),
  );
}

String _slide(int n, PptxImageSlide s, int slideCx, int slideCy) {
  final (x, y, cx, cy) = fitImageEmu(s.widthPt, s.heightPt, slideCx, slideCy);
  final b = _newDoc();
  b.element(
    'p:sld',
    attributes: _pmlNs,
    nest: () {
      b.element(
        'p:cSld',
        nest: () => b.element(
          'p:spTree',
          nest: () {
            _spTreeRoot(b);
            b.element(
              'p:pic',
              nest: () {
                b.element(
                  'p:nvPicPr',
                  nest: () {
                    _el(b, 'p:cNvPr', {'id': '2', 'name': 'Page $n'});
                    b.element(
                      'p:cNvPicPr',
                      nest: () => _el(b, 'a:picLocks', {'noChangeAspect': '1'}),
                    );
                    _el(b, 'p:nvPr');
                  },
                );
                b.element(
                  'p:blipFill',
                  nest: () {
                    _el(b, 'a:blip', {'r:embed': 'rId2'});
                    b.element('a:stretch', nest: () => _el(b, 'a:fillRect'));
                  },
                );
                b.element(
                  'p:spPr',
                  nest: () {
                    b.element(
                      'a:xfrm',
                      nest: () {
                        _el(b, 'a:off', {'x': '$x', 'y': '$y'});
                        _el(b, 'a:ext', {'cx': '$cx', 'cy': '$cy'});
                      },
                    );
                    b.element(
                      'a:prstGeom',
                      attributes: {'prst': 'rect'},
                      nest: () => _el(b, 'a:avLst'),
                    );
                  },
                );
              },
            );
            _textBoxes(b, s, x, y, cx, cy);
          },
        ),
      );
      b.element('p:clrMapOvr', nest: () => _el(b, 'a:masterClrMapping'));
    },
  );
  return _build(b);
}

/// Hộp chữ cho từng dòng của [s], đặt lên
/// khung ảnh (x, y, cx, cy). Hộp ẩn: không nền, không viền, chữ `solidFill` + `alpha 0%`
/// (đáng tin hơn `noFill`, không thành "chữ ma" ở LibreOffice / Google Slides); hộp hiển thị
/// ([PptxTextBox.visible]): chữ có màu, sửa được. Dòng rỗng hoặc có toạ độ/cỡ không hợp lệ thì bỏ.
void _textBoxes(XmlBuilder b, PptxImageSlide s, int x, int y, int cx, int cy) {
  if (s.textBoxes.isEmpty) return;
  if (!(s.widthPt.isFinite && s.widthPt > 0 && s.heightPt.isFinite && s.heightPt > 0)) {
    return;
  }
  final sx = cx / s.widthPt; // EMU trên mỗi point nội dung
  final sy = cy / s.heightPt;
  var id = 3; // 1 = nhóm gốc, 2 = ảnh
  for (final t in s.textBoxes) {
    final text = cleanXmlText(t.text.replaceAll(RegExp(r'[\r\n\t]+'), ' ')).trim();
    final vals = [t.left, t.top, t.width, t.height, t.fontSizePt];
    if (text.isEmpty || vals.any((v) => !v.isFinite) || t.width <= 0 || t.height <= 0) {
      continue;
    }
    final bx = (x + t.left * sx).round();
    final by = (y + t.top * sy).round();
    final bw = math.max(1, (t.width * sx).round());
    final bh = math.max(1, (t.height * sy).round());
    // Cỡ chữ theo cỡ slide, đơn vị 1/100 pt (PowerPoint nhận 1–4000 pt).
    final sz = (t.fontSizePt * sx / emuPerPt * 100).round().clamp(100, 400000);
    b.element(
      'p:sp',
      nest: () {
        b.element(
          'p:nvSpPr',
          nest: () {
            _el(b, 'p:cNvPr', {'id': '${id++}', 'name': 'Text'});
            _el(b, 'p:cNvSpPr', {'txBox': '1'});
            _el(b, 'p:nvPr');
          },
        );
        b.element(
          'p:spPr',
          nest: () {
            b.element(
              'a:xfrm',
              nest: () {
                _el(b, 'a:off', {'x': '$bx', 'y': '$by'});
                _el(b, 'a:ext', {'cx': '$bw', 'cy': '$bh'});
              },
            );
            b.element(
              'a:prstGeom',
              attributes: {'prst': 'rect'},
              nest: () => _el(b, 'a:avLst'),
            );
            _el(b, 'a:noFill');
            b.element('a:ln', nest: () => _el(b, 'a:noFill'));
          },
        );
        b.element(
          'p:txBody',
          nest: () {
            b.element(
              'a:bodyPr',
              attributes: {
                'wrap': 'none',
                'lIns': '0',
                'tIns': '0',
                'rIns': '0',
                'bIns': '0',
                'anchor': 'ctr',
              },
              nest: () => _el(b, 'a:noAutofit'),
            );
            _el(b, 'a:lstStyle');
            b.element(
              'a:p',
              nest: () => b.element(
                'a:r',
                nest: () {
                  b.element(
                    'a:rPr',
                    attributes: {
                      'lang': 'en-US',
                      'sz': '$sz',
                      if (t.bold) 'b': '1',
                      if (t.italic) 'i': '1',
                      'dirty': '0',
                    },
                    nest: () {
                      final rgb = t.visible
                          ? (t.colorRgb ?? 0).clamp(0, 0xFFFFFF)
                          : 0;
                      b.element(
                        'a:solidFill',
                        nest: () => b.element(
                          'a:srgbClr',
                          attributes: {
                            'val': rgb.toRadixString(16).padLeft(6, '0').toUpperCase(),
                          },
                          nest: () {
                            if (!t.visible) _el(b, 'a:alpha', {'val': '0'});
                          },
                        ),
                      );
                      final face = t.fontFamily;
                      if (t.visible && face != null && face.isNotEmpty) {
                        _el(b, 'a:latin', {'typeface': face});
                        _el(b, 'a:ea', {'typeface': face});
                        _el(b, 'a:cs', {'typeface': face});
                      }
                    },
                  );
                  b.element('a:t', nest: text);
                },
              ),
            );
          },
        );
      },
    );
  }
}

// --- static parts ----------------------------------------------------------

const _pmlRoot = 'xmlns:a="$_nsA" xmlns:r="$_nsR" xmlns:p="$_nsP"';

const _emptySpTree =
    '<p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/>'
    '</p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/>'
    '<a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr></p:spTree>';

const _presProps = '$_xmlDecl<p:presentationPr $_pmlRoot/>';

const _viewProps =
    '$_xmlDecl<p:viewPr $_pmlRoot><p:normalViewPr><p:restoredLeft sz="15620"/>'
    '<p:restoredTop sz="94660"/></p:normalViewPr><p:gridSpacing cx="76200" cy="76200"/>'
    '</p:viewPr>';

const _tableStyles =
    '$_xmlDecl<a:tblStyleLst xmlns:a="$_nsA" '
    'def="{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"/>';

/// Master: nền trắng, không placeholder, 1 layout.
const _slideMaster =
    '$_xmlDecl<p:sldMaster $_pmlRoot><p:cSld><p:bg><p:bgPr><a:solidFill>'
    '<a:srgbClr val="FFFFFF"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>'
    '$_emptySpTree</p:cSld>'
    '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" '
    'accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" '
    'accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
    '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>'
    '<p:txStyles>'
    '<p:titleStyle><a:lvl1pPr><a:defRPr sz="4400"/></a:lvl1pPr></p:titleStyle>'
    '<p:bodyStyle><a:lvl1pPr><a:defRPr sz="2800"/></a:lvl1pPr></p:bodyStyle>'
    '<p:otherStyle><a:lvl1pPr><a:defRPr sz="1800"/></a:lvl1pPr></p:otherStyle>'
    '</p:txStyles></p:sldMaster>';

/// Layout "Blank".
const _slideLayout =
    '$_xmlDecl<p:sldLayout $_pmlRoot type="blank" preserve="1">'
    '<p:cSld name="Blank">$_emptySpTree</p:cSld>'
    '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>';

const _solidPh = '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>';

String _ln(int w) =>
    '<a:ln w="$w" cap="flat" cmpd="sng" algn="ctr">$_solidPh'
    '<a:prstDash val="solid"/><a:miter lim="800000"/></a:ln>';

/// Theme Office tối giản (đủ 12 màu, 2 font, mỗi danh sách định dạng 3 mục như chuẩn yêu cầu).
final String _theme =
    '$_xmlDecl<a:theme xmlns:a="$_nsA" name="Office Theme"><a:themeElements>'
    '<a:clrScheme name="Office">'
    '<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>'
    '<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>'
    '<a:dk2><a:srgbClr val="44546A"/></a:dk2>'
    '<a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>'
    '<a:accent1><a:srgbClr val="4472C4"/></a:accent1>'
    '<a:accent2><a:srgbClr val="ED7D31"/></a:accent2>'
    '<a:accent3><a:srgbClr val="A5A5A5"/></a:accent3>'
    '<a:accent4><a:srgbClr val="FFC000"/></a:accent4>'
    '<a:accent5><a:srgbClr val="5B9BD5"/></a:accent5>'
    '<a:accent6><a:srgbClr val="70AD47"/></a:accent6>'
    '<a:hlink><a:srgbClr val="0563C1"/></a:hlink>'
    '<a:folHlink><a:srgbClr val="954F72"/></a:folHlink>'
    '</a:clrScheme>'
    '<a:fontScheme name="Office">'
    '<a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/>'
    '<a:cs typeface=""/></a:majorFont>'
    '<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/>'
    '<a:cs typeface=""/></a:minorFont>'
    '</a:fontScheme>'
    '<a:fmtScheme name="Office">'
    '<a:fillStyleLst>$_solidPh$_solidPh$_solidPh</a:fillStyleLst>'
    '<a:lnStyleLst>${_ln(6350)}${_ln(12700)}${_ln(19050)}</a:lnStyleLst>'
    '<a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle>'
    '<a:effectStyle><a:effectLst/></a:effectStyle>'
    '<a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>'
    '<a:bgFillStyleLst>$_solidPh$_solidPh$_solidPh</a:bgFillStyleLst>'
    '</a:fmtScheme></a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/>'
    '</a:theme>';
