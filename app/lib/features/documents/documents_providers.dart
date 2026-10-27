import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/errors/app_error.dart';
import '../../core/utils/doc_type.dart';
import '../../data/db/app_database.dart';
import '../../data/file_scanner/file_scanner.dart';
import '../../data/file_scanner/scan_sync.dart';
import '../../data/settings/settings_providers.dart';
import '../../engines/pdf/pdf_security.dart';
import 'documents_logic.dart';

/// Thư mục gốc để quét. Chỉ Android mới có `/storage/emulated/0`; máy khác → không quét.
final scanRootsProvider = Provider<List<String>>(
  (ref) => Platform.isAndroid ? const ['/storage/emulated/0'] : const [],
);

final fileScannerProvider = Provider<FileScanner>(
  (ref) => const IsolateFileScanner(),
);

/// Quyền truy cập bộ nhớ (để test thay bằng giả).
abstract interface class StoragePermissionService {
  /// Đã được cấp quyền đọc toàn bộ bộ nhớ chưa.
  Future<bool> isGranted();

  /// Xin quyền (Android 11+ mở trang cài đặt "Truy cập tất cả file"). `true` nếu được cấp.
  Future<bool> request();
}

/// Android 11+ cần `MANAGE_EXTERNAL_STORAGE`; Android 7–10 dùng quyền đọc bộ nhớ.
class PermissionHandlerStorage implements StoragePermissionService {
  const PermissionHandlerStorage();

  @override
  Future<bool> isGranted() async {
    if (!Platform.isAndroid) return true;
    return await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted;
  }

  @override
  Future<bool> request() async {
    if (!Platform.isAndroid) return true;
    // Android 11+ (R+): mở trang Cài đặt "Truy cập tất cả file".
    if (await Permission.manageExternalStorage.request().isGranted) return true;
    // Android ≤10: manageExternalStorage → RESTRICTED (không khả dụng trước API 30);
    // phải xin READ_EXTERNAL_STORAGE qua permission_handler.storage.
    return (await Permission.storage.request()).isGranted;
  }
}

final storagePermissionProvider = Provider<StoragePermissionService>(
  (ref) => const PermissionHandlerStorage(),
);

/// Giai đoạn của lượt quét.
enum ScanPhase { idle, scanning, done, needsPermission, failed }

class ScanState {
  const ScanState({
    this.phase = ScanPhase.idle,
    this.found = 0,
    this.lastFinishedAt,
    this.error,
  });

  final ScanPhase phase;

  /// Số file đã tìm thấy trong lượt quét đang chạy.
  final int found;
  final DateTime? lastFinishedAt;
  final AppError? error;

  bool get isScanning => phase == ScanPhase.scanning;
  bool get needsPermission => phase == ScanPhase.needsPermission;

  ScanState copyWith({
    ScanPhase? phase,
    int? found,
    DateTime? lastFinishedAt,
    AppError? error,
  }) => ScanState(
    phase: phase ?? this.phase,
    found: found ?? this.found,
    lastFinishedAt: lastFinishedAt ?? this.lastFinishedAt,
    error: error,
  );
}

/// Quét file + đồng bộ bảng `documents`. Tự quét một lần khi được đọc lần đầu.
final scanControllerProvider = NotifierProvider<ScanController, ScanState>(
  ScanController.new,
);

class ScanController extends Notifier<ScanState> {
  /// Quét lại khi app resume nhưng chưa quá khoảng này thì bỏ qua.
  static const resumeCooldown = Duration(seconds: 30);

  @override
  ScanState build() {
    Future.microtask(refresh);
    return const ScanState();
  }

  /// Quét lại. [force] = false: bỏ qua nếu đang quét hoặc vừa quét xong (dùng khi app resume).
  Future<void> refresh({bool force = true}) async {
    if (state.isScanning) return;
    final last = state.lastFinishedAt;
    if (!force &&
        state.phase == ScanPhase.done &&
        last != null &&
        DateTime.now().difference(last) < resumeCooldown) {
      return;
    }
    final granted = await ref.read(storagePermissionProvider).isGranted();
    if (!ref.mounted) return;
    if (!granted) {
      state = state.copyWith(phase: ScanPhase.needsPermission);
      return;
    }
    await _scan();
  }

  /// Xin quyền rồi quét. `true` nếu quyền được cấp.
  Future<bool> requestPermissionAndScan() async {
    final granted = await ref.read(storagePermissionProvider).request();
    if (!ref.mounted) return false;
    if (!granted) {
      state = state.copyWith(phase: ScanPhase.needsPermission);
      return false;
    }
    await _scan();
    return true;
  }

