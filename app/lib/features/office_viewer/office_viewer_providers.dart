// Provider engine của feature `office_viewer`.
// Agent viết impl thật trong thư mục mình, rồi sửa ĐÚNG MỘT DÒNG: thay
// `throw UnimplementedError(...)` bằng `const MyImpl()` / `MyImpl(...)`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/office/docx_engine.dart';
import '../../engines/office/xlsx_engine.dart';
import 'data/office_reader_engines.dart';

final docxEngineProvider = Provider<DocxEngine>(
  (ref) => const OfficeReaderDocxEngine(),
);

final xlsxEngineProvider = Provider<XlsxEngine>(
  (ref) => const OfficeReaderXlsxEngine(),
);
