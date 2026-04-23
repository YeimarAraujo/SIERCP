import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/session.dart';
import '../services/session_service.dart';
import '../widgets/section_label.dart';

import '../providers/session_provider.dart';

// ── Provider propio de pantalla para evitar recreación infinita ────────────────
// Primero intenta desde Firestore; si falla o no tiene métricas, usa el estado
// en memoria del activeSessionProvider (para cuando hay problemas de red).
final _sessionResultProvider =
    FutureProvider.family<SessionModel?, String>((ref, sessionId) async {
  // 1. Intentar desde Firestore
  try {
    final fromDb = await ref.read(sessionServiceProvider).getSession(sessionId);
    if (fromDb != null && fromDb.metrics != null) return fromDb;
  } catch (_) {}

  // 2. Fallback: usar el estado en memoria si el ID coincide
  final inMemory = ref.read(activeSessionProvider).session;
  if (inMemory != null && inMemory.id == sessionId) return inMemory;

  return null;
});

class SessionResultScreen extends ConsumerWidget {
  final String sessionId;
  const SessionResultScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(_sessionResultProvider(sessionId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: sessionAsync.when(
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.brand),
                SizedBox(height: 12),
                Text('Cargando resultados…',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          error: (e, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.red, size: 48),
                  const SizedBox(height: 12),
                  Text('Error al cargar resultados:\n$e',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(_sessionResultProvider(sessionId));
                    },
                    child: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Ir al inicio'),
                  ),
                ],
              ),
            ),
          ),
          data: (session) {
            if (session == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hourglass_empty,
                          color: AppColors.textSecondary, size: 48),
                      const SizedBox(height: 12),
                      const Text('Sesión no encontrada.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => context.go('/history'),
                        child: const Text('Ver historial'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final metrics = session.metrics;
            if (metrics == null) {
              // La sesión existe pero aún no tiene métricas
              // (raro pero posible si Firestore no terminó de escribir)
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.analytics_outlined,
                          color: AppColors.textSecondary, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                          'Las métricas de la sesión no están disponibles aún.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(_sessionResultProvider(sessionId));
                        },
                        child: const Text('Reintentar'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go('/history'),
                        child: const Text('Ver historial'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return _ResultBody(metrics: metrics, sessionId: sessionId);
          },
        ),
      ),
    );
  }
}

class _ResultBody extends ConsumerWidget {
  final SessionMetrics metrics;
  final String sessionId;
  const _ResultBody({required this.metrics, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme   = Theme.of(context);
    final isDark  = theme.brightness == Brightness.dark;
    final textP   = theme.textTheme.bodyLarge?.color  ?? AppColors.textPrimary;
    final surface = theme.colorScheme.surface;
    final border  = theme.colorScheme.outline;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),

          // ── Top bar ─────────────────────────────────────────────────────────
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => context.go('/history'),
              ),
              const Spacer(),
              _ExportMenu(sessionId: sessionId, metrics: metrics),
            ],
          ),
          const SizedBox(height: 12),

          // ── Score circle ────────────────────────────────────────────────────
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: metrics.score / 100),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => Column(
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 10,
                            backgroundColor: border,
                            valueColor:
                                AlwaysStoppedAnimation(metrics.scoreColor),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(value * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: metrics.scoreColor,
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'SpaceMono',
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  metrics.approved
                                      ? Icons.check_circle_outlined
                                      : Icons.cancel_outlined,
                                  color: metrics.scoreColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  metrics.approved
                                      ? 'APROBADO'
                                      : 'REPROBADO',
                                  style: TextStyle(
                                    color: metrics.scoreColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    metrics.approved
                        ? '¡Excelente técnica de RCP!'
                        : 'Sigue practicando — puedes mejorar',
                    style: TextStyle(
                      color: textP,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Calificación según estándares AHA 2020',
                    style: TextStyle(
                        color:
                            Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── AHA Parameters ───────────────────────────────────────────────────
          const SectionLabel('Parámetros evaluados AHA'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: border, width: 0.5),
              boxShadow: isDark ? null : AppShadows.card(false),
            ),
            child: Column(
              children: [
                _AhaRow(
                    label: 'Profundidad promedio',
                    value:
                        '${metrics.averageDepthMm.toStringAsFixed(1)} mm',
                    range: '50 – 60 mm',
                    ok: metrics.depthOk),
                Divider(color: border, height: 0.5),
                _AhaRow(
                    label: 'Frecuencia promedio',
                    value:
                        '${metrics.averageRatePerMin.toStringAsFixed(0)} /min',
                    range: '100 – 120 /min',
                    ok: metrics.rateOk),
                Divider(color: border, height: 0.5),
                _AhaRow(
                    label: 'Compresiones correctas',
                    value:
                        '${metrics.correctCompressionsPct.toStringAsFixed(1)}%',
                    range: 'Meta: 85%+',
                    ok: metrics.correctCompressionsPct >= 85),
                Divider(color: border, height: 0.5),
                _AhaRow(
                    label: 'Pausa máxima',
                    value:
                        '${metrics.maxPauseSeconds.toStringAsFixed(1)} s',
                    range: 'Máx: 10 s',
                    ok: metrics.maxPauseSeconds <= 10),
                Divider(color: border, height: 0.5),
                _AhaRow(
                    label: 'Total compresiones',
                    value: '${metrics.totalCompressions}',
                    range: '',
                    ok: true),
                Divider(color: border, height: 0.5),
                _AhaRow(
                    label: 'Interrupciones',
                    value: '${metrics.interruptionCount}',
                    range: 'Meta: 0',
                    ok: metrics.interruptionCount == 0),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Violations ────────────────────────────────────────────────────────
          if (metrics.violations.isNotEmpty) ...[
            const SectionLabel('Correcciones necesarias'),
            const SizedBox(height: 8),
            ...metrics.violations.map((v) => _ViolationCard(violation: v)),
            const SizedBox(height: 16),
          ],

          // ── Actions ──────────────────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: () => context.go('/scenarios'),
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('Nueva sesión RCP'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.go('/history'),
            icon: const Icon(Icons.bar_chart_outlined, size: 18),
            label: const Text('Ver historial completo'),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

// ─── Export menu ────────────────────────────────────────────────────────────────
class _ExportMenu extends ConsumerWidget {
  final String sessionId;
  final SessionMetrics metrics;
  const _ExportMenu({required this.sessionId, required this.metrics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'pdf') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Generando PDF… instala las dependencias primero con flutter pub get')),
          );
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined,
                  size: 18, color: AppColors.red),
              SizedBox(width: 10),
              Text('Exportar PDF'),
            ],
          ),
        ),
      ],
      icon: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_outlined,
                size: 16, color: AppColors.brand),
            SizedBox(width: 6),
            Text('Exportar',
                style: TextStyle(
                    color: AppColors.brand,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────────
class _AhaRow extends StatelessWidget {
  final String label;
  final String value;
  final String range;
  final bool ok;
  const _AhaRow(
      {required this.label,
      required this.value,
      required this.range,
      required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.green : AppColors.red;
    final textP =
        Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(color: textP, fontSize: 13))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SpaceMono')),
              if (range.isNotEmpty)
                Text(range, style: TextStyle(color: textS, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViolationCard extends StatelessWidget {
  final AhaViolation violation;
  const _ViolationCard({required this.violation});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.redBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: AppColors.red.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined,
                color: AppColors.red, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(violation.message,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      )),
                  Text('${violation.count} ocurrencia(s)',
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color,
                        fontSize: 11,
                      )),
                ],
              ),
            ),
          ],
        ),
      );
}
