import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:siercp/features/simulation/data/aed/wav_generator.dart';
import 'package:siercp/features/simulation/data/acls/acls_scenarios.dart';

enum _AclsPhase {
  assessment,
  cprCycle,
  rhythmCheck,
  shockable,
  charging,
  shockDelivered,
  nonShockable,
  drugAdmin,
  rosc,
  manageCause,
  completed,
}

class AclsSimulatorScreen extends StatefulWidget {
  const AclsSimulatorScreen({super.key});

  @override
  State<AclsSimulatorScreen> createState() => _AclsSimulatorScreenState();
}

class _AclsSimulatorScreenState extends State<AclsSimulatorScreen> {
  _AclsPhase _phase = _AclsPhase.assessment;
  late AclsScenario _scenario;
  final AudioPlayer _player = AudioPlayer();
  Directory? _tempDir;
  bool _soundEnabled = true;
  String _feedbackText = '';
  int _fileCounter = 0;
  int _cycleCount = 0;
  int _shockCount = 0;
  bool _epinephrineGiven = false;
  bool _amiodaroneGiven = false;
  bool _airwaySecured = false;
  double _etco2 = 28;

  @override
  void initState() {
    super.initState();
    _scenario = kAclsScenarios[0];
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

  void _setPhase(_AclsPhase p, {String feedback = ''}) {
    setState(() {
      _phase = p;
      if (feedback.isNotEmpty) _feedbackText = feedback;
    });
  }

  String _nextFile(String prefix) {
    _fileCounter++;
    return '${_tempDir?.path ?? "."}/${prefix}_$_fileCounter.wav';
  }

  Future<void> _playWav(List<double> samples) async {
    if (!_soundEnabled) return;
    try {
      final wav = WavGenerator.generateWav(samples: samples);
      final file = File(_nextFile('acls'));
      await file.writeAsBytes(wav);
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  Future<void> _playBeep(
      {double freq = 880, double dur = 0.08, double amp = 0.5}) async {
    await _playWav(WavGenerator.applyEnvelope(
        WavGenerator.sineWave(freq, dur, amplitude: amp), 2, 10));
  }

  Future<void> _playChime() async {
    final c = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(523, 0.12, amplitude: 0.5), 3, 20);
    final e = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(659, 0.12, amplitude: 0.5), 3, 20);
    final g = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(784, 0.25, amplitude: 0.5), 3, 50);
    await _playWav(WavGenerator.concat(
        [c, WavGenerator.silence(0.04), e, WavGenerator.silence(0.04), g]));
  }

