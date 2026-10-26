import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:office_reader/office_reader.dart' as rd;
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/widgets.dart';
import '../data/office_io.dart';
import '../data/text_decoder.dart';
import '../widgets/docx_view.dart';
import '../widgets/txt_viewer_page.dart';
import '../widgets/xlsx_view.dart';

final txtContentProvider = FutureProvider.autoDispose
    .family<DecodedText, String>((ref, path) => readTextFile(path));

final docxContentProvider = FutureProvider.autoDispose
    .family<rd.DocxDocument, String>((ref, path) => readDocxFile(path));

final xlsxContentProvider = FutureProvider.autoDispose
    .family<rd.XlsxWorkbook, String>((ref, path) => readXlsxFile(path));

/// Khung chờ / lỗi chung của 3 màn xem.
class _LoadScaffold extends StatelessWidget {
  const _LoadScaffold({
    required this.path,
    required this.color,
    required this.body,
  });

  final String path;
  final Color color;
  final Widget body;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: color,
      foregroundColor: Colors.white,
      title: Text(p.basename(path), overflow: TextOverflow.ellipsis),
    ),
    body: body,
  );
}

Widget _error(BuildContext context, Object e, VoidCallback retry) {
  final msg = appErrorMessage(context, AppError.from(e));
  return EmptyState(
    icon: Icons.error_outline,
    title: msg,
    actionLabel: context.l10n.core_retry,
    onAction: retry,
  );
}

class TxtViewerScreen extends ConsumerWidget {
  const TxtViewerScreen({super.key, required this.path});
  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = this.path;
    if (path == null) return const Scaffold(body: SizedBox.shrink());
    final async = ref.watch(txtContentProvider(path));
    return async.when(
      data: (c) => TxtViewerPage(path: path, content: c),
      loading: () => _LoadScaffold(
        path: path,
        color: const Color(0xFF78909C),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _LoadScaffold(
        path: path,
        color: const Color(0xFF78909C),
        body: _error(context, e, () => ref.invalidate(txtContentProvider(path))),
      ),
    );
  }
}

class DocxViewerScreen extends ConsumerWidget {
  const DocxViewerScreen({super.key, required this.path});
  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = this.path;
    if (path == null) return const Scaffold(body: SizedBox.shrink());
    final async = ref.watch(docxContentProvider(path));
    return async.when(
      data: (d) => DocxViewerPage(path: path, document: d),
      loading: () => _LoadScaffold(
        path: path,
        color: const Color(0xFF1E88E5),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _LoadScaffold(
        path: path,
        color: const Color(0xFF1E88E5),
        body: _error(context, e, () => ref.invalidate(docxContentProvider(path))),
      ),
    );
  }
}

class XlsxViewerScreen extends ConsumerWidget {
  const XlsxViewerScreen({super.key, required this.path});
  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = this.path;
    if (path == null) return const Scaffold(body: SizedBox.shrink());
    final async = ref.watch(xlsxContentProvider(path));
    return async.when(
      data: (w) => XlsxViewerPage(path: path, workbook: w),
      loading: () => _LoadScaffold(
        path: path,
        color: const Color(0xFF43A047),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _LoadScaffold(
        path: path,
        color: const Color(0xFF43A047),
        body: _error(context, e, () => ref.invalidate(xlsxContentProvider(path))),
      ),
    );
  }
}
