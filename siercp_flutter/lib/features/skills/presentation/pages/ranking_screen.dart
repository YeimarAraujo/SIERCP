import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/widgets/app_logo.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/skill_providers.dart';

/// Ranking institucional (S4): reusa la proyección de leaderboards.
class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(institutionRankingProvider);
    final myUid = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Ranking')),
      body: rankingAsync.when(
        loading: () => const AppLogoLoader(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('Sin datos de ranking todavía.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i];
              final isMe = e.uid == myUid;
              final medal = switch (i) { 0 => '🥇', 1 => '🥈', 2 => '🥉', _ => '${i + 1}' };
              return Card(
                color: isMe ? const Color(0x1A14B8A6) : null,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: SizedBox(
                    width: 32,
                    child: Center(
                        child: Text(medal, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  ),
                  title: Text(e.displayName,
                      style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.w500)),
                  subtitle: Text('${e.skillsCount} skills'),
                  trailing: Text('${e.averageScore.round()}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF14B8A6))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
