import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';

import '../models/alert_course.dart';
import '../models/session.dart';

import '../providers/session_provider.dart';
import '../widgets/section_label.dart';

/// Pantalla de detalle de curso para ESTUDIANTES.
/// Muestra requisitos, progreso individual, sesiones y reglas de aprobación.
class StudentCourseDetailScreen extends ConsumerWidget {
  final String courseId;
  const StudentCourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync  = ref.watch(coursesProvider);
    final sessionsAsync = ref.watch(sessionsHistoryProvider);

    final theme         = Theme.of(context);
    final isDark        = theme.brightness == Brightness.dark;
    final textP  = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border  = theme.colorScheme.outline;

    final course = coursesAsync.value?.firstWhere(
      (c) => c.id == courseId,
      orElse: () => CourseModel(
        id: courseId, title: 'Cargando...', instructorName: '',
        totalModules: 0, completedModules: 0, certification: '',
      ),
    );

    if (course == null) {
      return Scaffold(
        body: Center(child: Text('Curso no encontrado', style: TextStyle(color: textS))),
      );
    }

    // Filtrar sesiones de ESTE curso
    final allSessions = sessionsAsync.value ?? [];
    final courseSessions = allSessions
        .where((s) => s.courseId == courseId && s.status == SessionStatus.completed)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final totalSessions   = courseSessions.length;
    final approvedSessions = courseSessions.where((s) => s.metrics?.approved == true).length;
    final requiredSessions = course.totalModules > 0 ? course.totalModules : 4;
    final progressPct     = requiredSessions > 0
        ? (approvedSessions / requiredSessions).clamp(0.0, 1.0)
        : 0.0;
    final avgScore = courseSessions.isEmpty
        ? 0.0
        : courseSessions
              .where((s) => s.metrics != null)
              .map((s) => s.metrics!.score)
              .fold(0.0, (a, b) => a + b) /
            courseSessions.where((s) => s.metrics != null).length;

    // Regla de aprobación

    final remaining     = (requiredSessions - approvedSessions).clamp(0, requiredSessions);

