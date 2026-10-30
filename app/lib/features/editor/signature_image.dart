// Xử lý ảnh chữ ký (PNG nền trong suốt) — thuần Dart, không phụ thuộc Flutter widget.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:image/image.dart' as img;

import '../../core/errors/app_error.dart';

/// Cạnh dài tối đa (px) của ảnh chụp chữ ký sau khi thu nhỏ — đủ nét để ký, nhẹ để xử lý lại
/// mỗi lần kéo thanh độ nhạy.
const int kSignaturePhotoMaxSide = 1200;

/// Chênh lệch độ sáng tối thiểu giữa nền và nét (thang 0–255) để coi là "có nét" khi tự tính
/// ngưỡng. Ảnh giấy trắng trơn chỉ có nhiễu nhỏ → dưới mức này → không có chữ ký.
const int kSignatureMinContrast = 40;

/// Ảnh chụp chữ ký đã giải mã + xoay đúng chiều EXIF + thu nhỏ, kèm độ sáng từng pixel và
/// ngưỡng Otsu tự tính. Chỉ gồm số và [Uint8List] nên gửi qua `Isolate.run` được; giữ lại để
/// kéo thanh độ nhạy mà không phải giải mã JPG lần nữa.
class SignaturePhoto {
  const SignaturePhoto({
    required this.width,
    required this.height,
    required this.rgba,
    required this.luma,
    required this.autoThreshold,
  });

  final int width;
  final int height;

  /// Điểm ảnh RGBA 8 bit, hàng nối hàng.
  final Uint8List rgba;

  /// Độ sáng 0–255 từng pixel (đã trộn với nền trắng nếu ảnh gốc có trong suốt).
  final Uint8List luma;

  /// Ngưỡng Otsu (pixel có độ sáng ≤ ngưỡng là nét), hoặc `null` nếu ảnh không đủ tương phản
  /// để thấy nét nào (ảnh trơn một màu, giấy trắng không chữ ký).
  final int? autoThreshold;
}

