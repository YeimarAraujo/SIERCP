import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/users/data/models/user.dart'
    show CertVerificationStatus;
import 'package:siercp/core/widgets/demo_guard.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/core/widgets/metric_card.dart';
import 'package:siercp/features/devices/presentation/providers/device_provider.dart';
import 'package:siercp/features/notifications/presentation/providers/notification_provider.dart';
import 'package:siercp/features/devices/data/ble_service.dart';
import 'package:siercp/core/providers/connectivity_provider.dart';
import 'package:siercp/core/widgets/xp_strip.dart';
import 'package:siercp/features/users/data/admin_service.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/features/home/presentation/providers/mission_provider.dart';
import 'package:siercp/l10n/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoProvider);
    if (isDemo) return const _DemoHomeView();

    final user = ref.watch(currentUserProvider);
    final orgCtx = ref.watch(orgContextProvider);
    final loc = AppLocalizations.of(context)!;
    // Detecta instructor por asignación directa en curso
    final isInstructorOnCourse =
        ref.watch(isInstructorOnCourseProvider).valueOrNull ?? false;
    // Usar membership como primario; si no, detectar por asignación de curso
    final isAdmin = orgCtx.isAdmin || (user?.isAdmin ?? false);
    final isInstructor = !isAdmin &&
        (orgCtx.isInstructor ||
            (user?.isInstructor ?? false) ||
            isInstructorOnCourse);
    final isUsuario = !isAdmin && !isInstructor;
    final certApproved =
        user?.certVerification == CertVerificationStatus.approved;
    final theme = Theme.of(context);

    // BLE State
    final bleService = ref.watch(bleServiceProvider);
    final isConnected = bleService.isConnected;

    final coursesAsync = ref.watch(coursesProvider);
    final enrolledAsync = ref.watch(enrolledCoursesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _ConnectivityBanner(),
            // ── Fixed Header ────────────────────────────────────────────────────
            _DashboardHeader(user: user),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(recentAlertsProvider);
                  ref.invalidate(coursesProvider);
                  ref.invalidate(enrolledCoursesProvider);
                  ref.invalidate(deviceStatusProvider);
                  ref.invalidate(userStatsProvider);
                },
                color: AppColors.brand,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    // ── Dynamic Dashboard Content ──────────────────────────────────
                    if (isAdmin)
                      _AdminDashboard(ref: ref)
                    else if (isInstructor)
                      _CombinedInstructorDashboard(
                        ref: ref,
                        coursesAsync: coursesAsync,
                        enrolledAsync: enrolledAsync,
                        isConnected: isConnected,
                      )
                    else
                      _StudentDashboard(
                        ref: ref,
                        coursesAsync: coursesAsync,
                        isConnected: isConnected,
                      ),

                    // ── Instructor CTA (solo USUARIO sin cert aprobado) ──────────
                    if (isUsuario && !certApproved)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: _InstructorCtaCard(),
                        ),
                      ),

                    // ── Daily Mission Card ──────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: _DailyMissionCard(),
                      ),
                    ),

                    // ── Calendar Banner ──────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                        child: _CalendarBannerTile(),
                      ),
                    ),

                    if (!isAdmin) ...[
                      // XP / Level strip
                      // SliverToBoxAdapter(
                      //   child: Padding(
                      //     padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      //     child: XpStrip(),
                      //   ),
                      // ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SectionLabel(loc.recentActivity),
                              Icon(Icons.insights_rounded,
                                  size: 18,
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.5)),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverToBoxAdapter(
                          child: Consumer(
                            builder: (context, ref, child) {
                              final stats = ref.watch(userStatsProvider);
                              final screenWidth =
                                  MediaQuery.of(context).size.width;
                              final cols = screenWidth > 600
                                  ? 4
                                  : screenWidth > 400
                                      ? 3
                                      : 2;
                              return GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: cols,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 2,
                                children: [
                                  MetricCard(
                                    label: loc.sessionsToday,
                                    value: '${stats?.sessionsToday ?? 0}',
                                    suffix: '',
                                    status: (stats?.sessionsToday ?? 0) > 0
                                        ? MetricStatus.ok
                                        : MetricStatus.neutral,
                                  ),
                                  MetricCard(
                                    label: loc.avgDepth,
                                    value: stats?.averageDepthMm
                                            .toStringAsFixed(0) ??
                                        '0',
                                    suffix: 'mm',
                                    status: (stats?.averageDepthMm ?? 0) >=
                                                50 &&
                                            (stats?.averageDepthMm ?? 0) <= 60
                                        ? MetricStatus.ok
                                        : MetricStatus.warning,
                                  ),
                                  MetricCard(
                                    label: loc.avgRate,
                                    value:
                                        '${stats?.averageRatePerMin.toInt() ?? 0}',
                                    suffix: '/min',
                                    status: (stats?.averageRatePerMin ?? 0) >=
                                                100 &&
                                            (stats?.averageRatePerMin ?? 0) <=
                                                120
                                        ? MetricStatus.ok
                                        : MetricStatus.warning,
                                  ),
                                  MetricCard(
                                    label: loc.compressionScore,
                                    value:
                                        '${(stats?.averageScore ?? 0).toInt()}',
                                    suffix: '%',
                                    status: (stats?.averageScore ?? 0) >= 85
                                        ? MetricStatus.ok
                                        : MetricStatus.warning,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.brand.withValues(alpha: 0.2),
                ]
              : [AppColors.brandLight, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: AppColors.brand.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    );
  }
}

class _CalendarBannerTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    final accentColor = AppColors.accent;

    return GestureDetector(
      onTap: () => context.push('/calendar'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.18),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                color: accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.calendarBannerTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc.calendarBannerSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

//  Admin dashboard
class _AdminDashboard extends StatelessWidget {
  final WidgetRef ref;
  const _AdminDashboard({required this.ref});

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final loc = AppLocalizations.of(context)!;

    return SliverList(
      delegate: SliverChildListDelegate([
        // ── Admin Stats Summary ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _AdminStatPill(
                  label: loc.totalStudents,
                  value: '...',
                  icon: Icons.people_outline,
                  color: AppColors.brand,
                  stream: ref.watch(orgUsersProvider).whenData((members) =>
                      members
                          .where((m) =>
                              m.role == AppConstants.roleUsuario ||
                              m.role == AppConstants.roleUsuarioProfesional ||
                              m.role == AppConstants.roleUsuarioSST)
                          .length
                          .toString()),
                ),
                const SizedBox(width: 12),
                _AdminStatPill(
                  label: loc.activeManikins,
                  value: '...',
                  icon: Icons.developer_board,
                  color: AppColors.cyan,
                  stream: ref.watch(devicesStreamProvider).whenData((d) =>
                      d.where((x) => x.status == 'online').length.toString()),
                ),
                const SizedBox(width: 12),
                _AdminStatPill(
                  label: loc.alertsToday,
                  value: '...',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.amber,
                  stream: ref
                      .watch(recentAlertsProvider)
                      .whenData((a) => a.length.toString()),
                ),
              ],
            ),
          ),
        ),

        // ── Management Grid ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isLandscape ? 4 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isLandscape ? 1.0 : 1.1,
            children: [
              _AdminTile(
                icon: Icons.people_alt_outlined,
                label: loc.manageUsers,
                sub: loc.adminUsersSub,
                color: AppColors.brand,
                onTap: () => context.go('/admin/users'),
              ),
              _AdminTile(
                icon: Icons.bluetooth_searching_rounded,
                label: loc.manageManikins,
                sub: loc.adminDevicesSub,
                color: AppColors.cyan,
                onTap: () => context.go('/admin/devices'),
              ),
              _AdminTile(
                icon: Icons.menu_book_outlined,
                label: loc.manageCourses,
                sub: loc.adminCoursesSub,
                color: AppColors.accent,
                onTap: () => context.go('/courses'),
              ),
              _AdminTile(
                icon: Icons.bar_chart_outlined,
                label: loc.manageReports,
                sub: loc.adminReportsSub,
                color: AppColors.green,
                onTap: () => context.go('/history'),
              ),
            ],
          ),
        ),

        // ── Role Distribution Chart ──────────────────────────────────────
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _AdminOrgChart(ref: ref),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ── Role donut chart ──────────────────────────────────────────────────────────

