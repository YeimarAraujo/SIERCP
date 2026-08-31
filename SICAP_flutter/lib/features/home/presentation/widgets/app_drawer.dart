import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// APP DRAWER — Drawer lateral compartido por todos los roles
// ═══════════════════════════════════════════════════════════════════════════════

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user   = ref.watch(currentUserProvider);

    final bg     = isDark ? AppColors.darkBg     : AppColors.lightBg;
    final bg2    = isDark ? AppColors.darkBg2    : AppColors.lightBg2;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────────
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:  bg2,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width:      52,
                    height:     52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.brand, AppColors.brand2],
                        begin: Alignment.topLeft,
                        end:   Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _initials(user?.firstName, user?.lastName),
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Usuario',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        _RoleBadge(role: user?.role ?? ''),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Menu Items ─────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon:   Icons.person_outline,
                    label:  'Mi Perfil',
                    isDark: isDark,
                    onTap:  () {
                      Navigator.pop(context);
                      context.push('/profile');
                    },
                  ),
                  _DrawerItem(
                    icon:   Icons.settings_outlined,
                    label:  'Ajustes',
                    isDark: isDark,
                    onTap:  () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:  Text('Ajustes próximamente'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon:   Icons.security_outlined,
                    label:  'Seguridad',
                    isDark: isDark,
                    onTap:  () {
                      Navigator.pop(context);
                      _showSecuritySheet(
                          context, ref, isDark, theme, user?.email ?? '');
                    },
                  ),
                  _DrawerItem(
                    icon:   Icons.notifications_outlined,
                    label:  'Notificaciones',
                    isDark: isDark,
                    onTap:  () {
                      Navigator.pop(context);
                      context.push('/notifications');
                    },
                  ),
                  _DrawerItem(
                    icon:   Icons.verified_user_outlined,
                    label:  'Mis Certificados',
                    isDark: isDark,
                    onTap:  () {
                      Navigator.pop(context);
                      context.push('/profile/certificados');
                    },
                  ),
                  const Divider(height: 24),
                  _DrawerItem(
                    icon:   Icons.help_outline,
                    label:  'Ayuda & Soporte',
                    isDark: isDark,
                    onTap:  () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:  Text('Contacta a soporte@jomarsegurid.com'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Logout ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon:  Icon(Icons.logout, size: 18, color: AppColors.red),
                  label: Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      color:      AppColors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side:    BorderSide(
                        color: AppColors.red.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape:   RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final ok = await _confirmLogout(context);
                    if (ok && context.mounted) {
                      await ref.read(authStateProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String? first, String? last) {
    final f = first?.isNotEmpty == true ? first![0].toUpperCase() : '';
    final l = last?.isNotEmpty == true ? last![0].toUpperCase() : '';
    return '$f$l'.isEmpty ? '?' : '$f$l';
  }

  Future<bool> _confirmLogout(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title:   const Text('Cerrar sesión'),
            content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                ),
                child: const Text('Salir',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSecuritySheet(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    ThemeData theme,
    String email,
  ) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24, left: 24, right: 24,
        ),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.darkBg2 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize:     MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color:        Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Seguridad',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.lock_reset, color: AppColors.brand),
              title:   const Text('Cambiar contraseña'),
              subtitle: const Text('Recibirás un enlace en tu correo'),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(authStateProvider.notifier)
                    .sendPasswordReset(email);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:  Text('Enlace enviado a $email'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Componentes internos ──────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        size: 22,
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap:              onTap,
      horizontalTitleGap: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      AppConstants.roleSuperAdmin         => ('Super Admin', const Color(0xFF7C3AED)),
      AppConstants.roleAdmin              => ('Admin',        AppColors.brand),
      AppConstants.roleInstructor         => ('Instructor',   AppColors.cyan),
      AppConstants.roleUsuarioSST         => ('SST',          AppColors.green),
      AppConstants.roleUsuarioProfesional => ('Profesional',  AppColors.amber),
      _                                   => ('Usuario',      AppColors.brand2),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      color,
          fontSize:   10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
