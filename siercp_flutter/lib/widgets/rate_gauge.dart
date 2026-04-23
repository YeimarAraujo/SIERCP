import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../core/theme.dart';
import '../core/constants.dart';

class RateGauge extends StatelessWidget {
  final int ratePerMin;
  const RateGauge({super.key, required this.ratePerMin});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOk = ratePerMin >= AppConstants.ahaMinRatePerMin && ratePerMin <= AppConstants.ahaMaxRatePerMin;
    final color = ratePerMin == 0 
        ? AppColors.textTertiary 
        : (isOk ? const Color(0xFF00E5FF) : const Color(0xFFFFB300));

    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 160,
          startAngle: 180,
          endAngle: 0,
          canScaleToFit: true,
          showLabels: false,
          showTicks: false,
          radiusFactor: 1.0,
          axisLineStyle: AxisLineStyle(
            thickness: 0.15,
            thicknessUnit: GaugeSizeUnit.factor,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          pointers: <GaugePointer>[
            RangePointer(
              value: ratePerMin.toDouble(),
              width: 0.15,
              sizeUnit: GaugeSizeUnit.factor,
              color: color,
              cornerStyle: CornerStyle.bothCurve,
            ),
            MarkerPointer(
              value: ratePerMin.toDouble(),
              markerHeight: 12,
              markerWidth: 12,
              markerType: MarkerType.circle,
              color: Colors.white,
              borderWidth: 2,
              borderColor: color,
            ),
          ],
          ranges: [
            GaugeRange(
              startValue: AppConstants.ahaMinRatePerMin.toDouble(),
              endValue: AppConstants.ahaMaxRatePerMin.toDouble(),
              color: AppColors.green.withValues(alpha: 0.3),
              startWidth: 0.15,
              endWidth: 0.15,
              sizeUnit: GaugeSizeUnit.factor,
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              angle: 90,
              positionFactor: 0.1,
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ratePerMin.toString(),
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontFamily: 'SpaceMono',
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'cpm',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontFamily: 'SpaceMono',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

