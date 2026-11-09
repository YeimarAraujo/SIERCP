import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:siercp/core/theme/theme.dart';

class RateGauge extends StatelessWidget {
  final int ratePerMin;

  const RateGauge({
    super.key,
    required this.ratePerMin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isOk = ratePerMin >= 100 && ratePerMin <= 120;

    final accentColor =
        isOk ? AppColors.success(isDark) : AppColors.warning(isDark);

    final mutedColor = isDark ? Colors.white : Colors.black;

    final gaugeLineColor = mutedColor.withValues(alpha: isDark ? 0.08 : 0.12);

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
          const SizedBox(height: 8),
          Expanded(
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: 0,
                  maximum: 180,
                  startAngle: 150,
                  endAngle: 30,
                  showLabels: false,
                  showTicks: true,
                  tickOffset: 5,
                  majorTickStyle: MajorTickStyle(
                    length: 10,
                    thickness: 1.5,
                    color: gaugeLineColor,
                  ),
                  minorTickStyle: MinorTickStyle(
                    length: 5,
                    thickness: 1,
                    color: gaugeLineColor,
                  ),
                  axisLineStyle: AxisLineStyle(
                    thickness: 12,
                    color: gaugeLineColor,
                  ),
                  ranges: <GaugeRange>[
                    GaugeRange(
                      startValue: 100,
                      endValue: 120,
                      color: AppColors.green.withValues(
                        alpha: isDark ? 0.25 : 0.18,
                      ),
                      startWidth: 12,
                      endWidth: 12,
                    ),
                  ],
                  pointers: <GaugePointer>[
                    NeedlePointer(
                      value: ratePerMin.toDouble(),
                      needleLength: 0.6,
                      needleStartWidth: 1,
                      needleEndWidth: 4,
                      needleColor: accentColor,
                      knobStyle: KnobStyle(
                        knobRadius: 0.08,
                        color: accentColor,
                      ),
                      enableAnimation: true,
                      animationType: AnimationType.easeOutBack,
                    ),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      angle: 90,
                      positionFactor: 0.5,
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ratePerMin.toString(),
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              letterSpacing: -2,
                            ),
                          ),
                          Text(
                            'CPM',
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _RateStatusIndicator(isOk: isOk),
        ],
      ),
    );
  }
}

class _RateStatusIndicator extends StatelessWidget {
  final bool isOk;

  const _RateStatusIndicator({
    required this.isOk,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isOk ? Icons.check_circle : Icons.speed,
          color: isOk ? AppColors.green : muted,
          size: 10,
        ),
        const SizedBox(width: 4),
        Text(
          isOk ? 'RITMO OK' : 'IDEAL: 100-120',
          style: TextStyle(
            color: isOk ? AppColors.green : muted,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
