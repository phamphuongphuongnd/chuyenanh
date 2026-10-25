// Provider engine của feature `image_to_pdf`.
// Agent viết impl thật trong thư mục mình, rồi sửa ĐÚNG MỘT DÒNG: thay
// `throw UnimplementedError(...)` bằng `const MyImpl()` / `MyImpl(...)`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/pdf/image_to_pdf_engine.dart';

final imageToPdfEngineProvider = Provider<ImageToPdfEngine>(
  (ref) =>
      throw UnimplementedError('ImageToPdfEngine: chưa có impl (image_to_pdf)'),
);
