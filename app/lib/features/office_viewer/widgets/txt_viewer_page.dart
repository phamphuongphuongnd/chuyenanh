import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../data/text_decoder.dart';
import '../logic/text_search.dart';
import 'office_common.dart';

/// Cỡ chữ TXT (giữ trong phiên).
class TxtFontSize extends Notifier<double> {
  @override
  double build() => 16;

  void set(double v) => state = v.clamp(10, 40).toDouble();
}

final txtFontSizeProvider = NotifierProvider<TxtFontSize, double>(
  TxtFontSize.new,
);

/// Màn xem TXT: danh sách dòng, chụm để đổi cỡ chữ, tìm chữ, chuyển sang PDF.
class TxtViewerPage extends ConsumerStatefulWidget {
  const TxtViewerPage({super.key, required this.path, required this.content});

  final String path;
  final DecodedText content;

  @override
  ConsumerState<TxtViewerPage> createState() => _TxtViewerPageState();
}

class _TxtViewerPageState extends ConsumerState<TxtViewerPage> {
  late final List<String> _lines = splitLines(widget.content.text);
  final _scroller = IndexedScroller();
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  List<SearchHit> _hits = const [];
  int _current = 0;

  @override
  void dispose() {
    _scroller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    setState(() {
      _hits = findHits(_lines, q);
      _current = 0;
    });
    _goToCurrent();
  }

  void _step(int delta) {
    if (_hits.isEmpty) return;
    setState(() => _current = (_current + delta) % _hits.length);
    if (_current < 0) _current += _hits.length;
    _goToCurrent();
  }

  void _goToCurrent() {
    if (_hits.isEmpty) return;
    _scroller.jumpTo(_hits[_current].block, _lines.length);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fontSize = ref.watch(txtFontSizeProvider);
    final theme = Theme.of(context);
    final notifier = ref.read(txtFontSizeProvider.notifier);
    final query = _searchCtrl.text;
    final curHit = _hits.isEmpty ? null : _hits[_current];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.txt,
        foregroundColor: Colors.white,
        title: Text(p.basename(widget.path), overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l.office_search,
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = !_searching),
          ),
          IconButton(
            tooltip: l.office_zoomOut,
            icon: const Icon(Icons.zoom_out),
            onPressed: () => notifier.set(fontSize - 2),
          ),
          IconButton(
            tooltip: l.office_zoomIn,
            icon: const Icon(Icons.zoom_in),
            onPressed: () => notifier.set(fontSize + 2),
          ),
          IconButton(
            tooltip: l.office_convertToPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () =>
                context.push(Routes.textToPdf, extra: widget.path),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searching)
            OfficeSearchBar(
              color: AppColors.txt,
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
              }),
            ),
          if (widget.content.truncated)
            MaterialBanner(
              content: Text(l.office_truncated),
              actions: const [SizedBox.shrink()],
              dividerColor: Colors.transparent,
            ),
          Expanded(
            child: PinchZoom(
              scale: fontSize / 16,
              min: 10 / 16,
              max: 40 / 16,
              onScaleChanged: (s) => notifier.set(16 * s),
              child: SelectionArea(
                child: ListView.builder(
                  controller: _scroller.controller,
                  padding: const EdgeInsets.all(12),
                  itemCount: _lines.length,
                  itemBuilder: (context, i) => KeyedSubtree(
                    key: _scroller.keyFor(i),
                    child: _Line(
                      text: _lines[i],
                      query: _searching ? query : '',
                      currentStart: curHit != null && curHit.block == i
                          ? curHit.start
                          : null,
                      style: TextStyle(fontSize: fontSize, height: 1.4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              l.office_encodingLabel(widget.content.encoding.label),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.text,
    required this.query,
    required this.currentStart,
    required this.style,
  });

  final String text;
  final String query;
  final int? currentStart;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return Text(' ', style: style);
    if (query.trim().isEmpty) return Text(text, style: style);
    return Text.rich(
      TextSpan(
        children: [
          for (final s in highlightSegments(text, query))
            TextSpan(
              text: s.text,
              style: s.matched
                  ? TextStyle(
                      backgroundColor: s.start == currentStart
                          ? Colors.orange
                          : Colors.yellow,
                      color: Colors.black,
                    )
                  : null,
            ),
        ],
      ),
      style: style,
    );
  }
}
