import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../models/image_item.dart' show embeddedLongSide;

/// Chọn ảnh bằng trình chọn ảnh của hệ thống (Android Photo Picker / PHPicker trên iOS) —
/// không cần quyền đọc thư viện ảnh. Tách interface để widget test dùng bản giả.
abstract interface class PhotoPickerService {
  /// Mở trình chọn ảnh, tối đa [limit] ảnh (`null` = không giới hạn). Trả về đường dẫn theo
  /// thứ tự hệ thống trả; rỗng = người dùng huỷ. Ném [PermissionDenied] nếu bị chặn truy cập ảnh.
  ///
  /// Trình chọn cũ (trước Android 13) có thể bỏ qua [limit] — nơi gọi tự cắt bớt.
  Future<List<String>> pickImages({int? limit});

  /// File ảnh dùng được cho engine: JPG/PNG/WebP/BMP/GIF giữ nguyên; HEIC/HEIF/AVIF/định dạng lạ
  /// được đổi sang JPEG (cạnh dài ≤ 3000px) bằng codec của hệ điều hành và ghi vào [workDir].
  /// `null` nếu không đọc được.
  Future<String?> prepareFile(String path, Directory workDir);
}

/// Impl bằng `image_picker`.
class ImagePickerPhotoPickerService implements PhotoPickerService {
  const ImagePickerPhotoPickerService();

  @override
  Future<List<String>> pickImages({int? limit}) async {
    try {
      final picker = ImagePicker();
      // pickMultiImage đòi limit ≥ 2 → chọn 1 ảnh thì dùng pickImage.
      if (limit == 1) {
        final x = await picker.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        );
        return x == null ? const [] : [x.path];
      }
      final files = await picker.pickMultiImage(
        limit: limit != null && limit >= 2 ? limit : null,
        requestFullMetadata: false,
      );
      return [for (final f in files) f.path];
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied') throw const PermissionDenied();
      throw AppError.from(e);
    }
  }

  @override
  Future<String?> prepareFile(String path, Directory workDir) async {
    final file = File(path);
    final head = await _readHead(file);
    if (head == null) return null;
    if (isDirectlyDecodableMime(detectImageMime(head))) return path;
    // HEIC/HEIF/AVIF…: gói `image` không đọc được → để codec native đổi sang JPEG.
    await workDir.create(recursive: true);
    final name = p.basenameWithoutExtension(path).replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    final out = p.join(
      workDir.path,
      'pick_${DateTime.now().microsecondsSinceEpoch}_$name.jpg',
    );
    return convertImageFileToJpeg(path, out);
  }

  static Future<Uint8List?> _readHead(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      return await raf.read(32);
    } catch (_) {
      return null;
    } finally {
      await raf?.close();
    }
  }
}

/// Mime mà image_ops giải mã được trực tiếp.
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

/// Đoán mime từ vài chục byte đầu file (magic number). `null` = không nhận ra. Hàm thuần — có test.
String? detectImageMime(List<int> head) {
  bool at(int offset, List<int> sig) {
    if (head.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (head[offset + i] != sig[i]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (at(0, 'GIF8'.codeUnits)) return 'image/gif';
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'image/webp';
  if (at(0, 'BM'.codeUnits)) return 'image/bmp';
  // ISO-BMFF: byte 4..7 = "ftyp", byte 8..11 = brand.
  if (at(4, 'ftyp'.codeUnits) && head.length >= 12) {
    final brand = String.fromCharCodes(head.sublist(8, 12));
    if (const {'avif', 'avis'}.contains(brand)) return 'image/avif';
    if (const {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis'}.contains(brand)) {
      return 'image/heic';
    }
    if (const {'mif1', 'msf1'}.contains(brand)) return 'image/heif';
  }
  return null;
}

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

/// Nén điểm ảnh RGBA thành JPEG. Hàm thuần — có test; chạy được trong isolate.
Uint8List encodeRgbaAsJpeg(
  Uint8List rgba,
  int width,
  int height, {
  int quality = 92,
}) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
  );
  return img.encodeJpg(image, quality: quality);
}

/// Giải mã [src] bằng codec của Flutter/hệ điều hành (đọc được HEIC/HEIF trên Android 9+ và iOS),
/// thu nhỏ cạnh dài ≤ [maxSide], ghi JPEG ra [dst]. Trả về [dst]; `null` nếu không giải mã được.
Future<String?> convertImageFileToJpeg(
  String src,
  String dst, {
  int maxSide = embeddedLongSide,
}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    final bytes = await File(src).readAsBytes();
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = fitWithin(descriptor.width, descriptor.height, maxSide);
    codec = await descriptor.instantiateCodec(
      targetWidth: size.width,
      targetHeight: size.height,
    );
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final w = image.width;
    final h = image.height;
    // Nén JPEG nặng → isolate riêng cho UI không giật.
    final jpg = await Isolate.run(() => encodeRgbaAsJpeg(rgba, w, h));
    await File(dst).writeAsBytes(jpg, flush: true);
    return dst;
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}
