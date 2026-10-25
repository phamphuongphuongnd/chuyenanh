// Provider engine của feature `reader`.
// Agent viết impl thật trong thư mục mình, rồi sửa ĐÚNG MỘT DÒNG: thay
// `throw UnimplementedError(...)` bằng `const MyImpl()` / `MyImpl(...)`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/pdf/pdf_render_engine.dart';

final pdfRenderEngineProvider = Provider<PdfRenderEngine>(
  (ref) => throw UnimplementedError('PdfRenderEngine: chưa có impl (reader)'),
);
