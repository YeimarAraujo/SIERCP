import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/user.dart';
import '../services/admin_service.dart';

class UserDetailScreen extends ConsumerWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return usersAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.brand)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (users) {
        final user = users.where((u) => u.id == userId).firstOrNull;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Usuario no encontrado')),
            body: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_off_outlined, size: 48, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('Usuario no encontrado', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          );
        }
        return _UserDetailBody(user: user);
      },
    );
  }
}

class _UserDetailBody extends ConsumerWidget {
  final UserModel user;
  const _UserDetailBody({required this.user});

  Color get _roleColor {
    switch (user.role) {
      case 'ADMIN': return AppColors.amber;
      case 'INSTRUCTOR': return AppColors.accent;
      default: return AppColors.cyan;
    }
  }

  IconData get _roleIcon {
    switch (user.role) {
      case 'ADMIN': return Icons.admin_panel_settings_outlined;
      case 'INSTRUCTOR': return Icons.school_outlined;
      default: return Icons.person_outline;
    }
  }

  String get _roleLabel {
    switch (user.role) {
      case 'ADMIN': return 'Administrador';
      case 'INSTRUCTOR': return 'Instructor';
      default: return 'Estudiante';
    }
  }

  Future<void> _deleteUser(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: RichText(
          text: TextSpan(
            style: Theme.of(ctx).textTheme.bodyMedium,
            children: [
              const TextSpan(text: '¿Estás seguro de que deseas eliminar a '),
              TextSpan(
                text: user.fullName.isNotEmpty ? user.fullName : user.email,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: '? Esta acción no se puede deshacer.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Eliminar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 44),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await ref.read(adminServiceProvider).deleteUser(user.id);
        ref.invalidate(allUsersProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Usuario eliminado exitosamente'),
                ],
              ),
              backgroundColor: AppColors.green.withValues(alpha: 0.9),
            ),
          );
          context.go('/admin/users');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.red.withValues(alpha: 0.9),
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(adminServiceProvider).toggleUserActive(user.id);
      ref.invalidate(allUsersProvider);
      if (context.mounted) {
        final msg = user.isActive ? 'Cuenta desactivada' : 'Cuenta activada';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final surface = theme.colorScheme.surface;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.colorScheme.outline;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/admin/users'),
        ),
        title: const Text('Detalle de Usuario'),
        actions: [
          // Active/inactive toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                user.isActive ? Icons.block_outlined : Icons.check_circle_outlined,
                color: user.isActive ? AppColors.amber : AppColors.green,
              ),
              tooltip: user.isActive ? 'Desactivar cuenta' : 'Activar cuenta',
              onPressed: () => _toggleActive(context, ref),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: _roleColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: _roleColor.withValues(alpha: 0.4), width: 2),
                      boxShadow: AppShadows.elevated(isDark),
                    ),
                    child: Center(
                      child: Text(
                        user.initials,
                        style: TextStyle(
                          color: _roleColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.fullName.isNotEmpty ? user.fullName : 'Sin nombre',
                    style: TextStyle(
                      color: textP,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_roleIcon, size: 12, color: _roleColor),
                            const SizedBox(width: 5),
                            Text(
                              _roleLabel,
                              style: TextStyle(
                                color: _roleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!user.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.redBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.block_outlined, size: 12, color: AppColors.red),
                              SizedBox(width: 5),
                              Text('Inactivo', style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Info cards
            Text('Información de cuenta', style: TextStyle(color: textS, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.1)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: border, width: 0.5),
                boxShadow: isDark ? null : AppShadows.card(false),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.email_outlined,
                    label: 'Correo electrónico',
                    value: user.email,
                  ),
                  Divider(color: border, height: 0.5),
                  _InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Identificación / Cédula',
                    value: user.identificacion ?? 'No registrada',
                    valueColor: user.identificacion != null ? null : textS,
                  ),
                  Divider(color: border, height: 0.5),
                  _InfoRow(
                    icon: Icons.alternate_email_outlined,
                    label: 'Usuario',
                    value: user.email.split('@').first,
                  ),
                  Divider(color: border, height: 0.5),
                  _InfoRow(
                    icon: Icons.circle,
                    label: 'Estado',
                    value: user.isActive ? 'Activo' : 'Inactivo',
                    valueColor: user.isActive ? AppColors.green : AppColors.red,
                    iconColor: user.isActive ? AppColors.green : AppColors.red,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Actions
            Text('Acciones', style: TextStyle(color: textS, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.1)),
            const SizedBox(height: 10),

            // Toggle active
            OutlinedButton.icon(
              onPressed: () => _toggleActive(context, ref),
              icon: Icon(
                user.isActive ? Icons.block_outlined : Icons.check_circle_outlined,
                size: 18,
              ),
              label: Text(user.isActive ? 'Desactivar cuenta' : 'Reactivar cuenta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: user.isActive ? AppColors.amber : AppColors.green,
                side: BorderSide(
                  color: user.isActive ? AppColors.amber : AppColors.green,
                  width: 1,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Delete
            if (user.role != 'ADMIN')
              ElevatedButton.icon(
                onPressed: () => _deleteUser(context, ref),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Eliminar usuario'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.redBg,
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red, width: 0.5),
                  elevation: 0,
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color? iconColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor ?? textS),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: textS, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: valueColor ?? textP, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

