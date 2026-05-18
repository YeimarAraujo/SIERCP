import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/core/widgets/metric_card.dart';
import 'package:siercp/features/devices/presentation/providers/device_provider.dart';
import 'package:siercp/features/notifications/presentation/providers/notification_provider.dart';
import 'package:siercp/features/devices/data/ble_service.dart';
import 'package:siercp/core/providers/connectivity_provider.dart';
import 'package:siercp/core/widgets/section_label.dart';
import 'package:siercp/l10n/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final loc = AppLocalizations.of(context)!;
    final isAdmin = user?.isAdmin ?? false;
    final isInstructor = user?.isInstructor ?? false;
    final theme = Theme.of(context);

    // BLE State
    final bleService = ref.watch(bleServiceProvider);
    final isConnected = bleService.isConnected;

    final coursesAsync = ref.watch(coursesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _ConnectivityBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(recentAlertsProvider);
                  ref.invalidate(coursesProvider);
                  ref.invalidate(deviceStatusProvider);
                  ref.invalidate(userStatsProvider);
                },
                color: AppColors.brand,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── Header Section ─────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SIERCP'.toUpperCase(),
                                    style: TextStyle(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isAdmin
                                        ? loc.adminDashboardTitle
                                        : loc.welcomeName(user?.firstName ?? loc.user),
                                    style: TextStyle(
                                      color: theme.textTheme.bodyLarge?.color,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Notifications Icon
                            Consumer(
                              builder: (context, ref, child) {
                                final unreadCount =
                                    ref.watch(unreadNotificationsCountProvider);
                                return IconButton(
                                  onPressed: () =>
                                      context.push('/notifications'),
                                  icon: Stack(
                                    children: [
                                      const Icon(
                                          Icons.notifications_none_rounded,
                                          size: 28),
                                      if (unreadCount > 0)
                                        Positioned(
                                          right: 2,
                                          top: 2,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                                color: AppColors.red,
                                                shape: BoxShape.circle),
                                            child: Text(
                                              unreadCount > 9
                                                  ? '9+'
                                                  : '$unreadCount',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            _HeaderAvatar(user: user),
                          ],
                        ),
                      ),
                    ),

                    // ── Dynamic Dashboard Content ──────────────────────────────────
                    if (isAdmin)
                      _AdminDashboard(ref: ref)
                    else if (isInstructor)
                      _InstructorDashboard(
                        ref: ref,
                        coursesAsync: coursesAsync,
                      )
                    else
                      _StudentDashboard(
                        ref: ref,
                        coursesAsync: coursesAsync,
                        isConnected: isConnected,
                      ),

                    // ── Metrics / Activity (Ocultar para Admin si se prefiere) ───
                    if (!isAdmin) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
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
                              final isLandscape =
                                  MediaQuery.of(context).orientation ==
                                      Orientation.landscape;
                              return GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: isLandscape ? 4 : 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: isLandscape ? 1.4 : 1.5,
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
                    ],

                    // ── Calendar Banner ──────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: _CalendarBannerTile(),
                      ),
                    ),

                    // ── AHA 2025 Tips & More ─────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: _TipCard(),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
                  AppColors.accent.withValues(alpha: 0.1)
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lightbulb_outline,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                loc.ahaTipTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            loc.ahaTipBody,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
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

    return GestureDetector(
      onTap: () => context.push('/calendar'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.brand.withValues(alpha: 0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: AppColors.brand, size: 24),
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              size: 22,
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
                  stream: ref.watch(usersStreamProvider).whenData(
                      (u) => u.where((x) => x.isStudent).length.toString()),
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
      ]),
    );
  }
}

class _AdminStatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final AsyncValue<String>? stream;

  const _AdminStatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.stream,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color:
                      theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              stream?.when(
                    data: (v) => Text(v,
                        style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'SpaceMono')),
                    loading: () => const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.brand)),
                    error: (_, __) => Text(value,
                        style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                  ) ??
                  Text(value,
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

//  Instructor dashboard
class _InstructorDashboard extends StatelessWidget {
  final WidgetRef ref;
  final AsyncValue<List> coursesAsync;
  const _InstructorDashboard({required this.ref, required this.coursesAsync});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return SliverToBoxAdapter(
      child: Padding(
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

            // Mis cursos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionLabel(loc.activeCoursesTitle),
                TextButton.icon(
                  onPressed: () => context.go('/courses'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: Text(loc.viewAll),
                ),
              ],
            ),
            const SizedBox(height: 8),

            coursesAsync.when(
              loading: () => const _CourseCardShimmer(),
              error: (_, __) => const SizedBox.shrink(),
              data: (courses) => courses.isEmpty
                  ? Container(
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
                    )
                  : Column(
                      children: courses
                          .take(2)
                          .map((c) => _InstructorCourseCard(course: c))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

//  Admin tile
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
          boxShadow: isDark ? null : AppShadows.card(false),
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

//  Instructor course mini-card
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
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    final studentsAsync = ref.watch(courseStudentsProvider(course.id));

    return GestureDetector(
      onTap: () => context.go('/courses'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border, width: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: isDark ? null : AppShadows.card(false),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.menu_book_outlined,
                  color: AppColors.brand, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title,
                      style: TextStyle(
                          color: textP,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 11, color: textS),
                      const SizedBox(width: 4),
                      studentsAsync.when(
                        loading: () => const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppColors.brand)),
                        error: (_, __) => Text(loc.studentsCount(course.studentCount ?? 0),
                            style: TextStyle(color: textS, fontSize: 11)),
                        data: (list) => Text(loc.studentsCount(list.length),
                            style: TextStyle(color: textS, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: textS),
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isComplete
                ? [const Color(0xFF00695C), const Color(0xFF004D40)]
                : [AppColors.brand, AppColors.brand2],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.elevated(isDark),
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
                      Text(course.instructorName,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11)),
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
                Text(loc.approvedAndSessions(approved, requiredCount, totalDone),
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
                    ...courses.take(2).map((c) => _StudentCourseHero(
                          course: c,
                          isConnected: isConnected,
                        )),
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
