import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../models/session.dart';
import '../services/session_service.dart';
import '../widgets/metric_card.dart';
import '../widgets/alert_card.dart';
import '../widgets/section_label.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;
    final isInstructor = user?.isInstructor ?? false;
    final alertsAsync = ref.watch(recentAlertsProvider);
    final coursesAsync = ref.watch(coursesProvider);
    final deviceAsync = ref.watch(deviceStatusProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recentAlertsProvider);
            ref.invalidate(coursesProvider);
            ref.invalidate(deviceStatusProvider);
          },
          color: AppColors.brand,
          child: CustomScrollView(
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
                          Text(
                            isAdmin
                                ? 'Panel de Control'
                                : isInstructor
                                    ? 'Bienvenido, ${user?.firstName ?? 'Instructor'}'
                                    : 'Bienvenido, ${user?.firstName ?? ''}',
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            isAdmin
                                ? 'Administrador SIERCP'
                                : isInstructor
                                    ? 'Instructor'
                                    : (user?.role ?? 'ESTUDIANTE'),
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.brand,
                          child: Text(
                            user?.initials ?? 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Vistas por rol ─────────────────────────────────────────────
              if (isAdmin)
                _AdminDashboard(ref: ref)
              else if (isInstructor)
                _InstructorDashboard(ref: ref, coursesAsync: coursesAsync)
              else ...[
                // ── ESTUDIANTE: Per-course training cards ────────────────────
                SliverToBoxAdapter(
                  child: coursesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (courses) => courses.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionLabel('Tus cursos activos'),
                                const SizedBox(height: 8),
                                ...courses.map((c) => _StudentCourseHero(
                                      course: c,
                                      deviceAsync: deviceAsync,
                                    )),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _NotEnrolledCard(),
                          ),
                  ),
                ),

                // Métricas históricas
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: const SectionLabel('Resumen histórico'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: isLandscape ? 1.4 : 1.6,
                          children: [
                            MetricCard(
                              label: 'Sesiones hoy',
                              value: '${stats?.sessionsToday ?? 0}',
                              suffix: '',
                              status: (stats?.sessionsToday ?? 0) > 0
                                  ? MetricStatus.ok
                                  : MetricStatus.neutral,
                            ),
                            MetricCard(
                              label: 'Prof. promedio',
                              value: stats?.averageDepthMm.toStringAsFixed(0) ??
                                  '0',
                              suffix: 'mm',
                              status: (stats?.averageDepthMm ?? 0) >= 50 &&
                                      (stats?.averageDepthMm ?? 0) <= 60
                                  ? MetricStatus.ok
                                  : MetricStatus.warning,
                              hint: 'Rango: 50–60mm',
                            ),
                            MetricCard(
                              label: 'Frecuencia media',
                              value:
                                  stats?.averageRatePerMin.toStringAsFixed(0) ??
                                      '0',
                              suffix: '/min',
                              status: (stats?.averageRatePerMin ?? 0) >= 100 &&
                                      (stats?.averageRatePerMin ?? 0) <= 120
                                  ? MetricStatus.ok
                                  : MetricStatus.warning,
                              hint: 'Meta: 100–120',
                            ),
                            MetricCard(
                              label: '% Compresiones OK',
                              value:
                                  (stats?.averageScore ?? 0).toStringAsFixed(0),
                              suffix: '%',
                              status: (stats?.averageScore ?? 0) >= 85
                                  ? MetricStatus.ok
                                  : MetricStatus.warning,
                              hint: 'Meta: 85%+',
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Alertas (todos los roles)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: SectionLabel(
                      isAdmin ? 'Alertas del sistema' : 'Últimas alertas'),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: alertsAsync.when(
                    loading: () => const Center(
                      child: SizedBox(
                        height: 40,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.brand),
                      ),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (alerts) => Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: alerts.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Icon(Icons.notifications_none_outlined,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                                      size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Sin alertas recientes.',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: alerts
                                  .take(4)
                                  .map((a) => AlertCard(alert: a))
                                  .toList(),
                            ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
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
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverGrid.count(
        crossAxisCount: isLandscape ? 4 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: isLandscape ? 1.0 : 1.1,
        children: [
          _AdminTile(
            icon: Icons.people_alt_outlined,
            label: 'Usuarios',
            sub: 'Instructores y Estudiantes',
            color: AppColors.brand,
            onTap: () => context.go('/admin/users'),
          ),
          _AdminTile(
            icon: Icons.bluetooth_searching_rounded,
            label: 'Maniquíes',
            sub: 'Estado de conexión',
            color: AppColors.cyan,
            onTap: () => context.go('/admin/devices'),
          ),
          _AdminTile(
            icon: Icons.menu_book_outlined,
            label: 'Cursos',
            sub: 'Gestionar programas',
            color: AppColors.accent,
            onTap: () => context.go('/courses'),
          ),
          _AdminTile(
            icon: Icons.bar_chart_outlined,
            label: 'Reportes',
            sub: 'Estadísticas globales',
            color: AppColors.green,
            onTap: () => context.go('/history'),
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
                    label: 'Nuevo Curso',
                    color: AppColors.brand,
                    onTap: () => context.go('/courses'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.groups_2_outlined,
                    label: 'Mis Estudiantes',
                    color: AppColors.accent,
                    onTap: () => context.go('/courses'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.download_outlined,
                    label: 'Exportar',
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
                const SectionLabel('Mis cursos activos'),
                TextButton.icon(
                  onPressed: () => context.go('/courses'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text('Ver todos'),
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
                              'Aún no has creado ningún curso. Crea el primero.',
                              style: TextStyle(color: textS, fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/courses'),
                            child: const Text('Crear'),
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
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    final studentsAsync = ref.watch(courseStudentsProvider(course.id));
    final count = studentsAsync.value?.length ?? course.studentCount ?? 0;

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
                        error: (_, __) => Text('${course.studentCount ?? 0}',
                            style: TextStyle(color: textS, fontSize: 11)),
                        data: (list) => Text('${list.length} estudiantes',
                            style: TextStyle(color: textS, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: textS),
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
                'Sin curso asignado',
                style: TextStyle(
                    color: textP, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tu instructor aún no te ha inscrito en ningún curso. Contacta a tu instructor para unirte a un programa de entrenamiento RCP.',
            style: TextStyle(color: textS, fontSize: 12),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go('/courses'),
            icon: const Icon(Icons.search_outlined, size: 16),
            label: const Text('Ver cursos disponibles'),
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
  final AsyncValue<DeviceStatusData> deviceAsync;
  const _StudentCourseHero({required this.course, required this.deviceAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = deviceAsync.value?.isConnected ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Per-course progress
    final sessionsAsync = ref.watch(sessionsHistoryProvider);
    final allSessions = sessionsAsync.value ?? <SessionModel>[];
    final courseSessions = allSessions
        .where((s) =>
            s.courseId == course.id && s.status == SessionStatus.completed)
        .toList();
    final totalDone = courseSessions.length;
    final approved =
        courseSessions.where((s) => s.metrics?.approved == true).length;
    final required = course.totalModules > 0 ? course.totalModules : 4;
    final progress = required > 0 ? (approved / required).clamp(0.0, 1.0) : 0.0;
    final isComplete = approved >= required;

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
                // Device badge
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
                      isConnected ? 'Conectado' : 'Sin disp.',
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

            // Progress bar
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
                Text('$approved/$required aprobadas · $totalDone sesiones',
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

            // CTA
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
                        ? 'Ver detalle'
                        : totalDone > 0
                            ? 'Continuar entrenamiento'
                            : 'Comenzar entrenamiento',
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
