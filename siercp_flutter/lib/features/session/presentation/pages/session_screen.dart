import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/session/presentation/providers/session_provider.dart';
import 'package:siercp/features/session/presentation/providers/ble_session_provider.dart';
import 'package:siercp/core/widgets/compression_wave.dart';
import 'package:siercp/core/widgets/depth_gauge.dart';
import 'package:siercp/core/widgets/rate_gauge.dart';
import 'package:siercp/features/devices/data/ble_service.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final String? scenarioId;
  final String? courseId;
  const SessionScreen({super.key, this.scenarioId, this.courseId});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  bool _starting = true;
  int _countdown = 4;
  bool _isCountdownActive = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  Future<void> _startSession() async {
    try {
      // 1. Preparar el servicio de audio
      final audioService = ref.read(audioServiceProvider);
      await audioService.init();

      // 2. Iniciar el contador de preparación y cuenta regresiva
      setState(() {
        _starting = false;
        _isCountdownActive = true;
        _countdown = 5;
      });

      // Reproducir el audio de inicio/preparación
      audioService.playStart();

      // Esperar los primeros 2 segundos en "Prepárate" (ajustado a la duración del audio)
      await Future.delayed(const Duration(seconds: 2));

      // Cuenta regresiva visual de 3 a 1 (Segundos 3, 4 y 5)
      for (int i = 3; i >= 1; i--) {
        if (!mounted) return;
        setState(() => _countdown = i);
        await Future.delayed(const Duration(seconds: 1));
      }

      if (!mounted) return;
      setState(() => _isCountdownActive = false);

      // 3. Iniciar la sesión real (telemetría y cronómetro)
      await ref.read(bleServiceProvider).startHardwareSession();
      await ref.read(bleActiveSessionProvider.notifier).startSession(
            widget.scenarioId ?? 'default',
            courseId: widget.courseId,
          );
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al iniciar la sesión: $e');
    }
  }

  Future<void> _endSession() async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('Finalizar sesión',
            style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
        content: Text('¿Estás seguro de que deseas finalizar la sesión de RCP?',
            style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
              child: const Text('Finalizar',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Mostrar loading mientras se guarda
    setState(() => _starting = true);

    final sessionId = ref.read(bleActiveSessionProvider).session?.id;

    try {
      final session = await ref
          .read(bleActiveSessionProvider.notifier)
          .endSession()
          .timeout(const Duration(seconds: 15));
      
      await ref.read(bleServiceProvider).resetHardwareCounters();

      if (mounted) context.go('/session-result/${session.id}');
    } catch (e) {
      if (mounted) {
        if (sessionId != null) {
          context.go('/session-result/$sessionId');
        } else {
          setState(() {
            _starting = false;
            _error = 'Error al guardar la sesión: $e';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_starting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.brand),
              SizedBox(height: 16),
              Text('Preparando equipo...',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_isCountdownActive) {
      final theme = Theme.of(context);
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PREPÁRATE',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 40),
              if (_countdown <= 3)
                TweenAnimationBuilder<double>(
                  key: ValueKey(_countdown),
                  tween: Tween(begin: 2.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Text(
                        '$_countdown',
                        style: GoogleFonts.spaceMono(
                          color: AppColors.brand,
                          fontSize: 120,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.red, size: 48),
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Volver al inicio')),
              ],
            ),
          ),
        ),
      );
    }

    final state = ref.watch(bleActiveSessionProvider);
    final mode = ref.watch(sessionModeProvider);

    final live = state.liveData;
    final elapsed = state.elapsed;
    final history = state.depthHistory;
    final alerts = state.alerts;
    final session = state.session;

    final elapsedStr =
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Colores dinámicos basados en el puntaje (Si es modo evaluación, ocultamos el color)
    final Color scoreColor;
    if (mode == SessionMode.evaluation) {
      scoreColor = const Color(0xFF00D4FF); // Color neutro clínico
    } else {
      scoreColor = live.sessionScore >= 80
          ? const Color(0xFF00FF94)
          : live.sessionScore >= 60
              ? const Color(0xFFFFD600)
              : const Color(0xFFFF4B4B);
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 1.0 : 0.5),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- TOP CLINICAL HEADER ---
              _buildModernHeader(session, live, elapsedStr, scoreColor),

              // --- MAIN MONITORING AREA ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: isLandscape
                      ? _buildLandscapeLayout(history, live)
                      : _buildPortraitLayout(history, live),
                ),
              ),

              // --- BOTTOM ACTION BAR ---
              _buildBottomBar(alerts, live),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(dynamic session, dynamic live, String elapsedStr, Color scoreColor) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00D4FF),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0xFF00D4FF), blurRadius: 8)
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'MONITOR DE SESIÓN',
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  session?.scenarioTitle?.toUpperCase() ?? 'RCP ENTRENAMIENTO',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // CRITICAL TIMER CARD
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined,
                    color: Color(0xFF00D4FF), size: 20),
                const SizedBox(width: 12),
                Text(
                  elapsedStr,
                  style: GoogleFonts.spaceMono(
                    color: const Color(0xFF00D4FF),
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(List<double> history, dynamic live) {
    return Row(
      children: [
        // Waveform takes most space
        Expanded(
          flex: 5,
          child: _MonitorCard(
            title: 'DINÁMICA DE COMPRESIÓN',
            subtitle: 'PROFUNDIDAD (mm) / TIEMPO',
            icon: Icons.show_chart,
            child:
                CompressionWave(
                  history: history,
                  ratePerMin: live.ratePerMin,
                  score: live.sessionScore.toInt(),
                ),
          ),
        ),
        const SizedBox(width: 12),
        // Side Metrics
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                child: _MonitorCard(
                  title: 'FRECUENCIA',
                  subtitle: 'CPM (OBJETIVO 100-120)',
                  child: RateGauge(ratePerMin: live.ratePerMin),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _MonitorCard(
                  title: 'PROFUNDIDAD',
                  subtitle: 'MM (OBJETIVO 50-60)',
                  child: DepthGauge(depthMm: live.depthMm),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(List<double> history, dynamic live) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _MonitorCard(
            title: 'DINÁMICA DE COMPRESIÓN',
            child:
                CompressionWave(
                  history: history,
                  ratePerMin: live.ratePerMin,
                  score: live.sessionScore.toInt(),
                ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Expanded(
                child: _MonitorCard(
                  title: 'FRECUENCIA',
                  child: RateGauge(ratePerMin: live.ratePerMin),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MonitorCard(
                  title: 'PROFUNDIDAD',
                  child: DepthGauge(depthMm: live.depthMm),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(dynamic alerts, dynamic live) {
    final theme = Theme.of(context);
    final mode = ref.watch(sessionModeProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (mode != SessionMode.evaluation)
                  _MetricPill(
                    label: 'SCORE',
                    value: '${live.sessionScore.toStringAsFixed(0)}%',
                    color: live.sessionScore >= 80
                        ? const Color(0xFF00FF94)
                        : Colors.orange,
                  )
                else
                  const _MetricPill(
                    label: 'MODO',
                    value: 'EVALUACIÓN',
                    color: Color(0xFF00D4FF),
                  ),
                _MetricPill(
                  label: 'TOTAL CP',
                  value: live.compressionCount.toString(),
                  color: const Color(0xFF00D4FF),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _endSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4B4B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stop_rounded, size: 24),
                    SizedBox(width: 12),
                    Text('FINALIZAR SESIÓN',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  const _MonitorCard({
    required this.title,
    this.subtitle,
    this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5), size: 14),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Icon(Icons.more_vert, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.2), size: 14),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4), fontSize: 8),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(child: Center(child: child)),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 8,
                  fontWeight: FontWeight.bold)),
          Text(value,
              style: GoogleFonts.spaceMono(
                  color: color, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
