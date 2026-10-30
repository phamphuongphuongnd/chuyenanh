import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;

import '../../core/errors/app_error.dart';
import '../../core/l10n/l10n.dart';
import '../../core/navigation/open_file_args.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/doc_type.dart';
import '../../core/widgets/widgets.dart';
import '../office_viewer/data/text_decoder.dart'
    show findHitsLimited, largeTextChars;
import '../office_viewer/logic/text_search.dart';
import '../office_viewer/widgets/office_common.dart';
import 'data/reflow_loader.dart';
import 'logic/reflow_document.dart';
import 'logic/reflow_prefs.dart';
import 'reflow_args.dart';
import 'reflow_hooks.dart';

/// Chế độ đọc dàn lại chữ (`Routes.reflow`): trích chữ PDF, dựng lại tiêu đề / đoạn / danh sách / bảng
/// rồi hiện thành cột chữ chảy theo màn. Đổi cỡ chữ (chụm 2 ngón, A−/A+), nền đọc, giãn dòng; tìm chữ;
/// đọc to (`ReadAloudBar`, qua [reflowReadAloudBuilderProvider]); dịch (`showTranslateSheet`, qua
/// [reflowTranslatorProvider]).
class ReflowScreen extends ConsumerStatefulWidget {
  const ReflowScreen({
    super.key,
    required this.args,
    this.mode = ReflowMode.read,
  });

  final OpenFileArgs args;

  /// [ReflowMode.readAloud] = mở sẵn thanh đọc to; [ReflowMode.translate] = mở bảng dịch trang đang đọc.
  final ReflowMode mode;

  @override
  ConsumerState<ReflowScreen> createState() => _ReflowScreenState();
}

class _ReflowScreenState extends ConsumerState<ReflowScreen> {
  ReflowDocument? _doc;
  List<String> _texts = const [];
  AppError? _error;
  bool _loading = true;

  final _scroller = IndexedScroller();
  final _listKey = GlobalKey();

  /// Chỉ số các dòng đã từng dựng (để tìm dòng đang thấy trên màn).
  final Set<int> _built = {};

  final _searchCtrl = TextEditingController();
  bool _searching = false;
  List<SearchHit> _hits = const [];
  int _current = 0;
  Timer? _debounce;
  int _seq = 0;

  late bool _readAloud = widget.mode == ReflowMode.readAloud;

  /// Dòng đang được đọc to (tô nhẹ); null = không đọc.
  int? _speakingItem;

  String get _path => widget.args.path;
  String get _fileName => p.basename(_path);
  bool get _hasText => _doc?.hasText ?? false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- Mở file / mật khẩu ---------------------------------------------------

  void _fail(AppError error) {
    if (!mounted) return;
    setState(() {
      _error = error;
      _loading = false;
    });
  }

  /// Trích chữ; cần mật khẩu (chưa có / sai) thì hỏi rồi thử lại, huỷ thì rời màn.
  Future<void> _open() async {
    final loader = ref.read(reflowLoaderProvider);
    String? password = widget.args.password;
    String? errorText;
    while (true) {
      try {
        final doc = await loader(_path, password: password);
        if (!mounted) return;
        setState(() {
          _doc = doc;
          _texts = doc.itemTexts;
          _loading = false;
        });
        _afterLoaded(doc);
        return;
      } on PasswordRequired {
        errorText = null;
      } on WrongPassword {
        if (!mounted) return;
        errorText = context.l10n.core_errorWrongPassword;
      } on AppError catch (e) {
        _fail(e);
        return;
      } catch (e) {
        _fail(CorruptFile('$e'));
        return;
      }
      if (!mounted) return;
      password = await showPasswordDialog(
        context,
        message: context.l10n.core_passwordDialogMessage(_fileName),
        errorText: errorText,
      );
      if (!mounted) return;
      if (password == null) {
        Navigator.of(context).maybePop();
        return;
      }
    }
  }

