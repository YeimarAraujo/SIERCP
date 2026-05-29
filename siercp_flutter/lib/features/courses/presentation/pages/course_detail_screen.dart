import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:siercp/features/courses/data/models/alert_course.dart';
import 'package:siercp/features/guides/data/models/guide.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/features/guides/presentation/providers/guide_provider.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/core/widgets/guide_progress_card.dart';
import 'package:siercp/core/widgets/guide_list_tile.dart';
import 'package:siercp/core/widgets/category_filter_chips.dart';
import 'package:siercp/core/services/bulk_upload_service.dart';
import 'package:siercp/features/session/data/session_service.dart';
import 'package:siercp/features/users/data/models/user.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    final currentUser  = ref.watch(currentUserProvider);
    final canEdit      = currentUser?.isInstructor == true || currentUser?.isAdmin == true;

    final course = coursesAsync.value?.firstWhere(
      (c) => c.id == widget.courseId,
      orElse: () => CourseModel(
        id: widget.courseId,
        title: '',
        instructorName: '',
        totalModules: 0,
        completedModules: 0,
        certification: '',
      ),
    );

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          final isLandscape =
              MediaQuery.of(context).orientation == Orientation.landscape;
          return [
            SliverAppBar(
              expandedHeight: isLandscape ? 120 : 200,
              pinned: true,
              stretch: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                background: _InstructorHeaderCard(course: course),
              ),
              bottom: TabBar(
                controller: _tabCtrl,
                isScrollable: false,
                labelStyle:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                tabs: const [
                  Tab(
                      icon: Icon(Icons.grid_view_outlined, size: 18),
                      text: 'Módulos'),
                  Tab(
                      icon: Icon(Icons.people_outline, size: 18),
                      text: 'Estudiantes'),
                  Tab(
                      icon: Icon(Icons.how_to_reg_outlined, size: 18),
                      text: 'Asistencia'),
                  Tab(
                      icon: Icon(Icons.sports_score_outlined, size: 18),
                      text: 'Escenarios'),
                  Tab(
                      icon: Icon(Icons.bar_chart_outlined, size: 18),
                      text: 'Stats'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            // ── Tab 1: Guías ─────────────────────────────────────────────────
            _GuidesTab(courseId: widget.courseId, canEdit: canEdit),

            // ── Tab 2: Estudiantes ────────────────────────────────────────────
            _StudentsTab(courseId: widget.courseId, canEdit: canEdit),

            // ── Tab 3: Asistencia ─────────────────────────────────────────────
            _AttendanceTab(courseId: widget.courseId, canEdit: canEdit),

            // ── Tab 4: Escenarios ─────────────────────────────────────────────
            _ScenariosTab(courseId: widget.courseId),

            // ── Tab 5: Estadísticas ───────────────────────────────────────────
            _StatsTab(courseId: widget.courseId),
          ],
        ),
      ),
    );
  }
}

