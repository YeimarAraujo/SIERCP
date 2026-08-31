import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/simulation/data/ecg_scenarios_data.dart';
import 'package:siercp/features/simulation/data/ecg_signal.dart';
import 'package:siercp/features/simulation/data/models/ecg_scenario.dart';
import 'package:siercp/features/simulation/data/aed/ecg_audio_service.dart';
import 'package:siercp/features/simulation/presentation/widgets/monitor_trace.dart';

// Paleta fija de monitor clínico (independiente del tema claro/oscuro de la app).
const _monitorBg = Color(0xFF03070E);
const _monitorPanel = Color(0xFF0A1119);
const _monitorBorder = Color(0xFF16202E);
const _ecgGreen = Color(0xFF22E36B);
const _plethCyan = Color(0xFF18C9E8);
const _respYellow = Color(0xFFEAC84B);

/// Monitor multiparámetro que reproduce visualmente un escenario de ECG.
/// Recibe el id del escenario y obtiene los datos del repositorio; si no existe
/// muestra un estado de error en lugar de fallar.
class EcgMonitorScreen extends StatefulWidget {
  final String scenarioId;
  const EcgMonitorScreen({super.key, required this.scenarioId});

  @override
  State<EcgMonitorScreen> createState() => _EcgMonitorScreenState();
}

