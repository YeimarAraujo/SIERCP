import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/l10n/app_localizations.dart';

class NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  const NavItem(this.label, this.icon, this.selectedIcon, this.route);
}

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  List<NavItem> _getNavItems(bool isAdmin, bool isInstructor, AppLocalizations loc) {
    if (isAdmin) {
      return [
        NavItem(
            loc.navDashboard, Icons.dashboard_outlined, Icons.dashboard, '/home'),
        NavItem(loc.navUsers, Icons.group_outlined, Icons.group, '/admin/users'),
        NavItem(loc.navReports, Icons.picture_as_pdf_outlined, Icons.picture_as_pdf,
            '/reports'),
        NavItem(loc.navAnalytics, Icons.analytics_outlined, Icons.analytics,
            '/analytics'),
        NavItem(loc.navProfile, Icons.person_outline, Icons.person, '/profile'),
      ];
    } else if (isInstructor) {
      return [
        NavItem(loc.navHome, Icons.home_outlined, Icons.home, '/home'),
        NavItem(loc.navSession, Icons.favorite_outline, Icons.favorite, '/scenarios'),
        NavItem(loc.navHistory, Icons.show_chart_outlined, Icons.show_chart,
            '/history'),
        NavItem(
            loc.navCourses, Icons.menu_book_outlined, Icons.menu_book, '/courses'),
        NavItem(loc.navReports, Icons.picture_as_pdf_outlined, Icons.picture_as_pdf,
            '/reports'),
        NavItem(loc.navProfile, Icons.person_outline, Icons.person, '/profile'),
      ];
    } else {
      return [
        NavItem(loc.navHome, Icons.home_outlined, Icons.home, '/home'),
        NavItem(loc.navSession, Icons.favorite_outline, Icons.favorite, '/scenarios'),
        NavItem(loc.navHistory, Icons.show_chart_outlined, Icons.show_chart,
            '/history'),
        NavItem(
            loc.navCourses, Icons.menu_book_outlined, Icons.menu_book, '/courses'),
        NavItem(loc.navProfile, Icons.person_outline, Icons.person, '/profile'),
      ];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final loc = AppLocalizations.of(context)!;
    final isAdmin = user?.isAdmin ?? false;
    final isInstructor = user?.isInstructor ?? false;
    final navItems = _getNavItems(isAdmin, isInstructor, loc);

    final location = GoRouterState.of(context).matchedLocation;
    int index = navItems.indexWhere((item) =>
        location == item.route || location.startsWith(item.route + '/'));
    if (index == -1) {
      index = navItems.indexWhere((item) => location.startsWith(item.route));
    }
    if (index == -1) index = 0;

    final theme = Theme.of(context);
    final navBgColor = theme.navigationBarTheme.backgroundColor;
    final borderColor = theme.dividerTheme.color ?? AppColors.cardBorder;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (index != 0) {
          context.go('/home');
        }
      },
      child: Scaffold(
        body: Row(
          children: [
            if (isLandscape)
              Container(
                width: 100,
                decoration: BoxDecoration(
                  color: navBgColor,
                  border:
                      Border(right: BorderSide(color: borderColor, width: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (i) => context.go(navItems[i].route),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.transparent,
                  indicatorColor: theme.navigationBarTheme.indicatorColor,
                  indicatorShape: theme.navigationBarTheme.indicatorShape,
                  selectedIconTheme: IconThemeData(
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  unselectedIconTheme: IconThemeData(
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  selectedLabelTextStyle: theme
                      .navigationBarTheme.labelTextStyle
                      ?.resolve({WidgetState.selected}),
                  unselectedLabelTextStyle:
                      theme.navigationBarTheme.labelTextStyle?.resolve({}),
                  destinations: navItems
                      .map((d) => NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon),
                            label: Text(d.label),
                          ))
                      .toList(),
                ),
              ),
            Expanded(child: child),
          ],
        ),
        bottomNavigationBar: isLandscape
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: navBgColor,
                  border: Border(
                    top: BorderSide(
                        color: borderColor.withValues(alpha: 0.1), width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: NavigationBar(
                  height: 70,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: index,
                  onDestinationSelected: (i) => context.go(navItems[i].route),
                  destinations: navItems
                      .map((d) => NavigationDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon),
                            label: d.label,
                          ))
                      .toList(),
                ),
              ),
      ),
    );
  }
}
