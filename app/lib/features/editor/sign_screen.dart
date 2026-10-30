import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;

import '../../core/errors/app_error.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/output_directory.dart';
import '../../core/widgets/widgets.dart';
import '../../engines/pdf/pdf_render_engine.dart';
import '../../engines/pdf/pdf_sign_engine.dart';
import '../reader/reader_providers.dart';
import 'edited_output.dart';
import 'editor_common.dart';
import 'editor_providers.dart';
import 'page_lru_cache.dart';
import 'signature_image.dart';
import 'signature_overlay.dart';
import 'signature_overlay_model.dart';
import 'signature_pad_sheet.dart';
import 'signature_store.dart';

/// DPI render trang để xem khi đặt chữ ký (đủ nét, không ngốn RAM).
const double kSignPreviewDpi = 110;

/// Danh sách chữ ký đã lưu (mới nhất trước). `invalidate` sau khi lưu / xoá.
final savedSignaturesProvider =
    FutureProvider.autoDispose<List<SignatureEntry>>((ref) async {
      final store = await ref.watch(signatureStoreProvider.future);
      final result = <SignatureEntry>[];
      for (final s in await store.list()) {
        try {
          result.add(SignatureEntry(s, await store.read(s)));
        } on FileSystemException {
          // File vừa bị xoá / hỏng: bỏ qua, không làm hỏng cả danh sách.
        }
      }
      return result;
    });

/// Chữ ký đã lưu kèm nội dung PNG (nhỏ, tối đa [kMaxSavedSignatures] cái) — vẽ thumbnail từ bộ nhớ,
/// không giữ file mở.
class SignatureEntry {
  const SignatureEntry(this.saved, this.png);

  final SavedSignature saved;
  final Uint8List png;
}

/// Nguồn ảnh chữ ký chụp trên giấy.
enum SignaturePhotoSource { gallery, camera }

/// Lấy ảnh chữ ký (byte JPG/PNG). Tách interface để test không cần hộp thoại hệ thống.
abstract interface class SignaturePhotoPicker {
  /// Huỷ → `null`. Ném [PermissionDenied] nếu bị từ chối quyền ảnh / camera.
  Future<Uint8List?> pick(SignaturePhotoSource source);
}

/// Dùng `image_picker` (thư viện ảnh hoặc camera). Giới hạn cạnh 2400 px để plugin thu nhỏ sẵn
/// (đồng thời đổi HEIC → JPG trên iOS), đỡ tốn RAM khi giải mã.
class ImagePickerSignaturePhotoPicker implements SignaturePhotoPicker {
  const ImagePickerSignaturePhotoPicker();

  @override
  Future<Uint8List?> pick(SignaturePhotoSource source) async {
    try {
      final x = await ImagePicker().pickImage(
        source: source == SignaturePhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        requestFullMetadata: false,
      );
      return x == null ? null : await x.readAsBytes();
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
        throw const PermissionDenied();
      }
      throw AppError.from(e);
    }
  }
}

final signaturePhotoPickerProvider = Provider<SignaturePhotoPicker>(
  (ref) => const ImagePickerSignaturePhotoPicker(),
);

/// Giải mã ảnh + tách nét lần đầu (ngưỡng Otsu) trong isolate riêng. Hàm cấp cao nhất để
/// closure của `Isolate.run` chỉ mang theo tham số (không dính `State`/`ref`).
Future<({SignaturePhoto photo, Uint8List? png})> _decodeSignaturePhoto(
  Uint8List bytes,
  Color ink,
) => Isolate.run(() {
  final photo = decodeSignaturePhoto(bytes);
  return (photo: photo, png: signaturePngFromDecodedPhoto(photo, ink: ink));
});

/// Tách nét lại với ngưỡng / màu mực mới (khi kéo thanh độ nhạy hoặc đổi màu).
Future<Uint8List?> _extractSignature(
  SignaturePhoto photo,
  int threshold,
  Color ink,
) => Isolate.run(
  () => signaturePngFromDecodedPhoto(photo, threshold: threshold, ink: ink),
);