// ─── Header del Instructor ────────────────────────────────────────────────────
class _InstructorHeaderCard extends ConsumerWidget {
  final CourseModel? course;
  const _InstructorHeaderCard({this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final studentsAsync = course != null ? ref.watch(courseStudentsProvider(course!.id)) : null;
    final realCount = studentsAsync?.value?.length ?? course?.studentCount ?? 0;
    final textP  = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0D1B2A), const Color(0xFF162032)]
              : [const Color(0xFFEAF3FF), const Color(0xFFD5E9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, isLandscape ? 40 : 60, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar del instructor
          Container(
            width: isLandscape ? 50 : 72,
            height: isLandscape ? 50 : 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brand, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                course?.instructorName.isNotEmpty == true
                    ? course!.instructorName[0].toUpperCase()
                    : 'P',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Info del instructor y curso
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course?.title ?? 'Cargando...',
                  style: TextStyle(
                    color: textP,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 13, color: AppColors.brand),
                    const SizedBox(width: 4),
                    Text(
                      course?.instructorName ?? '',
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (course?.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    course!.description!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textS, fontSize: 11, height: 1.3),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MetaBadge(
                      icon: Icons.people_outline,
                      label: '$realCount estudiantes',
                    ),
                    const SizedBox(width: 8),
                    if (course?.inviteCode != null)
                      _MetaBadge(
                        icon: Icons.key_rounded,
                        label: course!.inviteCode!,
                        color: AppColors.amber,
                      ),
                  ],
                ),
                if (course?.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Creado ${DateFormat('dd MMM yyyy').format(course!.createdAt!)}',
                    style: TextStyle(color: textS, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MetaBadge({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Tab Guías ────────────────────────────────────────────────────────────────
class _GuidesTab extends ConsumerWidget {
  final String courseId;
  final bool canEdit;
  const _GuidesTab({required this.courseId, required this.canEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user          = ref.watch(currentUserProvider);
    final guidesAsync   = ref.watch(courseGuidesProvider(courseId));
    final progressAsync = ref.watch(userGuideProgressProvider(user?.id ?? ''));
    final selectedCat   = ref.watch(selectedGuideCategoryProvider);

    return guidesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data: (guides) {
        final progressMap = progressAsync.value ?? {};
        final required    = guides.where((g) => g.required).length;
        final completed   = guides.where((g) => progressMap[g.id]?.completed ?? false).length;
        final reqDone     = guides.where((g) => g.required && (progressMap[g.id]?.completed ?? false)).length;
        final summary     = GuideProgressSummary(
          totalGuides: guides.length, completedGuides: completed,
          requiredGuides: required, requiredCompleted: reqDone,
        );
        final filtered = selectedCat == null
            ? guides
            : guides.where((g) => g.category == selectedCat).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(courseGuidesProvider(courseId)),
          color: AppColors.brand,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: GuideProgressCard(summary: summary)),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              const SliverToBoxAdapter(child: CategoryFilterChips()),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_outlined, size: 48,
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          guides.isEmpty ? 'Aún no hay guías en este curso' : 'Sin guías en esta categoría',
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13),
                        ),
                        if (canEdit && guides.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Agregar primera guía'),
                            onPressed: () => context.push('/courses/$courseId/add-guide'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => GuideListTile(
                      guide: filtered[i],
                      progress: progressMap[filtered[i].id],
                      canManage: canEdit,
                      onTap: () => context.push('/guides/${filtered[i].id}/view', extra: filtered[i]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }
}

// ─── Tab Estudiantes ──────────────────────────────────────────────────────────
class _StudentsTab extends ConsumerWidget {
  final String courseId;
  final bool canEdit;
  const _StudentsTab({required this.courseId, required this.canEdit});

  Future<void> _handleBulkUpload(BuildContext context, WidgetRef ref) async {
    final bulkService = ref.read(bulkUploadServiceProvider);
    
    try {
      final students = await bulkService.pickAndParseCsv();
      if (students.isEmpty) return;

      if (!context.mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar Carga Masiva'),
          content: Text('Se procesarán ${students.length} estudiantes. Se crearán cuentas para los nuevos y se inscribirán a todos en este curso.\n\n¿Deseas continuar?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Procesar')),
          ],
        ),
      );

      if (confirm != true || !context.mounted) return;

      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Procesando estudiantes...'),
            ],
          ),
        ),
      );

      final result = await bulkService.processBulkEnrollment(
        courseId: courseId,
        students: students,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Cerrar progreso

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Proceso Finalizado'),
          content: Text('Total: ${result.total}\nCreados: ${result.created}\nInscritos: ${result.enrolled}\nErrores: ${result.errors}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );

    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(courseStudentsProvider(courseId));
    final studentIds = studentsAsync.value?.map((s) => s['studentId'] as String).toList() ?? [];
    final statusAsync = ref.watch(usersStatusProvider(studentIds));
    final statusMap = {for (var u in statusAsync.valueOrNull ?? []) u.id: u};

    final textS = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Column(
      children: [
        if (canEdit)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleBulkUpload(context, ref),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Carga Masiva (CSV)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      side: const BorderSide(color: AppColors.brand),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Implementar creación individual si se desea
                    },
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: const Text('Nuevo Estudiante'),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: studentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
            error:   (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: textS))),
            data: (students) => students.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off_outlined, size: 52,
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text('Sin estudiantes inscritos', style: TextStyle(color: textS, fontSize: 13)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(courseStudentsProvider(courseId)),
                    color: AppColors.brand,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: students.length,
                      itemBuilder: (ctx, i) {
                        final st = students[i];
                        final sid = st['studentId'] as String;
                        return _StudentProgressTile(
                          student: st,
                          courseId: courseId,
                          userStatus: statusMap[sid],
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _StudentProgressTile extends StatelessWidget {
  final Map<String, dynamic> student;
  final String courseId;
  final UserModel? userStatus;
  const _StudentProgressTile({required this.student, required this.courseId, this.userStatus});

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final isDark  = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final border  = theme.colorScheme.outline;
    final textP   = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS   = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT   = theme.textTheme.bodySmall?.color  ?? AppColors.textTertiary;

    final name   = student['studentName'] as String? ?? 'Sin nombre';
    final email  = student['studentEmail'] as String? ?? '';
    final avg    = (student['avgScore'] as num?)?.toDouble() ?? 0.0;
    final count  = (student['sessionCount'] as num?)?.toInt() ?? 0;
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase()
        : 'U';

    final isOnline = userStatus?.isOnline ?? false;
    final lastActive = userStatus?.lastActive;
    final sid = student['studentId'] as String;

    return InkWell(
      onTap: () => context.push('/instructor/students/$sid'),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border.withValues(alpha: 0.4), width: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: isDark ? null : AppShadows.card(false),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isOnline 
                        ? [AppColors.brand, AppColors.cyan]
                        : [AppColors.textSecondary.withValues(alpha: 0.3), AppColors.textSecondary.withValues(alpha: 0.5)],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Center(
                    child: Text(initials,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: TextStyle(color: textP, fontSize: 13, fontWeight: FontWeight.w600)),
                      if (lastActive != null && !isOnline)
                        Text(
                          'Último acceso: ${_formatTimeAgo(lastActive)}',
                          style: TextStyle(color: textT, fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                  if (email.isNotEmpty)
                    Text(email, style: TextStyle(color: textS, fontSize: 11)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _SmallBadge(
                        icon: Icons.sports_score_outlined,
                        label: 'Prom: ${avg.toStringAsFixed(1)}',
                        color: avg >= 70 ? AppColors.green : AppColors.red,
                      ),
                      const SizedBox(width: 6),
                      _SmallBadge(
                        icon: Icons.repeat_rounded,
                        label: '$count sesiones',
                        color: textT,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    return DateFormat('dd/MM').format(dt);
  }
}

// ─── Tab Asistencia ───────────────────────────────────────────────────────────
class _AttendanceTab extends ConsumerStatefulWidget {
  final String courseId;
  final bool canEdit;
  const _AttendanceTab({required this.courseId, required this.canEdit});

  @override
  ConsumerState<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<_AttendanceTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(courseStudentsProvider(widget.courseId));
    final attendanceAsync = ref.watch(courseAttendanceProvider((courseId: widget.courseId, date: _selectedDate)));
    
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;

    return Column(
      children: [
        // Date Selector
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, d MMMM').format(_selectedDate),
                style: TextStyle(color: textP, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              IconButton.filledTonal(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 7)),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                icon: const Icon(Icons.calendar_month_outlined, size: 20),
              ),
            ],
          ),
        ),

        Expanded(
          child: studentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (students) {
              return attendanceAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
                error: (e, _) => Center(child: Text('Error al cargar asistencia: $e')),
                data: (records) {
                  final attendanceMap = {for (var r in records) r['studentId'] as String: r['attended'] as bool};

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: students.length,
                    itemBuilder: (ctx, i) {
                      final st = students[i];
                      final sid = st['studentId'] as String;
                      final sname = st['studentName'] as String;
                      final attended = attendanceMap[sid] ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(sname, style: TextStyle(color: textP, fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(attended ? 'Presente' : 'Ausente', 
                            style: TextStyle(color: attended ? AppColors.green : AppColors.red, fontSize: 11)),
                          trailing: widget.canEdit 
                            ? Checkbox(
                                value: attended,
                                activeColor: AppColors.brand,
                                onChanged: (val) {
                                  ref.read(sessionServiceProvider).markAttendance(
                                    courseId: widget.courseId,
                                    studentId: sid,
                                    studentName: sname,
                                    attended: val ?? false,
                                    date: _selectedDate,
                                  );
                                },
                              )
                            : Icon(attended ? Icons.check_circle : Icons.cancel, 
                                color: attended ? AppColors.green : AppColors.red, size: 20),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _SmallBadge({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: c, fontSize: 10)),
      ],
    );
  }
}

// ─── Tab Escenarios ───────────────────────────────────────────────────────────
class _ScenariosTab extends ConsumerWidget {
  final String courseId;
  const _ScenariosTab({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenariosAsync = ref.watch(scenariosProvider);
    final textS          = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return scenariosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
      error:   (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: textS))),
      data: (scenarios) => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: scenarios.length,
        itemBuilder: (ctx, i) => _ScenarioCard(scenario: scenarios[i]),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final ScenarioModel scenario;
  const _ScenarioCard({required this.scenario});

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final border  = theme.colorScheme.outline;
    final textP   = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS   = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final color   = scenario.categoryColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border.withValues(alpha: 0.4), width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(child: Icon(scenario.icon, size: 22, color: color)),
          ),
          const SizedBox(height: 10),
          Text(scenario.title,
              style: TextStyle(color: textP, fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(scenario.description,
              style: TextStyle(color: textS, fontSize: 10),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(scenario.difficulty,
                style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Estadísticas ─────────────────────────────────────────────────────────
class _StatsTab extends ConsumerWidget {
  final String courseId;
  const _StatsTab({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(courseStudentsProvider(courseId));
    return studentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data: (students) {
        final count    = students.length;
        final withData = students.cast<Map<String, dynamic>>()
            .where((s) => (s['sessionCount'] as num? ?? 0) > 0).length;
        final avgScore = count == 0
            ? 0.0
            : students.cast<Map<String, dynamic>>()
                  .map((s) => (s['avgScore'] as num?)?.toDouble() ?? 0.0)
                  .fold(0.0, (a, b) => a + b) / count;

        // Calificación del Instructor basada en el desempeño de los alumnos
        // Si el promedio es > 85 es Sobresaliente, > 70 es Bueno, < 70 Regular
        final instructorRating = avgScore >= 85 ? 'Sobresaliente' : (avgScore >= 70 ? 'Competente' : 'Por Mejorar');
        final ratingColor = avgScore >= 85 ? AppColors.brand : (avgScore >= 70 ? AppColors.green : AppColors.red);

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Sección de Rendimiento del Instructor
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [ratingColor.withValues(alpha: 0.1), ratingColor.withValues(alpha: 0.05)],
                ),
                border: Border.all(color: ratingColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                children: [
                  const Text('CALIFICACIÓN DEL INSTRUCTOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  Text(instructorRating, style: TextStyle(color: ratingColor, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Basada en el promedio de $avgScore%', style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _StatCard(label: 'Estudiantes inscritos', value: '$count', icon: Icons.people_outline, color: AppColors.brand),
            const SizedBox(height: 12),
            _StatCard(label: 'Con sesiones realizadas', value: '$withData', icon: Icons.sports_score_outlined, color: AppColors.cyan),
            const SizedBox(height: 12),
            _StatCard(label: 'Promedio de calificación', value: '${avgScore.toStringAsFixed(1)}%', icon: Icons.star_outline_rounded, color: AppColors.amber),
            const SizedBox(height: 12),
            _StatCard(label: 'Tasa de participación', value: count == 0 ? '0%' : '${((withData / count) * 100).round()}%', icon: Icons.trending_up_rounded, color: AppColors.green),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final textP   = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS   = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4), width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: textP, fontSize: 24, fontWeight: FontWeight.w800)),
              Text(label, style: TextStyle(color: textS, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