  Future<void> _scan() async {
    final roots = ref.read(scanRootsProvider);
    if (roots.isEmpty) {
      state = state.copyWith(
        phase: ScanPhase.done,
        lastFinishedAt: DateTime.now(),
      );
      return;
    }
    state = ScanState(
      phase: ScanPhase.scanning,
      lastFinishedAt: state.lastFinishedAt,
    );
    final startedMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final result = await ref
          .read(fileScannerProvider)
          .scan(
            roots,
            onProgress: (n) {
              if (!ref.mounted) return;
              state = ScanState(
                phase: ScanPhase.scanning,
                found: n,
                lastFinishedAt: state.lastFinishedAt,
              );
            },
          );
      if (!ref.mounted) return;
      // Đọc được 0 thư mục gốc ⇒ thực chất chưa có quyền.
      if (result.unreadableRoots.length == roots.length) {
        state = state.copyWith(phase: ScanPhase.needsPermission);
        return;
      }
      // Root đọc được nhưng không thấy file và nhiều thư mục con bị chặn
      // (Android 11-12: READ_EXTERNAL_STORAGE không đủ, cần MANAGE_EXTERNAL_STORAGE).
      if (result.files.isEmpty && result.skippedDirectories > 0) {
        state = state.copyWith(phase: ScanPhase.needsPermission);
        return;
      }
      await syncScanToDatabase(
        ref.read(appDatabaseProvider),
        result,
        startedMs,
      );
      if (!ref.mounted) return;
      state = ScanState(
        phase: ScanPhase.done,
        found: result.files.length,
        lastFinishedAt: DateTime.now(),
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = ScanState(
        phase: ScanPhase.failed,
        lastFinishedAt: state.lastFinishedAt,
        error: AppError.from(e),
      );
    }
  }
}

/// Mọi tài liệu trong bảng `documents` (tự cập nhật khi quét xong / đổi tên / xoá).
final documentsProvider = StreamProvider<List<DocItem>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.documentsDao.watchAll().map(
    (rows) => [for (final r in rows) DocItem.fromDocument(r)],
  );
});

/// Các path đã đánh dấu ⭐.
final favoritePathsProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(appDatabaseProvider).favoritesDao.watchPaths(),
);

/// Danh sách Yêu thích, mới thêm trước; file không còn trên đĩa bị bỏ qua.
final favoriteItemsProvider = StreamProvider<List<DocItem>>((ref) {
  final dao = ref.watch(appDatabaseProvider).favoritesDao;
  return dao.watchAll().map(
    (rows) => [for (final r in rows) ?DocItem.fromFileSync(r.path)],
  );
});

/// Danh sách Gần đây, mới mở trước; file không còn trên đĩa bị bỏ qua.
final recentItemsProvider = StreamProvider<List<DocItem>>((ref) {
  final dao = ref.watch(appDatabaseProvider).recentsDao;
  return dao.watchRecent().map(
    (rows) => [for (final r in rows) ?DocItem.fromFileSync(r.path)],
  );
});

/// Cách sắp xếp đang chọn (lưu lại giữa các lần mở app).
final docSortProvider = NotifierProvider<DocSortNotifier, DocSort>(
  DocSortNotifier.new,
);

class DocSortNotifier extends Notifier<DocSort> {
  static const prefsKey = 'documents.sort';

  @override
  DocSort build() =>
      DocSort.fromName(ref.read(sharedPreferencesProvider).getString(prefsKey));

  Future<void> set(DocSort sort) async {
    state = sort;
    await ref.read(sharedPreferencesProvider).setString(prefsKey, sort.name);
  }
}

/// Tài liệu của một tab ([category] null = tất cả) đã sắp xếp theo lựa chọn hiện tại.
final categoryDocumentsProvider =
    Provider.family<AsyncValue<List<DocItem>>, DocCategory?>((ref, category) {
      final sort = ref.watch(docSortProvider);
      return ref
          .watch(documentsProvider)
          .whenData(
            (items) =>
                sortDocuments(filterDocuments(items, category: category), sort),
          );
    });

/// PDF có mật khẩu không (kết quả được cache theo path suốt phiên).
final pdfLockedProvider = FutureProvider.family<bool, String>((
  ref,
  path,
) async {
  if (extensionOf(path) != 'pdf') return false;
  if (!await pdfHasEncryptMarker(path)) return false;
  try {
    final bytes = await File(path).readAsBytes();
    return await ref.read(pdfSecurityProvider).isEncrypted(bytes);
  } on AppError {
    return false;
  } on FileSystemException {
    return false;
  }
});
