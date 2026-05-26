import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/courses/data/models/alert_course.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/features/devices/data/device_service.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/core/widgets/depth_gauge.dart';
import 'package:siercp/core/widgets/rate_gauge.dart';

class LiveInstructorScreen extends ConsumerStatefulWidget {
  final String courseId;
  const LiveInstructorScreen({super.key, required this.courseId});

  @override
  ConsumerState<LiveInstructorScreen> createState() =>
      _LiveInstructorScreenState();
}

class _LiveInstructorScreenState extends ConsumerState<LiveInstructorScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    final coursesAsync = ref.watch(coursesProvider);
    final courses = coursesAsync.value ?? [];
    final course = courses
        .cast<CourseModel?>()
        .firstWhere((c) => c?.id == widget.courseId, orElse: () => null);

    final activeSessionsAsync =
        ref.watch(courseActiveSessionsProvider(widget.courseId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            _LiveHeader(course: course, isDark: isDark),

            // ── Summary bar ────────────────────────────────────────────────
            activeSessionsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (sessions) => sessions.isEmpty
                  ? const SizedBox.shrink()
                  : _SummaryBar(sessions: sessions, isDark: isDark),
            ),

            // ── Content ─────────────────────────────────────────────────────
            Expanded(
              child: activeSessionsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.brand)),
                error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: TextStyle(color: textS))),
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return _EmptyState(textS: textS, textP: textP);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _RealtimeSessionCard(
                      session: sessions[i],
                      isDark: isDark,
                      index: i,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _LiveHeader extends StatelessWidget {
  final CourseModel? course;
  final bool isDark;
  const _LiveHeader({required this.course, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1800AD), Color(0xFF2D1FD4)],
              ),
        color: isDark ? theme.colorScheme.surface : null,
        border: isDark
            ? Border(
                bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3)))
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: isDark ? theme.textTheme.bodyLarge?.color : Colors.white),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00FF94),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0xFF00FF94), blurRadius: 6)
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'EN VIVO',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF00FF94)
                            : Colors.white.withValues(alpha: 0.85),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  course?.title ?? 'Monitorización en Vivo',
                  style: TextStyle(
                    color: isDark
                        ? theme.textTheme.bodyLarge?.color
                        : Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Sesiones activas de estudiantes',
                  style: TextStyle(
                    color: isDark
                        ? theme.textTheme.bodyMedium?.color
                        : Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Refresh indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHighest
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.autorenew_rounded,
                    size: 13,
                    color: isDark
                        ? theme.textTheme.bodySmall?.color
                        : Colors.white.withValues(alpha: 0.85)),
                const SizedBox(width: 5),
                Text(
                  'AUTO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? theme.textTheme.bodySmall?.color
                        : Colors.white.withValues(alpha: 0.85),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary bar ──────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<SessionModel> sessions;
  final bool isDark;
  const _SummaryBar({required this.sessions, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.brand.withValues(alpha: isDark ? 0.25 : 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatPill(
            label: 'Activos',
            value: '${sessions.length}',
            icon: Icons.people_alt_outlined,
            color: AppColors.brand,
          ),
          _Divider(),
          _StatPill(
            label: 'En curso',
            value: '${sessions.where((s) => s.status == SessionStatus.active).length}',
            icon: Icons.play_circle_outline_rounded,
            color: const Color(0xFF00FF94),
          ),
          _Divider(),
          _StatPill(
            label: 'Con dispositivo',
            value: '${sessions.where((s) => s.manikinId != null && s.manikinId!.isNotEmpty).length}',
            icon: Icons.bluetooth_connected_rounded,
            color: AppColors.cyan,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 28,
      color: AppColors.brand.withValues(alpha: 0.2),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatPill(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: 0.7))),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final Color textS;
  final Color textP;
  const _EmptyState({required this.textS, required this.textP});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.monitor_heart_outlined,
                  size: 36, color: textS.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin sesiones activas',
              style: TextStyle(
                  color: textP, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando un estudiante inicie una práctica con maniquí\naparecer aquí en tiempo real.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textS, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Realtime session card ────────────────────────────────────────────────────
class _RealtimeSessionCard extends ConsumerWidget {
  final SessionModel session;
  final bool isDark;
  final int index;

  const _RealtimeSessionCard(
      {required this.session, required this.isDark, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveMetrics = session.liveMetrics;
    final manikinId = session.manikinId;
    final hasLiveData = (liveMetrics?.compressionCount ?? 0) > 0;

    if (manikinId == null || manikinId.isEmpty) {
      return _DeviceMonitorCard(
        studentName: session.studentName,
        scenarioTitle: session.scenarioTitle,
        deviceId: null,
        depthMm: liveMetrics?.depthMm ?? 0,
        ratePerMin: liveMetrics?.ratePerMin ?? 0,
        qualityPct: liveMetrics?.correctPct ?? 0,
        connected: hasLiveData,
        isDark: isDark,
        index: index,
        liveMetrics: liveMetrics,
      );
    }

    final deviceStream = ref.watch(deviceServiceProvider).streamDevice(manikinId);

    return StreamBuilder<DeviceInfo?>(
      stream: deviceStream,
      builder: (context, snapshot) {
        final device = snapshot.data;
        final deviceConnected = device != null && device.isActive;
        return _DeviceMonitorCard(
          studentName: session.studentName,
          scenarioTitle: session.scenarioTitle,
          deviceId: manikinId,
          depthMm: device?.profundidadMm ?? liveMetrics?.depthMm ?? 0,
          ratePerMin: device?.frecuenciaCpm ?? liveMetrics?.ratePerMin ?? 0,
          qualityPct: liveMetrics?.correctPct ?? device?.calidadPct ?? 0,
          connected: deviceConnected || hasLiveData,
          isDark: isDark,
          index: index,
          liveMetrics: liveMetrics,
        );
      },
    );
  }
}

// ─── Device monitor card ─────────────────────────────────────────────────────
class _DeviceMonitorCard extends StatelessWidget {
  final String studentName;
  final String? scenarioTitle;
  final String? deviceId;
  final double depthMm;
  final int ratePerMin;
  final double qualityPct;
  final bool connected;
  final bool isDark;
  final int index;
  final LiveSessionData? liveMetrics;

  const _DeviceMonitorCard({
    required this.studentName,
    required this.scenarioTitle,
    required this.deviceId,
    required this.depthMm,
    required this.ratePerMin,
    this.qualityPct = 0,
    required this.connected,
    required this.isDark,
    required this.index,
    this.liveMetrics,
  });

  Color get _qualityColor {
    if (qualityPct >= 85) return const Color(0xFF00FF94);
    if (qualityPct >= 70) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT = theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final surfaceColor = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connected
              ? AppColors.brand.withValues(alpha: 0.3)
              : borderColor.withValues(alpha: 0.5),
          width: connected ? 1.5 : 0.5,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: connected
                      ? AppColors.brand.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: connected
                  ? AppColors.brand.withValues(alpha: isDark ? 0.12 : 0.04)
                  : borderColor.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                  bottom: BorderSide(
                      color: borderColor.withValues(alpha: 0.2), width: 0.5)),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: connected
                        ? AppColors.brand.withValues(alpha: 0.12)
                        : textT.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      studentName.isNotEmpty
                          ? studentName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: connected ? AppColors.brand : textT,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName,
                          style: TextStyle(
                              color: textP,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 1),
                      Text(
                        scenarioTitle ?? 'Sin escenario',
                        style: TextStyle(color: textS, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Connection status
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: connected
                        ? const Color(0xFF00FF94).withValues(alpha: 0.1)
                        : textT.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: connected
                          ? const Color(0xFF00FF94).withValues(alpha: 0.35)
                          : textT.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        connected
                            ? Icons.bluetooth_connected_rounded
                            : Icons.bluetooth_disabled_rounded,
                        size: 11,
                        color: connected
                            ? const Color(0xFF00FF94)
                            : textT.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        connected ? 'EN VIVO' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: connected
                              ? const Color(0xFF00FF94)
                              : textT.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: connected
                ? Column(
                    children: [
                      // ── Live metrics row (score / compressions / quality) ──
                      if (liveMetrics != null &&
                          liveMetrics!.compressionCount > 0) ...[
                        _LiveMetricsRow(
                            liveMetrics: liveMetrics!, textT: textT),
                        const SizedBox(height: 14),
                      ] else if (qualityPct > 0) ...[
                        // Fallback: barra de calidad del device stream
                        Row(
                          children: [
                            Text('CALIDAD',
                                style: TextStyle(
                                    color: textT,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1)),
                            const Spacer(),
                            Text(
                              '${qualityPct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                  color: _qualityColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (qualityPct / 100).clamp(0.0, 1.0),
                            backgroundColor:
                                _qualityColor.withValues(alpha: 0.12),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(_qualityColor),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      // ── Gauges row ─────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text('PROFUNDIDAD',
                                    style: TextStyle(
                                        color: textT,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5)),
                                const SizedBox(height: 6),
                                SizedBox(
                                    height: 80,
                                    child: DepthGauge(depthMm: depthMm)),
                              ],
                            ),
                          ),
                          Container(
                              width: 0.5,
                              height: 72,
                              color: borderColor.withValues(alpha: 0.3)),
                          Expanded(
                            child: Column(
                              children: [
                                Text('FRECUENCIA',
                                    style: TextStyle(
                                        color: textT,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5)),
                                const SizedBox(height: 6),
                                SizedBox(
                                    height: 80,
                                    child: RateGauge(ratePerMin: ratePerMin)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // ── Device ID chip ─────────────────────────────────────
                      if (deviceId != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sensors_rounded,
                                size: 11, color: textT.withValues(alpha: 0.5)),
                            const SizedBox(width: 5),
                            Text(
                              'Maniquí: ${deviceId!.length > 12 ? '${deviceId!.substring(0, 12)}…' : deviceId}',
                              style: TextStyle(
                                  color: textT.withValues(alpha: 0.6),
                                  fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sensors_off_rounded,
                            size: 18, color: textT.withValues(alpha: 0.3)),
                        const SizedBox(width: 10),
                        Text(
                          'Esperando datos del estudiante...',
                          style: TextStyle(
                              color: textT.withValues(alpha: 0.5),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Live metrics row (score / compressions / quality) ───────────────────────
class _LiveMetricsRow extends StatelessWidget {
  final LiveSessionData liveMetrics;
  final Color textT;

  const _LiveMetricsRow({required this.liveMetrics, required this.textT});

  Color _scoreColor(double score) {
    if (score >= 85) return AppColors.green;
    if (score >= 70) return AppColors.amber;
    return AppColors.red;
  }

  Color _qualColor(double pct) {
    if (pct >= 70) return AppColors.green;
    if (pct >= 50) return AppColors.amber;
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _scoreColor(liveMetrics.sessionScore);
    final qualColor = _qualColor(liveMetrics.correctPct);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scoreColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MetricCell(
            value: '${liveMetrics.sessionScore.round()}',
            unit: 'PTS',
            color: scoreColor,
            textT: textT,
          ),
          Container(width: 0.5, height: 28, color: textT.withValues(alpha: 0.15)),
          _MetricCell(
            value: '${liveMetrics.compressionCount}',
            unit: 'COMPRES.',
            color: textT,
            textT: textT,
          ),
          Container(width: 0.5, height: 28, color: textT.withValues(alpha: 0.15)),
          _MetricCell(
            value: '${liveMetrics.correctPct.round()}%',
            unit: 'CALIDAD',
            color: qualColor,
            textT: textT,
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String value;
  final String unit;
  final Color color;
  final Color textT;

  const _MetricCell({
    required this.value,
    required this.unit,
    required this.color,
    required this.textT,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: TextStyle(
            color: textT.withValues(alpha: 0.6),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
