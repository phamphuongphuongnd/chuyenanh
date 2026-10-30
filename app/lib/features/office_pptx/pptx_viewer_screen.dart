// Màn xem PPTX: vuốt từng slide, dải thumbnail, ghi chú, tuỳ chọn hiện slide ẩn.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:pptx_reader/pptx_reader.dart';

import '../../core/errors/app_error.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/doc_type.dart';
import '../../core/widgets/empty_state.dart';
import 'office_pptx_providers.dart';
import 'pptx_layout.dart';
import '../office_viewer/widgets/office_common.dart'
    show OfficeBottomBar, OfficeSearchBar, OfficeViewerAppBar, officeHeaderColor;
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
        appBar: OfficeViewerAppBar(category: DocCategory.ppt, title: title),
        body: Center(
          child: CircularProgressIndicator(
            color: officeHeaderColor(DocCategory.ppt),
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: OfficeViewerAppBar(category: DocCategory.ppt, title: title),
        body: EmptyState(
          icon: Symbols.error_rounded,
          title: appErrorMessage(context, AppError.from(e)),
          actionLabel: context.l10n.core_retry,
          onAction: () => ref.invalidate(pptxDeckProvider(path)),
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
    final t = context.tokens;
    final accent = officeHeaderColor(DocCategory.ppt);
    return Scaffold(
      appBar: OfficeViewerAppBar(
        category: DocCategory.ppt,
        title: widget.title,
        actions: [
          IconButton(
            tooltip: l.office_search,
            icon: const Icon(Symbols.search_rounded),
            onPressed: () => setState(() => _searching = !_searching),
          ),
          IconButton(
            tooltip: l.office_zoomOut,
            icon: const Icon(Symbols.zoom_out_rounded),
            onPressed: () => _zoomBy(-_zoomStep),
          ),
          IconButton(
            tooltip: l.office_zoomIn,
            icon: const Icon(Symbols.zoom_in_rounded),
            onPressed: () => _zoomBy(_zoomStep),
          ),
          IconButton(
            tooltip: l.pptx_notes,
            // Đang bật ghi chú: icon đặc (FILL 1).
            icon: Icon(Symbols.sticky_note_2_rounded, fill: _showNotes ? 1 : 0),
            onPressed: () => setState(() {
              _showNotes = !_showNotes;
              if (_searching) _runSearch();
            }),
          ),
          if (_hasHidden)
            IconButton(
              tooltip: _showHidden ? l.pptx_hideHidden : l.pptx_showHidden,
              icon: Icon(
                _showHidden
                    ? Symbols.visibility_rounded
                    : Symbols.visibility_off_rounded,
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
              category: DocCategory.ppt,
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
                  ? EmptyState(
                      icon: Symbols.slideshow_rounded,
                      title: l.pptx_emptyDeck,
                    )
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
                        OfficeBottomBar(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  l.pptx_slideOf(page + 1, indexes.length),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: t.textMuted,
                                  ),
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
                                        // Bo 8; viền vẽ đè lên ảnh slide để không bị che.
                                        child: Container(
                                          height: _thumbH,
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            color: t.surface2,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          foregroundDecoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: selected
                                                  ? accent
                                                  : t.lineStrong,
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
                                                Positioned(
                                                  right: 3,
                                                  top: 3,
                                                  child: Icon(
                                                    Symbols
                                                        .visibility_off_rounded,
                                                    size: 14,
                                                    color: t.textMuted,
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
    final t = context.tokens;
    final text = slide.notesText?.trim();
    final has = text != null && text.isNotEmpty;
    // Nền surface bo 16 hai góc trên, nối liền thanh đáy (số slide + thumbnail) bên dưới.
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 140),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Text(
          has ? text : l.pptx_noNotes,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: has ? t.text : t.textMuted,
          ),
        ),
      ),
    );
  }
}
