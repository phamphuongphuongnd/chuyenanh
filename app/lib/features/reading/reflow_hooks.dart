import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../translate/translate_sheet.dart';
import '../tts/read_aloud_bar.dart';

/// Dựng thanh đọc to cho các đoạn [paragraphs]; [onParagraph] báo đoạn đang đọc.
typedef ReflowReadAloudBuilder =
    Widget Function(List<String> paragraphs, ValueChanged<int> onParagraph);

/// Mở bảng dịch cho các đoạn [paragraphs].
typedef ReflowTranslator =
    Future<void> Function(BuildContext context, List<String> paragraphs);

/// Thanh đọc to của màn dàn chữ — mặc định [ReadAloudBar]; test override để khỏi gọi giọng đọc thật.
final reflowReadAloudBuilderProvider = Provider<ReflowReadAloudBuilder>(
  (ref) => (paragraphs, onParagraph) =>
      ReadAloudBar(paragraphs: paragraphs, onParagraph: onParagraph),
);

/// Bảng dịch của màn dàn chữ — mặc định [showTranslateSheet]; test override để ghi lại đoạn được dịch.
final reflowTranslatorProvider = Provider<ReflowTranslator>(
  (ref) => (context, paragraphs) =>
      showTranslateSheet(context, paragraphs: paragraphs),
);
