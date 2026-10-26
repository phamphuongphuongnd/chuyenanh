import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../data/db/app_database.dart';
import 'logic/outline.dart';

/// Mọi thứ màn đọc cần để dựng viewer. Tách khỏi Syncfusion để widget test thay được
/// viewer thật (cần plugin native) bằng viewer giả.
class ReaderViewerConfig {
  const ReaderViewerConfig({
    required this.path,
    required this.controller,
    required this.initialPage,
    required this.horizontal,
    required this.singlePage,
    required this.onLoaded,
    required this.onPageChanged,
    required this.onLoadFailed,
    this.bytes,
  });

  /// File gốc trên đĩa.
  final String path;

  /// Có giá trị → mở từ bytes đã giải mã (PDF có mật khẩu), bỏ qua [path].
  final Uint8List? bytes;

  final PdfViewerController controller;

  /// Trang mở đầu, đánh số từ 1.
  final int initialPage;

  final bool horizontal;
  final bool singlePage;

  /// Tài liệu đã tải: tổng số trang + mục lục.
  final void Function(int pageCount, List<OutlineEntry> outline) onLoaded;

  /// Trang hiện tại đổi (đánh số từ 1).
  final void Function(int page) onPageChanged;

  /// Không mở được (file hỏng, hoặc cần mật khẩu).
  final void Function(String detail) onLoadFailed;
}

typedef ReaderViewerBuilder =
    Widget Function(BuildContext context, ReaderViewerConfig config);

/// Viewer thật: `SfPdfViewer`. Hộp thoại mật khẩu của Syncfusion tắt — app dùng
/// `showPasswordDialog` + `pdfSecurityProvider.decrypt`.
Widget buildSfPdfViewer(BuildContext context, ReaderViewerConfig c) {
  void loaded(PdfDocumentLoadedDetails d) =>
      c.onLoaded(d.document.pages.count, flattenOutline(d.document));
  void changed(PdfPageChangedDetails d) => c.onPageChanged(d.newPageNumber);
  void failed(PdfDocumentLoadFailedDetails d) =>
      c.onLoadFailed('${d.error}: ${d.description}');
  final direction = c.horizontal
      ? PdfScrollDirection.horizontal
      : PdfScrollDirection.vertical;
  final layout = c.singlePage
      ? PdfPageLayoutMode.single
      : PdfPageLayoutMode.continuous;

  final bytes = c.bytes;
  if (bytes != null) {
    return SfPdfViewer.memory(
      bytes,
      controller: c.controller,
      initialPageNumber: c.initialPage,
      scrollDirection: direction,
      pageLayoutMode: layout,
      maxZoomLevel: 5,
      canShowPasswordDialog: false,
      canShowPaginationDialog: false,
      onDocumentLoaded: loaded,
      onPageChanged: changed,
      onDocumentLoadFailed: failed,
    );
  }
  return SfPdfViewer.file(
    File(c.path),
    controller: c.controller,
    initialPageNumber: c.initialPage,
    scrollDirection: direction,
    pageLayoutMode: layout,
    maxZoomLevel: 5,
    canShowPasswordDialog: false,
    canShowPaginationDialog: false,
    onDocumentLoaded: loaded,
    onPageChanged: changed,
    onDocumentLoadFailed: failed,
  );
}

final readerViewerBuilderProvider = Provider<ReaderViewerBuilder>(
  (ref) => buildSfPdfViewer,
);

/// Tạo `PdfViewerController` (test thay bằng bản giả để quan sát lệnh nhảy trang).
final readerControllerFactoryProvider =
    Provider<PdfViewerController Function()>((ref) => PdfViewerController.new);

/// In PDF bằng hộp thoại in của hệ thống (`printing`). Test thay bằng bản giả.
typedef PdfPrinter = Future<void> Function(Uint8List bytes, String jobName);

final pdfPrinterProvider = Provider<PdfPrinter>(
  (ref) =>
      (bytes, name) =>
          Printing.layoutPdf(onLayout: (format) async => bytes, name: name),
);

/// Bookmark của một file (cập nhật tức thì khi đổi).
final bookmarksForPathProvider = StreamProvider.family<List<Bookmark>, String>(
  (ref, path) => ref.watch(appDatabaseProvider).bookmarksDao.watchForPath(path),
);
