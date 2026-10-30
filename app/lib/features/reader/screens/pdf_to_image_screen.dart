import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/output_directory.dart';
import '../../../core/widgets/widgets.dart';
import '../../../engines/pdf/pdf_render_engine.dart';
import '../logic/page_range.dart';
import '../logic/pdf_to_image_export.dart';
import '../reader_providers.dart';

/// PDF → ảnh (`Routes.pdfToImage`, `extra: String? path`).
///
/// Chọn trang (tất cả / khoảng), định dạng JPG/PNG, DPI → `pdfx` render từng trang,
/// lưu vào thư mục con theo tên file trong thư mục lưu của app.
class PdfToImageScreen extends ConsumerStatefulWidget {
  const PdfToImageScreen({super.key, this.path});

  final String? path;

  @override
  ConsumerState<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends ConsumerState<PdfToImageScreen> {
  String? _path;
  PdfRenderDocument? _doc;
  bool _opening = false;
  AppError? _error;

  PdfPageSize? _firstPage;
  Uint8List? _thumbnail;

  bool _allPages = true;
  final TextEditingController _range = TextEditingController();
  PageRangeIssue? _rangeIssue;

  RenderFormat _format = RenderFormat.jpg;
  int _dpi = kDefaultDpi;

  PdfExportResult? _result;

  int get _pageCount => _doc?.pageCount ?? 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.path;
    if (initial != null) {
      _opening = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(initial));
    }
  }

  @override
  void dispose() {
    _range.dispose();
    _doc?.close();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await ref.read(pdfFilePickerProvider)();
    if (picked == null || !mounted) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    await _open(picked);
  }

  /// Mở tài liệu; PDF có mật khẩu → hỏi mật khẩu (sai thì hỏi lại).
  Future<void> _open(String path) async {
    final engine = ref.read(pdfRenderEngineProvider);
    String? password;
    String? errorText;
    try {
      PdfRenderDocument? doc;
      while (doc == null) {
        try {
          doc = await engine.openFile(path, password: password);
        } on PasswordRequired {
          password = await _askPassword(path, null);
          if (password == null) return _leave();
        } on WrongPassword {
          errorText = mounted ? context.l10n.core_errorWrongPassword : null;
          password = await _askPassword(path, errorText);
          if (password == null) return _leave();
        }
        if (!mounted) {
          await doc?.close();
          return;
        }
      }

      PdfPageSize? size;
      Uint8List? thumb;
      try {
        size = await doc.pageSize(0);
        thumb = await doc.renderThumbnail(0, maxSide: 480);
      } catch (_) {
        // Không có ảnh xem trước vẫn chuyển đổi được.
      }
      if (!mounted) {
        await doc.close();
        return;
      }
      final previous = _doc;
      setState(() {
        _path = path;
        _doc = doc;
        _firstPage = size;
        _thumbnail = thumb;
        _opening = false;
        _error = null;
        _result = null;
        _allPages = true;
        _range.clear();
        _rangeIssue = null;
      });
      await previous?.close();
    } on AppError catch (e) {
      _failOpen(e);
    } catch (e) {
      _failOpen(AppError.from(e));
    }
  }

  Future<String?> _askPassword(String path, String? errorText) {
    if (!mounted) return Future.value(null);
    return showPasswordDialog(
      context,
      message: context.l10n.core_passwordDialogMessage(p.basename(path)),
      errorText: errorText,
    );
  }

  void _leave() {
    if (!mounted) return;
    if (_doc == null) {
      // Huỷ nhập mật khẩu khi chưa có tài liệu nào: về màn trước.
      Navigator.of(context).maybePop();
    } else {
      setState(() => _opening = false);
    }
  }

  void _failOpen(AppError e) {
    if (!mounted) return;
    setState(() {
      _opening = false;
      _error = e;
    });
  }

  List<int>? _selectedPages() {
    if (_allPages) return List<int>.generate(_pageCount, (i) => i);
    final r = parsePageRange(_range.text, _pageCount);
    switch (r) {
      case PageRangeOk(:final pages):
        return pages;
      case PageRangeInvalid(:final issue):
        _rangeIssue = issue;
        return null;
    }
  }

  String? _rangeMessage(PageRangeIssue? issue) {
    if (issue == null) return null;
    final l = context.l10n;
    return switch (issue) {
      PageRangeIssue.empty => l.reader_rangeEmpty,
      PageRangeIssue.syntax => l.reader_rangeSyntax,
      PageRangeIssue.outOfRange => l.reader_rangeOutOfRange(_pageCount),
      PageRangeIssue.reversed => l.reader_rangeReversed,
    };
  }

  Future<void> _convert() async {
    final doc = _doc;
    final path = _path;
    if (doc == null || path == null) return;

    setState(() => _rangeIssue = null);
    final pages = _selectedPages();
    if (pages == null) {
      setState(() {}); // hiện _rangeIssue
      return;
    }

    final ctrl = showProgressDialog(
      context,
      title: context.l10n.reader_converting,
    );
    try {
      final dir = await ref.read(outputDirectoryProvider.future);
      final result = await exportPdfToImages(
        document: doc,
        pages: pages,
        dpi: _dpi.toDouble(),
        format: _format,
        parentDir: dir,
        baseName: p.basenameWithoutExtension(path),
        onProgress: ctrl.update,
        cancelToken: ctrl.cancelToken,
      );
      ctrl.close();
      if (!mounted) return;
      setState(() => _result = result);
    } on Cancelled {
      ctrl.close();
    } catch (e) {
      ctrl.close();
      if (!mounted) return;
      final err = e is AppError ? e : AppError.from(e);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(appErrorMessage(context, err))));
    }
  }

  Future<void> _share(PdfExportResult result) async {
    try {
      await ref.read(fileSharerProvider)(result.files);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appErrorMessage(context, AppError.from(e)))),
      );
    }
  }

  // --- Giao diện ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: context.tokens.bg,
      appBar: AppBar(title: Text(l.core_toolPdfToImage)),
      body: _buildBody(context),
      bottomNavigationBar: _doc != null && _result == null && !_opening
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  key: const Key('p2i_convert'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _convert,
                  child: Text(l.reader_convert),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    final l = context.l10n;
    if (_opening) return const Center(child: CircularProgressIndicator());

    final error = _error;
    if (error != null) {
      return EmptyState(
        icon: Symbols.error_rounded,
        title: appErrorMessage(context, error),
        actionLabel: l.core_selectFile,
        onAction: _pick,
      );
    }
    if (_doc == null) {
      return EmptyState(
        icon: Symbols.image_rounded,
        title: l.reader_choosePdf,
        actionLabel: l.core_selectFile,
        onAction: _pick,
      );
    }
    final result = _result;
    if (result != null) return _buildResult(context, result);
    return _buildOptions(context);
  }

  Widget _buildResult(BuildContext context, PdfExportResult result) {
    final l = context.l10n;
    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Block(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: _successGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Symbols.check_rounded, size: 48, color: _successGreen),
              ),
              const SizedBox(height: 18),
              Text(
                l.reader_resultTitle,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.text),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                l.reader_resultMessage(result.files.length),
                style: TextStyle(fontSize: 14, height: 1.45, color: t.text),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              SelectableText(
                result.directory,
                key: const Key('p2i_resultPath'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: t.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('p2i_share'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => _share(result),
          icon: const Icon(Symbols.share_rounded, size: 20),
          label: Text(l.core_share),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('p2i_again'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => setState(() => _result = null),
          child: Text(l.reader_convertMore),
        ),
      ],
    );
  }

  Widget _buildOptions(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final path = _path!;
    final size = _firstPage;
    final estimate = size == null
        ? null
        : estimateImageSize(size, _dpi.toDouble());

    final selectedCount = _allPages
        ? _pageCount
        : switch (parsePageRange(_range.text, _pageCount)) {
            PageRangeOk(:final pages) => pages.length,
            PageRangeInvalid() => null,
          };

    final optionTitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: t.text);
    final hint = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.textMuted);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Thẻ file: thumbnail trang 1 (hoặc icon loại file) + tên + số trang + nút đổi file.
        _Block(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              if (_thumbnail != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _thumbnail!,
                    height: 80,
                    gaplessPlayback: true,
                  ),
                )
              else
                FileTypeIcon.forPath(path, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.basename(path),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.reader_pageCount(_pageCount),
                      key: const Key('p2i_pageCount'),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l.core_selectFile,
                icon: Icon(Symbols.folder_open_rounded, color: t.textMuted),
                onPressed: _pick,
              ),
            ],
          ),
        ),
        // Trang cần chuyển.
        _SectionLabel(l.reader_pagesToConvert),
        RadioGroup<bool>(
          groupValue: _allPages,
          onChanged: (v) => setState(() => _allPages = v ?? true),
          child: CardSection(
            children: [
              _InkLayer(
                child: RadioListTile<bool>(
                  key: const Key('p2i_allPages'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  value: true,
                  title: Text(l.reader_allPages, style: optionTitle),
                ),
              ),
              _InkLayer(
                child: RadioListTile<bool>(
                  key: const Key('p2i_rangePages'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  value: false,
                  title: Text(l.reader_pageRange, style: optionTitle),
                ),
              ),
              if (!_allPages)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        key: const Key('p2i_rangeField'),
                        controller: _range,
                        hintText: l.reader_pageRangeHint,
                        errorText: _rangeMessage(_rangeIssue),
                        keyboardType: TextInputType.text,
                        onChanged: (_) => setState(() => _rangeIssue = null),
                      ),
                      if (selectedCount != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4),
                          child: Text(
                            l.reader_selectedCount(selectedCount),
                            style: hint,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Định dạng ảnh.
        _SectionLabel(l.reader_imageFormat),
        _Block(
          padding: const EdgeInsets.all(14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<RenderFormat>(
              key: const Key('p2i_format'),
              style: _pillSegmentStyle(context),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: RenderFormat.jpg, label: Text('JPG')),
                ButtonSegment(value: RenderFormat.png, label: Text('PNG')),
              ],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
          ),
        ),
        // Độ phân giải.
        _SectionLabel(l.reader_resolution),
        _Block(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final dpi in kDpiPresets)
                    ChoiceChip(
                      key: Key('p2i_dpi_$dpi'),
                      label: Text(l.reader_resolutionValue(dpi)),
                      selected: _dpi == dpi,
                      showCheckmark: false,
                      shape: const StadiumBorder(),
                      side: BorderSide.none,
                      backgroundColor: t.surface2,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _dpi == dpi ? Colors.white : t.text,
                      ),
                      onSelected: (_) => setState(() => _dpi = dpi),
                    ),
                ],
              ),
              if (estimate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 4),
                  child: Text(
                    l.reader_sizeEstimate(estimate.width, estimate.height),
                    key: const Key('p2i_estimate'),
                    style: hint,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Màu xanh "xong" của dấu ✓ (màu XLS trong bảng loại file).
const _successGreen = Color(0xFF43A047);

/// Kiểu viên cho [SegmentedButton]: đoạn đang chọn nền đỏ chủ đạo chữ trắng, còn lại nền `surface2`.
ButtonStyle _pillSegmentStyle(BuildContext context) {
  final t = context.tokens;
  return SegmentedButton.styleFrom(
    backgroundColor: t.surface2,
    foregroundColor: t.text,
    selectedBackgroundColor: AppColors.primary,
    selectedForegroundColor: Colors.white,
    side: BorderSide.none,
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );
}

/// Khối nền `surface` bo 20, không bóng.
class _Block extends StatelessWidget {
  const _Block({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: context.tokens.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

/// Lớp Material trong suốt để hiệu ứng chạm của dòng hiện trên nền trắng của [CardSection]
/// (không có lớp này, gợn sóng vẽ lên Material của Scaffold, nằm dưới nền thẻ nên không thấy).
class _InkLayer extends StatelessWidget {
  const _InkLayer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, child: child);
}

/// Nhãn mục 13/w700 màu phụ, đặt trên mỗi khối.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.tokens.textMuted,
      ),
    ),
  );
}
