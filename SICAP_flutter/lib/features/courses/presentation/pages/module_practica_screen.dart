import 'package:flutter/material.dart';
import 'package:siercp/core/widgets/app_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/features/courses/data/models/course_module.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/courses/data/course_service.dart';
import 'package:siercp/core/utils/connection_guard.dart';
import 'package:siercp/core/constants/clinical_scenarios.dart';

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
        loading: () => const AppLogoLoader(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sessions) {
          // Filtrar sesiones completadas de este curso y este alumno
          final courseSessions = sessions
              .where((s) =>
                  s.courseId == courseId && s.status == SessionStatus.completed)
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
                    border:
                        Border.all(color: AppColors.red.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.red),
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
                if (module.requiredSessions.isEmpty) ...[
                  // Módulo sin requerimientos configurados:
                  // mostrar botón de sesión libre con selección de escenario.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                          color: AppColors.amber.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.amber, size: 18),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'El instructor no ha configurado sesiones requeridas. '
                            'Puedes practicar libremente eligiendo un escenario.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _startFreeSession(context, ref),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Iniciar sesión de práctica'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                ] else
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
                      onStart: () =>
                          _startSession(context, ref, req.scenarioId),
                    );
                  }),

                if (module.requiredSessions.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  // ── Botón finalizar ─────────────────────────────
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
                      ref.invalidate(studentProgressProvider(courseId));
                      if (context.mounted) {
                        context.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('¡Módulo completado!')),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _startSession(BuildContext context, WidgetRef ref, String scenarioId) {
    if (ConnectionGuard.checkConnection(context, ref)) {
      context.push(
          '/simulation/practical/session?scenario=$scenarioId&courseId=$courseId');
    }
  }

  /// Inicio libre cuando el módulo no tiene requerimientos configurados.
  /// Usa el primer escenario disponible del sistema o abre selección de escenario.
  void _startFreeSession(BuildContext context, WidgetRef ref) {
    if (ConnectionGuard.checkConnection(context, ref)) {
      // Navegar a selección de escenario con el courseId para que la
      // sesión quede vinculada al curso aunque el módulo no tenga
      // escenarios configurados explícitamente.
      context.push(
          '/simulation/practical/session?scenario=paroCardiaco&courseId=$courseId');
    }
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
          color: isDone
              ? AppColors.green.withValues(alpha: 0.3)
              : theme.colorScheme.outline,
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
                  isDone
                      ? Icons.check_circle_rounded
                      : Icons.play_arrow_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: textP,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
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
                  Text('aprobadas',
                      style: TextStyle(color: textS, fontSize: 10)),
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

  String _getScenarioLabel(String id) =>
      getScenarioById(id)?.title ?? (id[0].toUpperCase() + id.substring(1));
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
