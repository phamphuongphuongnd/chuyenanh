import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Nhận ảnh do `binding.takeScreenshot(name)` gửi về và ghi `screenshots/<name>.png`
/// (chạy từ thư mục app/ nên ra app/screenshots/).
Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (
          String name,
          List<int> image, [
          Map<String, Object?>? args,
        ]) async {
          final file = File('screenshots/$name.png')
            ..createSync(recursive: true);
          file.writeAsBytesSync(image);
          return true;
        },
  );
}
