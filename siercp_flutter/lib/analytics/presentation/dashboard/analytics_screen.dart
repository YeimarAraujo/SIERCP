import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../data/models/analytics_models.dart';
import '../providers/analytics_providers.dart';
import '../widgets/analytics_widgets.dart';

class AnalyticsDashboardScreen extends ConsumerStatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  ConsumerState<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends ConsumerState<AnalyticsDashboardScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isExporting = false;

  Future<void> _exportDashboard() async {
    setState(() => _isExporting = true);
    try {
      // 1. Tomar captura del widget
      final Uint8List? image = await _screenshotController.capture(pixelRatio: 2.0);
      if (image == null) throw Exception("No se pudo capturar la pantalla");

      // 2. Generar PDF
      final pdf = pw.Document();
      final pdfImage = pw.MemoryImage(image);
      
      pdf.addPage(pw.Page(
        build: (pw.Context context) {
          return pw.Center(child: pw.Image(pdfImage));
        },
      ));

      // 3. Guardar archivo temporal
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/dashboard_analytics.pdf");
      await file.writeAsBytes(await pdf.save());

      // 4. Compartir
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Reporte de Analíticas SIERCP');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(dateRangeProvider);
    final kpisAsync = ref.watch(kpisProvider);
    final chartsAsync = ref.watch(chartsDataProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Dashboard Analítico', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          _isExporting
              ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: 'Exportar PDF',
                  onPressed: _exportDashboard,
                ),
        ],
      ),
      body: Screenshot(
        controller: _screenshotController,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor, // Background for screenshot
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filtros
                _buildFilters(range),
                const SizedBox(height: 24),

                // KPIs
                kpisAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Text('Error: $e'),
                  data: (kpis) => _buildKPIsGrid(kpis),
                ),
                const SizedBox(height: 24),

                // Gráficas
                chartsAsync.when(
                  loading: () => const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
                  error: (e, st) => Text('Error: $e'),
                  data: (data) => _buildCharts(data),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(DateRangeFilter currentRange) {
    return SegmentedButton<DateRangeFilter>(
      segments: const [
        ButtonSegment(value: DateRangeFilter.today, label: Text('Hoy')),
        ButtonSegment(value: DateRangeFilter.week, label: Text('Semana')),
        ButtonSegment(value: DateRangeFilter.month, label: Text('Mes')),
        ButtonSegment(value: DateRangeFilter.custom, label: Text('Histórico')),
      ],
      selected: {currentRange},
      onSelectionChanged: (set) {
        ref.read(dateRangeProvider.notifier).state = set.first;
      },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return AppColors.brand;
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
        }),
      ),
    );
  }

  Widget _buildKPIsGrid(AnalyticsKPIs kpis) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        KpiCard(
          title: 'Total Sesiones',
          value: '${kpis.totalSessions}',
          icon: Icons.monitor_heart,
          color: AppColors.brand,
        ),
        KpiCard(
          title: 'Score Promedio',
          value: '${kpis.avgScore.toStringAsFixed(1)}%',
          icon: Icons.star_rounded,
          color: AppColors.cyan,
        ),
        KpiCard(
          title: 'Horas Totales',
          value: kpis.totalTimeHours.toStringAsFixed(1),
          icon: Icons.timer_outlined,
          color: AppColors.green,
        ),
        KpiCard(
          title: 'Compresiones',
          value: '${kpis.totalCompressions}',
          icon: Icons.health_and_safety,
          color: AppColors.accent,
        ),
      ],
    );
  }

  Widget _buildCharts(ChartsData data) {
    if (data.categoryDistribution.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No hay datos en este rango de fechas')),
      );
    }

    return Column(
      children: [
        // Fila 1: LineChart y PieChart
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ChartCard(
                title: 'Evolución del Score',
                child: _buildLineChart(data.scoreOverTime),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 1,
              child: ChartCard(
                title: 'Por Escenario',
                child: _buildPieChart(data.pieDistribution),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Fila 2: BarChart y ScatterChart
        Row(
          children: [
            Expanded(
              child: ChartCard(
                title: 'Correlación Profundidad vs Frecuencia',
                child: _buildScatterChart(data.scatterPoints),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ChartCard(
                title: 'Distribución de Sesiones',
                child: _buildBarChart(data.categoryDistribution),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLineChart(Map<DateTime, double> scoreTime) {
    if (scoreTime.isEmpty) return const SizedBox();
    
    // Sort chronologically
    final sortedKeys = scoreTime.keys.toList()..sort();
    List<FlSpot> spots = [];
    double minX = 0;
    double maxX = (sortedKeys.length - 1).toDouble();

    for (int i = 0; i < sortedKeys.length; i++) {
      spots.add(FlSpot(i.toDouble(), scoreTime[sortedKeys[i]]!));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // Ocultar fechas por simplicidad
        ),
        borderData: FlBorderData(show: false),
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.brand,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.brand.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> pieDist) {
    if (pieDist.isEmpty) return const SizedBox();

    List<PieChartSectionData> sections = [];
    int i = 0;
    final colors = [AppColors.cyan, AppColors.accent];

    pieDist.forEach((key, value) {
      if (value > 0) {
        sections.add(PieChartSectionData(
          color: colors[i % colors.length],
          value: value,
          title: '${value.toStringAsFixed(0)}%',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ));
      }
      i++;
    });

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        sections: sections,
      ),
    );
  }

  Widget _buildBarChart(Map<String, int> distribution) {
    List<BarChartGroupData> groups = [];
    int i = 0;
    
    distribution.forEach((key, value) {
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: value.toDouble(),
            color: AppColors.brand,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ));
      i++;
    });

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final index = val.toInt();
                if (index >= 0 && index < distribution.keys.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(distribution.keys.elementAt(index), style: const TextStyle(fontSize: 10)),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        barGroups: groups,
      ),
    );
  }

  Widget _buildScatterChart(List<Map<String, double>> points) {
    if (points.isEmpty) return const SizedBox();

    List<ScatterSpot> scatterSpots = points.map((p) {
      return ScatterSpot(
        p['rate']!, // X axis = rate
        p['depth']!, // Y axis = depth
        dotPainter: FlDotCirclePainter(color: AppColors.cyan.withOpacity(0.6), radius: 4),
      );
    }).toList();

    return ScatterChart(
      ScatterChartData(
        scatterSpots: scatterSpots,
        minX: 80,
        maxX: 140,
        minY: 30,
        maxY: 80,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.2))),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }
}
