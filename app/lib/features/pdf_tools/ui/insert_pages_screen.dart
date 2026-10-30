import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../engines/pdf/pdf_render_engine.dart';
import '../../../engines/pdf/pdf_tools_engine.dart' show PageRange;
import '../../reader/reader_providers.dart' show pdfRenderEngineProvider;
import '../engine/insert_pages.dart';
import '../engine/page_ranges.dart';
import '../insert_pages_providers.dart';
import '../logic/tool_rules.dart';
import 'pdf_file_picker.dart';
import 'single_pdf_state.dart';
import 'tool_runner.dart';
import 'tool_widgets.dart';

/// Loại nội dung chèn trên màn.
enum _Kind { blank, images, pdf }

/// Chèn trang vào PDF có sẵn: trang trắng, ảnh, hoặc trang lấy từ PDF khác; chọn vị trí
/// đầu / sau trang N / cuối. Kết quả `<tên>_inserted.pdf`, không ghi đè gốc.
class InsertPagesScreen extends ConsumerStatefulWidget {
  const InsertPagesScreen({super.key, this.path});

  final String? path;

  @override
  ConsumerState<InsertPagesScreen> createState() => _InsertPagesScreenState();
}

class _InsertPagesScreenState extends ConsumerState<InsertPagesScreen>
    with SinglePdfToolState<InsertPagesScreen> {
  InsertWhere _where = InsertWhere.end;
  final _afterCtl = TextEditingController(text: '1');
  _Kind _kind = _Kind.blank;
  int _blankCount = 1;
  final List<Uint8List> _images = [];
  InsertImageFit _fit = InsertImageFit.a4;
  PdfInput? _other;
  bool _otherAll = true;
  final _rangesCtl = TextEditingController();
  _InsertThumbnails? _thumbs;

  @override
  String? get initialPath => widget.path;

  @override
  void onInputReady(PdfInput input) {
    _thumbs?.dispose();
    _thumbs = _InsertThumbnails(() async {
      // Chưa có engine render / file lạ → không có ảnh thu nhỏ, hiện ô số trang.
      final engine = ref.read(pdfRenderEngineProvider);
      return engine.openFile(input.path, password: input.password);
    });
    final n = int.tryParse(_afterCtl.text.trim());
    if (n == null || n > input.pageCount) _afterCtl.text = '1';
    setState(() {});
  }

  @override
  void dispose() {
    _thumbs?.dispose();
    _afterCtl.dispose();
    _rangesCtl.dispose();
    super.dispose();
  }

  /// Số trang gốc đứng trước khối chèn; `null` = ô "sau trang" đang sai.
  int? _insertAfter(int pageCount) {
    if (_where != InsertWhere.afterPage) {
      return resolveInsertAfter(_where, 1, pageCount);
    }
    final n = int.tryParse(_afterCtl.text.trim());
    if (n == null || n < 1 || n > pageCount) return null;
    return n;
  }

  /// Nội dung hiện tại + số trang sẽ chèn; `content == null` = chưa đủ/sai; [rangeError] = khoảng
  /// trang gõ sai.
  ({InsertContent? content, int pages, bool rangeError}) _content() {
    switch (_kind) {
      case _Kind.blank:
        return (content: InsertBlank(_blankCount), pages: _blankCount, rangeError: false);
      case _Kind.images:
        if (_images.isEmpty) return (content: null, pages: 0, rangeError: false);
        return (
          content: InsertImages(List.of(_images), fit: _fit),
          pages: _images.length,
          rangeError: false,
        );
      case _Kind.pdf:
        final other = _other;
        if (other == null) return (content: null, pages: 0, rangeError: false);
        List<PageRange>? ranges;
        if (!_otherAll) {
          if (_rangesCtl.text.trim().isEmpty) {
            return (content: null, pages: 0, rangeError: false);
          }
          try {
            ranges = parsePageRanges(_rangesCtl.text, other.pageCount);
          } on FormatException {
            return (content: null, pages: 0, rangeError: true);
          } on ArgumentError {
            return (content: null, pages: 0, rangeError: true);
          }
        }
        final c = InsertPdfPages(other.path, password: other.password, ranges: ranges);
        return (
          content: c,
          pages: insertedPageCount(c, otherPageCount: other.pageCount),
          rangeError: false,
        );
    }
  }

  Future<void> _addImage() async {
    final bytes = await ref.read(pdfFilePickerProvider).pickImageBytes();
    if (!mounted || bytes == null) return;
    if (!isPngOrJpeg(bytes)) {
      showToolMessage(context, context.l10n.insert_needImage);
      return;
    }
    setState(() => _images.add(bytes));
  }

  Future<void> _pickOther() async {
    final picked = await ref.read(pdfFilePickerProvider).pickPdfs();
    if (!mounted || picked.isEmpty) return;
    final loaded = await loadPdfInput(context, ref, picked.first);
    if (!mounted || loaded == null) return;
    setState(() => _other = loaded);
  }

  Future<void> _insert() async {
    final src = input;
    if (src == null) return;
    final after = _insertAfter(src.pageCount);
    final content = _content().content;
    if (after == null || content == null) return;
    final out = await newOutputPath(ref, suffixedName(src.path, 'inserted'));
    if (!mounted) return;
    final engine = ref.read(insertPagesEngineProvider);
    final result = await runToolJob<String>(
      context,
      title: context.l10n.core_processing,
      job: (onProgress, token) => engine.insertPages(
        src.path,
        after,
        content,
        out,
        password: src.password,
        onProgress: onProgress,
        cancelToken: token,
      ),
    );
    if (result == null || !mounted) return;
    await finish([result]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final title = l.core_toolInsertPages;
    final res = results;
    if (res != null) {
      return ToolScaffold(
        title: title,
        body: ToolResultView(paths: res, onDone: () => context.pop()),
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
    final after = _insertAfter(src.pageCount);
    final plan = _content();
    final ready = after != null && plan.content != null;
    return ToolScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          PdfInputCard(input: src, onChange: pickNew),
          const SizedBox(height: 16),
          _positionCard(context, src, after),
          const SizedBox(height: 16),
          _contentCard(context, plan.rangeError),
          if (ready) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Symbols.description_rounded,
                  size: 18,
                  color: context.tokens.primaryText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.insert_resultPages(src.pageCount + plan.pages),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.tokens.text,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          NoteBanner(l.tools_noteLosesFeatures),
        ],
      ),
      bottom: PrimaryActionButton(
        label: l.insert_action,
        icon: Symbols.note_add_rounded,
        onPressed: ready ? _insert : null,
      ),
    );
  }

  Widget _positionCard(BuildContext context, PdfInput src, int? after) {
    final l = context.l10n;
    final selected = _where == InsertWhere.afterPage ? after : null;
    return ToolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ToolSectionLabel(l.insert_position),
          ToolChipWrap(
            children: [
              for (final (where, label) in [
                (InsertWhere.start, l.insert_atStart),
                (InsertWhere.afterPage, l.insert_afterPage),
                (InsertWhere.end, l.insert_atEnd),
              ])
                ToolChoiceChip(
                  label: label,
                  selected: _where == where,
                  onTap: () => setState(() => _where = where),
                ),
            ],
          ),
          if (_where == InsertWhere.afterPage) ...[
            const SizedBox(height: 16),
            AppTextField(
              controller: _afterCtl,
              labelText: l.insert_afterPageLabel,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              errorText: after == null
                  ? l.insert_afterPageInvalid(src.pageCount)
                  : null,
            ),
            const SizedBox(height: 12),
            ToolHintText(l.insert_afterPageHint),
            const SizedBox(height: 10),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: src.pageCount,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _ThumbTile(
                  key: ValueKey('insert-after-${i + 1}'),
                  index: i,
                  selected: selected == i + 1,
                  thumbs: _thumbs,
                  onTap: () => setState(() {
                    _afterCtl.text = '${i + 1}';
                  }),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _contentCard(BuildContext context, bool rangeError) {
    final l = context.l10n;
    final t = context.tokens;
    final other = _other;
    return ToolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ToolSectionLabel(l.insert_content),
          ToolChipWrap(
            children: [
              for (final (kind, label) in [
                (_Kind.blank, l.insert_typeBlank),
                (_Kind.images, l.insert_typeImages),
                (_Kind.pdf, l.insert_typePdf),
              ])
                ToolChoiceChip(
                  label: label,
                  selected: _kind == kind,
                  onTap: () => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: 16),
          switch (_kind) {
            _Kind.blank => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.insert_blankCount,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.text,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l.insert_fewer,
                      icon: const Icon(Symbols.remove_rounded),
                      onPressed: _blankCount > 1
                          ? () => setState(() => _blankCount--)
                          : null,
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '$_blankCount',
                        key: const ValueKey('insert-blank-count'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: t.text,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l.insert_more,
                      icon: const Icon(Symbols.add_rounded),
                      onPressed: _blankCount < maxInsertBlankPages
                          ? () => setState(() => _blankCount++)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ToolHintText(l.insert_blankSizeNote),
              ],
            ),
            _Kind.images => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_images.isEmpty)
                  ToolHintText(l.insert_imagesEmpty)
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < _images.length; i++)
                        _ImageTile(
                          key: ValueKey('insert-image-$i'),
                          bytes: _images[i],
                          position: i + 1,
                          onRemove: () => setState(() => _images.removeAt(i)),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _addImage,
                    icon: const Icon(Symbols.add_photo_alternate_rounded),
                    label: Text(l.insert_addImage),
                  ),
                ),
                const SizedBox(height: 16),
                ToolSectionLabel(l.insert_imageFit),
                ToolChipWrap(
                  children: [
                    for (final (fit, label) in [
                      (InsertImageFit.a4, l.insert_fitA4),
                      (InsertImageFit.neighbor, l.insert_fitNeighbor),
                    ])
                      ToolChoiceChip(
                        label: label,
                        selected: _fit == fit,
                        onTap: () => setState(() => _fit = fit),
                      ),
                  ],
                ),
              ],
            ),
            _Kind.pdf => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (other == null) ...[
                  ToolHintText(l.insert_pdfNeedFile),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _pickOther,
                      icon: const Icon(Symbols.upload_file_rounded),
                      label: Text(l.tools_pickPdf),
                    ),
                  ),
                ] else ...[
                  ToolFileRow(
                    path: other.path,
                    info: pdfInputInfo(context, other),
                    locked: other.password != null,
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                    trailing: TextButton(
                      onPressed: _pickOther,
                      child: Text(l.tools_changeFile),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ToolChipWrap(
                    children: [
                      ToolChoiceChip(
                        label: l.insert_pdfAll,
                        selected: _otherAll,
                        onTap: () => setState(() => _otherAll = true),
                      ),
                      ToolChoiceChip(
                        label: l.insert_pdfRange,
                        selected: !_otherAll,
                        onTap: () => setState(() => _otherAll = false),
                      ),
                    ],
                  ),
                  if (!_otherAll) ...[
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _rangesCtl,
                      labelText: l.tools_splitRangesLabel,
                      hintText: l.tools_splitRangesHint,
                      keyboardType: TextInputType.text,
                      onChanged: (_) => setState(() {}),
                      errorText: rangeError
                          ? l.tools_splitInvalidRange(other.pageCount)
                          : null,
                    ),
                  ],
                ],
              ],
            ),
          },
        ],
      ),
    );
  }
}

