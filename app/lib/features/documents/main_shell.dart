import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tools/tool_registry.dart';
import '../../core/widgets/widgets.dart';
import '../settings/app_logo.dart';
import '../settings/settings_screen.dart';
import 'document_actions.dart';
import 'documents_providers.dart';
import 'home_screen.dart';
import 'home_tab.dart';
import 'widgets/tools_sheet.dart';

/// Khung chính: thanh điều hướng dưới (Trang chủ · Tập tin · nút ⇄ giữa · Công cụ · Cài đặt);
/// trên máy tính bảng là thanh bên trái cố định.
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

  void _select(int page) => setState(() {
    _index = page;
    _built.add(page);
  });

  // Nút ⇄ là hành động, không phải một trang: vào thẳng Ảnh sang PDF.
  void _convert() =>
      launchTool(context, allTools.firstWhere((t) => t.id == 'imageToPdf'));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pages = IndexedStack(
      index: _index,
      children: [
        _tab(0, () => const HomeTab()),
        _tab(1, () => const HomeScreen()),
        _tab(2, () => const ToolsPage()),
        _tab(3, () => const SettingsScreen()),
      ],
    );
    final items = [
      _NavSpec('nav-home', Symbols.home_rounded, l.docs_navHome),
      _NavSpec('nav-files', Symbols.folder_rounded, l.docs_navFiles),
      _NavSpec('nav-tools', Symbols.widgets_rounded, l.docs_toolsTitle),
      _NavSpec('nav-settings', Symbols.settings_rounded, l.settings_title),
    ];
    final tablet = isTabletLayout(context);
    // Back ở tab khác Trang chủ thì về Trang chủ thay vì thoát app.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0); // tab 0 luôn đã dựng
      },
      child: tablet
          ? Scaffold(
              body: Row(
                children: [
                  _SideBar(
                    items: items,
                    selected: _index,
                    onSelect: _select,
                    onConvert: _convert,
                  ),
                  Expanded(child: pages),
                ],
              ),
            )
          : Scaffold(
              body: pages,
              bottomNavigationBar: _BottomBar(
                items: items,
                selected: _index,
                onSelect: _select,
                onConvert: _convert,
              ),
            ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.key, this.icon, this.label);

  final String key;
  final IconData icon;
  final String label;
}

/// Màu mục đang chọn (đỏ chủ đạo ở bản sáng, đỏ nhạt ở bản tối).
Color _activeColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? context.tokens.primaryText
    : AppColors.primary;

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onConvert,
  });

  final List<_NavSpec> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onConvert;

  Widget _item(BuildContext context, int page) {
    final spec = items[page];
    final on = page == selected;
    final t = context.tokens;
    final color = on ? _activeColor(context) : t.textMuted;
    return Expanded(
      child: InkResponse(
        key: ValueKey(spec.key),
        onTap: () => onSelect(page),
        child: Semantics(
          selected: on,
          button: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 30,
                decoration: BoxDecoration(
                  color: on ? t.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Icon(spec.icon, size: 24, fill: on ? 1 : 0, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              const SizedBox(width: 6),
              _item(context, 0),
              _item(context, 1),
              Expanded(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -16),
                    child: _ConvertButton(onTap: onConvert),
                  ),
                ),
              ),
              _item(context, 2),
              _item(context, 3),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút tròn đỏ ⇄ giữa thanh dưới (mở Ảnh sang PDF).
class _ConvertButton extends StatelessWidget {
  const _ConvertButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = toolLabel(
      context,
      allTools.firstWhere((t) => t.id == 'imageToPdf'),
    );
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: const ValueKey('nav-convert'),
        onTap: onTap,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: context.tokens.bg, width: 4),
            boxShadow: AppShadows.navAction,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Symbols.swap_horiz_rounded,
            size: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Thanh bên trái của máy tính bảng: logo, nút "Ảnh sang PDF", 4 trang, mục Lối tắt.
class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onConvert,
  });

  final List<_NavSpec> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final active = _activeColor(context);
    Widget shortcut(IconData icon, String label, String route) => _SideRow(
      height: 46,
      icon: Icon(icon, size: 22, color: t.textMuted),
      label: Text(
        label,
        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: t.text),
      ),
      onTap: () => context.push(route),
    );
    return Container(
      width: size.width > size.height ? 264 : 236,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(right: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        right: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const AppLogo(size: 36),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.core_appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: t.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  key: const ValueKey('nav-convert'),
                  borderRadius: BorderRadius.circular(18),
                  onTap: onConvert,
                  child: SizedBox(
                    height: 54,
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Symbols.swap_horiz_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            toolLabel(
                              context,
                              allTools.firstWhere((x) => x.id == 'imageToPdf'),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < items.length; i++)
                _SideRow(
                  key: ValueKey(items[i].key),
                  height: 48,
                  background: i == selected ? t.primarySoft : null,
                  icon: Icon(
                    items[i].icon,
                    size: 23,
                    fill: i == selected ? 1 : 0,
                    color: i == selected ? active : t.textMuted,
                  ),
                  label: Text(
                    items[i].label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: i == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: i == selected ? active : t.text,
                    ),
                  ),
                  onTap: () => onSelect(i),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Divider(height: 1, color: t.line),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                child: Text(
                  l.docs_shortcuts,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.textMuted,
                  ),
                ),
              ),
              shortcut(Symbols.history_rounded, l.docs_recents, Routes.recents),
              shortcut(Symbols.star_rounded, l.docs_favorites, Routes.favorites),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideRow extends StatelessWidget {
  const _SideRow({
    super.key,
    required this.height,
    required this.icon,
    required this.label,
    required this.onTap,
    this.background,
  });

  final double height;
  final Widget icon;
  final Widget label;
  final VoidCallback onTap;
  final Color? background;

  @override
  Widget build(BuildContext context) => Material(
    color: background ?? Colors.transparent,
    shape: const StadiumBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            const SizedBox(width: 14),
            icon,
            const SizedBox(width: 12),
            Expanded(child: label),
          ],
        ),
      ),
    ),
  );
}