/// Giải mã ảnh chụp (JPG/PNG…), xoay theo EXIF, thu cạnh dài về ≤ [kSignaturePhotoMaxSide] px,
/// tính độ sáng và ngưỡng Otsu. Ném [CorruptFile] nếu không đọc được ảnh.
SignaturePhoto decodeSignaturePhoto(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    throw const CorruptFile('signature photo');
  }
  var image = img.bakeOrientation(decoded);
  final longSide = math.max(image.width, image.height);
  if (longSide > kSignaturePhotoMaxSide) {
    final scale = kSignaturePhotoMaxSide / longSide;
    image = img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      height: math.max(1, (image.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }
  if (image.format != img.Format.uint8 || image.numChannels != 4) {
    image = image.convert(format: img.Format.uint8, numChannels: 4, alpha: 255);
  }
  final rgba = Uint8List.fromList(image.getBytes(order: img.ChannelOrder.rgba));
  final count = image.width * image.height;
  final luma = Uint8List(count);
  final histogram = List<int>.filled(256, 0);
  for (var i = 0, o = 0; i < count; i++, o += 4) {
    // Độ sáng theo Rec. 601, trộn với nền trắng theo alpha (vùng trong suốt = giấy).
    final y = (299 * rgba[o] + 587 * rgba[o + 1] + 114 * rgba[o + 2]) ~/ 1000;
    final a = rgba[o + 3];
    final v = (y * a + 255 * (255 - a)) ~/ 255;
    luma[i] = v;
    histogram[v]++;
  }
  return SignaturePhoto(
    width: image.width,
    height: image.height,
    rgba: rgba,
    luma: luma,
    autoThreshold: otsuThreshold(histogram),
  );
}

/// Ngưỡng Otsu trên [histogram] 256 mức: chọn `t` làm cực đại phương sai giữa hai lớp
/// (≤ t là tối, > t là sáng). Trả `null` nếu không tách được hai lớp, hoặc hai lớp chênh nhau
/// dưới [minContrast] mức sáng (chỉ có nhiễu, không có nét).
int? otsuThreshold(List<int> histogram, {int minContrast = kSignatureMinContrast}) {
  var total = 0;
  var sumAll = 0.0;
  for (var i = 0; i < 256; i++) {
    total += histogram[i];
    sumAll += i * histogram[i];
  }
  if (total == 0) return null;
  var weightDark = 0;
  var sumDark = 0.0;
  var best = 0.0;
  int? first;
  var last = -1;
  var contrast = 0.0;
  for (var t = 0; t < 255; t++) {
    weightDark += histogram[t];
    if (weightDark == 0) continue;
    final weightLight = total - weightDark;
    if (weightLight == 0) break;
    sumDark += t * histogram[t];
    final meanDark = sumDark / weightDark;
    final meanLight = (sumAll - sumDark) / weightLight;
    final diff = meanLight - meanDark;
    final between = weightDark.toDouble() * weightLight * diff * diff;
    if (between > best) {
      best = between;
      first = t;
      last = t;
      contrast = diff;
    } else if (between == best && last == t - 1) {
      // Khoảng trống giữa hai đỉnh (các mức không có pixel) cho cùng phương sai → lấy giữa
      // khoảng, để nét không nằm sát ngưỡng (alpha mờ).
      last = t;
    }
  }
  if (first == null || contrast < minContrast) return null;
  return (first + last) ~/ 2;
}

/// Tách nét ký khỏi [photo]: pixel có độ sáng > [threshold] (mặc định: ngưỡng Otsu) thành trong
/// suốt; pixel tối giữ màu gốc, hoặc ép màu mực [ink]. Alpha mượt theo độ tối để mép nét không
/// răng cưa. Trả PNG đã cắt sát nét, hoặc `null` nếu không thấy nét nào.
Uint8List? signaturePngFromDecodedPhoto(
  SignaturePhoto photo, {
  int? threshold,
  Color? ink,
}) {
  final t = threshold ?? photo.autoThreshold;
  if (t == null) return null;
  final cut = t.clamp(0, 254);
  // Dải chuyển mềm: tối hơn ngưỡng quá `band` mức là đặc hẳn; sát ngưỡng thì mờ dần.
  final band = (cut * 0.35).clamp(8.0, 96.0);
  final argb = ink?.toARGB32();
  final inkR = argb == null ? 0 : (argb >> 16) & 0xFF;
  final inkG = argb == null ? 0 : (argb >> 8) & 0xFF;
  final inkB = argb == null ? 0 : argb & 0xFF;
  final src = photo.rgba;
  final luma = photo.luma;
  final out = Uint8List(src.length); // mặc định toàn 0 = trong suốt
  var inked = false;
  for (var i = 0, o = 0; i < luma.length; i++, o += 4) {
    final v = luma[i];
    if (v > cut) continue;
    final alpha = (((cut + 1 - v) / band).clamp(0.0, 1.0) * 255).round();
    if (alpha == 0) continue;
    inked = true;
    if (argb == null) {
      out[o] = src[o];
      out[o + 1] = src[o + 1];
      out[o + 2] = src[o + 2];
    } else {
      out[o] = inkR;
      out[o + 1] = inkG;
      out[o + 2] = inkB;
    }
    out[o + 3] = alpha;
  }
  if (!inked) return null;
  final image = img.Image.fromBytes(
    width: photo.width,
    height: photo.height,
    bytes: out.buffer,
    numChannels: 4,
  );
  return trimSignaturePng(Uint8List.fromList(img.encodePng(image)));
}

/// Từ ảnh chụp chữ ký (JPG/PNG) ra PNG nền trong suốt đã cắt sát nét — gộp
/// [decodeSignaturePhoto] + [signaturePngFromDecodedPhoto]. Trả `null` nếu không thấy nét;
/// ném [CorruptFile] nếu không đọc được ảnh. Nặng CPU: nơi gọi chạy bằng `Isolate.run`.
Uint8List? signaturePngFromPhoto(
  Uint8List bytes, {
  int? threshold,
  Color? ink,
}) => signaturePngFromDecodedPhoto(
  decodeSignaturePhoto(bytes),
  threshold: threshold,
  ink: ink,
);

/// Cắt phần trong suốt thừa quanh nét ký, chừa [padding] px mỗi cạnh.
///
/// Trả về `null` nếu ảnh không có nét nào (toàn trong suốt) — nghĩa là người dùng chưa ký.
/// Ném [CorruptFile] nếu không đọc được PNG.
Uint8List? trimSignaturePng(Uint8List png, {int padding = 4}) {
  final image = img.decodePng(png);
  if (image == null) throw const CorruptFile('signature png');
  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;
  for (final p in image) {
    if (p.a > 8) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
  }
  if (maxX < 0) return null;
  final x = (minX - padding).clamp(0, image.width - 1);
  final y = (minY - padding).clamp(0, image.height - 1);
  final right = (maxX + padding).clamp(0, image.width - 1);
  final bottom = (maxY + padding).clamp(0, image.height - 1);
  final cropped = img.copyCrop(
    image,
    x: x,
    y: y,
    width: right - x + 1,
    height: bottom - y + 1,
  );
  return Uint8List.fromList(img.encodePng(cropped));
}

/// Tỷ lệ rộng/cao của ảnh PNG. Ném [CorruptFile] nếu hỏng.
double pngAspectRatio(Uint8List png) {
  final image = img.decodePng(png);
  if (image == null || image.height == 0) {
    throw const CorruptFile('signature png');
  }
  return image.width / image.height;
}
