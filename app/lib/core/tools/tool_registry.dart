import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../router/routes.dart';

/// Nhóm công cụ (thứ tự hiển thị trong lưới Công cụ).
enum ToolGroup { create, convert, pdfTools, edit }

/// Đầu vào công cụ cần — feature documents dựa vào đây để mở picker trước hay không.
enum ToolInputType {
  /// Không cần file: push route không `extra`.
  none,

  /// Một PDF, route nhận `String?` — màn công cụ tự chọn file nếu null.
  pdf,

  /// Nhiều PDF (gộp): route nhận `String?` = file đầu tiên (nếu có).
  multiplePdf,

  /// Bắt buộc một PDF: người gọi chọn file trước rồi push `extra: String path`.
  pdfRequired,

  /// Một DOCX, route nhận `String?`.
  word,

  /// Một XLSX, route nhận `String?`.
  excel,

  /// Chữ gõ hoặc TXT, route nhận `String?`.
  text,

  /// Ảnh: màn tự chọn ảnh.
  images,
}

/// Mô tả một công cụ trong lưới / nút ＋.
@immutable
class ToolSpec {
  const ToolSpec({
    required this.id,
    required this.route,
    required this.icon,
    required this.labelKey,
    required this.group,
    required this.inputType,
  });

  /// Id ổn định (dùng làm key widget, analytics nội bộ).
  final String id;
  final String route;
  final IconData icon;

  /// Key ARB của tên công cụ (`core_tool...`). Lấy chữ: [toolLabel].
  final String labelKey;
  final ToolGroup group;
  final ToolInputType inputType;
}

/// Mọi công cụ của spec, theo thứ tự hiển thị.
const List<ToolSpec> allTools = [
  // Tạo PDF
  ToolSpec(
    id: 'imageToPdf',
    route: Routes.imageToPdf,
    icon: Icons.image_outlined,
    labelKey: 'core_toolImageToPdf',
    group: ToolGroup.create,
    inputType: ToolInputType.images,
  ),
  ToolSpec(
    id: 'scanner',
    route: Routes.scanner,
    icon: Icons.document_scanner_outlined,
    labelKey: 'core_toolScanner',
    group: ToolGroup.create,
    inputType: ToolInputType.none,
  ),
  ToolSpec(
    id: 'textToPdf',
    route: Routes.textToPdf,
    icon: Icons.text_fields,
    labelKey: 'core_toolTextToPdf',
    group: ToolGroup.create,
    inputType: ToolInputType.text,
  ),
  ToolSpec(
    id: 'createBlank',
    route: Routes.createBlank,
    icon: Icons.note_add_outlined,
    labelKey: 'core_toolCreateBlank',
    group: ToolGroup.create,
    inputType: ToolInputType.none,
  ),
  // Chuyển đổi
  ToolSpec(
    id: 'wordToPdf',
    route: Routes.wordToPdf,
    icon: Icons.description_outlined,
    labelKey: 'core_toolWordToPdf',
    group: ToolGroup.convert,
    inputType: ToolInputType.word,
  ),
  ToolSpec(
    id: 'excelToPdf',
    route: Routes.excelToPdf,
    icon: Icons.table_chart_outlined,
    labelKey: 'core_toolExcelToPdf',
    group: ToolGroup.convert,
    inputType: ToolInputType.excel,
  ),
  ToolSpec(
    id: 'pdfToImage',
    route: Routes.pdfToImage,
    icon: Icons.photo_library_outlined,
    labelKey: 'core_toolPdfToImage',
    group: ToolGroup.convert,
    inputType: ToolInputType.pdf,
  ),
  ToolSpec(
    id: 'pdfToText',
    route: Routes.pdfToText,
    icon: Icons.notes,
    labelKey: 'core_toolPdfToText',
    group: ToolGroup.convert,
    inputType: ToolInputType.pdf,
  ),
  ToolSpec(
    id: 'pdfToWord',
    route: Routes.pdfToWord,
    icon: Icons.article_outlined,
    labelKey: 'core_toolPdfToWord',
    group: ToolGroup.convert,
    inputType: ToolInputType.pdf,
  ),
  ToolSpec(
    id: 'pdfToExcel',
    route: Routes.pdfToExcel,
    icon: Icons.grid_on,
    labelKey: 'core_toolPdfToExcel',
    group: ToolGroup.convert,
    inputType: ToolInputType.pdf,
  ),
  // Công cụ PDF
  ToolSpec(
    id: 'merge',
    route: Routes.merge,
    icon: Icons.merge_type,
    labelKey: 'core_toolMerge',
    group: ToolGroup.pdfTools,
    inputType: ToolInputType.multiplePdf,
  ),
  ToolSpec(
    id: 'split',
    route: Routes.split,
    icon: Icons.call_split,
    labelKey: 'core_toolSplit',
    group: ToolGroup.pdfTools,
    inputType: ToolInputType.pdf,
  ),
  ToolSpec(
    id: 'organize',
    route: Routes.organize,
    icon: Icons.dashboard_customize_outlined,
    labelKey: 'core_toolOrganize',
    group: ToolGroup.pdfTools,
    inputType: ToolInputType.pdf,
  ),
  ToolSpec(
    id: 'lock',
    route: Routes.lock,
    icon: Icons.lock_outline,
    labelKey: 'core_toolLock',
    group: ToolGroup.pdfTools,
    inputType: ToolInputType.pdf,
  ),
  ToolSpec(
    id: 'unlock',
    route: Routes.unlock,
    icon: Icons.lock_open_outlined,
    labelKey: 'core_toolUnlock',
    group: ToolGroup.pdfTools,
    inputType: ToolInputType.pdf,
  ),
  ToolSpec(
    id: 'watermark',
    route: Routes.watermark,
    icon: Icons.branding_watermark_outlined,
    labelKey: 'core_toolWatermark',
    group: ToolGroup.pdfTools,
    inputType: ToolInputType.pdf,
  ),
  // Chỉnh sửa
  ToolSpec(
    id: 'annotate',
    route: Routes.annotate,
    icon: Icons.border_color_outlined,
    labelKey: 'core_toolAnnotate',
    group: ToolGroup.edit,
    inputType: ToolInputType.pdfRequired,
  ),
  ToolSpec(
    id: 'sign',
    route: Routes.sign,
    icon: Icons.draw_outlined,
    labelKey: 'core_toolSign',
    group: ToolGroup.edit,
    inputType: ToolInputType.pdfRequired,
  ),
  ToolSpec(
    id: 'fillForm',
    route: Routes.fillForm,
    icon: Icons.edit_note,
    labelKey: 'core_toolFillForm',
    group: ToolGroup.edit,
    inputType: ToolInputType.pdfRequired,
  ),
];

