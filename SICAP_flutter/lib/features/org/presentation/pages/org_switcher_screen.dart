import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/models/membership.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';

/// Pantalla de selección de organización activa.
/// Mostrada cuando el usuario pertenece a más de una organización.
class OrgSwitcherScreen extends ConsumerWidget {
  const OrgSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme    = Theme.of(context);
    final isDark   = theme.brightness == Brightness.dark;
    final textP    = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS    = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final orgCtx   = ref.watch(orgContextProvider);
    final user     = ref.watch(currentUserProvider);
    final memberships = orgCtx.allMemberships;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (orgCtx.hasOrg)
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back_ios_new,
                              size: 16, color: textS),
                          const SizedBox(width: 6),
                          Text('Volver',
                              style: TextStyle(color: textS, fontSize: 13)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text('Selecciona una organización',
                      style: TextStyle(
                          color:      textP,
                          fontSize:   22,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'Hola, ${user?.firstName ?? 'Usuario'}. '
                    'Perteneces a ${memberships.length} organizaciones.',
                    style: TextStyle(color: textS, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Lista de orgs ────────────────────────────────────────────────
            Expanded(
              child: memberships.isEmpty
                  ? _buildEmpty(context, textP, textS)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: memberships.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _OrgCard(
                        membership: memberships[i],
                        isActive: orgCtx.activeOrgId == memberships[i].institutionId,
                        isDark:   isDark,
                        onTap: () async {
                          await ref
                              .read(orgContextProvider.notifier)
                              .switchOrg(memberships[i].institutionId);
                          if (context.mounted) context.go('/home');
                        },
                      ),
                    ),
            ),

            // ── Footer ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                icon:  const Icon(Icons.logout_outlined, size: 16),
                label: const Text('Cerrar sesión'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, Color textP, Color textS) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.domain_outlined,
                size: 48, color: textS.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Sin organizaciones',
                style: TextStyle(
                    color: textP, fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            Text('No tienes organizaciones activas asignadas.',
                style: TextStyle(color: textS, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de organización ───────────────────────────────────────────────────

class _OrgCard extends ConsumerWidget {
  final MembershipModel membership;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _OrgCard({
    required this.membership,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme  = Theme.of(context);
    final textP  = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border  = theme.colorScheme.outline;

    final orgName = membership.institutionId;

    final roleColor = _roleColor(membership.role);

    return Material(
      color:        surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isActive ? AppColors.brand : border,
              width: isActive ? 1.5 : 0.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color:      AppColors.brand.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset:     const Offset(0, 4),
                    ),
                  ]
                : (isDark ? null : AppShadows.card(false)),
          ),
          child: Row(
            children: [
              // ── Icono de org ─────────────────────────────────────────────
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(
                      alpha: isActive ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.domain_outlined,
                  color: isActive ? AppColors.brand : textS,
                  size:  22,
                ),
              ),
              const SizedBox(width: 14),

              // ── Info ─────────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orgName,
                      style: TextStyle(
                          color:      textP,
                          fontWeight: FontWeight.w700,
                          fontSize:   14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color:        roleColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _roleLabel(membership.role),
                            style: TextStyle(
                                color:      roleColor,
                                fontSize:   10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (membership.isPlanActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              membership.planType.name.toUpperCase(),
                              style: const TextStyle(
                                  color:      AppColors.green,
                                  fontSize:   10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ── Indicador activo / chevron ───────────────────────────────
              if (isActive)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:  AppColors.brand.withValues(alpha: 0.12),
                    shape:  BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      size: 16, color: AppColors.brand),
                )
              else
                Icon(Icons.chevron_right, size: 18, color: textS),
            ],
          ),
        ),
      ),
    );
  }

  Color _roleColor(String role) => switch (role) {
        'SUPER_ADMIN'      => AppColors.amber,
        'ADMIN'            => AppColors.orange,
        'INSTRUCTOR'       => AppColors.accent,
        'USUARIO_SST'      => AppColors.green,
        'USUARIO_PROFESIONAL' => AppColors.cyan,
        _                  => AppColors.brand2,
      };

  String _roleLabel(String role) => switch (role) {
        'SUPER_ADMIN'      => 'Super Admin',
        'ADMIN'            => 'Admin',
        'INSTRUCTOR'       => 'Instructor',
        'USUARIO_SST'      => 'SST',
        'USUARIO_PROFESIONAL' => 'Profesional',
        _                  => 'Usuario',
      };
}
