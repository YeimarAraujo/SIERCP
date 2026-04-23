import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _getIndex(BuildContext context, bool isAdmin) {
    final location = GoRouterState.of(context).matchedLocation;
    if (isAdmin) {
      if (location.startsWith('/home')) return 0;
      if (location.startsWith('/admin/users')) return 1;
      if (location.startsWith('/admin/devices')) return 2;
      if (location.startsWith('/profile')) return 3;
    } else {
      if (location.startsWith('/home')) return 0;
      if (location.startsWith('/session') || location.startsWith('/scenarios')) return 1;
      if (location.startsWith('/history')) return 2;
      if (location.startsWith('/courses')) return 3;
      if (location.startsWith('/profile')) return 4;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final index = _getIndex(context, isAdmin);
    
    final theme = Theme.of(context);
    final navBgColor = theme.navigationBarTheme.backgroundColor;
    final borderColor = theme.dividerTheme.color ?? AppColors.cardBorder;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBgColor,
          border: Border(
            top: BorderSide(color: borderColor, width: 0.5),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) {
            if (isAdmin) {
              switch (i) {
                case 0: context.go('/home');
                case 1: context.go('/admin/users');
                case 2: context.go('/admin/devices');
                case 3: context.go('/profile');
              }
            } else {
              switch (i) {
                case 0: context.go('/home');
                case 1: context.go('/scenarios');
                case 2: context.go('/history');
                case 3: context.go('/courses');
                case 4: context.go('/profile');
              }
            }
          },
          destinations: isAdmin ? const [
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
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ] : const [
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
          ],
        ),
      ),
    );
  }
}

