import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/session.dart';
import '../services/session_service.dart';
import '../services/export_service.dart';
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
                      style: const TextStyle(color: AppColors.textSecondary)),
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

            return _ResultBody(
                session: session, metrics: metrics, sessionId: sessionId);
          },
        ),
      ),
    );
  }
}

class _ResultBody extends ConsumerWidget {
  final SessionModel session;
  final SessionMetrics metrics;
  final String sessionId;
  const _ResultBody(
      {required this.session, required this.metrics, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => context.go('/history'),
              ),
              const Spacer(),
              _ExportButton(session: session, metrics: metrics),
            ],
          ),
          const SizedBox(height: 12),
          if (isLandscape)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Score left
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _ScoreCircle(metrics: metrics, size: 120),
                      const SizedBox(height: 16),
                      Text(
                        metrics.approved
                            ? '¡Excelente técnica!'
                            : 'Sigue practicando',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textP,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ExportPdfAction(session: session, metrics: metrics),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Parameters right
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionLabel('Parámetros AHA'),
                      const SizedBox(height: 10),
                      _AhaParametersList(
                          metrics: metrics,
                          surface: surface,
                          border: border,
                          isDark: isDark),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            // Score center (Portrait)
            Center(child: _ScoreCircle(metrics: metrics, size: 140)),
            const SizedBox(height: 14),
            Center(
              child: Text(
                metrics.approved
                    ? '¡Excelente técnica de RCP!'
                    : 'Sigue practicando — puedes mejorar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textP,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Calificación según estándares AHA 2025',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),

            // AHA Parameters (Portrait)
            const SectionLabel('Parámetros evaluados AHA'),
            const SizedBox(height: 10),
            _AhaParametersList(
                metrics: metrics,
                surface: surface,
                border: border,
                isDark: isDark),
          ],
          const SizedBox(height: 20),
          if (metrics.violations.isNotEmpty) ...[
            const SectionLabel('Correcciones necesarias'),
            const SizedBox(height: 8),
            ...metrics.violations.map((v) => _ViolationCard(violation: v)),
            const SizedBox(height: 16),
          ],
          if (!isLandscape) ...[
            _ExportPdfAction(session: session, metrics: metrics),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/scenarios'),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Nueva sesión'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/history'),
                  icon: const Icon(Icons.bar_chart_outlined, size: 18),
                  label: const Text('Historial'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _ScoreCircle extends StatelessWidget {
  final SessionMetrics metrics;
  final double size;
  const _ScoreCircle({required this.metrics, required this.size});

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).colorScheme.outline;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: metrics.score / 100),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (_, value, __) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: size * 0.07,
                backgroundColor: border,
                valueColor: AlwaysStoppedAnimation(metrics.scoreColor),
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
                    fontSize: size * 0.25,
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
                      size: size * 0.08,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      metrics.approved ? 'APROBADO' : 'REPROBADO',
                      style: TextStyle(
                        color: metrics.scoreColor,
                        fontSize: size * 0.06,
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
    );
  }
}

class _AhaParametersList extends StatelessWidget {
  final SessionMetrics metrics;
  final Color surface, border;
  final bool isDark;

  const _AhaParametersList({
    required this.metrics,
    required this.surface,
    required this.border,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border, width: 0.5),
        boxShadow: isDark ? null : AppShadows.card(false),
      ),
      child: Column(
        children: [
          _AhaRow(
              label: 'Profundidad',
              value: '${metrics.averageDepthMm.toStringAsFixed(1)} mm',
              range: '50-60 mm',
              ok: metrics.depthOk),
          Divider(color: border, height: 0.5),
          _AhaRow(
              label: 'Frecuencia',
              value: '${metrics.averageRatePerMin.toStringAsFixed(0)} /min',
              range: '100-120 /min',
              ok: metrics.rateOk),
          Divider(color: border, height: 0.5),
          _AhaRow(
              label: 'Correctas',
              value: '${metrics.correctCompressionsPct.toStringAsFixed(1)}%',
              range: 'Meta: 85%+',
              ok: metrics.correctCompressionsPct >= 85),
          Divider(color: border, height: 0.5),
          _AhaRow(
              label: 'Pausa máx',
              value: '${metrics.maxPauseSeconds.toStringAsFixed(1)} s',
              range: 'Máx: 10 s',
              ok: metrics.maxPauseSeconds <= 10),
          Divider(color: border, height: 0.5),
          _AhaRow(
              label: 'Interrupciones',
              value: '${metrics.interruptionCount}',
              range: 'Meta: 0',
              ok: metrics.interruptionCount == 0),
        ],
      ),
    );
  }
}

class _ExportPdfAction extends ConsumerStatefulWidget {
  final SessionModel session;
  final SessionMetrics metrics;
  const _ExportPdfAction({required this.session, required this.metrics});

  @override
  ConsumerState<_ExportPdfAction> createState() => _ExportPdfActionState();
}

class _ExportPdfActionState extends ConsumerState<_ExportPdfAction> {
  bool _exporting = false;

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final exportService = ref.read(exportServiceProvider);
      await exportService.exportSessionPDF(widget.session, widget.metrics);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF generado y compartido exitosamente'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brand.withValues(alpha: isDark ? 0.15 : 0.08),
            AppColors.accent.withValues(alpha: isDark ? 0.10 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _exporting ? null : _exportPdf,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.brand, AppColors.accent]),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: _exporting
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded,
                          color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exportar reporte PDF',
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Genera y comparte el reporte de esta sesión',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExportButton extends ConsumerStatefulWidget {
  final SessionModel session;
  final SessionMetrics metrics;
  const _ExportButton({required this.session, required this.metrics});

  @override
  ConsumerState<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends ConsumerState<_ExportButton> {
  bool _exporting = false;

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final exportService = ref.read(exportServiceProvider);
      await exportService.exportSessionPDF(widget.session, widget.metrics);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF generado y compartido'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _exporting ? null : _exportPdf,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_exporting)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.brand,
                ),
              )
            else
              const Icon(Icons.picture_as_pdf_outlined,
                  size: 16, color: AppColors.brand),
            const SizedBox(width: 6),
            Text(
              _exporting ? 'Generando…' : 'Exportar PDF',
              style: const TextStyle(
                  color: AppColors.brand,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

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
              child: Text(label, style: TextStyle(color: textP, fontSize: 13))),
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
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 11,
                      )),
                ],
              ),
            ),
          ],
        ),
      );
}
