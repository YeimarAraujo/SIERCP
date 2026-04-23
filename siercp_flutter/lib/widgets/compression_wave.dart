import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class CompressionWave extends StatelessWidget {
  final List<double> history;

  const CompressionWave({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SEÑAL DE COMPRESIÓN',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 9,
            fontFamily: 'SpaceMono',
            letterSpacing: 0.05,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 60,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 80,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: AppColors.brand,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, index) {
                      final isLast = index == spots.length - 1;
                      final isOk = spot.y >= 50 && spot.y <= 60;
                      return FlDotCirclePainter(
                        radius: isLast ? 4 : 2,
                        color: isLast
                            ? AppColors.cyan
                            : isOk
                                ? AppColors.green
                                : AppColors.red,
                        strokeColor: Colors.transparent,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.brand.withValues(alpha: 0.2),
                        AppColors.brand.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
              // AHA range indicator lines
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 50,
                    color: AppColors.green.withValues(alpha: 0.3),
                    strokeWidth: 0.5,
                    dashArray: [4, 4],
                  ),
                  HorizontalLine(
                    y: 60,
                    color: AppColors.green.withValues(alpha: 0.3),
                    strokeWidth: 0.5,
                    dashArray: [4, 4],
                  ),
                ],
              ),
            ),
            duration: const Duration(milliseconds: 150),
          ),
        ),
      ],
    );
  }
}

