import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../../../core/utils/file_paths.dart';
import '../../../engines/pdf/pdf_tools_engine.dart';
import '../logic/text_fonts.dart';
import '../logic/vi_nfc.dart';
import 'isolate_job.dart';
import 'page_ranges.dart';
import 'pdf_ops.dart';

/// Trả về bytes font TTF Unicode (Noto) để vẽ [text] (chữ ngoài Latin-1); `null` = không có.
typedef PdfFontLoader = FutureOr<Uint8List?> Function(String text);

/// Font Noto theo hệ chữ của [text] nằm ở `assets/fonts/` (chưa có trong repo → trả `null`,
/// rơi về Helvetica; ký tự lạ có thể hiện sai).
Future<Uint8List?> loadBundledFont(String text) async {
  for (final name in fontAssetCandidates(text)) {
    try {
      final data = await rootBundle.load(name);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      // chưa có font → thử tên khác / bỏ qua
    }
  }
  return null;
}

/// [PdfToolsEngine] dùng Syncfusion PDF, mỗi thao tác chạy trong một isolate riêng
/// (huỷ được, báo tiến độ, không chặn UI).
class SyncfusionPdfTools implements PdfToolsEngine {
  const SyncfusionPdfTools({this.fontLoader = loadBundledFont});

  /// Nạp font Unicode khi watermark/tiêu đề có chữ ngoài Latin-1. `null` = không nạp.
  final PdfFontLoader? fontLoader;

  @override
  Future<String> merge(
    List<String> inputPaths,
    String outputPath, {
    Map<String, String> passwords = const {},
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (inputPaths.isEmpty) throw ArgumentError('inputPaths must not be empty');
    _ensureOutputIsNotInput(outputPath, inputPaths);
    final r = await runIsolateJob(
      mergeJob,
      {'inputs': inputPaths, 'passwords': passwords, 'output': outputPath},
      onProgress: onProgress,
      cancelToken: cancelToken,
      plannedOutputs: [outputPath],
    );
    return r! as String;
  }

  @override
  Future<List<String>> split(
    String inputPath,
    SplitMode mode,
    String outputDir,
    String baseName, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    final count = await pageCount(inputPath, password: password);
    final ranges = planSplit(mode, count);
    // Tên không trùng, tính trước ở luồng chính (trùng giữa các khoảng cũng được tránh).
    final outputs = <String>[];
    for (final r in ranges) {
      var path = await uniqueOutputPath(
        outputDir,
        '$baseName (${rangeLabel(r)})',
        'pdf',
      );
      // Hai khoảng trùng nhau (vd. "1-2, 1-2") cùng tên → đánh số tiếp.
      var n = 1;
      while (outputs.contains(path) || File(path).existsSync()) {
        path = p.join(
          outputDir,
          '${sanitizeFileName('$baseName (${rangeLabel(r)})')} ($n).pdf',
        );
        n++;
      }
      outputs.add(path);
    }
    await Directory(outputDir).create(recursive: true);
    final r = await runIsolateJob(
      splitJob,
      {
        'input': inputPath,
        'password': password,
        'ranges': ranges,
        'outputs': outputs,
      },
      onProgress: onProgress,
      cancelToken: cancelToken,
      plannedOutputs: outputs,
    );
    return (r! as List).cast<String>();
  }

  @override
  Future<String> organize(
    String inputPath,
    List<PageOp> pages,
    String outputPath, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (pages.isEmpty) throw ArgumentError('pages must not be empty');
    _ensureOutputIsNotInput(outputPath, [inputPath]);
    final r = await runIsolateJob(
      organizeJob,
      {
        'input': inputPath,
        'password': password,
        'ops': pages,
        'output': outputPath,
      },
      onProgress: onProgress,
      cancelToken: cancelToken,
      plannedOutputs: [outputPath],
    );
    return r! as String;
  }

  @override
  Future<String> watermark(
    String inputPath,
    WatermarkSpec spec,
    String outputPath, {
    String? password,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final text = spec.text;
    if (text == null && spec.imageBytes == null) {
      throw ArgumentError('watermark needs text or image');
    }
    if (text != null && text.trim().isEmpty) {
      throw ArgumentError('watermark text must not be empty');
    }
    _ensureOutputIsNotInput(outputPath, [inputPath]);
    // Chữ Việt NFD → NFC trước khi vẽ; engine nạp font theo chữ đã chuẩn hoá.
    final normalized = text == null ? null : composeVietnamese(text);
    final fontBytes = (normalized != null && !isLatin1(normalized))
        ? await fontLoader?.call(normalized)
        : null;
    final r = await runIsolateJob(
      watermarkJob,
      {
        'input': inputPath,
        'password': password,
        'spec': spec,
        'fontBytes': fontBytes,
        'output': outputPath,
      },
      onProgress: onProgress,
      cancelToken: cancelToken,
      plannedOutputs: [outputPath],
    );
    return r! as String;
  }

  @override
  Future<String> createBlank(
    BlankDocSpec spec,
    String outputPath, {
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final title = composeVietnamese(spec.title);
    final fontBytes = !isLatin1(title) ? await fontLoader?.call(title) : null;
    final r = await runIsolateJob(
      blankJob,
      {'spec': spec, 'fontBytes': fontBytes, 'output': outputPath},
      onProgress: onProgress,
      cancelToken: cancelToken,
      plannedOutputs: [outputPath],
    );
    return r! as String;
  }

  @override
  Future<int> pageCount(String inputPath, {String? password}) async {
    final r = await runIsolateJob(pageCountJob, {
      'input': inputPath,
      'password': password,
    });
    return r! as int;
  }

  /// Không bao giờ ghi đè file gốc.
  void _ensureOutputIsNotInput(String output, List<String> inputs) {
    final out = p.normalize(p.absolute(output));
    for (final i in inputs) {
      if (p.normalize(p.absolute(i)) == out) {
        throw ArgumentError('output must differ from input: $output');
      }
    }
  }
}