class _EcgMonitorScreenState extends State<EcgMonitorScreen>
    with SingleTickerProviderStateMixin {
  static const _repo = EcgScenarioRepository();

  EcgScenario? _scenario;
  late EcgGenerator _ecg;
  late final AnimationController _blink;
  final EcgAudioService _audio = EcgAudioService();
  bool _running = true;
  bool _showInfo = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _scenario = _repo.getById(widget.scenarioId);
    final s = _scenario;
    if (s != null) {
      _ecg = EcgGenerator(s.rhythm, s.heartRate > 0 ? s.heartRate.toDouble() : 150);
      _initAudio(s);
    }
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  Future<void> _initAudio(EcgScenario s) async {
    await _audio.init();
    if (!mounted) return;
    final rhythmType = _mapRhythmToAudio(s.rhythm);
    _audio.playRhythmLoop(rhythmType);
  }

  EcgRhythmTypeForAudio _mapRhythmToAudio(EcgRhythm rhythm) {
    switch (rhythm) {
      case EcgRhythm.vfib:
        return EcgRhythmTypeForAudio.fv;
      case EcgRhythm.vtach:
      case EcgRhythm.torsades:
        return EcgRhythmTypeForAudio.tv;
      case EcgRhythm.asystole:
        return EcgRhythmTypeForAudio.asistolia;
      case EcgRhythm.pea:
        return EcgRhythmTypeForAudio.aesp;
      case EcgRhythm.svt:
        return EcgRhythmTypeForAudio.tsv;
      case EcgRhythm.atrialFibrillation:
      case EcgRhythm.atrialFlutter:
        return EcgRhythmTypeForAudio.fa;
      case EcgRhythm.avBlock1:
      case EcgRhythm.avBlock2TypeI:
      case EcgRhythm.avBlock2TypeII:
      case EcgRhythm.avBlock3:
        return EcgRhythmTypeForAudio.bav;
      default:
        return EcgRhythmTypeForAudio.normal;
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    _audio.dispose();
    super.dispose();
  }

  // ── Señales derivadas ───────────────────────────────────────────────────────
  double _ecgSample(double t) => _ecg.sample(t);

  double _plethSample(double t) {
    final s = _scenario!;
    if (!s.pulsePresent || s.heartRate <= 0) {
      // Sin pulso perfundible: línea casi plana con ruido mínimo.
      return 0.02 * sin(2 * pi * 0.3 * t);
    }
    final period = 60.0 / s.heartRate;
    final p = (t % period) / period;
    final up = sin(pi * p.clamp(0.0, 1.0));
    var v = up * up; // ascenso sistólico
    // Muesca dicrótica.
    final d = (p - 0.45);
    v += 0.18 * exp(-(d * d) / 0.004);
    return v * 0.85 - 0.32;
  }

  double _respSample(double t) {
    final s = _scenario!;
    if (s.respRate <= 0) return 0.0;
    return sin(2 * pi * t * s.respRate / 60.0);
  }

  @override
  Widget build(BuildContext context) {
    final s = _scenario;
    if (s == null) return _notFound(context);

    final alarmColor = s.alarm.color;
    final isCritical = s.alarm == AlarmLevel.critical;

    return Scaffold(
      backgroundColor: _monitorBg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _blink,
          builder: (context, _) {
            final pulse = isCritical ? (0.4 + 0.6 * _blink.value) : 1.0;
            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isCritical
                      ? alarmColor.withValues(alpha: pulse)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  _topBar(s, alarmColor, pulse),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Ondas a la izquierda.
                        Expanded(
                          flex: 7,
                          child: _wavesColumn(s),
                        ),
                        // Constantes a la derecha.
                        SizedBox(
                          width: 116,
                          child: _vitalsColumn(s, pulse),
                        ),
                      ],
                    ),
                  ),
                  if (_showInfo) _infoPanel(s),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Barra superior ──────────────────────────────────────────────────────────
  Widget _topBar(EcgScenario s, Color alarmColor, double pulse) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: const BoxDecoration(
        color: _monitorPanel,
        border: Border(bottom: BorderSide(color: _monitorBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.white70),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'CAMA 01 · DII · ${s.category}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          // Chip de alarma.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: alarmColor.withValues(
                  alpha: s.alarm == AlarmLevel.critical ? pulse * 0.9 : 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: alarmColor.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Icon(
                  s.alarm == AlarmLevel.critical
                      ? Icons.warning_amber_rounded
                      : Icons.favorite_rounded,
                  size: 13,
                  color: s.alarm == AlarmLevel.critical
                      ? Colors.white
                      : alarmColor,
                ),
                const SizedBox(width: 5),
                Text(
                  s.alarm.label,
                  style: TextStyle(
                    color: s.alarm == AlarmLevel.critical
                        ? Colors.white
                        : alarmColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _running = !_running),
            icon: Icon(
              _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white70,
              size: 22,
            ),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () => setState(() => _showInfo = !_showInfo),
            icon: Icon(
              _showInfo
                  ? Icons.info_rounded
                  : Icons.info_outline_rounded,
              color: _showInfo ? _plethCyan : Colors.white70,
              size: 20,
            ),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _muted = !_muted;
                _audio.muted = _muted;
              });
            },
            icon: Icon(
              _muted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              color: _muted ? Colors.white38 : Colors.white70,
              size: 20,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ── Columna de ondas ────────────────────────────────────────────────────────
  Widget _wavesColumn(EcgScenario s) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: _traceLane(
            label: 'ECG II',
            color: _ecgGreen,
            grid: true,
            child: MonitorTrace(
              sampler: _ecgSample,
              color: _ecgGreen,
              windowSeconds: 4.5,
              amplitude: 0.30,
              strokeWidth: 1.8,
              running: _running,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: _traceLane(
            label: 'SpO₂ Pleth',
            color: _plethCyan,
            child: MonitorTrace(
              sampler: _plethSample,
              color: _plethCyan,
              windowSeconds: 4.5,
              amplitude: 0.55,
              strokeWidth: 1.8,
              running: _running,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: _traceLane(
            label: 'Resp',
            color: _respYellow,
            child: MonitorTrace(
              sampler: _respSample,
              color: _respYellow,
              windowSeconds: 9.0,
              amplitude: 0.40,
              strokeWidth: 1.6,
              running: _running,
            ),
          ),
        ),
      ],
    );
  }

  Widget _traceLane({
    required String label,
    required Color color,
    required Widget child,
    bool grid = false,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 4, 0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _monitorBorder),
      ),
      child: Stack(
        children: [
          if (grid)
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter(color)),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: child,
            ),
          ),
          Positioned(
            left: 8,
            top: 5,
            child: Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Columna de constantes ───────────────────────────────────────────────────
  Widget _vitalsColumn(EcgScenario s, double pulse) {
    final hrColor = s.alarm.color;
    final hrBlink =
        s.alarm == AlarmLevel.critical ? hrColor.withValues(alpha: pulse) : hrColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: _vitalTile(
              label: 'FC',
              unit: 'lpm',
              value: s.hrText,
              color: hrBlink,
              big: true,
              icon: Icons.favorite_rounded,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: 4,
            child: _vitalTile(
              label: 'SpO₂',
              unit: '%',
              value: s.spo2Text,
              color: _plethCyan,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: 4,
            child: _vitalTile(
              label: 'Resp',
              unit: 'rpm',
              value: s.respText,
              color: _respYellow,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: 4,
            child: _vitalTile(
              label: 'PA NI',
              unit: 'mmHg',
              value: s.bpText,
              color: const Color(0xFFE85AAE),
              small: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalTile({
    required String label,
    required String unit,
    required String value,
    required Color color,
    bool big = false,
    bool small = false,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _monitorPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _monitorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 3),
              ],
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: big ? 46 : (small ? 22 : 30),
                fontWeight: FontWeight.w800,
                height: 1.0,
                fontFeatures: const [],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              unit,
              style: TextStyle(
                color: color.withValues(alpha: 0.6),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Panel informativo (nota clínica) ────────────────────────────────────────
  Widget _infoPanel(EcgScenario s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: _monitorPanel,
        border: Border(top: BorderSide(color: _monitorBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 14, color: _plethCyan),
              const SizedBox(width: 6),
              Text(
                'Interpretación',
                style: TextStyle(
                  color: _plethCyan.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (!s.pulsePresent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SIN PULSO',
                    style: TextStyle(
                      color: AppColors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.clinicalNote,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _notFound(BuildContext context) {
    return Scaffold(
      backgroundColor: _monitorBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monitor_heart_outlined,
                size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            const Text('Escenario no encontrado',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuadrícula tenue de fondo estilo papel de ECG.
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final fine = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;
    final bold = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..strokeWidth = 0.8;
    const step = 12.0;
    var i = 0;
    for (double x = 0; x <= size.width; x += step, i++) {
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), i % 5 == 0 ? bold : fine);
    }
    i = 0;
    for (double y = 0; y <= size.height; y += step, i++) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), i % 5 == 0 ? bold : fine);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.color != color;
}
