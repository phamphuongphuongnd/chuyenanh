// Provider engine của feature `pdf_tools`.
// Agent viết impl thật trong thư mục mình, rồi sửa ĐÚNG MỘT DÒNG: thay
// `throw UnimplementedError(...)` bằng `const MyImpl()` / `MyImpl(...)`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/pdf/pdf_tools_engine.dart';

final pdfToolsEngineProvider = Provider<PdfToolsEngine>(
  (ref) => throw UnimplementedError('PdfToolsEngine: chưa có impl (pdf_tools)'),
);
