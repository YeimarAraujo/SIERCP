import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/courses/data/models/alert_course.dart';
import 'package:siercp/features/courses/data/models/course_module.dart';
import 'package:siercp/features/courses/data/course_service.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/core/services/firestore_service.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _instructorModulesProvider =
    FutureProvider.family<List<CourseModule>, String>(
  (ref, courseId) => ref.read(courseServiceProvider).getModules(courseId),
);

// ─────────────────────────────────────────────────────────────────────────────
class InstructorCourseManagementScreen extends ConsumerStatefulWidget {
  final String courseId;
  const InstructorCourseManagementScreen({super.key, required this.courseId});

  @override
  ConsumerState<InstructorCourseManagementScreen> createState() =>
      _InstructorCourseManagementScreenState();
}

class _InstructorCourseManagementScreenState
    extends ConsumerState<InstructorCourseManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    final course = coursesAsync.value?.firstWhere(
      (c) => c.id == widget.courseId,
      orElse: () => CourseModel(
        id: widget.courseId,
        title: 'Cargando...',
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
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            stretch: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                tooltip: 'Editar curso',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => context.push('/course-editor/${widget.courseId}'),
              ),
              IconButton(
                tooltip: 'Monitor en vivo',
                icon: const Icon(Icons.monitor_heart_outlined, size: 20,
                    color: AppColors.cyan),
                onPressed: () => context.push('/live/${widget.courseId}'),
              ),
              PopupMenuButton<String>(
                onSelected: (val) => _onMenuAction(context, val, course),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'archive',
                    child: Row(children: [
                      Icon(Icons.archive_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Archivar curso', style: TextStyle(fontSize: 13)),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'qr',
                    child: Row(children: [
                      Icon(Icons.qr_code_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Mostrar QR', style: TextStyle(fontSize: 13)),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(children: [
                      Icon(Icons.download_outlined, size: 16,
                          color: AppColors.green),
                      SizedBox(width: 8),
                      Text('Exportar notas',
                          style: TextStyle(fontSize: 13, color: AppColors.green)),
                    ]),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _CourseHeader(course: course),
            ),
            bottom: TabBar(
              controller: _tab,
              isScrollable: false,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              tabs: const [
                Tab(icon: Icon(Icons.layers_outlined, size: 18), text: 'Módulos'),
                Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Estudiantes'),
                Tab(icon: Icon(Icons.how_to_reg_outlined, size: 18), text: 'Asistencia'),
                Tab(icon: Icon(Icons.bar_chart_outlined, size: 18), text: 'Progreso'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _ModulesTab(courseId: widget.courseId),
            _StudentsManagementTab(courseId: widget.courseId, course: course),
            _AttendanceTab(courseId: widget.courseId),
            _ProgressTab(courseId: widget.courseId),
          ],
        ),
      ),
    );
  }

  void _onMenuAction(
      BuildContext context, String action, CourseModel? course) {
    switch (action) {
      case 'archive':
        _archiveCourse(context);
      case 'qr':
        if (course?.inviteCode != null) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Código QR del curso'),
              content: Text('Código: ${course!.inviteCode}'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar')),
              ],
            ),
          );
        }
      case 'export':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Exportando notas... (próximamente)')),
        );
    }
  }

  Future<void> _archiveCourse(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final router    = GoRouter.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archivar curso'),
        content:
            const Text('El curso quedará inactivo. ¿Deseas continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateCourse(widget.courseId, {'isActive': false});
      ref.invalidate(coursesProvider);
      if (mounted) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Curso archivado')));
        router.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.red));
      }
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _CourseHeader extends ConsumerWidget {
  final CourseModel? course;
  const _CourseHeader({this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    final studentsAsync = course != null
        ? ref.watch(courseStudentsProvider(course!.id))
        : null;
    final studentCount = studentsAsync?.value?.length ?? course?.studentCount ?? 0;

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
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 8),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.brand, Color(0xFF6d4aff)]),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Center(
              child: Icon(Icons.menu_book_outlined,
                  color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(course?.title ?? '',
                    style: TextStyle(
                        color: textP,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(course?.instructorName ?? '',
                    style: TextStyle(color: textS, fontSize: 12)),
                const SizedBox(height: 6),
                Row(children: [
                  _Chip(Icons.people_outline, '$studentCount alumnos'),
                  const SizedBox(width: 8),
                  _Chip(Icons.layers_outlined,
                      '${course?.totalModules ?? 0} módulos'),
                  if (course?.inviteCode != null) ...[
                    const SizedBox(width: 8),
                    _Chip(Icons.key_rounded, course!.inviteCode!,
                        color: AppColors.cyan),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _Chip(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: c),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: c, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Tab 1: Módulos ────────────────────────────────────────────────────────────
class _ModulesTab extends ConsumerStatefulWidget {
  final String courseId;
  const _ModulesTab({required this.courseId});

  @override
  ConsumerState<_ModulesTab> createState() => _ModulesTabState();
}

class _ModulesTabState extends ConsumerState<_ModulesTab> {
  IconData _iconForType(ModuleType t) {
    switch (t) {
      case ModuleType.teoria:
        return Icons.menu_book_outlined;
      case ModuleType.evaluacion_teorica:
        return Icons.quiz_outlined;
      case ModuleType.practica_guiada:
        return Icons.monitor_heart_outlined;
      case ModuleType.certificacion:
        return Icons.workspace_premium_outlined;
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

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(_instructorModulesProvider(widget.courseId));
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddModuleSheet(context),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar módulo'),
      ),
      body: modulesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.brand)),
        error: (e, _) => Center(
            child: Text('Error: $e', style: TextStyle(color: textS))),
        data: (modules) => modules.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.layers_outlined,
                        size: 52,
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('Sin módulos todavía',
                        style: TextStyle(color: textS, fontSize: 13)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddModuleSheet(context),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Crear primer módulo'),
                    ),
                  ],
                ),
              )
            : ReorderableListView.builder(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: modules.length,
                onReorder: (oldIndex, newIndex) =>
                    _reorder(modules, oldIndex, newIndex),
                itemBuilder: (ctx, i) {
                  final m = modules[i];
                  final color = _colorForType(m.type);
                  return Dismissible(
                    key: ValueKey(m.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: AppColors.red,
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white),
                    ),
                    confirmDismiss: (_) => _confirmDelete(context, m.title),
                    onDismissed: (_) => _deleteModule(m),
                    child: Container(
                      key: ValueKey('${m.id}_card'),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(
                            color: theme.colorScheme.outline,
                            width: 0.5),
                        borderRadius:
                            BorderRadius.circular(AppRadius.lg),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(_iconForType(m.type),
                              color: color, size: 22),
                        ),
                        title: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('M${i + 1}',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(m.title,
                                style: TextStyle(
                                    color: textP,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(m.type.label,
                              style: TextStyle(
                                  color: color, fontSize: 11)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Editar',
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18),
                              onPressed: () =>
                                  _showEditModuleSheet(context, m),
                            ),
                            const Icon(Icons.drag_handle_rounded,
                                size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar módulo'),
            content: Text('¿Eliminar "$title"? Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteModule(CourseModule m) async {
    try {
      await ref
          .read(courseServiceProvider)
          .deleteModule(widget.courseId, m.id);
      ref.invalidate(_instructorModulesProvider(widget.courseId));
      ref.invalidate(coursesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _reorder(
      List<CourseModule> modules, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final ids = modules.map((m) => m.id).toList();
    ids.insert(newIndex, ids.removeAt(oldIndex));
    try {
      await ref
          .read(courseServiceProvider)
          .reorderModules(widget.courseId, ids);
      ref.invalidate(_instructorModulesProvider(widget.courseId));
    } catch (_) {}
  }

  void _showAddModuleSheet(BuildContext context) {
    _ModuleFormSheet.show(
      context,
      courseId: widget.courseId,
      onSaved: () => ref.invalidate(_instructorModulesProvider(widget.courseId)),
    );
  }

  void _showEditModuleSheet(BuildContext context, CourseModule module) {
    _ModuleFormSheet.show(
      context,
      courseId: widget.courseId,
      module: module,
      onSaved: () => ref.invalidate(_instructorModulesProvider(widget.courseId)),
    );
  }
}

// ── Formulario de módulo (crear/editar) ───────────────────────────────────────
class _ModuleFormSheet {
  static void show(
    BuildContext context, {
    required String courseId,
    CourseModule? module,
    required VoidCallback onSaved,
  }) {
    final titleCtrl =
        TextEditingController(text: module?.title ?? '');
    ModuleType selectedType = module?.type ?? ModuleType.teoria;
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(builder: (ctx, setSt) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  module == null ? 'Nuevo módulo' : 'Editar módulo',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título del módulo',
                    prefixIcon: Icon(Icons.title_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tipo de módulo',
                    style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ModuleType.values.map((t) {
                    final selected = selectedType == t;
                    return FilterChip(
                      selected: selected,
                      label: Text(t.label),
                      onSelected: (_) => setSt(() => selectedType = t),
                      selectedColor: AppColors.brand.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.brand,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) return;
                          setSt(() => loading = true);
                          try {
                            final svc =
                                // ignore: use_build_context_synchronously
                                ProviderScope.containerOf(ctx)
                                    .read(courseServiceProvider);
                            if (module == null) {
                              await svc.createModule(
                                courseId: courseId,
                                title: title,
                                type: selectedType,
                                config: const {},
                              );
                            } else {
                              await svc.updateModule(
                                courseId,
                                module.id,
                                title: title,
                                type: selectedType,
                                config: module.pdfUrl != null
                                    ? {'pdfUrl': module.pdfUrl}
                                    : const {},
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            onSaved();
                          } catch (e) {
                            setSt(() => loading = false);
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(module == null ? 'Crear módulo' : 'Guardar cambios'),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

// ── Tab 2: Estudiantes ────────────────────────────────────────────────────────
class _StudentsManagementTab extends ConsumerStatefulWidget {
  final String courseId;
  final CourseModel? course;
  const _StudentsManagementTab(
      {required this.courseId, required this.course});

  @override
  ConsumerState<_StudentsManagementTab> createState() =>
      _StudentsManagementTabState();
}

class _StudentsManagementTabState
    extends ConsumerState<_StudentsManagementTab> {
  void _showAddStudentDialog() {
    final cedCtrl = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.person_add_outlined, color: AppColors.brand, size: 20),
            SizedBox(width: 10),
            Text('Agregar estudiante'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cedCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cédula del estudiante',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      final cedula = cedCtrl.text.trim();
                      if (cedula.isEmpty) return;
                      setSt(() => loading = true);
                      try {
                        final db = ref.read(firestoreServiceProvider);
                        final currentUser = ref.read(currentUserProvider);
                        // Buscar usuario por cédula
                        final usersSnap = await FirebaseFirestore.instance
                            .collection('users')
                            .where('identification', isEqualTo: cedula)
                            .limit(1)
                            .get();

                        if (usersSnap.docs.isEmpty) {
                          throw Exception('No se encontró usuario con esa cédula');
                        }

                        final userData = usersSnap.docs.first.data();
                        final studentId = usersSnap.docs.first.id;
                        final studentName =
                            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                                .trim();

                        await db.enrollStudent(
                          courseId: widget.courseId,
                          studentId: studentId,
                          studentName: studentName,
                          studentEmail: userData['email'] ?? '',
                          identificacion: cedula,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.invalidate(courseStudentsProvider(widget.courseId));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('$studentName inscrito correctamente'),
                                backgroundColor: AppColors.green));
                        }
                      } catch (e) {
                        setSt(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppColors.red));
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Inscribir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeStudent(String studentId, String studentName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar estudiante'),
        content: Text(
            '¿Eliminar a $studentName del curso? Se borrará su progreso.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('enrollments')
          .doc(studentId)
          .delete();
      ref.invalidate(courseStudentsProvider(widget.courseId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estudiante eliminado del curso')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.red));
      }
    }
  }

  void _showCertifyDialog(
      BuildContext context, String studentId, String studentName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.workspace_premium_outlined,
              color: AppColors.green, size: 20),
          SizedBox(width: 10),
          Text('Certificar estudiante'),
        ]),
        content: Text(
            '¿Emitir certificado de aprobación para $studentName?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // Crear documento de certificado en Firestore
                await FirebaseFirestore.instance
                    .collection('user_certificates')
                    .add({
                  'userId': studentId,
                  'courseId': widget.courseId,
                  'courseTitle':
                      widget.course?.title ?? '',
                  'type': 'AHA',
                  'issuer': 'SIERCP',
                  'certificateNumber':
                      'SIERCP-${DateTime.now().millisecondsSinceEpoch}',
                  'issueDate': DateTime.now()
                      .toIso8601String()
                      .substring(0, 10),
                  'verificationStatus': 'APPROVED',
                  'issuedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Certificado emitido para $studentName'),
                        backgroundColor: AppColors.green));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green),
            child: const Text('Certificar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(courseStudentsProvider(widget.courseId));
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final border = theme.colorScheme.outline;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Agregar'),
      ),
      body: studentsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.brand)),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: TextStyle(color: textS))),
        data: (students) => students.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_off_outlined,
                        size: 52,
                        color: border.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('Sin estudiantes inscritos',
                        style: TextStyle(color: textS, fontSize: 13)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showAddStudentDialog,
                      icon: const Icon(Icons.person_add_outlined, size: 16),
                      label: const Text('Agregar primer estudiante'),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: students.length,
                itemBuilder: (ctx, i) {
                  final st = students[i];
                  final name =
                      st['studentName'] as String? ?? 'Sin nombre';
                  final email = st['studentEmail'] as String? ?? '';
                  final sid = st['studentId'] as String? ?? '';
                  final avgScore =
                      (st['avgScore'] as num?)?.toDouble() ?? 0.0;
                  final completed =
                      (st['completedModules'] as int?) ?? 0;
                  final scoreColor = avgScore >= 85
                      ? AppColors.green
                      : avgScore >= 70
                          ? AppColors.amber
                          : AppColors.red;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: border, width: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: AppColors.brand,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: TextStyle(
                                      color: textP,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              Text(email,
                                  style:
                                      TextStyle(color: textS, fontSize: 11)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        scoreColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Nota: ${avgScore.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                        color: scoreColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('$completed módulos',
                                    style: TextStyle(
                                        color: textS, fontSize: 9)),
                              ]),
                            ],
                          ),
                        ),
                        // Acciones
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              size: 18, color: textS),
                          padding: EdgeInsets.zero,
                          onSelected: (val) {
                            if (val == 'certify') {
                              _showCertifyDialog(context, sid, name);
                            } else if (val == 'remove') {
                              _removeStudent(sid, name);
                            } else if (val == 'detail') {
                              context.push('/instructor/students/$sid');
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'detail',
                              child: Row(children: [
                                Icon(Icons.person_outline, size: 16),
                                SizedBox(width: 8),
                                Text('Ver detalle',
                                    style: TextStyle(fontSize: 13)),
                              ]),
                            ),
                            const PopupMenuItem(
                              value: 'certify',
                              child: Row(children: [
                                Icon(Icons.workspace_premium_outlined,
                                    size: 16, color: AppColors.green),
                                SizedBox(width: 8),
                                Text('Certificar',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.green)),
                              ]),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(children: [
                                Icon(Icons.person_remove_outlined,
                                    size: 16, color: AppColors.red),
                                SizedBox(width: 8),
                                Text('Eliminar del curso',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.red)),
                              ]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ── Tab 3: Asistencia (reutiliza el existente de course_detail_screen) ─────────
class _AttendanceTab extends ConsumerWidget {
  final String courseId;
  const _AttendanceTab({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.how_to_reg_outlined,
              size: 52,
              color: theme.colorScheme.outline.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('Gestión de asistencia',
              style: TextStyle(
                  color: textS, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Disponible en la vista detalle del curso',
              style: TextStyle(color: textS, fontSize: 12)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Abrir vista completa'),
            onPressed: () => context.push('/course-detail/$courseId'),
          ),
        ],
      ),
    );
  }
}

// ── Tab 4: Progreso ───────────────────────────────────────────────────────────
class _ProgressTab extends ConsumerWidget {
  final String courseId;
  const _ProgressTab({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(courseStudentsProvider(courseId));
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return studentsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.brand)),
      error: (e, _) =>
          Center(child: Text('Error: $e', style: TextStyle(color: textS))),
      data: (students) {
        if (students.isEmpty) {
          return Center(
              child: Text('Sin estudiantes', style: TextStyle(color: textS)));
        }

        double totalAvg = 0;
        int approved = 0;
        for (final s in students) {
          final avg = (s['avgScore'] as num?)?.toDouble() ?? 0.0;
          totalAvg += avg;
          if (avg >= 70) approved++;
        }
        final avgScore = students.isNotEmpty ? totalAvg / students.length : 0.0;
        final approvalRate =
            students.isNotEmpty ? approved / students.length * 100 : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // KPIs
              Row(children: [
                Expanded(
                    child: _KpiCard(
                  icon: Icons.people_outline,
                  label: 'Inscritos',
                  value: '${students.length}',
                  color: AppColors.brand,
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _KpiCard(
                  icon: Icons.sports_score_outlined,
                  label: 'Nota Promedio',
                  value: '${avgScore.toStringAsFixed(1)}%',
                  color: avgScore >= 85
                      ? AppColors.green
                      : avgScore >= 70
                          ? AppColors.amber
                          : AppColors.red,
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _KpiCard(
                  icon: Icons.check_circle_outline,
                  label: 'Aprobación',
                  value: '${approvalRate.toStringAsFixed(0)}%',
                  color: approvalRate >= 80 ? AppColors.green : AppColors.amber,
                )),
              ]),
              const SizedBox(height: 20),
              Text('Progreso individual',
                  style: TextStyle(
                      color: textP,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...students.map((s) {
                final name = s['studentName'] as String? ?? 'Sin nombre';
                final avg = (s['avgScore'] as num?)?.toDouble() ?? 0.0;
                final completed = (s['completedModules'] as int?) ?? 0;
                final color = avg >= 85
                    ? AppColors.green
                    : avg >= 70
                        ? AppColors.amber
                        : AppColors.red;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(
                        color: theme.colorScheme.outline, width: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(
                                  color: textP,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text('$completed módulos completados',
                              style: TextStyle(color: textS, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${avg.toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ]),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _KpiCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline, width: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color, fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
