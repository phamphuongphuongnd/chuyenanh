import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../engines/pdf/image_to_pdf_engine.dart';
import '../models/image_item.dart';
import '../models/pdf_estimate.dart';
import 'filter_sheet.dart' show pillChoiceChip;

/// Lựa chọn của người dùng ở bảng tuỳ chọn.
class ExportRequest {
  const ExportRequest({required this.options, required this.fileName});

  final ImageToPdfOptions options;

  /// Tên người dùng nhập (chưa chuẩn hoá).
  final String fileName;
}

/// Bảng tuỳ chọn xuất: khổ giấy, hướng, lề, chất lượng, tên file + dung lượng ước tính.
/// Trả về [ExportRequest] khi bấm "Tạo PDF", `null` nếu đóng.
Future<ExportRequest?> showOptionsSheet(
  BuildContext context, {
  required List<ImageItem> items,
  required ImageToPdfOptions initialOptions,
  required String initialName,
}) {
  return showModalBottomSheet<ExportRequest>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => OptionsSheet(
      items: items,
      initialOptions: initialOptions,
      initialName: initialName,
    ),
  );
}

class OptionsSheet extends StatefulWidget {
  const OptionsSheet({
    super.key,
    required this.items,
    required this.initialOptions,
    required this.initialName,
  });

  final List<ImageItem> items;
  final ImageToPdfOptions initialOptions;
  final String initialName;

  @override
  State<OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<OptionsSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late PageSizeOption _size = widget.initialOptions.pageSize;
  late PageOrientation _orientation = widget.initialOptions.orientation;
  late PageMargin _margin = widget.initialOptions.margin;
  late double _quality = widget.initialOptions.jpegQuality.toDouble();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      ExportRequest(
        options: ImageToPdfOptions(
          pageSize: _size,
          orientation: _orientation,
          margin: _margin,
          jpegQuality: _quality.round(),
        ),
        fileName: _name.text,
      ),
    );
  }

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: context.tokens.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  Widget _chips<T>({
    required List<(T, String)> options,
    required T selected,
    required ValueChanged<T>? onChanged,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final (value, label) in options)
        pillChoiceChip(
          context,
          label: label,
          selected: value == selected,
          onSelected: onChanged == null ? null : (_) => onChanged(value),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final estimate = estimatePdfBytes(widget.items, _quality.round());
    final fit = _size == PageSizeOption.fit;
    final t = context.tokens;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.img2pdf_optionsTitle,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: t.text,
                ),
              ),
              _section(
                l.core_fileName,
                AppTextField(
                  controller: _name,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              _section(
                l.img2pdf_pageSize,
                _chips<PageSizeOption>(
                  options: [
                    (PageSizeOption.a4, l.img2pdf_sizeA4),
                    (PageSizeOption.letter, l.img2pdf_sizeLetter),
                    (PageSizeOption.fit, l.img2pdf_sizeFit),
                  ],
                  selected: _size,
                  onChanged: (v) => setState(() => _size = v),
                ),
              ),
              _section(
                l.img2pdf_orientation,
                _chips<PageOrientation>(
                  options: [
                    (PageOrientation.auto, l.img2pdf_orientationAuto),
                    (PageOrientation.portrait, l.img2pdf_orientationPortrait),
                    (PageOrientation.landscape, l.img2pdf_orientationLandscape),
                  ],
                  selected: _orientation,
                  onChanged: fit
                      ? null
                      : (v) => setState(() => _orientation = v),
                ),
              ),
              _section(
                l.img2pdf_margin,
                _chips<PageMargin>(
                  options: [
                    (PageMargin.none, l.img2pdf_marginNone),
                    (PageMargin.small, l.img2pdf_marginSmall),
                    (PageMargin.large, l.img2pdf_marginLarge),
                  ],
                  selected: _margin,
                  onChanged: (v) => setState(() => _margin = v),
                ),
              ),
              _section(
                '${l.img2pdf_quality}: ${l.img2pdf_qualityValue(_quality.round())}',
                Slider(
                  value: _quality,
                  min: 30,
                  max: 100,
                  divisions: 14,
                  label: l.img2pdf_qualityValue(_quality.round()),
                  onChanged: (v) => setState(() => _quality = v),
                ),
              ),
              const SizedBox(height: 4),
              // Ước tính dung lượng: khối nền `surface2` bo 14, chữ phụ.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: t.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  l.img2pdf_estimatedSize(
                    formatFileSize(estimate, locale),
                    widget.items.length,
                  ),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: t.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        l.core_cancel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: _submit,
                      child: Text(
                        l.img2pdf_createPdf,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
