import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:siercp/core/widgets/app_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/features/reports/data/export_service.dart';
import 'package:siercp/features/simulation/data/simulation_service.dart'
    show quizHistoryProvider;
import 'package:siercp/core/widgets/section_label.dart';
import 'package:siercp/core/widgets/demo_guard.dart';
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
    final isDemo = ref.watch(isDemoProvider);
    if (isDemo) {
      return const DemoGuard(featureName: 'Historial', child: SizedBox());
    }

    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final loc = AppLocalizations.of(context)!;
    const accentColor = AppColors.accent;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(loc.historyTitle,
                  style: TextStyle(
                      color: textP, fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            TabBar(
              controller: _tabController,
              labelColor: accentColor,
              unselectedLabelColor: textS,
              indicatorColor: accentColor,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: const [
                Tab(text: 'Evaluaciones Prácticas'),
                Tab(text: 'Evaluaciones Teóricas'),
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

// ── Tab 1: Sesiones ───────────────────────────────────────────────────────

class _CprHistoryTab extends ConsumerWidget {
  final AppLocalizations loc;
  const _CprHistoryTab({required this.loc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsHistoryProvider);
    return sessionsAsync.when(
      loading: () => const AppLogoLoader(),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.signal_wifi_statusbar_connected_no_internet_4_outlined,
                size: 36, color: Theme.of(context).textTheme.bodyMedium?.color),
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

class _CprHistoryBody extends ConsumerStatefulWidget {
  final List<SessionModel> sessions;
  final AppLocalizations loc;
  const _CprHistoryBody({required this.sessions, required this.loc});

  @override
  ConsumerState<_CprHistoryBody> createState() => _CprHistoryBodyState();
}

class _CprHistoryBodyState extends ConsumerState<_CprHistoryBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  int _page = 0;
  static const int _perPage = 10;
  String _filter = 'all';

  List<SessionModel> get _filtered {
    if (_filter == 'all') return widget.sessions;
    if (_filter == 'passed') {
      return widget.sessions.where((s) => s.metrics?.approved == true).toList();
    }
    return widget.sessions
        .where((s) => s.metrics != null && s.metrics!.approved != true)
        .toList();
  }

  List<SessionModel> get _paginated =>
      _filtered.skip(_page * _perPage).take(_perPage).toList();

  int get _totalPages => (_filtered.length + _perPage - 1) ~/ _perPage;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final realStats = ref.watch(userStatsProvider);
    final quizAsync = ref.watch(quizHistoryProvider);
    final scores = widget.sessions
        .where((s) => s.metrics != null)
        .map((s) => s.metrics!.score)
        .toList();
    final avgScore =
        scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    final bestScore =
        scores.isEmpty ? 0.0 : scores.reduce((a, b) => a > b ? a : b);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.colorScheme.outline;
    final surface = theme.colorScheme.surface;
    final screenWidth = MediaQuery.of(context).size.width;
    const accentColor = AppColors.accent;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sessionsHistoryProvider);
        ref.invalidate(quizHistoryProvider);
      },
      color: AppColors.brand,
      child: CustomScrollView(
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
                          await svc.exportHistoryCSV(widget.sessions);
                        } else if (value == 'pdf' &&
                            widget.sessions.isNotEmpty &&
                            widget.sessions.first.metrics != null) {
                          await svc.exportSessionPDF(widget.sessions.first,
                              widget.sessions.first.metrics!);
                        } else if (value == 'combined') {
                          final quizData = quizAsync.valueOrNull ?? [];
                          await svc.exportCombinedCSV(
                              widget.sessions, quizData);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text(widget.loc.exportError(e.toString())),
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
                          Text(widget.loc.exportCsv),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'pdf',
                        child: Row(children: [
                          const Icon(Icons.picture_as_pdf_outlined,
                              size: 18, color: AppColors.red),
                          const SizedBox(width: 10),
                          Text(widget.loc.exportPdf),
                        ]),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'combined',
                        child: Row(children: [
                          Icon(Icons.download_outlined,
                              size: 18, color: AppColors.brand),
                          SizedBox(width: 10),
                          Text('Exportar todo (CSV)'),
                        ]),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: accentColor.withValues(alpha: 0.35),
                            width: 1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.download_outlined,
                              size: 14, color: accentColor),
                          const SizedBox(width: 5),
                          Text(widget.loc.exportBtn,
                              style: const TextStyle(
                                  color: accentColor,
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
              crossAxisCount: screenWidth > 600 ? 3 : 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: screenWidth > 600 ? 3 : 1.6,
              children: [
                _SummaryCard(
                  icon: Icons.analytics_outlined,
                  label: widget.loc.globalAvg,
                  value: '${avgScore.toStringAsFixed(0)}%',
                  color: AppColors.green,
                  isDark: isDark,
                ),
                _SummaryCard(
                  icon: Icons.emoji_events_outlined,
                  label: widget.loc.bestSession,
                  value: '${bestScore.toStringAsFixed(0)}%',
                  color: AppColors.cyan,
                  isDark: isDark,
                ),
                //_SummaryCard(
                //icon: Icons.history_outlined,
                //label: widget.loc.totalSessions,
                //value: '${widget.sessions.length}',
                //color: textP,
                //isDark: isDark,
                //),
                // _SummaryCard(
                //   icon: Icons.local_fire_department_outlined,
                //   label: widget.loc.withMetrics,
                //   value: '${scores.length}',
                //   color: AppColors.amber,
                //   isDark: isDark,
                // ),
                // _SummaryCard(
                //   icon: Icons.timer_outlined,
                //   label: widget.loc.practiceHours,
                //   value: '${(realStats?.totalHours ?? 0).toStringAsFixed(1)}h',
                //   color: AppColors.cyan,
                //   isDark: isDark,
                // ),
                _SummaryCard(
                  icon: Icons.local_fire_department_outlined,
                  label: widget.loc.currentStreak,
                  value: '${realStats?.streakDays ?? 0}d',
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
                child: SectionLabel(widget.loc.scoreProgression),
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
                              .map((e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                          isCurved: true,
                          color: accentColor,
                          barWidth: 2,
                          dotData: FlDotData(
                            getDotPainter: (_, __, ___, ____) =>
                                FlDotCirclePainter(
                              radius: 3,
                              color: accentColor,
                              strokeColor: Colors.transparent,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                accentColor.withValues(alpha: 0.25),
                                accentColor.withValues(alpha: 0.0),
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Todas',
                    selected: _filter == 'all',
                    onSelected: () => setState(() {
                      _filter = 'all';
                      _page = 0;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Aprobadas',
                    selected: _filter == 'passed',
                    onSelected: () => setState(() {
                      _filter = 'passed';
                      _page = 0;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Perdidas',
                    selected: _filter == 'failed',
                    onSelected: () => setState(() {
                      _filter = 'failed';
                      _page = 0;
                    }),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: SectionLabel(widget.loc.latestSessions),
            ),
          ),
          _filtered.isEmpty
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_alt_outlined,
                              size: 48, color: textS.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            _filter == 'all'
                                ? widget.loc.noSessions
                                : 'No hay sesiones con este filtro',
                            style: TextStyle(color: textS),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) =>
                          _SessionTile(session: _paginated[i], isDark: isDark),
                      childCount: _paginated.length,
                    ),
                  ),
                ),
          // Pagination
          if (_totalPages > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed:
                          _page > 0 ? () => setState(() => _page--) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                      color: _page > 0 ? accentColor : textS,
                    ),
                    Text(
                      '${_page + 1} / $_totalPages',
                      style: TextStyle(color: textS, fontSize: 13),
                    ),
                    IconButton(
                      onPressed: _page < _totalPages - 1
                          ? () => setState(() => _page++)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: _page < _totalPages - 1 ? accentColor : textS,
                    ),
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
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
      loading: () => const AppLogoLoader(),
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

class _QuizHistoryBody extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> sessions;
  const _QuizHistoryBody({required this.sessions});

  @override
  ConsumerState<_QuizHistoryBody> createState() => _QuizHistoryBodyState();
}

class _QuizHistoryBodyState extends ConsumerState<_QuizHistoryBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  int _page = 0;
  static const int _perPage = 10;
  String _filter = 'all';

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return widget.sessions;
    final passed = _filter == 'passed';
    return widget.sessions.where((s) => s['passed'] == passed).toList();
  }

  List<Map<String, dynamic>> get _paginated =>
      _filtered.skip(_page * _perPage).take(_perPage).toList();

  int get _totalPages => (_filtered.length + _perPage - 1) ~/ _perPage;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    const accentColor = AppColors.accent;
    final sessionsAsync = ref.watch(sessionsHistoryProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    if (widget.sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined,
                size: 48, color: textS.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Aún no tienes evaluaciones', style: TextStyle(color: textS)),
            const SizedBox(height: 4),
            Text('Completa una evaluación teórica o práctica',
                style: TextStyle(color: textS, fontSize: 11)),
          ],
        ),
      );
    }

    // Resumen XP total
    final totalXp = widget.sessions.fold<int>(
        0, (sum, s) => sum + ((s['xpEarned'] as num?)?.toInt() ?? 0));
    final totalPassed =
        widget.sessions.where((s) => s['passed'] == true).length;

    return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(quizHistoryProvider);
          ref.invalidate(sessionsHistoryProvider);
        },
        color: AppColors.brand,
        child: CustomScrollView(
          slivers: [
            // Export button
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
                          if (value == 'evaluations') {
                            await svc.exportEvaluationsCSV(widget.sessions);
                          } else if (value == 'combined') {
                            final sessions = sessionsAsync.valueOrNull ?? [];
                            await svc.exportCombinedCSV(
                                sessions, widget.sessions);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Error al exportar: ${e.toString()}'),
                                  backgroundColor: AppColors.red),
                            );
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'evaluations',
                          child: Row(children: [
                            Icon(Icons.table_chart_outlined,
                                size: 18, color: AppColors.green),
                            SizedBox(width: 10),
                            Text('Exportar evaluaciones (CSV)'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'combined',
                          child: Row(children: [
                            Icon(Icons.download_outlined,
                                size: 18, color: AppColors.brand),
                            SizedBox(width: 10),
                            Text('Exportar todo (CSV)'),
                          ]),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: accentColor.withValues(alpha: 0.35),
                              width: 1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download_outlined,
                                size: 14, color: accentColor),
                            SizedBox(width: 5),
                            Text('Exportar',
                                style: TextStyle(
                                    color: accentColor,
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              sliver: SliverGrid.count(
                crossAxisCount: screenWidth > 600 ? 3 : 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: screenWidth > 600 ? 3 : 1.6,
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
                    value: '${widget.sessions.length}',
                    color: textP,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Filter chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Todas',
                      selected: _filter == 'all',
                      onSelected: () => setState(() {
                        _filter = 'all';
                        _page = 0;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Aprobadas',
                      selected: _filter == 'passed',
                      onSelected: () => setState(() {
                        _filter = 'passed';
                        _page = 0;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Perdidas',
                      selected: _filter == 'failed',
                      onSelected: () => setState(() {
                        _filter = 'failed';
                        _page = 0;
                      }),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: SectionLabel('Historial de evaluaciones'),
              ),
            ),

            // List
            if (_filtered.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_alt_outlined,
                          size: 48, color: textS.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('No hay evaluaciones con este filtro',
                          style: TextStyle(color: textS)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _QuizSessionTile(
                        session: _paginated[i], isDark: isDark),
                    childCount: _paginated.length,
                  ),
                ),
              ),

            // Pagination
            if (_totalPages > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed:
                            _page > 0 ? () => setState(() => _page--) : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: _page > 0 ? accentColor : textS,
                      ),
                      Text(
                        '${_page + 1} / $_totalPages',
                        style: TextStyle(color: textS, fontSize: 13),
                      ),
                      IconButton(
                        onPressed: _page < _totalPages - 1
                            ? () => setState(() => _page++)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        color: _page < _totalPages - 1 ? accentColor : textS,
                      ),
                    ],
                  ),
                ),
              ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    ),
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
    final textSmall = theme.textTheme.bodySmall?.color;
    return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final valueSize = h < 50
                ? 16.0
                : h < 65
                    ? 20.0
                    : 26.0;
            final labelSize = h < 50 ? 9.0 : 10.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: textSmall,
                          fontSize: labelSize,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: valueSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        ));
  }
}

class _QuizSessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  final bool isDark;
  const _QuizSessionTile({required this.session, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    const accentColor = AppColors.accent;

    final type = session['type'] as String? ?? 'theoretical';
    final score = (session['score'] as num?)?.toDouble() ?? 0.0;
    final passed = session['passed'] as bool? ?? false;
    final xpEarned = (session['xpEarned'] as num?)?.toInt() ?? 0;
    final completedAt = session['completedAt'];

    final isPractical = type == 'practical_eval';
    final color = passed ? AppColors.green : AppColors.red;
    final icon =
        isPractical ? Icons.favorite_outline_rounded : Icons.quiz_outlined;
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

    return Padding(
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
                ),
              ),
              if (xpEarned > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        size: 11, color: accentColor),
                    Text(
                      '+$xpEarned XP',
                      style: const TextStyle(
                          color: accentColor,
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final valueSize = h < 50
              ? 16.0
              : h < 65
                  ? 20.0
                  : 26.0;
          final labelSize = h < 50 ? 9.0 : 10.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: labelSize,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(value,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: valueSize,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          );
        },
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
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            context.go('/simulation/practical/session-result/${session.id}'),
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
                      session.scenarioTitle ?? 'Sesión de práctica',
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
                    score != null ? '${score.toStringAsFixed(0)}%' : '--',
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: textS.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = AppColors.accent;
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : theme.colorScheme.outline,
            width: selected ? 0 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
