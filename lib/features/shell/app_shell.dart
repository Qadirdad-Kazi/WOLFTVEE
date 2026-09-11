import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/wolf_tv.dart';
import '../../core/theme/wolf_colors.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../core/widgets/wolf_brand.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _go(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tv = WolfTv.isTv;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: WolfColors.charcoal,
          border: Border(top: BorderSide(color: WolfColors.steel, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: tv ? 78 : 64,
            child: Row(
              children: [
                _NavItem(
                  label: 'HOME',
                  icon: Icons.home_outlined,
                  active: navigationShell.currentIndex == 0,
                  autofocus: tv,
                  onTap: () => _go(0),
                ),
                _NavItem(
                  label: 'FILMS',
                  icon: Icons.movie_outlined,
                  active: navigationShell.currentIndex == 1,
                  onTap: () => _go(1),
                ),
                _NavItem(
                  label: 'SERIES',
                  icon: Icons.tv_outlined,
                  active: navigationShell.currentIndex == 2,
                  onTap: () => _go(2),
                ),
                _NavItem(
                  label: 'LIVE',
                  icon: Icons.sensors,
                  active: navigationShell.currentIndex == 3,
                  onTap: () => _go(3),
                ),
                _NavItem(
                  label: 'YOU',
                  icon: Icons.person_outline,
                  active: navigationShell.currentIndex == 4,
                  onTap: () => _go(4),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: navigationShell.currentIndex == 4
          ? null
          : WolfTvFocusable(
              onActivate: () => context.push('/search'),
              child: FloatingActionButton.small(
                backgroundColor: WolfColors.lime,
                foregroundColor: WolfColors.voidBlack,
                elevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                shape: const RoundedRectangleBorder(),
                onPressed: () => context.push('/search'),
                child: const Icon(Icons.search),
              ),
            ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.autofocus = false,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tv = WolfTv.isTv;
    return Expanded(
      child: WolfTvFocusable(
        autofocus: autofocus,
        onActivate: onTap,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 2,
                width: active ? 24 : 0,
                color: WolfColors.lime,
                margin: const EdgeInsets.only(bottom: 6),
              ),
              Icon(
                icon,
                size: tv ? 26 : 22,
                color: active ? WolfColors.lime : WolfColors.mist,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: active ? WolfColors.lime : WolfColors.mist,
                      fontSize: tv ? 11 : 9,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact top bar used by secondary tabs.
class WolfTopBar extends StatelessWidget implements PreferredSizeWidget {
  const WolfTopBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 20,
      title: Row(
        children: [
          const WolfLogoMark(size: 28, radius: 5),
          const SizedBox(width: 10),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
      actions: actions,
    );
  }
}
