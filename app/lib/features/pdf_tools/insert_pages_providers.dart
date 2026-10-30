// Provider engine của công cụ Chèn trang (tách riêng khỏi pdf_tools_providers.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'engine/insert_pages.dart';

final insertPagesEngineProvider = Provider<InsertPagesEngine>(
  (ref) => const SyncfusionInsertPages(),
);
