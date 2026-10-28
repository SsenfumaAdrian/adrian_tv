import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand.dart';

/// Responsive navigation shell: bottom bar on phones, side rail on TV and
/// large screens (width >= 900 dp).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _destinations = [
    (
      path: AppRoute.home,
      icon: Icons.home_outlined,
      selected: Icons.home,
      label: 'Home',
    ),
    (
      path: AppRoute.live,
      icon: Icons.live_tv_outlined,
      selected: Icons.live_tv,
      label: 'Live TV',
    ),
    (
      path: AppRoute.guide,
      icon: Icons.calendar_month_outlined,
      selected: Icons.calendar_month,
      label: 'Guide',
    ),
    (
      path: AppRoute.search,
      icon: Icons.search_outlined,
      selected: Icons.search,
      label: 'Search',
    ),
    (
      path: AppRoute.settings,
      icon: Icons.settings_outlined,
      selected: Icons.settings,
      label: 'Settings',
    ),
  ];

  int get _index {
    final i = _destinations.indexWhere((d) => location.startsWith(d.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    if (!isWide) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => context.go(_destinations[i].path),
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selected, color: AppColors.cyan),
                label: d.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: BrandMark(size: width >= 1200 ? 44 : 36),
              ),
              Expanded(
                child: NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) =>
                      context.go(_destinations[i].path),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: AppColors.surface,
                  indicatorColor: AppColors.violet.withValues(alpha: 0.24),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selected, color: AppColors.cyan),
                        label: Text(d.label),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const VerticalDivider(width: 1, color: AppColors.surfaceBright),
          Expanded(child: child),
        ],
      ),
    );
  }
}
