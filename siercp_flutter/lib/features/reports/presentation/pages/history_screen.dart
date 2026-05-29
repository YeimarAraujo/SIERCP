import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/features/reports/data/export_service.dart';
import 'package:siercp/features/simulation/data/simulation_service.dart';
import 'package:siercp/core/widgets/section_label.dart';
import 'package:siercp/l10n/app_localizations.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.historyTitle,
                      style: TextStyle(
                          color: textP,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  Text(loc.historySubtitle,
                      style: TextStyle(color: textS, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.brand,
              unselectedLabelColor: textS,
              indicatorColor: AppColors.brand,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: const [
                Tab(text: 'Sesiones RCP'),
                Tab(text: 'Evaluaciones'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _CprHistoryTab(loc: loc),
                  const _QuizHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Sesiones RCP ───────────────────────────────────────────────────────

class _CprHistoryTab extends ConsumerWidget {
  final AppLocalizations loc;
  const _CprHistoryTab({required this.loc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsHistoryProvider);
    return sessionsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.brand)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.signal_wifi_statusbar_connected_no_internet_4_outlined,
                size: 36,
                color: Theme.of(context).textTheme.bodyMedium?.color),
            const SizedBox(height: 12),
            Text(loc.historyLoadError,
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color)),
            const SizedBox(height: 4),
            Text(e.toString(),
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 11)),
          ],
        ),
      ),
      data: (sessions) => _CprHistoryBody(sessions: sessions, loc: loc),
    );
  }
}

class _CprHistoryBody extends ConsumerWidget {
  final List<SessionModel> sessions;
  final AppLocalizations loc;
  const _CprHistoryBody({required this.sessions, required this.loc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = sessions
        .where((s) => s.metrics != null)
        .map((s) => s.metrics!.score)
        .toList();
    final avgScore =
        scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    final bestScore =
        scores.isEmpty ? 0.0 : scores.reduce((a, b) => a > b ? a : b);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.colorScheme.outline;
    final surface = theme.colorScheme.surface;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return CustomScrollView(
      slivers: [
        // Export menu
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    final svc = ref.read(exportServiceProvider);
                    try {
                      if (value == 'csv') {
                        await svc.exportHistoryCSV(sessions);
                      } else if (value == 'pdf' &&
                          sessions.isNotEmpty &&
                          sessions.first.metrics != null) {
                        await svc.exportSessionPDF(
                            sessions.first, sessions.first.metrics!);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text(loc.exportError(e.toString())),
                              backgroundColor: AppColors.red),
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'csv',
                      child: Row(children: [
                        const Icon(Icons.table_chart_outlined,
                            size: 18, color: AppColors.green),
                        const SizedBox(width: 10),
                        Text(loc.exportCsv),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'pdf',
                      child: Row(children: [
                        const Icon(Icons.picture_as_pdf_outlined,
                            size: 18, color: AppColors.red),
                        const SizedBox(width: 10),
                        Text(loc.exportPdf),
                      ]),
                    ),
                  ],
                  icon: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.35),
                          width: 1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download_outlined,
                            size: 14, color: AppColors.brand),
                        const SizedBox(width: 5),
                        Text(loc.exportBtn,
                            style: const TextStyle(
                                color: AppColors.brand,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
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
                label: loc.globalAvg,
                value: '${avgScore.toStringAsFixed(0)}%',
                color: AppColors.green,
                isDark: isDark,
              ),
              _SummaryCard(
                icon: Icons.emoji_events_outlined,
                label: loc.bestSession,
                value: '${bestScore.toStringAsFixed(0)}%',
                color: AppColors.cyan,
                isDark: isDark,
              ),
              _SummaryCard(
                icon: Icons.history_outlined,
                label: loc.totalSessions,
                value: '${sessions.length}',
                color: textP,
                isDark: isDark,
              ),
              _SummaryCard(
                icon: Icons.local_fire_department_outlined,
                label: loc.withMetrics,
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
              child: SectionLabel(loc.scoreProgression),
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
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: border, strokeWidth: 0.5),
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
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: scores.reversed
                            .toList()
                            .asMap()
                            .entries
                            .map((e) =>
                                FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        isCurved: true,
                        color: AppColors.brand,
                        barWidth: 2,
                        dotData: FlDotData(
                          getDotPainter: (_, __, ___, ____) =>
                              FlDotCirclePainter(
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
            child: SectionLabel(loc.latestSessions),
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
                        Icon(Icons.history_outlined,
                            size: 48,
                            color: textS.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(loc.noSessions,
                            style: TextStyle(color: textS)),
                      ],
                    ),
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _SessionTile(
                        session: sessions[i], isDark: isDark),
                    childCount: sessions.length,
                  ),
                ),
              ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ── Tab 2: Evaluaciones (quiz history) ───────────────────────────────────────

class _QuizHistoryTab extends ConsumerWidget {
  const _QuizHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(quizHistoryProvider);
    final theme = Theme.of(context);
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return historyAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.brand)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 36, color: textS),
            const SizedBox(height: 12),
            Text('Error al cargar evaluaciones',
                style: TextStyle(color: textS)),
          ],
        ),
      ),
      data: (sessions) => _QuizHistoryBody(sessions: sessions),
    );
  }
}

