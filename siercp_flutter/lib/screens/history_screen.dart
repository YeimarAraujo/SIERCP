import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';
import '../services/export_service.dart';
import '../widgets/section_label.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsHistoryProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.signal_wifi_statusbar_connected_no_internet_4_outlined,
                    size: 36, color: Theme.of(context).textTheme.bodyMedium?.color),
                const SizedBox(height: 12),
                Text('Error al cargar historial',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(height: 4),
                Text(e.toString(),
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 11)),
              ],
            ),
          ),
          data: (sessions) => _HistoryBody(sessions: sessions),
        ),
      ),
    );
  }
}

class _HistoryBody extends ConsumerWidget {
  final List<SessionModel> sessions;
  const _HistoryBody({required this.sessions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = sessions
        .where((s) => s.metrics != null)
        .map((s) => s.metrics!.score)
        .toList();
    final avgScore  = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    final bestScore = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a > b ? a : b);
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP  = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.colorScheme.outline;
    final surface = theme.colorScheme.surface;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Historial',
                        style: TextStyle(color: textP, fontSize: 20, fontWeight: FontWeight.w700)),
                    Text('Todas tus sesiones de RCP',
                        style: TextStyle(color: textS, fontSize: 12)),
                  ],
                ),
                // Export menu
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    final svc = ref.read(exportServiceProvider);
                    try {
                      if (value == 'csv') {
                        await svc.exportHistoryCSV(sessions);
                      } else if (value == 'pdf' && sessions.isNotEmpty && sessions.first.metrics != null) {
                        await svc.exportSessionPDF(sessions.first, sessions.first.metrics!);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: AppColors.red),
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'csv',
                      child: Row(
                        children: [
                          Icon(Icons.table_chart_outlined, size: 18, color: AppColors.green),
                          SizedBox(width: 10),
                          Text('Exportar CSV'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.red),
                          SizedBox(width: 10),
                          Text('Exportar PDF (última sesión)'),
                        ],
                      ),
                    ),
                  ],
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.brand.withValues(alpha: 0.35), width: 1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_outlined, size: 14, color: AppColors.brand),
                        SizedBox(width: 5),
                        Text('Exportar',
                            style: TextStyle(color: AppColors.brand, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),



        // Summary cards
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.count(
            crossAxisCount: isLandscape ? 4 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isLandscape ? 2.4 : 1.7,
            children: [
              _SummaryCard(
                icon: Icons.analytics_outlined,
                label: 'Promedio global',
                value: '${avgScore.toStringAsFixed(0)}%',
                color: AppColors.green,
                isDark: isDark,
              ),
              _SummaryCard(
                icon: Icons.emoji_events_outlined,
                label: 'Mejor sesión',
                value: '${bestScore.toStringAsFixed(0)}%',
                color: AppColors.cyan,
                isDark: isDark,
              ),
              _SummaryCard(
                icon: Icons.history_outlined,
                label: 'Total sesiones',
                value: '${sessions.length}',
                color: textP,
                isDark: isDark,
              ),
              _SummaryCard(
                icon: Icons.local_fire_department_outlined,
                label: 'Con métricas',
                value: '${scores.length}',
                color: AppColors.amber,
                isDark: isDark,
              ),
            ],
          ),
        ),

        // Progress chart
        if (scores.length > 1) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: const SectionLabel('Progresión de calificaciones'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 160,
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: border, width: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: isDark ? null : AppShadows.card(false),
                ),
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 100,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: border, strokeWidth: 0.5),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (v, _) => Text(
                            '${v.toInt()}',
                            style: TextStyle(color: textS, fontSize: 9),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: scores.asMap().entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        isCurved: true,
                        color: AppColors.brand,
                        barWidth: 2,
                        dotData: FlDotData(
                          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                            radius: 3,
                            color: AppColors.brand,
                            strokeColor: Colors.transparent,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.brand.withValues(alpha: 0.25),
                              AppColors.brand.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],

        // Sessions list
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: const SectionLabel('Últimas sesiones'),
          ),
        ),
        sessions.isEmpty
            ? SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_outlined, size: 48, color: textS.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text('Sin sesiones registradas.', style: TextStyle(color: textS)),
                      ],
                    ),
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _SessionTile(session: sessions[i], isDark: isDark),
                    childCount: sessions.length,
                  ),
                ),
              ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 11,
                    )),
              ),
            ],
          ),
          const Spacer(),
          Text(value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFamily: 'SpaceMono',
              )),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionModel session;
  final bool isDark;
  const _SessionTile({required this.session, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final score    = session.metrics?.score;
    final approved = session.metrics?.approved ?? false;
    final theme  = Theme.of(context);
    final textP  = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.colorScheme.outline;
    final surface = theme.colorScheme.surface;

    final color = score == null
        ? AppColors.textTertiary
        : approved
            ? AppColors.green
            : score >= 70
                ? AppColors.amber
                : AppColors.red;
    final icon = approved
        ? Icons.check_circle_outline
        : score != null && score >= 70
            ? Icons.warning_amber_outlined
            : Icons.cancel_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/session-result/${session.id}'),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.scenarioTitle ?? 'Sesión RCP',
                        style: TextStyle(color: textP, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${DateFormat('d MMM · HH:mm').format(session.startedAt)} · ${session.durationFormatted} · ${session.metrics?.totalCompressions ?? 0} comp.',
                        style: TextStyle(color: textS, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      score != null ? '${score.toStringAsFixed(0)}%' : '--',
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'SpaceMono',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      approved ? 'aprobado' : score != null ? 'revisar' : 'sin datos',
                      style: TextStyle(color: textS, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

