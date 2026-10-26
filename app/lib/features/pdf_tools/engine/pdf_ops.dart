// Các thao tác PDF chạy TRONG isolate (hàm top-level, tham số/kết quả sendable).
// Không import Flutter widget; chỉ Syncfusion + dart:io.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../../core/errors/app_error.dart';
import '../../../core/utils/file_paths.dart';
import '../../../engines/pdf/pdf_tools_engine.dart';
import 'isolate_job.dart';
import 'page_ranges.dart';
import 'watermark_layout.dart';

/// Mở PDF từ file, đổi lỗi thư viện thành [AppError].
Future<sf.PdfDocument> openPdfFile(String path, {String? password}) async {
  final Uint8List bytes;
  try {
    bytes = await File(path).readAsBytes();
  } on FileSystemException catch (e) {
    throw AppError.from(e) is Unknown ? CorruptFile(e.message) : AppError.from(e);
  }
  return openPdfBytes(bytes, password: password);
}

sf.PdfDocument openPdfBytes(Uint8List bytes, {String? password}) {
  try {
    return sf.PdfDocument(
      inputBytes: bytes,
      password: (password == null || password.isEmpty) ? null : password,
    );
  } on ArgumentError catch (e) {
    if (e.name == 'password' ||
        (e.message?.toString().toLowerCase().contains('password') ?? false)) {
      throw password == null || password.isEmpty
          ? const PasswordRequired()
          : const WrongPassword();
    }
    throw CorruptFile(e.toString());
  } catch (e) {
    throw CorruptFile(e.toString());
  }
}

int _rotationDegrees(sf.PdfPageRotateAngle a) => switch (a) {
  sf.PdfPageRotateAngle.rotateAngle0 => 0,
  sf.PdfPageRotateAngle.rotateAngle90 => 90,
  sf.PdfPageRotateAngle.rotateAngle180 => 180,
  sf.PdfPageRotateAngle.rotateAngle270 => 270,
};

sf.PdfPageRotateAngle _angleFromDegrees(int deg) =>
    switch (((deg % 360) + 360) % 360) {
      90 => sf.PdfPageRotateAngle.rotateAngle90,
      180 => sf.PdfPageRotateAngle.rotateAngle180,
      270 => sf.PdfPageRotateAngle.rotateAngle270,
      _ => sf.PdfPageRotateAngle.rotateAngle0,
    };

/// Chép trang [src] sang [out] bằng template (mất annotation/form/link). Giữ khổ
/// và hướng xoay của trang gốc, cộng thêm [extraRotation] độ.
void copyPage(sf.PdfDocument out, sf.PdfPage src, {int extraRotation = 0}) {
  final size = src.size;
  final section = out.sections!.add();
  final settings = section.pageSettings;
  settings.margins.all = 0;
  // Syncfusion chuẩn hoá kích thước theo orientation → đặt orientation trước khi đặt size,
  // và mọi cài đặt phải xong trước khi thêm trang (sau đó bị bỏ qua).
  settings.orientation = size.width > size.height
      ? sf.PdfPageOrientation.landscape
      : sf.PdfPageOrientation.portrait;
  settings.size = Size(size.width, size.height);
  final total = _rotationDegrees(src.rotation) + extraRotation;
  if (total % 360 != 0) settings.rotate = _angleFromDegrees(total);
  final page = section.pages.add();
  page.graphics.drawPdfTemplate(src.createTemplate(), Offset.zero);
}

Future<void> _save(sf.PdfDocument doc, String path, JobPort port) async {
  final bytes = await doc.save();
  doc.dispose();
  await writeAtomically(path, bytes);
  port.fileWritten(path);
}

// --------------------------------------------------------------------------
// Jobs

Future<Object?> mergeJob(Map<String, Object?> args, JobPort port) async {
  final inputs = (args['inputs'] as List).cast<String>();
  final passwords = (args['passwords'] as Map).cast<String, String>();
  final output = args['output'] as String;
  final docs = <sf.PdfDocument>[];
  final out = sf.PdfDocument();
  try {
    var total = 0;
    for (final path in inputs) {
      final d = await openPdfFile(path, password: passwords[path]);
      docs.add(d);
      total += d.pages.count;
    }
    if (total == 0) throw const CorruptFile('no pages');
    var done = 0;
    for (final d in docs) {
      for (var i = 0; i < d.pages.count; i++) {
        copyPage(out, d.pages[i]);
        port.progress(++done / total * 0.9);
      }
    }
    await _save(out, output, port);
    return output;
  } finally {
    for (final d in docs) {
      d.dispose();
    }
  }
}

