import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:siercp/core/theme/theme.dart';

class CompressionWave extends StatelessWidget {
  final List<double> history;
  final int ratePerMin;
  final int score;

  const CompressionWave({
    super.key,
    required this.history,
    this.ratePerMin = 0,
    this.score = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.black.withValues(alpha: 0.05);

    final secondaryText = isDark
        ? Colors.white.withValues(alpha: 0.3)
        : Colors.black.withValues(alpha: 0.35);
    if (history.isEmpty) return const SizedBox.shrink();

    final visibleHistory =
        history.length > 60 ? history.sublist(history.length - 60) : history;

    // Calculamos el color dinámico basado en la última compresión
    final lastDepth =
        visibleHistory.isNotEmpty ? visibleHistory.last / 10 : 0.0;
    final waveColor = _getWaveColor(lastDepth, isDark);

    final spots = visibleHistory
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: waveColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: waveColor, blurRadius: 4)
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MONITOREO EN TIEMPO REAL',
                          style: TextStyle(
                            color: waveColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _buildLiveBadge(),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 90,
                  minX: 0,
                  maxX: 50,
                  clipData: FlClipData.all(),
                  rangeAnnotations: RangeAnnotations(
                    horizontalRangeAnnotations: [
                      HorizontalRangeAnnotation(
                        y1: 50,
                        y2: 60,
                        color: const Color.fromARGB(255, 0, 255, 132)
                            .withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: gridColor,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 10,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.15, // Suavizado premium
                      color: waveColor,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            waveColor.withValues(alpha: 0.12),
                            waveColor.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Solo animar si no estamos en tiempo real extremo para ganar FPS
                duration: const Duration(milliseconds: 50),
                curve: Curves.linear,
              ),
            ),
            const SizedBox(height: 16),
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //     _MetricInfo(
            //       label: 'PROFUNDIDAD',
            //       value: lastDepth.toStringAsFixed(1),
            //       unit: 'cm',
            //       color: _getRateColor(ratePerMin),
            //     ),
            //     _MetricInfo(
            //       label: 'FRECUENCIA',
            //       value: '$ratePerMin',
            //       unit: 'cpm',
            //       color: waveColor,
            //     ),
            //     _MetricInfo(
            //       label: 'AHA SCORE',
            //       value: '$score',
            //       unit: '%',
            //       color: score >= 80 ? AppColors.green : AppColors.amber,
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.sensors, color: Colors.red, size: 10),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.red,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          )
        ],
      ),
    );
  }

  Color _getWaveColor(double depth, bool isDark) {
    if (depth >= 5.0 && depth <= 6.0) {
      return AppColors.success(isDark);
    }

    if (depth > 6.0) {
      return AppColors.danger(isDark);
    }

    return AppColors.warning(isDark);
  }

  Color _getRateColor(int rate) {
    if (rate >= 100 && rate <= 120) return AppColors.green;
    if (rate > 120) return AppColors.red;
    return AppColors.amber;
  }
}

class _MetricInfo extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MetricInfo({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withValues(alpha: 0.5),
              fontSize: 8,
              fontWeight: FontWeight.bold),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}
