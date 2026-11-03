import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../translate/translate_sheet.dart';
import '../tts/read_aloud_bar.dart';

/// Dựng thanh đọc to cho các đoạn [paragraphs]; [onParagraph] báo đoạn đang đọc;
/// [autoStart] = tự phát ngay khi giọng đọc sẵn sàng. [paragraphs] có thể dài thêm về cuối khi
/// các trang sau dàn xong ([moreComing] = còn đoạn sắp tới: đọc hết phần có thì chờ, không dừng).
typedef ReflowReadAloudBuilder =
    Widget Function(
      List<String> paragraphs,
      ValueChanged<int> onParagraph, {
      bool autoStart,
      bool moreComing,
    });

/// Mở bảng dịch cho các đoạn [paragraphs].
typedef ReflowTranslator =
    Future<void> Function(BuildContext context, List<String> paragraphs);

/// Thanh đọc to của màn dàn chữ — mặc định [ReadAloudBar]; test override để khỏi gọi giọng đọc thật.
final reflowReadAloudBuilderProvider = Provider<ReflowReadAloudBuilder>(
  (ref) => (paragraphs, onParagraph, {autoStart = false, moreComing = false}) =>
      ReadAloudBar(
        paragraphs: paragraphs,
        onParagraph: onParagraph,
        autoStart: autoStart,
        moreComing: moreComing,
      ),
);

/// Bảng dịch của màn dàn chữ — mặc định [showTranslateSheet]; test override để ghi lại đoạn được dịch.
final reflowTranslatorProvider = Provider<ReflowTranslator>(
  (ref) => (context, paragraphs) =>
      showTranslateSheet(context, paragraphs: paragraphs),
);