/// Tìm công cụ theo id (null nếu không có).
ToolSpec? toolById(String id) {
  for (final t in allTools) {
    if (t.id == id) return t;
  }
  return null;
}

/// Tên công cụ theo ngôn ngữ hiện tại.
String toolLabel(BuildContext context, ToolSpec tool) =>
    toolLabelFor(context.l10n, tool.labelKey);

/// Như [toolLabel] nhưng nhận [AppLocalizations] (tiện cho test).
String toolLabelFor(AppLocalizations l, String labelKey) => switch (labelKey) {
  'core_toolImageToPdf' => l.core_toolImageToPdf,
  'core_toolScanner' => l.core_toolScanner,
  'core_toolTextToPdf' => l.core_toolTextToPdf,
  'core_toolCreateBlank' => l.core_toolCreateBlank,
  'core_toolWordToPdf' => l.core_toolWordToPdf,
  'core_toolExcelToPdf' => l.core_toolExcelToPdf,
  'core_toolPdfToImage' => l.core_toolPdfToImage,
  'core_toolPdfToText' => l.core_toolPdfToText,
  'core_toolPdfToWord' => l.core_toolPdfToWord,
  'core_toolPdfToExcel' => l.core_toolPdfToExcel,
  'core_toolMerge' => l.core_toolMerge,
  'core_toolSplit' => l.core_toolSplit,
  'core_toolOrganize' => l.core_toolOrganize,
  'core_toolLock' => l.core_toolLock,
  'core_toolUnlock' => l.core_toolUnlock,
  'core_toolWatermark' => l.core_toolWatermark,
  'core_toolAnnotate' => l.core_toolAnnotate,
  'core_toolSign' => l.core_toolSign,
  'core_toolFillForm' => l.core_toolFillForm,
  _ => labelKey,
};
