import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pdf_file_picker.dart';
import 'pdf_pick_screen.dart';
import 'tool_runner.dart';

/// Phần dùng chung của màn công cụ làm việc trên MỘT file PDF: nhận path từ route (hoặc tự
/// mở hộp chọn file), mở thử (hỏi mật khẩu nếu cần), giữ kết quả để hiện màn kết quả.
mixin SinglePdfToolState<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Path nhận qua `extra` của route (null = tự chọn).
  String? get initialPath;

  PdfInput? input;
  bool loading = false;

  /// Các file kết quả; khác null = đang hiện màn kết quả.
  List<String>? results;

  /// Gọi khi [input] đổi (đã chọn file mới) — màn con dựng lại trạng thái riêng.
  void onInputReady(PdfInput input) {}

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) start();
    });
  }

  Future<void> start() async {
    final path = initialPath;
    if (path != null) {
      await _load(path);
    } else {
      await pickNew();
    }
  }

  /// Mở hộp chọn file rồi nạp file mới (huỷ → giữ file cũ).
  Future<void> pickNew() async {
    final mode = pickMode;
    if (mode != null) {
      final path = await ref.read(inAppPdfPickerProvider)(context, mode);
      if (!mounted || path == null) return;
      await _load(path);
      return;
    }
    final picked = await ref.read(pdfFilePickerProvider).pickPdfs();
    if (!mounted || picked.isEmpty) return;
    await _load(picked.first);
  }

  /// Khác null = chọn file từ danh sách PDF trong app (đã lọc theo trạng thái khoá).
  PdfPickMode? get pickMode => null;

  Future<void> _load(String path) async {
    setState(() => loading = true);
    final loaded = await loadPdfInput(context, ref, path);
    if (!mounted) return;
    setState(() {
      loading = false;
      if (loaded != null) {
        input = loaded;
        results = null;
      }
    });
    if (loaded != null) onInputReady(loaded);
  }

  /// Ghi nhận kết quả: lưu vào bảng documents và hiện màn kết quả.
  Future<void> finish(List<String> paths) async {
    await registerOutputs(ref, paths);
    if (!mounted) return;
    setState(() => results = paths);
  }
}
