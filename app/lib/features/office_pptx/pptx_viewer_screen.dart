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
import '../office_viewer/widgets/office_common.dart' show OfficeSearchBar;
import 'pptx_search.dart';
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

  // Tìm kiếm.
  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  List<PptxHit> _hits = const [];
  Map<PptxParagraph, PptxParagraphPos>? _hitIndex;
  int _current = 0;

  // Zoom bằng nút: các trang đang dựng, khoá theo vị trí trang.
  final Map<int, _ZoomablePageState> _zoomPages = {};
  static const double _zoomStep = 0.25;

  static const double _thumbH = 64;
  static const double _thumbGap = 8;

  List<int> get _indexes =>
      visibleSlideIndexes(widget.deck, showHidden: _showHidden);

  bool get _hasHidden => widget.deck.slides.any((s) => s.hidden);

  @override
  void dispose() {
    _pages.dispose();
    _thumbs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _runSearch() {
    _hits = findPptxHits(
      widget.deck,
      _indexes,
      _searchCtrl.text,
      includeNotes: _showNotes,
    );
    _hitIndex = indexPptxParagraphs(widget.deck, _indexes, _searchCtrl.text);
  }

  void _onQuery(String _) {
    setState(() {
      _runSearch();
      _current = 0;
    });
    if (_hits.isNotEmpty) _goTo(_hits[0].page);
  }

  void _step(int d) {
    if (_hits.isEmpty) return;
    setState(() => _current = (_current + d) % _hits.length);
    if (_current < 0) _current += _hits.length;
    _goTo(_hits[_current].page);
  }

  void _zoomBy(double delta) {
    final i = _indexes.isEmpty ? 0 : _page.clamp(0, _indexes.length - 1);
    _zoomPages[i]?.zoomBy(delta);
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
            tooltip: l.office_search,
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = !_searching),
          ),
          IconButton(
            tooltip: l.office_zoomOut,
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _zoomBy(-_zoomStep),
          ),
          IconButton(
            tooltip: l.office_zoomIn,
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _zoomBy(_zoomStep),
          ),
          IconButton(
            tooltip: l.pptx_notes,
            icon: Icon(
              _showNotes ? Icons.sticky_note_2 : Icons.sticky_note_2_outlined,
            ),
            onPressed: () => setState(() {
              _showNotes = !_showNotes;
              if (_searching) _runSearch();
            }),
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
                _current = 0;
                if (_searching) _runSearch();
                if (_pages.hasClients) _pages.jumpToPage(0);
              }),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_searching)
            OfficeSearchBar(
              color: AppColors.ppt,
              controller: _searchCtrl,
              onChanged: _onQuery,
              current: _hits.isEmpty ? 0 : _current + 1,
              total: _hits.length,
              onPrev: () => _step(-1),
              onNext: () => _step(1),
              onClose: () => setState(() {
                _searching = false;
                _searchCtrl.clear();
                _hits = const [];
                _hitIndex = null;
                _current = 0;
              }),
            ),
          Expanded(
            child: PptxSearchHighlight(
              query: _searching ? _searchCtrl.text : '',
              index: _searching ? _hitIndex : null,
              currentSlide: _hits.isEmpty ? -1 : _hits[_current].slideIndex,
              currentOccurrence: currentOccurrenceInSlide(_hits, _current),
              child: indexes.isEmpty
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
                              key: ValueKey('${_showHidden}_$i'),
                              onAttach: (st) => _zoomPages[i] = st,
                              onDetach: (st) {
                                if (_zoomPages[i] == st) _zoomPages.remove(i);
                              },
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
                        if (_showNotes)
                          _NotesPanel(slide: deck.slides[indexes[page]]),
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
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: _thumbGap),
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
            ),
          ),
        ],
      ),
    );
  }
}

/// Trang slide có zoom 2 ngón; khi đang zoom thì khoá vuốt chuyển trang (báo qua callback).
class _ZoomablePage extends StatefulWidget {
  const _ZoomablePage({
    super.key,
    required this.child,
    required this.onZoomChanged,
    required this.onAttach,
    required this.onDetach,
  });
  final Widget child;
  final ValueChanged<bool> onZoomChanged;
  final ValueChanged<_ZoomablePageState> onAttach;
  final ValueChanged<_ZoomablePageState> onDetach;

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  final TransformationController _c = TransformationController();

  static const double _minZoom = 1;
  static const double _maxZoom = 4;

  /// Phóng/thu quanh tâm khung, bước làm tròn theo [delta], trong 1.0–4.0.
  void zoomBy(double delta) {
    final cur = _c.value.getMaxScaleOnAxis();
    final target = ((cur / delta.abs()).round() * delta.abs() + delta).clamp(
      _minZoom,
      _maxZoom,
    );
    if (target <= _minZoom + 1e-6) {
      _c.value = Matrix4.identity();
      return;
    }
    final size = context.size;
    if (size == null) return;
    final f = target / cur;
    final cx = size.width / 2, cy = size.height / 2;
    final t = Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..scaleByDouble(f, f, 1, 1)
      ..translateByDouble(-cx, -cy, 0, 1);
    _c.value = t * _c.value;
  }

  @override
  void initState() {
    super.initState();
    widget.onAttach(this);
    _c.addListener(() {
      widget.onZoomChanged(_c.value.getMaxScaleOnAxis() > 1.02);
    });
  }

  @override
  void dispose() {
    widget.onDetach(this);
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
        maxScale: 4,
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
          style: has ? null : TextStyle(color: Theme.of(context).hintColor),
        ),
      ),
    );
  }
}
