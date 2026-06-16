import 'package:flutter/material.dart';
import 'package:siercp/core/widgets/app_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/badge.dart';
import '../providers/skill_providers.dart';

/// Insignias (S4): obtenidas a color, bloqueadas con progreso visual.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(badgesViewProvider);
    final owned = ref.watch(ownedSkillIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Insignias')),
      body: view.when(
        loading: () => const AppLogoLoader(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data.earned.isEmpty && data.locked.isEmpty) {
            return const Center(child: Text('Aún no hay insignias disponibles.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (data.earned.isNotEmpty) ...[
                _SectionTitle('Obtenidas (${data.earned.length})'),
                ...data.earned.map((b) => _BadgeTile(badge: b, owned: owned, earned: true)),
                const SizedBox(height: 20),
              ],
              if (data.locked.isNotEmpty) ...[
                _SectionTitle('Por desbloquear (${data.locked.length})'),
                ...data.locked.map((b) => _BadgeTile(badge: b, owned: owned, earned: false)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                color: Theme.of(context).hintColor)),
      );
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.owned, required this.earned});
  final BadgeModel badge;
  final Set<String> owned;
  final bool earned;

  Color _tierColor() => switch (badge.tier) {
        'GOLD' => const Color(0xFFF59E0B),
        'SILVER' => const Color(0xFF9CA3AF),
        _ => const Color(0xFFB45309),
      };

  @override
  Widget build(BuildContext context) {
    final progress = badge.progress(owned);
    final color = earned ? _tierColor() : Theme.of(context).disabledColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: earned ? 0.18 : 0.10),
              child: Icon(earned ? Icons.workspace_premium : Icons.lock_outline, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(badge.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: earned ? null : Theme.of(context).hintColor)),
                  const SizedBox(height: 2),
                  Text(badge.description,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (!earned) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Theme.of(context).dividerColor,
                        valueColor: AlwaysStoppedAnimation(_tierColor()),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${(progress * 100).round()}%',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
