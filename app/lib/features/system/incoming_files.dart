import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/navigation/open_file_args.dart';
import '../../core/platform/app_platform.dart';
import '../../core/router/app_router.dart';
import '../../core/router/routes.dart';
import '../../core/utils/doc_type.dart';
import '../../core/utils/file_import.dart' show importedFolderName;
import '../../core/utils/output_directory.dart';
import '../../data/db/app_database.dart';
import 'incoming_action.dart';
import 'incoming_files_service.dart';

export 'incoming_action.dart';
export 'incoming_files_service.dart';

/// Thư mục con của `cacheDir` nơi native Android chép file nhận được (khớp Kotlin).
const String incomingCacheFolderName = 'incoming';

/// Nhận file mở từ app khác (Android VIEW/SEND/SEND_MULTIPLE, iOS "Mở trong") rồi mở đúng màn.
///
/// Điểm nối: `app.dart` chỉ `ref.watch(incomingFilesProvider)`. Lấy lô khởi động lạnh
/// (`takeInitial`) một lần, sau đó nghe `onFiles` khi app đang chạy. Các lô xử lý tuần tự.
final incomingFilesProvider = Provider<void>((ref) {
  final service = ref.watch(incomingFilesServiceProvider);
  var disposed = false;
  var chain = Future<void>.value();

  Future<void> run(IncomingBatch batch) async {
    if (disposed) return;
    await handleIncomingBatch(ref, batch, isActive: () => !disposed);
  }

  void enqueue(IncomingBatch batch) {
    if (disposed || batch.isEmpty) return;
    chain = chain.then((_) => run(batch)).catchError((Object e, StackTrace st) {
      debugPrint('incoming: $e\n$st');
    });
  }

  service.setFilesHandler(enqueue);
  ref.onDispose(() {
    disposed = true;
    service.setFilesHandler(null);
  });
  service.takeInitial().then(enqueue);
});

// ---------------------------------------------------------------- phụ thuộc (ghi đè trong test)

/// Thư mục native được phép đặt file vào. File ngoài các thư mục này bị từ chối.
///  - Android: `cacheDir/incoming`;
///  - iOS: `Documents/Imported`.
final incomingSourceRootsProvider = FutureProvider<List<String>>((ref) async {
  switch (ref.watch(appPlatformProvider)) {
    case AppPlatform.android:
      final tmp = await getTemporaryDirectory();
      return [p.join(tmp.path, incomingCacheFolderName)];
    case AppPlatform.ios:
      final docs = await getApplicationDocumentsDirectory();
      return [p.join(docs.path, importedFolderName)];
    case AppPlatform.other:
      return const [];
  }
});

/// Thư mục bền để chép file từ cache sang (Android: `Documents/Phiotron PDF/Imported`, theo cài
/// đặt thư mục lưu). `null` = không cần chép (iOS: native đã đặt sẵn vào `Documents/Imported`).
final incomingTargetDirProvider = FutureProvider<String?>((ref) async {
  if (ref.watch(appPlatformProvider) != AppPlatform.android) return null;
  final out = await ref.watch(outputDirectoryProvider.future);
  return p.join(out, importedFolderName);
});

/// Mở .doc/.xls/.ppt bằng app ngoài; `true` = đã mở được.
typedef IncomingExternalOpener = Future<bool> Function(String path);

final incomingExternalOpenerProvider = Provider<IncomingExternalOpener>(
  (ref) => openWithExternalApp,
);

/// Hiện thông báo (SnackBar) cho người dùng.
typedef IncomingNotify = void Function(List<IncomingNotice> notices);

final incomingNotifierProvider = Provider<IncomingNotify>(
  (ref) => showIncomingNotices,
);

// ---------------------------------------------------------------- thông báo

enum IncomingNoticeKind { unsupported, failed, openFailed, savedOthers }

class IncomingNotice {
  const IncomingNotice(this.kind, [this.count = 0]);
  final IncomingNoticeKind kind;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is IncomingNotice && other.kind == kind && other.count == count;

  @override
  int get hashCode => Object.hash(kind, count);

  @override
  String toString() => 'IncomingNotice($kind, $count)';
}

String incomingNoticeText(AppLocalizations l, IncomingNotice n) =>
    switch (n.kind) {
      IncomingNoticeKind.unsupported => l.incoming_unsupported,
      IncomingNoticeKind.failed => l.incoming_failed(n.count),
      IncomingNoticeKind.openFailed => l.incoming_openFailed,
      IncomingNoticeKind.savedOthers => l.incoming_savedOthers(n.count),
    };

/// SnackBar qua `rootNavigatorKey` (không cần BuildContext của màn nào).
void showIncomingNotices(List<IncomingNotice> notices) {
  if (notices.isEmpty) return;
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (l == null || messenger == null) return;
  final text = notices.map((n) => incomingNoticeText(l, n)).join('\n');
  messenger.showSnackBar(SnackBar(content: Text(text)));
}

// ---------------------------------------------------------------- xử lý một lô

