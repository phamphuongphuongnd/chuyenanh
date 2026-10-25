# pptx_reader

Pure Dart (no Flutter) reader that turns a PowerPoint `.pptx` file into a plain
data model, so a Flutter app can draw slides itself (Stack / Positioned /
CustomPaint). Fully offline, synchronous, safe inside `Isolate.run`.

```dart
import 'package:pptx_reader/pptx_reader.dart';

final deck = await Isolate.run(() => readPptx(bytes)); // throws PptxFormatException
for (final slide in deck.slides) {
  for (final shape in slide.shapes) {
    switch (shape) {
      case PptxTextShape s: ...    // autoshape / text box / placeholder / connector (geometry == line)
      case PptxPictureShape p: ... // p.bytes, p.extension, p.crop
      case PptxTableShape t: ...   // columnWidthsEmu, rows[].cells[] (gridSpan/rowSpan/hMerge/vMerge)
      case PptxGroupShape g: ...   // children already in slide coordinates
    }
  }
}
```

Units: positions/sizes in EMU (`deck.slideWidthEmu`, 914400 EMU = 1 inch,
12700 EMU = 1 pt); font sizes in points; colours as ARGB ints (`0xAARRGGBB`).

## What is resolved

- Slide order from `presentation.xml` `sldIdLst` + rels (not file names); slide size; hidden slides/shapes.
- `p:sp`, `p:cxnSp` (line), `p:pic` (+ `srcRect` crop), `p:graphicFrame` tables, `p:grpSp`
  (`chOff/chExt` converted, nested), `mc:AlternateContent` (Fallback preferred).
- Placeholder inheritance slide -> layout (by `idx`, then `type`) -> master (by type):
  `xfrm`, geometry, fill, line, `bodyPr` (insets, anchor, wrap), list styles.
- Text formatting chain: `presentation defaultTextStyle` -> master `txStyles`
  (title/body/other by level) -> master/layout placeholder `lstStyle` -> `p:style fontRef`
  -> shape `lstStyle` -> `pPr` / `rPr`. Bullets (`buChar`, `buAutoNum`, `buNone`), spacing,
  margins, `normAutofit fontScale/lnSpcReduction`, theme fonts `+mj-lt/+mn-lt`,
  `slidenum` fields, external hyperlinks.
- Colours: `srgbClr`, `schemeClr` (master `clrMap`, `clrMapOvr`, theme via master rels),
  `sysClr`, `prstClr`, `scrgbClr`, `hslClr`; modifiers `lumMod/lumOff/satMod/hueOff/tint/shade/alpha/...`.
- `p:style` `fillRef/lnRef/fontRef`; backgrounds slide -> layout -> master (`bgPr` or `bgRef`).
- Master/layout non-placeholder shapes are prepended (respecting `showMasterSp="0"`).
- Table styles from `tableStyles.xml` (wholeTbl, bands, first/last row/col: fill, borders, text colour/bold).
- Speaker notes (`notesSlide` body placeholder).
- Images are decompressed only when referenced (shared images decoded once).

## Known limitations

- Gradient fills -> first stop colour; pattern fills -> foreground colour; no effects (shadow, glow, 3D).
- Preset geometries other than rect/roundRect/ellipse/triangle/line map to `other`
  (raw name in `presetGeometry`); `custGeom` paths are not exported; adjust values ignored.
- Charts, SmartArt, OLE, media, ink: empty `PptxTextShape` with `unsupportedKind` set
  (no fallback image extracted except when `mc:Fallback` provides a `p:pic`).
- `bgRef`/`fillRef` use the reference colour as a solid fill (theme gradient/image fills not expanded).
- Group rotation/flip is not baked into children (rotate the group as a whole).
- Text: no column layout, tab stops, kerning, character spacing, highlight, `vert` details
  (only a `verticalText` flag), right-to-left; `spcPct` before/after is approximated from the first run size.
- Placeholder match falls back to the first placeholder of the same category when `idx` does not match.
- UTF-16 encoded XML parts and encrypted/password-protected files are not supported.
