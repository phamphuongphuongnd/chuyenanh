import 'dart:ui' show Color;

import 'package:image_cropper/image_cropper.dart';

/// Cắt ảnh bằng màn cắt hệ thống. Tách interface để test.
abstract interface class CropService {
  /// Mở màn cắt cho [sourcePath]; trả về file ảnh đã cắt, `null` nếu người dùng huỷ.
  Future<String?> crop(
    String sourcePath, {
    required String title,
    required Color toolbarColor,
  });
}

class ImageCropperCropService implements CropService {
  const ImageCropperCropService();

  @override
  Future<String?> crop(
    String sourcePath, {
    required String title,
    required Color toolbarColor,
  }) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: toolbarColor,
          toolbarWidgetColor: const Color(0xFFFFFFFF),
          activeControlsWidgetColor: toolbarColor,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: const [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );
    return cropped?.path;
  }
}
