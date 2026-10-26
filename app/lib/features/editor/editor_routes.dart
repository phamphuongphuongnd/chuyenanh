import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/widgets.dart';
import 'annotate_screen.dart';
import 'fill_form_screen.dart';
import 'sign_screen.dart';

/// Route của feature `editor` (gộp trong `core/router/app_router.dart`). Mỗi route nhận
/// `extra: String` = đường dẫn file PDF.
final List<RouteBase> editorRoutes = [
  GoRoute(
    path: Routes.annotate,
    builder: (context, state) => _withPath(
      state,
      (path) => AnnotateScreen(key: ValueKey('annotate:$path'), path: path),
    ),
  ),
  GoRoute(
    path: Routes.sign,
    builder: (context, state) => _withPath(
      state,
      (path) => SignScreen(key: ValueKey('sign:$path'), path: path),
    ),
  ),
  GoRoute(
    path: Routes.fillForm,
    builder: (context, state) => _withPath(
      state,
      (path) => FillFormScreen(key: ValueKey('fill:$path'), path: path),
    ),
  ),
];

/// Thiếu `extra` (mở route trực tiếp) thì báo lỗi thay vì crash.
Widget _withPath(GoRouterState state, Widget Function(String path) build) {
  final extra = state.extra;
  if (extra is String && extra.isNotEmpty) return build(extra);
  return const _MissingPdfScreen();
}

class _MissingPdfScreen extends StatelessWidget {
  const _MissingPdfScreen();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PlaceholderScreen(title: l.edit_title, detail: l.edit_loadFailed);
  }
}
