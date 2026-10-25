import '../errors/app_error.dart';

/// Tiến độ 0.0 → 1.0.
typedef ProgressCallback = void Function(double progress);

/// Cờ huỷ cho việc nặng. Engine gọi [throwIfCancelled] giữa các bước (mỗi trang / mỗi ảnh).
class CancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in List.of(_listeners)) {
      l();
    }
    _listeners.clear();
  }

  /// Gọi [listener] khi bị huỷ (gọi ngay nếu đã huỷ).
  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  /// Ném [Cancelled] nếu đã huỷ.
  void throwIfCancelled() {
    if (_cancelled) throw const Cancelled();
  }
}
