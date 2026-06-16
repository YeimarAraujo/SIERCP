import 'package:flutter/material.dart';
import 'package:siercp/core/widgets/app_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/user_skill.dart';
import '../providers/skill_providers.dart';

const _kAppUrl = 'https://siercp.com';

/// Skill Wallet — competencias verificadas del usuario (S2/S3).
/// Solo lectura: las skills las otorga el Competency Engine (Cloud Functions).
class SkillWalletScreen extends ConsumerWidget {
  const SkillWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(userSkillsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Skill Passport')),
      body: skillsAsync.when(
        loading: () => const AppLogoLoader(),
        error: (e, _) => Center(child: Text('Error al cargar skills: $e')),
        data: (skills) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _PassportHeader(),
            const SizedBox(height: 12),
            const _QuickLinks(),
            const SizedBox(height: 16),
            if (skills.isEmpty)
              const _EmptyState()
            else
              ...skills.expand((s) => [_SkillCard(skill: s), const SizedBox(height: 12)]),
          ],
        ),
      ),
    );
  }
}

/// Accesos rápidos a Insignias, Rutas y Ranking.
class _QuickLinks extends StatelessWidget {
  const _QuickLinks();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LinkChip(icon: Icons.workspace_premium_outlined, label: 'Insignias', onTap: () => context.go('/badges')),
        const SizedBox(width: 8),
        _LinkChip(icon: Icons.route_outlined, label: 'Rutas', onTap: () => context.go('/learning-paths')),
        const SizedBox(width: 8),
        _LinkChip(icon: Icons.leaderboard_outlined, label: 'Ranking', onTap: () => context.go('/ranking')),
      ],
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
      ),
    );
  }
}

/// Header con control opt-in del perfil público y botón de compartir.
class _PassportHeader extends ConsumerStatefulWidget {
  const _PassportHeader();
  @override
  ConsumerState<_PassportHeader> createState() => _PassportHeaderState();
}

class _PassportHeaderState extends ConsumerState<_PassportHeader> {
  bool _busy = false;

  Future<void> _toggle(bool enabled) async {
    setState(() => _busy = true);
    try {
      await ref.read(skillServiceProvider).setPublicProfile(enabled);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el perfil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(publicProfileProvider);
    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (p) {
        final url = p.slug.isEmpty ? null : '$_kAppUrl/u/${p.slug}';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Perfil público',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    if (_busy)
                      const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Switch(value: p.enabled, onChanged: _toggle),
                  ],
                ),
                Text(
                  p.enabled
                      ? 'Tu Skill Passport es visible públicamente.'
                      : 'Actívalo para compartir tus competencias verificadas.',
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                ),
                if (p.enabled && url != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(url,
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, size: 20),
                        onPressed: () => Share.share(
                          'Mira mis competencias verificadas en SIERCP: $url',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill});
  final UserSkill skill;

  Color _levelColor(BuildContext ctx) => switch (skill.levelOrder) {
        >= 4 => const Color(0xFF14B8A6),
        3 => const Color(0xFF22C55E),
        2 => const Color(0xFFF59E0B),
        _ => Theme.of(ctx).colorScheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _levelColor(context).withValues(alpha: 0.15),
              child: Icon(Icons.verified, color: _levelColor(context)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(skill.skillName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('Nivel ${skill.levelLabel} · ${skill.issuedByName}',
                      style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(skill.skillCode,
                      style: TextStyle(
                          fontFeatures: const [],
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Theme.of(context).hintColor)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _levelColor(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${skill.bestScore.round()}',
                  style: TextStyle(color: _levelColor(context), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.workspace_premium_outlined,
                size: 64, color: Theme.of(context).hintColor),
            const SizedBox(height: 16),
            const Text('Aún no tienes competencias verificadas',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Completa sesiones de entrenamiento para obtener skills respaldadas por tu desempeño real.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }
}
