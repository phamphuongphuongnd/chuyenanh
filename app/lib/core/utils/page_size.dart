/// Khổ giấy dùng chung (cài đặt `defaultPageSize`, Ảnh→PDF, tạo tài liệu trắng, chuyển đổi).
enum PageSizeOption {
  a4,
  letter,

  /// Trang vừa khít ảnh (chỉ có nghĩa với Ảnh→PDF; nơi khác coi như A4).
  fit;

  /// Kích thước dọc tính bằng point (1/72 inch). `fit` trả về A4.
  (double width, double height) get portraitPoints => switch (this) {
    PageSizeOption.letter => (612, 792),
    PageSizeOption.a4 || PageSizeOption.fit => (595.28, 841.89),
  };

  static PageSizeOption fromName(String? name) => PageSizeOption.values
      .firstWhere((e) => e.name == name, orElse: () => PageSizeOption.a4);
}

/// Số pixel của cạnh dài [points] khi render ở [dpi]: `points / 72 * dpi` (làm tròn).
int pointsToPixels(double points, double dpi) => (points / 72 * dpi).round();