class _PageData {
  const _PageData(this.image, this.size);

  final Uint8List image;

  /// Kích thước trang "nhìn thấy" (point) — cùng hệ với `PdfSignEngine.pageSize`.
  final Size size;
}

/// Màn ký PDF (`Routes.sign`): chọn / vẽ chữ ký, đặt lên trang (kéo, đổi cỡ), lưu ra file MỚI.
///
/// Trang được render bằng `pdfRenderEngineProvider` (feature reader) để biết đúng toạ độ trang;
/// việc đặt ảnh lên PDF do `pdfSignEngineProvider`.
class SignScreen extends ConsumerStatefulWidget {
  const SignScreen({super.key, required this.path});

  final String path;

  @override
  ConsumerState<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends ConsumerState<SignScreen> {
  PdfRenderDocument? _doc;
  String? _password;
  Object? _openError;
  bool _opening = true;
  int _pageIndex = 0;
  /// Chỉ giữ ảnh vài trang gần nhất (ảnh PNG lớn); kích thước trang giữ riêng ở [_pageSizes].
  final PageLruCache<int, Future<_PageData>> _pages = PageLruCache(4);
  final Map<int, Size> _pageSizes = {};

  final List<PlacedSignature> _items = [];
  int _nextId = 1;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    // l10n cần context đã gắn vào cây → chờ khung hình đầu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open();
    });
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _openError = null;
    });
    final l = context.l10n;
    final name = p.basename(widget.path);
    String? errorText;
    try {
      final render = ref.read(pdfRenderEngineProvider);
      while (true) {
        try {
          final doc = await render.openFile(widget.path, password: _password);
          if (!mounted) {
            await doc.close();
            return;
          }
          setState(() {
            _doc = doc;
            _opening = false;
          });
          return;
        } on PasswordRequired {
          errorText = null;
        } on WrongPassword {
          errorText = l.core_errorWrongPassword;
        }
        if (!mounted) return;
        final pw = await showPasswordDialog(
          context,
          message: l.core_passwordDialogMessage(name),
          errorText: errorText,
        );
        if (pw == null) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        _password = pw;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _openError = e;
          _opening = false;
        });
      }
    }
  }

  Future<_PageData> _loadPage(int index) async {
    final doc = _doc!;
    final size = await ref
        .read(pdfSignEngineProvider)
        .pageSize(widget.path, index, password: _password);
    final image = await doc.renderPage(index, dpi: kSignPreviewDpi);
    _pageSizes[index] = size;
    return _PageData(image, size);
  }

  Future<_PageData> _pageData(int index) =>
      _pages.putIfAbsent(index, () => _loadPage(index));

  void _goToPage(int index) {
    final count = _doc?.pageCount ?? 1;
    if (index < 0 || index >= count) return;
    setState(() {
      _pageIndex = index;
      _selectedId = null;
    });
  }

  Future<void> _addFromBytes(Uint8List png) async {
    try {
      final data = await _pageData(_pageIndex);
      final aspect = pngAspectRatio(png);
      final item = PlacedSignature(
        id: _nextId++,
        pageIndex: _pageIndex,
        pngBytes: png,
        aspect: aspect,
        norm: initialNormRect(aspect, data.size),
      );
      if (!mounted) return;
      setState(() {
        _items.add(item);
        _selectedId = item.id;
      });
    } catch (e) {
      if (mounted) showEditorError(context, e);
    }
  }

  Future<void> _addSaved(SignatureEntry s) => _addFromBytes(s.png);

  Future<void> _drawNew() async {
    final png = await showSignaturePadSheet(context);
    if (png == null || !mounted) return;
    await _saveAndAdd(png);
  }

  /// Lưu chữ ký mới vào kho rồi đặt lên trang hiện tại.
  Future<void> _saveAndAdd(Uint8List png) async {
    try {
      final store = await ref.read(signatureStoreProvider.future);
      await store.save(png);
      ref.invalidate(savedSignaturesProvider);
    } catch (e) {
      // Không lưu được thì vẫn cho dùng chữ ký vừa tạo trong phiên này.
      if (mounted) showEditorError(context, e);
    }
    if (mounted) await _addFromBytes(png);
  }

  /// Nhập chữ ký từ ảnh chụp: chọn nguồn → lấy ảnh → tách nét (isolate) → xem trước, chỉnh độ
  /// nhạy / màu mực → lưu + đặt lên trang như chữ ký vừa vẽ.
  Future<void> _importFromPhoto() async {
    final l = context.l10n;
    final source = await showAppSheet<SignaturePhotoSource>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(l.edit_importSignatureTitle),
          SheetOption(
            key: const Key('importFromGallery'),
            icon: Symbols.photo_library_rounded,
            label: l.edit_pickFromGallery,
            onTap: () =>
                Navigator.of(ctx).pop(SignaturePhotoSource.gallery),
          ),
          SheetOption(
            key: const Key('importFromCamera'),
            icon: Symbols.photo_camera_rounded,
            label: l.edit_takePhoto,
            onTap: () => Navigator.of(ctx).pop(SignaturePhotoSource.camera),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    final Uint8List? bytes;
    try {
      bytes = await ref.read(signaturePhotoPickerProvider).pick(source);
    } catch (e) {
      if (mounted) showEditorError(context, e);
      return;
    }
    if (bytes == null || !mounted) return;

    final ink = kPenColors.first;
    final progress = showProgressDialog(context, cancellable: false);
    ({SignaturePhoto photo, Uint8List? png}) first;
    try {
      first = await _decodeSignaturePhoto(bytes, ink);
    } catch (e) {
      progress.close();
      if (mounted) showEditorError(context, e);
      return;
    }
    progress.close();
    if (!mounted) return;
    final firstPng = first.png;
    final threshold = first.photo.autoThreshold;
    if (firstPng == null || threshold == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.edit_importNoInk)));
      return;
    }
    final png = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SignatureImportSheet(
        photo: first.photo,
        initialPng: firstPng,
        initialThreshold: threshold,
        initialInk: ink,
      ),
    );
    if (png == null || !mounted) return;
    await _saveAndAdd(png);
  }

  Future<void> _deleteSaved(SignatureEntry s) async {
    final l = context.l10n;
    final ok = await showConfirmDialog(
      context,
      title: l.edit_deleteSignatureTitle,
      message: l.edit_deleteSignatureMessage,
      confirmLabel: l.core_delete,
    );
    if (!ok || !mounted) return;
    try {
      final store = await ref.read(signatureStoreProvider.future);
      await store.delete(s.saved);
      ref.invalidate(savedSignaturesProvider);
    } catch (e) {
      if (mounted) showEditorError(context, e);
    }
  }

  void _update(int id, PlacedSignature Function(PlacedSignature) f) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    setState(() => _items[i] = f(_items[i]));
  }

  Future<void> _apply() async {
    final l = context.l10n;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.edit_noPlacements)));
      return;
    }
    final progress = showProgressDialog(context, cancellable: false);
    String? out;
    try {
      final placements = [
        for (final it in _items)
          SignaturePlacement(
            pageIndex: it.pageIndex,
            bounds: normToPdfRect(it.norm, _pageSizes[it.pageIndex]!),
            pngBytes: it.pngBytes,
          ),
      ];
      final dir = await ref.read(outputDirectoryProvider.future);
      final target = await editedOutputPath(dir, widget.path, EditKind.sign);
      out = await ref
          .read(pdfSignEngineProvider)
          .applySignatures(
            widget.path,
            placements,
            target,
            password: _password,
          );
    } catch (e) {
      progress.close();
      if (mounted) showEditorError(context, e);
      return;
    }
    progress.close();
    if (!mounted) return;
    setState(_items.clear);
    await showSavedDialog(context, out);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canApply = _doc != null;
    return UnsavedChangesGuard(
      hasChanges: _items.isNotEmpty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            p.basename(widget.path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              key: const Key('apply'),
              tooltip: l.edit_applySignatures,
              icon: const Icon(Symbols.check_rounded),
              onPressed: canApply ? _apply : null,
            ),
          ],
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l = context.l10n;
    if (_opening) return const Center(child: CircularProgressIndicator());
    if (_openError != null || _doc == null) {
      final e = _openError;
      return EmptyState(
        title: e is AppError ? appErrorMessage(context, e) : l.edit_loadFailed,
        icon: Symbols.error_rounded,
        actionLabel: l.core_retry,
        onAction: _open,
      );
    }
    final count = _doc!.pageCount;
    return Column(
      children: [
        HintBanner(l.edit_signHint),
        Expanded(
          child: FutureBuilder<_PageData>(
            key: ValueKey(_pageIndex),
            future: _pageData(_pageIndex),
            builder: (context, snap) {
              if (snap.hasError) {
                return EmptyState(
                  title: snap.error is AppError
                      ? appErrorMessage(context, snap.error as AppError)
                      : l.edit_loadFailed,
                  icon: Symbols.error_rounded,
                  actionLabel: l.core_retry,
                  onAction: () => setState(() => _pages.remove(_pageIndex)),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildPageArea(context, snap.data!);
            },
          ),
        ),
        _PageNavigator(
          pageIndex: _pageIndex,
          pageCount: count,
          onPrevious: _pageIndex > 0 ? () => _goToPage(_pageIndex - 1) : null,
          onNext: _pageIndex < count - 1
              ? () => _goToPage(_pageIndex + 1)
              : null,
        ),
        _SignatureBar(
          onNew: _drawNew,
          onImport: _importFromPhoto,
          onPick: _addSaved,
          onDelete: _deleteSaved,
        ),
      ],
    );
  }

  Widget _buildPageArea(BuildContext context, _PageData data) {
    final l = context.l10n;
    return LayoutBuilder(
      builder: (context, c) {
        const pad = kSignatureAreaPadding;
        final availW = (c.maxWidth - 2 * pad).clamp(1.0, double.infinity);
        final availH = (c.maxHeight - 2 * pad).clamp(1.0, double.infinity);
        final scale = [
          availW / data.size.width,
          availH / data.size.height,
        ].reduce((a, b) => a < b ? a : b);
        final box = Size(data.size.width * scale, data.size.height * scale);
        const origin = Offset(pad, pad);
        return Center(
          child: SizedBox(
            width: box.width + 2 * pad,
            height: box.height + 2 * pad,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fromRect(
                  rect: origin & box,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selectedId = null),
                    child: DecoratedBox(
                      // Trang giấy: nền trắng + bóng nhẹ để tách khỏi nền màn.
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 12,
                            offset: Offset(0, 4),
                            color: Color(0x1A000000),
                          ),
                        ],
                      ),
                      child: Image.memory(
                        data.image,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
                for (final it in _items.where((e) => e.pageIndex == _pageIndex))
                  ...signatureOverlayWidgets(
                    context,
                    item: it,
                    pageBox: box,
                    pageOrigin: origin,
                    selected: it.id == _selectedId,
                    removeLabel: l.edit_removeSignature,
                    onSelect: () => setState(() => _selectedId = it.id),
                    onMove: (delta) => _update(
                      it.id,
                      (s) => s.copyWith(norm: moveNormRect(s.norm, delta)),
                    ),
                    onResize: (w) => _update(
                      it.id,
                      (s) => s.copyWith(
                        norm: resizeNormRect(s.norm, w, data.size, s.aspect),
                      ),
                    ),
                    onRemove: () => setState(() {
                      _items.removeWhere((e) => e.id == it.id);
                      _selectedId = null;
                    }),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PageNavigator extends StatelessWidget {
  const _PageNavigator({
    required this.pageIndex,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageIndex;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    // Nút tròn 40 nền `surface2` hai bên viên số trang.
    final navStyle = IconButton.styleFrom(
      fixedSize: const Size.square(40),
      minimumSize: const Size.square(40),
      padding: EdgeInsets.zero,
      backgroundColor: t.surface2,
      foregroundColor: t.text,
      disabledBackgroundColor: t.surface2.withValues(alpha: 0.5),
      disabledForegroundColor: t.textMuted.withValues(alpha: 0.5),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const Key('prevPage'),
            tooltip: l.edit_previousPage,
            style: navStyle,
            icon: const Icon(Symbols.chevron_left_rounded, size: 22),
            onPressed: onPrevious,
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: ShapeDecoration(
              color: t.surface,
              shape: StadiumBorder(side: BorderSide(color: t.line)),
            ),
            child: Text(
              l.edit_pageOf(pageIndex + 1, pageCount),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: t.text,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            key: const Key('nextPage'),
            tooltip: l.edit_nextPage,
            style: navStyle,
            icon: const Icon(Symbols.chevron_right_rounded, size: 22),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// Dải chữ ký đã lưu + ô "chữ ký mới" + ô "từ ảnh".
class _SignatureBar extends ConsumerWidget {
  const _SignatureBar({
    required this.onNew,
    required this.onImport,
    required this.onPick,
    required this.onDelete,
  });

  final VoidCallback onNew;
  final VoidCallback onImport;
  final ValueChanged<SignatureEntry> onPick;
  final ValueChanged<SignatureEntry> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final saved = ref.watch(savedSignaturesProvider);
    final list = saved.value ?? const <SignatureEntry>[];
    // Thanh đáy nền `surface` bo trên 24, kẻ trên `line` (cùng kiểu thanh công cụ chú thích).
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            children: [
              _actionTile(
                context,
                key: const Key('newSignature'),
                icon: Symbols.draw_rounded,
                label: l.edit_newSignature,
                onTap: onNew,
              ),
              _actionTile(
                context,
                key: const Key('importSignature'),
                icon: Symbols.add_photo_alternate_rounded,
                label: l.edit_importSignature,
                onTap: onImport,
              ),
              if (list.isEmpty && saved.hasValue)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Center(
                    child: SizedBox(
                      width: 200,
                      child: Text(
                        l.edit_noSavedSignatures,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: t.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              for (final s in list)
                _Tile(
                  key: Key('saved_${s.saved.fileName}'),
                  onTap: () => onPick(s),
                  onLongPress: () => onDelete(s),
                  // Nền luôn trắng để nét mực tối vẫn thấy rõ ở giao diện tối.
                  background: Colors.white,
                  borderColor: t.line,
                  badge: GestureDetector(
                    key: Key('delete_${s.saved.fileName}'),
                    onTap: () => onDelete(s),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Symbols.cancel_rounded,
                        size: 20,
                        fill: 1,
                        color: AppTokens.light.textMuted,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                    child: Image.memory(
                      s.png,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(
                        Symbols.broken_image_rounded,
                        color: AppTokens.light.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ô hành động nền `primarySoft`: icon + nhãn (chữ ký mới / từ ảnh).
  Widget _actionTile(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    return _Tile(
      key: key,
      onTap: onTap,
      background: t.primarySoft,
      borderColor: t.primaryText.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: t.primaryText),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.primaryText,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Khoảng ngưỡng cho thanh độ nhạy (thang sáng 0–255; cao hơn = giữ thêm nét nhạt).
const double _kMinThreshold = 10;
const double _kMaxThreshold = 250;

/// Bảng xem trước chữ ký tách từ ảnh: nền caro (thấy rõ phần trong suốt), thanh độ nhạy
/// (ngưỡng), 4 màu mực như bảng vẽ chữ ký. Đóng với PNG đã cắt sát khi bấm "Dùng chữ ký".
class _SignatureImportSheet extends StatefulWidget {
  const _SignatureImportSheet({
    required this.photo,
    required this.initialPng,
    required this.initialThreshold,
    required this.initialInk,
  });

  final SignaturePhoto photo;
  final Uint8List initialPng;
  final int initialThreshold;
  final Color initialInk;

  @override
  State<_SignatureImportSheet> createState() => _SignatureImportSheetState();
}

class _SignatureImportSheetState extends State<_SignatureImportSheet> {
  late double _threshold = widget.initialThreshold.toDouble().clamp(
    _kMinThreshold,
    _kMaxThreshold,
  );
  late Color _ink = widget.initialInk;
  late Uint8List? _png = widget.initialPng;
  bool _busy = false;

  /// Lượt xử lý mới nhất — kết quả của lượt cũ về muộn thì bỏ.
  int _generation = 0;

  Future<void> _reprocess() async {
    final gen = ++_generation;
    setState(() => _busy = true);
    Uint8List? png;
    Object? error;
    try {
      png = await _extractSignature(widget.photo, _threshold.round(), _ink);
    } catch (e) {
      error = e;
    }
    if (!mounted || gen != _generation) return;
    setState(() {
      _busy = false;
      if (error == null) _png = png;
    });
    if (error != null) showEditorError(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final labelStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: t.text,
    );
    final png = _png;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.edit_importSignatureTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.edit_importSignatureHint,
            style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted),
          ),
          const SizedBox(height: 14),
          // Ô xem trước: nền caro sáng ở cả giao diện tối (mực tối vẫn thấy rõ), bo 16.
          Container(
            key: const Key('importPreview'),
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.line),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: CustomPaint(
                painter: const _CheckerPainter(),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: png == null
                            ? Center(
                                child: Text(
                                  l.edit_importNoInk,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: AppTokens.light.textMuted,
                                  ),
                                ),
                              )
                            : Image.memory(
                                png,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                      ),
                    ),
                    if (_busy)
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(l.edit_penColor, style: labelStyle),
              const SizedBox(width: 10),
              for (final c in kPenColors)
                _InkDot(
                  key: Key('ink_${c.toARGB32()}'),
                  color: c,
                  selected: _ink == c,
                  onTap: () {
                    if (_ink == c) return;
                    setState(() => _ink = c);
                    _reprocess();
                  },
                ),
            ],
          ),
          Row(
            children: [
              Text(l.edit_sensitivity, style: labelStyle),
              Expanded(
                child: Slider(
                  key: const Key('importThreshold'),
                  value: _threshold,
                  min: _kMinThreshold,
                  max: _kMaxThreshold,
                  activeColor: AppColors.primary,
                  inactiveColor: t.surface2,
                  onChanged: (v) => setState(() => _threshold = v),
                  // Xử lý lại khi thả tay — kéo liên tục không dựng isolate mỗi khung hình.
                  onChangeEnd: (_) => _reprocess(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('cancelImport'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l.core_cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('useImported'),
                      onPressed: _busy || png == null
                          ? null
                          : () => Navigator.of(context).pop(png),
                      child: Text(l.edit_useSignature),
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

/// Nền caro trắng / xám nhạt — kiểu nền "trong suốt" của trình sửa ảnh.
class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

  static const double _cell = 12;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final grey = Paint()..color = const Color(0xFFECECEC);
    for (var y = 0; y * _cell < size.height; y++) {
      for (var x = (y.isEven ? 0 : 1); x * _cell < size.width; x += 2) {
        canvas.drawRect(Rect.fromLTWH(x * _cell, y * _cell, _cell, _cell), grey);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) => false;
}

/// Chấm màu mực tròn 32 (cùng kiểu chấm màu bút ở bảng vẽ chữ ký).
class _InkDot extends StatelessWidget {
  const _InkDot({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.primary : t.lineStrong,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? const Icon(
                    Symbols.check_rounded,
                    size: 16,
                    weight: 700,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    required this.background,
    required this.borderColor,
    this.badge,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color background;
  final Color borderColor;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    // Ô chữ ký bo 14, viền mảnh.
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 108,
        child: Stack(
          children: [
            Positioned.fill(
              child: Material(
                color: background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: child,
                ),
              ),
            ),
            if (badge != null) Positioned(top: 0, right: 0, child: badge!),
          ],
        ),
      ),
    );
  }
}