Future<Object?> splitJob(Map<String, Object?> args, JobPort port) async {
  final input = args['input'] as String;
  final password = args['password'] as String?;
  final ranges = (args['ranges'] as List).cast<PageRange>();
  final outputs = (args['outputs'] as List).cast<String>();
  final src = await openPdfFile(input, password: password);
  try {
    validateRanges(ranges, src.pages.count);
    for (var i = 0; i < ranges.length; i++) {
      final out = sf.PdfDocument();
      for (var p = ranges[i].start - 1; p < ranges[i].end; p++) {
        copyPage(out, src.pages[p]);
      }
      await _save(out, outputs[i], port);
      port.progress((i + 1) / ranges.length);
    }
    return outputs;
  } finally {
    src.dispose();
  }
}

Future<Object?> organizeJob(Map<String, Object?> args, JobPort port) async {
  final input = args['input'] as String;
  final password = args['password'] as String?;
  final ops = (args['ops'] as List).cast<PageOp>();
  final output = args['output'] as String;
  final src = await openPdfFile(input, password: password);
  try {
    validatePageOps(ops, src.pages.count);
    final out = sf.PdfDocument();
    for (var i = 0; i < ops.length; i++) {
      copyPage(out, src.pages[ops[i].sourceIndex], extraRotation: ops[i].rotation);
      port.progress((i + 1) / ops.length * 0.9);
    }
    await _save(out, output, port);
    return output;
  } finally {
    src.dispose();
  }
}

Future<Object?> watermarkJob(Map<String, Object?> args, JobPort port) async {
  final input = args['input'] as String;
  final password = args['password'] as String?;
  final spec = args['spec'] as WatermarkSpec;
  final fontBytes = args['fontBytes'] as Uint8List?;
  final output = args['output'] as String;
  final doc = await openPdfFile(input, password: password);
  try {
    // Mở có mật khẩu rồi lưu thì file kết quả không còn mật khẩu (như merge).
    doc.security.userPassword = '';
    doc.security.ownerPassword = '';
    final opacity = spec.opacity.clamp(0.0, 1.0);
    sf.PdfFont? font;
    sf.PdfBrush? brush;
    sf.PdfBitmap? bitmap;
    if (spec.text != null) {
      font = makeFont(spec.text!, spec.fontSize, fontBytes);
      brush = sf.PdfSolidBrush(_color(spec.colorArgb));
    } else {
      bitmap = sf.PdfBitmap(spec.imageBytes!);
    }
    final count = doc.pages.count;
    for (var i = 0; i < count; i++) {
      final page = doc.pages[i];
      final size = page.size;
      final g = page.graphics;
      g.save();
      g.setTransparency(opacity);
      double itemW;
      double itemH;
      if (font != null) {
        final m = font.measureString(spec.text!);
        itemW = m.width + 2;
        itemH = m.height;
      } else {
        itemW = size.width * spec.imageScale.clamp(0.05, 1.0);
        itemH = itemW * bitmap!.height / math.max(1, bitmap.width);
      }
      final c = watermarkCenter(
        pageW: size.width,
        pageH: size.height,
        itemW: itemW,
        itemH: itemH,
        angleDeg: spec.angle,
        alignX: spec is PlacedWatermarkSpec ? spec.alignX : 0,
        alignY: spec is PlacedWatermarkSpec ? spec.alignY : 0,
      );
      g.translateTransform(c.dx, c.dy);
      g.rotateTransform(spec.angle);
      final box = Rect.fromLTWH(-itemW / 2, -itemH / 2, itemW, itemH);
      if (font != null) {
        g.drawString(spec.text!, font, brush: brush, bounds: box);
      } else {
        g.drawImage(bitmap!, box);
      }
      g.restore();
      port.progress((i + 1) / count * 0.9);
    }
    await _save(doc, output, port);
    return output;
  } catch (e) {
    doc.dispose();
    rethrow;
  }
}

