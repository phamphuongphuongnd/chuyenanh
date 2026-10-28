import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/tools/tool_registry.dart';
import '../settings/settings_screen.dart';
import 'document_actions.dart';
import 'documents_providers.dart';
import 'home_screen.dart';
import 'home_tab.dart';
import 'widgets/tools_sheet.dart';

/// Khung chính: thanh điều hướng dưới
/// (Trang chủ · Tập tin · nút ⇄ giữa · Công cụ · Cài đặt).
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _index = 0;

  /// Tab đã được chọn ít nhất một lần (dựng lười, sau đó giữ sống).
  final _built = <int>{0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tab "Tập tin" (nơi kích hoạt lượt quét đầu) giờ dựng lười: đọc provider
    // ở đây (sau khung hình đầu, để Trang chủ hiện trước) để lượt quét đầu vẫn chạy.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(scanControllerProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Khi tab Tập tin chưa dựng thì nó chưa tự quét lại lúc resume → làm thay.
    if (state == AppLifecycleState.resumed && !_built.contains(1)) {
      ref.read(scanControllerProvider.notifier).refresh(force: false);
    }
  }

  Widget _tab(int i, Widget Function() make) =>
      _built.contains(i) ? make() : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Back ở tab khác Trang chủ thì về Trang chủ thay vì thoát app.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0); // tab 0 luôn đã dựng
      },
      child: Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _tab(0, () => const HomeTab()),
          _tab(1, () => const HomeScreen()),
          _tab(2, () => const ToolsPage()),
          _tab(3, () => const SettingsScreen()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _onSelected,
        destinations: [
          NavigationDestination(
            key: const ValueKey('nav-home'),
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l.docs_navHome,
          ),
          NavigationDestination(
            key: const ValueKey('nav-files'),
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: l.docs_navFiles,
          ),
          NavigationDestination(
            key: const ValueKey('nav-convert'),
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.swap_horiz, color: Colors.white),
            ),
            label: '',
          ),
          NavigationDestination(
            key: const ValueKey('nav-tools'),
            icon: const Icon(Icons.apps_outlined),
            selectedIcon: const Icon(Icons.apps),
            label: l.docs_toolsTitle,
          ),
          NavigationDestination(
            key: const ValueKey('nav-settings'),
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l.settings_title,
          ),
        ],
      ),
    ),
    );
  }

  // Mục giữa (⇄) là nút hành động, không phải một trang: vào thẳng Ảnh sang PDF.
  int get _navIndex => _index < 2 ? _index : _index + 1;

  void _onSelected(int i) {
    if (i == 2) {
      launchTool(context, allTools.firstWhere((t) => t.id == 'imageToPdf'));
      return;
    }
    setState(() {
      _index = i < 2 ? i : i - 1;
      _built.add(_index);
    });
  }
}
