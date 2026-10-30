import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../core/errors/app_error.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_paths.dart';
import '../../core/utils/output_directory.dart';
import '../../core/widgets/widgets.dart';
import '../pdf_tools/ui/tool_runner.dart' show showToolError, showToolMessage;
import '../pdf_tools/ui/tool_widgets.dart';
import '../scanner/capture/document_capture.dart';
import '../scanner/manual/manual_crop_screen.dart';
import 'id_card_services.dart';

enum _Source { scan, gallery }

/// Màn Quét thẻ 2 mặt lên 1 trang: ô "Mặt trước" / "Mặt sau" (chụp bằng trình quét có sẵn
/// hoặc chọn ảnh thư viện, chụp lại, xoay 90°) → xem trước trang A4 ghép → xuất PDF / JPG.
class IdCardScreen extends ConsumerStatefulWidget {
  const IdCardScreen({super.key});

  @override
  ConsumerState<IdCardScreen> createState() => _IdCardScreenState();
}

class _IdCardScreenState extends ConsumerState<IdCardScreen> {
  IdCardSide? _front;
  IdCardSide? _back;
  IdCardFormat _format = IdCardFormat.pdf;
  IdCardSize _size = IdCardSize.actual;
  bool _watermarkOn = false;
  final TextEditingController _purpose = TextEditingController();
  Timer? _purposeDebounce;

  /// Hình mờ đã vẽ, theo chữ (vẽ lại khi chữ đổi).
  String? _watermarkText;
  Uint8List? _watermarkPng;

  Uint8List? _preview;
  bool _previewRunning = false;
  bool _previewDirty = false;

  bool _busy = false;
  String? _result;

  /// Ảnh tạm (quét / cắt tay / thư viện) — xoá khi rời màn.
  final Set<String> _temps = {};
  late final Future<void> Function(Iterable<String>) _cleaner;

  @override
  void initState() {
    super.initState();
    _cleaner = ref.read(idCardTempCleanerProvider);
  }

  @override
  void dispose() {
    _purposeDebounce?.cancel();
    _purpose.dispose();
    // Ảnh giấy tờ tuỳ thân không nên nằm lại trong cache.
    unawaited(_cleaner(_temps.toList()));
    super.dispose();
  }

  bool get _ready => _front != null && _back != null;

  // ------------------------------------------------------------ lấy ảnh

