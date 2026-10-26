/// Số ảnh tối đa trong một PDF (giữ bộ nhớ ở mức an toàn trên máy yếu).
const int maxImagesPerPdf = 100;

/// Tập chọn có thứ tự: số thứ tự hiện trên ảnh = thứ tự bấm (bắt đầu từ 1).
/// Bỏ chọn ảnh giữa chừng thì các ảnh sau tự dồn số.
class OrderedSelection<T> {
  OrderedSelection({this.limit = maxImagesPerPdf});

  final int limit;
  final List<T> _items = [];

  List<T> get items => List.unmodifiable(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isFull => _items.length >= limit;

  bool contains(T item) => _items.contains(item);

  /// Số thứ tự 1-based, `null` nếu chưa chọn.
  int? numberOf(T item) {
    final i = _items.indexOf(item);
    return i < 0 ? null : i + 1;
  }

  /// Chọn / bỏ chọn [item]. Trả về `false` nếu muốn chọn thêm nhưng đã đủ [limit]
  /// (khi đó không đổi gì); các trường hợp khác trả về `true`.
  bool toggle(T item) {
    if (_items.remove(item)) return true;
    if (isFull) return false;
    _items.add(item);
    return true;
  }

  /// Thêm cuối danh sách nếu chưa có và còn chỗ. Trả về `true` nếu thêm được.
  bool add(T item) {
    if (_items.contains(item) || isFull) return false;
    _items.add(item);
    return true;
  }

  bool remove(T item) => _items.remove(item);

  void clear() => _items.clear();
}
