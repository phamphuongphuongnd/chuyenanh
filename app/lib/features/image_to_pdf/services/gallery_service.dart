import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import '../models/image_item.dart' show embeddedLongSide;

/// Quyền truy cập thư viện ảnh.
enum GalleryAccess {
  /// Đọc được toàn bộ ảnh.
  granted,

  /// Chỉ một phần ảnh người dùng cho phép (Android 14+ "chọn ảnh").
  limited,

  /// Bị từ chối.
  denied,
}

/// Một album ảnh (thư mục).
class GalleryAlbum {
  const GalleryAlbum({
    required this.id,
    required this.name,
    required this.count,
    this.native,
  });

  final String id;
  final String name;
  final int count;

  /// Đối tượng gốc của plugin (chỉ [GalleryService] dùng).
  final Object? native;
}

/// Một ảnh trong thư viện.
class GalleryAsset {
  const GalleryAsset({
    required this.id,
    this.width = 0,
    this.height = 0,
    this.native,
  });

  final String id;
  final int width;
  final int height;
  final Object? native;
}

/// Truy cập thư viện ảnh của máy. Tách thành interface để widget test dùng bản giả.
abstract interface class GalleryService {
  Future<GalleryAccess> requestAccess();

  /// Album có ảnh, album "Tất cả / Gần đây" đứng đầu.
  Future<List<GalleryAlbum>> albums();

  /// Một trang ảnh của [album], mới nhất trước. Trang trống = hết.
  Future<List<GalleryAsset>> assets(
    GalleryAlbum album, {
    required int page,
    required int pageSize,
  });

  /// Ảnh thu nhỏ (JPEG) để hiện lưới.
  Future<Uint8List?> thumbnail(GalleryAsset asset, {int size = 256});

  /// File ảnh dùng được cho engine (JPG/PNG/WebP/BMP/GIF). HEIC/HEIF/định dạng lạ được
  /// đổi sang JPEG bằng codec native (cạnh dài ≤ 3000px) và ghi vào [workDir].
  /// `null` nếu không lấy được.
  Future<String?> resolveFile(GalleryAsset asset, Directory workDir);

  /// Mở màn cài đặt quyền của app.
  Future<void> openSettings();
}

/// Phần mở rộng/mime mà image_ops giải mã được trực tiếp.
const Set<String> _directMimes = {
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/bmp',
  'image/gif',
};

/// Mime có thể đọc thẳng không cần đổi định dạng. Hàm thuần — có test.
bool isDirectlyDecodableMime(String? mime) =>
    mime != null && _directMimes.contains(mime.toLowerCase());

/// Kích thước thu nhỏ giữ tỉ lệ sao cho cạnh dài ≤ [maxSide] (không phóng to).
({int width, int height}) fitWithin(int width, int height, int maxSide) {
  if (width <= 0 || height <= 0) return (width: maxSide, height: maxSide);
  final longest = math.max(width, height);
  if (longest <= maxSide) return (width: width, height: height);
  final k = maxSide / longest;
  return (
    width: math.max(1, (width * k).round()),
    height: math.max(1, (height * k).round()),
  );
}

/// Impl bằng `photo_manager`.
class PhotoManagerGalleryService implements GalleryService {
  const PhotoManagerGalleryService();

  @override
  Future<GalleryAccess> requestAccess() async {
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );
    if (state == PermissionState.limited) return GalleryAccess.limited;
    return state.isAuth ? GalleryAccess.granted : GalleryAccess.denied;
  }

  @override
  Future<List<GalleryAlbum>> albums() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate)],
      ),
    );
    final result = <GalleryAlbum>[];
    for (final p in paths) {
      final count = await p.assetCountAsync;
      if (count <= 0) continue;
      result.add(
        GalleryAlbum(id: p.id, name: p.name, count: count, native: p),
      );
    }
    return result;
  }

  @override
  Future<List<GalleryAsset>> assets(
    GalleryAlbum album, {
    required int page,
    required int pageSize,
  }) async {
    final path = album.native as AssetPathEntity;
    final list = await path.getAssetListPaged(page: page, size: pageSize);
    return [
      for (final e in list)
        GalleryAsset(
          id: e.id,
          width: e.orientatedWidth,
          height: e.orientatedHeight,
          native: e,
        ),
    ];
  }

  @override
  Future<Uint8List?> thumbnail(GalleryAsset asset, {int size = 256}) {
    final e = asset.native as AssetEntity;
    return e.thumbnailDataWithSize(ThumbnailSize.square(size), quality: 80);
  }

  @override
  Future<String?> resolveFile(GalleryAsset asset, Directory workDir) async {
    final e = asset.native as AssetEntity;
    final mime = e.mimeType ?? await e.mimeTypeAsync;
    if (isDirectlyDecodableMime(mime)) {
      final f = await e.originFile;
      if (f != null) return f.path;
    }
    // HEIC/HEIF/AVIF…: để codec native của hệ điều hành đổi sang JPEG.
    final size = fitWithin(
      e.orientatedWidth,
      e.orientatedHeight,
      embeddedLongSide,
    );
    final data = await e.thumbnailDataWithSize(
      ThumbnailSize(size.width, size.height),
      quality: 92,
    );
    if (data == null || data.isEmpty) return null;
    await workDir.create(recursive: true);
    final safeId = e.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final out = File('${workDir.path}${Platform.pathSeparator}$safeId.jpg');
    await out.writeAsBytes(data, flush: true);
    return out.path;
  }

  @override
  Future<void> openSettings() => PhotoManager.openSetting();
}
