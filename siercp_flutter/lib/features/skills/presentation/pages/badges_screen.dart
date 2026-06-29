import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/widgets/app_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/theme/theme.dart';

import '../../data/models/badge.dart';
import '../providers/skill_providers.dart';

/// Insignias (S4): obtenidas a color, bloqueadas con progreso visual.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(badgesViewProvider);
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
                  Text('Insignias',
                      style: TextStyle(
                          color: textP,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: view.when(
                loading: () => const AppLogoLoader(),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (data) {
                  if (data.earned.isEmpty && data.locked.isEmpty) {
                    return const Center(
                        child: Text('Aún no hay insignias disponibles.'));
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (data.earned.isNotEmpty) ...[
                        _SectionTitle('Obtenidas (${data.earned.length})'),
                        ...data.earned.map((b) =>
                            _BadgeTile(badge: b, owned: owned, earned: true)),
                        const SizedBox(height: 20),
                      ],
                      if (data.locked.isNotEmpty) ...[
                        _SectionTitle('Por desbloquear (${data.locked.length})'),
                        ...data.locked.map((b) =>
                            _BadgeTile(badge: b, owned: owned, earned: false)),
                      ],
                    ],
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Theme.of(context).hintColor)),
      );
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile(
      {required this.badge, required this.owned, required this.earned});
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _tierColor().withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                badge.tier == 'GOLD'
                    ? Icons.workspace_premium_rounded
                    : badge.tier == 'SILVER'
                        ? Icons.shield_rounded
                        : Icons.military_tech_rounded,
                color: _tierColor(),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(badge.name,
                        style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  Text(
                      '${badge.description} · ${(progress * 100).round()}%',
                      style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 11)),
                ],
              ),
            ),
            if (!earned)
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                  valueColor:
                      AlwaysStoppedAnimation(_tierColor()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
