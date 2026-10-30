// Lập chỉ mục chữ của tài liệu (chạy nền) + tìm theo nội dung.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../documents/documents_logic.dart';
import '../documents/documents_providers.dart';
import 'data/text_extractor.dart';
import 'logic/search_text.dart';

/// Hàm trích chữ một file (test thay bằng giả). `null` = không có chữ / không đọc được.
typedef ContentExtractor = Future<PreparedText?> Function(
  String path,
  String ext,
);

final contentExtractorProvider = Provider<ContentExtractor>(
  (ref) => extractTextInIsolate,
);

/// Nghỉ giữa hai file để không chiếm CPU liên tục (test đặt `Duration.zero`).
final contentIndexPauseProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 400),
);

/// File có được lập chỉ mục không: đuôi đọc được và không quá [maxIndexedFileBytes].
bool isIndexable(DocItem d) =>
    indexableExtensions.contains(d.ext) && d.size <= maxIndexedFileBytes;

/// Tiến độ lập chỉ mục.
class ContentIndexState {
  const ContentIndexState({
    this.total = 0,
    this.done = 0,
    this.running = false,
  });

  /// Số file cần có chỉ mục (đuôi hỗ trợ, ≤ 50MB).
  final int total;

  /// Số file trong [total] đã có chỉ mục bản mới nhất.
  final int done;

  /// Vòng lập chỉ mục đang chạy (kể cả lúc tạm dừng vì app ở nền).
  final bool running;

  /// Còn file chưa lập chỉ mục → hiện dòng "Đang lập chỉ mục n/m file".
  bool get isIndexing => running && done < total;

  @override
  bool operator ==(Object other) =>
      other is ContentIndexState &&
      other.total == total &&
      other.done == done &&
      other.running == running;

  @override
  int get hashCode => Object.hash(total, done, running);
}

/// Bộ lập chỉ mục. Tự chạy khi được lắng nghe lần đầu (điểm khởi động: `ref.watch` trong
/// `SearchScreen`) và sống suốt phiên: lắng nghe [documentsProvider], mỗi lần danh sách đổi thì
/// trích chữ — TỪNG file một, nghỉ giữa các file, dừng khi app ở nền — cho file chưa có chỉ mục
/// hoặc đã đổi. Lưu ý Riverpod 3: chỉ `read` (không ai listen) thì provider bị tạm dừng, danh
/// sách tài liệu không tới; lúc không ai listen, thay đổi danh sách được giao lại khi có listener.
final contentIndexProvider =
    NotifierProvider<ContentIndexController, ContentIndexState>(
      ContentIndexController.new,
    );

class ContentIndexController extends Notifier<ContentIndexState> {
  /// Danh sách tài liệu mới nhất (chỉ file lập chỉ mục được).
  List<DocItem> _docs = const [];

  /// Danh sách đổi trong lúc đang chạy → tính lại hàng đợi.
  bool _dirty = false;
  bool _running = false;
  bool _disposed = false;

  bool _foreground = true;
  Completer<void>? _resumed;
  AppLifecycleListener? _lifecycle;

  @override
  ContentIndexState build() {
    _disposed = false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    ref.onDispose(() {
      _disposed = true;
      _lifecycle?.dispose();
      _lifecycle = null;
      _wake();
    });
    ref.listen<AsyncValue<List<DocItem>>>(documentsProvider, (_, next) {
      final items = next.value;
      if (items != null) _onDocuments(items);
    }, fireImmediately: true);
    return const ContentIndexState();
  }

  void _onLifecycle(AppLifecycleState s) {
    _foreground = s == AppLifecycleState.resumed;
    if (_foreground) _wake();
  }

