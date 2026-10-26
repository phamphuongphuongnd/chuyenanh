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

## Tests with real files

`test/real_files_test.dart` reads decks written by desktop PowerPoint
(`test/fixtures/real/`). Regenerate them with
`powershell -ExecutionPolicy Bypass -File tool/make_real_fixtures.ps1` (needs PowerPoint; uses COM and
always quits it; re-run if it exits with -1 at start-up). `dart run tool/dump.dart file.pptx` prints
what the reader sees. `deck_organic.pptx` (1 MB) is git-ignored and its tests skip when absent.

## Known limitations

- Gradient fills -> first stop colour; pattern fills -> foreground colour; no effects (shadow, glow, 3D).
- Preset geometries other than rect/roundRect/ellipse/triangle/line map to `other`
  (raw name in `presetGeometry`; adjust values ignored). Freeforms (`custGeom`) export their
  `customPaths` (moveTo/lineTo/cubic/quad/arcTo/close in path space) when all coordinates are
  literal numbers; paths that use guide formulas (`gdLst`) are skipped.
- Charts, SmartArt, OLE, media, ink: empty `PptxTextShape` with `unsupportedKind` set
  (no fallback image extracted except when `mc:Fallback` provides a `p:pic`).
- `bgRef`/`fillRef` look up the theme `fillStyleLst`/`bgFillStyleLst` (picture textures are extracted,
  gradients become their first stop with `phClr` substituted); without a matching style the
  reference colour is a solid fill.
- `tint`/`shade` are computed in linear RGB like PowerPoint (default outline of a new shape = `172C51`).
- Bullets expose `bulletFontFamily` / `bulletColorArgb` / `bulletSizePct` (symbol fonts such as
  Wingdings keep private-use code points in `bulletChar`).
- Group rotation/flip is not baked into children (rotate the group as a whole).
- Text: no column layout, tab stops, kerning, character spacing, highlight, `vert` details
  (only a `verticalText` flag), right-to-left; `spcPct` before/after is approximated from the first run size.
- Placeholder match falls back to the first placeholder of the same category when `idx` does not match.
- UTF-16 encoded XML parts and encrypted/password-protected files are not supported.
