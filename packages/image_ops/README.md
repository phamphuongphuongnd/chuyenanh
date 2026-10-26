# image_ops

Pure-Dart (no Flutter, no `dart:ui`) image processing for the offline
"PDF Office" app: edit photos before they go into a PDF and compute where
each image sits on a PDF page. Every function is synchronous and pure, so it
can run inside `Isolate.run`.

```dart
final jpeg = await Isolate.run(() => applyEdit(bytes, const ImageEdit(
  rotationQuarterTurns: 1,                       // clockwise
  crop: NormRect(left: .1, top: .1, width: .8, height: .8), // after rotation
  filter: ImageFilter.magicColor,
  maxLongSide: 3000,
)));
final place = placeImageOnPage(
    imagePxWidth: 3000, imagePxHeight: 2250, size: PageSizePreset.a4);
```

## API (`package:image_ops/image_ops.dart`)

| Function | Notes |
|---|---|
| `applyEdit(bytes, edit, {jpegQuality = 90, format = OutputFormat.auto})` | Reads JPG/PNG/WebP/BMP/GIF (first frame). EXIF orientation is applied first. Returns JPEG, or PNG when the result has real alpha. Metadata (EXIF/GPS) is stripped. |
| `renderPreview(bytes, edit, {maxSide = 1024})` | Same pipeline, capped size, quality 80. |
| `probe(bytes)` → `ImageInfoLite` | Width/height after EXIF, `ImageSourceFormat`, `hasAlpha` (true only if a pixel is not opaque), `exifOrientation`. JPEG reads the header only. |
| `perspectiveWarp(bytes, corners4, {outLongSide})` | 4 corners TL, TR, BR, BL (normalised, EXIF-oriented frame) → upright rectangle; size = mean opposite edge lengths. |
| `detectDocumentCorners(bytes)` → `List<NormPoint>?` | Simple paper detection; `null` when not confident. |
| `placeImageOnPage(...)` → `PagePlacement` | Points (1/72 in), origin top-left (`pdfY = pageHeight - imageTop - imageHeight`). |
| `estimateJpegBytes(w, h, quality)` | Bits-per-pixel table for typical 4:2:0 photos; document scans are usually smaller. |

Extra fields beyond the brief: `ImageEdit.adaptiveThreshold` (blackWhite:
adaptive local vs. global Otsu), `ImageEdit.copyWith`, `OutputFormat`
(`auto/jpeg/png`; PNG is the better choice for `blackWhite`, since JPEG adds ringing),
`ImageInfoLite.exifOrientation`, `pageSizesPt`, `marginPt`.

### Semantics
- Pipeline: decode (big JPEGs use the decoder's 1/2, 1/4 or 1/8 DCT scaling
  when `maxLongSide` allows) → EXIF orientation → crop (mapped back through
  the rotation) → **downscale** (area average) → rotate → filter. The image
  is shrunk before filtering.
- `brightness`/`contrast` are in -1..1. They are applied before
  `grayscale`/`blackWhite` (so they move the threshold) and after
  `enhance`/`brighten`/`magicColor` (so auto-levels do not undo them).
- Filters: `blackWhite` uses a Bradley local-mean threshold (window ≈ 1/16
  of the long side, 15 %) plus "very dark ⇒ black", or Otsu;
  `enhance` = 1–99 % stretch (gain ≤ 2.5) + 3×3 unsharp; `brighten` = gamma
  0.7; `magicColor` = per-channel 2 %/97 % levels (white balance on the paper)
  + slight contrast and saturation.
- Layout: `auto` orientation = landscape when the image is wider than tall.
  The image keeps its aspect ratio, is centred, fits inside the margins
  (0/18/36 pt) and is never enlarged beyond `px * 72 / dpiForFit`.
  `fitImage` = natural size + margins.
- `detectDocumentCorners`: works on a copy about 400 px wide. Steps: 5×5 blur → Otsu split →
  the largest regions of each class → fill holes → convex hull → the
  largest inscribed quadrilateral. It accepts a region only if it is ≥ 90 % convex,
  the quad covers ≥ 90 % of the hull and 10–95 % of the frame, and the classes
  differ by ≥ 30 grey levels.

## Tests

```
cd packages/image_ops
dart pub get && dart analyze && dart test          # 252 tests
dart test -t perf                                   # timings only
dart run tool/bench.dart                            # per-stage timings
```

All sample images are generated in code (`test/helpers.dart`): a tilted grey
or white sheet with "text" lines, EXIF-rotated JPEGs, PNG with alpha,
WebP (via `encodeWebP` from package:image 4.12, so that test is not skipped), BMP and an
animated GIF.

## Performance (measured)

Generated 4000×3000 JPEG (q90, 3.6 MB), `applyEdit(maxLongSide: 3000)` →
3000×2250 JPEG q90, Windows 11 x64 desktop (8 threads, other jobs running):

| | AOT (`dart compile exe`, ≈ Flutter release) | JIT (`dart test`) |
|---|---|---|
| original | 1.9 s | 1.5–2.7 s |
| grayscale / brighten | 1.5–2.0 s | 1.5–1.6 s |
| blackWhite | 1.8 s | 1.9–2.2 s |
| enhance | 2.1 s | 2.7–2.8 s |
| magicColor | 1.9 s | 1.9–2.0 s |
| renderPreview (1024) | 1.2 s | 0.9–1.2 s |
| detectDocumentCorners | 0.26 s | 0.3–0.4 s |
| perspectiveWarp (full res) | — | 1.7–1.8 s |

Stage breakdown (AOT): JPEG decode ≈ 1.0 s (package:image, the biggest
cost), downscale 0.35 s, filter 0.03–0.43 s, JPEG encode 0.5 s. Phones will be
slower, so run these in an isolate and show `renderPreview` while editing.

## Limitations
- The decoders and encoders are pure Dart (package:image), which is several
  times slower than native codecs. The JPEG decode sets the floor.
- Only the first frame of an animated GIF or WebP is used. CMYK JPEG and
  16-bit PNG go through package:image's conversion.
- Document detection is heuristic. It needs a sheet that contrasts with the
  background and has visible corners. It returns `null` instead of guessing.
- `estimateJpegBytes` is a rough heuristic; real size depends on content.
