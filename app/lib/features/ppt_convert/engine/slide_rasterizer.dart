// Chụp slide PPTX thành PNG bằng chính widget `SlideView` của trình xem (nên PDF trông giống
// hệt màn xem). Slide được dựng tạm trong Overlay, đặt ngoài vùng nhìn thấy, chờ ảnh giải mã
// xong rồi `RenderRepaintBoundary.toImage`.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
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
                child: SlideView(deck: deck, slide: slide, renderScale: ratio),
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
      // Ảnh xong → `Image` setState → cần thêm khung hình để vẽ ảnh vào lớp.
      if (!ctx.mounted) throw const Cancelled();
      final boundary = ctx.findRenderObject()! as RenderRepaintBoundary;
      for (var i = 0; i < _maxSettleFrames; i++) {
        await _nextFrame();
        if (i >= 1 && !_needsPaint(boundary)) break;
      }
      if (!overlay.mounted) throw const Cancelled();

      final image = await boundary.toImage(pixelRatio: ratio);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw const CorruptFile('slide encode failed');
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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