  Future<void> _pick(bool front) async {
    if (_busy) return;
    final l = context.l10n;
    final source = await showAppSheet<_Source>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(front ? l.idcard_front : l.idcard_back),
          SheetOption(
            key: const ValueKey('idcard_source_scan'),
            icon: Symbols.document_scanner_rounded,
            label: l.idcard_scan,
            onTap: () => Navigator.of(ctx).pop(_Source.scan),
          ),
          SheetOption(
            key: const ValueKey('idcard_source_gallery'),
            icon: Symbols.photo_library_rounded,
            label: l.idcard_gallery,
            onTap: () => Navigator.of(ctx).pop(_Source.gallery),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    _busy = true;
    try {
      final path = switch (source) {
        _Source.scan => await _scan(),
        _Source.gallery =>
          await ref.read(idCardGalleryPickerProvider).pickImage(),
      };
      if (path == null || !mounted) return;
      _temps.add(path);
      final old = front ? _front : _back;
      setState(() {
        if (front) {
          _front = IdCardSide(path);
        } else {
          _back = IdCardSide(path);
        }
        _result = null;
      });
      if (old != null && old.path != path) {
        _temps.remove(old.path);
        unawaited(_cleaner([old.path]));
      }
      unawaited(_refreshPreview());
    } catch (e, st) {
      debugPrint('idcard: lấy ảnh lỗi: $e | $st');
      if (mounted) showToolError(context, e);
    } finally {
      _busy = false;
    }
  }

  /// Trình quét tự nhận viền (1 trang); máy không có → chụp ảnh + kéo bốn góc. `null` = huỷ.
  Future<String?> _scan() async {
    final capture = ref.read(documentCaptureProvider);
    try {
      final pages = await capture.scanPages(maxPages: 1);
      if (pages == null || pages.isEmpty) return null;
      // Trình quét có thể trả nhiều ảnh dù chỉ xin 1: giữ ảnh đầu, xoá phần dư.
      if (pages.length > 1) unawaited(_cleaner(pages.skip(1)));
      return pages.first;
    } on ScannerUnavailable {
      if (!mounted) return null;
      showToolMessage(context, context.l10n.scan_autoUnavailable);
      final photo = await capture.takePhoto();
      if (photo == null || !mounted) return null;
      final cropped = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => ManualCropScreen(imagePath: photo)),
      );
      if (cropped != photo) unawaited(_cleaner([photo]));
      return cropped;
    }
  }

  void _rotate(bool front) {
    setState(() {
      if (front) {
        _front = _front?.rotated();
      } else {
        _back = _back?.rotated();
      }
      _result = null;
    });
    unawaited(_refreshPreview());
  }

  // ------------------------------------------------------------ ghép / xem trước

  Future<IdCardRequest> _request({required bool preview}) async =>
      IdCardRequest(
        front: _front!,
        back: _back!,
        size: _size,
        watermarkPng: await _watermark(),
        preview: preview,
      );

  Future<Uint8List?> _watermark() async {
    final purpose = _purpose.text.trim();
    if (!_watermarkOn || purpose.isEmpty) return null;
    final text = context.l10n.idcard_watermarkText(purpose);
    if (text != _watermarkText || _watermarkPng == null) {
      _watermarkPng = await ref.read(idCardWatermarkRendererProvider)(text);
      _watermarkText = text;
    }
    return _watermarkPng;
  }

  /// Ghép bản xem trước; đang ghép mà có thay đổi thì ghép lại một lượt sau khi xong.
  Future<void> _refreshPreview() async {
    if (!_ready) {
      if (_preview != null) setState(() => _preview = null);
      return;
    }
    if (_previewRunning) {
      _previewDirty = true;
      return;
    }
    setState(() => _previewRunning = true);
    final composer = ref.read(idCardComposerProvider);
    try {
      do {
        _previewDirty = false;
        if (!_ready) break;
        final bytes = await composer.compose(await _request(preview: true));
        if (!mounted) return;
        if (!_previewDirty) setState(() => _preview = bytes);
      } while (_previewDirty && mounted);
    } catch (e, st) {
      debugPrint('idcard: ghép xem trước lỗi: $e | $st');
      if (mounted) {
        setState(() => _preview = null);
        showToolError(context, e);
      }
    } finally {
      if (mounted) setState(() => _previewRunning = false);
    }
  }

  void _onPurposeChanged(String _) {
    _purposeDebounce?.cancel();
    _purposeDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _result = null);
      unawaited(_refreshPreview());
    });
  }

  // ------------------------------------------------------------ xuất

  Future<void> _export() async {
    final l = context.l10n;
    if (!_ready) {
      showToolMessage(context, l.idcard_needBoth);
      return;
    }
    if (_busy) return;
    _busy = true;
    final ctrl = showProgressDialog(
      context,
      title: l.core_processing,
      cancellable: false,
    );
    try {
      final request = await _request(preview: false);
      final page = await ref.read(idCardComposerProvider).compose(request);
      final dir = await ref.read(outputDirectoryProvider.future);
      final out = await ref
          .read(idCardExporterProvider)
          .export(
            page: page,
            format: _format,
            outputDir: dir,
            baseName: idCardFileName(DateTime.now()),
          );
      if (_format == IdCardFormat.pdf) {
        try {
          await ref.read(idCardRegisterOutputProvider)(out);
        } catch (_) {
          // bảng documents chỉ là bộ đệm; lần quét sau sẽ thấy file.
        }
      }
      ctrl.close();
      if (!mounted) return;
      setState(() => _result = out);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l.idcard_savedTo(parentFolderName(out))),
            action: SnackBarAction(
              label: l.core_open,
              onPressed: () => _open(out),
            ),
          ),
        );
    } catch (e, st) {
      debugPrint('idcard: xuất lỗi: $e | $st');
      ctrl.close();
      if (mounted) showToolError(context, e);
    } finally {
      _busy = false;
    }
  }

  /// PDF → trình đọc của app; JPG → app xem ảnh của máy.
  Future<void> _open(String path) async {
    if (!mounted) return;
    if (p.extension(path).toLowerCase() == '.pdf') {
      await openToolFile(context, path);
      return;
    }
    try {
      final r = await OpenFilex.open(path);
      if (r.type != ResultType.done) throw const UnsupportedFormat('jpg');
    } catch (e) {
      if (mounted) showToolError(context, e);
    }
  }

  // ------------------------------------------------------------ giao diện

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final result = _result;
    return ToolScaffold(
      title: l.core_toolIdCard,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ToolHintText(l.idcard_hint),
          const SizedBox(height: 16),
          _SideTile(
            key: const ValueKey('idcard_front'),
            label: l.idcard_front,
            side: _front,
            onPick: () => _pick(true),
            onRotate: () => _rotate(true),
          ),
          const SizedBox(height: 14),
          _SideTile(
            key: const ValueKey('idcard_back'),
            label: l.idcard_back,
            side: _back,
            onPick: () => _pick(false),
            onRotate: () => _rotate(false),
          ),
          const SizedBox(height: 20),
          ToolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ToolSectionLabel(l.idcard_format),
                ToolChipWrap(
                  children: [
                    for (final f in IdCardFormat.values)
                      ToolChoiceChip(
                        key: ValueKey('idcard_format_${f.name}'),
                        label: f.extension.toUpperCase(),
                        selected: _format == f,
                        onTap: () => setState(() {
                          _format = f;
                          _result = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ToolSectionLabel(l.idcard_size),
                ToolChipWrap(
                  children: [
                    for (final s in IdCardSize.values)
                      ToolChoiceChip(
                        key: ValueKey('idcard_size_${s.name}'),
                        label: s == IdCardSize.actual
                            ? l.idcard_sizeActual
                            : l.idcard_sizeLarge,
                        selected: _size == s,
                        onTap: () {
                          if (_size == s) return;
                          setState(() {
                            _size = s;
                            _result = null;
                          });
                          unawaited(_refreshPreview());
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // ToolCard có nền màu: ListTile cần Material riêng để vệt nhấn không bị che.
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    key: const ValueKey('idcard_watermark'),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    value: _watermarkOn,
                    onChanged: (v) {
                      setState(() {
                        _watermarkOn = v;
                        _result = null;
                      });
                      unawaited(_refreshPreview());
                    },
                    title: Text(
                      l.idcard_watermark,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                  ),
                ),
                if (_watermarkOn)
                  AppTextField(
                    controller: _purpose,
                    hintText: l.idcard_watermarkHint,
                    textInputAction: TextInputAction.done,
                    onChanged: _onPurposeChanged,
                    onSubmitted: _onPurposeChanged,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ToolSectionLabel(l.idcard_preview),
          _PagePreview(
            bytes: _preview,
            busy: _previewRunning,
            emptyText: l.idcard_previewEmpty,
          ),
          if (result != null) ...[
            const SizedBox(height: 20),
            _ResultCard(
              path: result,
              onOpen: () => _open(result),
              onShare: () => shareToolFile(context, result),
            ),
          ],
        ],
      ),
      bottom: PrimaryActionButton(
        label: _format == IdCardFormat.pdf
            ? l.idcard_exportPdf
            : l.idcard_exportJpg,
        icon: _format == IdCardFormat.pdf
            ? Symbols.picture_as_pdf_rounded
            : Symbols.image_rounded,
        onPressed: _ready ? _export : null,
      ),
    );
  }
}

/// Ô lớn tỉ lệ thẻ (85.6×54): trống → bấm để lấy ảnh; có ảnh → ảnh + Chụp lại / Xoay.
class _SideTile extends StatelessWidget {
  const _SideTile({
    super.key,
    required this.label,
    required this.side,
    required this.onPick,
    required this.onRotate,
  });

  final String label;
  final IdCardSide? side;
  final VoidCallback onPick;
  final VoidCallback onRotate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final s = side;
    final frame = AspectRatio(
      aspectRatio: 85.6 / 54,
      child: Material(
        color: s == null ? t.surface : t.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: s == null ? t.lineStrong : t.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPick,
          child: s == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: t.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Symbols.add_a_photo_rounded,
                        size: 28,
                        color: t.primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l.idcard_tapToAdd,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: t.textMuted),
                      ),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: RotatedBox(
                        quarterTurns: s.turns,
                        child: Image.file(
                          File(s.path),
                          key: ValueKey(s.path),
                          fit: BoxFit.contain,
                          cacheWidth: 900,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => Icon(
                            Symbols.broken_image_rounded,
                            size: 40,
                            color: t.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: t.scrim,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
    if (s == null) return frame;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        frame,
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Symbols.restart_alt_rounded, size: 20),
              label: Text(l.idcard_retake),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: onRotate,
              icon: const Icon(Symbols.rotate_90_degrees_cw_rounded, size: 20),
              label: Text(l.idcard_rotate),
            ),
          ],
        ),
      ],
    );
  }
}

/// Khung trang A4 trắng hiện ảnh ghép; chưa đủ 2 mặt → dòng hướng dẫn.
class _PagePreview extends StatelessWidget {
  const _PagePreview({
    required this.bytes,
    required this.busy,
    required this.emptyText,
  });

  final Uint8List? bytes;
  final bool busy;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final b = bytes;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: AspectRatio(
          aspectRatio: 210 / 297,
          child: Container(
            key: const ValueKey('idcard_preview'),
            decoration: BoxDecoration(
              // Trang giấy luôn trắng, cả ở giao diện tối.
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.lineStrong),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (b != null)
                  Image.memory(
                    b,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  )
                else if (!busy)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        emptyText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ),
                  ),
                if (busy)
                  const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ kết quả: file đã tạo + Chia sẻ / Mở.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.path,
    required this.onOpen,
    required this.onShare,
  });

  final String path;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ToolCard(
      key: const ValueKey('idcard_result'),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ToolFileRow(
            path: path,
            info: l.idcard_savedTo(parentFolderName(path)),
            onTap: onOpen,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: SecondaryActionButton(
                    label: l.core_share,
                    icon: Symbols.share_rounded,
                    onPressed: onShare,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryActionButton(
                    label: l.core_open,
                    icon: Symbols.open_in_new_rounded,
                    onPressed: onOpen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
