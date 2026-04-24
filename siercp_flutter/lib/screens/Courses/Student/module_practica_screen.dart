import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../models/session.dart';
import '../../../models/course_module.dart';
import '../../../providers/session_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/course_service.dart';

class ModulePracticaScreen extends ConsumerWidget {
  final CourseModule module;
  final String courseId;

  const ModulePracticaScreen({
    super.key,
    required this.module,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final user = ref.watch(currentUserProvider);

    // Obtenemos el historial de sesiones para calcular el progreso local del módulo
    final sessionsAsync = ref.watch(sessionsHistoryProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(module.title, style: const TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sessions) {
          // Filtrar sesiones completadas de este curso y este alumno
          final courseSessions = sessions
              .where((s) => s.courseId == courseId && s.status == SessionStatus.completed)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header explicativo ──────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Debes completar todas las sesiones requeridas con el puntaje mínimo para finalizar este módulo.',
                          style: TextStyle(color: textS, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'SESIONES REQUERIDAS',
                  style: TextStyle(
                    color: textS,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Lista de requerimientos ────────────────────────
                ...module.requiredSessions.map((req) {
                  // Contar cuántas sesiones de este escenario han sido aprobadas
                  final approvedCount = courseSessions.where((s) {
                    final isScenario = s.scenarioId == req.scenarioId;
                    final score = s.metrics?.score ?? 0;
                    return isScenario && score >= req.minScore;
                  }).length;

                  final isDone = approvedCount >= req.count;

                  return _RequirementCard(
                    req: req,
                    approvedCount: approvedCount,
                    isDone: isDone,
                    onStart: () => _startSession(context, req.scenarioId),
                  );
                }),

                const SizedBox(height: 40),

                // ── Botón finalizar ────────────────────────────────
                // Solo se habilita si todos los requerimientos están cumplidos
                _FinalizeButton(
                  module: module,
                  courseSessions: courseSessions,
                  onFinalize: () async {
                    await ref.read(courseServiceProvider).markModuleComplete(
                          courseId: courseId,
                          moduleId: module.id,
                          studentId: user?.id ?? '',
                        );
                    if (context.mounted) {
                      context.pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('¡Módulo completado!')),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _startSession(BuildContext context, String scenarioId) {
    // Navegamos a la pantalla de sesión pasando el escenario y el courseId
    // para que la sesión quede vinculada a este curso.
    context.push('/session?scenario=$scenarioId&courseId=$courseId');
  }
}

class _RequirementCard extends StatelessWidget {
  final RequiredSession req;
  final int approvedCount;
  final bool isDone;
  final VoidCallback onStart;

  const _RequirementCard({
    required this.req,
    required this.approvedCount,
    required this.isDone,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    
    final label = _getScenarioLabel(req.scenarioId);
    final color = isDone ? AppColors.green : AppColors.brand;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDone ? AppColors.green.withValues(alpha: 0.3) : theme.colorScheme.outline,
          width: isDone ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDone ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: textP, fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(
                      'Mínimo: ${req.minScore}% de puntaje',
                      style: TextStyle(color: textS, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$approvedCount / ${req.count}',
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'SpaceMono',
                    ),
                  ),
                  Text('aprobadas', style: TextStyle(color: textS, fontSize: 10)),
                ],
              ),
            ],
          ),
          if (!isDone) ...[
            const SizedBox(height: 16),
            Divider(color: theme.colorScheme.outline, height: 1),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text('Iniciar sesión ahora'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  side: const BorderSide(color: AppColors.brand),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getScenarioLabel(String id) {
    switch (id) {
      case 'paroCardiaco': return 'Paro cardíaco';
      case 'accidenteTransito': return 'Accidente de tránsito';
      case 'ahogamiento': return 'Ahogamiento';
      case 'descargaElectrica': return 'Descarga eléctrica';
      default: return id[0].toUpperCase() + id.substring(1);
    }
  }
}

class _FinalizeButton extends StatelessWidget {
  final CourseModule module;
  final List<dynamic> courseSessions;
  final VoidCallback onFinalize;

  const _FinalizeButton({
    required this.module,
    required this.courseSessions,
    required this.onFinalize,
  });

  @override
  Widget build(BuildContext context) {
    // Verificar si TODOS los requerimientos se cumplen
    bool allMet = true;
    for (final req in module.requiredSessions) {
      final approvedCount = courseSessions.where((s) {
        final isScenario = s.scenarioId == req.scenarioId;
        final score = s.metrics?.score ?? 0;
        return isScenario && score >= req.minScore;
      }).length;
      if (approvedCount < req.count) {
        allMet = false;
        break;
      }
    }

    return ElevatedButton.icon(
      onPressed: allMet ? onFinalize : null,
      icon: const Icon(Icons.check_circle_outline),
      label: const Text('Finalizar módulo de práctica'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
        minimumSize: const Size(double.infinity, 54),
      ),
    );
  }
}
