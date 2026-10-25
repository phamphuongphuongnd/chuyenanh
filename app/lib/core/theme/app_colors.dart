import 'package:flutter/material.dart';

import '../utils/doc_type.dart';

/// Bảng màu app (spec mục 4).
abstract final class AppColors {
  static const Color primary = Color(0xFFE5393B);
  static const Color primaryDark = Color(0xFFC62828);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);

  /// Nền ô nhập trong hộp thoại.
  static const Color inputFill = Color(0xFFFFF8E1);
  static const Color inputFillDark = Color(0xFF2C2A22);

  static const Color pdf = Color(0xFFE53935);
  static const Color doc = Color(0xFF1E88E5);
  static const Color xls = Color(0xFF43A047);
  static const Color ppt = Color(0xFFF4511E);
  static const Color txt = Color(0xFF78909C);
  static const Color image = Color(0xFF8E24AA);
  static const Color other = Color(0xFF9E9E9E);

  /// Màu theo loại file (giữ nguyên ở giao diện tối).
  static Color forDocType(DocType type) => switch (type) {
    DocType.pdf => pdf,
    DocType.doc || DocType.docx => doc,
    DocType.xls || DocType.xlsx => xls,
    DocType.ppt || DocType.pptx => ppt,
    DocType.txt => txt,
    DocType.image => image,
    DocType.other => other,
  };

  /// Màu thanh tiêu đề theo tab (null = tab All → đỏ chủ đạo).
  static Color forCategory(DocCategory? category) => switch (category) {
    null => primary,
    DocCategory.pdf => pdf,
    DocCategory.doc => doc,
    DocCategory.xls => xls,
    DocCategory.ppt => ppt,
    DocCategory.txt => txt,
  };
}