/// Kiểm tra → chép vào thư mục bền → ghi "Gần đây" → mở màn theo [planIncoming] → thông báo.
/// [isActive] trả `false` khi provider đã huỷ (dừng giữa chừng sau mỗi bước `await`).
Future<void> handleIncomingBatch(
  Ref ref,
  IncomingBatch batch, {
  bool Function()? isActive,
}) async {
  bool alive() => isActive?.call() ?? true;

  var failed = batch.failed;
  var unsupported = batch.unsupported;

  // 1. Chỉ nhận đuôi hỗ trợ, nằm trong thư mục native được phép, còn tồn tại.
  final roots = await ref.read(incomingSourceRootsProvider.future);
  final accepted = <String>[];
  for (final path in batch.paths) {
    if (!isSupportedIncomingPath(path)) {
      unsupported++;
    } else if (!isWithinIncomingRoots(path, roots) ||
        !await File(path).exists()) {
      failed++;
    } else {
      accepted.add(path);
    }
  }
  if (!alive()) return;

  // 2. Android: chép từ cache sang thư mục bền rồi xoá bản cache.
  String? target;
  try {
    target = await ref.read(incomingTargetDirProvider.future);
  } on Object {
    target = null;
  }
  final paths = <String>[];
  for (final path in accepted) {
    if (target == null) {
      paths.add(path);
      continue;
    }
    try {
      final saved = await persistIncomingFile(path, target);
      if (!p.equals(saved, path)) await _deleteQuietly(path);
      paths.add(saved);
    } on FileSystemException {
      // Không ghi được thư mục bền: vẫn mở từ bản trong cache.
      paths.add(path);
    }
  }
  if (!alive()) return;

  // 3. Chọn hành động, ghi "Gần đây" cho tài liệu (ảnh thì không).
  final plan = planIncoming(paths);
  unsupported += plan.unsupported;
  final recents = ref.read(appDatabaseProvider).recentsDao;
  for (final path in paths) {
    if (!documentExtensions.contains(extensionOf(path))) continue;
    await recents.touch(path).catchError((Object _) {});
  }
  if (!alive()) return;

  // 4. Mở màn.
  final notices = <IncomingNotice>[];
  final router = ref.read(appRouterProvider);
  switch (plan.action) {
    case OpenInApp(:final path, :final route):
      final Object extra = route == Routes.pdfReader
          ? OpenFileArgs(path)
          : path;
      unawaited(router.push<void>(route, extra: extra));
    case OpenExternal(:final path):
      final ok = await ref.read(incomingExternalOpenerProvider)(path);
      if (!ok) notices.add(const IncomingNotice(IncomingNoticeKind.openFailed));
    case ImagesToPdf(:final paths):
      unawaited(
        router.push<void>(Routes.imageToPdf, extra: <String>[...paths]),
      );
    case MergePdfs(:final first):
      unawaited(router.push<void>(Routes.merge, extra: first));
    case NothingToOpen():
      break;
  }

  // 5. Thông báo.
  if (unsupported > 0) {
    notices.add(const IncomingNotice(IncomingNoticeKind.unsupported));
  }
  if (failed > 0) {
    notices.add(IncomingNotice(IncomingNoticeKind.failed, failed));
  }
  if (plan.notOpened > 0) {
    notices.add(IncomingNotice(IncomingNoticeKind.savedOthers, plan.notOpened));
  }
  if (notices.isNotEmpty && alive()) {
    ref.read(incomingNotifierProvider)(notices);
  }
}

// ---------------------------------------------------------------- tiện ích file

/// [path] nằm trong một trong các [roots] (so sau khi giải symlink).
bool isWithinIncomingRoots(String path, List<String> roots) {
  final real = _realPath(path);
  return roots.any((root) => p.isWithin(_realPath(root), real));
}

String _realPath(String path) {
  try {
    return File(path).resolveSymbolicLinksSync();
  } on FileSystemException {
    return p.normalize(p.absolute(path));
  }
}

/// Chép [source] vào thư mục [dir]: `a.pdf`, `a (1).pdf`…; cùng tên và cùng dung lượng thì
/// dùng lại bản cũ (như `importIntoAppDocuments`). Đã nằm trong [dir] thì trả nguyên.
Future<String> persistIncomingFile(String source, String dir) async {
  if (p.isWithin(dir, source)) return source;
  final file = File(source);
  await Directory(dir).create(recursive: true);
  final base = p.basenameWithoutExtension(source);
  final ext = p.extension(source);
  final length = await file.length();
  for (var i = 0; ; i++) {
    final name = i == 0 ? '$base$ext' : '$base ($i)$ext';
    final target = File(p.join(dir, name));
    if (!await target.exists()) {
      await file.copy(target.path);
      return target.path;
    }
    if (await target.length() == length) return target.path;
  }
}

Future<void> _deleteQuietly(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // Bản cache — để hệ thống / native dọn sau.
  }
}

/// Như nhánh đời cũ của `openDocument`: chép vào `cache/open_external` rồi `OpenFilex`.
Future<bool> openWithExternalApp(String path) async {
  try {
    final cacheDir = await getTemporaryDirectory();
    final copy = p.join(cacheDir.path, 'open_external', p.basename(path));
    await Directory(p.dirname(copy)).create(recursive: true);
    await File(path).copy(copy);
    final result = await OpenFilex.open(copy);
    return result.type == ResultType.done;
  } on Object {
    return false;
  }
}
