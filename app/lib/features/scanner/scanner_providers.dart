// Provider của feature `scanner`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/ocr/ocr_engine.dart';
import 'ocr/ml_kit_ocr_engine.dart';

final ocrEngineProvider = Provider<OcrEngine>((ref) {
  final engine = MlKitOcrEngine();
  ref.onDispose(engine.dispose);
  return engine;
});
