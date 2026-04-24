import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme.dart';
import '../models/session.dart';
import '../models/alert_course.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';
import '../services/local_storage_service.dart';
import '../services/report_pdf_service.dart';
import '../services/firestore_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.brand, AppColors.accent]),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reportes',
                          style: TextStyle(
                              color: textP,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      Text('Genera y consulta reportes PDF',
                          style: TextStyle(color: textS, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightBg2,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: textS,
                labelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                dividerHeight: 0,
                tabs: const [
                  Tab(text: 'Generar Reporte'),
                  Tab(text: 'Reportes Guardados'),
                ],
              ),
            ),

            // Body
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _GenerateTab(
                    generating: _generating,
                    onGenerate: _handleGenerate,
                  ),
                  const _SavedReportsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGenerate(
    String type, {
    String? courseId,
    String? courseName,
    String? studentId,
    String? studentName,
  }) async {
    if (_generating) return;
    setState(() => _generating = true);

    try {
      final reportSvc = ref.read(reportPdfServiceProvider);
      final firestoreSvc = ref.read(firestoreServiceProvider);
      final localSvc = ref.read(localStorageServiceProvider);
      ReportRecord record;

      if (type == 'course' && courseId != null) {
        // Reporte consolidado de curso
        final students = await firestoreSvc.getCourseStudents(courseId);
        localSvc.saveCourseEnrollments(courseId, students);

        final studentSessionsMap = <String, List<SessionModel>>{};
        for (final st in students) {
          final sid = st['studentId'] as String? ?? '';
          if (sid.isNotEmpty) {
            final sessions = await firestoreSvc.getStudentSessions(sid);
            final courseSessions =
                sessions.where((s) => s.courseId == courseId).toList();
            studentSessionsMap[sid] = courseSessions;
            localSvc.saveSessions(courseSessions);
          }
        }

        final course = localSvc.getCourse(courseId) ??
            CourseModel(
                id: courseId,
                title: courseName ?? '',
                instructorName: '',
                totalModules: 0,
                completedModules: 0,
                certification: '');

        record = await reportSvc.generateCourseReport(
          course: course,
          students: students,
          studentSessions: studentSessionsMap,
        );
      } else if (type == 'student' && studentId != null && courseId != null) {
        // Reporte individual de estudiante en un curso
        final sessions = await firestoreSvc.getStudentSessions(studentId);
        final courseSessions =
            sessions.where((s) => s.courseId == courseId).toList();
        localSvc.saveSessions(courseSessions);

        record = await reportSvc.generateStudentCourseReport(
          studentId: studentId,
          studentName: studentName ?? 'Estudiante',
          courseId: courseId,
          courseName: courseName ?? 'Curso',
          sessions: courseSessions,
        );
      } else {
        throw Exception('Parámetros insuficientes para generar el reporte.');
      }

      if (mounted) {
        _tabCtrl.animateTo(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Reporte generado: ${record.title}'),
            backgroundColor: AppColors.green,
            action: SnackBarAction(
              label: 'Abrir',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(record.filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }
}

// ─── Tab: Generar Reporte ──────────────────────────────────────────────────────
class _GenerateTab extends ConsumerWidget {
  final bool generating;
  final Future<void> Function(String type,
      {String? courseId,
      String? courseName,
      String? studentId,
      String? studentName}) onGenerate;

  const _GenerateTab({required this.generating, required this.onGenerate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;
    final user = ref.watch(currentUserProvider);
    final canGenerate = user?.isInstructor == true || user?.isAdmin == true;

    return coursesAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.brand)),
      error: (e, _) =>
          Center(child: Text('Error: $e', style: TextStyle(color: textS))),
      data: (courses) {
        if (courses.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.folder_off_outlined,
                  size: 48, color: textS.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('No hay cursos disponibles',
                  style: TextStyle(color: textS, fontSize: 13)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: courses.length,
          itemBuilder: (ctx, i) {
            final course = courses[i];
            return _CourseReportCard(
              course: course,
              isDark: isDark,
              surface: surface,
              border: border,
              textP: textP,
              textS: textS,
              generating: generating,
              canGenerate: canGenerate,
              onGenerateCourse: () => onGenerate('course',
                  courseId: course.id, courseName: course.title),
              onGenerateStudent: (sid, sname) => onGenerate('student',
                  courseId: course.id,
                  courseName: course.title,
                  studentId: sid,
                  studentName: sname),
            );
          },
        );
      },
    );
  }
}

class _CourseReportCard extends ConsumerStatefulWidget {
  final CourseModel course;
  final bool isDark;
  final Color surface, border, textP, textS;
  final bool generating, canGenerate;
  final VoidCallback onGenerateCourse;
  final void Function(String studentId, String studentName) onGenerateStudent;

  const _CourseReportCard({
    required this.course,
    required this.isDark,
    required this.surface,
    required this.border,
    required this.textP,
    required this.textS,
    required this.generating,
    required this.canGenerate,
    required this.onGenerateCourse,
    required this.onGenerateStudent,
  });

  @override
  ConsumerState<_CourseReportCard> createState() => _CourseReportCardState();
}

class _CourseReportCardState extends ConsumerState<_CourseReportCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.surface,
        border:
            Border.all(color: widget.border.withValues(alpha: 0.4), width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: widget.isDark ? null : AppShadows.card(false),
      ),
      child: Column(
        children: [
          // Course header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.brand, AppColors.accent]),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.school_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.course.title,
                        style: TextStyle(
                            color: widget.textP,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text('${widget.course.studentCount ?? 0} estudiantes',
                        style: TextStyle(color: widget.textS, fontSize: 11)),
                  ],
                )),
                if (widget.canGenerate)
                  widget.generating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.brand))
                      : IconButton(
                          icon: const Icon(Icons.picture_as_pdf_rounded,
                              color: AppColors.brand, size: 20),
                          tooltip: 'Reporte consolidado del curso',
                          onPressed: widget.onGenerateCourse,
                        ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.textS, size: 20),
              ]),
            ),
          ),

          // Estudiantes expandidos
          if (_expanded && widget.canGenerate)
            _StudentsList(
              courseId: widget.course.id,
              textP: widget.textP,
              textS: widget.textS,
              generating: widget.generating,
              onGenerate: widget.onGenerateStudent,
            ),
        ],
      ),
    );
  }
}

