import 'package:flutter/material.dart';
import 'package:siercp/core/theme/theme.dart';
 
class EvaluacionResultadoDialog extends StatelessWidget {
  /// Puntaje 0–100.
  final double score;
 
  /// XP ganado (viene de [QuizSessionResult.xpEarned]).
  final int xpEarned;
 
  /// Si hubo subida de nivel, viene de [QuizSessionResult.newLevel].
  final int? newLevel;
 
  /// Callback al presionar "Aceptar" (después de que el diálogo se cierra).
  final VoidCallback? onAceptar;
 
  const EvaluacionResultadoDialog({
    super.key,
    required this.score,
    required this.xpEarned,
    this.newLevel,
    this.onAceptar,
  });
 
  bool get _passed => score >= 70;
 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
 
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.brand.withValues(alpha: isDark ? 0.4 : 0.2),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Ícono ──────────────────────────────────────────────────────
            Text(
              _passed ? '🏆' : '💪',
              style: const TextStyle(fontSize: 52),
            ),
            const SizedBox(height: 16),
 
            // ── Mensaje principal ──────────────────────────────────────────
            Text(
              _passed
                  ? '¡Felicitaciones!'
                  : 'Vaya, qué cerca…\n¡más esfuerzo la próxima vez!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${score.toStringAsFixed(0)}%',
              style: TextStyle(
                color: _passed ? AppColors.green : AppColors.red,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
 
            const SizedBox(height: 16),
            Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
 
            // ── XP ganado ──────────────────────────────────────────────────
            if (xpEarned > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: AppColors.amber, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '+$xpEarned XP',
                    style: const TextStyle(
                      color: AppColors.amber,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ] else ...[
              Text(
                'Necesitas ≥70% para ganar XP',
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
            ],
 
            // ── Level-up badge ─────────────────────────────────────────────
            if (newLevel != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '🎉 ¡Subiste al Nivel $newLevel!',
                  style: const TextStyle(
                    color: AppColors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
 
            // ── Botón ──────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onAceptar?.call();
                },
                child: const Text(
                  'Aceptar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}