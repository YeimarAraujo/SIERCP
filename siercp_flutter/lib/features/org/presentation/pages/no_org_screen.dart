import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';

/// Pantalla mostrada cuando un ADMIN está autenticado pero no pertenece
/// a ninguna organización activa (sin memberships aprobadas).
/// USUARIO e INSTRUCTOR siempre pasan al /home directamente.
class NoOrgScreen extends ConsumerWidget {
  const NoOrgScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP  = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final user   = ref.watch(currentUserProvider);
    final role   = user?.role ?? '';

    final _Config cfg = switch (role) {
      AppConstants.roleAdmin => const _Config(
          icon:     Icons.domain_disabled_outlined,
          color:    AppColors.brand,
          title:    'Institución no asignada',
          body:     'Tu cuenta de administrador está activa, pero aún no está '
                    'vinculada a ninguna organización en SIERCP.',
          hint:     'Registra tu empresa o institución para comenzar, '
                    'o espera a que el equipo de SIERCP active tu cuenta.',
          actions:  _Actions.adminActions,
        ),
      _ => const _Config(
          icon:     Icons.domain_disabled_outlined,
          color:    AppColors.brand,
          title:    'Sin organización asignada',
          body:     'Tu cuenta está activa pero aún no has sido añadido '
                    'a ninguna organización en SIERCP.',
          hint:     'Contacta al administrador de tu empresa o institución '
                    'para que te invite, o continúa usando la plataforma '
                    'de forma independiente.',
          actions:  _Actions.defaultActions,
        ),
    };  // ignore: exhaustive_cases

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Ilustración ──────────────────────────────────────────────
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cfg.color.withValues(alpha: isDark ? 0.25 : 0.12),
                      AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(cfg.icon, size: 52, color: cfg.color),
              ),
              const SizedBox(height: 28),

              // ── Título ───────────────────────────────────────────────────
              Text(
                cfg.title,
                style: TextStyle(
                  color:      textP,
                  fontSize:   22,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // ── Descripción ──────────────────────────────────────────────
              Text(
                cfg.body,
                style: TextStyle(color: textS, fontSize: 14, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                cfg.hint,
                style: TextStyle(color: textS, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // ── Info del usuario ─────────────────────────────────────────
              if (user != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color:        isDark ? AppColors.darkBg2 : AppColors.lightBg2,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: cfg.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            user.initials,
                            style: TextStyle(
                              color:      cfg.color,
                              fontWeight: FontWeight.w700,
                              fontSize:   14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName,
                                style: TextStyle(
                                    color:      textP,
                                    fontWeight: FontWeight.w600,
                                    fontSize:   13)),
                            Text(user.email,
                                style: TextStyle(color: textS, fontSize: 11)),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cfg.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(role,
                                  style: TextStyle(
                                      color:      cfg.color,
                                      fontSize:   9,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const Spacer(flex: 2),

              // ── Acciones ─────────────────────────────────────────────────
              if (cfg.actions == _Actions.adminActions) ...[
                FilledButton.icon(
                  onPressed: () => context.go('/register-institution'),
                  icon:  const Icon(Icons.add_business_outlined, size: 18),
                  label: const Text('Registrar mi institución'),
                  style: FilledButton.styleFrom(
                    minimumSize:     const Size(double.infinity, 50),
                    backgroundColor: AppColors.brand,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              ElevatedButton.icon(
                onPressed: () async {
                  await ref
                      .read(orgContextProvider.notifier)
                      .loadForUser(user?.id ?? '');
                  if (context.mounted) {
                    final orgCtx = ref.read(orgContextProvider);
                    if (orgCtx.hasOrg) context.go('/home');
                  }
                },
                icon:  const Icon(Icons.refresh_outlined),
                label: const Text('Verificar acceso'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),

              if (cfg.actions == _Actions.defaultActions) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon:  const Icon(Icons.home_outlined, size: 18),
                  label: const Text('Continuar sin organización'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],

              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                icon:  Icon(Icons.logout_outlined, size: 16, color: textS),
                label: Text('Cerrar sesión',
                    style: TextStyle(color: textS, fontSize: 13)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Config helpers ────────────────────────────────────────────────────────────

enum _Actions { adminActions, defaultActions }

class _Config {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String hint;
  final _Actions actions;
  const _Config({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.hint,
    required this.actions,
  });
}
