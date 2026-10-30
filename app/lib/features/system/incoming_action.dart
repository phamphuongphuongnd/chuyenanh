import '../../core/navigation/open_document.dart';
import '../../core/utils/doc_type.dart';

/// Việc cần làm với một lô file nhận từ app khác. Chọn bằng [planIncoming] (hàm thuần).
sealed class IncomingAction {
  const IncomingAction();
}

/// Mở trong app: [route] là `Routes.pdfReader` / viewer docx·xlsx·pptx·txt.
final class OpenInApp extends IncomingAction {
  const OpenInApp(this.path, this.route);
  final String path;
  final String route;

  @override
  bool operator ==(Object other) =>
      other is OpenInApp && other.path == path && other.route == route;

  @override
  int get hashCode => Object.hash(path, route);

  @override
  String toString() => 'OpenInApp($path, $route)';
}

/// .doc/.xls/.ppt đời cũ: mở bằng app ngoài (`OpenFilex`), như `openDocument`.
final class OpenExternal extends IncomingAction {
  const OpenExternal(this.path);
  final String path;

  @override
  bool operator ==(Object other) => other is OpenExternal && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'OpenExternal($path)';
}

/// Một hoặc nhiều ảnh → màn sửa của "Ảnh sang PDF".
final class ImagesToPdf extends IncomingAction {
  const ImagesToPdf(this.paths);
  final List<String> paths;

  @override
  bool operator ==(Object other) =>
      other is ImagesToPdf && _listEquals(other.paths, paths);

  @override
  int get hashCode => Object.hashAll(paths);

  @override
  String toString() => 'ImagesToPdf($paths)';
}

/// Nhiều PDF → màn Gộp. Màn Gộp chỉ nhận một file đầu ([first]); các file còn lại đã nằm trong
/// "Gần đây" để người dùng thêm.
final class MergePdfs extends IncomingAction {
  const MergePdfs(this.paths);
  final List<String> paths;

  String get first => paths.first;

  @override
  bool operator ==(Object other) =>
      other is MergePdfs && _listEquals(other.paths, paths);

  @override
  int get hashCode => Object.hashAll(paths);

  @override
  String toString() => 'MergePdfs($paths)';
}

/// Không có file nào mở được.
final class NothingToOpen extends IncomingAction {
  const NothingToOpen();

  @override
  bool operator ==(Object other) => other is NothingToOpen;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'NothingToOpen()';
}

/// Kết quả [planIncoming].
class IncomingPlan {
  const IncomingPlan({
    required this.action,
    this.unsupported = 0,
    this.notOpened = 0,
  });

  final IncomingAction action;

  /// Số file bị bỏ vì đuôi không hỗ trợ.
  final int unsupported;

  /// Số file hợp lệ đã nhận nhưng không mở trực tiếp (vd. ảnh đi kèm PDF, PDF thứ 2+ khi gộp).
  final int notOpened;

  @override
  String toString() =>
      'IncomingPlan($action, unsupported: $unsupported, notOpened: $notOpened)';
}

/// Đuôi được nhận: tài liệu + ảnh (`core/utils/doc_type.dart`).
bool isSupportedIncomingPath(String path) {
  final ext = extensionOf(path);
  return documentExtensions.contains(ext) || imageExtensions.contains(ext);
}

/// Chọn hành động theo danh sách [paths] (giữ thứ tự):
///  - chỉ có ảnh → [ImagesToPdf] (tất cả ảnh);
///  - từ 2 tài liệu trở lên và đều là PDF → [MergePdfs];
///  - còn lại → mở tài liệu đầu tiên ([OpenInApp] hoặc [OpenExternal]), phần còn lại tính
///    vào `notOpened`;
///  - không có file hợp lệ → [NothingToOpen].
IncomingPlan planIncoming(List<String> paths) {
  final supported = paths.where(isSupportedIncomingPath).toList();
  final unsupported = paths.length - supported.length;
  final images = supported
      .where((s) => imageExtensions.contains(extensionOf(s)))
      .toList();
  final docs = supported
      .where((s) => documentExtensions.contains(extensionOf(s)))
      .toList();

  if (supported.isEmpty) {
    return IncomingPlan(
      action: const NothingToOpen(),
      unsupported: unsupported,
    );
  }
  if (docs.isEmpty) {
    return IncomingPlan(action: ImagesToPdf(images), unsupported: unsupported);
  }
  if (docs.length >= 2 &&
      docs.every((d) => docTypeFromPath(d) == DocType.pdf)) {
    return IncomingPlan(
      action: MergePdfs(docs),
      unsupported: unsupported,
      notOpened: docs.length - 1 + images.length,
    );
  }
  final first = docs.first;
  final route = routeForDocument(first);
  return IncomingPlan(
    action: route != null ? OpenInApp(first, route) : OpenExternal(first),
    unsupported: unsupported,
    notOpened: supported.length - 1,
  );
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
