// Provider engine của feature `convert`.
// Agent viết impl thật trong thư mục mình, rồi sửa ĐÚNG MỘT DÒNG: thay
// `throw UnimplementedError(...)` bằng `const MyImpl()` / `MyImpl(...)`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/convert/convert_engine.dart';
import 'engine/pdf_convert_engine.dart';

final convertEngineProvider = Provider<ConvertEngine>(
  (ref) => const PdfConvertEngine(),
);
