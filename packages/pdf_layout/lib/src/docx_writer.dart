import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'blocks.dart';
import 'options.dart';

const _nsW = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const _nsR =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _nsPkgRel =
    'http://schemas.openxmlformats.org/package/2006/relationships';
const _relBase =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _ctBase = 'application/vnd.openxmlformats-officedocument';

/// Writes [blocks] as a minimal WordprocessingML (.docx) package.
///
/// Pure and synchronous; safe to run inside `Isolate.run`.
Uint8List writeDocx(
  List<DocBlock> blocks, {
  DocxWriteOptions options = const DocxWriteOptions(),
}) {
  final numbering = _Numbering.plan(blocks);
  final parts = <String, String>{
    '[Content_Types].xml': _contentTypes(),
    '_rels/.rels': _rootRels(),
    'docProps/core.xml': _core(options),
    'docProps/app.xml': _app(),
    'word/_rels/document.xml.rels': _documentRels(),
    'word/document.xml': _DocumentWriter(options, numbering).write(blocks),
    'word/styles.xml': _styles(options),
    'word/numbering.xml': numbering.toXml(options),
  };
  final archive = Archive();
  parts.forEach((name, xml) {
    archive.addFile(ArchiveFile.bytes(name, utf8.encode(xml)));
  });
  return ZipEncoder().encodeBytes(archive);
}

// --- helpers ---------------------------------------------------------------

/// Removes characters that are not allowed in XML 1.0 (control characters,
/// lone surrogates, U+FFFE/U+FFFF).
String cleanXmlText(String s) {
  final sb = StringBuffer();
  for (final r in s.runes) {
    final ok =
        r == 0x9 ||
        r == 0xA ||
        r == 0xD ||
        (r >= 0x20 && r <= 0xD7FF) ||
        (r >= 0xE000 && r <= 0xFFFD) ||
        (r >= 0x10000 && r <= 0x10FFFF);
    if (ok) sb.writeCharCode(r);
  }
  return sb.toString();
}

XmlBuilder _newDoc() =>
    XmlBuilder()
      ..processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');

String _build(XmlBuilder b) => b.buildDocument().toXmlString();

int _twips(double pt) => (pt * 20).round();

void _el(XmlBuilder b, String name, [Map<String, String> attrs = const {}]) =>
    b.element(name, attributes: attrs);

// --- package parts ---------------------------------------------------------

String _contentTypes() {
  final b = _newDoc();
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
      void override(String part, String type) =>
          _el(b, 'Override', {'PartName': part, 'ContentType': type});
      override(
        '/word/document.xml',
        '$_ctBase.wordprocessingml.document.main+xml',
      );
      override('/word/styles.xml', '$_ctBase.wordprocessingml.styles+xml');
      override(
        '/word/numbering.xml',
        '$_ctBase.wordprocessingml.numbering+xml',
      );
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
  ('rId1', '$_relBase/officeDocument', 'word/document.xml'),
  (
    'rId2',
    'http://schemas.openxmlformats.org/package/2006/relationships/'
        'metadata/core-properties',
    'docProps/core.xml',
  ),
  ('rId3', '$_relBase/extended-properties', 'docProps/app.xml'),
]);

String _documentRels() => _rels([
  ('rId1', '$_relBase/styles', 'styles.xml'),
  ('rId2', '$_relBase/numbering', 'numbering.xml'),
]);

