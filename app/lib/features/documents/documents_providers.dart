import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/errors/app_error.dart';
import '../../core/platform/app_platform.dart';
import '../../core/utils/doc_type.dart';
import '../../core/utils/file_paths.dart';
import '../../core/utils/output_directory.dart';
import '../../data/db/app_database.dart';
import '../../data/file_scanner/file_scanner.dart';
import '../../data/file_scanner/scan_sync.dart';
import '../../data/settings/settings_providers.dart';
import '../../engines/pdf/pdf_security.dart';
import 'documents_logic.dart';

/// Thư mục gốc cố định để quét (test ghi đè). Rỗng ⇒ dùng [platformScanRootsProvider].
final scanRootsProvider = Provider<List<String>>((ref) => const []);

/// Gốc bộ nhớ chung trên Android: quét cả máy khi đã có quyền "Truy cập tất cả file"
/// (người dùng chọn giữ quyền này, chấp nhận khó lên Google Play).
const String androidStorageRoot = '/storage/emulated/0';

/// Thư mục lưu cũ trên Android (`Documents/PDF Office`): không ghi nữa, chỉ quét để thấy file cũ.
const String legacyAndroidOutputDir =
    '/storage/emulated/0/Documents/$legacyAppFolderName';

/// Thư mục quét trên Android: bộ nhớ chung [storageRoot] (cả máy), thư mục lưu kết quả [outputDir],
/// thư mục mặc định / cũ trong `Documents` (file đã lưu trước đó) và Documents riêng của app (có
/// `Imported`). Bỏ thư mục không tồn tại, bỏ trùng và bỏ thư mục nằm trong một thư mục khác đã có
/// (không quét hai lần). [storageRoot] rỗng ⇒ chỉ quét vùng của app.
Future<List<String>> androidScanRoots({
  required String outputDir,
  required String appDocumentsDir,
  String storageRoot = '',
  String defaultDir = defaultAndroidOutputDir,
  String legacyDir = legacyAndroidOutputDir,
}) async {
  final roots = <String>[];
  for (final dir in [
    if (storageRoot.isNotEmpty) storageRoot,
    outputDir,
    defaultDir,
    legacyDir,
    appDocumentsDir,
  ]) {
    final norm = p.normalize(dir);
    if (roots.any((r) => p.equals(r, norm) || p.isWithin(r, norm))) continue;
    if (!await Directory(norm).exists()) continue;
    roots
      ..removeWhere((r) => p.isWithin(norm, r))
      ..add(norm);
  }
  return roots;
}

/// Đường dẫn Documents riêng của app (test ghi đè).
final appDocumentsDirProvider = FutureProvider<String>(
  (ref) async => (await getApplicationDocumentsDirectory()).path,
);

/// Thư mục quét khi [scanRootsProvider] rỗng: iOS chỉ có vùng Documents của chính app
/// (file nhập từ Tệp + kết quả xuất); Android xem [androidScanRoots]; nền tảng khác → rỗng.
final platformScanRootsProvider = Provider<Future<List<String>> Function()>((
  ref,
) {
  final platform = ref.watch(appPlatformProvider);
  return () async => switch (platform) {
    AppPlatform.ios => [await ref.read(appDocumentsDirProvider.future)],
    AppPlatform.android => await androidScanRoots(
      storageRoot: androidStorageRoot,
      outputDir: await ref.read(outputDirectoryProvider.future),
      appDocumentsDir: await ref.read(appDocumentsDirProvider.future),
    ),
    AppPlatform.other => const <String>[],
  };
});

final fileScannerProvider = Provider<FileScanner>(
  (ref) => const IsolateFileScanner(),
);

/// Quyền truy cập bộ nhớ (để test thay bằng giả).
abstract interface class StoragePermissionService {
  /// Đã đủ quyền để lưu / liệt kê tài liệu chưa.
  Future<bool> isGranted();

