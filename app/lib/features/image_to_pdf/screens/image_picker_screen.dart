import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/permissions/camera_permission.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../image_to_pdf_paths.dart';
import '../image_to_pdf_providers.dart';
import '../models/ordered_selection.dart';

/// Bước 1: chọn nguồn ảnh — mở ngay trình chọn ảnh của hệ thống (không cần quyền thư viện ảnh),
/// kèm hai nút "Chọn ảnh" (mở lại trình chọn) và "Chụp ảnh" (camera).
///
/// [addMode] = đang thêm ảnh từ màn sửa: xong thì trả về `List<String>` đường dẫn
/// (`context.pop`) thay vì mở màn sửa. [remaining] là số ảnh còn thêm được (mặc định tối đa).
class ImagePickerScreen extends ConsumerStatefulWidget {
  const ImagePickerScreen({super.key, this.addMode = false, this.remaining});

  final bool addMode;
  final int? remaining;

  @override
  ConsumerState<ImagePickerScreen> createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends ConsumerState<ImagePickerScreen> {
  bool _busy = false;

  /// Số ảnh tối đa lượt này được chọn (ít nhất 1).
  int get _limit => math.max(1, widget.remaining ?? maxImagesPerPdf);

  @override
  void initState() {
    super.initState();
    if (!widget.addMode) {
      // Bắt đầu lượt mới: dọn file tạm của lượt trước.
      unawaited(ref.read(workDirCleanerProvider)());
    }
    // Mở trình chọn ngay khi vào màn; huỷ thì ở lại màn này để chọn lại / chụp.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_pick());
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Chạy [task] khi không bận; lỗi → báo bằng snackbar.
  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) _snack(appErrorMessage(context, AppError.from(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() => _run(() async {
    final limit = _limit;
    var picked = await ref
        .read(photoPickerServiceProvider)
        .pickImages(limit: limit);
    if (!mounted || picked.isEmpty) return;
    if (picked.length > limit) {
      // Trình chọn cũ không giới hạn số ảnh → cắt bớt, giữ thứ tự.
      _snack(context.l10n.img2pdf_maxImages(limit));
      picked = picked.take(limit).toList();
    }
    final paths = await _prepare(picked);
    if (paths != null) _finish(paths);
  });

  Future<void> _camera() => _run(() async {
    // Giải thích trước khi xin quyền; "Để sau" thì thôi, không báo lỗi.
    if (!await ensureCameraPermission(context, ref) || !mounted) return;
    final path = await ref.read(cameraServiceProvider).capture();
    // Ảnh chụp là JPEG sẵn, dùng thẳng.
    if (path != null && mounted) _finish([path]);
  });

  /// Đổi ảnh engine không đọc được (HEIC…) sang JPEG, có hộp tiến trình.
  /// `null` = huỷ hoặc không còn ảnh nào dùng được.
  Future<List<String>?> _prepare(List<String> picked) async {
    final l = context.l10n;
    final service = ref.read(photoPickerServiceProvider);
    final ctrl = showProgressDialog(context, title: l.img2pdf_preparing);
    final paths = <String>[];
    var failed = 0;
    try {
      final workDir = await ref.read(workDirProvider)();
      for (var i = 0; i < picked.length; i++) {
        ctrl.cancelToken.throwIfCancelled();
        String? path;
        try {
          path = await service.prepareFile(picked[i], workDir);
        } catch (_) {
          path = null;
        }
        if (path != null) {
          paths.add(path);
        } else {
          failed++;
        }
        ctrl.update((i + 1) / picked.length);
      }
    } on Cancelled {
      return null;
    } finally {
      ctrl.close();
    }
    if (!mounted) return null;
    if (failed > 0) _snack(l.img2pdf_skippedImages(failed));
    return paths.isEmpty ? null : paths;
  }

  void _finish(List<String> paths) {
    if (widget.addMode) {
      context.pop(paths);
    } else {
      unawaited(context.push(img2pdfEditPath, extra: paths));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(l.img2pdf_pickTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: t.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Symbols.add_photo_alternate_rounded,
                        size: 44,
                        fill: 1,
                        color: t.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l.img2pdf_pickHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: t.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    key: const ValueKey('choose_photos_button'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Symbols.photo_library_rounded),
                    label: Text(l.img2pdf_choosePhotos),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('take_photo_button'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _busy ? null : _camera,
                    icon: const Icon(Symbols.photo_camera_rounded),
                    label: Text(l.img2pdf_takePhoto),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
