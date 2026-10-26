// Provider engine của feature `reader`.
// Agent viết impl thật trong thư mục mình, rồi sửa ĐÚNG MỘT DÒNG: thay
// `throw UnimplementedError(...)` bằng `const MyImpl()` / `MyImpl(...)`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/pdf/pdf_render_engine.dart';
import '../../engines/pdf/pdf_security.dart';
import '../../engines/pdf/pdfx_render_engine.dart';

final pdfRenderEngineProvider = Provider<PdfRenderEngine>(
  (ref) => PdfxRenderEngine(security: ref.watch(pdfSecurityProvider)),
);
