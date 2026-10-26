// Lớp bọc quanh `SfPdfViewer` cho màn chú thích / điền form.
//
// Tách thành provider để widget test thay bằng bản giả (SfPdfViewer cần plugin nền tảng,
// không chạy được trong `flutter test`).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Tham số truyền cho viewer; màn hình điều khiển viewer qua [controller].
class EditorViewerArgs {
  const EditorViewerArgs({
    required this.path,
    required this.controller,
    this.undoController,
    this.onLoaded,
    this.onLoadFailed,
    this.onChanged,
    this.onAnnotationSelected,
  });

  final String path;
  final PdfViewerController controller;
  final UndoHistoryController? undoController;

  /// Tài liệu đã nạp xong (có thể đọc `controller.getFormFields()`…).
  final VoidCallback? onLoaded;

  /// Không mở được tài liệu.
  final VoidCallback? onLoadFailed;

  /// Có thay đổi chưa lưu (thêm/sửa/xoá chú thích, đổi giá trị ô form).
  final VoidCallback? onChanged;

  /// Chú thích được chọn (`null` = bỏ chọn).
  final ValueChanged<Annotation?>? onAnnotationSelected;
}

typedef EditorViewerBuilder =
    Widget Function(BuildContext context, EditorViewerArgs args);

/// Lưu tài liệu đang mở trong viewer ra bytes ([flatten] = làm phẳng ô form).
typedef EditorDocumentSaver =
    Future<List<int>> Function(
      PdfViewerController controller, {
      bool flatten,
    });

Widget _syncfusionViewer(BuildContext context, EditorViewerArgs a) {
  return SfPdfViewer.file(
    File(a.path),
    controller: a.controller,
    undoController: a.undoController,
    onDocumentLoaded: (_) => a.onLoaded?.call(),
    onDocumentLoadFailed: (_) => a.onLoadFailed?.call(),
    onAnnotationAdded: (_) => a.onChanged?.call(),
    onAnnotationEdited: (_) => a.onChanged?.call(),
    onAnnotationRemoved: (_) => a.onChanged?.call(),
    onAnnotationSelected: (an) => a.onAnnotationSelected?.call(an),
    onAnnotationDeselected: (_) => a.onAnnotationSelected?.call(null),
    onFormFieldValueChanged: (_) => a.onChanged?.call(),
  );
}

Future<List<int>> _syncfusionSave(
  PdfViewerController controller, {
  bool flatten = false,
}) => controller.saveDocument(
  flattenOption: flatten ? PdfFlattenOption.formFields : PdfFlattenOption.none,
);

final editorViewerBuilderProvider = Provider<EditorViewerBuilder>(
  (ref) => _syncfusionViewer,
);

final editorDocumentSaverProvider = Provider<EditorDocumentSaver>(
  (ref) => _syncfusionSave,
);
