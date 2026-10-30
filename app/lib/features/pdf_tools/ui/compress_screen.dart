import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_format.dart';
import '../engine/compress_pdf.dart';
import 'single_pdf_state.dart';
import 'tool_runner.dart';
import 'tool_widgets.dart';

/// Nén PDF (3 mức), lưu thành file mới `<tên>_compressed.pdf`.
///
/// Nhẹ: giữ chữ chọn được. Vừa/Mạnh: mỗi trang thành ảnh JPEG (mất chữ, liên kết, chú thích).
/// File gốc có mật khẩu → file kết quả không có mật khẩu.
class CompressScreen extends ConsumerStatefulWidget {
  const CompressScreen({super.key, this.path});

  final String? path;

  @override
  ConsumerState<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends ConsumerState<CompressScreen>
    with SinglePdfToolState<CompressScreen> {
  CompressLevel _level = CompressLevel.medium;

  /// Kết quả đã nhận (hiện dòng "Từ X → Y" ở màn kết quả).
  CompressResult? _done;

  /// File mới không nhỏ hơn: chờ người dùng chọn giữ hay xoá.
  CompressResult? _pending;

  @override
  String? get initialPath => widget.path;

  @override
  void onInputReady(PdfInput input) {
    setState(() {
      _done = null;
      _pending = null;
    });
  }

  Future<void> _compress() async {
    final src = input;
    if (src == null) return;
    final out = await newOutputPath(ref, compressedBaseName(src.path));
    if (!mounted) return;
    final engine = ref.read(compressEngineProvider);
    final level = _level;
    final res = await runToolJob<CompressResult>(
      context,
      title: context.l10n.core_processing,
      job: (onProgress, token) => engine.compress(
        src.path,
        out,
        level,
        password: src.password,
        onProgress: onProgress,
        cancelToken: token,
      ),
    );
    if (res == null || !mounted) return;
    if (res.isSmaller) {
      _done = res;
      await finish([res.outputPath]);
    } else {
      setState(() => _pending = res);
    }
  }

  Future<void> _keepPending() async {
    final res = _pending;
    if (res == null) return;
    setState(() {
      _pending = null;
      _done = res;
    });
    await finish([res.outputPath]);
  }

  Future<void> _deletePending() async {
    final res = _pending;
    if (res == null) return;
    try {
      final f = File(res.outputPath);
      if (await f.exists()) await f.delete();
    } catch (e) {
      if (mounted) showToolError(context, e);
      return;
    }
    if (!mounted) return;
    setState(() => _pending = null);
    showToolMessage(context, context.l10n.compress_deleted);
  }

  String _size(int bytes) =>
      formatFileSize(bytes, Localizations.localeOf(context).toString());

  String _summary(CompressResult r) {
    final l = context.l10n;
    final from = _size(r.originalBytes);
    final to = _size(r.outputBytes);
    return r.isSmaller
        ? l.compress_resultSummary(from, to, r.percent)
        : l.compress_resultNoGain(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = l.core_toolCompress;
    final res = results;
    if (res != null) {
      final done = _done;
      return ToolScaffold(
        title: title,
        body: Column(
          children: [
            if (done != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _SizeSummary(_summary(done)),
              ),
            Expanded(
              child: ToolResultView(paths: res, onDone: () => context.pop()),
            ),
          ],
        ),
      );
    }
    final pending = _pending;
    if (pending != null) return _buildNotSmaller(pending);
    final src = input;
    if (src == null) {
      return ToolScaffold(
        title: title,
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : PickPdfPrompt(onPick: pickNew),
      );
    }
    return ToolScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          PdfInputCard(input: src, onChange: pickNew),
          const SizedBox(height: 16),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ToolSectionLabel(l.compress_levelLabel),
                ToolChipWrap(
                  children: [
                    for (final level in CompressLevel.values)
                      ToolChoiceChip(
                        label: _levelLabel(l, level),
                        selected: _level == level,
                        onTap: () => setState(() => _level = level),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ToolHintText(_levelDescription(l, _level)),
              ],
            ),
          ),
          if (compressLevelRasterizes(_level)) ...[
            const SizedBox(height: 16),
            NoteBanner(l.compress_rasterWarning, warning: true),
          ],
          if (src.password != null) ...[
            const SizedBox(height: 16),
            NoteBanner(l.compress_passwordNote),
          ],
        ],
      ),
      bottom: PrimaryActionButton(
        label: l.compress_action,
        icon: Symbols.compress_rounded,
        onPressed: _compress,
      ),
    );
  }

  /// File mới không nhỏ hơn file gốc: báo, cho giữ hoặc xoá.
  Widget _buildNotSmaller(CompressResult r) {
    final l = context.l10n;
    return ToolScaffold(
      title: l.core_toolCompress,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          ToolCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ToolFileRow(path: r.outputPath, info: _size(r.outputBytes)),
          ),
          const SizedBox(height: 16),
          NoteBanner(
            '${l.compress_notSmallerTitle}\n'
            '${l.compress_notSmallerBody(_size(r.originalBytes), _size(r.outputBytes))}',
            warning: true,
          ),
        ],
      ),
      bottom: Row(
        children: [
          Expanded(
            child: SecondaryActionButton(
              label: l.compress_deleteNew,
              icon: Symbols.delete_rounded,
              onPressed: _deletePending,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryActionButton(
              label: l.compress_keep,
              icon: Symbols.check_rounded,
              onPressed: _keepPending,
            ),
          ),
        ],
      ),
    );
  }
}

String _levelLabel(AppLocalizations l, CompressLevel level) => switch (level) {
  CompressLevel.light => l.compress_levelLight,
  CompressLevel.medium => l.compress_levelMedium,
  CompressLevel.strong => l.compress_levelStrong,
};

String _levelDescription(AppLocalizations l, CompressLevel level) =>
    switch (level) {
      CompressLevel.light => l.compress_levelLightDesc,
      CompressLevel.medium => l.compress_levelMediumDesc,
      CompressLevel.strong => l.compress_levelStrongDesc,
    };

/// Dòng "Từ X → Y (giảm Z%)" trên màn kết quả.
class _SizeSummary extends StatelessWidget {
  const _SizeSummary(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ToolCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          const Icon(
            Symbols.compress_rounded,
            size: 22,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: t.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
