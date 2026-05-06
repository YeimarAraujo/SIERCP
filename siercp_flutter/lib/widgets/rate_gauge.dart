import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../core/theme.dart';

class RateGauge extends StatelessWidget {
  final int ratePerMin;
  const RateGauge({super.key, required this.ratePerMin});

  @override
  Widget build(BuildContext context) {
    final isOk = ratePerMin >= 100 && ratePerMin <= 120;
    final accentColor = isOk ? AppColors.green : const Color(0xFF00D4FF);

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
            'RHYTHM CADENCE',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
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
                  majorTickStyle: const MajorTickStyle(length: 10, thickness: 1.5, color: Colors.white10),
                  minorTickStyle: const MinorTickStyle(length: 5, thickness: 1, color: Colors.white10),
                  axisLineStyle: const AxisLineStyle(
                    thickness: 12,
                    color: Colors.white10,
                  ),
                  ranges: <GaugeRange>[
                    // Zona Ideal AHA
                    GaugeRange(
                      startValue: 100,
                      endValue: 120,
                      color: AppColors.green.withValues(alpha: 0.3),
                      startWidth: 12,
                      endWidth: 12,
                    ),
                  ],
                  pointers: <GaugePointer>[
                    // Aguja digital
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
                          const Text(
                            'CPM',
                            style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold),
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
  const _RateStatusIndicator({required this.isOk});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isOk ? Icons.check_circle : Icons.speed,
          color: isOk ? AppColors.green : Colors.white24,
          size: 10,
        ),
        const SizedBox(width: 4),
        Text(
          isOk ? 'RHYTHM OK' : 'IDEAL: 100-120',
          style: TextStyle(
            color: isOk ? AppColors.green : Colors.white38,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

