import '../../../engines/pdf/pdf_tools_engine.dart';

/// Một trang trong danh sách đang sắp xếp. [uid] cố định suốt phiên (để chọn / kéo thả
/// không lệch khi đổi thứ tự), [sourceIndex] là chỉ số 0-based trong file gốc.
class PageEntry {
  const PageEntry({
    required this.uid,
    required this.sourceIndex,
    this.rotation = 0,
  });

  final int uid;
  final int sourceIndex;

  /// 0 / 90 / 180 / 270 — góc xoay thêm so với file gốc.
  final int rotation;

  PageEntry rotated(int delta) => PageEntry(
    uid: uid,
    sourceIndex: sourceIndex,
    rotation: (((rotation + delta) % 360) + 360) % 360,
  );
}

/// Trạng thái sắp xếp trang (thuần, bất biến): thứ tự, xoá, xoay, chọn.
/// Mọi thao tác trả về bản mới; thao tác không hợp lệ trả về chính nó.
class PageEditList {
  PageEditList._(this.pages, this.selected, this._pageCount);

  /// Danh sách ban đầu: trang 0..[pageCount)-1, không xoay, chưa chọn.
  factory PageEditList.fromCount(int pageCount) {
    if (pageCount < 1) throw ArgumentError('pageCount must be >= 1');
    return PageEditList._(
      List.unmodifiable([
        for (var i = 0; i < pageCount; i++) PageEntry(uid: i, sourceIndex: i),
      ]),
      const {},
      pageCount,
    );
  }

  final List<PageEntry> pages;

  /// [PageEntry.uid] đang được chọn.
  final Set<int> selected;
  final int _pageCount;

  int get length => pages.length;
  bool get hasSelection => selected.isNotEmpty;
  bool get allSelected => selected.length == pages.length;

  /// Đã khác bản gốc (đổi thứ tự / xoá / xoay).
  bool get isModified {
    if (pages.length != _pageCount) return true;
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].sourceIndex != i || pages[i].rotation != 0) return true;
    }
    return false;
  }

  bool isSelected(int uid) => selected.contains(uid);

  PageEditList _with(List<PageEntry> p, [Set<int>? sel]) =>
      PageEditList._(List.unmodifiable(p), sel ?? selected, _pageCount);

  PageEditList toggle(int uid) {
    if (!pages.any((e) => e.uid == uid)) return this;
    final sel = Set<int>.of(selected);
    if (!sel.add(uid)) sel.remove(uid);
    return _with(pages, sel);
  }

  PageEditList selectAll() => _with(pages, {for (final e in pages) e.uid});

  PageEditList clearSelection() => _with(pages, const {});

  /// Xoay các trang đang chọn [degrees] độ (bội của 90, âm = ngược chiều kim đồng hồ).
  PageEditList rotateSelected(int degrees) {
    if (!hasSelection || degrees % 90 != 0) return this;
    return _with([
      for (final e in pages) isSelected(e.uid) ? e.rotated(degrees) : e,
    ]);
  }

  /// Xoá các trang đang chọn. Không cho xoá hết (giữ ít nhất 1 trang) → trả về chính nó.
  PageEditList deleteSelected() {
    if (!hasSelection || allSelected) return this;
    return _with([
      for (final e in pages)
        if (!isSelected(e.uid)) e,
    ], const {});
  }

  /// Chuyển trang ở vị trí [from] tới vị trí [to] (kéo thả).
  PageEditList move(int from, int to) {
    if (from < 0 || from >= pages.length || to < 0 || to >= pages.length) {
      return this;
    }
    if (from == to) return this;
    final list = List<PageEntry>.of(pages);
    final item = list.removeAt(from);
    list.insert(to, item);
    return _with(list);
  }

  /// Dịch các trang đang chọn lên trước ([delta] = -1) hoặc ra sau (+1) một vị trí.
  PageEditList moveSelected(int delta) {
    if (!hasSelection || (delta != -1 && delta != 1)) return this;
    final list = List<PageEntry>.of(pages);
    var changed = false;
    if (delta < 0) {
      for (var i = 1; i < list.length; i++) {
        if (isSelected(list[i].uid) && !isSelected(list[i - 1].uid)) {
          final t = list[i - 1];
          list[i - 1] = list[i];
          list[i] = t;
          changed = true;
        }
      }
    } else {
      for (var i = list.length - 2; i >= 0; i--) {
        if (isSelected(list[i].uid) && !isSelected(list[i + 1].uid)) {
          final t = list[i + 1];
          list[i + 1] = list[i];
          list[i] = t;
          changed = true;
        }
      }
    }
    return changed ? _with(list) : this;
  }

  /// Toàn bộ danh sách theo thứ tự mới → [PageOp] cho `PdfToolsEngine.organize`.
  List<PageOp> toOps() => [
    for (final e in pages) PageOp(e.sourceIndex, rotation: e.rotation),
  ];

  /// Chỉ các trang đang chọn (theo thứ tự hiện tại) → trích trang.
  List<PageOp> selectedOps() => [
    for (final e in pages)
      if (isSelected(e.uid)) PageOp(e.sourceIndex, rotation: e.rotation),
  ];
}
