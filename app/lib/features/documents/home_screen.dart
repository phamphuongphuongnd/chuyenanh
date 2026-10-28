import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/doc_type.dart';
import 'documents_providers.dart';
import 'widgets/document_list.dart';
import 'widgets/home_drawer.dart';
import 'widgets/sort_menu.dart';

/// Thứ tự tab trang chủ: All · PDF · DOC · XLS · PPT · TXT (`null` = All).
const List<DocCategory?> homeTabs = [
  null,
  DocCategory.pdf,
  DocCategory.doc,
  DocCategory.xls,
  DocCategory.ppt,
  DocCategory.txt,
];

/// Tab "Tập tin": AppBar đổi màu theo tab, tab loại file, danh sách tài liệu.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabs = TabController(
    length: homeTabs.length,
    vsync: this,
  )..addListener(_onTabChanged);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    super.dispose();
  }

  int _shownIndex = 0;

  /// Chỉ dựng lại AppBar khi tab thật sự đổi (listener bắn nhiều lần lúc vuốt).
  void _onTabChanged() {
    if (_tabs.index == _shownIndex) return;
    setState(() => _shownIndex = _tabs.index);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quay lại app (có thể vừa cấp quyền trong Cài đặt / có file mới) → quét lại.
    if (state == AppLifecycleState.resumed) {
      ref.read(scanControllerProvider.notifier).refresh(force: false);
    }
  }

  void _goToCategory(DocCategory category) =>
      _tabs.animateTo(homeTabs.indexOf(category));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final current = homeTabs[_shownIndex];
    // Khởi động lượt quét đầu tiên.
    ref.watch(scanControllerProvider.select((s) => s.phase == ScanPhase.idle));

    return Scaffold(
      drawer: const HomeDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.forCategory(current),
        title: Text(l.core_appName),
        actions: [
          IconButton(
            key: const ValueKey('home-favorites'),
            tooltip: l.docs_favorites,
            icon: const Icon(Icons.star_border),
            onPressed: () => context.push(Routes.favorites),
          ),
          IconButton(
            key: const ValueKey('home-recents'),
            tooltip: l.docs_recents,
            icon: const Icon(Icons.history),
            onPressed: () => context.push(Routes.recents),
          ),
          IconButton(
            key: const ValueKey('home-search'),
            tooltip: l.docs_searchHint,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(Routes.search),
          ),
          const SortMenuButton(),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l.docs_tabAll),
            const Tab(text: 'PDF'),
            const Tab(text: 'DOC'),
            const Tab(text: 'XLS'),
            const Tab(text: 'PPT'),
            const Tab(text: 'TXT'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final category in homeTabs)
            DocumentList(
              category: category,
              onPickCategory: category == null ? _goToCategory : null,
            ),
        ],
      ),
    );
  }
}
