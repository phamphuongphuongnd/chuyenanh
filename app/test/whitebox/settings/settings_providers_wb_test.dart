// Kiểm thử hộp trắng A13 — app/lib/features/settings/settings_providers.dart
// Thiết kế: test-output/whitebox/settings/settings_providers/buoc-1..5. Expected chép từ Bước 5.
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_office/features/settings/settings_providers.dart';

class _FakePicker extends FilePickerPlatform {
  _FakePicker(this.result);
  final String? result;
  String? title;
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    title = dialogTitle;
    return result;
  }
}

void main() {
  late FilePickerPlatform saved;
  setUp(() => saved = FilePickerPlatform.instance);
  tearDown(() => FilePickerPlatform.instance = saved);

  test('1-1 chuyển tiếp tới FilePicker.getDirectoryPath với tiêu đề', () async {
    final f = _FakePicker('/sd/Docs');
    FilePickerPlatform.instance = f;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final r = await c.read(directoryPickerProvider)('Chọn thư mục');
    expect(f.title, 'Chọn thư mục');
    expect(r, '/sd/Docs');
  });
  test('1-1b huỷ ⇒ null', () async {
    FilePickerPlatform.instance = _FakePicker(null);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await c.read(directoryPickerProvider)('x'), isNull);
  });
}
