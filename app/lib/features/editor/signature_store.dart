import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/utils/file_paths.dart';

/// Số chữ ký lưu tối đa; vượt quá thì xoá cái cũ nhất.
const int kMaxSavedSignatures = 12;

/// Một chữ ký đã lưu (file PNG trong thư mục riêng của app).
class SavedSignature {
  const SavedSignature({required this.path, required this.modified});

  final String path;
  final DateTime modified;

  String get fileName => p.basename(path);
}

/// Lưu / liệt kê / xoá chữ ký PNG trong thư mục [directory] của app (không phải thư mục lưu file ra).
class SignatureStore {
  SignatureStore(this.directory);

  final Directory directory;

  /// Mới nhất trước. Bỏ qua file lạ không phải `.png`.
  Future<List<SavedSignature>> list() async {
    if (!await directory.exists()) return const [];
    final result = <SavedSignature>[];
    await for (final e in directory.list(followLinks: false)) {
      if (e is File && p.extension(e.path).toLowerCase() == '.png') {
        result.add(
          SavedSignature(path: e.path, modified: await e.lastModified()),
        );
      }
    }
    result.sort((a, b) {
      final c = b.modified.compareTo(a.modified);
      return c != 0 ? c : b.path.compareTo(a.path);
    });
    return result;
  }

  /// Lưu PNG mới, trả về bản ghi. Giữ tối đa [kMaxSavedSignatures] chữ ký.
  Future<SavedSignature> save(Uint8List png) async {
    await directory.create(recursive: true);
    final path = await uniqueOutputPath(
      directory.path,
      'signature_${DateTime.now().millisecondsSinceEpoch}',
      'png',
    );
    final file = await writeAtomically(path, png);
    final saved = SavedSignature(
      path: file.path,
      modified: await file.lastModified(),
    );
    final all = await list();
    for (final extra in all.skip(kMaxSavedSignatures)) {
      await delete(extra);
    }
    return saved;
  }

  Future<Uint8List> read(SavedSignature s) => File(s.path).readAsBytes();

  Future<void> delete(SavedSignature s) async {
    final f = File(s.path);
    if (await f.exists()) await f.delete();
  }
}

/// Thư mục `<app documents>/signatures`.
final signatureStoreProvider = FutureProvider<SignatureStore>((ref) async {
  final docs = await getApplicationDocumentsDirectory();
  return SignatureStore(Directory(p.join(docs.path, 'signatures')));
});