  /// Xin quyền (hộp thoại hệ thống). `true` nếu được cấp.
  Future<bool> request();
}

/// Android 10 (API 29) trở xuống dùng quyền bộ nhớ thường; từ Android 11 cần "Truy cập tất cả file".
const int legacyStorageMaxSdk = 29;

/// Quyền để quét cả máy:
/// - Android 11+ (API ≥ 30): `Permission.manageExternalStorage` ("Truy cập tất cả file", mở trang
///   Cài đặt).
/// - Android 7–10 (API ≤ 29): `Permission.storage` (đọc/ghi bộ nhớ ngoài).
/// - Android không đọc được mức API: thử "Truy cập tất cả file" rồi tới quyền bộ nhớ.
/// - Nền tảng khác: `true`.
class PermissionHandlerStorage implements StoragePermissionService {
  const PermissionHandlerStorage({
    required this.platform,
    required this.sdkInt,
    this.storageGranted = _storageGranted,
    this.requestStorage = _requestStorage,
    this.manageGranted = _manageGranted,
    this.requestManage = _requestManage,
  });

  final AppPlatform platform;
  final Future<int?> Function() sdkInt;

  /// Trạng thái / xin `Permission.storage` (test thay bằng giả).
  final Future<bool> Function() storageGranted;
  final Future<bool> Function() requestStorage;

  /// Trạng thái / xin `Permission.manageExternalStorage` (test thay bằng giả).
  final Future<bool> Function() manageGranted;
  final Future<bool> Function() requestManage;

  static Future<bool> _storageGranted() => Permission.storage.isGranted;
  static Future<bool> _requestStorage() async =>
      (await Permission.storage.request()).isGranted;
  static Future<bool> _manageGranted() =>
      Permission.manageExternalStorage.isGranted;
  static Future<bool> _requestManage() async =>
      (await Permission.manageExternalStorage.request()).isGranted;

  @override
  Future<bool> isGranted() async {
    if (platform != AppPlatform.android) return true;
    final sdk = await sdkInt();
    if (sdk == null) return await manageGranted() || await storageGranted();
    return sdk <= legacyStorageMaxSdk ? storageGranted() : manageGranted();
  }

  @override
  Future<bool> request() async {
    if (platform != AppPlatform.android) return true;
    final sdk = await sdkInt();
    if (sdk == null) return await requestManage() || await requestStorage();
    return sdk <= legacyStorageMaxSdk ? requestStorage() : requestManage();
  }
}

final storagePermissionProvider = Provider<StoragePermissionService>(
  (ref) => PermissionHandlerStorage(
    platform: ref.watch(appPlatformProvider),
    sdkInt: () => ref.read(androidSdkIntProvider.future),
  ),
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
    // Android ≤10: lúc chưa có quyền, thư mục lưu đã rơi về vùng riêng của app → tính lại.
    ref.invalidate(outputDirectoryProvider);
    await _scan();
    return true;
  }

  /// Đặt đồng bộ ngay đầu `_scan`: `refresh` kiểm `isScanning` trước một `await`
  /// nên hai lời gọi gần nhau vẫn có thể cùng lọt vào quét.
  bool _scanning = false;

  Future<void> _scan() async {
    if (_scanning) return;
    _scanning = true;
    try {
      await _runScan();
    } finally {
      _scanning = false;
    }
  }

  Future<void> _runScan() async {
    var roots = ref.read(scanRootsProvider);
    if (roots.isEmpty) roots = await ref.read(platformScanRootsProvider)();
    if (!ref.mounted) return;
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
      // Gốc đọc được nhưng không thấy file và nhiều thư mục con bị chặn
      // (Android 11+: chưa bật "Truy cập tất cả file").
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
  return dao.watchAll().asyncMap(
    (rows) => _resolveExisting(ref, rows.map((r) => r.path).toList()),
  );
});

