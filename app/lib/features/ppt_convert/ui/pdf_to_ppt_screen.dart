import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/file_paths.dart';
import '../../../core/utils/output_directory.dart';
import '../../../data/db/app_database.dart';
import '../../image_to_pdf/services/output_registry.dart';
import '../../pdf_tools/ui/single_pdf_state.dart';
import '../../pdf_tools/ui/tool_runner.dart';
import '../../pdf_tools/ui/tool_widgets.dart';
import '../engine/pdf_to_ppt.dart';

/// PDF → PowerPoint (`Routes.pdfToPpt`, `extra: String? path`).
///
/// Mỗi trang PDF render thành ảnh JPEG (150 hoặc 200 dpi) rồi thành một slide ảnh; cỡ slide
/// theo trang 1. Lưu `<tên>.pptx` vào thư mục lưu của app; màn kết quả mở bằng trình xem
/// PPTX của app hoặc chia sẻ.
class PdfToPptScreen extends ConsumerStatefulWidget {
  const PdfToPptScreen({super.key, this.path});

  final String? path;

  @override
  ConsumerState<PdfToPptScreen> createState() => _PdfToPptScreenState();
}

class _PdfToPptScreenState extends ConsumerState<PdfToPptScreen>
    with SinglePdfToolState<PdfToPptScreen> {
  int _dpi = kPdfToPptDefaultDpi;

  @override
  String? get initialPath => widget.path;

  Future<void> _convert() async {
    final src = input;
    if (src == null) return;
    final l = context.l10n;
    final dir = await ref.read(outputDirectoryProvider.future);
    final out = await uniqueOutputPath(
      dir,
      baseNameWithoutExtension(src.path),
      'pptx',
    );
    if (!mounted) return;
    final converter = ref.read(pdfToPptConverterProvider);
    final dpi = _dpi;
    final saved = await runToolJob<String>(
      context,
      title: l.pdfppt_converting,
      job: (onProgress, token) => converter.convert(
        inputPath: src.path,
        outputPath: out,
        password: src.password,
        dpi: dpi,
        onProgress: onProgress,
        cancelToken: token,
      ),
    );
    if (saved == null || !mounted) return;
    try {
      await registerOutputDocument(ref.read(appDatabaseProvider), saved);
    } catch (_) {
      // bảng documents chỉ là bộ đệm; lần quét sau sẽ thấy file.
    }
    if (mounted) setState(() => results = [saved]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = l.core_toolPdfToPpt;
    final done = results;
    if (done != null) {
      return ToolScaffold(
        title: title,
        body: ToolResultView(paths: done, onDone: () => context.pop()),
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
          const SizedBox(height: 16),
          NoteBanner(l.pdfppt_note),
          const SizedBox(height: 16),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ToolSectionLabel(l.pdfppt_quality),
                ToolChipWrap(
                  children: [
                    for (final dpi in kPdfToPptDpiOptions)
                      ToolChoiceChip(
                        key: Key('pdfppt_dpi_$dpi'),
                        label: dpi == kPdfToPptDefaultDpi
                            ? l.pdfppt_qualityStandard
                            : l.pdfppt_qualityHigh,
                        selected: _dpi == dpi,
                        onTap: () => setState(() => _dpi = dpi),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ToolHintText(l.pdfppt_slidesToCreate(src.pageCount)),
                const SizedBox(height: 4),
                ToolHintText(l.pdfppt_sizeInfo),
              ],
            ),
          ),
        ],
      ),
      bottom: PrimaryActionButton(
        key: const Key('pdfppt_convert'),
        label: l.pdfppt_convert,
        icon: Symbols.slideshow_rounded,
        onPressed: loading ? null : _convert,
      ),
    );
  }
}
