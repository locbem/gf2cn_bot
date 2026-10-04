import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'section_page.dart';
import 'settings_page.dart';

/// Khung chính: thanh điều hướng dưới (điện thoại) hoặc bên trái (Windows/màn rộng).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final Set<int> _visited = {0};

  static const _sections = ['handbook', 'world', 'news'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = AppScope.read(context);
      app.startBackgroundTasks(onTranslationUpdated: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppScope.read(context).s.t('translation_updated_snack'))),
        );
      });
    });
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final destinations = <(IconData, IconData, String)>[
      (Icons.menu_book_outlined, Icons.menu_book_rounded, s.t('nav_handbook')),
      (Icons.public_outlined, Icons.public_rounded, s.t('nav_world')),
      (Icons.perm_media_outlined, Icons.perm_media_rounded, s.t('nav_news')),
      (Icons.settings_outlined, Icons.settings_rounded, s.t('settings')),
    ];

    final pages = [
      for (final key in _sections) SectionPage(sectionKey: key),
      const SettingsPage(),
    ];

    // Chỉ dựng trang khi đã từng mở (khởi động nhanh hơn), sau đó giữ trạng thái.
    final body = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < pages.length; i++)
          _visited.contains(i) ? pages[i] : const SizedBox.shrink(),
      ],
    );

    final wide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _select(0);
      },
      child: wide
          ? Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    extended: MediaQuery.sizeOf(context).width >= 1280,
                    minExtendedWidth: 200,
                    labelType: MediaQuery.sizeOf(context).width >= 1280
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: _RailLogo(),
                    ),
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: Icon(d.$1),
                          selectedIcon: Icon(d.$2),
                          label: Text(d.$3),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      children: [
                        const _DownloadStrip(),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Scaffold(
              body: body,
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _DownloadStrip(),
                  NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: [
                      for (final d in destinations)
                        NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _RailLogo extends StatelessWidget {
  const _RailLogo();

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accent, Color(0xFF8C2F00)],
          ),
        ),
        alignment: Alignment.center,
        child: const Text('GF2', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
      );
}

/// Thanh tiến độ mảnh khi đang tải ảnh nền.
class _DownloadStrip extends StatelessWidget {
  const _DownloadStrip();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListenableBuilder(
      listenable: app.offline,
      builder: (context, _) {
        final dl = app.offline;
        if (!dl.running) return const SizedBox.shrink();
        return Tooltip(
          message: app.s.t('downloading_pack', {
            'pack': dl.current == null ? '' : app.s.t('pack_${dl.current!.name}'),
            'd': dl.done,
            't': dl.total,
          }),
          child: LinearProgressIndicator(
            value: dl.preparing ? null : dl.fraction,
            minHeight: 2,
            backgroundColor: Colors.transparent,
          ),
        );
      },
    );
  }
}
