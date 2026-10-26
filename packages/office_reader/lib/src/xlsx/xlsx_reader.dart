import 'dart:math' as math;
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../common.dart';
import 'number_format.dart';
import 'xlsx_model.dart';
import 'xlsx_styles.dart';

/// Parses an .xlsx file. Throws [OfficeFormatException] on unreadable input.
XlsxWorkbook readXlsx(Uint8List bytes) =>
    guardFormat('xlsx', () => _XlsxReader(OoxmlPackage(bytes)).read());

/// Column letters (`A`, `AB`) to 0-based index.
int columnIndex(String letters) {
  var n = 0;
  for (final c in letters.toUpperCase().codeUnits) {
    if (c < 0x41 || c > 0x5A) break;
    n = n * 26 + (c - 0x40);
  }
  return n - 1;
}

final _refRe = RegExp(r'^\$?([A-Za-z]{1,3})\$?(\d+)$');

/// `B3` -> (2, 1). Null when not a cell reference.
(int, int)? parseCellRef(String ref) {
  final m = _refRe.firstMatch(ref.trim());
  if (m == null) return null;
  return (int.parse(m.group(2)!) - 1, columnIndex(m.group(1)!));
}

class _XlsxReader {
  final OoxmlPackage pkg;
  _XlsxReader(this.pkg);

  late final List<String> _shared;
  late final XlsxStyles _styles;
  bool _date1904 = false;

  XlsxWorkbook read() {
    var wbPath = 'xl/workbook.xml';
    for (final r in pkg.rels('').values) {
      if (r.type.endsWith('/officeDocument') && pkg.has(r.resolvedPath)) {
        wbPath = r.resolvedPath;
      }
    }
    final wb = pkg.xml(wbPath);
    if (wb == null) {
      throw const OfficeFormatException('Missing xl/workbook.xml');
    }
    final rels = pkg.rels(wbPath);
    final dir = wbPath.contains('/')
        ? wbPath.substring(0, wbPath.lastIndexOf('/'))
        : '';
    String part(String suffix, String fallback) {
      for (final r in rels.values) {
        if (!r.external && r.type.endsWith(suffix)) return r.resolvedPath;
      }
      return OoxmlPackage.resolvePath(dir, fallback);
    }

    _date1904 = ooxmlBool(
      wb.rootElement.child('workbookPr')?.attr('date1904'),
      ifMissing: false,
    );
    _shared = _sharedStrings(
      pkg.xml(part('/sharedStrings', 'sharedStrings.xml')),
    );
    final colors = XlsxColors.parse(
      pkg.xml(part('/theme', 'theme/theme1.xml')),
    );
    _styles = XlsxStyles(pkg.xml(part('/styles', 'styles.xml')), colors);

    final sheets = <XlsxSheet>[];
    final sheetsEl = wb.rootElement.child('sheets');
    for (final s in sheetsEl?.childrenNamed('sheet') ?? const <XmlElement>[]) {
      final name = s.attr('name') ?? 'Sheet${sheets.length + 1}';
      final state = s.attr('state');
      final hidden = state == 'hidden' || state == 'veryHidden';
      final rel = rels[s.attr('id') ?? ''];
      final doc = rel == null || rel.external
          ? null
          : pkg.xml(rel.resolvedPath);
      sheets.add(_sheet(name, hidden, doc));
    }
    return XlsxWorkbook(sheets: sheets, date1904: _date1904);
  }

  static String _richText(XmlElement si) {
    final b = StringBuffer();
    for (final e in si.childElements) {
      if (e.localName == 't') {
        b.write(e.innerText);
      } else if (e.localName == 'r') {
        for (final t in e.childrenNamed('t')) {
          b.write(t.innerText);
        }
      }
      // rPh (phonetic hints) and phoneticPr are skipped.
    }
    return _unescapeX(b.toString());
  }

  /// Decodes `_x000D_`-style escapes used by Excel for control chars.
  static String _unescapeX(String s) {
    if (!s.contains('_x')) return s;
    return s.replaceAllMapped(RegExp(r'_x([0-9A-Fa-f]{4})_'), (m) {
      return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
    });
  }

  List<String> _sharedStrings(XmlDocument? doc) {
    if (doc == null) return const [];
    return [
      for (final si in doc.rootElement.childrenNamed('si')) _richText(si),
    ];
  }

