import 'package:path/path.dart' as p;

import '../../core/utils/file_paths.dart';

/// Kiểu chỉnh sửa → hậu tố tên file (chỉ ASCII để không phụ thuộc ngôn ngữ).
enum EditKind {
  annotate('annotated'),
  sign('signed'),
  fillForm('filled');

  const EditKind(this.suffix);
  final String suffix;
}

/// Đường dẫn file kết quả: `<outputDir>/<tên gốc>_<hậu tố>.pdf`, thêm ` (1)`… nếu trùng.
/// Không bao giờ trả về chính [inputPath] (không ghi đè file gốc).
Future<String> editedOutputPath(
  String outputDir,
  String inputPath,
  EditKind kind,
) async {
  final base = baseNameWithoutExtension(inputPath);
  var candidate = await uniqueOutputPath(
    outputDir,
    '${base}_${kind.suffix}',
    'pdf',
  );
  // Trùng đúng file gốc (ví dụ gốc tên `a_signed.pdf` nằm trong thư mục lưu): uniqueOutputPath đã
  // tránh vì file tồn tại, nhưng kiểm lại cho chắc.
  if (p.equals(candidate, inputPath)) {
    candidate = await uniqueOutputPath(outputDir, '${base}_${kind.suffix}_1', 'pdf');
  }
  return candidate;
}

/// Ghi [bytes] ra file kết quả mới và trả về đường dẫn.
Future<String> writeEditedPdf(
  String outputDir,
  String inputPath,
  EditKind kind,
  List<int> bytes,
) async {
  final path = await editedOutputPath(outputDir, inputPath, kind);
  await writeAtomically(path, bytes);
  return path;
}

/// Tên file để hiển thị.
String displayFileName(String path) => p.basename(path);
