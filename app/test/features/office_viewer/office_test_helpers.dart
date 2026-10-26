import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Dựng file zip OOXML tối giản từ map đường dẫn → nội dung.
Uint8List buildZip(Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, content) {
    final data = utf8.encode(content);
    archive.addFile(ArchiveFile(name, data.length, data));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

const _wNs = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

/// DOCX tối giản chỉ có `word/document.xml` với [bodyXml] trong `<w:body>`.
Uint8List buildDocx(String bodyXml) => buildZip({
  '[Content_Types].xml':
      '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/></Types>',
  'word/document.xml':
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document $_wNs><w:body>$bodyXml</w:body></w:document>',
});

String wPara(String text, {bool bold = false}) =>
    '<w:p><w:r>${bold ? '<w:rPr><w:b/></w:rPr>' : ''}<w:t xml:space="preserve">$text</w:t></w:r></w:p>';

/// XLSX tối giản: một sheet, ô chuỗi inline. [cells]: `A1` → text.
Uint8List buildXlsx(
  Map<String, String> cells, {
  String merges = '',
  String sheetName = 'Data',
}) {
  final byRow = <int, List<MapEntry<String, String>>>{};
  for (final e in cells.entries) {
    final row = int.parse(e.key.replaceAll(RegExp(r'[A-Z]'), ''));
    byRow.putIfAbsent(row, () => []).add(e);
  }
  final rows = StringBuffer();
  for (final r in byRow.keys.toList()..sort()) {
    rows.write('<row r="$r">');
    for (final e in byRow[r]!) {
      rows.write('<c r="${e.key}" t="inlineStr"><is><t>${e.value}</t></is></c>');
    }
    rows.write('</row>');
  }
  return buildZip({
    '[Content_Types].xml':
        '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/></Types>',
    '_rels/.rels':
        '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    'xl/workbook.xml':
        '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="$sheetName" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
    'xl/worksheets/sheet1.xml':
        '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>$rows</sheetData>$merges</worksheet>',
  });
}
