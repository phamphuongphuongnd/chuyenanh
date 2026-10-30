import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import 'id_card_screen.dart';

/// Route của feature `id_card` (quét 2 mặt thẻ lên 1 trang).
final List<RouteBase> idCardRoutes = [
  GoRoute(path: Routes.idCard, builder: (_, _) => const IdCardScreen()),
];
