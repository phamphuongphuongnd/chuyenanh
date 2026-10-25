// Provider engine của feature `office_viewer`.
// Agent viết impl thật trong thư mục mình, rồi sửa ĐÚNG MỘT DÒNG: thay
// `throw UnimplementedError(...)` bằng `const MyImpl()` / `MyImpl(...)`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/office/docx_engine.dart';
import '../../engines/office/xlsx_engine.dart';

final docxEngineProvider = Provider<DocxEngine>(
  (ref) => throw UnimplementedError('DocxEngine: chưa có impl (office_viewer)'),
);

final xlsxEngineProvider = Provider<XlsxEngine>(
  (ref) => throw UnimplementedError('XlsxEngine: chưa có impl (office_viewer)'),
);
