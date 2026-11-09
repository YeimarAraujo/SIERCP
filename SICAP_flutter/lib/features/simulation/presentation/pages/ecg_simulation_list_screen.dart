import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/simulation/data/ecg_scenarios_data.dart';
import 'package:siercp/features/simulation/data/models/ecg_scenario.dart';

/// Lista de escenarios de ECG simulado, agrupados por categoría clínica. Lee del
/// [EcgScenarioRepository], por lo que añadir escenarios al catálogo los muestra
/// aquí automáticamente sin tocar esta pantalla.
class EcgSimulationListScreen extends StatelessWidget {
  const EcgSimulationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final grouped = const EcgScenarioRepository().grouped();
    final total = kEcgScenarios.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: textP),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'ECG Simulado',
                              style: TextStyle(
                                color: textP,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$total escenarios clínicos · monitor en tiempo real',
                          style: TextStyle(color: textS, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  for (final entry in grouped.entries) ...[
                    _CategoryHeader(
                        title: entry.key, count: entry.value.length),
                    const SizedBox(height: 10),
                    for (final s in entry.value) ...[
                      _ScenarioCard(scenario: s),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 12),
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

class _CategoryHeader extends StatelessWidget {
  final String title;
  final int count;
  const _CategoryHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: textS,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 0.5,
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: TextStyle(color: textS.withValues(alpha: 0.6), fontSize: 11),
        ),
      ],
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final EcgScenario scenario;
  const _ScenarioCard({required this.scenario});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final color = scenario.accent;

    return GestureDetector(
      onTap: () => context.push('/simulation/ecg/${scenario.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline, width: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: isDark ? null : AppShadows.card(false),
        ),
        child: Row(
          children: [
            // Mini-pictograma de onda.
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: CustomPaint(
                painter: _MiniWavePainter(color),
                size: const Size(52, 52),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scenario.name,
                    style: TextStyle(
                      color: textP,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    scenario.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textS, fontSize: 11, height: 1.3),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      _pill(
                        Icons.favorite_rounded,
                        '${scenario.hrText} lpm',
                        scenario.alarm.color,
                      ),
                      const SizedBox(width: 6),
                      _pill(
                        Icons.shield_moon_outlined,
                        scenario.alarm.label,
                        scenario.alarm.color,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: theme.colorScheme.outline, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pequeño trazo de ECG decorativo dentro del avatar de cada tarjeta.
class _MiniWavePainter extends CustomPainter {
  final Color color;
  _MiniWavePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final p = Path();
    final midY = size.height * 0.55;
    final w = size.width;
    p.moveTo(w * 0.08, midY);
    p.lineTo(w * 0.34, midY);
    p.lineTo(w * 0.40, midY + size.height * 0.10); // Q
    p.lineTo(w * 0.46, midY - size.height * 0.34); // R
    p.lineTo(w * 0.52, midY + size.height * 0.18); // S
    p.lineTo(w * 0.58, midY);
    p.lineTo(w * 0.70, midY);
    p.quadraticBezierTo(
        w * 0.78, midY - size.height * 0.14, w * 0.86, midY); // T
    p.lineTo(w * 0.92, midY);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniWavePainter old) => old.color != color;
}
