import 'package:flutter/material.dart';
import '../models/guide.dart';
import '../core/theme.dart';
import 'package:intl/intl.dart';

// ─── GuideListTile ────────────────────────────────────────────────────────────
class GuideListTile extends StatelessWidget {
  final GuideModel guide;
  final GuideProgress? progress;
  final VoidCallback? onTap;
  final bool canManage;

  const GuideListTile({
    super.key,
    required this.guide,
    this.progress,
    this.onTap,
    this.canManage = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final isDark  = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final border  = theme.colorScheme.outline;
    final textP   = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS   = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT   = theme.textTheme.bodySmall?.color  ?? AppColors.textTertiary;

    final isCompleted  = progress?.completed ?? false;
    final isInProgress = !isCompleted && (progress?.timeSpentSeconds ?? 0) > 0;

    // Color según categoría
    final catColor = _catColor(guide.category);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(
            color: isCompleted
                ? AppColors.green.withValues(alpha: 0.3)
                : border.withValues(alpha: 0.5),
            width: isCompleted ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: isDark ? null : AppShadows.card(false),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Ícono de categoría
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    guide.category.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Contenido principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título + badge obligatoria
                    Row(
                      children: [
                        if (guide.required) ...[
                          const Icon(Icons.star_rounded,
                              size: 12, color: AppColors.amber),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            guide.title,
                            style: TextStyle(
                              color: textP,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      guide.description,
                      style: TextStyle(color: textS, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Fila inferior: categoría + tiempo
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            guide.category.label,
                            style: TextStyle(
                              color: catColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.schedule_outlined, size: 10, color: textT),
                        const SizedBox(width: 3),
                        Text(
                          '${guide.estimatedMinutes} min',
                          style: TextStyle(color: textT, fontSize: 10),
                        ),
                        if (isCompleted && progress?.completedAt != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle,
                              size: 10, color: AppColors.green),
                          const SizedBox(width: 3),
                          Text(
                            DateFormat('dd/MM/yy').format(progress!.completedAt!),
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Estado visual
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatusIcon(
                    completed: isCompleted,
                    inProgress: isInProgress,
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right_rounded, size: 16, color: textT),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _catColor(GuideCategory cat) {
    switch (cat) {
      case GuideCategory.tecnica:      return AppColors.brand;
      case GuideCategory.teoria:       return const Color(0xFF8B5CF6);
      case GuideCategory.seguridad:    return AppColors.green;
      case GuideCategory.emergencias:  return AppColors.red;
      case GuideCategory.equipamiento: return AppColors.amber;
    }
  }
}

// ─── Status Icon ──────────────────────────────────────────────────────────────
class _StatusIcon extends StatelessWidget {
  final bool completed;
  final bool inProgress;
  const _StatusIcon({required this.completed, required this.inProgress});

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return const Icon(Icons.check_circle_rounded,
          size: 22, color: AppColors.green);
    }
    if (inProgress) {
      return const Icon(Icons.menu_book_rounded,
          size: 22, color: AppColors.amber);
    }
    return Icon(Icons.radio_button_unchecked_rounded,
        size: 22, color: Theme.of(context).colorScheme.outline);
  }
}
