/// Pure Dart reader for PowerPoint .pptx files.
///
/// ```dart
/// final deck = readPptx(bytes); // or: await Isolate.run(() => readPptx(bytes))
/// ```
library;

export 'src/model.dart';
export 'src/reader.dart' show readPptx;
