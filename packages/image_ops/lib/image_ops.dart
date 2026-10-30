/// Pure-Dart image processing for PDF Office: edit (rotate, crop, resize,
/// filters, JPEG compression), document rectification/detection, and PDF page
/// layout. No Flutter / dart:ui; every function is synchronous and pure, so it
/// can run inside `Isolate.run`.
library;

export 'src/document.dart' show perspectiveWarp, detectDocumentCorners;
export 'src/edit.dart' show applyEdit, renderPreview, probe;
export 'src/id_card.dart'
    show composeIdCard, idCardFrames, IdCardLayout, IdCardFit, IdCardFrame;
export 'src/layout.dart'
    show placeImageOnPage, estimateJpegBytes, pageSizesPt, marginPt;
export 'src/models.dart';
