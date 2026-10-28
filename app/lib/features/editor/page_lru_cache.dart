/// Cache LRU nhỏ (giữ thứ tự truy cập) để giới hạn số ảnh trang đang giữ trong RAM.
class PageLruCache<K, V> {
  PageLruCache(this.capacity) : assert(capacity > 0);

  final int capacity;
  final Map<K, V> _map = {}; // LinkedHashMap: đầu = cũ nhất.

  int get length => _map.length;

  bool containsKey(K key) => _map.containsKey(key);

  /// Lấy giá trị (đánh dấu mới dùng) hoặc tạo bằng [ifAbsent]; vượt [capacity] thì bỏ cái cũ nhất.
  V putIfAbsent(K key, V Function() ifAbsent) {
    final existing = _map.remove(key);
    final value = existing ?? ifAbsent();
    _map[key] = value;
    while (_map.length > capacity) {
      _map.remove(_map.keys.first);
    }
    return value;
  }

  V? remove(K key) => _map.remove(key);
}