class _QuizHistoryBody extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  const _QuizHistoryBody({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined,
                size: 48, color: textS.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Aún no tienes evaluaciones',
                style: TextStyle(color: textS)),
            const SizedBox(height: 4),
            Text('Completa una evaluación teórica o práctica',
                style: TextStyle(color: textS, fontSize: 11)),
          ],
        ),
      );
    }

    // Resumen XP total
    final totalXp = sessions.fold<int>(
        0, (sum, s) => sum + ((s['xpEarned'] as num?)?.toInt() ?? 0));
    final totalPassed =
        sessions.where((s) => s['passed'] == true).length;

    return CustomScrollView(
      slivers: [
        // Summary cards
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverGrid.count(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _QuizSummaryCard(
                icon: Icons.bolt_rounded,
                label: 'XP Total',
                value: '$totalXp XP',
                color: AppColors.brand,
                isDark: isDark,
              ),
              _QuizSummaryCard(
                icon: Icons.check_circle_outline_rounded,
                label: 'Aprobadas',
                value: '$totalPassed',
                color: AppColors.green,
                isDark: isDark,
              ),
              _QuizSummaryCard(
                icon: Icons.quiz_outlined,
                label: 'Total',
                value: '${sessions.length}',
                color: textP,
                isDark: isDark,
              ),
            ],
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: SectionLabel('Historial de evaluaciones'),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _QuizSessionTile(
                  session: sessions[i], isDark: isDark),
              childCount: sessions.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuizSummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _QuizSummaryCard({
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border:
            Border.all(color: theme.colorScheme.outline, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const Spacer(),
          Text(value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'SpaceMono',
              )),
          Text(label,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 10,
              )),
        ],
      ),
    );
  }
}

class _QuizSessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  final bool isDark;
  const _QuizSessionTile(
      {required this.session, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS =
        theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.colorScheme.outline;
    final surface = theme.colorScheme.surface;

    final type = session['type'] as String? ?? 'theoretical';
    final score = (session['score'] as num?)?.toDouble() ?? 0.0;
    final passed = session['passed'] as bool? ?? false;
    final xpEarned =
        (session['xpEarned'] as num?)?.toInt() ?? 0;
    final completedAt = session['completedAt'];

    final isPractical = type == 'practical_eval';
    final color = passed ? AppColors.green : AppColors.red;
    final icon = isPractical
        ? Icons.favorite_outline_rounded
        : Icons.quiz_outlined;
    final typeLabel =
        isPractical ? 'Evaluación práctica' : 'Evaluación teórica';

    String dateStr = '';
    if (completedAt != null) {
      try {
        final ts = completedAt as dynamic;
        final dt = ts.toDate() as DateTime;
        dateStr = DateFormat('d MMM yyyy · HH:mm').format(dt);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  Text(typeLabel,
                      style: TextStyle(
                          color: textP,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Text(
                    dateStr.isNotEmpty ? dateStr : 'Sin fecha',
                    style: TextStyle(color: textS, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${score.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'SpaceMono',
                  ),
                ),
                if (xpEarned > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded,
                          size: 11, color: AppColors.brand),
                      Text(
                        '+$xpEarned XP',
                        style: const TextStyle(
                            color: AppColors.brand,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  )
                else
                  Text(
                    passed ? 'Aprobado' : 'No aprobado',
                    style: TextStyle(color: textS, fontSize: 10),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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
        border:
            Border.all(color: theme.colorScheme.outline, width: 0.5),
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
    final loc = AppLocalizations.of(context)!;
    final score = session.metrics?.score;
    final approved = session.metrics?.approved ?? false;
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS =
        theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
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
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.scenarioTitle ?? loc.cprSession,
                        style: TextStyle(
                            color: textP,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${DateFormat('d MMM · HH:mm').format(session.startedAt)} · ${session.durationFormatted} · ${session.metrics?.totalCompressions ?? 0} ${loc.compLabel}',
                        style: TextStyle(color: textS, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      score != null
                          ? '${score.toStringAsFixed(0)}%'
                          : '--',
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'SpaceMono',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      approved
                          ? loc.approved
                          : score != null
                              ? loc.review
                              : loc.noData,
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
