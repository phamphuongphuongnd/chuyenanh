import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/navigation/open_file_args.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/db/app_database.dart';
import '../../../engines/pdf/pdf_security.dart';
import '../logic/bookmark_logic.dart';
import '../logic/outline.dart';
import '../logic/reader_prefs.dart';
import '../reader_viewer.dart';
import '../shortcut/shortcut_service.dart';
import '../widgets/bookmarks_sheet.dart';
import '../widgets/outline_sheet.dart';
import '../widgets/page_indicator_bar.dart';
import '../widgets/reader_search_bar.dart';

enum _Menu {
  bookmarks,
  outline,
  goToPage,
  darkMode,
  horizontal,
  singlePage,
  bookmarkDocument,
  print,
  shortcut,
  toImages,
}

/// Trình đọc PDF (`Routes.pdfReader`).
///
/// Mở file bằng viewer; nếu cần mật khẩu thì hỏi bằng `showPasswordDialog` rồi giải mã
/// bằng `pdfSecurityProvider.decrypt` và mở lại từ bytes.
class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({super.key, required this.args});

  final OpenFileArgs args;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  late final PdfViewerController _controller;
  final TextEditingController _searchText = TextEditingController();

  /// Bytes đã giải mã (PDF có mật khẩu). null = mở thẳng từ file.
  Uint8List? _bytes;
  bool _unlocking = false;
  AppError? _error;

  int _page = 1;
  int _pageCount = 0;
  List<OutlineEntry> _outline = const [];

  /// Đổi giá trị để dựng lại viewer (đổi cách hiển thị / mở lại bằng bytes).
  int _generation = 0;

  bool _searching = false;
  PdfTextSearchResult? _result;

  String get _path => widget.args.path;
  String get _fileName => p.basename(_path);
  bool get _loaded => _pageCount > 0;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(readerControllerFactoryProvider)();
    _page = (widget.args.initialPage ?? 0) + 1;
    if (_page < 1) _page = 1;

    if (!File(_path).existsSync()) {
      _error = const CorruptFile('not found');
    } else if (widget.args.password != null) {
      _unlocking = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _unlock(password: widget.args.password),
      );
    }
  }

  @override
  void dispose() {
    _searchText.dispose();
    _controller.dispose();
    super.dispose();
  }

  // --- Mở file / mật khẩu ---------------------------------------------------

  void _fail(AppError error) {
    if (!mounted) return;
    setState(() {
      _error = error;
      _unlocking = false;
    });
  }

  /// Viewer báo không mở được: kiểm tra có phải do mật khẩu không.
  Future<void> _onLoadFailed(String detail) async {
    if (!mounted || _unlocking || _error != null) return;
    if (_bytes != null) {
      _fail(CorruptFile(detail));
      return;
    }
    setState(() => _unlocking = true);
    try {
      final raw = await File(_path).readAsBytes();
      final encrypted = await ref.read(pdfSecurityProvider).isEncrypted(raw);
      if (!mounted) return;
      if (encrypted) {
        await _unlock(raw: raw);
      } else {
        _fail(CorruptFile(detail));
      }
    } on AppError catch (e) {
      _fail(e);
    } catch (e) {
      _fail(AppError.from(e) is Unknown ? CorruptFile('$e') : AppError.from(e));
    }
  }

  /// Hỏi mật khẩu (nếu chưa có) → giải mã → mở lại bằng bytes.
  Future<void> _unlock({String? password, Uint8List? raw}) async {
    final security = ref.read(pdfSecurityProvider);
    try {
      raw ??= await File(_path).readAsBytes();
    } catch (e) {
      final err = AppError.from(e);
      _fail(err is Unknown ? CorruptFile('$e') : err);
      return;
    }

    String? pw = password;
    String? errorText;
    while (true) {
      if (!mounted) return;
      if (pw == null) {
        pw = await showPasswordDialog(
          context,
          message: context.l10n.core_passwordDialogMessage(_fileName),
          errorText: errorText,
        );
        if (!mounted) return;
        if (pw == null) {
          // Huỷ nhập mật khẩu → rời màn đọc.
          Navigator.of(context).maybePop();
          return;
        }
      }
      try {
        final plain = await security.decrypt(raw, pw);
        if (!mounted) return;
        setState(() {
          _bytes = plain;
          _error = null;
          _unlocking = false;
          _generation++;
        });
        return;
      } on WrongPassword {
        if (!mounted) return;
        errorText = context.l10n.core_errorWrongPassword;
        pw = null;
      } on AppError catch (e) {
        _fail(e);
        return;
      } catch (e) {
        _fail(CorruptFile('$e'));
        return;
      }
    }
  }

  // --- Hành động -------------------------------------------------------------

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _jumpTo(int page) {
    if (page < 1 || page > _pageCount) return;
    _controller.jumpToPage(page);
  }

  Future<void> _goToPageDialog() async {
    final target = await showGoToPageDialog(
      context,
      pageCount: _pageCount,
      current: _page,
    );
    if (target != null) _jumpTo(target);
  }

  Future<void> _togglePageBookmark() async {
    final dao = ref.read(appDatabaseProvider).bookmarksDao;
    final added = await togglePageBookmark(dao, _path, _page - 1);
    if (!mounted) return;
    final l = context.l10n;
    _snack(added ? l.reader_bookmarkAdded : l.reader_bookmarkRemoved);
  }

  Future<void> _toggleDocumentBookmark() async {
    final dao = ref.read(appDatabaseProvider).bookmarksDao;
    final added = await toggleDocumentBookmark(dao, _path);
    if (!mounted) return;
    final l = context.l10n;
    _snack(added ? l.reader_bookmarkAdded : l.reader_bookmarkRemoved);
  }

  Future<void> _print() async {
    try {
      final bytes = _bytes ?? await File(_path).readAsBytes();
      await ref.read(pdfPrinterProvider)(bytes, _fileName);
    } catch (e) {
      if (!mounted) return;
      _snack(appErrorMessage(context, AppError.from(e)));
    }
  }

  Future<void> _addShortcut() async {
    final label = p.basenameWithoutExtension(_path);
    final ok = await ref
        .read(shortcutServiceProvider)
        .requestPinShortcut(path: _path, label: label);
    if (!mounted) return;
    final l = context.l10n;
    _snack(ok ? l.reader_shortcutRequested : l.reader_shortcutFailed);
  }

  static const double _zoomStep = 0.25;
  static const double _zoomMin = 1.0;
  static const double _zoomMax = 3.0;

  /// Đổi mức phóng đại theo bước 0.25, kẹp 1.0–3.0 (giới hạn của syncfusion).
  void _zoomBy(double delta) {
    final next = (_controller.zoomLevel + delta).clamp(_zoomMin, _zoomMax);
    _controller.zoomLevel = next.toDouble();
  }

  void _startSearch() => setState(() => _searching = true);

  void _runSearch(String query) {
    final text = query.trim();
    if (text.isEmpty) return;
    setState(() => _result = _controller.searchText(text));
  }

  void _closeSearch() {
    _result?.clear();
    _searchText.clear();
    setState(() {
      _searching = false;
      _result = null;
    });
  }

  Future<void> _onMenu(_Menu item) async {
    final prefs = ref.read(readerPrefsProvider);
    final notifier = ref.read(readerPrefsProvider.notifier);
    switch (item) {
      case _Menu.bookmarks:
        await showBookmarksSheet(
          context,
          path: _path,
          onOpenPage: (page0) => _jumpTo(page0 + 1),
        );
      case _Menu.outline:
        await showOutlineSheet(
          context,
          entries: _outline,
          onSelect: (e) {
            final page = e.pageNumber;
            if (page != null) {
              _jumpTo(page);
            } else {
              _controller.jumpToBookmark(e.bookmark);
            }
          },
        );
      case _Menu.goToPage:
        await _goToPageDialog();
      case _Menu.darkMode:
        await notifier.setDarkMode(!prefs.darkMode);
      case _Menu.horizontal:
        await notifier.setHorizontal(!prefs.horizontal);
      case _Menu.singlePage:
        await notifier.setSinglePage(!prefs.singlePage);
      case _Menu.bookmarkDocument:
        await _toggleDocumentBookmark();
      case _Menu.print:
        await _print();
      case _Menu.shortcut:
        await _addShortcut();
      case _Menu.toImages:
        await context.push(Routes.pdfToImage, extra: _path);
    }
  }

  // --- Giao diện ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(readerPrefsProvider);
    final bookmarks =
        ref.watch(bookmarksForPathProvider(_path)).value ?? const <Bookmark>[];

    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      child: Scaffold(
        appBar: _buildAppBar(context, prefs, bookmarks),
        body: Column(
          children: [
            if (_searching)
              ReaderSearchBar(
                textController: _searchText,
                result: _result,
                onSubmitted: _runSearch,
                onPrevious: () => _result?.previousInstance(),
                onNext: () => _result?.nextInstance(),
                onClose: _closeSearch,
              ),
            Expanded(child: _buildBody(context, prefs)),
          ],
        ),
        bottomNavigationBar: _loaded && _error == null
            ? PageIndicatorBar(
                page: _page.clamp(1, _pageCount),
                pageCount: _pageCount,
                onPrevious: _controller.previousPage,
                onNext: _controller.nextPage,
                onJump: _jumpTo,
              )
            : null,
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    ReaderPrefs prefs,
    List<Bookmark> bookmarks,
  ) {
    final l = context.l10n;
    final pageMarked = isPageBookmarked(bookmarks, _page - 1);
    final docMarked = isDocumentBookmarked(bookmarks);
    final shortcutOk = ref.watch(shortcutSupportedProvider).value ?? false;

    PopupMenuItem<_Menu> item(_Menu m, IconData icon, String label) =>
        PopupMenuItem<_Menu>(
          value: m,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon),
            title: Text(label),
          ),
        );

    CheckedPopupMenuItem<_Menu> check(_Menu m, bool on, String label) =>
        CheckedPopupMenuItem<_Menu>(value: m, checked: on, child: Text(label));

    return AppBar(
      title: Text(_fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          key: const Key('reader_searchButton'),
          tooltip: l.reader_search,
          icon: const Icon(Icons.search),
          onPressed: _loaded ? _startSearch : null,
        ),
        IconButton(
          key: const Key('reader_zoomOutButton'),
          tooltip: l.office_zoomOut,
          icon: const Icon(Icons.zoom_out),
          onPressed: _loaded ? () => _zoomBy(-_zoomStep) : null,
        ),
        IconButton(
          key: const Key('reader_zoomInButton'),
          tooltip: l.office_zoomIn,
          icon: const Icon(Icons.zoom_in),
          onPressed: _loaded ? () => _zoomBy(_zoomStep) : null,
        ),
        IconButton(
          key: const Key('reader_bookmarkButton'),
          tooltip: pageMarked
              ? l.reader_removePageBookmark
              : l.reader_bookmarkPage,
          icon: Icon(pageMarked ? Icons.bookmark : Icons.bookmark_border),
          onPressed: _loaded ? _togglePageBookmark : null,
        ),
        PopupMenuButton<_Menu>(
          key: const Key('reader_menuButton'),
          tooltip: l.reader_more,
          onSelected: _onMenu,
          itemBuilder: (context) => [
            item(_Menu.bookmarks, Icons.bookmarks_outlined, l.reader_bookmarks),
            item(_Menu.outline, Icons.format_list_bulleted, l.reader_outline),
            item(_Menu.goToPage, Icons.pin_outlined, l.reader_goToPage),
            const PopupMenuDivider(),
            check(_Menu.darkMode, prefs.darkMode, l.reader_darkMode),
            check(
              _Menu.horizontal,
              prefs.horizontal,
              l.reader_horizontalScroll,
            ),
            check(_Menu.singlePage, prefs.singlePage, l.reader_singlePage),
            const PopupMenuDivider(),
            item(
              _Menu.bookmarkDocument,
              docMarked
                  ? Icons.collections_bookmark
                  : Icons.collections_bookmark_outlined,
              docMarked
                  ? l.reader_removeDocumentBookmark
                  : l.reader_bookmarkDocument,
            ),
            item(_Menu.print, Icons.print_outlined, l.reader_print),
            if (shortcutOk)
              item(
                _Menu.shortcut,
                Icons.add_to_home_screen,
                l.reader_addShortcut,
              ),
            item(_Menu.toImages, Icons.image_outlined, l.core_toolPdfToImage),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ReaderPrefs prefs) {
    final error = _error;
    if (error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: appErrorMessage(context, error),
        message: _fileName,
        actionLabel: context.l10n.core_close,
        onAction: () => Navigator.of(context).maybePop(),
      );
    }
    if (_unlocking && _bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final viewer = ref.watch(readerViewerBuilderProvider)(
      context,
      ReaderViewerConfig(
        path: _path,
        bytes: _bytes,
        controller: _controller,
        initialPage: _page < 1 ? 1 : _page,
        horizontal: prefs.horizontal,
        singlePage: prefs.singlePage,
        onLoaded: (count, outline) {
          if (!mounted) return;
          setState(() {
            _pageCount = count;
            _outline = outline;
            if (_page > count) _page = count;
          });
        },
        onPageChanged: (page) {
          if (mounted && page != _page) setState(() => _page = page);
        },
        onLoadFailed: _onLoadFailed,
      ),
    );

    final keyed = KeyedSubtree(
      key: ValueKey('${_generation}_${prefs.horizontal}_${prefs.singlePage}'),
      child: viewer,
    );
    if (!prefs.darkMode) return keyed;
    return ColorFiltered(
      key: const Key('reader_darkFilter'),
      colorFilter: const ColorFilter.matrix(kInvertColorMatrix),
      child: keyed,
    );
  }
}
