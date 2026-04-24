import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../providers/session_provider.dart';
import '../widgets/compression_wave.dart';
import '../widgets/depth_gauge.dart';
import '../widgets/rate_gauge.dart';
import '../widgets/aha_status_bar.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final String? scenarioId;
  const SessionScreen({super.key, this.scenarioId});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  bool _starting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  Future<void> _startSession() async {
    try {
      await ref.read(activeSessionProvider.notifier).startSession(
            widget.scenarioId ?? 'default',
          );
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al iniciar la sesión: $e');
    } finally {
      if (mounted) setState(() => _starting = false);
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
        content: Text(
            '¿Estás seguro de que deseas finalizar la sesión de RCP?',
            style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
              child: const Text('Finalizar', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Mostrar loading mientras se guarda
    setState(() => _starting = true);

    final sessionId = ref.read(activeSessionProvider).session?.id;

    try {
      final session = await ref
          .read(activeSessionProvider.notifier)
          .endSession()
          .timeout(const Duration(seconds: 15));

      if (mounted) context.go('/session-result/${session.id}');
    } catch (e) {
      // Si falló Firestore pero tenemos el sessionId guardado, navegar igual
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
              Text('Iniciando sesión RCP...',
                  style: TextStyle(color: AppColors.textSecondary)),
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

    final state = ref.watch(activeSessionProvider);
    final live = state.liveData;
    final elapsed = state.elapsed;
    final history = state.depthHistory;
    final alerts = state.alerts;
    final session = state.session;

    final elapsedStr =
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sesión activa',
                          style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          Text(
                              'Escenario: ${session?.scenarioTitle ?? 'RCP Adulto'}',
                              style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 11)),
                          const SizedBox(width: 8),
                          Text(elapsedStr,
                              style: const TextStyle(
                                  color: AppColors.brand,
                                  fontSize: 11,
                                  fontFamily: 'SpaceMono',
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  _LiveBadge(),
                ],
              ),
            ),
            
            // Monitor Area (Forced Dark)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0B0E),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15)
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Gauges Row
                            Row(
                              children: [
                                Expanded(
                                  child: _MonitorPanel(
                                    label: 'PROFUNDIDAD',
                                    widget: SizedBox(
                                      height: 130,
                                      child: DepthGauge(depthMm: live.depthMm),
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 100, color: Colors.white10),
                                Expanded(
                                  child: _MonitorPanel(
                                    label: 'FRECUENCIA',
                                    widget: SizedBox(
                                      height: 130,
                                      child: RateGauge(ratePerMin: live.ratePerMin),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Stats Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _MonitorStat(label: 'COMPRESIONES', value: '${live.compressionCount}', color: Colors.white),
                                _MonitorStat(label: 'OXÍGENO %', value: live.oxygen.toStringAsFixed(0), color: const Color(0xFF00E5FF)),
                                _MonitorStat(label: 'CALIDAD %', value: live.sessionScore.toStringAsFixed(0), color: const Color(0xFF00FF41)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Waveform
                            if (history.isNotEmpty)
                              Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CompressionWave(history: history),
                                ),
                              ),
                            const SizedBox(height: 12),
                            
                            // AHA Status (Themed Dark)
                            Theme(
                              data: ThemeData.dark(),
                              child: AhaStatusBar(
                                depthMm: live.depthMm,
                                ratePerMin: live.ratePerMin,
                                decompressedFully: live.decompressedFully,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Alerts & Button Area (App Theme)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  if (alerts.isNotEmpty)
                    _AlertBanner(alert: alerts.first),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _endSession,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('Finalizar sesión'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red.withValues(alpha: 0.1),
                      foregroundColor: AppColors.red,
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: AppColors.red, width: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorPanel extends StatelessWidget {
  final String label;
  final Widget widget;
  const _MonitorPanel({required this.label, required this.widget});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
      const SizedBox(height: 10),
      widget,
    ],
  );
}

class _MonitorStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MonitorStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800, fontFamily: 'SpaceMono')),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
    ],
  );
}

class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(opacity: _anim, child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle))),
        const SizedBox(width: 5),
        const Text('EN VIVO', style: TextStyle(color: AppColors.green, fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _AlertBanner extends StatelessWidget {
  final dynamic alert;
  const _AlertBanner({required this.alert});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: alert.bgColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: alert.color.withValues(alpha: 0.2))),
    child: Row(
      children: [
        Icon(alert.icon, color: alert.color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(alert.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text(alert.message, style: const TextStyle(fontSize: 11)),
          ]),
        ),
      ],
    ),
  );
}

