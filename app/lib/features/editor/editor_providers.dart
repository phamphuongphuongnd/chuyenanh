// Provider engine của feature `editor`.
// Agent viết impl thật trong thư mục mình, rồi sửa ĐÚNG MỘT DÒNG: thay
// `throw UnimplementedError(...)` bằng `const MyImpl()` / `MyImpl(...)`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/pdf/pdf_sign_engine.dart';

final pdfSignEngineProvider = Provider<PdfSignEngine>(
  (ref) => throw UnimplementedError('PdfSignEngine: chưa có impl (editor)'),
);
