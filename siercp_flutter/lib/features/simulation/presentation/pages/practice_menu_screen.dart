import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/core/widgets/xp_strip.dart';
import 'package:siercp/l10n/app_localizations.dart';

class PracticeMenuScreen extends ConsumerWidget {
  const PracticeMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.simulationTitle,
                    style: TextStyle(
                      color: textP,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc.simulationSubtitle,
                    style: TextStyle(color: textS, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // XP / level strip
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: XpStrip(),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Evaluaciones Prácticas ───────────────────────────
                    const _SectionHeader(
                      title: 'Evaluaciones Prácticas',
                    ),
                    const SizedBox(height: 12),
                    _MenuCard(
                      icon: Icons.cases_outlined,
                      title: 'Evaluaciones teóricas',
                      description:
                          'Casos clínicos AHA: RCP, DEA, OVACE, ahogamiento, anafilaxia y más.',
                      color: AppColors.accent,
                      onTap: () =>
                          context.push('/simulation/theoretical/cases'),
                    ),
                    const SizedBox(height: 16),
                    _MenuCard(
                      icon: Icons.favorite_outlined,
                      title: loc.practicalEval,
                      description: loc.practicalEvalDesc,
                      color: AppColors.red,
                      onTap: () => context.push('/simulation/practical'),
                    ),
                    const SizedBox(height: 16),

                    // ── Simulaciones ─────────────────────────────────────
                    const _SectionHeader(
                      title: 'Simulaciones',
                    ),
                    const SizedBox(height: 12),
                    _MenuCard(
                      icon: Icons.electric_bolt_outlined,
                      title: 'Electrocardiograma (ECG) Simulado',
                      description:
                          'Escenarios clínicos en un monitor multiparámetro en tiempo real.',
                      color: AppColors.green,
                      onTap: () => context.push('/simulation/ecg'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encabezado de sección (Evaluaciones Prácticas / Simulaciones).
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;

    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: textP,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// Mensaje informativo para opciones aún no disponibles (ECG evaluación).

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  /// Si es true, la tarjeta se atenúa y muestra un distintivo "Próximamente".
  final bool comingSoon;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final cardBg = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: comingSoon ? 0.72 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: isDark ? null : AppShadows.card(false),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: textP,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(color: textS, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                comingSoon
                    ? Icons.lock_clock_outlined
                    : Icons.chevron_right_rounded,
                color: theme.colorScheme.outline,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