  void _wake() {
    final c = _resumed;
    _resumed = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  void _onDocuments(List<DocItem> items) {
    _allPaths = {for (final d in items) d.path};
    _docs = [
      for (final d in items)
        if (isIndexable(d)) d,
    ];
    _dirty = true;
    if (!_running) unawaited(_run());
  }

  /// Path mọi tài liệu trong bảng `documents` (để dọn chỉ mục của file đã mất).
  Set<String> _allPaths = const {};

  void _set(ContentIndexState s) {
    if (_disposed || !ref.mounted) return;
    state = s;
  }

  Future<void> _run() async {
    _running = true;
    try {
      final dao = ref.read(appDatabaseProvider).documentTextsDao;
      final extract = ref.read(contentExtractorProvider);
      final pause = ref.read(contentIndexPauseProvider);
      var queue = <DocItem>[];
      var total = 0;
      while (!_disposed) {
        if (_dirty) {
          _dirty = false;
          final docs = _docs;
          // Dọn chữ của file đã mất. Danh sách rỗng (chưa quét / chưa có quyền) thì không
          // dọn để không xoá chỉ mục cũ.
          if (_allPaths.isNotEmpty) await dao.deleteExcept(_allPaths);
          if (_disposed) return;
          final byPath = {for (final d in docs) d.path: d};
          final stale = await dao.stalePaths([
            for (final d in docs)
              (
                path: d.path,
                modifiedMs: d.modified.millisecondsSinceEpoch,
                size: d.size,
              ),
          ]);
          if (_disposed) return;
          queue = [for (final p in stale) byPath[p]!];
          total = docs.length;
          _set(
            ContentIndexState(
              total: total,
              done: total - queue.length,
              running: queue.isNotEmpty,
            ),
          );
        }
        if (queue.isEmpty) break;

        // App ở nền → chờ quay lại mới chạy tiếp.
        while (!_foreground && !_disposed) {
          await (_resumed ??= Completer<void>()).future;
        }
        if (_disposed) return;

        final doc = queue.removeAt(0);
        final text = await extract(doc.path, doc.ext);
        if (_disposed) return;
        await dao.upsert(
          DocumentTextsCompanion.insert(
            path: doc.path,
            content: text?.content ?? '',
            normalized: text?.normalized ?? '',
            sourceModifiedMs: doc.modified.millisecondsSinceEpoch,
            sourceSize: doc.size,
            extractedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        _set(
          ContentIndexState(
            total: total,
            done: total - queue.length,
            running: queue.isNotEmpty || _dirty,
          ),
        );
        if (queue.isNotEmpty && pause > Duration.zero) {
          await Future<void>.delayed(pause);
        }
      }
    } catch (_) {
      // Lỗi DB (vd DB đóng khi thoát app): bỏ lượt này, lần đổi danh sách sau chạy lại.
    } finally {
      _running = false;
      if (!_disposed) {
        _set(
          ContentIndexState(
            total: state.total,
            done: state.done,
            running: false,
          ),
        );
        // Danh sách đổi đúng lúc vòng lặp vừa thoát.
        if (_dirty) unawaited(_run());
      }
    }
  }
}

/// Hàm tìm theo nội dung (test thay bằng giả). Nhận từ khoá đã [normalizeQuery].
typedef ContentSearcher = Future<List<ContentHit>> Function(
  String normalizedQuery,
);

final contentSearcherProvider = Provider<ContentSearcher>((ref) {
  final dao = ref.watch(appDatabaseProvider).documentTextsDao;
  return (q) => dao.searchHits(q);
});

/// Từ khoá ngắn hơn mức này không tìm trong nội dung (1 ký tự khớp gần như mọi file).
const int minContentQueryLength = 2;

/// Kết quả tìm theo nội dung cho từ khoá đã chuẩn hoá. Tự tìm lại khi lập chỉ mục tiến thêm
/// (mỗi 20 file) và khi xong.
final contentSearchProvider = FutureProvider.autoDispose
    .family<List<ContentHit>, String>((ref, normalizedQuery) async {
      if (normalizedQuery.length < minContentQueryLength) return const [];
      ref.watch(contentIndexProvider.select((s) => (s.running, s.done ~/ 20)));
      return ref.read(contentSearcherProvider)(normalizedQuery);
    });
