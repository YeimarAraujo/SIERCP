import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/simulation/data/simulation_service.dart';
import 'package:siercp/l10n/app_localizations.dart';

class SimulationMenuScreen extends ConsumerWidget {
  const SimulationMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final user = ref.watch(currentUserProvider);
    final statsAsync = user != null
        ? ref.watch(userStatsProvider(user.id))
        : const AsyncData<Map<String, dynamic>>({});

    final stats = statsAsync.valueOrNull ?? {};
    final xp = (stats['xp'] as num?)?.toInt() ?? 0;
    final level = (stats['level'] as num?)?.toInt() ?? 1;
    final quizCount = (stats['totalQuizSessions'] as num?)?.toInt() ?? 0;

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
            _XpStrip(xp: xp, level: level, quizCount: quizCount),

            const SizedBox(height: 20),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _MenuCard(
                      icon: Icons.psychology_outlined,
                      title: loc.theoreticalEval,
                      description: loc.theoreticalEvalDesc,
                      color: AppColors.brand,
                      onTap: () => context.push('/simulation/theoretical'),
                    ),
                    const SizedBox(height: 16),
                    _MenuCard(
                      icon: Icons.favorite_outlined,
                      title: loc.practicalEval,
                      description: loc.practicalEvalDesc,
                      color: AppColors.red,
                      onTap: () => context.push('/simulation/practical'),
                    ),
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

class _XpStrip extends StatelessWidget {
  final int xp;
  final int level;
  final int quizCount;

  const _XpStrip({
    required this.xp,
    required this.level,
    required this.quizCount,
  });

  static const _thresholds = [0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5500];

  double get _levelProgress {
    if (level >= _thresholds.length) return 1.0;
    final current = _thresholds[level - 1];
    final next = _thresholds[level];
    if (next == current) return 1.0;
    return ((xp - current) / (next - current)).clamp(0.0, 1.0);
  }

  int get _xpToNextLevel {
    if (level >= _thresholds.length) return 0;
    return _thresholds[level] - xp;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final cardBg = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(color: border, width: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: isDark ? null : AppShadows.card(false),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$level',
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Nivel $level',
                              style: TextStyle(
                                  color: textP,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text('$xp XP',
                              style: const TextStyle(
                                  color: AppColors.brand,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _levelProgress,
                          minHeight: 4,
                          backgroundColor:
                              AppColors.brand.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation(AppColors.brand),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatChip(
                    icon: Icons.quiz_outlined,
                    label: '$quizCount evaluaciones'),
                const SizedBox(width: 12),
                if (_xpToNextLevel > 0)
                  _StatChip(
                      icon: Icons.trending_up_rounded,
                      label: '$_xpToNextLevel XP para nivel ${level + 1}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final textT = Theme.of(context).textTheme.bodySmall?.color ??
        AppColors.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: textT),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: textT, fontSize: 10)),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
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
                  Text(
                    title,
                    style: TextStyle(
                      color: textP,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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
              Icons.chevron_right_rounded,
              color: theme.colorScheme.outline,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
