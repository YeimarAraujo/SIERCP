import 'package:flutter/material.dart';
import 'package:siercp/core/widgets/app_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/learning_path.dart';
import '../providers/skill_providers.dart';

/// Rutas de aprendizaje (S4): progreso por skills obtenidas y desbloqueos.
class LearningPathsScreen extends ConsumerWidget {
  const LearningPathsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(learningPathsProvider);
    final owned = ref.watch(ownedSkillIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rutas de aprendizaje')),
      body: pathsAsync.when(
        loading: () => const AppLogoLoader(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (paths) {
          if (paths.isEmpty) {
            return const Center(child: Text('Aún no hay rutas de aprendizaje.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: paths.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _PathCard(path: paths[i], owned: owned),
          );
        },
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
    const teal = Color(0xFF14B8A6);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(path.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                if (complete)
                  const Icon(Icons.check_circle, color: teal, size: 22),
              ],
            ),
            if (path.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(path.description,
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: const AlwaysStoppedAnimation(teal),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('$done / ${path.skillIds.length} skills',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                const Spacer(),
                if (path.estimatedHours > 0)
                  Text('${path.estimatedHours} h · ${path.level}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
