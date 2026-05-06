import 'package:flutter/material.dart';
import 'package:siercp/core/theme/theme.dart';

class DepthGauge extends StatelessWidget {
  final double depthMm;
  const DepthGauge({super.key, required this.depthMm});

  @override
  Widget build(BuildContext context) {
    final depthCm = depthMm / 10;
    const maxCm = 8.0;
    const segments = 20; // Más segmentos para mayor fluidez
    
    final isInTarget = depthCm >= 5.0 && depthCm <= 6.0;
    final accentColor = isInTarget ? AppColors.green : const Color(0xFFFF8A00);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          const Text(
            'DEPTH PRECISION',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                // Digital Vertical Meter
                Expanded(
                  flex: 1,
                  child: Column(
                    children: List.generate(segments, (index) {
                      final reverseIndex = segments - 1 - index;
                      final val = (reverseIndex + 1) * (maxCm / segments);
                      final isActive = depthCm >= val;
                      final isTargetZone = val >= 5.0 && val <= 6.0;

                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(vertical: 0.5, horizontal: 2),
                          decoration: BoxDecoration(
                            color: isActive 
                                ? accentColor 
                                : (isTargetZone ? AppColors.green.withValues(alpha: 0.1) : Colors.white10),
                            borderRadius: BorderRadius.circular(1),
                            boxShadow: isActive ? [BoxShadow(color: accentColor.withValues(alpha: 0.4), blurRadius: 4)] : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                // Numeric Display
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      const Text(
                        'CENTIMETERS',
                        style: TextStyle(color: Colors.white24, fontSize: 7, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _TargetStatusBadge(isInTarget: isInTarget),
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
  const _TargetStatusBadge({required this.isInTarget});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isInTarget ? AppColors.green : Colors.white10).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: (isInTarget ? AppColors.green : Colors.white24).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        isInTarget ? 'OPTIMAL' : 'ADJUST',
        style: TextStyle(
          color: isInTarget ? AppColors.green : Colors.white38,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

