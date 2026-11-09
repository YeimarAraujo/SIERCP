import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:siercp/features/simulation/data/aed/wav_generator.dart';
import 'package:siercp/features/simulation/data/airway/airway_scenarios.dart';

enum _AirwayPhase {
  start,
  initialAssessment,
  headTiltChinLift,
  jawThrust,
  evaluateBreathing,
  preOxygenate,
  chooseDevice,
  verifyPlacement,
  correctPlacement,
  esophagealIntubation,
  secureDevice,
  confirmCapnography,
  completed,
}

class AirwaySimulatorScreen extends StatefulWidget {
  const AirwaySimulatorScreen({super.key});

  @override
  State<AirwaySimulatorScreen> createState() => _AirwaySimulatorScreenState();
}

class _AirwaySimulatorScreenState extends State<AirwaySimulatorScreen> {
  _AirwayPhase _phase = _AirwayPhase.start;
  late AirwayScenario _scenario;
  final AudioPlayer _player = AudioPlayer();
  Directory? _tempDir;
  bool _soundEnabled = true;
  String _feedbackText = '';
  int _fileCounter = 0;
  int _attempts = 0;
  double _spo2 = 94;
  double _etco2 = 0;

  @override
  void initState() {
    super.initState();
    _scenario = kAirwayScenarios[0];
    _initAudio();
  }

