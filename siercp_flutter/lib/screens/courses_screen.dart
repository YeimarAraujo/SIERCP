import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/alert_course.dart';
import '../providers/session_provider.dart';
import '../providers/auth_provider.dart';
import '../services/admin_service.dart';
import '../services/export_service.dart';
import '../services/session_service.dart';
import '../widgets/section_label.dart';
import 'package:siercp/l10n/app_localizations.dart';

// ─── Main Screen ──────────────────────────────────────────────────────────────
class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  // ─── Create course dialog ─────────────────────────────────────────────────
  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final estudiantesCtrl = TextEditingController();
    
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_circle_outline_rounded, color: AppColors.brand, size: 20),
            const SizedBox(width: 10),
            Text(loc.createCourseTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: loc.courseNameLabel,
                prefixIcon: const Icon(Icons.menu_book_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: loc.courseDescLabel,
                prefixIcon: const Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: estudiantesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: loc.studentsCedulaLabel,
                hintText: loc.studentsCedulaHint,
                prefixIcon: const Icon(Icons.people_alt_outlined),
              ),
            ),
          ],
        ),
        ), // End of SingleChildScrollView
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.cancelBtn)),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 16),
            label: Text(loc.createBtn),
            onPressed: () async {
              try {
                final user = ref.read(currentUserProvider);
                await ref.read(sessionServiceProvider).createCourse(
                  name:           nameCtrl.text.trim(),
                  description:    descCtrl.text.trim(),
                  instructorId:   user?.id ?? '',
                  instructorName: user?.fullName ?? '',
                );
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(coursesProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(children: [
                          const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(loc.createSuccess),
                        ]),
                      ),
                    );
                  }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.red.withValues(alpha: 0.9),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ─── Enroll student by cedula dialog ─────────────────────────────────────
  void _showEnrollDialog(String courseId) {
    final cedulaCtrl = TextEditingController();
    bool loading = false;
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.person_add_outlined, color: AppColors.brand, size: 20),
              const SizedBox(width: 10),
              Text(loc.enrollStudentTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cedulaCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: loc.cedulaLabel,
                  hintText: loc.cedulaHint,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.enrollInfo,
                style: TextStyle(
                  color: Theme.of(ctx).textTheme.bodyMedium?.color,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.cancelBtn)),
            ElevatedButton.icon(
              icon: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.person_add_rounded, size: 16),
              label: Text(loc.enrollBtn),
              onPressed: loading
                  ? null
                  : () async {
                      setSt(() => loading = true);
                        try {
                          final user = ref.read(currentUserProvider);
                          await ref.read(adminServiceProvider).enrollStudentByCedula(
                            courseId:     courseId,
                            cedula:       cedulaCtrl.text.trim(),
                            instructorId: user?.id ?? '',
                          );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ref.invalidate(coursesProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(children: [
                                const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(loc.enrollSuccess),
                              ]),
                            ),
                          );
                        }
                      } catch (e) {
                        setSt(() => loading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppColors.red.withValues(alpha: 0.9),
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Join Course Dialog (Students) ───────────────────────────────────────
  void _showJoinDialog() {
    final codeCtrl = TextEditingController();
    bool loading = false;
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.sensor_door_outlined, color: AppColors.brand, size: 20),
              const SizedBox(width: 10),
              Text(loc.joinCourseTitle),
            ],
          ),
          content: TextField(
            controller: codeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: loc.courseCodeLabel,
              hintText: loc.courseCodeHint,
              prefixIcon: const Icon(Icons.key_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.cancelBtn),
            ),
            ElevatedButton.icon(
              icon: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login_rounded, size: 16),
              label: Text(loc.unirseBtn),
              onPressed: loading
                  ? null
                  : () async {
                      if (codeCtrl.text.trim().isEmpty) return;
                      setSt(() => loading = true);
                      try {
                        final user = ref.read(currentUserProvider);
                        await ref.read(sessionServiceProvider).joinCourse(
                          codeCtrl.text.trim().toUpperCase(),
                          studentId:      user?.id ?? '',
                          studentName:    user?.fullName ?? '',
                          studentEmail:   user?.email ?? '',
                          identificacion: user?.identificacion,
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ref.invalidate(coursesProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(children: [
                                const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(loc.joinSuccess),
                              ]),
                              backgroundColor: AppColors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setSt(() => loading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(loc.joinError(e.toString())),
                              backgroundColor: AppColors.red.withValues(alpha: 0.9),
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync  = ref.watch(coursesProvider);
    final currentUser   = ref.watch(currentUserProvider);
    final loc           = AppLocalizations.of(context)!;
    final isInstructor  = currentUser?.isInstructor ?? false;
    final isAdmin       = currentUser?.isAdmin ?? false;
    final canManage     = isInstructor || isAdmin;

    final theme  = Theme.of(context);
    final textP  = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(coursesProvider),
          color: AppColors.brand,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.coursesTitle,
                              style: TextStyle(
                                color: textP,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 2),
                          Text(
                            canManage
                                ? loc.coursesSubtitleManage
                                : loc.coursesSubtitleStudent,
                            style: TextStyle(color: textS, fontSize: 12),
                          ),
                        ],
                      ),
                      // Botón crear (solo instructores/admin)
                      if (canManage)
                        ElevatedButton.icon(
                          onPressed: _showCreateDialog,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(loc.newBadge),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Courses list
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: SectionLabel(
                    canManage ? loc.activeCourses : loc.myCourses,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: coursesAsync.when(
                  loading: () => const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
                  ),
                  error: (e, __) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(loc.loadCoursesError(e.toString()),
                          style: TextStyle(color: textS)),
                    ),
                  ),
                  data: (courses) => courses.isEmpty
                      ? _EmptyCoursesState(
                          canManage: canManage,
                          onCreate: canManage ? _showCreateDialog : _showJoinDialog,
                        )
                       : Padding(
                           padding: const EdgeInsets.symmetric(horizontal: 16),
                           child: Column(
                             children: courses
                                 .map((c) => _CourseCard(
                                       course: c,
                                       canManage: canManage,
                                       onEnroll: () => _showEnrollDialog(c.id),
                                     ))
                                .toList(),
                          ),
                        ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
      floatingActionButton: !canManage
          ? FloatingActionButton.extended(
              onPressed: _showJoinDialog,
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(loc.joinCourseBtn),
            )
          : null,
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyCoursesState extends StatelessWidget {
  final bool canManage;
  final VoidCallback onCreate;
  const _EmptyCoursesState({required this.canManage, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT = theme.textTheme.bodySmall?.color  ?? AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 52, color: textT.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            canManage
                ? loc.noCoursesCreatedPlain
                : loc.noCoursesJoinedPlain,
            textAlign: TextAlign.center,
            style: TextStyle(color: textS, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            canManage
                ? loc.noCoursesCreatedDesc
                : loc.noCoursesJoinedDesc,
            textAlign: TextAlign.center,
            style: TextStyle(color: textT, fontSize: 12),
          ),
          if (canManage) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(loc.createFirstCourseBtn),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 46)),
            ),
          ] else ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.sensor_door_outlined, size: 16),
              label: Text(loc.joinWithCodeBtn),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 46)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Course card ──────────────────────────────────────────────────────────────
class _CourseCard extends ConsumerWidget {
  final CourseModel course;
  final bool canManage;
  final VoidCallback onEnroll;
  const _CourseCard({
    required this.course,
    required this.canManage,
    required this.onEnroll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP  = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT  = theme.textTheme.bodySmall?.color  ?? AppColors.textTertiary;
    final surface = theme.colorScheme.surface;
    final border  = theme.colorScheme.outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: Column(
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 11, color: textS),
                              const SizedBox(width: 4),
                              Text(course.instructorName,
                                  style: TextStyle(color: textS, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Código de invitación (solo si existe y es instructor/admin)
                    if (course.inviteCode != null && canManage)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.brand.withValues(alpha: 0.25), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.key_rounded,
                                size: 10, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              course.inviteCode!,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'SpaceMono',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: course.progress,
                    backgroundColor: border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.brand),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(loc.completedPct(course.progressPct.toString()),
                        style: TextStyle(color: textT, fontSize: 10)),
                    if (canManage)
                      Row(
                        children: [
                          Icon(Icons.people_outline, size: 11, color: textT),
                          const SizedBox(width: 4),
                          Text(loc.studentsCount(course.studentCount ?? 0),
                              style: TextStyle(color: textT, fontSize: 10)),
                        ],
                      )
                    else
                      Text(loc.cprCertificate,
                          style: TextStyle(color: textT, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),

          // Actions row (solo para instructores/admin)
          if (canManage) ...[
            Divider(color: border, height: 0.5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  // Ver detalle completo
                  _ActionButton(
                    icon: Icons.open_in_new_rounded,
                    label: loc.courseDetail,
                    color: AppColors.accent,
                    onTap: () => context.push('/courses/${course.id}'),
                  ),
                  // Inscribir student
                  _ActionButton(
                    icon: Icons.person_add_outlined,
                    label: loc.courseEnroll,
                    onTap: onEnroll,
                  ),
                  // Exportar notas
                  _ActionButton(
                    icon: Icons.download_outlined,
                    label: loc.courseExport,
                    color: AppColors.green,
                    onTap: () => _exportStudentGrades(context, ref, course),
                  ),
                  // Monitoreo en vivo
                  _ActionButton(
                    icon: Icons.monitor_heart_outlined,
                    label: loc.courseLive,
                    color: AppColors.cyan,
                    onTap: () => context.push('/live/${course.id}'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _exportStudentGrades(
    BuildContext context,
    WidgetRef ref,
    CourseModel course,
  ) async {
    final loc = AppLocalizations.of(context)!;
    try {
      final exportSvc = ref.read(exportServiceProvider);
      await exportSvc.exportCourseGradesCSV(course);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(loc.exportGradesSuccess),
            ]),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.exportGradesError(e.toString())),
            backgroundColor: AppColors.red.withValues(alpha: 0.9),
          ),
        );
      }
    }
  }
}

// ─── Action button inside card ─────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brand;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: c),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    color: c,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Students bottom sheet ────────────────────────────────────────────────────
class _StudentsBottomSheet extends ConsumerWidget {
  final String courseId;
  const _StudentsBottomSheet({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(courseStudentsProvider(courseId));
    final loc = AppLocalizations.of(context)!;
    final theme  = Theme.of(context);
    final textP  = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final bg     = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.groups_2_outlined, color: AppColors.brand, size: 20),
                  const SizedBox(width: 10),
                  Text(loc.courseStudentsTitle,
                      style: TextStyle(
                          color: textP, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Divider(color: border, height: 0.5),
            Expanded(
              child: studentsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: TextStyle(color: textS)),
                ),
                data: (students) => students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_off_outlined, size: 40, color: textS),
                            const SizedBox(height: 12),
                            Text(loc.noStudentsInscribed,
                                style: TextStyle(color: textS, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        itemCount: students.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _StudentTile(student: students[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Student tile ─────────────────────────────────────────────────────────────
class _StudentTile extends ConsumerWidget {
  final dynamic student;
  const _StudentTile({required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP  = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border  = theme.colorScheme.outline;

    // Score color
    final score = student.avgScore as double? ?? 0.0;
    final scoreColor = score >= 85
        ? AppColors.green
        : score >= 70
            ? AppColors.amber
            : AppColors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard
            : AppColors.lightSurface2,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.brand.withValues(alpha: 0.15),
            child: Text(
              student.initials ?? 'E',
              style: const TextStyle(
                color: AppColors.brand,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName ?? loc.studentNameFallback,
                  style: TextStyle(
                      color: textP, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 10, color: textS),
                    const SizedBox(width: 4),
                    Text(student.identificacion ?? '—',
                        style: TextStyle(color: textS, fontSize: 10)),
                    const SizedBox(width: 8),
                    Icon(Icons.history_outlined, size: 10, color: textS),
                    const SizedBox(width: 4),
                    Text(loc.sessionsCountLabel(student.sessionCount ?? 0),
                        style: TextStyle(color: textS, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          // Score badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${score.toStringAsFixed(0)}%',
              style: TextStyle(
                color: scoreColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'SpaceMono',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

