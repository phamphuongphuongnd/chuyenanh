// Dịch vụ của feature `id_card` (quét 2 mặt thẻ lên 1 trang): chọn ảnh thư viện, ghép trang
// trong isolate, xuất PDF / JPG, vẽ hình mờ, dọn file tạm. Test thay bằng bản giả qua
// `ProviderScope(overrides: …)`.
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_ops/image_ops.dart' as ops;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/app_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_paths.dart';
import '../../data/db/app_database.dart';
import '../../engines/pdf/image_to_pdf_engine.dart';
import '../image_to_pdf/image_to_pdf_providers.dart';
import '../image_to_pdf/services/output_registry.dart';

/// Định dạng file xuất.
enum IdCardFormat {
  pdf('pdf'),
  jpg('jpg');

  const IdCardFormat(this.extension);
  final String extension;
}

/// Cỡ thẻ trên trang: đúng cỡ thật (in ra bằng thẻ thật) hoặc phóng to cho dễ đọc.
enum IdCardSize {
  actual(1.0),
  large(1.6);

  const IdCardSize(this.scale);
  final double scale;
}

/// Một mặt thẻ đã có ảnh: đường dẫn + số lần xoay 90° theo chiều kim đồng hồ.
@immutable
class IdCardSide {
  const IdCardSide(this.path, {this.turns = 0});

  final String path;
  final int turns;

  IdCardSide rotated() => IdCardSide(path, turns: (turns + 1) % 4);
}

/// Yêu cầu ghép một trang.
@immutable
class IdCardRequest {
  const IdCardRequest({
    required this.front,
    required this.back,
    this.size = IdCardSize.actual,
    this.watermarkPng,
    this.preview = false,
  });

  final IdCardSide front;
  final IdCardSide back;
  final IdCardSize size;

  /// Lớp hình mờ PNG (có alpha) đã vẽ sẵn; `null` = không có.
  final Uint8List? watermarkPng;

  /// Bản xem trước: canvas nửa độ phân giải (150 dpi) cho nhanh.
  final bool preview;

  ops.IdCardLayout get layout => ops.IdCardLayout(
    pageWidthPx: preview ? 1240 : 2480,
    pageHeightPx: preview ? 1754 : 3508,
    scale: size.scale,
    jpegQuality: preview ? 80 : 92,
    watermarkPng: watermarkPng,
  );
}

/// Tên file mặc định: `IDCard_yyyyMMdd_HHmmss`.
String idCardFileName(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'IDCard_${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}'
      '_${two(t.hour)}${two(t.minute)}${two(t.second)}';
}

// ---------------------------------------------------------------- chọn ảnh thư viện

/// Chọn một ảnh từ thư viện. `null` = người dùng huỷ.
abstract interface class IdCardGalleryPicker {
  Future<String?> pickImage();
}

class ImagePickerIdCardGalleryPicker implements IdCardGalleryPicker {
  const ImagePickerIdCardGalleryPicker();

  @override
  Future<String?> pickImage() async {
    try {
      // Có imageQuality/maxWidth → plugin nén lại thành JPEG (HEIC trên iOS cũng thành JPEG,
      // gói `image` không đọc được HEIC) và ảnh 12–50MP được thu nhỏ trước khi ghép.
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 3000,
        maxHeight: 3000,
        requestFullMetadata: false,
      );
      return x?.path;
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied') throw const PermissionDenied();
      throw AppError.from(e);
    }
  }
}

final idCardGalleryPickerProvider = Provider<IdCardGalleryPicker>(
  (ref) => const ImagePickerIdCardGalleryPicker(),
);

// ---------------------------------------------------------------- ghép trang

/// Ghép hai mặt thành một trang JPEG (bytes).
abstract interface class IdCardComposer {
  /// Ném [CorruptFile] nếu ảnh hỏng / không đọc được.
  Future<Uint8List> compose(IdCardRequest request);
}

/// Đọc file + ghép trong isolate riêng (`Isolate.run`) để không giật giao diện.
class IsolateIdCardComposer implements IdCardComposer {
  const IsolateIdCardComposer();

  @override
  Future<Uint8List> compose(IdCardRequest request) async {
    final frontPath = request.front.path, backPath = request.back.path;
    final frontTurns = request.front.turns, backTurns = request.back.turns;
    final layout = request.layout;
    try {
      return await Isolate.run(
        () => ops.composeIdCard(
          File(frontPath).readAsBytesSync(),
          File(backPath).readAsBytesSync(),
          layout: layout,
          frontTurns: frontTurns,
          backTurns: backTurns,
        ),
      );
    } on FormatException catch (e) {
      throw CorruptFile(e.message);
    } on PathNotFoundException catch (e) {
      throw CorruptFile(e.message);
    }
  }
}

final idCardComposerProvider = Provider<IdCardComposer>(
  (ref) => const IsolateIdCardComposer(),
);

// ---------------------------------------------------------------- xuất file