class _AdminOrgChart extends StatelessWidget {
  final WidgetRef ref;
  const _AdminOrgChart({required this.ref});

  static const _roleColors = {
    AppConstants.roleInstructor: AppColors.accent,
    AppConstants.roleUsuario: AppColors.brand,
    AppConstants.roleUsuarioProfesional: AppColors.cyan,
    AppConstants.roleUsuarioSST: AppColors.green,
    AppConstants.roleAdmin: AppColors.amber,
  };

  static const _roleLabels = {
    AppConstants.roleInstructor: 'Instructor',
    AppConstants.roleUsuario: 'Participante',
    AppConstants.roleUsuarioProfesional: 'Profesional',
    AppConstants.roleUsuarioSST: 'SST',
    AppConstants.roleAdmin: 'Admin',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final membersAsync = ref.watch(orgUsersProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución de roles',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          membersAsync.when(
            loading: () => const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const SizedBox(
              height: 80,
              child: Center(child: Text('No se pudo cargar')),
            ),
            data: (members) {
              if (members.isEmpty) {
                return SizedBox(
                  height: 80,
                  child: Center(
                    child: Text(
                      'Sin miembros registrados',
                      style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.5)),
                    ),
                  ),
                );
              }

              final counts = <String, int>{};
              for (final m in members) {
                counts[m.role] = (counts[m.role] ?? 0) + 1;
              }

              final sections = counts.entries.map((e) {
                final color = _roleColors[e.key] ?? AppColors.textSecondary;
                return PieChartSectionData(
                  value: e.value.toDouble(),
                  color: color,
                  radius: 48,
                  title: '${e.value}',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }).toList();

              return SizedBox(
                height: 160,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Admin stat pill ────────────────────────────────────────────────────────────

class _AdminStatPill extends ConsumerWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final AsyncValue<String> stream;
  const _AdminStatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.stream,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outline, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stream.when(
                loading: () => Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: theme.textTheme.bodyLarge?.color)),
                error: (_, __) => Text('-',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: theme.textTheme.bodyLarge?.color)),
                data: (v) => Text(v,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: theme.textTheme.bodyLarge?.color)),
              ),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.6))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Role donut chart ──────────────────────────────────────────────────────────
