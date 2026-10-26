// Provider engine của feature `convert`.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../engines/convert/convert_engine.dart';
import '../../engines/ocr/ocr_engine.dart';
import '../reader/reader_providers.dart' show pdfRenderEngineProvider;
import '../scanner/scanner_providers.dart' show ocrEngineProvider;
import 'engine/ocr_pdf_convert_engine.dart';
import 'engine/pdf_convert_engine.dart';

/// Hệ chữ OCR cho PDF quét ảnh → TXT/DOCX/XLSX. Màn chuyển đổi đặt giá trị này
/// (mặc định theo ngôn ngữ app) ngay trước khi chuyển.
final convertOcrScriptProvider =
    NotifierProvider<ConvertOcrScript, OcrScript>(ConvertOcrScript.new);

class ConvertOcrScript extends Notifier<OcrScript> {
  @override
  OcrScript build() => OcrScript.latin;

  void set(OcrScript script) => state = script;
}

final convertEngineProvider = Provider<ConvertEngine>(
  (ref) => OcrPdfConvertEngine(
    inner: const PdfConvertEngine(),
    render: ref.watch(pdfRenderEngineProvider),
    ocr: ref.watch(ocrEngineProvider),
    scriptProvider: () => ref.read(convertOcrScriptProvider),
    tempDir: p.join(Directory.systemTemp.path, 'pdf_ocr'),
  ),
);
