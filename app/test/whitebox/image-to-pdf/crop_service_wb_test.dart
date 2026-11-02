// ignore_for_file: depend_on_referenced_packages
// Kiểm thử hộp trắng (A06) — services/crop_service.dart. Mã bộ = buoc-5-du-lieu-thu.md của crop_service.
// Plugin image_cropper được thay bằng bản giả qua `ImageCropperPlatform.instance`.
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:image_cropper_platform_interface/image_cropper_platform_interface.dart';
import 'package:pdf_office/features/image_to_pdf/services/crop_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeCropper extends Fake
    with MockPlatformInterfaceMixin
    implements ImageCropperPlatform {
  _FakeCropper(this.result);
  final String? result;
  final List<(String, ImageCompressFormat, List<PlatformUiSettings>?)> calls = [];

  @override
  Future<CroppedFile?> cropImage({
    required String sourcePath,
    int? maxWidth,
    int? maxHeight,
    CropAspectRatio? aspectRatio,
    ImageCompressFormat compressFormat = ImageCompressFormat.jpg,
    int compressQuality = 90,
    List<PlatformUiSettings>? uiSettings,
  }) async {
    calls.add((sourcePath, compressFormat, uiSettings));
    return result == null ? null : CroppedFile(result!);
  }
}

void main() {
  late ImageCropperPlatform saved;
  setUp(() => saved = ImageCropperPlatform.instance);
  tearDown(() => ImageCropperPlatform.instance = saved);

  const svc = ImageCropperCropService();

  group('U1 crop', () {
    test('1-1 người dùng huỷ màn cắt ⇒ null', () async {
      final f = _FakeCropper(null);
      ImageCropperPlatform.instance = f;
      final r = await svc.crop('/src.jpg', title: 'Crop', toolbarColor: const Color(0xFFE53935));
      expect(f.calls.single.$1, '/src.jpg');
      expect(r, isNull);
    });
    test('1-2 cắt xong ⇒ đường dẫn file đã cắt (JPEG)', () async {
      final f = _FakeCropper('/cropped.jpg');
      ImageCropperPlatform.instance = f;
      final r = await svc.crop('/src.jpg', title: 'Crop', toolbarColor: const Color(0xFFE53935));
      expect(f.calls.single.$1, '/src.jpg');
      expect(f.calls.single.$2, ImageCompressFormat.jpg);
      expect(r, '/cropped.jpg');
    });
  });
}
