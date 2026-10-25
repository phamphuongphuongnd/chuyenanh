// Provider engine của feature `scanner`.
// Agent viết impl thật trong thư mục mình, rồi sửa ĐÚNG MỘT DÒNG: thay
// `throw UnimplementedError(...)` bằng `const MyImpl()` / `MyImpl(...)`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/ocr/ocr_engine.dart';

final ocrEngineProvider = Provider<OcrEngine>(
  (ref) => throw UnimplementedError('OcrEngine: chưa có impl (scanner)'),
);