  XlsxSheet _sheet(String name, bool hidden, XmlDocument? doc) {
    if (doc == null) {
      return XlsxSheet(
        name: name,
        maxRow: 0,
        maxCol: 0,
        cells: const {},
        hidden: hidden,
      );
    }
    final root = doc.rootElement;
    final cells = <(int, int), XlsxCell>{};
    final rowHeights = <int, double>{};
    var maxRow = 0, maxCol = 0;

    final data = root.child('sheetData');
    var rowIdx = -1;
    for (final row in data?.childrenNamed('row') ?? const <XmlElement>[]) {
      final r = parseIntOrNull(row.attr('r'));
      rowIdx = r != null ? r - 1 : rowIdx + 1;
      if (ooxmlBool(row.attr('hidden'), ifMissing: false)) {
        rowHeights[rowIdx] = 0;
      } else {
        final ht = parseDoubleOrNull(row.attr('ht'));
        if (ht != null &&
            ooxmlBool(row.attr('customHeight'), ifMissing: true)) {
          rowHeights[rowIdx] = ht;
        }
      }
      final rowStyle = ooxmlBool(row.attr('customFormat'), ifMissing: false)
          ? parseIntOrNull(row.attr('s'))
          : null;
      var colIdx = -1;
      for (final c in row.childrenNamed('c')) {
        final ref = c.attr('r');
        final pos = ref == null ? null : parseCellRef(ref);
        if (pos != null) {
          colIdx = pos.$2;
        } else {
          colIdx++;
        }
        final cell = _cell(c, rowStyle);
        if (cell == null) continue;
        cells[(rowIdx, colIdx)] = cell;
        maxRow = math.max(maxRow, rowIdx + 1);
        maxCol = math.max(maxCol, colIdx + 1);
      }
    }

    final merges = <XlsxRange>[];
    for (final m
        in root.child('mergeCells')?.childrenNamed('mergeCell') ??
            const <XmlElement>[]) {
      final ref = m.attr('ref');
      if (ref == null) continue;
      final parts = ref.split(':');
      final a = parseCellRef(parts[0]);
      final b = parts.length > 1 ? parseCellRef(parts[1]) : a;
      if (a == null || b == null) continue;
      final range = XlsxRange(
        math.min(a.$1, b.$1),
        math.min(a.$2, b.$2),
        math.max(a.$1, b.$1),
        math.max(a.$2, b.$2),
      );
      merges.add(range);
      maxRow = math.max(maxRow, range.lastRow + 1);
      maxCol = math.max(maxCol, range.lastCol + 1);
    }

    final fmt = root.child('sheetFormatPr');
    final defaultColWidth =
        parseDoubleOrNull(fmt?.attr('defaultColWidth')) ??
        ((parseDoubleOrNull(fmt?.attr('baseColWidth')) ?? 8) + 0.43);
    final defaultRowHeight =
        parseDoubleOrNull(fmt?.attr('defaultRowHeight')) ?? 15;

    final colWidths = <int, double>{};
    final colLimit = math.max(maxCol, 1) + 64; // avoid expanding A:XFD
    for (final col
        in root.child('cols')?.childrenNamed('col') ?? const <XmlElement>[]) {
      final min = (parseIntOrNull(col.attr('min')) ?? 1) - 1;
      final max = (parseIntOrNull(col.attr('max')) ?? (min + 1)) - 1;
      final hiddenCol = ooxmlBool(col.attr('hidden'), ifMissing: false);
      final w = parseDoubleOrNull(col.attr('width'));
      if (w == null && !hiddenCol) continue;
      for (var i = min; i <= max && i < colLimit; i++) {
        colWidths[i] = hiddenCol ? 0 : w!;
      }
    }

    var frozenRows = 0, frozenCols = 0;
    final pane = root.child('sheetViews')?.child('sheetView')?.child('pane');
    if (pane != null) {
      final state = pane.attr('state');
      if (state == 'frozen' || state == 'frozenSplit') {
        frozenCols = parseDoubleOrNull(pane.attr('xSplit'))?.round() ?? 0;
        frozenRows = parseDoubleOrNull(pane.attr('ySplit'))?.round() ?? 0;
      }
    }

    return XlsxSheet(
      name: name,
      maxRow: maxRow,
      maxCol: maxCol,
      cells: cells,
      merges: merges,
      columnWidthsChars: colWidths,
      rowHeightsPt: rowHeights,
      defaultColumnWidthChars: defaultColWidth,
      defaultRowHeightPt: defaultRowHeight,
      frozenRows: frozenRows,
      frozenCols: frozenCols,
      hidden: hidden,
    );
  }

  XlsxCell? _cell(XmlElement c, int? rowStyle) {
    final sAttr = parseIntOrNull(c.attr('s'));
    final style = _styles.at(sAttr ?? rowStyle);
    final t = c.attr('t') ?? 'n';
    final fEl = c.child('f');
    final formula = fEl?.innerText;
    final v = c.child('v')?.innerText;

    XlsxCell make(String display, Object? raw, XlsxCellType type) => XlsxCell(
      display: display,
      raw: raw,
      type: type,
      style: style,
      formula: formula,
    );

    switch (t) {
      case 'inlineStr':
        final isEl = c.child('is');
        final s = isEl == null ? (v ?? '') : _richText(isEl);
        return make(formatText(s, style.numberFormat), s, XlsxCellType.string);
      case 's':
        final i = parseIntOrNull(v);
        final s = i != null && i >= 0 && i < _shared.length ? _shared[i] : '';
        return make(formatText(s, style.numberFormat), s, XlsxCellType.string);
      case 'str':
        final s = _unescapeX(v ?? '');
        return make(formatText(s, style.numberFormat), s, XlsxCellType.string);
      case 'b':
        final b =
            v != null && (v.trim() == '1' || v.trim().toLowerCase() == 'true');
        return make(b ? 'TRUE' : 'FALSE', b, XlsxCellType.boolean);
      case 'e':
        return make(v ?? '#N/A', v ?? '#N/A', XlsxCellType.error);
      case 'd':
        final dt = v == null ? null : DateTime.tryParse(v);
        if (dt == null) return make(v ?? '', v, XlsxCellType.string);
        final serial = dateToExcelSerial(dt, date1904: _date1904);
        final code = isDateFormat(style.numberFormat)
            ? style.numberFormat
            : 'yyyy-mm-dd';
        return make(
          formatNumber(serial, code, date1904: _date1904),
          excelSerialToDate(serial, date1904: _date1904),
          XlsxCellType.date,
        );
      default:
        if (v == null || v.trim().isEmpty) {
          if (sAttr == null && formula == null) return null;
          return make('', null, XlsxCellType.blank);
        }
        final n = double.tryParse(v.trim());
        if (n == null) return make(v, v, XlsxCellType.string);
        final display = formatNumber(
          n,
          style.numberFormat,
          date1904: _date1904,
        );
        if (isDateFormat(style.numberFormat) && n >= 0) {
          return make(
            display,
            excelSerialToDate(n, date1904: _date1904),
            XlsxCellType.date,
          );
        }
        return make(display, n, XlsxCellType.number);
    }
  }
}
