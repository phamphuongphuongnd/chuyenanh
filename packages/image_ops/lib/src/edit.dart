import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'filters.dart';
import 'models.dart';
import 'raw.dart';

/// Decodes [encoded] (JPG/PNG/WebP/BMP/GIF first frame…), applies the EXIF
/// orientation, then [edit], and re-encodes.
///
/// Pipeline (cheapest order): decode (reduced-scale for big JPEGs when
/// [ImageEdit.maxLongSide] allows) -> EXIF orientation -> crop (mapped back
/// through the rotation) -> downscale -> rotate -> filter. Output is JPEG, or
/// PNG when the result has real alpha (see [format]). Metadata is stripped.
///
/// Throws [FormatException] for unreadable data. Pure Dart: safe inside
/// `Isolate.run`.
Uint8List applyEdit(
  Uint8List encoded,
  ImageEdit edit, {
  int jpegQuality = 90,
  OutputFormat format = OutputFormat.auto,
}) {
  final raw = editRaw(encoded, edit);
  return encodeRaw(raw, format, jpegQuality);
}

/// Same as [applyEdit] but capped to [maxSide] on the long side and encoded
/// at a preview quality (80) for fast on-screen display.
Uint8List renderPreview(Uint8List encoded, ImageEdit edit,
    {int maxSide = 1024}) {
  final cap = edit.maxLongSide == null
      ? maxSide
      : math.min(edit.maxLongSide!, maxSide);
  return applyEdit(encoded, edit.copyWith(maxLongSide: cap), jpegQuality: 80);
}

/// Runs the edit pipeline and returns raw pixels (internal, also used by
/// document helpers).
RawImage editRaw(Uint8List encoded, ImageEdit edit) {
  final crop = edit.crop;
  final maxLong = edit.maxLongSide;

  // Decode at reduced scale only when no crop narrows the region, otherwise
  // the cropped part could end up below maxLongSide.
  int? target;
  if (maxLong != null && maxLong > 0) {
    if (crop == null) {
      target = maxLong;
    } else {
      final frac = math.max(crop.width.clamp(0.0, 1.0), crop.height.clamp(0.0, 1.0));
      if (frac > 0) target = (maxLong / frac).ceil();
    }
  }
  final decoded = decodeRaw(encoded, targetLongSide: target);
  var raw = applyOrientation(decoded.image, decoded.orientation);

  final turns = edit.quarterTurns;
  if (crop != null) raw = cropNorm(raw, unrotateRect(crop, turns));
  if (maxLong != null && maxLong > 0) raw = downscaleToLongSide(raw, maxLong);
  raw = rotateCw(raw, turns);
  applyFilters(raw, edit);
  return raw;
}

/// Size (after EXIF orientation), container format and real-alpha flag.
///
/// JPEG is read from the header only; other formats are decoded (needed to
/// know whether any pixel is actually transparent).
ImageInfoLite probe(Uint8List encoded) {
  final decoder = img.findDecoderForData(encoded);
  if (decoder == null) {
    throw const FormatException('Unsupported or corrupt image data');
  }
  if (decoder.format == img.ImageFormat.jpg) {
    final info = img.JpegDecoder().startDecode(encoded);
    if (info == null) {
      throw const FormatException('Unsupported or corrupt image data');
    }
    final exif = img.decodeJpgExif(encoded);
    final o = (exif != null && exif.imageIfd.hasOrientation)
        ? (exif.imageIfd.orientation ?? 1)
        : 1;
    final swap = orientationSwaps(o);
    return ImageInfoLite(
      width: swap ? info.height : info.width,
      height: swap ? info.width : info.height,
      format: ImageSourceFormat.jpeg,
      hasAlpha: false,
      exifOrientation: o,
    );
  }
  final d = decodeRaw(encoded);
  final swap = orientationSwaps(d.orientation);
  return ImageInfoLite(
    width: swap ? d.image.height : d.image.width,
    height: swap ? d.image.width : d.image.height,
    format: d.format,
    hasAlpha: d.image.hasRealAlpha,
    exifOrientation: d.orientation,
  );
}
