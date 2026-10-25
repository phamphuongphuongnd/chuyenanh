/// Pure Dart layout reconstruction for text extracted from PDF pages.
///
/// * [rebuildDocument] – headings, paragraphs, lists, tables, page breaks.
/// * [detectSheets] – one grid per page for spreadsheet export.
/// * [writeDocx] – minimal .docx writer for the rebuilt blocks.
///
/// All entry points are synchronous, side-effect free and only take plain
/// data, so they can run inside `Isolate.run`.
library;

export 'src/blocks.dart';
export 'src/docx_writer.dart' show writeDocx;
export 'src/model.dart';
export 'src/options.dart';
export 'src/rebuild.dart' show rebuildDocument;
export 'src/sheets.dart';