    // Estado del curso
    final CourseStatus status;
    if (approvedSessions >= requiredSessions) {
      status = CourseStatus.completed;
    } else if (totalSessions > 0) {
      status = CourseStatus.inProgress;
    } else {
      status = CourseStatus.pending;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: () => context.canPop() ? context.pop() : context.go('/courses'),
                    ),
                    const Spacer(),
                    _StatusBadge(status: status),
                  ],
                ),
              ),
            ),

            // ── Course Info Card ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF0D1B2A), const Color(0xFF162032)]
                          : [const Color(0xFFEAF3FF), const Color(0xFFD5E9FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: AppColors.brand.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.brand, AppColors.accent],
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(course.title,
                                    style: TextStyle(color: textP, fontSize: 18, fontWeight: FontWeight.w800),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.brand),
                                  const SizedBox(width: 4),
                                  Text(course.instructorName,
                                      style: const TextStyle(color: AppColors.brand, fontSize: 12, fontWeight: FontWeight.w600)),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (course.description != null && course.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(course.description!, style: TextStyle(color: textS, fontSize: 12), maxLines: 3),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Progress Ring + Stats ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: border, width: 0.5),
                    boxShadow: isDark ? null : AppShadows.card(false),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Progress ring
                          SizedBox(
                            width: 90, height: 90,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: progressPct),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOutCubic,
                              builder: (_, val, __) => Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 90, height: 90,
                                    child: CircularProgressIndicator(
                                      value: val,
                                      strokeWidth: 8,
                                      backgroundColor: border,
                                      valueColor: AlwaysStoppedAnimation(
                                        status == CourseStatus.completed
                                            ? AppColors.green
                                            : AppColors.brand,
                                      ),
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                  Column(mainAxisSize: MainAxisSize.min, children: [
                                    Text('${(val * 100).toInt()}%',
                                        style: TextStyle(color: textP, fontSize: 22,
                                            fontWeight: FontWeight.w800, fontFamily: 'SpaceMono')),
                                    Text('avance', style: TextStyle(color: textS, fontSize: 9)),
                                  ]),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Stats
                          Expanded(
                            child: Column(
                              children: [
                                _MiniStat(label: 'Sesiones realizadas', value: '$totalSessions', icon: Icons.repeat_rounded, color: AppColors.cyan),
                                const SizedBox(height: 8),
                                _MiniStat(label: 'Sesiones aprobadas', value: '$approvedSessions / $requiredSessions', icon: Icons.check_circle_outline, color: AppColors.green),
                                const SizedBox(height: 8),
                                _MiniStat(label: 'Promedio', value: '${avgScore.toStringAsFixed(1)}%', icon: Icons.star_outline_rounded, color: AppColors.amber),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressPct,
                          backgroundColor: border,
                          valueColor: AlwaysStoppedAnimation(
                            status == CourseStatus.completed ? AppColors.green : AppColors.brand,
                          ),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$approvedSessions de $requiredSessions sesiones aprobadas',
                              style: TextStyle(color: textS, fontSize: 10)),
                          if (remaining > 0)
                            Text('Faltan $remaining',
                                style: const TextStyle(color: AppColors.amber, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Requisitos del Curso ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: const SectionLabel('Requisitos para completar'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: border, width: 0.5),
                    boxShadow: isDark ? null : AppShadows.card(false),
                  ),
                  child: Column(
                    children: [
                      _RequirementRow(
                        icon: Icons.sports_score_outlined,
                        label: 'Calificación mínima de aprobación',
                        value: '${course.requiredScore.toStringAsFixed(0)}%',
                        met: avgScore >= course.requiredScore || totalSessions == 0,
                      ),
                      Divider(color: border, height: 20),
                      _RequirementRow(
                        icon: Icons.repeat_rounded,
                        label: 'Sesiones aprobadas requeridas',
                        value: '$requiredSessions sesiones',
                        met: approvedSessions >= requiredSessions,
                      ),
                      Divider(color: border, height: 20),
                      _RequirementRow(
                        icon: Icons.verified_outlined,
                        label: 'Certificación',
                        value: course.certification.isNotEmpty ? course.certification : 'BLS AHA 2025',
                        met: status == CourseStatus.completed,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Regla de aprobación contextual ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cyanBg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.cyan.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.cyan, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          remaining > 0
                              ? 'Te faltan $remaining sesión(es) aprobada(s) con mínimo ${course.requiredScore.toStringAsFixed(0)}% para completar este curso.'
                              : '¡Has completado todos los requisitos de este curso!',
                          style: TextStyle(color: textP, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Historial de sesiones ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: SectionLabel('Sesiones del curso ($totalSessions)'),
              ),
            ),
            if (courseSessions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: border, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.history_outlined, size: 40, color: textS.withValues(alpha: 0.5)),
                        const SizedBox(height: 10),
                        Text('Aún no has realizado sesiones en este curso',
                            style: TextStyle(color: textS, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SessionTile(session: courseSessions[i], index: i + 1),
                  ),
                  childCount: courseSessions.length,
                ),
              ),

            // ── CTA Button ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: status == CourseStatus.completed
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.greenBg,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.emoji_events_rounded, color: AppColors.green, size: 22),
                            const SizedBox(width: 10),
                            Text('¡Curso completado!',
                                style: TextStyle(color: textP, fontSize: 15, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => context.go('/scenarios'),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: Text(totalSessions > 0 ? 'Continuar entrenamiento' : 'Comenzar entrenamiento'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Enums & Helpers ──────────────────────────────────────────────────────────────
enum CourseStatus { pending, inProgress, completed }

class _StatusBadge extends StatelessWidget {
  final CourseStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (String label, Color color, IconData icon) = switch (status) {
      CourseStatus.completed  => ('Completado', AppColors.green, Icons.check_circle_rounded),
      CourseStatus.inProgress => ('En progreso', AppColors.amber, Icons.autorenew_rounded),
      CourseStatus.pending    => ('Pendiente', AppColors.cyan, Icons.hourglass_empty_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final textP = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: TextStyle(color: textS, fontSize: 11))),
      Text(value, style: TextStyle(color: textP, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'SpaceMono')),
    ]);
  }
}

class _RequirementRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool met;
  const _RequirementRow({required this.icon, required this.label, required this.value, required this.met});

  @override
  Widget build(BuildContext context) {
    final textP = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final color = met ? AppColors.green : AppColors.amber;
    return Row(children: [
      Icon(met ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 18, color: color),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: textP, fontSize: 12, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(color: textS, fontSize: 11)),
      ])),
    ]);
  }
}

class _SessionTile extends StatelessWidget {
  final SessionModel session;
  final int index;
  const _SessionTile({required this.session, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP  = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border  = theme.colorScheme.outline;
    final m = session.metrics;
    final score = m?.score ?? 0;
    final approved = m?.approved ?? false;
    final scoreColor = approved ? AppColors.green : (score >= 50 ? AppColors.amber : AppColors.red);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border.withValues(alpha: 0.4), width: 0.5),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: InkWell(
        onTap: () => context.push('/session-result/${session.id}'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Row(children: [
          // Index badge
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text('#$index',
                style: TextStyle(color: scoreColor, fontSize: 11, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(session.scenarioTitle ?? 'Sesión RCP',
                style: TextStyle(color: textP, fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${session.startedAt.day}/${session.startedAt.month}/${session.startedAt.year} · ${session.durationFormatted}',
                style: TextStyle(color: textS, fontSize: 10)),
          ])),
          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(approved ? Icons.check_circle_outline : Icons.cancel_outlined, size: 12, color: scoreColor),
              const SizedBox(width: 4),
              Text('${score.toStringAsFixed(0)}%',
                  style: TextStyle(color: scoreColor, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'SpaceMono')),
            ]),
          ),
        ]),
      ),
    );
  }
}
