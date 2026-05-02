import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class CompressionWave extends StatelessWidget {
  final List<double> history;
  final int ratePerMin;

  const CompressionWave({super.key, required this.history, this.ratePerMin = 0});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    final visibleHistory = history.length > 60 
        ? history.sublist(history.length - 60) 
        : history;

    // Calculamos el color dinámico basado en la última compresión
    final lastDepth = visibleHistory.isNotEmpty ? visibleHistory.last / 10 : 0.0;
    final waveColor = _getWaveColor(lastDepth);

    final spots = visibleHistory
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E12).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
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
                  const Text(
                    'COMPRESSION DEPTH WAVEFORM',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: waveColor,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: waveColor, blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'REAL-TIME MONITORING',
                        style: TextStyle(color: waveColor, fontSize: 9, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              _buildLiveBadge(),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 80,
                minX: 0,
                maxX: 59,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    // Zona ideal AHA (5-6 cm)
                    HorizontalLine(
                      y: 50,
                      color: AppColors.green.withValues(alpha: 0.2),
                      strokeWidth: 20, // Banda ancha
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.centerRight,
                        style: const TextStyle(color: AppColors.green, fontSize: 8),
                        labelResolver: (_) => 'IDEAL',
                      ),
                    ),
                  ],
                ),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.4,
                    color: waveColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          waveColor.withValues(alpha: 0.2),
                          waveColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: Duration.zero,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MetricInfo(
                label: 'DEPTH',
                value: lastDepth.toStringAsFixed(1),
                unit: 'cm',
                color: waveColor,
              ),
              _MetricInfo(
                label: 'RATE',
                value: '$ratePerMin',
                unit: 'cpm',
                color: _getRateColor(ratePerMin),
              ),
              const _MetricInfo(
                label: 'AHA SCORE',
                value: '98', // TODO: Vincular con cálculo real
                unit: '%',
                color: AppColors.green,
              ),
            ],
          ),
        ],
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
            style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getWaveColor(double depth) {
    if (depth < 4.0) return AppColors.blue; // Superficial
    if (depth >= 5.0 && depth <= 6.0) return AppColors.green; // Ideal
    if (depth > 6.0) return AppColors.red; // Muy fuerte
    return AppColors.orange; // Medio
  }

  Color _getRateColor(int rate) {
    if (rate >= 100 && rate <= 120) return AppColors.green;
    if (rate > 120) return AppColors.red;
    return AppColors.orange;
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
          style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold),
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
              style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}

