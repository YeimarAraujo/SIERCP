import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/widgets/app_logo.dart';
import 'package:siercp/core/theme/theme.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/skill_providers.dart';

/// Ranking institucional (S4): reusa la proyección de leaderboards.
class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(institutionRankingProvider);
    final myUid = ref.watch(currentUserProvider)?.id;
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

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
                  Text('Ranking',
                      style: TextStyle(
                          color: textP,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: rankingAsync.when(
                loading: () => const AppLogoLoader(),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (entries) {
                  if (entries.isEmpty) {
                    return const Center(
                        child: Text('Sin datos de ranking todavía.'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      final isMe = e.uid == myUid;
                      final medalIcon = switch (i) {
                        0 => Icons.emoji_events_rounded,
                        1 => Icons.workspace_premium_rounded,
                        2 => Icons.military_tech_rounded,
                        _ => null,
                      };
                      final medalColor = switch (i) {
                        0 => const Color(0xFFF59E0B),
                        1 => const Color(0xFF9CA3AF),
                        2 => const Color(0xFFCD7F32),
                        _ => textP,
                      };

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.accent.withValues(alpha: 0.08)
                              : surface,
                          border: Border.all(
                              color: isMe
                                  ? AppColors.accent.withValues(alpha: 0.2)
                                  : border,
                              width: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Center(
                                  child: medalIcon != null
                                      ? Icon(medalIcon,
                                          color: medalColor, size: 22)
                                      : Text('${i + 1}',
                                          style: TextStyle(
                                              color: textP,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(e.displayName,
                                        style: TextStyle(
                                            fontWeight: isMe
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: textP,
                                            fontSize: 14)),
                                    Text('${e.skillsCount} skills',
                                        style: TextStyle(
                                            color: theme
                                                .textTheme.bodyMedium?.color,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text('${e.averageScore.round()}',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accent)),
                            ],
                          ),
                        ),
                      );
                    },
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
