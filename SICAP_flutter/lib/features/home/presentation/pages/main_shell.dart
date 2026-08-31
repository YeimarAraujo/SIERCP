import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/features/users/data/models/user.dart';
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

  bool _hideBottomNav(String location) {
    const hiddenRoutes = [
      '/simulation/practical/session',
      '/simulation/practical/session-result',
      '/simulation/practical/scenario-guide',
      '/simulation/theoretical/evaluations/:topicId',
      '/simulation/theoretical/result',
      '/simulation/ecg',
      '/simulation/theoretical/cases',
      '/simulation/theoretical/random',
      '/simulation/theoretical/triage',
      '/simulation/theoretical/result/:sessionId',
      '/simulation/aed-simulator',
      '/simulation/airway-simulator',
      '/simulation/acls-simulator',
      '/simulation/trauma-simulator',
      '/live',
      '/course-editor',
      '/student',
    ];

    return hiddenRoutes.any((route) => location.startsWith(route));
  }

  List<NavItem> _getNavItems(
    UserModel? user,
    OrgContextState orgCtx,
    bool isInstructorOnCourse,
    AppLocalizations loc,
  ) {
    final isAdminRole = orgCtx.isAdmin || (user?.isAdmin == true);
    if (isAdminRole) {
      return [
        NavItem(loc.navDashboard, Icons.dashboard_outlined, Icons.dashboard,
            '/home'),
        const NavItem('En vivo', Icons.live_tv_outlined, Icons.live_tv,
            '/instructor/students'),
        const NavItem(
            'Cursos', Icons.menu_book_outlined, Icons.menu_book, '/courses'),
        NavItem(
            loc.navUsers, Icons.group_outlined, Icons.group, '/admin/users'),
        NavItem(loc.navProfile, Icons.person_outline, Icons.person, '/profile'),
      ];
    }
    // Instructor: por membership, por rol global, O por asignación directa en un curso
    final isInstructor = orgCtx.isInstructor ||
        (user?.isInstructor == true) ||
        isInstructorOnCourse;
    if (isInstructor) {
      return [
        NavItem(loc.navHome, Icons.home_outlined, Icons.home, '/home'),
        NavItem(loc.navSimulation, Icons.psychology_outlined, Icons.psychology,
            '/simulation'),
        const NavItem('Mis cursos', Icons.menu_book_outlined, Icons.menu_book,
            '/courses'),
        const NavItem('En vivo', Icons.live_tv_outlined, Icons.live_tv,
            '/instructor/students'),
        NavItem(loc.navProfile, Icons.person_outline, Icons.person, '/profile'),
      ];
    }
    return [
      NavItem(loc.navHome, Icons.home_outlined, Icons.home, '/home'),
      NavItem(loc.navSimulation, Icons.psychology_outlined, Icons.psychology,
          '/simulation'),
      NavItem(loc.navCourses, Icons.menu_book_outlined, Icons.menu_book,
          '/courses'),
      const NavItem(
          'Historial', Icons.history_outlined, Icons.history, '/history'),
      NavItem(loc.navProfile, Icons.person_outline, Icons.person, '/profile'),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final orgCtx = ref.watch(orgContextProvider);
    final loc = AppLocalizations.of(context)!;
    // Detecta instructor por asignación directa en curso (puede ser async)
    final isInstructorOnCourse =
        ref.watch(isInstructorOnCourseProvider).valueOrNull ?? false;
    final navItems = _getNavItems(user, orgCtx, isInstructorOnCourse, loc);

    final location = GoRouterState.of(context).uri.path;
    final hideNavBar = _hideBottomNav(location);

    const profileChildRoutes = [
      '/badges',
      '/learning-paths',
      '/ranking',
      '/skills',
    ];

    int index = navItems.indexWhere((item) =>
        location == item.route || location.startsWith('${item.route}/'));
    if (index == -1) {
      index = navItems.indexWhere((item) => location.startsWith(item.route));
    }
    if (index == -1) {
      if (profileChildRoutes
          .any((r) => location == r || location.startsWith('$r/'))) {
        index = navItems.indexWhere((item) => item.route == '/profile');
      }
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
        appBar: null,
        body: Row(
          children: [
            if (isLandscape && !hideNavBar)
              Container(
                key: const ValueKey('main-shell-rail'),
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
                    size: 24,
                    color: theme.navigationBarTheme.iconTheme
                        ?.resolve({WidgetState.selected})?.color,
                  ),
                  unselectedIconTheme: IconThemeData(
                    size: 24,
                    color:
                        theme.navigationBarTheme.iconTheme?.resolve({})?.color,
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
            Expanded(
              key: const ValueKey('main-shell-body'),
              child: child,
            ),
          ],
        ),
        bottomNavigationBar: (isLandscape || hideNavBar)
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
