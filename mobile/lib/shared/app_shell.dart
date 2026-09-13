import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import 'live_events/live_events_listener.dart';

class AppTab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AppTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Bottom-tab frame for a signed-in role. Each tab keeps its own navigation
/// stack (StatefulShellRoute.indexedStack); detail screens are pushed above
/// the shell so the bar only shows on top-level destinations. Hosts the live
/// event listener so notifications surface on whichever tab is open.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final List<AppTab> tabs;

  const AppShell({
    super.key,
    required this.navigationShell,
    required this.tabs,
  });

  void _select(int index) {
    if (index != navigationShell.currentIndex) {
      HapticFeedback.selectionClick();
    }
    // Re-tapping the current tab returns it to its first screen.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiveEventsListener(
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _select,
            destinations: [
              for (final tab in tabs)
                NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: tab.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
