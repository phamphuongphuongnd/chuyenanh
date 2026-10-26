// Provider engine của feature `office_pptx`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pptx_reader/pptx_reader.dart' as pkg;

import '../../engines/office/pptx_engine.dart';
import 'pptx_engine_impl.dart';

final pptxEngineProvider = Provider<PptxEngine>(
  (ref) => const PackagePptxEngine(),
);

/// Hàm nạp model đầy đủ (pptx_reader) cho màn xem; test ghi đè bằng deck dựng sẵn.
final pptxDeckLoaderProvider = Provider<Future<pkg.PptxDeck> Function(String)>(
  (ref) => loadPptxDeckFromFile,
);

/// Deck của một file (theo path), parse một lần rồi giữ cache trong phiên.
final pptxDeckProvider = FutureProvider.family<pkg.PptxDeck, String>(
  (ref, path) => ref.read(pptxDeckLoaderProvider)(path),
);