//
//  Combined instructor dashboard: enrolled courses (student) first, then instructor courses
class _CombinedInstructorDashboard extends StatelessWidget {
  final WidgetRef ref;
  final AsyncValue<List> coursesAsync;
  final AsyncValue<List> enrolledAsync;
  final bool isConnected;
  const _CombinedInstructorDashboard({
    required this.ref,
    required this.coursesAsync,
    required this.enrolledAsync,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final userId = currentUser?.id ?? '';
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Instructor courses ──
          _InstructorBody(ref: ref, coursesAsync: coursesAsync),
          // ── Enrolled courses (as student) ──
          enrolledAsync.when(
            loading: () => const _CourseCardShimmer(),
            error: (_, __) => const SizedBox.shrink(),
            data: (enrolled) {
              final studentCourses =
                  enrolled.where((c) => !c.isInstructorOf(userId)).toList();
              if (studentCourses.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Continuar aprendizaje'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ...studentCourses.map((c) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: SizedBox(
                                  width: 250,
                                  child: _StudentCourseHero(
                                    course: c,
                                    isConnected: isConnected,
                                  ),
                                ),
                              )),
                          _SeeAllTile(onTap: () => context.push('/courses')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InstructorDashboard extends StatelessWidget {
  final WidgetRef ref;
  final AsyncValue<List> coursesAsync;
  const _InstructorDashboard({required this.ref, required this.coursesAsync});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: _InstructorBody(ref: ref, coursesAsync: coursesAsync),
    );
  }
}

class _InstructorBody extends ConsumerWidget {
  final WidgetRef ref;
  final AsyncValue<List> coursesAsync;
  const _InstructorBody({required this.ref, required this.coursesAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;
    final currentUser = ref.watch(currentUserProvider);
    final userId = currentUser?.id ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Quick actions
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.add_circle_outline_rounded,
                  label: loc.quickNewCourse,
                  color: AppColors.brand,
                  onTap: () => context.go('/courses'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.groups_2_outlined,
                  label: loc.quickMyStudents,
                  color: AppColors.accent,
                  onTap: () => context.go('/instructor/students'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.download_outlined,
                  label: loc.quickExport,
                  color: AppColors.green,
                  onTap: () => context.go('/history'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Mis cursos (solo donde es instructor)
          const SectionLabel('Gestionar cursos'),
          const SizedBox(height: 12),

          coursesAsync.when(
            loading: () => const _CourseCardShimmer(),
            error: (_, __) => const SizedBox.shrink(),
            data: (courses) {
              final instructorCourses =
                  courses.where((c) => c.isInstructorOf(userId)).toList();
              if (instructorCourses.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surface,
                    border: Border.all(color: border, width: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: isDark ? null : AppShadows.card(false),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.school_outlined, size: 24, color: textS),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          loc.noCoursesCreated,
                          style: TextStyle(color: textS, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/courses'),
                        child: Text(loc.createBtn),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 160,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ...instructorCourses.map((c) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: SizedBox(
                                width: 250,
                                child: _InstructorCourseCard(course: c),
                              ),
                            )),
                        _SeeAllTile(onTap: () => context.push('/courses')),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: isDark ? null : AppShadows.card(false),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(label,
                  style: TextStyle(
                      color: textP, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(color: textS, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

//  Quick action tile (instructor)
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border, width: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textP, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

//  Instructor course card (similar to courses_screen design)
class _InstructorCourseCard extends ConsumerWidget {
  final dynamic course;
  const _InstructorCourseCard({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT = theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    final currentUser = ref.watch(currentUserProvider);
    final sessionsAsync = ref.watch(sessionsHistoryProvider);
    final allSessions = sessionsAsync.value ?? [];
    final courseSessions = allSessions
        .where((s) =>
            s.courseId == course.id && s.status == SessionStatus.completed)
        .toList();
    final approved =
        courseSessions.where((s) => s.metrics?.approved == true).length;
    final requiredCount = course.totalModules > 0 ? course.totalModules : 4;
    final progress =
        requiredCount > 0 ? (approved / requiredCount).clamp(0.0, 1.0) : 0.0;
    final isComplete = approved >= requiredCount;
    final progressColor = isComplete ? AppColors.green : AppColors.brand;

    return GestureDetector(
      onTap: () => context.push('/courses/${course.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isComplete ? AppColors.green : AppColors.brand,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    isComplete
                        ? Icons.emoji_events_rounded
                        : Icons.menu_book_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.people_outline_rounded,
                              size: 12, color: Colors.white60),
                          const SizedBox(width: 4),
                          Text(
                            '${course.studentCount ?? 0} estudiantes',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(
                    isComplete ? AppColors.green : Colors.white),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Progreso general: ${(progress * 100).toInt()}%',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                border: Border.all(color: Colors.white30),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.settings_outlined, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Gestionar curso',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//  Not enrolled card (student)
class _NotEnrolledCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: AppColors.amber, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                loc.noCourseAssigned,
                style: TextStyle(
                    color: textP, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            loc.noCourseAssignedDesc,
            style: TextStyle(color: textS, fontSize: 12),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go('/courses'),
            icon: const Icon(Icons.search_outlined, size: 16),
            label: Text(loc.viewAvailableCourses),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 42),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeeAllTile extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeAllTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        color: Colors.transparent,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_forward_rounded,
                  color: AppColors.accent, size: 24),
              const SizedBox(height: 6),
              Text('Ver todos',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentCourseHero extends ConsumerWidget {
  final dynamic course;
  final bool isConnected;
  const _StudentCourseHero({required this.course, required this.isConnected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    final sessionsAsync = ref.watch(sessionsHistoryProvider);
    final allSessions = sessionsAsync.value ?? <SessionModel>[];
    final courseSessions = allSessions
        .where((s) =>
            s.courseId == course.id && s.status == SessionStatus.completed)
        .toList();
    final totalDone = courseSessions.length;
    final approved =
        courseSessions.where((s) => s.metrics?.approved == true).length;
    final requiredCount = course.totalModules > 0 ? course.totalModules : 4;

    final progress =
        requiredCount > 0 ? (approved / requiredCount).clamp(0.0, 1.0) : 0.0;
    final isComplete = approved >= requiredCount;

    final user = ref.read(currentUserProvider);

    return GestureDetector(
      onTap: () => context.push(
        '/student/course-detail',
        extra: {
          'courseId': course.id,
          'studentId': user?.id ?? '',
          'courseTitle': course.title,
          'instructorName': course.instructorName,
        },
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isComplete ? AppColors.green : AppColors.brand,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    isComplete
                        ? Icons.emoji_events_rounded
                        : Icons.menu_book_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 11, color: Colors.white60),
                          const SizedBox(width: 4),
                          Text(course.instructorName,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isConnected ? AppColors.green : AppColors.amber)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      isConnected
                          ? Icons.bluetooth_connected_rounded
                          : Icons.bluetooth_disabled_rounded,
                      color: isConnected ? AppColors.green : AppColors.amber,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isConnected ? loc.connected : loc.noDeviceMini,
                      style: TextStyle(
                        color: isConnected ? AppColors.green : AppColors.amber,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(
                    isComplete ? AppColors.green : Colors.white),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    loc.approvedAndSessions(approved, requiredCount, totalDone),
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 10)),
                Text('${(progress * 100).toInt()}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'SpaceMono')),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                border: Border.all(color: Colors.white30),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isComplete
                        ? Icons.visibility_outlined
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isComplete
                        ? loc.viewDetail
                        : totalDone > 0
                            ? loc.continueTraining
                            : loc.startTrainingBtn,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCardShimmer extends StatelessWidget {
  const _CourseCardShimmer();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      );
}

class _DashboardHeader extends ConsumerWidget {
  final dynamic user;
  const _DashboardHeader({this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final isAdmin = user?.isAdmin ?? false;
    final orgCtx = ref.watch(orgContextProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          Image.asset(
            theme.brightness == Brightness.dark
                ? 'assets/images/SICAP/webp/logo_sicap_white.webp'
                : 'assets/images/SICAP/webp/logo_sicap.webp',
            height: 40,
            errorBuilder: (_, __, ___) => Icon(
              Icons.favorite,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF1800AD),
              size: 18,
            ),
          ),
          const SizedBox(width: 15),
          const Spacer(),
          Consumer(
            builder: (context, ref, child) {
              final unreadCount = ref.watch(unreadNotificationsCountProvider);
              return IconButton(
                onPressed: () => context.push('/notifications'),
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_none_rounded, size: 26),
                    if (unreadCount > 0)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: AppColors.red, shape: BoxShape.circle),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          _HeaderAvatar(user: user),
        ],
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final dynamic user;
  const _HeaderAvatar({this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/profile'),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.2), width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.brand,
          backgroundImage:
              user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
          child: user?.avatarUrl == null
              ? Text(
                  user?.initials ?? 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _StudentDashboard extends StatelessWidget {
  final WidgetRef ref;
  final AsyncValue<List> coursesAsync;
  final bool isConnected;
  const _StudentDashboard(
      {required this.ref,
      required this.coursesAsync,
      required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SliverToBoxAdapter(
      child: coursesAsync.when(
        loading: () => const _CourseCardShimmer(),
        error: (_, __) => const SizedBox.shrink(),
        data: (courses) => courses.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(loc.continueLearning),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...courses.take(3).map((c) => Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: SizedBox(
                                    width: 250,
                                    child: _StudentCourseHero(
                                      course: c,
                                      isConnected: isConnected,
                                    ),
                                  ),
                                )),
                            _SeeAllTile(onTap: () => context.push('/courses')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _NotEnrolledCard(),
              ),
      ),
    );
  }
}

// ── Instructor CTA ────────────────────────────────────────────────────────────

class _InstructorCtaCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final accentColor = AppColors.accent;

    return GestureDetector(
      onTap: () => context.go('/instructor-apply'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.18),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.school_outlined, color: accentColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¿Quieres ser Instructor?',
                      style: TextStyle(
                          color: textP,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(
                      'Sube tus licencias SST y certificaciones profesionales para operar como instructor',
                      style:
                          TextStyle(color: textS, fontSize: 11, height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DailyMissionCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final mission = ref.watch(todayMissionProvider);
    final completedAsync = ref.watch(missionCompletedProvider);
    final completed = completedAsync.valueOrNull ?? false;
    final isClaimed = ref.watch(missionXpClaimedProvider);
    final accentColor = AppColors.accent;

    return GestureDetector(
      onTap: completed && !isClaimed
          ? () => claimMissionXp(ref).then((_) {
                ref.invalidate(missionCompletedProvider);
              })
          : !completed
              ? () => context.go('/practical')
              : null,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: completed
              ? AppColors.green.withValues(alpha: 0.1)
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: completed
                ? AppColors.green.withValues(alpha: 0.3)
                : accentColor.withValues(alpha: 0.18),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (completed ? AppColors.green : accentColor)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(mission.iconData,
                  size: 24, color: (completed ? AppColors.green : accentColor)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    completed ? 'Misión completada' : 'Misión del día',
                    style: TextStyle(
                      color: completed ? AppColors.green : textS,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mission.title,
                    style: TextStyle(
                      color: textP,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    mission.description,
                    style: TextStyle(color: textS, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (completed && !isClaimed)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.green, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '+${mission.xpReward} XP',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            if (completed && isClaimed)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.green, size: 22),
            if (!completed) const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ConnectivityBanner extends ConsumerWidget {
  const _ConnectivityBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final loc = AppLocalizations.of(context)!;
    if (isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.orange.withValues(alpha: 0.9),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 8),
          Text(
            loc.noInternet,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoHomeView extends ConsumerWidget {
  const _DemoHomeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textS = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Icon(Icons.visibility_outlined,
                  size: 64, color: AppColors.accent.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              Text('Modo Demo',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 8),
              Text(
                'Estás explorando SIERCP en modo invitado.\nCrea una cuenta para acceder a todas las funciones.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: textS),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.person_add),
                label: const Text('Crear Cuenta o Iniciar Sesión'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 40),
              _FeaturePreview(
                icon: Icons.fitness_center,
                title: 'Entrenamiento RCP',
                desc: 'Practica compresiones con maniquíes y simulación',
              ),
              _FeaturePreview(
                icon: Icons.menu_book,
                title: 'Cursos',
                desc: 'Accede a contenido educativo estructurado',
              ),
              _FeaturePreview(
                icon: Icons.history,
                title: 'Historial',
                desc: 'Revisa tu progreso y sesiones anteriores',
              ),
              _FeaturePreview(
                icon: Icons.emoji_events,
                title: 'Logros',
                desc: 'Gana insignias y certificaciones',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturePreview extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _FeaturePreview({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.dividerTheme.color ?? AppColors.cardBorder;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: AppColors.accent.withValues(alpha: 0.6), size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.6))),
                ],
              ),
            ),
            Icon(Icons.lock_outline,
                size: 16, color: AppColors.accent.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
