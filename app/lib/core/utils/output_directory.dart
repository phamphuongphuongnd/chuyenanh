import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/settings/settings_providers.dart';

const String appFolderName = 'Phiotron PDF';

/// Tên thư mục lưu cũ (trước 30/10/2026). Không ghi vào nữa nhưng file cũ vẫn nằm ở đó: Android hiện quét
/// toàn bộ bộ nhớ, iOS quét cả `Documents` nên vẫn thấy; khi thôi quét toàn máy phải đưa thư mục này vào danh sách quét.
const String legacyAppFolderName = 'PDF Office';

/// Thư mục mặc định trên Android: `/storage/emulated/0/Documents/Phiotron PDF`.
const String defaultAndroidOutputDir =
    '/storage/emulated/0/Documents/$appFolderName';

/// Thư mục lưu kết quả theo cài đặt `outputDir` (null = mặc định), đã được tạo sẵn.
///
/// Dùng: `final dir = await ref.read(outputDirectoryProvider.future);`
/// (được cả trong `Ref` lẫn `WidgetRef`). Tự tính lại khi người dùng đổi thư mục.
final outputDirectoryProvider = FutureProvider<String>((ref) async {
  final configured = ref.watch(settingsProvider.select((s) => s.outputDir));
  return resolveOutputDirectory(configured);
});

/// Không tạo được thư mục cấu hình (thiếu quyền, thẻ nhớ bị rút…) → rơi về
/// `<app documents>/Phiotron PDF`.
Future<String> resolveOutputDirectory(String? configured) async {
  final candidates = <String>[
    if (configured != null && configured.isNotEmpty) configured,
    if (Platform.isAndroid) defaultAndroidOutputDir,
  ];
  for (final dir in candidates) {
    if (await _ensureDir(dir)) return dir;
  }
  final docs = await getApplicationDocumentsDirectory();
  final fallback = p.join(docs.path, appFolderName);
  await Directory(fallback).create(recursive: true);
  return fallback;
}

Future<bool> _ensureDir(String dir) async {
  try {
    await Directory(dir).create(recursive: true);
    // Thư mục đã có nhưng không ghi được (mất quyền) thì `create` vẫn thành công.
    final probe = File(p.join(dir, '.write_test_$pid'));
    await probe.writeAsString('');
    await probe.delete();
    return true;
  } on FileSystemException {
    return false;
  }
}
