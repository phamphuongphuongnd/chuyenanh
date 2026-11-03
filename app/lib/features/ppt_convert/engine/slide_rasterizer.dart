// Chụp slide PPTX thành ảnh JPEG bằng chính widget `SlideView` của trình xem (nên PDF trông giống
// hệt màn xem). Slide được dựng tạm trong Overlay, đặt ngoài vùng nhìn thấy, chờ ảnh giải mã
// xong rồi `RenderRepaintBoundary.toImage`.
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:pptx_reader/pptx_reader.dart';

import '../../../core/errors/app_error.dart';
import '../../office_pptx/slide_view.dart';
import 'ppt_to_pdf.dart';

/// Impl [SlideRasterizer] trên một [OverlayState] (thường là overlay gốc của app, để có sẵn
/// Theme / Localizations mà `SlideView` cần).
class OverlaySlideRasterizer implements SlideRasterizer {
  OverlaySlideRasterizer(this.overlay);

  final OverlayState overlay;

  /// Số khung hình chờ tối đa để mọi ảnh trong slide vẽ xong.
  static const int _maxSettleFrames = 6;

  @override
  Future<Uint8List> renderSlide(
    PptxDeck deck,
    PptxSlide slide, {
    required int dpi,
  }) async {
    if (!overlay.mounted) throw const Cancelled();
    final size = pdfPageSizeOf(deck);
    final ratio = slidePixelRatio(dpi);
    final boundaryKey = GlobalKey();
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        // Ngoài mép trái màn hình: vẫn layout + paint (để chụp) nhưng người dùng không thấy.
        left: -size.width - 100,
        top: 0,
        width: size.width,
        height: size.height,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: MediaQuery(
              // Cỡ chữ hệ thống không được làm lệch bố cục slide.
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.noScaling),
              child: RepaintBoundary(
                key: boundaryKey,
                // Overlay gốc nằm ngoài Scaffold: thiếu Material thì chữ số/dấu đầu dòng bị
                // gạch chân vàng (kiểu chữ báo lỗi của Flutter) ngay trong ảnh slide.
                child: Material(
                  type: MaterialType.transparency,
                  child: SlideView(deck: deck, slide: slide, renderScale: ratio),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    final providers = <ImageProvider>[];
    try {
      await _nextFrame();
      final ctx = boundaryKey.currentContext;
      if (ctx == null || !ctx.mounted) throw const Cancelled();

      // Chờ mọi ảnh (ảnh trong slide + ảnh nền) giải mã xong. Dùng đúng ImageProvider của
      // widget `Image` đã dựng → cùng khoá cache với ảnh đang hiển thị.
      void collect(Element e) {
        final w = e.widget;
        if (w is Image) providers.add(w.image);
        e.visitChildElements(collect);
      }

      (ctx as Element).visitChildElements(collect);
      final pending = [
        for (final pvd in providers)
          precacheImage(pvd, ctx, onError: (_, _) {}),
      ];
      if (pending.isNotEmpty) await Future.wait(pending);
      // Ảnh xong → `Image` setState → cần thêm khung hình để vẽ ảnh vào lớp. Slide không có
      // ảnh thì không có gì phải chờ (khung đầu đã layout + paint xong).
      if (!ctx.mounted) throw const Cancelled();
      final boundary = ctx.findRenderObject()! as RenderRepaintBoundary;
      if (providers.isNotEmpty) {
        for (var i = 0; i < _maxSettleFrames; i++) {
          await _nextFrame();
          // Bản release không có `debugNeedsPaint` → 1 khung là đủ.
          if (!_needsPaint(boundary)) break;
        }
      }
      if (!overlay.mounted) throw const Cancelled();

      final image = await boundary.toImage(pixelRatio: ratio);
      try {
        // Lấy điểm ảnh thô (rất nhanh) rồi nén JPEG trong isolate: không chặn luồng giao diện
        // và PDF nhúng thẳng JPEG, khỏi bị Syncfusion giải mã PNG bằng Dart ở bước ghép.
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) throw const CorruptFile('slide encode failed');
        return await _encodeJpeg(data, image.width, image.height);
      } finally {
        image.dispose();
      }
    } finally {
      entry.remove();
      entry.dispose();
      // Ảnh slide độ phân giải cao chỉ dùng một lần: bỏ khỏi cache cho đỡ RAM.
      for (final pvd in providers) {
        // Ảnh của trình xem có thể cùng khoá; nạp lại được nên bỏ qua kết quả.
        pvd.evict().ignore();
      }
    }
  }
}

Future<void> _nextFrame() {
  WidgetsBinding.instance.scheduleFrame();
  return WidgetsBinding.instance.endOfFrame;
}

/// `debugNeedsPaint` chỉ có ở bản debug; bản release coi như đã vẽ xong.
bool _needsPaint(RenderObject r) {
  var needs = false;
  assert(() {
    needs = r.debugNeedsPaint;
    return true;
  }());
  return needs;
}

/// Chất lượng JPEG của ảnh slide (90 giữ chữ nhỏ còn nét ở 150 dpi).
const int kSlideJpegQuality = 90;

/// Bộ nén JPEG của Android (libjpeg-turbo) — xem `ImageCodecChannel.kt`.
const MethodChannel _codecChannel = MethodChannel('com.phuong.pdfoffice/image_codec');

/// Kênh native không có (iOS, test) → nhớ lại để khỏi gọi thử mỗi slide.
bool _nativeCodecMissing = false;

/// Nén điểm ảnh RGBA thành JPEG, nền trong suốt (slide không có nền) trộn lên trắng như lúc hiển
/// thị. Ưu tiên bộ nén của Android; gói `image` Dart thuần chậm hơn nhiều lần trên máy 32-bit
/// (≈ 8 s/slide trên Galaxy A13) nên chỉ là đường dự phòng.
Future<Uint8List> _encodeJpeg(ByteData rgba, int width, int height) async {
  final bytes = rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes);
  if (!_nativeCodecMissing && defaultTargetPlatform == TargetPlatform.android) {
    try {
      final out = await _codecChannel.invokeMethod<Uint8List>('encodeJpeg', {
        'rgba': bytes,
        'width': width,
        'height': height,
        'quality': kSlideJpegQuality,
      });
      if (out != null && out.isNotEmpty) return out;
    } on MissingPluginException {
      _nativeCodecMissing = true;
    } on PlatformException {
      // Thiếu RAM / lỗi nén native: thử lại bằng Dart.
    }
  }
  return _encodeJpegDart(bytes, width, height);
}

Future<Uint8List> _encodeJpegDart(Uint8List rgba, int width, int height) {
  final transfer = TransferableTypedData.fromList([rgba]);
  return Isolate.run(() {
    final raw = transfer.materialize().asUint8List();
    // Trộn lên trắng bằng tay (alpha nhân sẵn: c + 255 − a) — nhanh hơn `compositeImage`.
    final rgb = Uint8List(width * height * 3);
    for (var i = 0, j = 0; j < rgb.length; i += 4, j += 3) {
      final inv = 255 - raw[i + 3];
      rgb[j] = raw[i] + inv;
      rgb[j + 1] = raw[i + 1] + inv;
      rgb[j + 2] = raw[i + 2] + inv;
    }
    final flat = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgb.buffer,
      numChannels: 3,
    );
    return img.encodeJpg(flat, quality: kSlideJpegQuality);
  });
}