Future<Object?> blankJob(Map<String, Object?> args, JobPort port) async {
  final spec = args['spec'] as BlankDocSpec;
  final fontBytes = args['fontBytes'] as Uint8List?;
  final output = args['output'] as String;
  if (spec.pageCount < 1 || spec.pageCount > maxBlankPages) {
    throw RangeError.range(spec.pageCount, 1, maxBlankPages, 'pageCount');
  }
  var (w, h) = spec.pageSize.portraitPoints;
  if (spec.landscape) (w, h) = (h, w);
  final doc = sf.PdfDocument();
  try {
    doc.pageSettings.margins.all = 0;
    doc.pageSettings.orientation = w > h
        ? sf.PdfPageOrientation.landscape
        : sf.PdfPageOrientation.portrait;
    doc.pageSettings.size = Size(w, h);
    doc.documentInformation.title = spec.title;
    if (spec.category != null) doc.documentInformation.subject = spec.category!;

    const margin = 36.0;
    final bg = spec.backgroundArgb & 0xFFFFFFFF;
    final paintBg = bg != 0xFFFFFFFF;
    final bgBrush = sf.PdfSolidBrush(_color(bg));
    final linePen = sf.PdfPen(_color(0xFFB0BEC5), width: 0.5);
    final titleFont = spec.title.isEmpty
        ? null
        : makeFont(spec.title, 22, fontBytes, bold: true);
    final titleHeight = titleFont == null ? 0.0 : 44.0;

    for (var i = 0; i < spec.pageCount; i++) {
      final page = doc.pages.add();
      final g = page.graphics;
      if (paintBg) g.drawRectangle(brush: bgBrush, bounds: Rect.fromLTWH(0, 0, w, h));
      final top = margin + (i == 0 ? titleHeight : 0);
      if (i == 0 && titleFont != null) {
        g.drawString(
          spec.title,
          titleFont,
          brush: sf.PdfBrushes.black,
          bounds: Rect.fromLTWH(margin, margin, w - 2 * margin, 30),
        );
      }
      switch (spec.template) {
        case BlankTemplate.blank:
          break;
        case BlankTemplate.lined:
          for (var y = top + 28; y <= h - margin; y += 28) {
            g.drawLine(linePen, Offset(margin, y), Offset(w - margin, y));
          }
        case BlankTemplate.grid:
          const step = 20.0;
          for (var y = top; y <= h - margin + 0.1; y += step) {
            g.drawLine(linePen, Offset(margin, y), Offset(w - margin, y));
          }
          for (var x = margin; x <= w - margin + 0.1; x += step) {
            g.drawLine(linePen, Offset(x, top), Offset(x, h - margin));
          }
      }
      port.progress((i + 1) / spec.pageCount * 0.9);
    }
    await _save(doc, output, port);
    return output;
  } catch (e) {
    doc.dispose();
    rethrow;
  }
}

Future<Object?> pageCountJob(Map<String, Object?> args, JobPort port) async {
  final doc = await openPdfFile(
    args['input'] as String,
    password: args['password'] as String?,
  );
  try {
    return doc.pages.count;
  } finally {
    doc.dispose();
  }
}

// --------------------------------------------------------------------------
// Helpers

sf.PdfColor _color(int argb) =>
    sf.PdfColor((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);

/// `true` nếu [text] chỉ gồm ký tự mà font chuẩn (Latin-1) vẽ được.
bool isLatin1(String text) => text.runes.every((r) => r <= 0xFF);

/// Font vẽ [text]: chữ Latin-1 → Helvetica; ngoài ra cần [fontBytes] (TTF Unicode nhúng).
/// Thiếu font cho chữ ngoài Latin-1 → vẫn dùng Helvetica (ký tự lạ có thể hiện sai).
sf.PdfFont makeFont(
  String text,
  double size,
  Uint8List? fontBytes, {
  bool bold = false,
}) {
  if (!isLatin1(text) && fontBytes != null) {
    return sf.PdfTrueTypeFont(fontBytes, size);
  }
  return sf.PdfStandardFont(
    sf.PdfFontFamily.helvetica,
    size,
    style: bold ? sf.PdfFontStyle.bold : sf.PdfFontStyle.regular,
  );
}
