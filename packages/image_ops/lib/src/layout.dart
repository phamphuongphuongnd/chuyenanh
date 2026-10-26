import 'dart:math' as math;

import 'models.dart';

/// Portrait (short, long) sizes in points.
const Map<PageSizePreset, (double, double)> pageSizesPt = {
  PageSizePreset.a4: (595.28, 841.89),
  PageSizePreset.letter: (612, 792),
  PageSizePreset.legal: (612, 1008),
  PageSizePreset.a3: (841.89, 1190.55),
  PageSizePreset.a5: (419.53, 595.28),
};

double marginPt(MarginPreset m) => switch (m) {
      MarginPreset.none => 0,
      MarginPreset.small => 18,
      MarginPreset.large => 36,
    };

/// Places an image of [imagePxWidth] x [imagePxHeight] pixels on a page.
///
/// * The image keeps its aspect ratio and is centred.
/// * Its natural size is `px * 72 / dpiForFit` points; it is shrunk to fit the
///   printable area (page minus [margin] on every side) but never enlarged
///   beyond its natural size.
/// * [PageOrientation.auto] picks landscape for landscape images (w > h).
/// * [PageSizePreset.fitImage]: the page is the natural image size plus the
///   margins ([orientation] is ignored).
///
/// Coordinates have their origin at the page's top-left corner.
PagePlacement placeImageOnPage({
  required int imagePxWidth,
  required int imagePxHeight,
  required PageSizePreset size,
  PageOrientation orientation = PageOrientation.auto,
  MarginPreset margin = MarginPreset.small,
  double dpiForFit = 150,
}) {
  if (imagePxWidth <= 0 || imagePxHeight <= 0) {
    throw ArgumentError('Image size must be positive: '
        '${imagePxWidth}x$imagePxHeight');
  }
  if (!(dpiForFit > 0)) {
    throw ArgumentError.value(dpiForFit, 'dpiForFit', 'must be > 0');
  }
  final m = marginPt(margin);
  final natW = imagePxWidth * 72 / dpiForFit;
  final natH = imagePxHeight * 72 / dpiForFit;

  if (size == PageSizePreset.fitImage) {
    return PagePlacement(
      pageWidth: natW + 2 * m,
      pageHeight: natH + 2 * m,
      imageLeft: m,
      imageTop: m,
      imageWidth: natW,
      imageHeight: natH,
    );
  }

  final (short, long) = pageSizesPt[size]!;
  final landscape = switch (orientation) {
    PageOrientation.landscape => true,
    PageOrientation.portrait => false,
    PageOrientation.auto => imagePxWidth > imagePxHeight,
  };
  final pageW = landscape ? long : short;
  final pageH = landscape ? short : long;
  final availW = math.max(0.0, pageW - 2 * m);
  final availH = math.max(0.0, pageH - 2 * m);
  final scale = math.min(1.0, math.min(availW / natW, availH / natH));
  final imgW = natW * scale;
  final imgH = natH * scale;
  return PagePlacement(
    pageWidth: pageW,
    pageHeight: pageH,
    imageLeft: (pageW - imgW) / 2,
    imageTop: (pageH - imgH) / 2,
    imageWidth: imgW,
    imageHeight: imgH,
  );
}

/// Bits per pixel of a typical baseline 4:2:0 photo JPEG by quality
/// (piecewise linear). Mostly-white document scans come out smaller.
const List<(int, double)> _bppTable = [
  (1, 0.15),
  (10, 0.25),
  (30, 0.50),
  (50, 0.75),
  (70, 1.00),
  (80, 1.30),
  (90, 2.00),
  (95, 2.80),
  (100, 5.00),
];

/// Rough expected JPEG size in bytes (for showing an estimate in the UI).
int estimateJpegBytes(int width, int height, int quality) {
  if (width <= 0 || height <= 0) return 0;
  final q = quality.clamp(1, 100);
  var bpp = _bppTable.last.$2;
  for (var i = 1; i < _bppTable.length; i++) {
    final (q1, b1) = _bppTable[i];
    if (q <= q1) {
      final (q0, b0) = _bppTable[i - 1];
      bpp = b0 + (b1 - b0) * (q - q0) / (q1 - q0);
      break;
    }
  }
  const header = 620; // SOI, quant/huffman tables, frame/scan headers
  return (width * height * bpp / 8).round() + header;
}
