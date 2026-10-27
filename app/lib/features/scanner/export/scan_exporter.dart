import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:image_ops/image_ops.dart' as ops;
import 'package:path/path.dart' as p;
import 'package:pdf_layout/pdf_layout.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/file_paths.dart';
import '../../../engines/ocr/ocr_engine.dart';
import '../../../engines/pdf/image_to_pdf_engine.dart';
import '../../convert/engine/font_set.dart';
import '../model/scan_page.dart';
import '../ocr/ocr_blocks.dart';
import 'searchable_pdf.dart';

/// Áp chỉnh sửa lên ảnh, trả bytes đã mã hoá. Mặc định chạy `image_ops` trong isolate.
typedef PageRenderer = Future<Uint8List> Function(
  String path,
  ops.ImageEdit edit,
);

Future<Uint8List> renderPageInIsolate(String path, ops.ImageEdit edit) {
  // Đen trắng: PNG tránh vệt nhiễu của JPEG.
  final format = edit.filter == ops.ImageFilter.blackWhite
      ? ops.OutputFormat.png
      : ops.OutputFormat.auto;
  return Isolate.run(
    () => ops.applyEdit(
      Uint8List.fromList(File(path).readAsBytesSync()),
      edit,
      format: format,
    ),
  );
}

class ScanExportResult {
  const ScanExportResult({
    required this.outputPath,
    required this.pageCount,
    this.hasText = true,
    this.textLayer = false,
  });
  final String outputPath;
  final int pageCount;

  /// false = OCR không nhận ra chữ nào (TXT/DOCX trống).
  final bool hasText;

  /// PDF đã có lớp chữ tìm kiếm được (chỉ khi xuất PDF với `searchable`).
  final bool textLayer;
}

/// Xuất danh sách trang đã quét ra PDF / TXT / DOCX. Không ghi đè file cũ.
class ScanExporter {
  ScanExporter({
    required this.pdfEngine,
    required this.ocrEngine,
    required this.outputDir,
    required this.tempDir,
    PageRenderer? renderer,
    DateTime Function()? now,
    this.fontSource = const AssetFontSource(),
  }) : _render = renderer ?? renderPageInIsolate,
       _now = now ?? DateTime.now;

  final ImageToPdfEngine pdfEngine;
  final OcrEngine ocrEngine;
  final String outputDir;
  final String tempDir;

  /// Nguồn font Noto cho lớp chữ tìm kiếm được.
  final FontSource fontSource;
  final PageRenderer _render;
  final DateTime Function() _now;

  /// Cạnh dài tối đa của ảnh đưa vào OCR (đủ nét cho dấu tiếng Việt, không quá nặng).
  static const ocrLongSide = 2560;

