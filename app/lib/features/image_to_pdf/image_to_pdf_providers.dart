// Provider của feature `image_to_pdf`: engine thật + các dịch vụ nền tảng (thư viện ảnh,
// camera, cắt ảnh, xử lý ảnh). Test thay bằng bản giả qua `ProviderScope(overrides: …)`.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engines/pdf/image_to_pdf_engine.dart';
import '../../engines/pdf/syncfusion_image_to_pdf_engine.dart';
import 'services/camera_service.dart';
import 'services/crop_service.dart';
import 'services/gallery_service.dart';
import 'services/image_processor.dart';

final imageToPdfEngineProvider = Provider<ImageToPdfEngine>(
  (ref) => const SyncfusionImageToPdfEngine(),
);

final galleryServiceProvider = Provider<GalleryService>(
  (ref) => const PhotoManagerGalleryService(),
);

final cameraServiceProvider = Provider<CameraService>(
  (ref) => const ImagePickerCameraService(),
);

final cropServiceProvider = Provider<CropService>(
  (ref) => const ImageCropperCropService(),
);

final imageProcessorProvider = Provider<ImageProcessor>(
  (ref) => const IsolateImageProcessor(),
);

/// Cache ảnh xem trước (một bản cho cả phiên, xoá khi provider bị huỷ).
final previewCacheProvider = Provider<PreviewCache>((ref) {
  final cache = PreviewCache(ref.watch(imageProcessorProvider));
  ref.onDispose(cache.clear);
  return cache;
});

/// Thư mục tạm của feature (HEIC đã đổi, ảnh đã cắt…). Test override trỏ vào thư mục tạm.
final workDirProvider = Provider<Future<Directory> Function()>(
  (ref) => img2pdfWorkDir,
);

/// Dọn file tạm của lượt trước khi bắt đầu lượt mới. Test override bằng hàm rỗng.
final workDirCleanerProvider = Provider<Future<void> Function()>(
  (ref) => clearImg2pdfWorkDir,
);
