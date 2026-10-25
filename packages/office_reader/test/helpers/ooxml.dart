// Builders for tiny OOXML packages used as test fixtures.
// Everything is generated in memory; no sample files are downloaded.
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// A valid 1x1 transparent PNG.
final Uint8List tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Zips [files] (path -> `String` or `List<int>`) into a package.
Uint8List buildZip(Map<String, Object> files) {
  final archive = Archive();
  files.forEach((name, content) {
    if (content is String) {
      archive.addFile(ArchiveFile.string(name, content));
    } else {
      archive.addFile(ArchiveFile.bytes(name, content as List<int>));
    }
  });
  return ZipEncoder().encodeBytes(archive);
}

const _wNs =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
    'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
    'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
    'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" '
    'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"';

const _relNs =
    'xmlns="http://schemas.openxmlformats.org/package/2006/relationships"';

/// Builds a minimal .docx. [body] is the inner XML of `<w:body>`.
/// [rels] are `<Relationship .../>` elements for document.xml.rels.
Uint8List buildDocx({
  required String body,
  String? styles,
  String? numbering,
  String rels = '',
  Map<String, List<int>> media = const {},
  Map<String, String> extraParts = const {},
}) {
  final files = <String, Object>{
    '[Content_Types].xml':
        '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
    'word/document.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document $_wNs><w:body>$body</w:body></w:document>',
    'word/_rels/document.xml.rels':
        '<?xml version="1.0" encoding="UTF-8"?><Relationships $_relNs>$rels</Relationships>',
  };
  if (styles != null) {
    files['word/styles.xml'] = '<w:styles $_wNs>$styles</w:styles>';
  }
  if (numbering != null) {
    files['word/numbering.xml'] = '<w:numbering $_wNs>$numbering</w:numbering>';
  }
  media.forEach((k, v) => files['word/$k'] = v);
  files.addAll(extraParts);
  return buildZip(files);
}

/// Paragraph with plain runs.
String p(String text, {String pPr = '', String rPr = ''}) =>
    '<w:p><w:pPr>$pPr</w:pPr><w:r><w:rPr>$rPr</w:rPr>'
    '<w:t xml:space="preserve">$text</w:t></w:r></w:p>';

const _sNs =
    'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';

class SheetSpec {
  final String name;
  final String xml; // inner XML of <worksheet>
  final String? state;
  const SheetSpec(this.name, this.xml, {this.state});
}

/// Builds a minimal .xlsx. Sheets are written in reverse file order on
/// purpose so the reader must rely on workbook order + rels.
Uint8List buildXlsx({
  required List<SheetSpec> sheets,
  String? sharedStrings,
  String? styles,
  String workbookPr = '',
}) {
  final sheetEls = StringBuffer();
  final rels = StringBuffer();
  final files = <String, Object>{};
  for (var i = 0; i < sheets.length; i++) {
    final s = sheets[i];
    final fileNo = sheets.length - i; // reversed numbering
    final state = s.state == null ? '' : ' state="${s.state}"';
    sheetEls.write(
      '<sheet name="${s.name}" sheetId="${i + 1}" r:id="rId${i + 10}"$state/>',
    );
    rels.write(
      '<Relationship Id="rId${i + 10}" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet$fileNo.xml"/>',
    );
    files['xl/worksheets/sheet$fileNo.xml'] =
        '<?xml version="1.0" encoding="UTF-8"?><worksheet $_sNs>${s.xml}</worksheet>';
  }
  files['[Content_Types].xml'] =
      '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>';
  files['xl/workbook.xml'] =
      '<?xml version="1.0" encoding="UTF-8"?><workbook $_sNs>$workbookPr<sheets>$sheetEls</sheets></workbook>';
  files['xl/_rels/workbook.xml.rels'] =
      '<?xml version="1.0" encoding="UTF-8"?><Relationships $_relNs>$rels</Relationships>';
  if (sharedStrings != null) {
    files['xl/sharedStrings.xml'] = '<sst $_sNs>$sharedStrings</sst>';
  }
  if (styles != null) {
    files['xl/styles.xml'] = '<styleSheet $_sNs>$styles</styleSheet>';
  }
  return buildZip(files);
}
