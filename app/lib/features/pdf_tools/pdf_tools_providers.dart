// Provider engine của feature `pdf_tools`.
// Agent viết impl thật trong thư mục mình, rồi sửa ĐÚNG MỘT DÒNG: thay
// `throw UnimplementedError(...)` bằng `const MyImpl()` / `MyImpl(...)`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/pdf/pdf_tools_engine.dart';
import 'engine/syncfusion_pdf_tools.dart';

final pdfToolsEngineProvider = Provider<PdfToolsEngine>(
  (ref) => const SyncfusionPdfTools(),
);
