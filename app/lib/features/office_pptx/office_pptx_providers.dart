// Provider engine của feature `office_pptx`.
// Agent viết impl thật trong thư mục mình, rồi sửa ĐÚNG MỘT DÒNG: thay
// `throw UnimplementedError(...)` bằng `const MyImpl()` / `MyImpl(...)`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/office/pptx_engine.dart';

final pptxEngineProvider = Provider<PptxEngine>(
  (ref) => throw UnimplementedError('PptxEngine: chưa có impl (office_pptx)'),
);