/// Ghi trang đã ghép ra file kết quả.
abstract interface class IdCardExporter {
  /// [page] là JPEG trang A4. Trả về đường dẫn file đã tạo (không trùng file cũ).
  Future<String> export({
    required Uint8List page,
    required IdCardFormat format,
    required String outputDir,
    required String baseName,
  });
}

class DefaultIdCardExporter implements IdCardExporter {
  const DefaultIdCardExporter(this._pdfEngine, this._tempDir);

  final ImageToPdfEngine _pdfEngine;
  final Future<Directory> Function() _tempDir;

  @override
  Future<String> export({
    required Uint8List page,
    required IdCardFormat format,
    required String outputDir,
    required String baseName,
  }) async {
    final out = await uniqueOutputPath(outputDir, baseName, format.extension);
    if (format == IdCardFormat.jpg) {
      await writeAtomically(out, page);
      return out;
    }
    // PDF: một trang A4 dọc, lề 0 → ảnh (cùng tỉ lệ A4) phủ kín trang.
    final dir = await _tempDir();
    final tmp = File(
      p.join(dir.path, 'page_${DateTime.now().microsecondsSinceEpoch}.jpg'),
    );
    await tmp.writeAsBytes(page, flush: true);
    try {
      final r = await _pdfEngine.createPdf(
        imagePaths: [tmp.path],
        outputPath: out,
        options: const ImageToPdfOptions(
          pageSize: PageSizeOption.a4,
          orientation: PageOrientation.portrait,
          margin: PageMargin.none,
          jpegQuality: 92,
        ),
      );
      return r.outputPath;
    } finally {
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }
}

/// Thư mục tạm của feature (`<temp>/idcard_work`), đã được tạo.
Future<Directory> idCardWorkDir() async {
  final base = await getTemporaryDirectory();
  return Directory(p.join(base.path, 'idcard_work')).create(recursive: true);
}

final idCardWorkDirProvider = Provider<Future<Directory> Function()>(
  (ref) => idCardWorkDir,
);

final idCardExporterProvider = Provider<IdCardExporter>(
  (ref) => DefaultIdCardExporter(
    ref.watch(imageToPdfEngineProvider),
    ref.watch(idCardWorkDirProvider),
  ),
);

/// Ghi file kết quả vào bảng `documents` / `recents` (hiện ngay ở Trang chủ). Test override.
final idCardRegisterOutputProvider = Provider<Future<void> Function(String)>(
  (ref) =>
      (path) => registerOutputDocument(ref.read(appDatabaseProvider), path),
);

// ---------------------------------------------------------------- dọn file tạm

/// Xoá các ảnh tạm (ảnh quét, ảnh cắt tay, ảnh thư viện plugin chép vào cache) — chỉ xoá file
/// nằm trong thư mục tạm của app, không bao giờ đụng ảnh gốc trong thư viện.
Future<void> deleteIdCardTempFiles(Iterable<String> paths) async {
  final list = paths.toList();
  if (list.isEmpty) return;
  String root;
  try {
    root = p.canonicalize((await getTemporaryDirectory()).path);
  } catch (_) {
    return;
  }
  await deleteFilesUnder(root, list);
}

/// Xoá những file trong [paths] nằm dưới thư mục [root] (hàm tách riêng để test).
Future<int> deleteFilesUnder(String root, Iterable<String> paths) async {
  var removed = 0;
  for (final path in paths) {
    if (!p.isWithin(root, p.canonicalize(path))) continue;
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
        removed++;
      }
    } on FileSystemException {
      // đang dùng / đã mất: bỏ qua
    }
  }
  return removed;
}

/// Hàm dọn file tạm (test override để không gọi `path_provider`).
final idCardTempCleanerProvider =
    Provider<Future<void> Function(Iterable<String> paths)>(
      (ref) => deleteIdCardTempFiles,
    );

// ---------------------------------------------------------------- hình mờ

/// Vẽ lớp hình mờ: chữ [text] xám trong suốt, xoay chéo, lặp vài dòng, nền trong suốt.
/// Trả về PNG cùng tỉ lệ khung thẻ (85.6×54).
typedef IdCardWatermarkRenderer = Future<Uint8List> Function(String text);

Future<Uint8List> renderIdCardWatermark(String text) async {
  const w = 1012.0, h = 638.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontFamily: kUiFontFamily,
        fontSize: 54,
        fontWeight: FontWeight.w700,
        color: Color(0x66505050),
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: w * 1.1);
  canvas.translate(w / 2, h / 2);
  canvas.rotate(-math.atan2(h, w));
  // Ba dòng song song: giữa và hai bên, để chữ phủ cả thẻ.
  for (final dy in [-h * 0.42, 0.0, h * 0.42]) {
    painter.paint(canvas, Offset(-painter.width / 2, dy - painter.height / 2));
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(w.toInt(), h.toInt());
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw const CorruptFile('watermark');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
    painter.dispose();
  }
}

final idCardWatermarkRendererProvider = Provider<IdCardWatermarkRenderer>(
  (ref) => renderIdCardWatermark,
);
