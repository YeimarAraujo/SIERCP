import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/widgets/app_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/theme/theme.dart';

import '../../data/models/learning_path.dart';
import '../providers/skill_providers.dart';

/// Rutas de aprendizaje (S4): progreso por skills obtenidas y desbloqueos.
class LearningPathsScreen extends ConsumerWidget {
  const LearningPathsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(learningPathsProvider);
    final owned = ref.watch(ownedSkillIdsProvider);
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/skills'),
                  ),
                  const SizedBox(width: 4),
                  Text('Rutas de aprendizaje',
                      style: TextStyle(
                          color: textP,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: pathsAsync.when(
                loading: () => const AppLogoLoader(),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (paths) {
                  if (paths.isEmpty) {
                    return const Center(
                        child: Text('Aún no hay rutas de aprendizaje.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: paths.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _PathCard(path: paths[i], owned: owned),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({required this.path, required this.owned});
  final LearningPath path;
  final Set<String> owned;

  @override
  Widget build(BuildContext context) {
    final progress = path.progress(owned);
    final complete = path.isComplete(owned);
    final done = path.skillIds.where(owned.contains).length;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(path.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                if (complete)
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.accent, size: 22),
              ],
            ),
            if (path.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(path.description,
                  style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 13)),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    isDark ? AppColors.darkBorder : AppColors.lightBorder,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('$done / ${path.skillIds.length} skills',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color)),
                const Spacer(),
                if (path.estimatedHours > 0)
                  Text('${path.estimatedHours} h · ${path.level}',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
