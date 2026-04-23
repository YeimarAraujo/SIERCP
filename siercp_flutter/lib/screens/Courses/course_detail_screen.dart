import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../models/course_module.dart';
import '../../../services/course_service.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final _studentModulesProvider =
    FutureProvider.family<List<CourseModule>, String>(
  (ref, courseId) => ref.read(courseServiceProvider).getModules(courseId),
);

// ─── Screen ───────────────────────────────────────────────────────────────────
class CourseDetailScreen extends ConsumerWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(_studentModulesProvider(courseId));
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text('Módulos del curso',
            style: TextStyle(
                color: textP, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: modulesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e', style: TextStyle(color: textS)),
        ),
        data: (modules) => modules.isEmpty
            ? _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                itemCount: modules.length,
                itemBuilder: (_, i) => _ModuleRoadmapCard(
                  module: modules[i],
                  index: i,
                  isUnlocked: i == 0, // por ahora solo el primero desbloqueado
                  isCompleted: false,
                ),
              ),
      ),
    );
  }
}

// ─── Card de módulo (roadmap) ─────────────────────────────────────────────────
class _ModuleRoadmapCard extends StatelessWidget {
  final CourseModule module;
  final int index;
  final bool isUnlocked;
  final bool isCompleted;

  const _ModuleRoadmapCard({
    required this.module,
    required this.index,
    required this.isUnlocked,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;

    final typeColor = _colorForType(module.type);
    final locked = !isUnlocked && !isCompleted;

    return Opacity(
      opacity: locked ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color:
              isCompleted ? AppColors.green.withValues(alpha: 0.06) : surface,
          border: Border.all(
            color:
                isCompleted ? AppColors.green.withValues(alpha: 0.3) : border,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: locked
                  ? theme.colorScheme.outline.withValues(alpha: 0.1)
                  : typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: locked
                  ? Icon(Icons.lock_outline_rounded, size: 20, color: textS)
                  : Text(module.type.icon,
                      style: const TextStyle(fontSize: 22)),
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'M${index + 1}',
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  module.title,
                  style: TextStyle(
                    color: textP,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isCompleted)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.green, size: 18),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              locked
                  ? 'Completa el módulo anterior para desbloquear'
                  : module.type.label,
              style: TextStyle(
                color: locked ? textS : typeColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          trailing: locked
              ? null
              : Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textS),
          onTap: locked
              ? null
              : () {
                  // TODO: navegar al contenido del módulo
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Abriendo: ${module.title}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
        ),
      ),
    );
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
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textS = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_outlined, size: 48, color: textS),
          const SizedBox(height: 12),
          Text('Este curso aún no tiene módulos',
              style: TextStyle(color: textS, fontSize: 14)),
        ],
      ),
    );
  }
}
