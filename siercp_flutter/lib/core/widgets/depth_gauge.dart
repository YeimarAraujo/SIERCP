import 'package:flutter/material.dart';
import 'package:siercp/core/theme/theme.dart';

class DepthGauge extends StatelessWidget {
  final double depthMm;

  const DepthGauge({
    super.key,
    required this.depthMm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final depthCm = depthMm / 10;

    const maxCm = 8.0;
    const segments = 20;

    final isInTarget = depthCm >= 5.0 && depthCm <= 6.0;

    final Color accentColor;

    if (isInTarget) {
      accentColor = AppColors.success(isDark);
    } else if (depthCm > 6.0) {
      accentColor = AppColors.danger(isDark);
    } else {
      accentColor = AppColors.warning(isDark);
    }

    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    final secondaryText = theme.textTheme.bodySmall?.color?.withValues(
      alpha: isDark ? 0.5 : 0.7,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    children: List.generate(
                      segments,
                      (index) {
                        final reverseIndex = segments - 1 - index;

                        final val = (reverseIndex + 1) * (maxCm / segments);

                        final isActive = depthCm >= val;

                        final isTargetZone = val >= 5.0 && val <= 6.0;

                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(
                              vertical: 0.5,
                              horizontal: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? accentColor
                                  : isTargetZone
                                      ? AppColors.green.withValues(alpha: 0.12)
                                      : inactiveColor,
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color:
                                            accentColor.withValues(alpha: 0.35),
                                        blurRadius: 4,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        depthCm.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        'CENTIMETROS',
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _TargetStatusBadge(
                        isInTarget: isInTarget,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetStatusBadge extends StatelessWidget {
  final bool isInTarget;

  const _TargetStatusBadge({
    required this.isInTarget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5);

    final color = isInTarget ? AppColors.green : muted;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: (isInTarget ? AppColors.green : muted ?? Colors.grey)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: (isInTarget ? AppColors.green : muted ?? Colors.grey)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        isInTarget ? 'CORRECTO' : 'FUERA DE RANGO',
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
