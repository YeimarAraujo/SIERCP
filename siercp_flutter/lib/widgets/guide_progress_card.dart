import 'package:flutter/material.dart';
import '../models/guide.dart';
import '../core/theme.dart';

// ─── GuideProgressCard ────────────────────────────────────────────────────────
class GuideProgressCard extends StatelessWidget {
  final GuideProgressSummary summary;
  const GuideProgressCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final isDark   = theme.brightness == Brightness.dark;
    final textP    = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS    = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final allDone  = summary.allRequiredDone;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: allDone
            ? const LinearGradient(
                colors: [Color(0xFF00C853), Color(0xFF00E676)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1A2A3A), const Color(0xFF152536)]
                    : [const Color(0xFFE8F4FF), const Color(0xFFD0E8FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: allDone
              ? Colors.transparent
              : AppColors.brand.withValues(alpha: 0.2),
        ),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ícono animado
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: allDone
                      ? Colors.white.withValues(alpha: 0.3)
                      : AppColors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  allDone ? Icons.auto_awesome : Icons.menu_book_outlined,
                  color: allDone ? Colors.white : AppColors.brand,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allDone
                          ? '¡Guías obligatorias completadas! 🎉'
                          : 'Progreso de guías',
                      style: TextStyle(
                        color: allDone ? Colors.white : textP,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.completedGuides}/${summary.totalGuides} leídas',
                      style: TextStyle(
                        color: allDone
                            ? Colors.white.withValues(alpha: 0.85)
                            : textS,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge de obligatorias
              if (summary.requiredGuides > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: allDone
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppColors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${summary.requiredCompleted}/${summary.requiredGuides} obligatorias',
                    style: TextStyle(
                      color: allDone ? Colors.white : AppColors.brand,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Barra de progreso general
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: summary.completionPct,
              backgroundColor: allDone
                  ? Colors.white.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(
                allDone ? Colors.white : AppColors.brand,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(summary.completionPct * 100).round()}% completado',
                style: TextStyle(
                  color: allDone
                      ? Colors.white.withValues(alpha: 0.85)
                      : textS,
                  fontSize: 11,
                ),
              ),
              if (!allDone && summary.requiredGuides > 0)
                Text(
                  '${summary.requiredGuides - summary.requiredCompleted} obligatorias pendientes',
                  style: TextStyle(
                    color: AppColors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
