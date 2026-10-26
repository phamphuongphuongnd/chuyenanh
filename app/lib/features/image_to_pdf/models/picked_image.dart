import '../services/gallery_service.dart';

/// Một mục đã chọn ở màn chọn ảnh: ảnh trong thư viện, hoặc file vừa chụp bằng camera.
class PickedImage {
  const PickedImage._(this.key, this.asset, this.filePath);

  factory PickedImage.fromAsset(GalleryAsset asset) =>
      PickedImage._('a:${asset.id}', asset, null);

  factory PickedImage.fromFile(String path) =>
      PickedImage._('f:$path', null, path);

  /// Khoá duy nhất (so sánh bằng khoá).
  final String key;
  final GalleryAsset? asset;
  final String? filePath;

  @override
  bool operator ==(Object other) => other is PickedImage && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
