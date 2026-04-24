// ─── student_course_detail_screen.dart ───────────────────────────────────────
// Vista que ve el ALUMNO cuando hace tap en una clase asignada.
// Muestra la lista de módulos con estado (bloqueado / pendiente / completado)
// y al hacer tap en un módulo de teoría abre [StudentModuleViewerScreen].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../models/course_module.dart';
import '../../../services/course_service.dart';

// ─── Providers ────────────────────────────────────────────────────────────────
// Reutilizamos el mismo provider del editor
// (Ahora importado de course_service.dart)

// Provider del progreso del alumno en un curso.
// Retorna un Set<String> de IDs de módulos completados.
final studentModuleProgressProvider =
    FutureProvider.family<Set<String>, _ProgressKey>(
  (ref, key) => ref
      .read(courseServiceProvider)
      .getStudentProgress(key.courseId, key.studentId),
);

class _ProgressKey {
  final String courseId;
  final String studentId;
  const _ProgressKey(this.courseId, this.studentId);
  @override
  bool operator ==(Object other) =>
      other is _ProgressKey &&
      other.courseId == courseId &&
      other.studentId == studentId;

  @override
  int get hashCode => Object.hash(courseId, studentId);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class StudentCourseDetailScreen extends ConsumerWidget {
  final String courseId;
  final String studentId;
  final String courseTitle;
  final String instructorName;

  const StudentCourseDetailScreen({
    super.key,
    required this.courseId,
    required this.studentId,
    required this.courseTitle,
    required this.instructorName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('📚 courseId: "$courseId" | studentId: "$studentId"');
    
    final modulesAsync = ref.watch(courseModulesProvider(courseId));
    final progressAsync = ref.watch(
        studentModuleProgressProvider(_ProgressKey(courseId, studentId)));

    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── AppBar con gradiente ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.brand.withValues(alpha: 0.15),
                      AppColors.brand.withValues(alpha: 0.04),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(courseTitle,
                        style: TextStyle(
                            color: textP,
                            fontSize: 18,
                            fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 13, color: AppColors.brand),
                      const SizedBox(width: 4),
                      Flexible(
                        // ← AÑADIR Flexible aquí
                        child: Text(
                          instructorName,
                          style: const TextStyle(
                              color: AppColors.brand,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow
                              .ellipsis, // ← por si el nombre es largo
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),

          // ── Contenido ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: modulesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.brand)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text('Error: $e')),
              ),
              data: (modules) {
                if (modules.isEmpty) {
                  return _EmptyCourseState();
                }
                return progressAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.brand)),
                  ),
                  error: (e, _) => _ModulesList(
                    modules: modules,
                    completedIds: const {},
                    courseId: courseId,
                    studentId: studentId,
                    ref: ref,
                  ),
                  data: (completedIds) => _ModulesList(
                    modules: modules,
                    completedIds: completedIds,
                    courseId: courseId,
                    studentId: studentId,
                    ref: ref,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lista de módulos ──────────────────────────────────────────────────────────
class _ModulesList extends StatelessWidget {
  final List<CourseModule> modules;
  final Set<String> completedIds;
  final String courseId;
  final String studentId;
  final WidgetRef ref;

  const _ModulesList({
    required this.modules,
    required this.completedIds,
    required this.courseId,
    required this.studentId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    // Calcular progreso
    final completedCount = completedIds.length;
    final totalCount = modules.length;
    final progressPercent = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Barra de progreso global ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outline, width: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tu progreso',
                        style: TextStyle(
                            color: textP,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text('$completedCount / $totalCount módulos',
                        style: TextStyle(color: textS, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    backgroundColor:
                        theme.colorScheme.outline.withValues(alpha: 0.2),
                    color: AppColors.brand,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(progressPercent * 100).toStringAsFixed(0)}% completado',
                  style: const TextStyle(
                      color: AppColors.brand,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // ── Etiqueta sección ───────────────────────────────────────────
          Text('MÓDULOS A COMPLETAR',
              style: TextStyle(
                  color: textS,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),

          // ── Lista de módulos ───────────────────────────────────────────
          ...modules.asMap().entries.map((entry) {
            final i = entry.key;
            final module = entry.value;

            // Regla de desbloqueo: primer módulo siempre desbloqueado,
            // los demás se desbloquean cuando el anterior está completo.
            final isCompleted = completedIds.contains(module.id);
            final previousCompleted =
                i == 0 || completedIds.contains(modules[i - 1].id);
            final isLocked = !previousCompleted && !isCompleted;

            return _StudentModuleCard(
              module: module,
              index: i,
              isCompleted: isCompleted,
              isLocked: isLocked,
              onTap: isLocked
                  ? null
                  : () => _openModule(context, module, isCompleted),
            );
          }),
        ],
      ),
    );
  }

  void _openModule(
      BuildContext context, CourseModule module, bool isCompleted) {
    switch (module.type) {
      case ModuleType.teoria:
        context.push(
          '/student/module-viewer',
          extra: {
            'module': module,
            'courseId': courseId,
            'studentId': studentId,
            'isCompleted': isCompleted,
          },
        );
        break;
      case ModuleType.evaluacion_teorica:
        context.push(
          '/student/quiz',
          extra: {
            'module': module,
            'courseId': courseId,
            'studentId': studentId,
          },
        );
        break;
      case ModuleType.practica_guiada:
        context.push('/student/practica',
            extra: {'module': module, 'courseId': courseId});
        break;
      case ModuleType.certificacion:
        context.push('/student/certificacion',
            extra: {'courseId': courseId, 'studentId': studentId});
        break;
    }
  }
}

// ─── Card de módulo (vista alumno) ────────────────────────────────────────────
class _StudentModuleCard extends StatelessWidget {
  final CourseModule module;
  final int index;
  final bool isCompleted;
  final bool isLocked;
  final VoidCallback? onTap;

  const _StudentModuleCard({
    required this.module,
    required this.index,
    required this.isCompleted,
    required this.isLocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    final typeColor = _colorForType(module.type);
    final statusColor = isCompleted
        ? AppColors.green
        : isLocked
            ? textS.withValues(alpha: 0.4)
            : typeColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isLocked ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(
              color:
                  isCompleted ? AppColors.green.withValues(alpha: 0.3) : border,
              width: isCompleted ? 1.0 : 0.5,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              // ── Número del módulo ───────────────────────────────────
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg),
                    bottomLeft: Radius.circular(AppRadius.lg),
                  ),
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isCompleted)
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.green, size: 22)
                      else if (isLocked)
                        Icon(Icons.lock_rounded,
                            color: textS.withValues(alpha: 0.4), size: 20)
                      else
                        Text('${index + 1}',
                            style: TextStyle(
                                color: typeColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                            textAlign: TextAlign.center),
                    ]),
              ),

              // ── Contenido ───────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            module.type.label,
                            style: TextStyle(
                                color: typeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(module.type.icon,
                            style: const TextStyle(fontSize: 12)),
                      ]),
                      const SizedBox(height: 6),
                      Text(module.title,
                          style: TextStyle(
                              color: textP,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        isCompleted
                            ? '✓ Completado'
                            : isLocked
                                ? '🔒 Completa el módulo anterior'
                                : _subtitle(),
                        style: TextStyle(
                          color: isCompleted
                              ? AppColors.green
                              : isLocked
                                  ? textS.withValues(alpha: 0.5)
                                  : textS,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Chevron ─────────────────────────────────────────────
              if (!isLocked)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: isCompleted ? AppColors.green : typeColor,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    switch (module.type) {
      case ModuleType.teoria:
        final parts = <String>[
          if (module.pdfUrl != null) '📄 PDF',
          if (module.videoUrl != null) '🎬 Video',
          if (module.textContent != null) '📝 Texto',
        ];
        return parts.isEmpty ? 'Ver contenido' : parts.join(' · ');
      case ModuleType.evaluacion_teorica:
        return '${module.questions.length} preguntas · mín. ${module.passingScore}%';
      case ModuleType.practica_guiada:
        return '${module.requiredSessions.length} sesiones requeridas';
      case ModuleType.certificacion:
        return 'Obtener certificado';
    }
  }

  Color _colorForType(ModuleType t) {
    switch (t) {
      case ModuleType.teoria:
        return AppColors.brand;
      case ModuleType.evaluacion_teorica:
        return AppColors.amber;
      case ModuleType.practica_guiada:
        return AppColors.red;
      case ModuleType.certificacion:
        return AppColors.green;
    }
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyCourseState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textS = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.layers_outlined, size: 48, color: textS),
          const SizedBox(height: 16),
          Text('Sin módulos disponibles',
              style: TextStyle(color: textS, fontSize: 14)),
          const SizedBox(height: 6),
          Text('El instructor aún no ha publicado contenido.',
              style: TextStyle(color: textS, fontSize: 12),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
