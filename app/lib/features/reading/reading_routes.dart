import 'package:go_router/go_router.dart';

import '../../core/navigation/open_file_args.dart';
import '../../core/router/routes.dart';
import 'reflow_args.dart';
import 'reflow_screen.dart';

/// Route của feature `reading` (chế độ đọc dàn chữ, đọc to, dịch).
/// `extra` là [ReflowArgs] (có chế độ) hoặc [OpenFileArgs] (= chỉ đọc); sai kiểu → coi như path rỗng.
final List<RouteBase> readingRoutes = [
  GoRoute(
    path: Routes.reflow,
    builder: (_, state) {
      final extra = state.extra;
      return switch (extra) {
        ReflowArgs() => ReflowScreen(args: extra.file, mode: extra.mode),
        OpenFileArgs() => ReflowScreen(args: extra),
        _ => const ReflowScreen(args: OpenFileArgs('')),
      };
    },
  ),
];
