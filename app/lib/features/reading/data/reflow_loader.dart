import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf_layout/pdf_layout.dart';

import '../../../core/errors/app_error.dart';
import '../../convert/engine/pdf_extract.dart';
import '../logic/reflow_document.dart';

/// Đọc PDF ở [path] (mật khẩu [password] nếu có) thành [ReflowDocument].
/// Ném [PasswordRequired] / [WrongPassword] / [CorruptFile]; PDF quét → `ReflowDocument.empty`.
typedef ReflowLoader =
    Future<ReflowDocument> Function(String path, {String? password});

/// Nguồn chữ của màn đọc dàn chữ — test override bằng dữ liệu giả.
final reflowLoaderProvider = Provider<ReflowLoader>(
  (ref) => loadReflowDocument,
);

/// Trích chữ (`extractLayoutPages`) + dựng khối (`rebuildDocument`) trong isolate riêng.
Future<ReflowDocument> loadReflowDocument(
  String path, {
  String? password,
}) async {
  final Uint8List bytes;
  try {
    bytes = await File(path).readAsBytes();
  } catch (e) {
    final err = AppError.from(e);
    throw err is Unknown ? CorruptFile('$e') : err;
  }
  return Isolate.run(() {
    final pages = extractLayoutPages(bytes, password: password);
    if (!hasAnyText(pages)) {
      return ReflowDocument.empty(pageCount: pages.length);
    }
    return buildReflowDocument(rebuildDocument(pages));
  });
}