class _StudentsList extends ConsumerWidget {
  final String courseId;
  final Color textP, textS;
  final bool generating;
  final void Function(String studentId, String studentName) onGenerate;

  const _StudentsList({
    required this.courseId,
    required this.textP,
    required this.textS,
    required this.generating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(courseStudentsProvider(courseId));

    return studentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.brand)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $e', style: TextStyle(color: textS, fontSize: 11)),
      ),
      data: (students) {
        if (students.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Sin estudiantes inscritos',
                style: TextStyle(color: textS, fontSize: 12)),
          );
        }
        return Column(
          children: [
            const Divider(height: 1),
            ...students.cast<Map<String, dynamic>>().map((st) {
              final name = st['studentName'] as String? ?? 'Sin nombre';
              final sid = st['studentId'] as String? ?? '';
              final avg = (st['avgScore'] as num?)?.toDouble() ?? 0.0;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(name,
                    style: TextStyle(
                        color: textP,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                subtitle: Text('Promedio: ${avg.toStringAsFixed(1)}%',
                    style: TextStyle(color: textS, fontSize: 10)),
                trailing: generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: AppColors.brand))
                    : IconButton(
                        icon: const Icon(Icons.description_outlined,
                            color: AppColors.cyan, size: 18),
                        tooltip: 'Generar reporte de $name',
                        onPressed: () => onGenerate(sid, name),
                      ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ─── Tab: Reportes Guardados ──────────────────────────────────────────────────
class _SavedReportsTab extends ConsumerWidget {
  const _SavedReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localSvc = ref.read(localStorageServiceProvider);
    final reports = localSvc.getAllReports();
    final theme = Theme.of(context);
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    if (reports.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.folder_open_outlined,
              size: 52, color: textS.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No hay reportes guardados',
              style: TextStyle(color: textS, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Genera uno desde la pestaña anterior',
              style: TextStyle(color: textS.withValues(alpha: 0.6), fontSize: 11)),
        ]),
      );
    }

    // Agrupar reportes por tipo
    final courseReports = reports.where((r) => r.type == 'course').toList();
    final studentReports = reports.where((r) => r.type == 'student').toList();

    return RefreshIndicator(
      onRefresh: () async => (context as Element).markNeedsBuild(),
      color: AppColors.brand,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (courseReports.isNotEmpty) ...[
            _buildSectionHeader('CURSOS (GRUPALES)', Icons.groups_rounded),
            ...courseReports.map((r) => _ReportTile(report: r)),
            const SizedBox(height: 20),
          ],
          if (studentReports.isNotEmpty) ...[
            _buildSectionHeader('ESTUDIANTES (INDIVIDUAL)', Icons.person_rounded),
            ...studentReports.map((r) => _ReportTile(report: r)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.brand),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(thickness: 0.5)),
        ],
      ),
    );
  }
}

class _ReportTile extends ConsumerWidget {
  final ReportRecord report;
  const _ReportTile({required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkCard : Colors.white;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.dividerTheme.color ?? AppColors.cardBorder;
    
    final localSvc = ref.read(localStorageServiceProvider);
    final exists = File(report.filePath).existsSync();
    final color = report.type == 'course' ? AppColors.brand : AppColors.cyan;
    final icon = report.type == 'course' ? Icons.groups_outlined : Icons.person_outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border.withValues(alpha: 0.4), width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(report.title,
            style: TextStyle(color: textP, fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${DateFormat('dd MMM yyyy · HH:mm').format(report.generatedAt)} · ${report.sessionCount} sesiones',
          style: TextStyle(color: textS, fontSize: 10),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (report.averageScore != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (report.averageScore! >= 70 ? AppColors.green : AppColors.red).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${report.averageScore!.toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: report.averageScore! >= 70 ? AppColors.green : AppColors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: textS),
            onSelected: (v) async {
              if (v == 'open' && exists) {
                await OpenFilex.open(report.filePath);
              } else if (v == 'share' && exists) {
                await Share.shareXFiles([XFile(report.filePath, mimeType: 'application/pdf')],
                    subject: report.title);
              } else if (v == 'delete') {
                await localSvc.deleteReport(report.id);
                if (exists) {
                  try {
                    await File(report.filePath).delete();
                  } catch (_) {}
                }
                // Refrescar UI - Esto asume que el widget padre se reconstruirá
                // En una app real usaríamos un StateNotifierProvider para el historial de reportes.
              }
            },
            itemBuilder: (_) => [
              if (exists)
                const PopupMenuItem(
                    value: 'open',
                    child: Row(children: [
                      Icon(Icons.open_in_new, size: 16, color: AppColors.brand),
                      SizedBox(width: 8),
                      Text('Abrir'),
                    ])),
              if (exists)
                const PopupMenuItem(
                    value: 'share',
                    child: Row(children: [
                      Icon(Icons.share_outlined, size: 16, color: AppColors.cyan),
                      SizedBox(width: 8),
                      Text('Compartir'),
                    ])),
              const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 16, color: AppColors.red),
                    SizedBox(width: 8),
                    Text('Eliminar'),
                  ])),
            ],
          ),
        ]),
      ),
    );
  }
}