/// Ô trang nhỏ trong dải chọn "sau trang N": ảnh thu nhỏ (hoặc số trang), viền đỏ khi chọn,
/// vạch đỏ bên phải = chỗ sẽ chèn.
class _ThumbTile extends StatelessWidget {
  const _ThumbTile({
    super.key,
    required this.index,
    required this.selected,
    required this.thumbs,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final _InsertThumbnails? thumbs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final placeholder = Center(
      child: Text(
        '${index + 1}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black38,
        ),
      ),
    );
    final th = thumbs;
    final image = th == null
        ? placeholder
        : FutureBuilder<Uint8List?>(
            future: th.thumbnail(index),
            builder: (context, snap) {
              final data = snap.data;
              if (data == null) return placeholder;
              return Image.memory(data, fit: BoxFit.contain, gaplessPlayback: true);
            },
          );
    return Semantics(
      button: true,
      selected: selected,
      label: l.tools_pageNumber(index + 1),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: [
                Container(
                  width: 62,
                  height: 84,
                  decoration: BoxDecoration(
                    // Trang giấy luôn trắng (cả giao diện tối).
                    color: Colors.white,
                    border: selected
                        ? Border.all(color: AppColors.primary, width: 2.5)
                        : Border.all(color: t.lineStrong),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(2),
                  child: image,
                ),
                const SizedBox(height: 6),
                Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? t.primaryText : t.textMuted,
                  ),
                ),
              ],
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Container(
                width: 3,
                height: 84,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ô ảnh đã chọn: ảnh thu nhỏ, số thứ tự, nút bỏ.
class _ImageTile extends StatelessWidget {
  const _ImageTile({
    super.key,
    required this.bytes,
    required this.position,
    required this.onRemove,
  });

  final Uint8List bytes;
  final int position;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: t.surface2,
              border: Border.all(color: t.lineStrong),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              cacheWidth: 160,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox(),
            ),
          ),
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$position',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRemove,
                child: Tooltip(
                  message: context.l10n.tools_remove,
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Symbols.close_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nạp ảnh thu nhỏ từng trang theo yêu cầu, có nhớ (như màn Sắp xếp). Không mở được
/// tài liệu render → mọi ô trả `null`.
class _InsertThumbnails {
  _InsertThumbnails(this._open);

  final Future<PdfRenderDocument> Function() _open;
  Future<PdfRenderDocument?>? _doc;
  final Map<int, Future<Uint8List?>> _cache = {};
  bool _disposed = false;

  Future<PdfRenderDocument?> _document() => _doc ??= () async {
    try {
      return await _open();
    } catch (_) {
      return null;
    }
  }();

  Future<Uint8List?> thumbnail(int index) => _cache.putIfAbsent(index, () async {
    final doc = await _document();
    if (doc == null || _disposed) return null;
    try {
      return await doc.renderThumbnail(index, maxSide: 160);
    } catch (_) {
      return null;
    }
  });

  void dispose() {
    _disposed = true;
    _doc?.then((d) => d?.close());
  }
}