  String defaultBaseName() {
    final t = _now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Scan_${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  /// [searchable] = true: OCR từng trang (hệ chữ [script]) rồi phủ lớp chữ vô hình lên PDF.
  /// OCR / vẽ lớp chữ lỗi (không phải huỷ) thì vẫn xuất PDF ảnh bình thường.
  Future<ScanExportResult> exportPdf(
    List<ScanPage> pages, {
    String? baseName,
    bool searchable = false,
    OcrScript script = OcrScript.latin,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    _requirePages(pages);
    // Chia tiến độ: [ảnh] → [OCR] → [tạo PDF] → [lớp chữ].
    final imgEnd = searchable ? 0.15 : 0.4;
    final ocrEnd = searchable ? 0.6 : imgEnd;
    final pdfEnd = searchable ? 0.9 : 1.0;
    final work = await _makeWorkDir();
    try {
      final paths = <String>[];
      for (var i = 0; i < pages.length; i++) {
        cancelToken?.throwIfCancelled();
        paths.add(await _pathFor(pages[i], work, 'pdf$i', pages[i].toEdit()));
        onProgress?.call(imgEnd * (i + 1) / pages.length);
      }
      List<OcrResult>? ocr;
      if (searchable) {
        try {
          ocr = await _ocrAll(
            pages,
            script,
            onProgress == null
                ? null
                : (v) => onProgress(imgEnd + (ocrEnd - imgEnd) * v),
            cancelToken,
          );
        } on Cancelled {
          rethrow;
        } catch (e) {
          debugPrint('scan_exporter: OCR lỗi ($e), xuất PDF không có lớp chữ');
        }
      }
      await Directory(outputDir).create(recursive: true);
      final out = await uniqueOutputPath(
        outputDir,
        baseName ?? defaultBaseName(),
        'pdf',
      );
      final result = await pdfEngine.createPdf(
        imagePaths: paths,
        outputPath: out,
        onProgress: onProgress == null
            ? null
            : (v) => onProgress(ocrEnd + (pdfEnd - ocrEnd) * v),
        cancelToken: cancelToken,
      );
      try {
        var textLayer = false;
        if (ocr != null) {
          cancelToken?.throwIfCancelled();
          final file = File(result.outputPath);
          final withText = await addInvisibleTextLayer(
            await file.readAsBytes(),
            ocr,
            fontSource,
          );
          if (withText != null) {
            await writeAtomically(result.outputPath, withText);
            textLayer = true;
          }
          onProgress?.call(1);
        }
        return ScanExportResult(
          outputPath: result.outputPath,
          pageCount: result.pageCount,
          textLayer: textLayer,
        );
      } catch (_) {
        // Huỷ/lỗi sau khi PDF đã ghi: không để lại file dở trong thư mục xuất.
        try {
          await File(result.outputPath).delete();
        } on FileSystemException {
          // đã không còn
        }
        rethrow;
      }
    } finally {
      await _cleanup(work);
    }
  }

  Future<ScanExportResult> exportTxt(
    List<ScanPage> pages,
    OcrScript script, {
    String? baseName,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final results = await _ocrAll(pages, script, onProgress, cancelToken);
    final text = ocrPagesToText(results);
    final out = await uniqueOutputPath(
      outputDir,
      baseName ?? defaultBaseName(),
      'txt',
    );
    await writeAtomically(out, utf8.encode(text));
    return ScanExportResult(
      outputPath: out,
      pageCount: pages.length,
      hasText: text.isNotEmpty,
    );
  }

  Future<ScanExportResult> exportDocx(
    List<ScanPage> pages,
    OcrScript script, {
    String? baseName,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final results = await _ocrAll(pages, script, onProgress, cancelToken);
    final blocks = ocrPagesToDocBlocks(results);
    final bytes = await Isolate.run(() => writeDocx(blocks));
    final out = await uniqueOutputPath(
      outputDir,
      baseName ?? defaultBaseName(),
      'docx',
    );
    await writeAtomically(out, bytes);
    return ScanExportResult(
      outputPath: out,
      pageCount: pages.length,
      hasText: ocrPagesToText(results).isNotEmpty,
    );
  }

  Future<List<OcrResult>> _ocrAll(
    List<ScanPage> pages,
    OcrScript script,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  ) async {
    _requirePages(pages);
    final work = await _makeWorkDir();
    try {
      final results = <OcrResult>[];
      for (var i = 0; i < pages.length; i++) {
        cancelToken?.throwIfCancelled();
        final page = pages[i];
        // OCR trên ảnh đã xoay đúng chiều, KHÔNG áp bộ lọc màu (giữ nét dấu).
        final edit = ops.ImageEdit(
          rotationQuarterTurns: page.quarterTurns,
          maxLongSide: ocrLongSide,
        );
        final path = await _pathFor(page, work, 'ocr$i', edit, force: true);
        results.add(await ocrEngine.recognize(path, script));
        onProgress?.call((i + 1) / pages.length);
      }
      return results;
    } finally {
      await _cleanup(work);
    }
  }

  /// Trang chưa chỉnh dùng thẳng file gốc; còn lại render ra file tạm.
  Future<String> _pathFor(
    ScanPage page,
    Directory work,
    String name,
    ops.ImageEdit edit, {
    bool force = false,
  }) async {
    if (!force && page.isUnedited) return page.path;
    final Uint8List bytes;
    try {
      bytes = await _render(page.path, edit);
    } on FormatException {
      throw const CorruptFile('page unreadable');
    }
    final isPng = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50;
    final file = File(p.join(work.path, '$name${isPng ? '.png' : '.jpg'}'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  void _requirePages(List<ScanPage> pages) {
    if (pages.isEmpty) throw const CorruptFile('no pages');
  }

  Future<Directory> _makeWorkDir() async {
    await Directory(tempDir).create(recursive: true);
    return Directory(tempDir).createTemp('scan_');
  }

  Future<void> _cleanup(Directory d) async {
    try {
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }
}