  Future<void> _initAudio() async {
    _tempDir = await getTemporaryDirectory();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _setPhase(_AirwayPhase p, {String feedback = ''}) {
    setState(() {
      _phase = p;
      if (feedback.isNotEmpty) _feedbackText = feedback;
    });
  }

  String _nextFile(String prefix) {
    _fileCounter++;
    return '${_tempDir?.path ?? "."}/${prefix}_$_fileCounter.wav';
  }

  Future<void> _playTone(double freq, double dur, {double amp = 0.4}) async {
    if (!_soundEnabled) return;
    try {
      final samples = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(freq, dur, amplitude: amp),
        3, 20,
      );
      final wav = WavGenerator.generateWav(samples: samples);
      final file = File(_nextFile('aw'));
      await file.writeAsBytes(wav);
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  Future<void> _playBuzz() async {
    if (!_soundEnabled) return;
    try {
      final samples = WavGenerator.applyEnvelope(
        WavGenerator.squareWave(150, 0.4, amplitude: 0.4), 5, 60,
      );
      final wav = WavGenerator.generateWav(samples: samples);
      final file = File(_nextFile('aw_buzz'));
      await file.writeAsBytes(wav);
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  Future<void> _playChime() async {
    if (!_soundEnabled) return;
    try {
      final c = WavGenerator.applyEnvelope(WavGenerator.sineWave(523, 0.12, amplitude: 0.5), 3, 20);
      final e = WavGenerator.applyEnvelope(WavGenerator.sineWave(659, 0.12, amplitude: 0.5), 3, 20);
      final g = WavGenerator.applyEnvelope(WavGenerator.sineWave(784, 0.25, amplitude: 0.5), 3, 50);
      final gap = WavGenerator.silence(0.04);
      final wav = WavGenerator.generateWav(samples: WavGenerator.concat([c, gap, e, gap, g]));
      final file = File(_nextFile('aw_chime'));
      await file.writeAsBytes(wav);
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  void _onStart() {
    if (_phase != _AirwayPhase.start) return;
    _spo2 = _scenario.breathing ? 94 : 88;
    _etco2 = 0;
    _attempts = 0;
    _setPhase(_AirwayPhase.initialAssessment, feedback:
        'Evaluacion inicial:\n'
        'Paciente: ${_scenario.title}\n'
        'Consciente: ${_scenario.conscious ? "Si" : "No"}\n'
        'Respira: ${_scenario.breathing ? "Si" : "No"}\n'
        'SpO2: $_spo2%\n\n'
        'Active equipo de via aerea. Verifique equipamiento:\n'
        'BVM, OPA, SGA, TET, laringoscopio, aspirador.\n'
        'Preoxigene con O2 15 L/min si es posible.');
    _playTone(660, 0.1);
  }

  void _onScenarioChanged(AirwayScenario s) {
    _player.stop();
    setState(() {
      _scenario = s;
      _phase = _AirwayPhase.start;
      _feedbackText = '';
    });
  }

  void _onJawThrust() {
    if (_phase != _AirwayPhase.initialAssessment) return;
    _setPhase(_AirwayPhase.jawThrust, feedback:
        'Traccion Mandibular realizada.\n'
        'Via aerea abierta sin movilizar columna cervical.\n'
        'Evalue respiracion durante 10 segundos.');
    _playTone(660, 0.1);
  }

  void _onOpenAirway() {
    if (_phase != _AirwayPhase.initialAssessment) return;
    _setPhase(_AirwayPhase.headTiltChinLift, feedback:
        'Head-tilt Chin-lift realizado.\n'
        'Via aerea abierta. Evalue respiracion durante 10 segundos.');
    _playTone(660, 0.1);
  }

  void _onEvaluateBreathing() {
    if (_phase != _AirwayPhase.headTiltChinLift &&
        _phase != _AirwayPhase.jawThrust) return;
    if (_scenario.breathing) {
      _setPhase(_AirwayPhase.evaluateBreathing, feedback:
          'Respiracion presente.\n'
          'Frecuencia: ${_scenario.conscious ? "16" : "8"} respiraciones por minuto\n'
          'SpO2: $_spo2%\n'
          'Ventile con BVM + O2 a 15 L/min.');
    } else {
      _setPhase(_AirwayPhase.evaluateBreathing, feedback:
          'NO respiracion detectable.\n'
          'Inicie ventilacion con BVM + O2 a 15 L/min.\n'
          'Considere dispositivo de via aerea avanzada.');
    }
    _playTone(440, 0.15);
  }

  void _onPreOxygenate() {
    if (_phase != _AirwayPhase.evaluateBreathing) return;
    _spo2 = (_spo2 + 3).clamp(0, 98).toDouble();
    _playTone(660, 0.1);
    _setPhase(_AirwayPhase.preOxygenate, feedback:
        'Ventilacion con BVM + O2 15 L/min iniciada.\n'
        'SpO2: $_spo2% (mejorando).\n'
        'Seleccione el dispositivo de via aerea mas adecuado.');
  }

  void _onChooseDevice(AirwayCorrectDevice device) {
    if (_phase != _AirwayPhase.preOxygenate &&
        _phase != _AirwayPhase.chooseDevice) return;
    _attempts++;
    if (device == _scenario.correctDevice) {
      _playChime();
      _setPhase(_AirwayPhase.verifyPlacement, feedback:
          'Dispositivo colocado correctamente.\n'
          'Verifique ubicacion mediante:\n'
          '- Auscultacion bilateral de murmullo vesicular\n'
          '- Elevacion del torax con cada ventilacion\n'
          '- Capnografia (ETCO2)');
    } else {
      _playBuzz();
      _spo2 = (_spo2 - 5).clamp(0, 100).toDouble();
      String hint;
      switch (device) {
        case AirwayCorrectDevice.opa:
          hint = 'OPA no es suficiente para este escenario. '
              'Considere un dispositivo mas avanzado.';
        case AirwayCorrectDevice.sga:
          hint = 'SGA no es el dispositivo ideal. '
              'Evalue la necesidad de un dispositivo definitivo.';
        case AirwayCorrectDevice.ett:
          hint = 'TET puede ser muy invasivo como primer paso. '
              'Considere la via aerea escalonada.';
        case AirwayCorrectDevice.bvmOnly:
          hint = 'Solo BVM no es suficiente. '
              'Agregue un dispositivo de via aerea.';
        case AirwayCorrectDevice.noDevice:
          hint = 'Este escenario requiere un dispositivo. '
              'Seleccione el adecuado.';
      }
      _setPhase(_AirwayPhase.chooseDevice, feedback:
          'Dispositivo incorrecto. $hint\n'
          'SpO2: $_spo2%\n'
          'Intento $_attempts. Reintente.');
    }
  }

  void _onVerifyCorrect() {
    if (_phase != _AirwayPhase.verifyPlacement) return;
    _playChime();
    _setPhase(_AirwayPhase.correctPlacement, feedback:
        'Ubicacion correcta confirmada.\n'
        '- Auscultacion: murmullo vesicular bilateral presente\n'
        '- ETCO2: ${_etco2.toStringAsFixed(0)} mmHg (onda cuadrada sostenida)\n'
        '- SatO2: $_spo2%\n'
        'Asegure y fije el dispositivo.');
  }

  void _onVerifyIncorrect() {
    if (_phase != _AirwayPhase.verifyPlacement) return;
    _playBuzz();
    _spo2 = (_spo2 - 8).clamp(0, 100).toDouble();
    _setPhase(_AirwayPhase.esophagealIntubation, feedback:
        'INTUBACION ESOFAGICA DETECTADA.\n'
        '- Sin murmullo vesicular\n'
        '- ETCO2: 0 mmHg (sin onda)\n'
        '- Distension gastrica\n'
        '- SpO2: $_spo2% (descendiendo)\n'
        'Retire el tubo inmediatamente. Ventile con BVM + OPA.');
  }

  void _onReattempt() {
    if (_phase != _AirwayPhase.esophagealIntubation) return;
    _playTone(660, 0.1);
    _setPhase(_AirwayPhase.chooseDevice, feedback:
        'Tubo retirado. Ventilacion con BVM + OPA restablecida.\n'
        'Reintente colocacion de dispositivo.\n'
        'Considere usar videolaringoscopio o dispositivo diferente.');
  }

  void _onSecureDevice() {
    if (_phase != _AirwayPhase.correctPlacement &&
        _phase != _AirwayPhase.confirmCapnography) return;
    _playChime();
    _setPhase(_AirwayPhase.secureDevice, feedback:
        'Dispositivo asegurado y fijado.\n'
        '- Confirmar con capnografia continua\n'
        '- Solicitar RX de torax para verificar profundidad\n'
        '- Documentar procedimiento\n'
        '- Monitorizar ventilacion y oxigenacion.');
  }

  void _onComplete() {
    if (_phase != _AirwayPhase.secureDevice) return;
    _playChime();
    _setPhase(_AirwayPhase.completed, feedback:
        'COMPLETADO: Manejo de via aerea finalizado.\n'
        'Escenario: ${_scenario.title}\n'
        'Dispositivo utilizado: ${_scenario.correctDevice.name}\n'
        'Intentos: $_attempts\n'
        'SpO2 final: $_spo2%\n'
        'ETCO2 final: ${_etco2.toStringAsFixed(0)} mmHg');
  }

  void _reset() {
    _player.stop();
    setState(() {
      _phase = _AirwayPhase.start;
      _feedbackText = '';
    });
  }

  Color _feedbackColor(String text) {
    if (text.contains('LESION') || text.contains('INTUBACION ESOFAGICA') ||
        text.contains('NO respira') || text.contains('no es la opcion') ||
        text.contains('no es suficiente') || text.contains('no es el primer') ||
        text.contains('puede causar')) {
      return const Color(0xFFFF6B6B);
    }
    if (text.contains('COMPLETADO') || text.contains('correcta') ||
        text.contains('asegurado') || text.contains('exitosamente')) {
      return const Color(0xFF00FF88);
    }
    return const Color(0xFFE0E0E0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textP = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Via Aerea', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded, size: 20),
            onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
          ),
          PopupMenuButton<AirwayScenario>(
            icon: const Icon(Icons.list_rounded, size: 20),
            onSelected: _onScenarioChanged,
            itemBuilder: (_) => kAirwayScenarios.map((s) =>
              PopupMenuItem(value: s, child: Text(s.title, style: const TextStyle(fontSize: 13)))
            ).toList(),
          ),
        ],
      ),
      backgroundColor: isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _scenario.complication != AirwayComplication.none
                ? Colors.orange.withValues(alpha: 0.1)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_scenario.title, style: TextStyle(
                        color: textP, fontSize: 15, fontWeight: FontWeight.w800,
                      )),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_scenario.description, style: TextStyle(
                  color: textP.withValues(alpha: 0.6), fontSize: 11,
                )),
                const SizedBox(height: 8),
                Text(_scenario.situation, style: TextStyle(
                  color: textP.withValues(alpha: 0.8), fontSize: 12, height: 1.4,
                )),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── Monitor display: ventilator-style vital signs ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF001122),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // SpO2
                            Expanded(
                              child: Column(
                                children: [
                                  Text('SpO₂', style: TextStyle(color: Colors.grey, fontSize: 9, letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text('${_spo2.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color: _spo2 >= 90 ? const Color(0xFF00FF88) : const Color(0xFFFF6B6B),
                                      fontSize: 36, fontWeight: FontWeight.w800,
                                    )),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.1)),
                            // ETCO2
                            Expanded(
                              child: Column(
                                children: [
                                  Text('ETCO₂', style: TextStyle(color: Colors.grey, fontSize: 9, letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text(_etco2 > 0 ? '${_etco2.toStringAsFixed(0)}' : '--',
                                    style: TextStyle(
                                      color: _etco2 > 0 ? const Color(0xFFFFD700) : Colors.grey,
                                      fontSize: 36, fontWeight: FontWeight.w800,
                                    )),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _phase.name.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(color: const Color(0xFF00BFFF), fontSize: 9, letterSpacing: 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── Feedback area ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A1628) : const Color(0xFF1A2332),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFF2A3A4A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_feedbackText.isNotEmpty)
                          Text(
                            _feedbackText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _feedbackColor(_feedbackText),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.6,
                            ),
                          )
                        else
                          Text(
                            'Presione Iniciar para comenzar\nel manejo de la via aerea',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF888888), fontSize: 12, height: 1.5),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── Phase label ──
                  Text(
                    _phase == _AirwayPhase.completed ? 'COMPLETADO' : 'SIMULADOR DE VIA AEREA',
                    style: TextStyle(
                      color: _phase == _AirwayPhase.completed ? const Color(0xFF00FF88) : const Color(0xFF00BFFF),
                      fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildControls(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback? onTap, {Color? color, bool destructive = false, double height = 50}) {
    final c = color ?? (destructive ? const Color(0xFFEF4444) : const Color(0xFF3B82F6));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: c.withValues(alpha: 0.1),
            foregroundColor: c,
            side: BorderSide(color: c.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildChoiceButton(String label, AirwayCorrectDevice device) {
    final c = const Color(0xFF10B981);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: c,
            side: BorderSide(color: c.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _onChooseDevice(device),
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildControls() {
    switch (_phase) {
      case _AirwayPhase.start:
        return _buildButton('Iniciar', _onStart, color: const Color(0xFF10B981));
      case _AirwayPhase.initialAssessment:
        if (_scenario.complication == AirwayComplication.cervicalInjury) {
          return _buildButton('Traccion Mandibular (Jaw Thrust)', _onJawThrust,
              color: const Color(0xFFF59E0B));
        }
        return _buildButton('Abrir Via Aerea (Head-tilt Chin-lift)', _onOpenAirway,
            color: const Color(0xFF3B82F6));
      case _AirwayPhase.headTiltChinLift:
      case _AirwayPhase.jawThrust:
        return _buildButton('Evaluar Respiracion (10 seg)', _onEvaluateBreathing,
            color: const Color(0xFF8B5CF6));
      case _AirwayPhase.evaluateBreathing:
        return Column(children: [
          _buildButton('Ventilar con BVM + O2 (15 L/min)', _onPreOxygenate,
              color: const Color(0xFF3B82F6)),
          _buildButton('Seleccionar Dispositivo', () {
            _setPhase(_AirwayPhase.chooseDevice,
                feedback: 'Seleccione el dispositivo mas adecuado:\n'
                'Considere la via aerea segun el escenario.');
          }, color: const Color(0xFF8B5CF6)),
        ]);
      case _AirwayPhase.preOxygenate:
        return Column(children: [
          Text('Seleccione dispositivo:', style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 11, fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 8),
          _buildChoiceButton('BVM + Canula Orofaringea (OPA)', AirwayCorrectDevice.opa),
          _buildChoiceButton('Mascarilla Laringea (SGA)', AirwayCorrectDevice.sga),
          _buildChoiceButton('Tubo Endotraqueal (TET)', AirwayCorrectDevice.ett),
          _buildChoiceButton('Solo BVM (sin OPA)', AirwayCorrectDevice.bvmOnly),
          _buildChoiceButton('Solo OPA (sin BVM)', AirwayCorrectDevice.noDevice),
        ]);
      case _AirwayPhase.chooseDevice:
        return Column(children: [
          Text('Seleccione dispositivo:', style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 11, fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 8),
          _buildChoiceButton('BVM + Canula Orofaringea (OPA)', AirwayCorrectDevice.opa),
          _buildChoiceButton('Mascarilla Laringea (SGA)', AirwayCorrectDevice.sga),
          _buildChoiceButton('Tubo Endotraqueal (TET)', AirwayCorrectDevice.ett),
          _buildChoiceButton('Solo BVM (sin OPA)', AirwayCorrectDevice.bvmOnly),
          _buildChoiceButton('Solo OPA (sin BVM)', AirwayCorrectDevice.noDevice),
        ]);
      case _AirwayPhase.verifyPlacement:
        return Column(
          children: [
            _buildButton('Verificar Correcta', _onVerifyCorrect,
                color: const Color(0xFF10B981)),
            _buildButton('Intubacion Esofagica', _onVerifyIncorrect,
                color: const Color(0xFFEF4444)),
          ],
        );
      case _AirwayPhase.esophagealIntubation:
        return _buildButton('Retirar y Reintentar (BVM + OPA)', _onReattempt,
            color: const Color(0xFFF59E0B));
      case _AirwayPhase.correctPlacement:
        return _buildButton('Asegurar y Fijar Dispositivo', _onSecureDevice,
            color: const Color(0xFF10B981));
      case _AirwayPhase.confirmCapnography:
        return _buildButton('Fijar y Confirmar con RX Torax', _onSecureDevice,
            color: const Color(0xFF10B981));
      case _AirwayPhase.secureDevice:
        return _buildButton('Finalizar Escenario', _onComplete,
            color: const Color(0xFF10B981));
      case _AirwayPhase.completed:
        return Column(
          children: [
            _buildButton('Repetir Escenario', _reset,
                color: const Color(0xFF3B82F6)),
            _buildButton('Volver', () => Navigator.pop(context),
                color: const Color(0xFF6B7280)),
          ],
        );
    }
  }
}
