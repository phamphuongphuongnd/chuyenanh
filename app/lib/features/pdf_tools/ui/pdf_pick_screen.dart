import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_format.dart';
import '../../../core/utils/doc_type.dart';
import '../../../core/widgets/widgets.dart';
import '../../documents/documents_logic.dart';
import '../../documents/documents_providers.dart';
import 'pdf_file_picker.dart';

/// Bộ lọc danh sách PDF khi chọn file cho công cụ.
enum PdfPickMode {
  /// Chỉ PDF chưa khoá (công cụ Khoá PDF).
  unlockedOnly,

  /// Chỉ PDF đã khoá (công cụ Mở khoá PDF).
  lockedOnly,
}

/// Mở màn chọn PDF trong app. Với picker giả (test) thì đi thẳng qua [PdfFilePicker].
final inAppPdfPickerProvider =
    Provider<Future<String?> Function(BuildContext, PdfPickMode)>((ref) {
      final picker = ref.read(pdfFilePickerProvider);
      if (picker is! SystemPdfFilePicker) {
        return (_, _) async {
          final picked = await picker.pickPdfs();
          return picked.isEmpty ? null : picked.first;
        };
      }
      return (context, mode) => Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => PdfPickScreen(mode: mode)),
      );
    });

/// PDF trong danh sách tài liệu đã lọc theo trạng thái khoá. Không cache lâu:
/// khoá/mở khoá xong quay lại danh sách phải đúng ngay.
final _pickablePdfsProvider = FutureProvider.autoDispose
    .family<List<DocItem>, PdfPickMode>((ref, mode) async {
      final all = await ref.watch(documentsProvider.future);
      final pdfs = all.where((d) => d.type == DocType.pdf).toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));
      final out = <DocItem>[];
      for (final d in pdfs) {
        final locked = await _isLocked(ref, d.path);
        if (locked == (mode == PdfPickMode.lockedOnly)) out.add(d);
      }
      return out;
    });

Future<bool> _isLocked(Ref ref, String path) async {
  // Dò nhanh dấu /Encrypt; chỉ file có dấu mới cần engine xác nhận.
  if (!await pdfHasEncryptMarker(path)) return false;
  return ref.watch(pdfLockedProvider(path).future);
}

/// Chọn một PDF từ danh sách trong app (chỉ PDF; theo [mode] chỉ file khoá/chưa khoá).
class PdfPickScreen extends ConsumerStatefulWidget {
  const PdfPickScreen({super.key, required this.mode});

  final PdfPickMode mode;

  @override
  ConsumerState<PdfPickScreen> createState() => _PdfPickScreenState();
}

class _PdfPickScreenState extends ConsumerState<PdfPickScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fromStorage() async {
    final picked = await ref.read(pdfFilePickerProvider).pickPdfs();
    if (!mounted || picked.isEmpty) return;
    Navigator.of(context).pop(picked.first);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final list = ref.watch(_pickablePdfsProvider(widget.mode));
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      // Ô tìm kiếm chữ trắng trên thanh tiêu đề → giữ nền đỏ chủ đạo, chữ/icon trắng.
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        title: AppSearchField(
          controller: _controller,
          hintText: l.docs_searchHint,
          autofocus: false,
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          IconButton(
            tooltip: l.core_open,
            icon: const Icon(Symbols.folder_open_rounded),
            onPressed: _fromStorage,
          ),
        ],
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Symbols.error_rounded,
          title: appErrorMessage(context, AppError.from(e)),
        ),
        data: (items) {
          final shown = filterDocuments(items, query: _controller.text);
          if (shown.isEmpty) {
            return EmptyState(
              illustration: const FileTypeIcon(DocType.pdf, size: 64),
              title: l.docs_emptySearch,
            );
          }
          final locked = widget.mode == PdfPickMode.lockedOnly;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: shown.length,
            itemBuilder: (_, i) {
              final d = shown[i];
              return CardRow(
                first: i == 0,
                last: i == shown.length - 1,
                child: _PickRow(
                  item: d,
                  locked: locked,
                  info: formatFileInfoLine(d.size, d.modified, d.folder, locale),
                  onTap: () => Navigator.of(context).pop(d.path),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Một dòng PDF trong màn chọn: như dòng tài liệu nhưng không có ⭐ ⋮.
/// Không có nền riêng — nền trắng bo góc do [CardRow] vẽ.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.item,
    required this.locked,
    required this.info,
    required this.onTap,
  });

  final DocItem item;
  final bool locked;
  final String info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              FileTypeIcon(item.type, size: 40, locked: locked),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: t.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
