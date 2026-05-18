import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/simulation/data/models/quiz_topic.dart';
import 'package:siercp/features/simulation/data/simulation_service.dart';
import 'package:siercp/l10n/app_localizations.dart';

class TheoreticalHubScreen extends ConsumerWidget {
  const TheoreticalHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final topicsAsync = ref.watch(quizTopicsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: theme.textTheme.bodyLarge?.color),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.quizTopicsTitle,
                          style: TextStyle(
                              color: textP,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Text(loc.quizTopicsSubtitle,
                          style: TextStyle(color: textS, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: topicsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 40, color: AppColors.textTertiary),
                      const SizedBox(height: 12),
                      Text(loc.quizErrorLoad,
                          style: TextStyle(color: textS, fontSize: 13),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(quizTopicsProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                data: (topics) => topics.isEmpty
                    ? _EmptyTopics(loc: loc)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: topics.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _TopicCard(
                          topic: topics[i],
                          onTap: () => context.push(
                            '/simulation/theoretical/quiz/${topics[i].id}',
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTopics extends StatelessWidget {
  final AppLocalizations loc;
  const _EmptyTopics({required this.loc});

  @override
  Widget build(BuildContext context) {
    final textS =
        Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.psychology_outlined,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text('No hay temas disponibles aún.',
              style: TextStyle(color: textS, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final QuizTopic topic;
  final VoidCallback onTap;

  const _TopicCard({
    required this.topic,
    required this.onTap,
  });

  // Topics with requiresPlan show a badge but are not locked client-side;
  // the Cloud Function enforces plan access when questions are requested.
  bool get _isLocked => false;

  Color get _categoryColor {
    switch (topic.category.toLowerCase()) {
      case 'rcp':
        return AppColors.red;
      case 'trauma':
        return AppColors.amber;
      case 'ecg':
        return AppColors.brand;
      case 'pediatrico':
        return AppColors.accent;
      default:
        return AppColors.cyan;
    }
  }

  IconData get _categoryIcon {
    switch (topic.category.toLowerCase()) {
      case 'rcp':
        return Icons.favorite_outlined;
      case 'trauma':
        return Icons.healing_outlined;
      case 'ecg':
        return Icons.monitor_heart_outlined;
      case 'pediatrico':
        return Icons.child_care_outlined;
      default:
        return Icons.medical_services_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT = theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final cardBg = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;
    final locked = _isLocked;
    final color = _categoryColor;
    final durationMin = (topic.durationSeconds / 60).ceil();

    return GestureDetector(
      onTap: locked
          ? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                  loc.quizPlanRequired(topic.requiresPlan ?? ''),
                  style: TextStyle(
                      color: theme.colorScheme.onInverseSurface),
                ),
                backgroundColor: theme.colorScheme.inverseSurface,
              ))
          : onTap,
      child: Opacity(
        opacity: locked ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: isDark ? null : AppShadows.card(false),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: locked
                    ? Icon(Icons.lock_outline_rounded,
                        color: textT, size: 22)
                    : Icon(_categoryIcon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            topic.title,
                            style: TextStyle(
                              color: textP,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (locked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              topic.requiresPlan?.toUpperCase() ?? '',
                              style: const TextStyle(
                                color: AppColors.amber,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      topic.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textS, fontSize: 10),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.quiz_outlined,
                          label: '${topic.questionCount} preguntas',
                          color: textT,
                        ),
                        const SizedBox(width: 12),
                        _InfoChip(
                          icon: Icons.timer_outlined,
                          label: '${durationMin} min',
                          color: textT,
                        ),
                        const Spacer(),
                        Text(
                          topic.category.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!locked)
                Icon(Icons.chevron_right_rounded, size: 20, color: textT),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      );
}