  Future<void> _playCprMetronome() async {
    if (!_soundEnabled) return;
    final beep = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(800, 0.04, amplitude: 0.5), 1, 20);
    final pause = WavGenerator.silence(60.0 / 110 - 0.04);
    final loop = WavGenerator.concat(
        List.filled(8, beep).expand((b) => [b, pause]).toList());
    await _playWav(loop);
  }

  void _resetState() {
    _cycleCount = 0;
    _shockCount = 0;
    _epinephrineGiven = false;
    _amiodaroneGiven = false;
    _airwaySecured = false;
  }

  void _onNoPulse() {
    if (_phase != _AclsPhase.assessment) return;
    _startCprCycle();
  }

  void _startCprCycle() {
    _cycleCount++;
    _etco2 = (_etco2 + 2).clamp(0, 45).toDouble();
    _setPhase(_AclsPhase.cprCycle,
        feedback: 'CICLO $_cycleCount DE RCP\n'
            'Inicie compresiones toracicas:\n'
            'Frecuencia: 100-120 por minuto\n'
            'Profundidad: 5-6 cm\n'
            'Relacion 30:2 (o compresiones continuas si via aerea avanzada)\n'
            'Releve cada 2 minutos si hay personal disponible.\n'
            'ETCO2 actual: ${_etco2.toStringAsFixed(0)} mmHg\n'
            '(ETCO2 > 20 mmHg indica RCP de calidad)');
    _playCprMetronome();
  }

  void _onCprDone() {
    if (_phase != _AclsPhase.cprCycle) return;
    _setPhase(_AclsPhase.rhythmCheck,
        feedback: 'Pausa de compresiones.\n'
            'Analizando ritmo cardiaco en monitor...\n'
            'Verifique el ritmo mientras mantiene via aerea permeable.\n'
            'ETCO2 durante RCP: ${_etco2.toStringAsFixed(0)} mmHg\n'
            'Evalue pulso carotideo durante 5-10 segundos.');
    _playBeep(freq: 660);
  }

  void _onPulsePresent() {
    if (_phase != _AclsPhase.rhythmCheck) return;
    _setPhase(_AclsPhase.rosc,
        feedback: 'PULSO PRESENTE - ROSC ALCANZADO\n'
            'Frecuencia: ${_scenario.id == "acls_post_rosc" ? "110" : "90"} lpm\n'
            'Presion arterial: ${_scenario.id == "acls_post_rosc" ? "80/40" : "110/70"} mmHg\n'
            'ETCO2: ${(_etco2 + 10).toStringAsFixed(0)} mmHg (aumento abrupto = ROSC)\n'
            'SpO2: 94%\n\n'
            'Cuidados post-paro:\n'
            '- Mantener PAM >= 65 mmHg\n'
            '- SatO2 94-98%\n'
            '- Normocapnia (ETCO2 35-40 mmHg)\n'
            '- Control termico (33-36 grados C)\n'
            '- Electrocardiograma de 12 derivaciones\n'
            '- Considerar coronariografia urgente');
    _playChime();
  }

  void _onNoPulseCheck() {
    if (_phase != _AclsPhase.rhythmCheck) return;
    if (_scenario.initialRhythm == AclsRhythm.vf ||
        _scenario.initialRhythm == AclsRhythm.tvsp) {
      _setPhase(_AclsPhase.shockable,
          feedback:
              'SIN PULSO. Ritmo: ${_scenario.initialRhythm.name.toUpperCase()}\n'
              'RITMO DESFIBRILABLE\n'
              'Cargue desfibrilador a 200 J (bifasico).\n'
              'Anuncie: "ALEJENSE" - verifique que nadie toca al paciente.\n'
              'Administre descarga.');
    } else {
      _setPhase(_AclsPhase.nonShockable,
          feedback:
              'SIN PULSO. Ritmo: ${_scenario.initialRhythm.name.toUpperCase()}\n'
              'RITMO NO DESFIBRILABLE\n'
              'Continue RCP de alta calidad.\n'
              'Administre adrenalina 1 mg IV/IO lo antes posible.\n'
              'Busque causas reversibles (5H y 5T).');
    }
  }

  void _onShock() {
    if (_phase != _AclsPhase.shockable) return;
    _shockCount++;
    _setPhase(_AclsPhase.charging,
        feedback: 'DESFIBRILADOR CARGANDO...\n'
            'Descarga numero $_shockCount\n'
            'Energia: 200-360 J (bifasico)\n'
            'Verifique que nadie esta en contacto con el paciente.');
    _playBeep(freq: 1200, dur: 0.5);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _setPhase(_AclsPhase.shockDelivered,
          feedback: 'DESCARGA ADMINISTRADA\n'
              'Reanude RCP inmediatamente (no verifique ritmo/pulso aun).\n'
              'Comprima 5 ciclos (2 min) antes de reevaluar.\n'
              '${_shockCount >= 3 ? "Administre amiodarona 300 mg IV/IO tras la 3ra descarga." : ""}\n'
              '${_shockCount >= 2 && !_epinephrineGiven ? "Administre adrenalina 1 mg IV/IO cada 3-5 min." : ""}');
      _playWav(WavGenerator.concat([
        WavGenerator.applyEnvelope(
            WavGenerator.sineWave(60, 0.3, amplitude: 0.8), 2, 100),
        WavGenerator.noise(0.05, amplitude: 0.3),
        WavGenerator.applyEnvelope(
            WavGenerator.sineWave(180, 0.3, amplitude: 0.5), 10, 80),
      ]));
    });
  }

  void _onContinueAfterShock() {
    if (_phase != _AclsPhase.shockDelivered) return;
    _etco2 = (_etco2 + 1).clamp(0, 45).toDouble();
    if (_shockCount >= 3 && !_amiodaroneGiven) {
      _setPhase(_AclsPhase.drugAdmin,
          feedback: 'Seleccione farmaco segun algoritmo ACLS:\n'
              '1. Adrenalina 1 mg IV/IO ${_epinephrineGiven ? "(repetir)" : ""}\n'
              '2. Amiodarona 300 mg IV/IO ${_amiodaroneGiven ? "(administrada)" : "(si 3ra descarga)"}\n'
              '3. Asegurar via aerea ${_airwaySecured ? "(completado)" : ""}\n\n'
              'Luego: Reanude RCP 2 minutos.');
    } else if (_shockCount >= 2 && !_epinephrineGiven) {
      _setPhase(_AclsPhase.drugAdmin,
          feedback: 'Seleccione farmaco segun algoritmo ACLS:\n'
              '1. Adrenalina 1 mg IV/IO\n'
              '${!_airwaySecured ? "2. Asegurar via aerea\n" : ""}\n'
              'Luego: Reanude RCP 2 minutos.');
    } else {
      _startCprCycle();
    }
  }

  void _onGiveEpinephrine() {
    if (_phase != _AclsPhase.drugAdmin) return;
    _epinephrineGiven = true;
    _playBeep(freq: 523, dur: 0.15);
    String msg = 'Adrenalina 1 mg IV/IO administrada.\n'
        'Repetir cada 3-5 minutos durante el paro.\n';
    if (!_amiodaroneGiven && _shockCount >= 3) {
      msg += 'Administre amiodarona si FV/TVSP persiste.\n';
    }
    if (!_airwaySecured) {
      msg += 'Asegure via aerea si no lo ha hecho.\n';
    }
    msg += '\nReanude RCP por 2 minutos.';
    _setPhase(_AclsPhase.drugAdmin, feedback: msg);
  }

  void _onGiveAmiodarone() {
    if (_phase != _AclsPhase.drugAdmin) return;
    _amiodaroneGiven = true;
    _playBeep(freq: 659, dur: 0.15);
    String msg = 'Amiodarona 300 mg IV/IO administrada.\n';
    if (!_epinephrineGiven) {
      msg += 'Administre adrenalina 1 mg IV/IO.\n';
    }
    if (!_airwaySecured) {
      msg += 'Asegure via aerea.\n';
    }
    msg += '\nPuede repetir amiodarona 150 mg en 3-5 min si persiste FV.\n'
        'Reanude RCP por 2 minutos.';
    _setPhase(_AclsPhase.drugAdmin, feedback: msg);
  }

  void _onSecureAirway() {
    if (_phase != _AclsPhase.drugAdmin) return;
    _airwaySecured = true;
    _playBeep(freq: 440, dur: 0.12);
    _setPhase(_AclsPhase.drugAdmin,
        feedback: 'Via aerea avanzada asegurada (TET/ML).\n'
            'Confirme con capnografia (ETCO2) y auscultacion.\n'
            'Ventile a 10 rpm (1 ventilacion cada 6 segundos).\n'
            'Compresiones continuas sin pausas para ventilacion.\n'
            'Fije el tubo a la profundidad correcta.\n\n'
            'Continue RCP por 2 minutos.');
  }

  void _onContinueCpr() {
    if (_phase != _AclsPhase.drugAdmin && _phase != _AclsPhase.shockDelivered)
      return;
    if (_scenario.cause == AclsCause.postRosc) {
      _setPhase(_AclsPhase.rosc,
          feedback: 'ROSC ALCANZADO\n'
              'Presion arterial: ${_scenario.id == "acls_post_rosc" ? "80/40" : "110/70"} mmHg\n'
              'Frecuencia cardiaca: ${_scenario.id == "acls_post_rosc" ? "110" : "90"} lpm\n'
              'ETCO2: ${(_etco2 + 15).toStringAsFixed(0)} mmHg\n\n'
              'Cuidados post-paro inmediatos:\n'
              'Control termico (33-36 grados C)\n'
              'Coronariografia urgente\n'
              'Mantener PAM >= 65 mmHg\n'
              'SatO2 94-98%\n'
              'Ventilacion con normocapnia\n'
              'Evaluacion neurologica');
      _playChime();
      return;
    }
    if (_cycleCount >= _scenario.cyclesRequired) {
      _setPhase(_AclsPhase.manageCause,
          feedback: 'RCP avanzada completada: $_cycleCount ciclos.\n'
              'ETCO2 durante RCP: ${_etco2.toStringAsFixed(0)} mmHg.\n'
              'Busque y trate CAUSA REVERSIBLE:\n'
              '${_causeList(_scenario.cause)}');
      _playBeep(freq: 440, dur: 0.2);
      return;
    }
    _startCprCycle();
  }

  void _onTreatCause() {
    if (_phase != _AclsPhase.manageCause) return;
    String msg;
    switch (_scenario.cause) {
      case AclsCause.tamponade:
        msg = 'TAPONAMIENTO: pericardiocentesis.\n'
            'Ecografia FAST: derrame pericardico.\n'
            'Puncion subxifoidea guiada por ECO.\n'
            'Aguja 18G, dirigida a escapula izquierda.\n'
            'Drenar 20-30 mL -> mejoria hemodinamica.';
        break;
      case AclsCause.massivePe:
        msg = 'TEP MASIVO: trombolisis.\n'
            'Tenecteplasa 0.5 mg/kg IV en bolo.\n'
            'ECMO si disponible.\n'
            'Contraindicaciones: cirugia < 7 dias, ACV < 3 meses.';
        break;
      case AclsCause.ischemia:
        msg = 'ISQUEMIA: coronariografia urgente.\n'
            'IAMCEST -> ICP primaria.\n'
            'Antiagregacion + anticoagulacion.\n'
            'Balon de contrapulsacion si shock cardiogenico.';
        break;
      case AclsCause.hyperkalemia:
        msg = 'HIPERPOTASEMIA: tratamiento agudo.\n'
            'Gluconato de calcio 10 mL IV (estabiliza membrana).\n'
            'Insulina 10U + D5% 50 mL IV.\n'
            'Salbutamol nebulizado 10-20 mg.\n'
            'Kayexalato/patiromer si requiere.';
        break;
      case AclsCause.hypothermia:
        msg = 'HIPOTERMIA: calentamiento activo.\n'
            'Fluidos intravenosos calientes (40 grados C).\n'
            'Colchon de aire caliente o manta termica.\n'
            'Lavado peritoneal/gastrico con solucion caliente.\n'
            'ECMO si paro refractario.';
        break;
      case AclsCause.toxin:
        msg = 'TOXICOS: antídoto especifico.\n'
            'Active centro de toxicologia.\n'
            'Soporte vital avanzado mientras actua el antídoto.';
        break;
      case AclsCause.postRosc:
        msg = 'Causa tratada: cuidados post-paro.\n'
            'Continue atencion en UCI.\n'
            'Hipotermia terapeutica.\n'
            'Evaluacion neurologica seriada.';
        break;
      default:
        msg = 'No se identifico causa reversible especifica.\n'
            'Continue monitorizacion y cuidados post-paro.\n'
            'Revise las 5H y 5T nuevamente.';
    }
    _setPhase(_AclsPhase.completed, feedback: 'ESCENARIO COMPLETADO\n\n$msg');
    _playChime();
  }

  void _onRoscComplete() {
    if (_phase != _AclsPhase.rosc) return;
    if (_scenario.cause != AclsCause.none &&
        _scenario.cause != AclsCause.postRosc) {
      _setPhase(_AclsPhase.manageCause,
          feedback: 'ROSC estabilizado temporalmente.\n'
              'Ahora trate la causa subyacente.\n'
              '${_causeList(_scenario.cause)}');
      _playBeep();
    } else {
      _setPhase(_AclsPhase.completed,
          feedback: 'PACIENTE ESTABILIZADO\n\n'
              'Resumen:\n'
              'Ciclos de RCP: $_cycleCount\n'
              'Descargas: $_shockCount\n'
              'Adrenalina: ${_epinephrineGiven ? "Si" : "No"}\n'
              'Amiodarona: ${_amiodaroneGiven ? "Si" : "No"}\n'
              'Via aerea: ${_airwaySecured ? "Asegurada" : "No asegurada"}\n\n'
              'Ingreso a UCI.\n'
              'Hipotermia terapeutica si aplica.\n'
              'Evaluacion neurologica seriada.\n'
              'Prevencion secundaria.');
      _playChime();
    }
  }

  String _causeList(AclsCause cause) {
    switch (cause) {
      case AclsCause.tamponade:
        return '5T: Taponamiento cardiaco\n-> Pericardiocentesis';
      case AclsCause.massivePe:
        return '5T: Trombosis pulmonar (TEP)\n-> Trombolisis';
      case AclsCause.ischemia:
        return '5T: Trombosis coronaria (IAM)\n-> ICP / Fibrinolisis';
      case AclsCause.hyperkalemia:
        return '5H: Hiperpotasemia\n-> Gluconato Ca + Insulina/D5';
      case AclsCause.hypothermia:
        return '5H: Hipotermia\n-> Calentamiento activo';
      case AclsCause.toxin:
        return '5T: Toxicos\n-> Antidoto especifico';
      default:
        return 'Busque 5H y 5T:\n'
            'Hipoxia, Hipovolemia, H+, Hipo/Hiper-K, Hipotermia\n'
            'Trombosis (coronaria/pulmonar), Taponamiento,\n'
            'Toxicos, Tension (neumotorax)';
    }
  }

  void _onScenarioChanged(AclsScenario s) {
    _player.stop();
    setState(() {
      _scenario = s;
      _phase = _AclsPhase.assessment;
      _feedbackText = '';
      _resetState();
    });
  }

  void _reset() {
    _player.stop();
    setState(() {
      _phase = _AclsPhase.assessment;
      _feedbackText = '';
      _resetState();
    });
  }

  Color _feedbackColor(String text) {
    if (text.contains('PULSO PRESENTE') ||
        text.contains('ROSC ALCANZADO') ||
        text.contains('PACIENTE ESTABILIZADO') ||
        text.contains('ESCENARIO COMPLETADO')) {
      return const Color(0xFF00FF88);
    }
    if (text.contains('DESCARG') ||
        text.contains('SIN PULSO') ||
        text.contains('hipotension') ||
        text.contains('critico')) {
      return const Color(0xFFFF6B6B);
    }
    if (text.contains('Administre') ||
        text.contains('adrenalina') ||
        text.contains('Amiodarona') ||
        text.contains('RITMO DESFIBRILABLE')) {
      return const Color(0xFFFFD700);
    }
    return const Color(0xFFE0E0E0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textP = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    return Scaffold(
      appBar: AppBar(
        title: const Text('RCP Avanzada',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
                _soundEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                size: 20),
            onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
          ),
          PopupMenuButton<AclsScenario>(
            icon: const Icon(Icons.list_rounded, size: 20),
            onSelected: _onScenarioChanged,
            itemBuilder: (_) => kAclsScenarios
                .map((s) => PopupMenuItem(
                    value: s,
                    child: Text(s.title, style: const TextStyle(fontSize: 13))))
                .toList(),
          ),
        ],
      ),
      backgroundColor:
          isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: (_scenario.cause != AclsCause.none &&
                    _scenario.cause != AclsCause.postRosc)
                ? Colors.red.withValues(alpha: 0.05)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(_scenario.title,
                            style: TextStyle(
                                color: textP,
                                fontSize: 15,
                                fontWeight: FontWeight.w800))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _scenario.initialRhythm == AclsRhythm.vf ||
                                _scenario.initialRhythm == AclsRhythm.tvsp
                            ? Colors.orange.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                          _scenario.initialRhythm.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color:
                                _scenario.initialRhythm == AclsRhythm.vf ||
                                        _scenario.initialRhythm ==
                                            AclsRhythm.tvsp
                                    ? Colors.orange
                                    : Colors.grey,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_scenario.situation,
                    style: TextStyle(
                        color: textP.withValues(alpha: 0.8),
                        fontSize: 11,
                        height: 1.4)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── Monitor display: defibrillator-style rhythm ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF001122),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        // Rhythm display
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _phase == _AclsPhase.completed
                                    ? 'ROSC'
                                    : _scenario.initialRhythm.name.toUpperCase(),
                                style: TextStyle(
                                  color: _phase == _AclsPhase.completed
                                      ? const Color(0xFF00FF88)
                                      : _scenario.initialRhythm == AclsRhythm.vf ||
                                              _scenario.initialRhythm == AclsRhythm.tvsp
                                          ? Colors.redAccent
                                          : Colors.yellowAccent,
                                  fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1,
                                ),
                              ),
                            ),
                            if (_phase.index >= _AclsPhase.cprCycle.index && _phase != _AclsPhase.completed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('SIN PULSO', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Vitals strip
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _aStatItem('CICLOS', _cycleCount > 0 ? '$_cycleCount/${_scenario.cyclesRequired}' : '--'),
                            _aStatItem('DESCARGAS', _shockCount > 0 ? '$_shockCount' : '--'),
                            _aStatItem('ETCO₂', _phase.index >= _AclsPhase.cprCycle.index ? '${_etco2.toStringAsFixed(0)}' : '--',
                                color: _etco2 > 20 ? const Color(0xFF00FF88) : const Color(0xFFFF6B6B)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _phase.name.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(color: Colors.cyan, fontSize: 9, letterSpacing: 2),
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
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.6,
                            ),
                          )
                        else
                          Text('Seleccione escenario y presione Iniciar',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── Phase label ──
                  Text(
                    _phase == _AclsPhase.completed ? 'COMPLETADO' : 'ACLS SIMULATOR',
                    style: TextStyle(
                      color: _phase == _AclsPhase.completed ? const Color(0xFF00FF88) : Colors.cyan,
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

  Widget _buildButton(String label, VoidCallback? onTap,
      {Color? color, bool destructive = false, double height = 50}) {
    final c = color ??
        (destructive ? const Color(0xFFEF4444) : const Color(0xFF3B82F6));
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onTap,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _aStatItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 8, letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildControls() {
    switch (_phase) {
      case _AclsPhase.assessment:
        return Column(children: [
          Text('Evaluacion ABCDE:',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color)),
          const SizedBox(height: 8),
          _buildButton('No responde, sin pulso -> Iniciar RCP', _onNoPulse,
              color: const Color(0xFFEF4444)),
        ]);
      case _AclsPhase.cprCycle:
        return _buildButton(
            'RCP 2 min completado\n(reevaluar ritmo y pulso)', _onCprDone,
            color: const Color(0xFF3B82F6), height: 56);
      case _AclsPhase.rhythmCheck:
        return Column(children: [
          _buildButton('Pulso presente (ROSC)', _onPulsePresent,
              color: const Color(0xFF10B981)),
          _buildButton('Sin pulso -> analizar ritmo', _onNoPulseCheck,
              color: const Color(0xFFEF4444)),
        ]);
      case _AclsPhase.shockable:
        return _buildButton(
            'DESFIBRILAR (${_scenario.initialRhythm.name.toUpperCase()})',
            _onShock,
            color: const Color(0xFFF59E0B),
            height: 56);
      case _AclsPhase.charging:
        return _buildButton('CARGANDO...', null,
            color: const Color(0xFF888888), height: 56);
      case _AclsPhase.nonShockable:
        return _buildButton(
            'Ritmo no desfibrilable\nAdministre adrenalina + RCP', () {
          _epinephrineGiven = true;
          _setPhase(_AclsPhase.drugAdmin,
              feedback: 'Adrenalina 1 mg IV/IO administrada.\n'
                  'Repetir cada 3-5 minutos.\n'
                  'Continue RCP 2 minutos.\n'
                  'Busque causas reversibles (5H/5T).');
        }, color: const Color(0xFF6B7280), height: 56);
      case _AclsPhase.shockDelivered:
        return Column(children: [
          _buildButton('Administrar farmacos', _onContinueAfterShock,
              color: const Color(0xFF8B5CF6)),
          _buildButton('Reanudar RCP directamente', _startCprCycle,
              color: const Color(0xFF3B82F6)),
        ]);
      case _AclsPhase.drugAdmin:
        return Column(children: [
          if (!_epinephrineGiven)
            _buildButton('Adrenalina 1 mg IV/IO', _onGiveEpinephrine,
                color: const Color(0xFF8B5CF6)),
          if (!_amiodaroneGiven && _shockCount >= 3)
            _buildButton('Amiodarona 300 mg IV/IO', _onGiveAmiodarone,
                color: const Color(0xFFF59E0B)),
          if (!_airwaySecured)
            _buildButton('Asegurar Via Aerea', _onSecureAirway,
                color: const Color(0xFF3B82F6)),
          const Divider(height: 16),
          _buildButton('Reanudar RCP 2 min', _onContinueCpr,
              color: const Color(0xFF10B981)),
        ]);
      case _AclsPhase.manageCause:
        return Column(children: [
          _buildButton('Tratar Causa Reversible', _onTreatCause,
              color: const Color(0xFF10B981), height: 56),
          _buildButton('No identificar causa -- RCP (2 min)', _startCprCycle,
              color: const Color(0xFF6B7280)),
        ]);
      case _AclsPhase.rosc:
        return Column(children: [
          _buildButton(
              'Estabilizar y continuar cuidados post-paro', _onRoscComplete,
              color: const Color(0xFF10B981)),
          _buildButton('Tratar causa subyacente', _onTreatCause,
              color: const Color(0xFF3B82F6)),
        ]);
      case _AclsPhase.completed:
        return Column(children: [
          _buildButton('Repetir Escenario', _reset,
              color: const Color(0xFF3B82F6)),
          _buildButton('Volver', () => Navigator.pop(context),
              color: const Color(0xFF6B7280)),
        ]);
    }
  }
}
