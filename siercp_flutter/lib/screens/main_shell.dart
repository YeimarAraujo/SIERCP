import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _getIndex(BuildContext context, bool isAdmin, bool isInstructor) {
    final location = GoRouterState.of(context).matchedLocation;

    if (isAdmin) {
      if (location.startsWith('/home')) return 0;
      if (location.startsWith('/admin/users')) return 1;
      if (location.startsWith('/admin/devices')) return 2;
      if (location.startsWith('/reports')) return 3;
      if (location.startsWith('/analytics')) return 4;
      if (location.startsWith('/profile')) return 5;
    } else if (isInstructor) {
      if (location.startsWith('/home')) return 0;
      if (location.startsWith('/session') || location.startsWith('/scenarios'))
        return 1;
      if (location.startsWith('/history')) return 2;
      if (location.startsWith('/courses')) return 3;
      if (location.startsWith('/reports')) return 4;
      if (location.startsWith('/profile')) return 5;
    } else {
      // Estudiantes
      if (location.startsWith('/home')) return 0;
      if (location.startsWith('/session') || location.startsWith('/scenarios'))
        return 1;
      if (location.startsWith('/history')) return 2;
      if (location.startsWith('/courses')) return 3;
      if (location.startsWith('/profile')) return 4;
    }
    return 0;
  }

  void _onDestinationSelected(int i, BuildContext context, WidgetRef ref,
      bool isAdmin, bool isInstructor) {
    final user = ref.read(currentUserProvider);

    if (isAdmin) {
      switch (i) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go('/admin/users');
          break;
        case 2:
          context.go('/admin/devices');
          break;
        case 3:
          context.go('/reports');
          break;
        case 4:
          context.go('/analytics');
          break;
        case 5:
          context.go('/profile');
          break;
      }
    } else if (isInstructor) {
      switch (i) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go('/scenarios');
          break;
        case 2:
          context.go('/history');
          break;
        case 3:
          context.go('/courses');
          break;
        case 4:
          context.go('/reports');
          break;
        case 5:
          context.go('/profile');
          break;
      }
    } else {
      // Estudiantes - NO tienen acceso a reportes
      switch (i) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go('/session');
          break;
        case 2:
          context.go('/history');
          break;
        case 3:
          context.go('/courses');
          break;
        case 4:
          context.go('/profile');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final isInstructor = user?.isInstructor ?? false;
    final index = _getIndex(context, isAdmin, isInstructor);

    final theme = Theme.of(context);
    final navBgColor = theme.navigationBarTheme.backgroundColor;
    final borderColor = theme.dividerTheme.color ?? AppColors.cardBorder;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final navDestinations = isAdmin
        ? const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Usuarios',
            ),
            NavigationDestination(
              icon: Icon(Icons.developer_board),
              selectedIcon: Icon(Icons.developer_board),
              label: 'Maniquíes',
            ),
            NavigationDestination(
              icon: Icon(Icons.picture_as_pdf_outlined),
              selectedIcon: Icon(Icons.picture_as_pdf),
              label: 'Reportes',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'Analíticas',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ]
        : isInstructor
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_outline),
                  selectedIcon: Icon(Icons.favorite),
                  label: 'Sesión',
                ),
                NavigationDestination(
                  icon: Icon(Icons.show_chart_outlined),
                  selectedIcon: Icon(Icons.show_chart),
                  label: 'Historial',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Cursos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.picture_as_pdf_outlined),
                  selectedIcon: Icon(Icons.picture_as_pdf),
                  label: 'Reportes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_outline),
                  selectedIcon: Icon(Icons.favorite),
                  label: 'Sesión',
                ),
                NavigationDestination(
                  icon: Icon(Icons.show_chart_outlined),
                  selectedIcon: Icon(Icons.show_chart),
                  label: 'Historial',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Cursos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ];

    return Scaffold(
      body: Row(
        children: [
          if (isLandscape)
            Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: borderColor, width: 0.5)),
              ),
              child: SingleChildScrollView(
                child: IntrinsicHeight(
                  child: NavigationRail(
                    selectedIndex: index,
                    onDestinationSelected: (i) => _onDestinationSelected(
                        i, context, ref, isAdmin, isInstructor),
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: navBgColor,
                    selectedLabelTextStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelTextStyle: const TextStyle(fontSize: 11),
                    destinations: navDestinations
                        .map((d) => NavigationRailDestination(
                              icon: d.icon,
                              selectedIcon: d.selectedIcon,
                              label: Text(d.label),
                            ))
                        .toList(),
                  ),
                ),
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
                  top: BorderSide(color: borderColor, width: 0.5),
                ),
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => _onDestinationSelected(
                    i, context, ref, isAdmin, isInstructor),
                destinations: navDestinations,
              ),
            ),
    );
  }
}
