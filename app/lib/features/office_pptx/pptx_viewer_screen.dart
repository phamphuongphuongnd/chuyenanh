// Màn xem PPTX: vuốt từng slide, dải thumbnail, ghi chú, tuỳ chọn hiện slide ẩn.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:pptx_reader/pptx_reader.dart';

import '../../core/errors/app_error.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import 'office_pptx_providers.dart';
import 'pptx_layout.dart';
import 'slide_view.dart';

class PptxViewerScreen extends ConsumerWidget {
  const PptxViewerScreen({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pptxDeckProvider(path));
    final title = p.basename(path);
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(title),
          backgroundColor: AppColors.ppt,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          backgroundColor: AppColors.ppt,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  appErrorMessage(context, AppError.from(e)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(pptxDeckProvider(path)),
                  child: Text(context.l10n.core_retry),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (deck) => PptxDeckView(deck: deck, title: title),
    );
  }
}

/// Phần xem một deck đã nạp (tách ra để widget test không cần file).
class PptxDeckView extends StatefulWidget {
  const PptxDeckView({super.key, required this.deck, required this.title});
  final PptxDeck deck;
  final String title;

  @override
  State<PptxDeckView> createState() => _PptxDeckViewState();
}

class _PptxDeckViewState extends State<PptxDeckView> {
  final PageController _pages = PageController();
  final ScrollController _thumbs = ScrollController();
  bool _showHidden = false;
  bool _showNotes = false;
  bool _zoomed = false;
  int _page = 0;

  static const double _thumbH = 64;
  static const double _thumbGap = 8;

  List<int> get _indexes =>
      visibleSlideIndexes(widget.deck, showHidden: _showHidden);

  bool get _hasHidden => widget.deck.slides.any((s) => s.hidden);

  @override
  void dispose() {
    _pages.dispose();
    _thumbs.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int page) {
    // Trang đang zoom bị huỷ không báo lại `onZoomChanged(false)`: tự bỏ khoá vuốt.
    setState(() {
      _page = page;
      _zoomed = false;
    });
    final aspect = widget.deck.slideWidthEmu / widget.deck.slideHeightEmu;
    final step = _thumbH * aspect + _thumbGap;
    if (_thumbs.hasClients) {
      final target = (page * step - 40).clamp(
        0.0,
        _thumbs.position.maxScrollExtent,
      );
      _thumbs.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final indexes = _indexes;
    final deck = widget.deck;
    final page = indexes.isEmpty ? 0 : _page.clamp(0, indexes.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.ppt,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: l.pptx_notes,
            icon: Icon(
              _showNotes ? Icons.sticky_note_2 : Icons.sticky_note_2_outlined,
            ),
            onPressed: () => setState(() => _showNotes = !_showNotes),
          ),
          if (_hasHidden)
            IconButton(
              tooltip: _showHidden ? l.pptx_hideHidden : l.pptx_showHidden,
              icon: Icon(
                _showHidden ? Icons.visibility : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() {
                _showHidden = !_showHidden;
                _page = 0;
                if (_pages.hasClients) _pages.jumpToPage(0);
              }),
            ),
        ],
      ),
      body: indexes.isEmpty
          ? Center(child: Text(l.pptx_emptyDeck))
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    key: ValueKey(_showHidden),
                    controller: _pages,
                    physics: _zoomed
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: indexes.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, i) => _ZoomablePage(
                      onZoomChanged: (z) {
                        if (z != _zoomed) setState(() => _zoomed = z);
                      },
                      child: SlideView(
                        deck: deck,
                        slide: deck.slides[indexes[i]],
                        renderScale: 2.5,
                      ),
                    ),
                  ),
                ),
                if (_showNotes) _NotesPanel(slide: deck.slides[indexes[page]]),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    l.pptx_slideOf(page + 1, indexes.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SizedBox(
                  height: _thumbH + 16,
                  child: ListView.separated(
                    controller: _thumbs,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: indexes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: _thumbGap),
                    itemBuilder: (context, i) {
                      final slide = deck.slides[indexes[i]];
                      final selected = i == page;
                      return Semantics(
                        button: true,
                        label: l.pptx_slideN(i + 1),
                        child: GestureDetector(
                          onTap: () => _goTo(i),
                          child: Container(
                            height: _thumbH,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selected
                                    ? AppColors.ppt
                                    : Colors.grey.shade400,
                                width: selected ? 2.5 : 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                RepaintBoundary(
                                  child: SlideView(
                                    deck: deck,
                                    slide: slide,
                                    renderScale: 0.4,
                                  ),
                                ),
                                if (slide.hidden)
                                  const Positioned(
                                    right: 2,
                                    top: 2,
                                    child: Icon(
                                      Icons.visibility_off,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// Trang slide có zoom 2 ngón; khi đang zoom thì khoá vuốt chuyển trang (báo qua callback).
class _ZoomablePage extends StatefulWidget {
  const _ZoomablePage({required this.child, required this.onZoomChanged});
  final Widget child;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  final TransformationController _c = TransformationController();

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      widget.onZoomChanged(_c.value.getMaxScaleOnAxis() > 1.02);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () => _c.value = Matrix4.identity(),
      child: InteractiveViewer(
        transformationController: _c,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black26)],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesPanel extends StatelessWidget {
  const _NotesPanel({required this.slide});
  final PptxSlide slide;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = slide.notesText?.trim();
    final has = text != null && text.isNotEmpty;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 140),
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        child: Text(
          has ? text : l.pptx_noNotes,
          style: has
              ? null
              : TextStyle(color: Theme.of(context).hintColor),
        ),
      ),
    );
  }
}
