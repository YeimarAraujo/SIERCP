import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../core/theme.dart';
import '../core/constants.dart';

class DepthGauge extends StatelessWidget {
  final double depthMm;
  const DepthGauge({super.key, required this.depthMm});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOk = depthMm >= AppConstants.ahaMinDepthMm && depthMm <= AppConstants.ahaMaxDepthMm;
    final color = depthMm == 0 
        ? AppColors.textTertiary 
        : (isOk ? const Color(0xFF00FF41) : const Color(0xFFFF3131));

    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 80,
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
              value: depthMm,
              width: 0.15,
              sizeUnit: GaugeSizeUnit.factor,
              color: color,
              cornerStyle: CornerStyle.bothCurve,
            ),
            MarkerPointer(
              value: depthMm,
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
              startValue: AppConstants.ahaMinDepthMm,
              endValue: AppConstants.ahaMaxDepthMm,
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
                    depthMm.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontFamily: 'SpaceMono',
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'mm',
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

