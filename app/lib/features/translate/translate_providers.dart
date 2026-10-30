import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'translator_engine.dart';

/// Bộ dịch trên máy. Test ghi đè bằng engine giả.
final translatorEngineProvider = Provider<TranslatorEngine>(
  (ref) => MlKitTranslatorEngine(),
);
