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
        bottomNavigationBar: _PremiumStudentNavigation(
          tabs: tabs,
          selectedIndex: navigationShell.currentIndex,
          onSelected: _select,
        ),
      ),
    );
  }
}

class _PremiumStudentNavigation extends StatelessWidget {
  final List<AppTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PremiumStudentNavigation({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 280);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: .10),
            blurRadius: 24,
            offset: const Offset(0, -7),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++)
                Expanded(
                  child: _PremiumTab(
                    tab: tabs[index],
                    selected: index == selectedIndex,
                    duration: duration,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumTab extends StatelessWidget {
  final AppTab tab;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  const _PremiumTab({
    required this.tab,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: Padding(
          padding: const EdgeInsets.only(top: 7, bottom: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                width: selected ? 38 : 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? AppColors.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.brand.withValues(alpha: .25),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: AnimatedScale(
                  duration: duration,
                  curve: Curves.easeOutBack,
                  scale: selected ? 1.05 : .92,
                  child: Icon(
                    selected ? tab.selectedIcon : tab.icon,
                    size: 21,
                    color: selected ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: selected ? AppColors.ink : AppColors.muted,
                  fontSize: tabsLabelSize(tab.label),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
                child: Text(tab.label, textScaler: TextScaler.noScaling),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double tabsLabelSize(String label) => label.length > 8 ? 9.5 : 10.5;
}
