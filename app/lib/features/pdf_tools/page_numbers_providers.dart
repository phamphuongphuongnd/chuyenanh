// Provider riêng của công cụ Đánh số trang (test thay bằng bản giả).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'engine/page_numbers.dart';

final pageNumbersEngineProvider = Provider<PageNumbersEngine>(
  (ref) => const SyncfusionPageNumbers(),
);
