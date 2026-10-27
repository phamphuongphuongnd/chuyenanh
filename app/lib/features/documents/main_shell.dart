import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/tools/tool_registry.dart';
import '../settings/settings_screen.dart';
import 'document_actions.dart';
import 'home_screen.dart';
import 'home_tab.dart';
import 'widgets/tools_sheet.dart';

/// Khung chính: thanh điều hướng dưới
/// (Trang chủ · Tập tin · nút ⇄ giữa · Công cụ · Cài đặt).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeTab(),
          HomeScreen(),
          ToolsPage(),
          SettingsScreen(),
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
    );
  }

  // Mục giữa (⇄) là nút hành động, không phải một trang: vào thẳng Ảnh sang PDF.
  int get _navIndex => _index < 2 ? _index : _index + 1;

  void _onSelected(int i) {
    if (i == 2) {
      launchTool(context, allTools.firstWhere((t) => t.id == 'imageToPdf'));
      return;
    }
    setState(() => _index = i < 2 ? i : i - 1);
  }
}