/// Danh sách Gần đây, mới mở trước; file không còn trên đĩa bị bỏ qua.
final recentItemsProvider = StreamProvider<List<DocItem>>((ref) {
  final dao = ref.watch(appDatabaseProvider).recentsDao;
  return dao.watchRecent().asyncMap(
    (rows) => _resolveExisting(ref, rows.map((r) => r.path).toList()),
  );
});

/// Dựng [DocItem] cho [paths] (giữ thứ tự) mà không chặn UI isolate: kiểm tồn tại bằng
/// `exists()` bất đồng bộ (song song); metadata lấy từ bảng `documents` nếu đã có trong
/// [documentsProvider], còn lại mới `stat` bất đồng bộ. File đã mất bị bỏ qua.
Future<List<DocItem>> _resolveExisting(Ref ref, List<String> paths) async {
  if (paths.isEmpty) return const [];
  final known = <String, DocItem>{
    for (final d in ref.read(documentsProvider).value ?? const <DocItem>[])
      d.path: d,
  };
  final items = await Future.wait(
    paths.map((path) async {
      try {
        if (!await File(path).exists()) return null;
        final cached = known[path];
        if (cached != null) return cached;
        final stat = await File(path).stat();
        return DocItem(
          path: path,
          name: p.basename(path),
          ext: extensionOf(path),
          size: stat.size,
          modified: stat.modified,
          folder: parentFolderName(path),
        );
      } on FileSystemException {
        return null;
      }
    }),
  );
  return [for (final item in items) ?item];
}

/// Chỉ [limit] mục đầu còn tồn tại: Trang chủ chỉ hiện vài mục nên không `stat` cả trăm file
/// (bộ nhớ trong của máy yếu chậm, làm trễ khung hình đầu).
List<DocItem> _firstExisting(Iterable<String> paths, int limit) {
  final out = <DocItem>[];
  for (final path in paths) {
    final item = DocItem.fromFileSync(path);
    if (item != null) out.add(item);
    if (out.length >= limit) break;
  }
  return out;
}

/// Số mục mỗi nhóm hiện ở Trang chủ.
const int homeSectionLimit = 5;

/// Yêu thích cho Trang chủ (tối đa [homeSectionLimit] mục).
final homeFavoriteItemsProvider = StreamProvider<List<DocItem>>((ref) {
  final dao = ref.watch(appDatabaseProvider).favoritesDao;
  return dao.watchAll().map(
    (rows) => _firstExisting(rows.map((r) => r.path), homeSectionLimit),
  );
});

/// Gần đây cho Trang chủ (tối đa [homeSectionLimit] mục).
final homeRecentItemsProvider = StreamProvider<List<DocItem>>((ref) {
  final dao = ref.watch(appDatabaseProvider).recentsDao;
  return dao.watchRecent().map(
    (rows) => _firstExisting(rows.map((r) => r.path), homeSectionLimit),
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

/// Toàn bộ tài liệu đã sắp xếp một lần; các tab chỉ lọc lại (giữ nguyên thứ tự) nên không sắp xếp 6 lần.
final _sortedDocumentsProvider =
    Provider.autoDispose<AsyncValue<List<DocItem>>>((ref) {
      final sort = ref.watch(docSortProvider);
      return ref
          .watch(documentsProvider)
          .whenData((items) => sortDocuments(items, sort));
    });

/// Tài liệu của một tab ([category] null = tất cả) đã sắp xếp theo lựa chọn hiện tại.
final categoryDocumentsProvider = Provider.autoDispose
    .family<AsyncValue<List<DocItem>>, DocCategory?>((ref, category) {
      return ref
          .watch(_sortedDocumentsProvider)
          .whenData((items) => filterDocuments(items, category: category));
    });

/// PDF có mật khẩu không (kết quả được cache theo path suốt phiên).
final pdfLockedProvider = FutureProvider.autoDispose.family<bool, String>((
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
