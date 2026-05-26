import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/simulation/data/simulation_service.dart';

/// Barra compacta de XP y nivel del usuario.
/// Lee de userStats/{userId} vía [userStatsProvider].
class XpStrip extends ConsumerWidget {
  final bool compact;
  const XpStrip({super.key, this.compact = false});

  static const _thresholds = [0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5500];

  static double levelProgress(int xp, int level) {
    if (level >= _thresholds.length) return 1.0;
    final current = _thresholds[level - 1];
    final next = _thresholds[level];
    if (next == current) return 1.0;
    return ((xp - current) / (next - current)).clamp(0.0, 1.0);
  }

  static int xpToNext(int xp, int level) {
    if (level >= _thresholds.length) return 0;
    return _thresholds[level] - xp;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final statsAsync = user != null
        ? ref.watch(userStatsProvider(user.id))
        : const AsyncData<Map<String, dynamic>>({});

    final stats = statsAsync.valueOrNull ?? {};
    final xp = (stats['xp'] as num?)?.toInt() ?? 0;
    final level = (stats['level'] as num?)?.toInt() ?? 1;
    final quizCount = (stats['totalQuizSessions'] as num?)?.toInt() ?? 0;
    final progress = levelProgress(xp, level);
    final toNext = xpToNext(xp, level);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textT = theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final cardBg = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
          : const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: Row(
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
                    value: progress,
                    minHeight: 4,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.brand),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.quiz_outlined,
                          size: 11, color: textT),
                      const SizedBox(width: 3),
                      Text('$quizCount evaluaciones',
                          style: TextStyle(color: textT, fontSize: 10)),
                      if (toNext > 0) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.trending_up_rounded,
                            size: 11, color: textT),
                        const SizedBox(width: 3),
                        Text('$toNext XP para nivel ${level + 1}',
                            style: TextStyle(color: textT, fontSize: 10)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