  /// Cuộn tới trang mở đầu; chế độ dịch thì mở luôn bảng dịch cho trang đó.
  void _afterLoaded(ReflowDocument doc) {
    if (!doc.hasText) return;
    final page = widget.args.initialPage ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (page > 0) {
        await _scroller.jumpTo(
          doc.firstItemOfPage(page),
          doc.items.length,
          alignment: 0,
        );
      }
      if (!mounted || widget.mode != ReflowMode.translate) return;
      final paragraphs = doc.paragraphsOfPage(page);
      await ref.read(reflowTranslatorProvider)(
        context,
        paragraphs.isEmpty ? doc.paragraphs : paragraphs,
      );
    });
  }

  // --- Tìm chữ ---------------------------------------------------------------

  void _onQuery(String q) {
    _debounce?.cancel();
    final seq = ++_seq;
    final texts = _texts;
    final large = texts.fold<int>(0, (n, t) => n + t.length) > largeTextChars;
    if (!large) {
      _applyHits(findHitsLimited(texts, q));
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final r = await Isolate.run(() => findHitsLimited(texts, q));
      if (!mounted || seq != _seq) return;
      _applyHits(r);
    });
  }

  void _applyHits(({List<SearchHit> hits, bool truncated}) r) {
    setState(() {
      _hits = r.hits;
      _current = 0;
    });
    _goToCurrent();
  }

  void _step(int delta) {
    if (_hits.isEmpty) return;
    setState(() {
      _current = (_current + delta) % _hits.length;
      if (_current < 0) _current += _hits.length;
    });
    _goToCurrent();
  }

  void _goToCurrent() {
    if (_hits.isEmpty) return;
    _scroller.jumpTo(_hits[_current].block, _texts.length);
  }

  void _closeSearch() {
    _debounce?.cancel();
    _seq++;
    _searchCtrl.clear();
    setState(() {
      _searching = false;
      _hits = const [];
      _current = 0;
    });
  }

  // --- Đọc to / dịch ---------------------------------------------------------

  /// [ReadAloudBar] báo đoạn đang đọc (âm = đã dừng) → tô nhẹ + cuộn tới.
  void _onSpeakParagraph(int paragraph) {
    final doc = _doc;
    if (doc == null || !mounted) return;
    final item = paragraph < 0 ? null : doc.itemOfParagraph(paragraph);
    setState(() => _speakingItem = item);
    if (item != null) _scroller.jumpTo(item, doc.items.length);
  }

  /// Khoảng dòng đang thấy trên màn (đầu, cuối); chưa dựng xong → null.
  (int, int)? _visibleRange() {
    final listBox = _listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || !listBox.hasSize) return null;
    final top = listBox.localToGlobal(Offset.zero).dy;
    final bottom = top + listBox.size.height;
    int? first;
    int? last;
    for (final i in _built.toList()) {
      final box = _scroller.keyFor(i).currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) {
        _built.remove(i);
        continue;
      }
      final y = box.localToGlobal(Offset.zero).dy;
      if (y + box.size.height <= top || y >= bottom) continue;
      first = first == null ? i : math.min(first, i);
      last = last == null ? i : math.max(last, i);
    }
    return first == null ? null : (first, last!);
  }

  /// Dịch đoạn đang thấy (không xác định được → cả tài liệu) hoặc cả tài liệu.
  Future<void> _translate({required bool all}) async {
    final doc = _doc;
    if (doc == null || !doc.hasText) return;
    var paragraphs = doc.paragraphs;
    if (!all) {
      final range = _visibleRange();
      if (range != null) {
        final visible = doc.paragraphsInRange(range.$1, range.$2);
        if (visible.isNotEmpty) paragraphs = visible;
      }
    }
    await ref.read(reflowTranslatorProvider)(context, paragraphs);
  }

  Future<void> _openDisplaySheet() =>
      showAppSheet<void>(context, builder: (_) => const _DisplaySheet());

  // --- Giao diện ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(reflowPrefsProvider);
    final doc = _doc;
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      child: Scaffold(
        backgroundColor: _hasText ? prefs.theme.background : null,
        appBar: _buildAppBar(context),
        body: Column(
          children: [
            if (_searching)
              OfficeSearchBar(
                key: const Key('reflow_searchBar'),
                category: DocCategory.pdf,
                controller: _searchCtrl,
                onChanged: _onQuery,
                current: _hits.isEmpty ? 0 : _current + 1,
                total: _hits.length,
                onPrev: () => _step(-1),
                onNext: () => _step(1),
                onClose: _closeSearch,
              ),
            Expanded(child: _buildBody(context, prefs)),
          ],
        ),
        bottomNavigationBar: _readAloud && doc != null && doc.hasText
            ? ref.watch(reflowReadAloudBuilderProvider)(
                doc.paragraphs,
                _onSpeakParagraph,
              )
            : null,
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final l = context.l10n;
    final header = AppColors.headerForCategory(DocCategory.pdf);
    final actionStyle = IconButton.styleFrom(
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white54,
    );
    final hasText = _hasText;

    PopupMenuItem<bool> translateItem(bool all, IconData icon, String label) =>
        PopupMenuItem<bool>(
          value: all,
          child: Row(
            children: [
              Icon(icon, size: 22, color: context.tokens.textMuted),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: context.tokens.text,
                  ),
                ),
              ),
            ],
          ),
        );

    return AppBar(
      backgroundColor: header,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        fontFamily: kUiFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      title: Text(_fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          key: const Key('reflow_searchButton'),
          tooltip: l.office_search,
          style: actionStyle,
          icon: const Icon(Symbols.search_rounded),
          onPressed: hasText
              ? () => _searching ? _closeSearch() : setState(() => _searching = true)
              : null,
        ),
        IconButton(
          key: const Key('reflow_readAloudButton'),
          tooltip: _readAloud ? l.reading_hideReadAloud : l.reading_menuReadAloud,
          style: actionStyle,
          icon: Icon(
            Symbols.record_voice_over_rounded,
            fill: _readAloud ? 1 : 0,
          ),
          onPressed: hasText
              ? () => setState(() {
                  _readAloud = !_readAloud;
                  if (!_readAloud) _speakingItem = null;
                })
              : null,
        ),
        PopupMenuButton<bool>(
          key: const Key('reflow_translateButton'),
          tooltip: l.reading_menuTranslate,
          enabled: hasText,
          icon: Icon(
            Symbols.translate_rounded,
            color: hasText ? Colors.white : Colors.white54,
          ),
          menuPadding: const EdgeInsets.all(6),
          onSelected: (all) => _translate(all: all),
          itemBuilder: (_) => [
            translateItem(
              false,
              Symbols.visibility_rounded,
              l.reading_translateVisible,
            ),
            translateItem(
              true,
              Symbols.description_rounded,
              l.reading_translateAll,
            ),
          ],
        ),
        IconButton(
          key: const Key('reflow_displayButton'),
          tooltip: l.reading_display,
          style: actionStyle,
          icon: const Icon(Symbols.format_size_rounded),
          onPressed: _openDisplaySheet,
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ReflowPrefs prefs) {
    final l = context.l10n;
    final error = _error;
    if (error != null) {
      return EmptyState(
        icon: Symbols.error_rounded,
        title: appErrorMessage(context, error),
        message: _fileName,
        actionLabel: l.core_close,
        onAction: () => Navigator.of(context).maybePop(),
      );
    }
    final doc = _doc;
    if (_loading || doc == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppColors.headerForCategory(DocCategory.pdf),
            ),
            const SizedBox(height: 16),
            Text(
              l.reading_loading,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.tokens.textMuted,
              ),
            ),
          ],
        ),
      );
    }
    if (!doc.hasText) {
      return EmptyState(
        key: const Key('reflow_noText'),
        icon: Symbols.image_rounded,
        title: l.reading_noTextTitle,
        message: l.reading_noTextMessage,
        actionLabel: l.reading_openPdfToText,
        onAction: () => context.push(Routes.pdfToText, extra: _path),
      );
    }

    final notifier = ref.read(reflowPrefsProvider.notifier);
    final width = MediaQuery.sizeOf(context).width;
    // Cột chữ tối đa ~720 để dòng không quá dài trên máy tính bảng.
    final side = math.max(20.0, (width - 720) / 2);
    return ColoredBox(
      color: prefs.theme.background,
      child: PinchZoom(
        scale: prefs.fontSize / kReflowDefaultFont,
        min: kReflowMinFont / kReflowDefaultFont,
        max: kReflowMaxFont / kReflowDefaultFont,
        onScaleChanged: (s) => notifier.setFontSize(kReflowDefaultFont * s),
        child: SelectionArea(
          child: KeyedSubtree(
            key: _listKey,
            child: ListView.builder(
              key: const Key('reflow_list'),
              controller: _scroller.controller,
              padding: EdgeInsets.fromLTRB(side, 12, side, 40),
              itemCount: doc.items.length,
              itemBuilder: (context, i) {
                _built.add(i);
                return KeyedSubtree(
                  key: _scroller.keyFor(i),
                  child: _buildItem(context, doc.items[i], i, prefs),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    ReflowItem item,
    int index,
    ReflowPrefs prefs,
  ) {
    final l = context.l10n;
    final theme = prefs.theme;
    final fs = prefs.fontSize;
    final base = TextStyle(
      fontSize: fs,
      height: prefs.lineHeight,
      fontWeight: FontWeight.w400,
      color: theme.foreground,
    );
    final query = _searching ? _searchCtrl.text : '';
    final hit = _hits.isEmpty ? null : _hits[_current];
    final currentStart = hit != null && hit.block == index ? hit.start : null;
    Widget text(TextStyle style) => _HighlightText(
      item.text,
      query: query,
      currentStart: currentStart,
      style: style,
    );

    final Widget child = switch (item.kind) {
      ReflowKind.pageMarker => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            l.reading_pageMarker(item.page + 1),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.muted,
            ),
          ),
        ),
      ),
      ReflowKind.imagePage => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(Symbols.image_rounded, size: 20, color: theme.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.reading_noTextTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: theme.muted,
                ),
              ),
            ),
          ],
        ),
      ),
      ReflowKind.heading => Padding(
        padding: EdgeInsets.only(top: fs * 0.7, bottom: fs * 0.4),
        child: text(
          base.copyWith(
            fontSize: fs * switch (item.level) { 1 => 1.45, 2 => 1.28, _ => 1.14 },
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ),
      ReflowKind.paragraph => Padding(
        padding: EdgeInsets.only(bottom: fs * 0.7),
        child: text(
          item.bold ? base.copyWith(fontWeight: FontWeight.w600) : base,
        ),
      ),
      ReflowKind.listItem => Padding(
        padding: EdgeInsets.only(bottom: fs * 0.35, left: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: fs * 1.5),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(item.marker, style: base),
              ),
            ),
            Expanded(child: text(base)),
          ],
        ),
      ),
      ReflowKind.tableRow => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: theme.muted.withValues(alpha: 0.5),
                width: 3,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 0, 2),
            child: text(base.copyWith(fontSize: fs * 0.92)),
          ),
        ),
      ),
    };

    if (index != _speakingItem) return child;
    return DecoratedBox(
      key: const Key('reflow_speaking'),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(
          alpha: theme == ReflowTheme.dark ? 0.24 : 0.12,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

/// Chữ có tô kết quả tìm: khớp = vàng, kết quả đang chọn = cam (như trình xem TXT).
class _HighlightText extends StatelessWidget {
  const _HighlightText(
    this.text, {
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

/// Bảng "Hiển thị": cỡ chữ A−/A+, nền đọc, giãn dòng. Đổi là áp dụng ngay (nhớ trong phiên).
class _DisplaySheet extends ConsumerWidget {
  const _DisplaySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final prefs = ref.watch(reflowPrefsProvider);
    final notifier = ref.read(reflowPrefsProvider.notifier);
    final spacingLabels = [
      l.reading_spacingCompact,
      l.reading_spacingNormal,
      l.reading_spacingWide,
    ];

    Widget label(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Text(
        s,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: t.textMuted,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(l.reading_display),
        label(l.reading_fontSize),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              _FontButton(
                key: const Key('reflow_fontSmaller'),
                label: 'A−',
                small: true,
                tooltip: l.reading_fontSmaller,
                onTap: prefs.fontSize > kReflowMinFont
                    ? () => notifier.setFontSize(prefs.fontSize - 2)
                    : null,
              ),
              Expanded(
                child: Text(
                  '${prefs.fontSize.round()}',
                  key: const Key('reflow_fontValue'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
              ),
              _FontButton(
                key: const Key('reflow_fontLarger'),
                label: 'A+',
                tooltip: l.reading_fontLarger,
                onTap: prefs.fontSize < kReflowMaxFont
                    ? () => notifier.setFontSize(prefs.fontSize + 2)
                    : null,
              ),
            ],
          ),
        ),
        label(l.reading_background),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              for (final (i, theme) in ReflowTheme.values.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _Choice(
                    key: Key('reflow_theme_${theme.name}'),
                    label: switch (theme) {
                      ReflowTheme.light => l.reading_themeLight,
                      ReflowTheme.sepia => l.reading_themeSepia,
                      ReflowTheme.dark => l.reading_themeDark,
                    },
                    background: theme.background,
                    foreground: theme.foreground,
                    selected: prefs.theme == theme,
                    onTap: () => notifier.setTheme(theme),
                  ),
                ),
              ],
            ],
          ),
        ),
        label(l.reading_lineSpacing),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(
            children: [
              for (var i = 0; i < kReflowLineHeights.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _Choice(
                    key: Key('reflow_spacing_$i'),
                    label: spacingLabels[i],
                    background: t.surface,
                    foreground: t.text,
                    selected: prefs.lineHeight == kReflowLineHeights[i],
                    onTap: () => notifier.setLineHeight(kReflowLineHeights[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Nút tròn "A−" / "A+" (viền `lineStrong`, vùng chạm 48).
class _FontButton extends StatelessWidget {
  const _FontButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.small = false,
  });

  final String label;
  final String tooltip;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: t.surface,
        shape: CircleBorder(side: BorderSide(color: t.lineStrong)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: small ? 14 : 19,
                  fontWeight: FontWeight.w700,
                  color: enabled ? t.text : t.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô chọn (nền đọc / giãn dòng): bo 14, viền đỏ 2 khi đang chọn.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(14);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppColors.primary : t.lineStrong,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
