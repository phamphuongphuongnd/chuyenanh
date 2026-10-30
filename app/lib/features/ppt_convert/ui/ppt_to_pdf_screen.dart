import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pptx_reader/pptx_reader.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/doc_type.dart';
import '../../../core/utils/file_format.dart';
import '../../../core/utils/file_paths.dart';
import '../../../core/utils/output_directory.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/db/app_database.dart';
import '../../image_to_pdf/services/output_registry.dart';
import '../../pdf_tools/ui/tool_runner.dart';
import '../../pdf_tools/ui/tool_widgets.dart';
import '../engine/ppt_to_pdf.dart';
import '../engine/ppt_to_pdf_providers.dart';

/// PowerPoint (.pptx) → PDF: mỗi slide một trang ảnh, giống trình xem PPTX của app.
///
/// Không có [path] → tự mở bộ chọn file khi vào màn.
class PptToPdfScreen extends ConsumerStatefulWidget {
  const PptToPdfScreen({super.key, this.path});

  final String? path;

  @override
  ConsumerState<PptToPdfScreen> createState() => _PptToPdfScreenState();
}

class _PptToPdfScreenState extends ConsumerState<PptToPdfScreen> {
  String? _path;
  PptxDeck? _deck;
  int? _sizeBytes;
  bool _loading = false;
  PptToPdfOptions _options = const PptToPdfOptions();

  /// Khác null = đang hiện màn kết quả.
  String? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final path = widget.path;
      if (path != null) {
        _load(path);
      } else {
        _pick();
      }
    });
  }

  Future<void> _pick() async {
    final String? path;
    try {
      path = await ref.read(pptxFilePickerProvider).pickPresentation();
    } catch (e) {
      if (mounted) showToolError(context, e);
      return;
    }
    if (!mounted || path == null) return;
    await _load(path);
  }

  Future<void> _load(String path) async {
    setState(() => _loading = true);
    try {
      final deck = await ref.read(pptToPdfEngineProvider).openDeck(path);
      int? size;
      try {
        size = await File(path).length();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _path = path;
        _deck = deck;
        _sizeBytes = size;
        _result = null;
      });
    } on UnsupportedFormat catch (e) {
      if (!mounted) return;
      final l = context.l10n;
      showToolMessage(
        context,
        e.extension == 'ppt' ? l.pptpdf_legacyPpt : l.pptpdf_notPptx,
      );
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _convert() async {
    final deck = _deck;
    final src = _path;
    if (deck == null || src == null) return;
    final l = context.l10n;
    final String outPath;
    try {
      final dir = await ref.read(outputDirectoryProvider.future);
      outPath = await uniqueOutputPath(dir, pptToPdfBaseName(src), 'pdf');
    } catch (e) {
      if (mounted) showToolError(context, e);
      return;
    }
    if (!mounted) return;
    final engine = ref.read(pptToPdfEngineProvider);
    final rasterizer = ref.read(slideRasterizerFactoryProvider)(context);
    final options = _options;
    final out = await runToolJob<String>(
      context,
      title: l.pptpdf_converting,
      job: (onProgress, token) => engine.convert(
        deck,
        outPath,
        rasterizer: rasterizer,
        options: options,
        onProgress: onProgress,
        cancelToken: token,
      ),
    );
    if (out == null || !mounted) return;
    try {
      await registerOutputDocument(ref.read(appDatabaseProvider), out);
    } catch (_) {
      // Bảng documents chỉ là bộ đệm; lần quét sau sẽ thấy file.
    }
    if (!mounted) return;
    setState(() => _result = out);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = l.core_toolPptToPdf;
    final result = _result;
    if (result != null) {
      return ToolScaffold(
        title: title,
        body: ToolResultView(paths: [result], onDone: () => context.pop()),
      );
    }
    final deck = _deck;
    final path = _path;
    if (deck == null || path == null) {
      return ToolScaffold(
        title: title,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(
                title: l.pptpdf_pickHint,
                illustration: const FileTypeIcon(DocType.pptx, size: 64),
                actionLabel: l.pptpdf_pickFile,
                onAction: _pick,
              ),
      );
    }

    final count = slidesToExport(
      deck,
      includeHidden: _options.includeHidden,
    ).length;
    final hidden = hiddenSlideCount(deck);
    final locale = Localizations.localeOf(context).toString();
    final info = [
      l.pptpdf_slideCount(deck.slides.length),
      if (_sizeBytes != null) formatFileSize(_sizeBytes!, locale),
    ].join(' • ');
    final t = context.tokens;

    return ToolScaffold(
      title: title,
      bottom: PrimaryActionButton(
        label: l.pptpdf_convert,
        icon: Symbols.picture_as_pdf_rounded,
        onPressed: count == 0 || _loading ? null : _convert,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          ToolFileCard(path: path, info: info, onChange: _pick),
          const SizedBox(height: 16),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ToolSectionLabel(l.pptpdf_quality),
                ToolChipWrap(
                  children: [
                    for (final (q, label) in [
                      (PptPdfQuality.standard, l.pptpdf_qualityStandard),
                      (PptPdfQuality.high, l.pptpdf_qualityHigh),
                    ])
                      ToolChoiceChip(
                        label: label,
                        selected: _options.quality == q,
                        onTap: () => setState(
                          () => _options = _options.copyWith(quality: q),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (hidden > 0) ...[
            const SizedBox(height: 12),
            ToolCard(
              padding: EdgeInsets.zero,
              child: Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  secondary: Icon(
                    Symbols.visibility_off_rounded,
                    color: t.textMuted,
                  ),
                  title: Text(
                    l.pptpdf_skipHidden,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                  subtitle: Text(
                    l.pptpdf_hiddenInfo(hidden),
                    style: TextStyle(fontSize: 12.5, color: t.textMuted),
                  ),
                  value: !_options.includeHidden,
                  onChanged: (skip) => setState(
                    () => _options = _options.copyWith(includeHidden: !skip),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ToolHintText(
              count == 0 ? l.pptpdf_noSlides : l.pptpdf_pagesToExport(count),
              color: count == 0 ? t.primaryText : null,
            ),
          ),
          const SizedBox(height: 12),
          NoteBanner(l.pptpdf_note),
        ],
      ),
    );
  }
}
