/// Colour treatment applied after geometry (rotate, crop, resize).
enum ImageFilter {
  /// No colour change.
  original,

  /// Luminance only (R = G = B).
  grayscale,

  /// Pure black / white. Adaptive local threshold by default (good for
  /// photographed documents with uneven light); global Otsu when
  /// [ImageEdit.adaptiveThreshold] is false.
  blackWhite,

  /// Contrast stretch plus light sharpening.
  enhance,

  /// Lift brightness (mostly the shadows and mid-tones).
  brighten,

  /// White balance on the paper, then contrast stretch: "document scan" look.
  magicColor,
}

/// Output encoding of [applyEdit] / [renderPreview] / [perspectiveWarp].
enum OutputFormat {
  /// JPEG, or PNG when the result has real (non-opaque) alpha.
  auto,

  /// Always JPEG (alpha is flattened onto white).
  jpeg,

  /// Always PNG (lossless).
  png,
}

/// Container format detected by [probe].
enum ImageSourceFormat { jpeg, png, webp, bmp, gif, other }

/// A rectangle in normalised coordinates (0..1) of the image *after*
/// rotation. Values outside 0..1 are clamped.
class NormRect {
  final double left, top, width, height;

  const NormRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  static const full = NormRect(left: 0, top: 0, width: 1, height: 1);

  double get right => left + width;
  double get bottom => top + height;

  @override
  bool operator ==(Object other) =>
      other is NormRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'NormRect($left, $top, $width x $height)';
}

/// A point in normalised coordinates (0..1) of the EXIF-oriented image.
class NormPoint {
  final double x, y;

  const NormPoint(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is NormPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'NormPoint($x, $y)';
}

/// Everything the editor can do to one image. Order of application:
/// EXIF orientation -> rotation -> crop -> downscale -> filter ->
/// brightness/contrast.
class ImageEdit {
  /// Clockwise quarter turns; any integer, normalised modulo 4.
  final int rotationQuarterTurns;

  /// Crop in the rotated frame; null = whole image.
  final NormRect? crop;

  final ImageFilter filter;

  /// Downscale so the long side is at most this many pixels (never upscales).
  final int? maxLongSide;

  /// -1..1, added as `brightness * 255` to every channel. 0 = unchanged.
  final double brightness;

  /// -1..1; channel = (v - 128) * (1 + contrast) + 128. 0 = unchanged.
  final double contrast;

  /// For [ImageFilter.blackWhite]: local adaptive threshold (true) or global
  /// Otsu threshold (false).
  final bool adaptiveThreshold;

  const ImageEdit({
    this.rotationQuarterTurns = 0,
    this.crop,
    this.filter = ImageFilter.original,
    this.maxLongSide,
    this.brightness = 0,
    this.contrast = 0,
    this.adaptiveThreshold = true,
  });

  /// Normalised turns in 0..3.
  int get quarterTurns => rotationQuarterTurns % 4;

  ImageEdit copyWith({
    int? rotationQuarterTurns,
    NormRect? crop,
    bool clearCrop = false,
    ImageFilter? filter,
    int? maxLongSide,
    bool clearMaxLongSide = false,
    double? brightness,
    double? contrast,
    bool? adaptiveThreshold,
  }) =>
      ImageEdit(
        rotationQuarterTurns: rotationQuarterTurns ?? this.rotationQuarterTurns,
        crop: clearCrop ? null : (crop ?? this.crop),
        filter: filter ?? this.filter,
        maxLongSide:
            clearMaxLongSide ? null : (maxLongSide ?? this.maxLongSide),
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        adaptiveThreshold: adaptiveThreshold ?? this.adaptiveThreshold,
      );

  @override
  bool operator ==(Object other) =>
      other is ImageEdit &&
      other.quarterTurns == quarterTurns &&
      other.crop == crop &&
      other.filter == filter &&
      other.maxLongSide == maxLongSide &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.adaptiveThreshold == adaptiveThreshold;

  @override
  int get hashCode => Object.hash(quarterTurns, crop, filter, maxLongSide,
      brightness, contrast, adaptiveThreshold);
}

/// Cheap facts about an encoded image.
class ImageInfoLite {
  /// Size after applying EXIF orientation.
  final int width, height;
  final ImageSourceFormat format;

  /// True only when at least one pixel is not fully opaque.
  final bool hasAlpha;

  /// Raw EXIF orientation tag (1..8), 1 when absent.
  final int exifOrientation;

  const ImageInfoLite({
    required this.width,
    required this.height,
    required this.format,
    required this.hasAlpha,
    this.exifOrientation = 1,
  });

  @override
  String toString() =>
      'ImageInfoLite(${width}x$height, $format, alpha: $hasAlpha)';
}

/// Page size presets for [placeImageOnPage].
enum PageSizePreset { a4, letter, legal, a3, a5, fitImage }

enum PageOrientation { auto, portrait, landscape }

/// 0 / 18 pt / 36 pt on every side.
enum MarginPreset { none, small, large }

/// Result of [placeImageOnPage], in PDF points (1/72 inch), origin at the
/// TOP-LEFT of the page (flip y for PDF's bottom-left origin:
/// `pdfY = pageHeight - imageTop - imageHeight`).
class PagePlacement {
  final double pageWidth, pageHeight;
  final double imageLeft, imageTop, imageWidth, imageHeight;

  const PagePlacement({
    required this.pageWidth,
    required this.pageHeight,
    required this.imageLeft,
    required this.imageTop,
    required this.imageWidth,
    required this.imageHeight,
  });

  bool get isLandscape => pageWidth > pageHeight;

  @override
  String toString() => 'PagePlacement(page ${pageWidth}x$pageHeight, image '
      '$imageLeft,$imageTop ${imageWidth}x$imageHeight)';
}