String _core(DocxWriteOptions o) {
  final created = (o.created ?? DateTime.now()).toUtc();
  final stamp = '${created.toIso8601String().split('.').first}Z';
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
      if (o.title != null) {
        b.element('dc:title', nest: cleanXmlText(o.title!));
      }
      b.element('dc:creator', nest: cleanXmlText(o.author));
      b.element('cp:lastModifiedBy', nest: cleanXmlText(o.author));
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

String _app() {
  final b = _newDoc();
  b.element(
    'Properties',
    attributes: {
      'xmlns':
          'http://schemas.openxmlformats.org/officeDocument/2006/'
          'extended-properties',
    },
    nest: () => b.element('Application', nest: 'pdf_layout'),
  );
  return _build(b);
}

// --- styles ----------------------------------------------------------------

String _styles(DocxWriteOptions o) {
  final b = _newDoc();
  final halfPt = (o.fontSizePt * 2).round().toString();
  b.element(
    'w:styles',
    attributes: {'xmlns:w': _nsW},
    nest: () {
      b.element(
        'w:docDefaults',
        nest: () {
          b.element(
            'w:rPrDefault',
            nest: () => b.element(
              'w:rPr',
              nest: () {
                _el(b, 'w:rFonts', {
                  'w:ascii': o.fontFamily,
                  'w:hAnsi': o.fontFamily,
                  'w:eastAsia': o.fallbackFontFamily,
                  'w:cs': o.fallbackFontFamily,
                });
                _el(b, 'w:sz', {'w:val': halfPt});
                _el(b, 'w:szCs', {'w:val': halfPt});
              },
            ),
          );
          b.element(
            'w:pPrDefault',
            nest: () => b.element(
              'w:pPr',
              nest: () => _el(b, 'w:spacing', {
                'w:after': '120',
                'w:line': '264',
                'w:lineRule': 'auto',
              }),
            ),
          );
        },
      );
      b.element(
        'w:style',
        attributes: {
          'w:type': 'paragraph',
          'w:default': '1',
          'w:styleId': 'Normal',
        },
        nest: () {
          _el(b, 'w:name', {'w:val': 'Normal'});
          _el(b, 'w:qFormat');
        },
      );
      const sizes = [32, 28, 24];
      for (var level = 1; level <= 3; level++) {
        b.element(
          'w:style',
          attributes: {'w:type': 'paragraph', 'w:styleId': 'Heading$level'},
          nest: () {
            _el(b, 'w:name', {'w:val': 'heading $level'});
            _el(b, 'w:basedOn', {'w:val': 'Normal'});
            _el(b, 'w:next', {'w:val': 'Normal'});
            _el(b, 'w:uiPriority', {'w:val': '9'});
            _el(b, 'w:qFormat');
            b.element(
              'w:pPr',
              nest: () {
                _el(b, 'w:keepNext');
                _el(b, 'w:keepLines');
                _el(b, 'w:spacing', {'w:before': '240', 'w:after': '120'});
                _el(b, 'w:outlineLvl', {'w:val': '${level - 1}'});
              },
            );
            b.element(
              'w:rPr',
              nest: () {
                _el(b, 'w:b');
                _el(b, 'w:bCs');
                _el(b, 'w:sz', {'w:val': '${sizes[level - 1]}'});
                _el(b, 'w:szCs', {'w:val': '${sizes[level - 1]}'});
              },
            );
          },
        );
      }
      b.element(
        'w:style',
        attributes: {'w:type': 'paragraph', 'w:styleId': 'ListParagraph'},
        nest: () {
          _el(b, 'w:name', {'w:val': 'List Paragraph'});
          _el(b, 'w:basedOn', {'w:val': 'Normal'});
          _el(b, 'w:uiPriority', {'w:val': '34'});
          _el(b, 'w:qFormat');
          b.element(
            'w:pPr',
            nest: () {
              _el(b, 'w:ind', {'w:left': '720'});
              _el(b, 'w:contextualSpacing');
            },
          );
        },
      );
      b.element(
        'w:style',
        attributes: {'w:type': 'table', 'w:styleId': 'TableGrid'},
        nest: () {
          _el(b, 'w:name', {'w:val': 'Table Grid'});
          _el(b, 'w:uiPriority', {'w:val': '39'});
          b.element('w:pPr', nest: () => _el(b, 'w:spacing', {'w:after': '0'}));
          b.element('w:tblPr', nest: () => _borders(b, 'w:tblBorders'));
        },
      );
    },
  );
  return _build(b);
}

void _borders(XmlBuilder b, String name) {
  b.element(
    name,
    nest: () {
      for (final side in [
        'top',
        'left',
        'bottom',
        'right',
        'insideH',
        'insideV',
      ]) {
        _el(b, 'w:$side', {
          'w:val': 'single',
          'w:sz': '4',
          'w:space': '0',
          'w:color': 'auto',
        });
      }
    },
  );
}

// --- numbering -------------------------------------------------------------

class _ListFormat {
  final String numFmt; // bullet, decimal, lowerLetter, upperLetter
  final String lvlText;
  const _ListFormat(this.numFmt, this.lvlText);
  String get key => '$numFmt|$lvlText';
}

class _Num {
  final int numId;
  final int abstractId;
  final int? start;
  _Num(this.numId, this.abstractId, this.start);
}

class _Numbering {
  final List<_ListFormat> formats = [];
  final List<_Num> nums = [];
  final Map<DocListItem, int> numIdOf = Map.identity();

  _Numbering();

  int _abstractFor(_ListFormat f) {
    final i = formats.indexWhere((e) => e.key == f.key);
    if (i >= 0) return i;
    formats.add(f);
    return formats.length - 1;
  }

  static (_ListFormat, int?) _parse(DocListItem item) {
    final m = item.marker.trim();
    if (item.ordered) {
      final d = RegExp(r'^(\d+)([.)])$').firstMatch(m);
      if (d != null) {
        return (_ListFormat('decimal', '%1${d[2]}'), int.parse(d[1]!));
      }
      final lower = RegExp(r'^([a-z])([.)])$').firstMatch(m);
      if (lower != null) {
        return (
          _ListFormat('lowerLetter', '%1${lower[2]}'),
          lower[1]!.codeUnitAt(0) - 0x60,
        );
      }
      final upper = RegExp(r'^([A-Z])([.)])$').firstMatch(m);
      if (upper != null) {
        return (
          _ListFormat('upperLetter', '%1${upper[2]}'),
          upper[1]!.codeUnitAt(0) - 0x40,
        );
      }
      return (const _ListFormat('decimal', '%1.'), 1);
    }
    final bullet = m.isEmpty ? '•' : String.fromCharCode(m.runes.first);
    return (_ListFormat('bullet', bullet), null);
  }

  factory _Numbering.plan(List<DocBlock> blocks) {
    final n = _Numbering();
    // Always define the default bullet so the part is never empty.
    final defaultBullet = n._abstractFor(const _ListFormat('bullet', '•'));
    n.nums.add(_Num(1, defaultBullet, null));
    final bulletNum = <int, int>{defaultBullet: 1};
    String? runKey;
    var runNum = 0;
    for (final block in blocks) {
      if (block is! DocListItem) {
        runKey = null;
        continue;
      }
      final (format, start) = _parse(block);
      final abs = n._abstractFor(format);
      if (!block.ordered) {
        n.numIdOf[block] = bulletNum.putIfAbsent(abs, () {
          n.nums.add(_Num(n.nums.length + 1, abs, null));
          return n.nums.length;
        });
        runKey = null;
        continue;
      }
      if (runKey != format.key) {
        n.nums.add(_Num(n.nums.length + 1, abs, start ?? 1));
        runNum = n.nums.length;
        runKey = format.key;
      }
      n.numIdOf[block] = runNum;
    }
    return n;
  }

  String toXml(DocxWriteOptions o) {
    final b = _newDoc();
    b.element(
      'w:numbering',
      attributes: {'xmlns:w': _nsW},
      nest: () {
        for (var i = 0; i < formats.length; i++) {
          final f = formats[i];
          b.element(
            'w:abstractNum',
            attributes: {'w:abstractNumId': '$i'},
            nest: () {
              _el(b, 'w:multiLevelType', {'w:val': 'singleLevel'});
              b.element(
                'w:lvl',
                attributes: {'w:ilvl': '0'},
                nest: () {
                  _el(b, 'w:start', {'w:val': '1'});
                  _el(b, 'w:numFmt', {'w:val': f.numFmt});
                  _el(b, 'w:lvlText', {'w:val': cleanXmlText(f.lvlText)});
                  _el(b, 'w:lvlJc', {'w:val': 'left'});
                  b.element(
                    'w:pPr',
                    nest: () =>
                        _el(b, 'w:ind', {'w:left': '720', 'w:hanging': '360'}),
                  );
                  if (f.numFmt == 'bullet') {
                    b.element(
                      'w:rPr',
                      nest: () => _el(b, 'w:rFonts', {
                        'w:ascii': o.fontFamily,
                        'w:hAnsi': o.fontFamily,
                        'w:hint': 'default',
                      }),
                    );
                  }
                },
              );
            },
          );
        }
        for (final num in nums) {
          b.element(
            'w:num',
            attributes: {'w:numId': '${num.numId}'},
            nest: () {
              _el(b, 'w:abstractNumId', {'w:val': '${num.abstractId}'});
              if (num.start != null) {
                b.element(
                  'w:lvlOverride',
                  attributes: {'w:ilvl': '0'},
                  nest: () =>
                      _el(b, 'w:startOverride', {'w:val': '${num.start}'}),
                );
              }
            },
          );
        }
      },
    );
    return _build(b);
  }
}

// --- document --------------------------------------------------------------

class _DocumentWriter {
  final DocxWriteOptions o;
  final _Numbering numbering;
  final XmlBuilder b = _newDoc();

  _DocumentWriter(this.o, this.numbering);

  int get _textWidth => _twips(o.pageWidthPt - 2 * o.marginPt);

  String write(List<DocBlock> blocks) {
    b.element(
      'w:document',
      attributes: {'xmlns:w': _nsW, 'xmlns:r': _nsR},
      nest: () {
        b.element(
          'w:body',
          nest: () {
            for (final block in blocks) {
              _block(block);
            }
            if (blocks.isEmpty || blocks.last is DocTable) {
              b.element('w:p');
            }
            _sectPr();
          },
        );
      },
    );
    return _build(b);
  }

  void _block(DocBlock block) {
    switch (block) {
      case DocHeading h:
        _paragraph(h.spans, style: 'Heading${h.level.clamp(1, 3)}');
      case DocParagraph p:
        _paragraph(
          p.spans,
          align: p.align,
          indentPt: p.indentPt,
          firstLinePt: p.firstLineIndentPt,
        );
      case DocListItem l:
        _paragraph(
          l.spans,
          style: 'ListParagraph',
          numId: numbering.numIdOf[l] ?? 1,
        );
      case DocTable t:
        _table(t);
      case DocPageBreak _:
        b.element(
          'w:p',
          nest: () =>
              b.element('w:r', nest: () => _el(b, 'w:br', {'w:type': 'page'})),
        );
    }
  }

  void _paragraph(
    List<DocSpan> spans, {
    String? style,
    int? numId,
    DocAlign align = DocAlign.left,
    double indentPt = 0,
    double firstLinePt = 0,
  }) {
    final left = _twips(indentPt);
    final first = _twips(firstLinePt);
    final jc = switch (align) {
      DocAlign.left => null,
      DocAlign.center => 'center',
      DocAlign.right => 'right',
      DocAlign.justify => 'both',
    };
    b.element(
      'w:p',
      nest: () {
        if (style != null ||
            numId != null ||
            left != 0 ||
            first != 0 ||
            jc != null) {
          b.element(
            'w:pPr',
            nest: () {
              if (style != null) _el(b, 'w:pStyle', {'w:val': style});
              if (numId != null) {
                b.element(
                  'w:numPr',
                  nest: () {
                    _el(b, 'w:ilvl', {'w:val': '0'});
                    _el(b, 'w:numId', {'w:val': '$numId'});
                  },
                );
              }
              if (left != 0 || first != 0) {
                _el(b, 'w:ind', {
                  'w:left': '$left',
                  if (first > 0) 'w:firstLine': '$first',
                  if (first < 0) 'w:hanging': '${-first}',
                });
              }
              if (jc != null) _el(b, 'w:jc', {'w:val': jc});
            },
          );
        }
        for (final s in spans) {
          _run(s);
        }
      },
    );
  }

  void _run(DocSpan span) {
    final text = cleanXmlText(span.text);
    if (text.isEmpty) return;
    b.element(
      'w:r',
      nest: () {
        final size = span.fontSizePt;
        if (span.bold || size != null) {
          b.element(
            'w:rPr',
            nest: () {
              if (span.bold) {
                _el(b, 'w:b');
                _el(b, 'w:bCs');
              }
              if (size != null && size > 0) {
                final hp = '${(size * 2).round()}';
                _el(b, 'w:sz', {'w:val': hp});
                _el(b, 'w:szCs', {'w:val': hp});
              }
            },
          );
        }
        final buf = StringBuffer();
        void flushText() {
          if (buf.isEmpty) return;
          b.element(
            'w:t',
            attributes: {'xml:space': 'preserve'},
            nest: buf.toString(),
          );
          buf.clear();
        }

        for (final ch in text.split('')) {
          if (ch == '\t') {
            flushText();
            _el(b, 'w:tab');
          } else if (ch == '\n') {
            flushText();
            _el(b, 'w:br');
          } else if (ch != '\r') {
            buf.write(ch);
          }
        }
        flushText();
      },
    );
  }

  void _table(DocTable t) {
    final cols = t.columnCount;
    if (cols == 0) return;
    final colW = _textWidth ~/ cols;
    b.element(
      'w:tbl',
      nest: () {
        b.element(
          'w:tblPr',
          nest: () {
            _el(b, 'w:tblStyle', {'w:val': 'TableGrid'});
            _el(b, 'w:tblW', {'w:w': '${colW * cols}', 'w:type': 'dxa'});
            _borders(b, 'w:tblBorders');
            _el(b, 'w:tblLayout', {'w:type': 'fixed'});
          },
        );
        b.element(
          'w:tblGrid',
          nest: () {
            for (var c = 0; c < cols; c++) {
              _el(b, 'w:gridCol', {'w:w': '$colW'});
            }
          },
        );
        for (final row in t.cells) {
          b.element(
            'w:tr',
            nest: () {
              for (var c = 0; c < cols; c++) {
                final text = c < row.length ? row[c] : '';
                b.element(
                  'w:tc',
                  nest: () {
                    b.element(
                      'w:tcPr',
                      nest: () =>
                          _el(b, 'w:tcW', {'w:w': '$colW', 'w:type': 'dxa'}),
                    );
                    _paragraph([DocSpan(text)]);
                  },
                );
              }
            },
          );
        }
      },
    );
  }

  void _sectPr() {
    final m = '${_twips(o.marginPt)}';
    b.element(
      'w:sectPr',
      nest: () {
        _el(b, 'w:pgSz', {
          'w:w': '${_twips(o.pageWidthPt)}',
          'w:h': '${_twips(o.pageHeightPt)}',
          if (o.pageWidthPt > o.pageHeightPt) 'w:orient': 'landscape',
        });
        _el(b, 'w:pgMar', {
          'w:top': m,
          'w:right': m,
          'w:bottom': m,
          'w:left': m,
          'w:header': '720',
          'w:footer': '720',
          'w:gutter': '0',
        });
      },
    );
  }
}
