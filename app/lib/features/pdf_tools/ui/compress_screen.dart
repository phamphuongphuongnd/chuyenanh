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
/// Nhẹ: giữ chữ chọn được. Vừa/Mạnh: mỗi trang thành ảnh JPEG (chữ vẫn chọn được, liên kết /
/// highlight / ghi chú được dựng lại; ô biểu mẫu, hình vẽ mất và được báo).
/// Không bao giờ ra file to hơn gốc: không nén được thì báo, không tạo file mới.
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

  /// Lần nén gần nhất không nén thêm được (không có file mới): báo ở màn chọn mức.
  CompressResult? _optimal;

  @override
  String? get initialPath => widget.path;

  @override
  void onInputReady(PdfInput input) {
    setState(() {
      _done = null;
      _optimal = null;
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
    if (res.alreadyOptimal) {
      setState(() => _optimal = res);
    } else {
      _done = res;
      await finish([res.outputPath]);
    }
  }

  String _size(int bytes) =>
      formatFileSize(bytes, Localizations.localeOf(context).toString());

  String _summary(CompressResult r) {
    final l = context.l10n;
    final from = _size(r.originalBytes);
    final to = _size(r.outputBytes);
    return l.compress_resultSummary(from, to, r.percent);
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
                child: Column(
                  children: [
                    _SizeSummary(_summary(done)),
                    if (done.fellBackToLight) ...[
                      const SizedBox(height: 12),
                      NoteBanner(context.l10n.compress_fellBackNote),
                    ],
                    if (done.lostAnnotations > 0) ...[
                      const SizedBox(height: 12),
                      NoteBanner(
                        context.l10n.compress_lostAnnotations(
                          done.lostAnnotations,
                        ),
                        warning: true,
                      ),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: ToolResultView(paths: res, onDone: () => context.pop()),
            ),
          ],
        ),
      );
    }
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
          if (_optimal != null) ...[
            const SizedBox(height: 16),
            NoteBanner(
              '${l.compress_alreadyOptimizedTitle}\n'
              '${l.compress_alreadyOptimizedBody(_size(_optimal!.originalBytes))}',
              warning: true,
            ),
          ],
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
