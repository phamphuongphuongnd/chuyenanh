import 'dart:io';
import 'dart:typed_data';

import 'package:office_reader/office_reader.dart' as rd;

import '../../../engines/office/docx_engine.dart';
import '../../../engines/office/xlsx_engine.dart';
import 'docx_mapping.dart';
import 'office_io.dart';
import 'xlsx_mapping.dart';

/// `DocxEngine` bọc `packages/office_reader` (parse + map trong isolate).
class OfficeReaderDocxEngine implements DocxEngine {
  const OfficeReaderDocxEngine();

  @override
  Future<DocxDocument> parseFile(String path) =>
      runParsing(() => mapDocx(rd.readDocx(File(path).readAsBytesSync())));

  @override
  Future<DocxDocument> parseBytes(Uint8List bytes) =>
      runParsing(() => mapDocx(rd.readDocx(bytes)));
}

/// `XlsxEngine` bọc `packages/office_reader`.
class OfficeReaderXlsxEngine implements XlsxEngine {
  const OfficeReaderXlsxEngine();

  @override
  Future<XlsxWorkbook> parseFile(String path) =>
      runParsing(() => mapXlsx(rd.readXlsx(File(path).readAsBytesSync())));

  @override
  Future<XlsxWorkbook> parseBytes(Uint8List bytes) =>
      runParsing(() => mapXlsx(rd.readXlsx(bytes)));
}
