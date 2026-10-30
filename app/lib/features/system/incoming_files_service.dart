import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tên kênh — khớp `IncomingFilesChannel.CHANNEL` (Kotlin) và `IncomingFilesBridge` (Swift).
const String kIncomingChannelName = 'com.phuong.pdfoffice/incoming';

/// Một lô file native vừa nhận (đã chép vào cache / `Documents/Imported`).
class IncomingBatch {
  const IncomingBatch({
    this.paths = const [],
    this.failed = 0,
    this.unsupported = 0,
  });

  /// Native trả `{paths: [String], failed: int, unsupported: int}`; chấp nhận cả
  /// `List<String>` trần.
  factory IncomingBatch.fromNative(Object? raw) {
    if (raw is List) {
      return IncomingBatch(paths: _paths(raw));
    }
    if (raw is Map) {
      return IncomingBatch(
        paths: _paths(raw['paths']),
        failed: _count(raw['failed']),
        unsupported: _count(raw['unsupported']),
      );
    }
    return const IncomingBatch();
  }

  /// Đường dẫn bản sao native đã chép.
  final List<String> paths;

  /// Số file native không nhận được (lỗi đọc, mất quyền, quá 200 MB).
  final int failed;

  /// Số file native bỏ vì đuôi / mime không hỗ trợ.
  final int unsupported;

  bool get isEmpty => paths.isEmpty && failed == 0 && unsupported == 0;

  static List<String> _paths(Object? raw) => raw is List
      ? raw.whereType<String>().where((s) => s.isNotEmpty).toList()
      : const [];

  static int _count(Object? raw) => raw is int && raw > 0 ? raw : 0;
}

/// Cầu nối tới phần native. Nền tảng không có phần native (test, desktop): lô rỗng, không ném lỗi.
class IncomingFilesService {
  IncomingFilesService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(kIncomingChannelName);

  final MethodChannel _channel;

  /// File của intent / URL đã mở app (khởi động lạnh). Chỉ trả một lần.
  Future<IncomingBatch> takeInitial() async {
    try {
      return IncomingBatch.fromNative(
        await _channel.invokeMethod<Object?>('takeInitial'),
      );
    } on MissingPluginException {
      return const IncomingBatch();
    } on PlatformException {
      return const IncomingBatch();
    }
  }

  /// Native gọi `onFiles` khi app đang chạy và nhận file mới.
  void setFilesHandler(void Function(IncomingBatch batch)? handler) {
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFiles') {
        final batch = IncomingBatch.fromNative(call.arguments);
        if (!batch.isEmpty) handler(batch);
      }
      return null;
    });
  }
}

final incomingFilesServiceProvider = Provider<IncomingFilesService>(
  (ref) => IncomingFilesService(),
);
