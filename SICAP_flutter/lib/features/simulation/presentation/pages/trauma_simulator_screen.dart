import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:siercp/features/simulation/data/aed/wav_generator.dart';
import 'package:siercp/features/simulation/data/trauma/trauma_scenarios.dart';

enum _TraumaPhase {
  sceneAssessment,
  sceneSafe,
  airwayCervical,
  breathingAssessment,
  circulationAssessment,
  disabilityAssessment,
  exposureAssessment,
  interventions,
  secondarySurvey,
  transport,
  completed,
}

class TraumaSimulatorScreen extends StatefulWidget {
  const TraumaSimulatorScreen({super.key});

  @override
  State<TraumaSimulatorScreen> createState() => _TraumaSimulatorScreenState();
}

class _TraumaSimulatorScreenState extends State<TraumaSimulatorScreen> {
  _TraumaPhase _phase = _TraumaPhase.sceneAssessment;
  late TraumaScenario _scenario;
  final AudioPlayer _player = AudioPlayer();
  Directory? _tempDir;
  bool _soundEnabled = true;
  String _feedbackText = '';
  int _fileCounter = 0;
  final Set<String> _completedInterventions = {};
  double _sbp = 120;
  double _hr = 90;
  double _spo2 = 96;
  double _rr = 16;
  int _gcs = 15;

  @override
  void initState() {
    super.initState();
    _scenario = kTraumaScenarios[0];
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

  void _setPhase(_TraumaPhase p, {String feedback = ''}) {
    setState(() { _phase = p; if (feedback.isNotEmpty) _feedbackText = feedback; });
  }

  String _nextFile(String prefix) {
    _fileCounter++;
    return '${_tempDir?.path ?? "."}/${prefix}_$_fileCounter.wav';
  }

  void _initVitals() {
    switch (_scenario.type) {
      case TraumaType.tce:
        _sbp = 160; _hr = 55; _spo2 = 92; _rr = 10; _gcs = 6;
      case TraumaType.neumotorax:
        _sbp = 70; _hr = 130; _spo2 = 85; _rr = 28; _gcs = 14;
      case TraumaType.hemoneumotorax:
        _sbp = 85; _hr = 120; _spo2 = 88; _rr = 26; _gcs = 14;
      case TraumaType.taponamiento:
        _sbp = 80; _hr = 115; _spo2 = 94; _rr = 22; _gcs = 15;
      case TraumaType.hemorragia:
        _sbp = 60; _hr = 140; _spo2 = 90; _rr = 24; _gcs = 12;
      case TraumaType.quemadura:
        _sbp = 100; _hr = 110; _spo2 = 89; _rr = 22; _gcs = 15;
      case TraumaType.amputacion:
        _sbp = 70; _hr = 130; _spo2 = 91; _rr = 26; _gcs = 13;
      case TraumaType.politrauma:
        _sbp = 65; _hr = 135; _spo2 = 86; _rr = 28; _gcs = 9;
    }
  }

  Future<void> _playWav(List<double> samples) async {
    if (!_soundEnabled) return;
    try {
      final wav = WavGenerator.generateWav(samples: samples);
      final file = File(_nextFile('tr'));
      await file.writeAsBytes(wav);
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  Future<void> _playBeep({double freq = 880, double dur = 0.08}) async {
    await _playWav(WavGenerator.applyEnvelope(WavGenerator.sineWave(freq, dur, amplitude: 0.5), 2, 10));
  }

  Future<void> _playBuzz() async {
    await _playWav(WavGenerator.applyEnvelope(WavGenerator.squareWave(150, 0.4, amplitude: 0.4), 5, 60));
  }

  Future<void> _playSiren() async {
    await _playWav(WavGenerator.sweep(600, 900, 1.5, amplitude: 0.3));
  }

  Future<void> _playChime() async {
    final c = WavGenerator.applyEnvelope(WavGenerator.sineWave(523, 0.12, amplitude: 0.5), 3, 20);
    final e = WavGenerator.applyEnvelope(WavGenerator.sineWave(659, 0.12, amplitude: 0.5), 3, 20);
    final g = WavGenerator.applyEnvelope(WavGenerator.sineWave(784, 0.25, amplitude: 0.5), 3, 50);
    await _playWav(WavGenerator.concat([c, WavGenerator.silence(0.04), e, WavGenerator.silence(0.04), g]));
  }

  String _vitalsText() {
    return 'Signos vitales:\n'
        'PA: ${_sbp.toStringAsFixed(0)}/${(_sbp * 0.6).toStringAsFixed(0)} mmHg\n'
        'FC: ${_hr.toStringAsFixed(0)} lpm\n'
        'SpO2: ${_spo2.toStringAsFixed(0)}%\n'
        'FR: ${_rr.toStringAsFixed(0)} rpm\n'
        'GCS: $_gcs\n';
  }

  void _reset() {
    _player.stop();
    _completedInterventions.clear();
    _fileCounter = 0;
    setState(() {
      _phase = _TraumaPhase.sceneAssessment;
      _feedbackText = '';
    });
  }

  void _onStartScene() {
    _initVitals();
    _setPhase(_TraumaPhase.sceneAssessment, feedback:
        'EVALUACION DE ESCENA\n\n'
        'Seguridad de la escena:\n'
        '- Use equipo de proteccion personal (guantes, mascarilla, lentes)\n'
        '- Escena segura? Verifique riesgos ambientales\n'
        '- Mecanismo de lesion: ${_scenario.description}\n'
        '- Numero de victimas: 1\n'
        '- Apoyo adicional activado\n\n'
        '${_vitalsText()}');
    _playBeep();
  }

  void _onSceneSafe() {
    _setPhase(_TraumaPhase.sceneSafe, feedback:
        'EVALUACION PRIMARIA (ABCDE)\n\n'
        'A: Via aerea con control cervical\n'
        'B: Respiracion y ventilacion\n'
        'C: Circulacion con control de hemorragias\n'
        'D: Discapacidad (GCS, pupilas, motor)\n'
        'E: Exposicion y control ambiental\n\n'
        'Comience con evaluacion de via aerea (A).');
    _playBeep(freq: 660);
  }

  void _onAirwayAssessment() {
    if (_scenario.spinalPrecaution) {
      _setPhase(_TraumaPhase.airwayCervical, feedback:
          'A: VIA AEREA CON PRECAUCION CERVICAL\n\n'
          'Mantenga inmovilizacion cervical manual en linea.\n'
          '{: Via aerea permeable? ${_scenario.type == TraumaType.tce ? "Comprometida (GCS $_gcs)" : "Permeable"}\n'
          'Coloque collar cervical rigido.\n'
          'Aspire secreciones si es necesario.\n'
          'Considere via aerea avanzada si GCS <= 8.\n\n'
          '${_vitalsText()}');
    } else {
      _setPhase(_TraumaPhase.airwayCervical, feedback:
          'A: VIA AEREA\n\n'
          'Via aerea permeable.\n'
          'No requiere precaucion cervical.\n'
          'Administre O2 15 L/min con mascarilla reservorio.\n\n'
          '${_vitalsText()}');
    }
    _playBeep();
  }

  void _onBreathingAssessment() {
    String bText;
    switch (_scenario.type) {
      case TraumaType.neumotorax:
        bText = 'B: RESPIRACION - NEUMOTORAX A TENSION\n\n'
            'AUSCULTACION:\n'
            'Ausencia de ruidos respiratorios en hemitorax derecho.\n'
            'Desviacion traqueal hacia la izquierda.\n'
            'Enfisema subcutaneo palpable.\n'
            'Ingurgitacion yugular presente.\n\n'
            'Requiere descompresion inmediata con aguja 14G\n'
            'en 2do espacio intercostal, linea medioclavicular.\n\n'
            '${_vitalsText()}';
      case TraumaType.hemoneumotorax:
        bText = 'B: RESPIRACION - HEMONEUMOTORAX\n\n'
            'AUSCULTACION:\n'
            'Ruidos respiratorios disminuidos en base izquierda.\n'
            'Matidez a la percusion.\n'
            'Dolor toracico y equimosis.\n\n'
            'Requiere sello toracico y tubo pleural (36-40 Fr).\n\n'
            '${_vitalsText()}';
      case TraumaType.taponamiento:
        bText = 'B: RESPIRACION\n\n'
            'AUSCULTACION:\n'
            'Ruidos respiratorios presentes y simetricos.\n'
            'Sin signos de compromiso ventilatorio.\n'
            'Pase a evaluacion de circulacion (C).\n\n'
            '${_vitalsText()}';
      case TraumaType.tce:
        bText = 'B: RESPIRACION\n\n'
            'Respira espontaneamente con patron irregular.\n'
            'SatO2: ${_spo2.toStringAsFixed(0)}%\n'
            'FR: ${_rr.toStringAsFixed(0)} rpm\n'
            'Administre O2. Considere IOT si persiste hipoxia.\n'
            'Evite hiperventilacion (objetivo: ETCO2 35-40 mmHg).\n\n'
            '${_vitalsText()}';
      case TraumaType.quemadura:
        bText = 'B: RESPIRACION - INHALACION DE HUMO\n\n'
            'AUSCULTACION:\n'
            'Estridor inspiratorio.\n'
            'Vibrisas nasales quemadas.\n'
            'Esputo carbonaceo.\n'
            'Edema de via aerea progresivo.\n\n'
            'Considere IOT precoz antes de que progrese el edema.\n\n'
            '${_vitalsText()}';
      default:
        bText = 'B: RESPIRACION\n\n'
            'AUSCULTACION:\n'
            'Ruidos respiratorios presentes y simetricos.\n'
            'FR: ${_rr.toStringAsFixed(0)} rpm. SpO2: ${_spo2.toStringAsFixed(0)}%\n'
            'Administre O2 15 L/min. Reevalúe.\n\n'
            '${_vitalsText()}';
    }
    _setPhase(_TraumaPhase.breathingAssessment, feedback: bText);
    _playBuzz();
  }

  void _onCirculationAssessment() {
    final hasBleeding = _scenario.type == TraumaType.amputacion ||
        _scenario.type == TraumaType.hemorragia ||
        _scenario.type == TraumaType.politrauma;

    String cText;
    if (hasBleeding) {
      cText = 'C: CIRCULACION - SHOCK HEMORRAGICO\n\n'
          'Signos de shock:\n'
          'PA: ${_sbp.toStringAsFixed(0)}/${(_sbp * 0.6).toStringAsFixed(0)} mmHg\n'
          'FC: ${_hr.toStringAsFixed(0)} lpm - TAQUICARDIA\n'
          'Piel: fria, palida, diaforetica\n'
          'Llenado capilar: > 3 segundos\n\n'
          'ACCIONES:\n'
          '- 2 accesos IV/IO gruesos (14-16G)\n'
          '- Cristaloides 500 mL en bolo, reevaluar\n'
          '- Hemorragia externa: torniquete\n'
          '- Sospecha hemorragia interna: FAST + pelvis\n\n'
          '${_vitalsText()}';
    } else if (_scenario.type == TraumaType.taponamiento) {
      cText = 'C: CIRCULACION - TAPONAMIENTO CARDIACO\n\n'
          'Triada de Beck:\n'
          '- Ingurgitacion yugular\n'
          '- Hipotension (PA ${_sbp.toStringAsFixed(0)}/${(_sbp * 0.6).toStringAsFixed(0)})\n'
          '- Ruidos cardiacos apagados\n'
          'Pulso paradójico presente.\n\n'
          'Ecografia FAST: derrame pericardico.\n'
          'REALICE PERICARDIOCENTESIS (subxifoideo, guiado por ECO).\n\n'
          '${_vitalsText()}';
    } else {
      cText = 'C: CIRCULACION - ESTABLE\n\n'
          'PA: ${_sbp.toStringAsFixed(0)}/${(_sbp * 0.6).toStringAsFixed(0)} mmHg\n'
          'FC: ${_hr.toStringAsFixed(0)} lpm\n'
          'Piel caliente, perfundida.\n'
          'Llenado capilar < 2 segundos.\n'
          'Pase a evaluacion neurologica (D).\n\n'
          '${_vitalsText()}';
    }
    _setPhase(_TraumaPhase.circulationAssessment, feedback: cText);
    _playBuzz();
  }

  void _onNeedleDecompression() {
    if (_phase != _TraumaPhase.breathingAssessment &&
        _phase != _TraumaPhase.circulationAssessment &&
        _phase != _TraumaPhase.interventions) return;
    _completedInterventions.add('decompression');
    _spo2 = (_spo2 + 6).clamp(0, 98).toDouble();
    _sbp = (_sbp + 15).clamp(0, 140).toDouble();
    _hr = (_hr - 15).clamp(0, 140).toDouble();
    _setPhase(_TraumaPhase.circulationAssessment, feedback:
        'DESCOMPRESION TORACICA CON AGUJA 14G\n'
        'Procedimiento:\n'
        '- 2do espacio intercostal, linea medioclavicular derecha\n'
        '- Aguja 14G (naranja) angulada 45 grados hacia superior\n'
        '- Avance hasta sentir perdida de resistencia\n'
        '- Salida de aire a presion\n'
        '- Deje la camisa del cateter colocada\n\n'
        'Mejoria esperada:\n'
        'PA: ${_sbp.toStringAsFixed(0)}/${(_sbp * 0.6).toStringAsFixed(0)} mmHg\n'
        'SpO2: ${_spo2.toStringAsFixed(0)}%\n\n'
        'Sello toracico: coloque valvula de Heimlich o sello 3 puntos.');
    _playBeep(freq: 1200, dur: 0.15);
  }

  void _onChestSeal() {
    _completedInterventions.add('chestSeal');
    _spo2 = (_spo2 + 3).clamp(0, 98).toDouble();
    _setPhase(_TraumaPhase.circulationAssessment, feedback:
        'SELLO TORACICO COLOCADO\n\n'
        'Procedimiento:\n'
        '- Valvula de Heimlich o ap�sito 3 puntos\n'
        '- Prepare tubo pleural (drenaje 36-40 Fr)\n'
        '- Conectar a sistema de sello de agua\n'
        '- Confirme con RX de torax\n\n'
        'SpO2: ${_spo2.toStringAsFixed(0)}%');
    _playBeep();
  }

  void _onTourniquet() {
    _completedInterventions.add('tourniquet');
    _sbp = (_sbp + 20).clamp(0, 140).toDouble();
    _hr = (_hr - 20).clamp(0, 140).toDouble();
    _setPhase(_TraumaPhase.circulationAssessment, feedback:
        'TORNIQUETE COLOCADO\n\n'
        'Tecnica:\n'
        '- 5-8 cm proximal a la herida\n'
        '- Sobre piel intacta (no sobre ropa)\n'
        '- Apretar hasta que cese el sangrado\n'
        '- Anotar hora de colocacion\n'
        '- NO aflojar hasta llegar a quirorfano\n'
        '- Tiempo de isquemia: limite 2 horas\n\n'
        'PA: ${_sbp.toStringAsFixed(0)}/${(_sbp * 0.6).toStringAsFixed(0)} mmHg\n'
        'FC: ${_hr.toStringAsFixed(0)} lpm');
    _playBeep(freq: 880, dur: 0.12);
  }

  void _onPelvicBinding() {
    _completedInterventions.add('pelvicBinding');
    _sbp = (_sbp + 10).clamp(0, 140).toDouble();
    _setPhase(_TraumaPhase.circulationAssessment, feedback:
        'FIJADOR PELVICO COLOCADO\n\n'
        'Tecnica con sabana (sheet/sling):\n'
        '- Sabana doblada a nivel de trocanteres\n'
        '- Cruzada anteriormente\n'
        '- Traccion lateral para cerrar pelvis\n'
        '- Fijar con pinzas o nudos\n\n'
        'Reduce volumen pelvico y sangrado.\n'
        'Transfunda hemoderivados lo antes posible.\n\n'
        'PA: ${_sbp.toStringAsFixed(0)}/${(_sbp * 0.6).toStringAsFixed(0)} mmHg');
    _playBeep();
  }

  void _onFluidResuscitation() {
    _completedInterventions.add('fluidResuscitation');
    _sbp = (_sbp + 15).clamp(0, 140).toDouble();
    _hr = (_hr - 10).clamp(0, 140).toDouble();
    _setPhase(_TraumaPhase.circulationAssessment, feedback:
        'REANIMACION CON FLUIDOS\n\n'
        'Protocolo:\n'
        '- 2 accesos IV/IO de grueso calibre (14-16G)\n'
        '- Cristaloides: 500 mL en bolo, reevaluar\n'
        '- Transfusion masiva si persiste shock\n'
        '- Relacion 1:1:1 (GR:Plasma:Plaquetas)\n'
        '- Activar protocolo de transfusion masiva\n'
        '- Evite hipotermia: fluidos calientes\n\n'
        'PA: ${_sbp.toStringAsFixed(0)}/${(_sbp * 0.6).toStringAsFixed(0)} mmHg\n'
        'FC: ${_hr.toStringAsFixed(0)} lpm');
    _playBeep();
  }

  void _onSpinalImmobilization() {
    _completedInterventions.add('spinalImmobilization');
    _setPhase(_TraumaPhase.circulationAssessment, feedback:
        'INMOVILIZACION ESPINAL COMPLETA\n\n'
        'Procedimiento:\n'
        '- Collar cervical rigido (tamano adecuado)\n'
        '- Tabla espinal larga o camilla de cuchara\n'
        '- Fijacion con correas y bloques laterales\n'
        '- Log-roll para evaluar espalda\n'
        '- Mantener hasta descartar lesion medular\n\n'
        '${_vitalsText()}');
    _playBeep();
  }

  void _onNeedleCric() {
    _completedInterventions.add('needleCric');
    _sbp = (_sbp + 25).clamp(0, 140).toDouble();
    _hr = (_hr - 20).clamp(0, 140).toDouble();
    _setPhase(_TraumaPhase.circulationAssessment, feedback:
        'PERICARDIOCENTESIS REALIZADA\n\n'
        'Tecnica:\n'
        '- Aguja 18G, abordaje subxifoideo\n'
        '- Angulo 45 grados, dirigida a escapula izquierda\n'
        '- Avance hasta aspirar liquido (sangre/goteo)\n'
        '- Drene 20-30 mL\n'
        '- Mejoria hemodinamica inmediata\n\n'
        'PA: ${_sbp.toStringAsFixed(0)}/${(_sbp * 0.6).toStringAsFixed(0)} mmHg\n'
        'FC: ${_hr.toStringAsFixed(0)} lpm\n\n'
        'Considere ventana pericardica quirurgica.');
    _playBeep(freq: 1200, dur: 0.2);
  }

  void _onDisability() {
    String neuroText;
    switch (_scenario.type) {
      case TraumaType.tce:
        _gcs = 6;
        neuroText = 'D: EXAMEN NEUROLOGICO - TCE SEVERO\n\n'
            'GCS: $_gcs (O1 V2 M3)\n'
            'Pupilas: anisocoria derecha (midriasis)\n'
            'Reflejo fotomotor: lento derecho, normal izquierdo\n'
            'Respuesta motora: flexion al dolor (decorticacion) der.\n'
            'Signo de Babinski: bilateral presente\n\n'
            'Signos de hipertension intracraneal:\n'
            '- Triada de Cushing (HTA + bradicardia + resp. irregular)\n'
            '- PA: ${_sbp.toStringAsFixed(0)}/${(_sbp * 0.6).toStringAsFixed(0)} / FC: ${_hr.toStringAsFixed(0)}\n\n'
            'ACCION:\n'
            '- IOT con sedacion (etomidato + succinilcolina)\n'
            '- Hiperventilacion moderada si herniacion\n'
            '- Manitol 0.5-1 g/kg o solucion salina hipertonica\n'
            '- TC craneal urgente sin contraste';
      case TraumaType.politrauma:
        _gcs = 9;
        neuroText = 'D: EXAMEN NEUROLOGICO\n\n'
            'GCS: $_gcs (O2 V3 M4)\n'
            'Pupilas: normales, simetricas, reactivas\n'
            'Respuesta motora: localiza el dolor\n\n'
            'Reevaluar cada 5 minutos.\n'
            'Si deterioro neurologico, considere TC urgente.';
      default:
        _gcs = 15;
        neuroText = 'D: EXAMEN NEUROLOGICO\n\n'
            'GCS: $_gcs (O4 V5 M6)\n'
            'Pupilas: normales, isocoricas, fotorreactivas\n'
            'Respuesta motora: obedece ordenes, fuerza conservada\n'
            'Sensibilidad: conservada en 4 extremidades\n\n'
            'Paciente neurologicamente intacto. Reevaluar periodicamente.';
    }
    _setPhase(_TraumaPhase.disabilityAssessment, feedback: neuroText);
    _playBeep();
  }

  void _onExposure() {
    _setPhase(_TraumaPhase.exposureAssessment, feedback:
        'E: EXPOSICION Y AMBIENTE\n\n'
        'Procedimiento:\n'
        '- Desvista completamente al paciente (cortar ropa)\n'
        '- Busque lesiones ocultas:\n'
        '  * Espalda (log-roll)\n'
        '  * Axilas, ingles, pliegues\n'
        '  * Perine (hematoma = fractura pelvica)\n'
        '- Evite hipotermia:\n'
        '  * Mantas termicas o calentadores\n'
        '  * Fluidos intravenosos calientes\n'
        '  * Ambiente calido (24-26 grados C)\n'
        '- Cubra heridas con apostos esteriles\n\n'
        'Signos vitales:\n'
        'PA: ${_sbp.toStringAsFixed(0)}/${(_sbp * 0.6).toStringAsFixed(0)} mmHg\n'
        'FC: ${_hr.toStringAsFixed(0)} lpm\n'
        'SpO2: ${_spo2.toStringAsFixed(0)}%');
    _playBeep();
  }

  void _onInterventionMenu() {
    final pending = _scenario.requiredInterventions
        .where((i) => !_completedInterventions.contains(i.name)).toList();
    if (pending.isEmpty) {
      _onSecondarySurvey();
      return;
    }
    _setPhase(_TraumaPhase.interventions, feedback:
        'INTERVENCIONES PENDIENTES:\n' +
        pending.map((i) {
          switch (i) {
            case TraumaIntervention.decompression: return 'Descompresion toracica con aguja 14G';
            case TraumaIntervention.tourniquet: return 'Colocar torniquete';
            case TraumaIntervention.pelvicBinding: return 'Fijador pelvico (sheet/sling)';
            case TraumaIntervention.chestSeal: return 'Sello toracico + tubo pleural';
            case TraumaIntervention.fluidResuscitation: return 'Reanimacion con fluidos/transfusion';
            case TraumaIntervention.spinalImmobilization: return 'Inmovilizacion espinal';
            case TraumaIntervention.needleCric: return 'Pericardiocentesis';
          }
        }).join('\n') +
        '\n\n${_vitalsText()}');
    _playBeep();
  }

  void _onSecondarySurvey() {
    _setPhase(_TraumaPhase.secondarySurvey, feedback:
        'EVALUACION SECUNDARIA\n\n'
        'AMPLA:\n'
        'A: Alergias\n'
        'M: Medicacion actual\n'
        'P: Patologicos personales / Embarazo\n'
        'L: Last meal (ultima ingesta)\n'
        'A: Ambiente del evento\n\n'
        'Exploracion cefalo-caudal completa:\n'
        '- Cabeza y cuello\n'
        '- Torax (Rx portatil)\n'
        '- Abdomen (FAST + Rx pelvis)\n'
        '- Pelvis y perine\n'
        '- Extremidades\n'
        '- Espalda (log-roll)\n\n'
        'Estudios:\n'
        '- Rx torax, pelvis, columna cervical lateral\n'
        '- ECO FAST\n'
        '- TC segun hallazgos\n'
        '- Laboratorio: BH, QS, coagulacion, lactato, gasometria, tipificacion\n\n'
        'Reevaluar signos vitales cada 5 minutos.');
    _playBeep(freq: 523);
  }

  void _onTransport() {
    _playSiren();
    String destText;
    switch (_scenario.type) {
      case TraumaType.tce:
        destText = 'DECISION DE DESTINO:\n\n'
            'PACIENTE CON TCE + GCS <= 8\n'
            '-> CENTRO DE TRAUMA NIVEL I\n'
            '- Con neurocirugia disponible\n'
            '- TC inmediato sin contraste\n'
            '- Evaluar PIC / hemorragia intracraneal\n'
            '- Monitorizacion neurologica continua';
      case TraumaType.taponamiento:
        destText = 'DECISION DE DESTINO:\n\n'
            'PACIENTE CON TAPONAMIENTO\n'
            '-> QUIRRFANO URGENTE\n'
            '- Cirugia cardiaca disponible\n'
            '- Ventana pericardica vs esternotomia\n'
            '- Ecocardiograma transesofagico intraoperatorio';
      default:
        destText = 'DECISION DE DESTINO:\n\n'
            'PACIENTE TRAUMA GRAVE\n'
            '-> CENTRO DE TRAUMA NIVEL I-II\n'
            '- Quirfano disponible\n'
            '- Cirugia general/trauma\n'
            '- UCI trauma post-operatoria\n'
            '- Banco de sangre con protocolo de transfusion masiva';
    }
    _setPhase(_TraumaPhase.transport, feedback: destText);
  }

  void _onComplete() {
    _setPhase(_TraumaPhase.completed, feedback:
        'EVALUACION COMPLETADA\n\n'
        'Paciente transferido a centro de trauma.\n'
        'Intervenciones realizadas:\n' +
        _completedInterventions.map((i) => "- $i").join("\n") +
        '\n\nSignos vitales finales:\n'
        'PA: ${_sbp.toStringAsFixed(0)}/${(_sbp * 0.6).toStringAsFixed(0)} mmHg\n'
        'FC: ${_hr.toStringAsFixed(0)} lpm\n'
        'SpO2: ${_spo2.toStringAsFixed(0)}%\n'
        'GCS: $_gcs');
    _playChime();
  }

  void _onScenarioChanged(TraumaScenario s) {
    _player.stop();
    _completedInterventions.clear();
    setState(() {
      _scenario = s;
      _phase = _TraumaPhase.sceneAssessment;
      _feedbackText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textP = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trauma', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded, size: 20),
            onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
          ),
          PopupMenuButton<TraumaScenario>(
            icon: const Icon(Icons.list_rounded, size: 20),
            onSelected: _onScenarioChanged,
            itemBuilder: (_) => kTraumaScenarios.map((s) =>
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_scenario.title, style: TextStyle(color: textP, fontSize: 15, fontWeight: FontWeight.w800))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _scenario.spinalPrecaution ? Colors.orange.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_scenario.spinalPrecaution ? 'PRECAUCION ESPINAL' : 'ESTABLE', style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: _scenario.spinalPrecaution ? Colors.orange : Colors.grey,
                      )),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_scenario.situation, style: TextStyle(color: textP.withValues(alpha: 0.8), fontSize: 11, height: 1.4)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── Monitor display: trauma vitals panel ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF001122),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _tVital('SBP', '${_sbp.toStringAsFixed(0)}', Colors.redAccent)),
                            _tDiv(),
                            Expanded(child: _tVital('HR', '${_hr.toStringAsFixed(0)}',
                                _hr > 100 || _hr < 60 ? Colors.redAccent : const Color(0xFF00FF88))),
                            _tDiv(),
                            Expanded(child: _tVital('SpO₂', '${_spo2.toStringAsFixed(0)}%',
                                _spo2 >= 90 ? const Color(0xFF00FF88) : Colors.redAccent)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _tVital('RR', '${_rr.toStringAsFixed(0)}',
                                _rr > 20 || _rr < 12 ? Colors.redAccent : const Color(0xFF00FF88))),
                            _tDiv(),
                            Expanded(child: _tVital('GCS', '$_gcs',
                                _gcs >= 13 ? const Color(0xFF00FF88) : _gcs >= 9 ? Colors.yellowAccent : Colors.redAccent)),
                            _tDiv(),
                            Expanded(child: _tVital('INTERV', '${_completedInterventions.length}', Colors.orangeAccent)),
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
                              color: _feedbackText.contains('NEUMOTORAX') || _feedbackText.contains('SHOCK') || _feedbackText.contains('COMPROMETIDA')
                                  ? const Color(0xFFFF6B6B)
                                  : _feedbackText.contains('COMPLETADA') || _feedbackText.contains('COLOCADO')
                                      ? const Color(0xFF00FF88)
                                      : const Color(0xFFE0E0E0),
                              fontSize: 12, fontWeight: FontWeight.w500, height: 1.6,
                            ),
                          )
                        else
                          Text('Presione Iniciar para comenzar\nevaluacion primaria de trauma',
                            textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── Phase label ──
                  Text(
                    _phase == _TraumaPhase.completed ? 'COMPLETADO' : 'TRAUMA SIMULATOR',
                    style: TextStyle(
                      color: _phase == _TraumaPhase.completed ? const Color(0xFF00FF88) : Colors.cyan,
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

  Widget _buildButton(String label, VoidCallback? onTap, {Color? color, double height = 50}) {
    final c = color ?? const Color(0xFF3B82F6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity, height: height,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: c.withValues(alpha: 0.1), foregroundColor: c,
            side: BorderSide(color: c.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _tVital(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 8, letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _tDiv() {
    return SizedBox(width: 8, child: Center(child: Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.1))));
  }

  Widget _buildControls() {
    switch (_phase) {
      case _TraumaPhase.sceneAssessment:
        return Column(children: [
          _buildButton('Iniciar Evaluacion de Escena', _onStartScene, color: Colors.orange),
          _buildButton('Escena segura -> Evaluacion Primaria', _onSceneSafe, color: const Color(0xFF10B981)),
        ]);
      case _TraumaPhase.sceneSafe:
        return _buildButton('Evaluar Via Aerea (A)', _onAirwayAssessment, color: const Color(0xFF3B82F6));
      case _TraumaPhase.airwayCervical:
        return _buildButton('Evaluar Respiracion (B)', _onBreathingAssessment, color: const Color(0xFF3B82F6));
      case _TraumaPhase.breathingAssessment:
        return Column(children: [
          if (_scenario.type == TraumaType.neumotorax || _scenario.type == TraumaType.hemoneumotorax) ...[
            _buildButton('Descompresion con Aguja 14G', _onNeedleDecompression, color: const Color(0xFFEF4444)),
            _buildButton('Colocar Sello Toracico', _onChestSeal, color: const Color(0xFFF59E0B)),
          ],
          _buildButton('Evaluar Circulacion (C)', _onCirculationAssessment, color: const Color(0xFF8B5CF6)),
        ]);
      case _TraumaPhase.circulationAssessment:
        return Column(children: [
          if (_scenario.type == TraumaType.amputacion || _scenario.type == TraumaType.politrauma)
            _buildButton('Colocar Torniquete', _onTourniquet, color: const Color(0xFFEF4444)),
          if (_scenario.type == TraumaType.hemorragia || _scenario.type == TraumaType.politrauma)
            _buildButton('Fijador Pelvico (Sheet/Sling)', _onPelvicBinding, color: const Color(0xFFF59E0B)),
          if (_scenario.type != TraumaType.tce)
            _buildButton('Reanimacion con Fluidos', _onFluidResuscitation, color: const Color(0xFF3B82F6)),
          if (_scenario.spinalPrecaution)
            _buildButton('Inmovilizacion Espinal', _onSpinalImmobilization, color: Colors.orange),
          if (_scenario.type == TraumaType.taponamiento)
            _buildButton('Pericardiocentesis', _onNeedleCric, color: const Color(0xFFEF4444)),
          if (_scenario.type != TraumaType.neumotorax && _scenario.type != TraumaType.hemoneumotorax)
            _buildButton('Evaluacion Neurologica (D)', _onDisability, color: const Color(0xFF8B5CF6)),
        ]);
      case _TraumaPhase.disabilityAssessment:
        return _buildButton('Exposicion (E) y Ambiente', _onExposure, color: const Color(0xFF3B82F6));
      case _TraumaPhase.exposureAssessment:
        return Column(children: [
          if (_completedInterventions.length < _scenario.requiredInterventions.length)
            _buildButton('Intervenciones Pendientes', _onInterventionMenu, color: Colors.orange),
          _buildButton('Evaluacion Secundaria', _onSecondarySurvey, color: const Color(0xFF10B981)),
        ]);
      case _TraumaPhase.interventions:
        return Column(children: [
          if (!_completedInterventions.contains('decompression') && _scenario.requiredInterventions.any((i) => i == TraumaIntervention.decompression))
            _buildButton('Descompresion Toracica', _onNeedleDecompression, color: const Color(0xFFEF4444)),
          if (!_completedInterventions.contains('chestSeal') && _scenario.requiredInterventions.any((i) => i == TraumaIntervention.chestSeal))
            _buildButton('Sello Toracico', _onChestSeal, color: const Color(0xFFF59E0B)),
          if (!_completedInterventions.contains('tourniquet') && _scenario.requiredInterventions.any((i) => i == TraumaIntervention.tourniquet))
            _buildButton('Torniquete', _onTourniquet, color: const Color(0xFFEF4444)),
          if (!_completedInterventions.contains('pelvicBinding') && _scenario.requiredInterventions.any((i) => i == TraumaIntervention.pelvicBinding))
            _buildButton('Fijador Pelvico', _onPelvicBinding, color: const Color(0xFFF59E0B)),
          if (!_completedInterventions.contains('fluidResuscitation') && _scenario.requiredInterventions.any((i) => i == TraumaIntervention.fluidResuscitation))
            _buildButton('Reanimacion con Fluidos', _onFluidResuscitation, color: const Color(0xFF3B82F6)),
          if (!_completedInterventions.contains('spinalImmobilization') && _scenario.requiredInterventions.any((i) => i == TraumaIntervention.spinalImmobilization))
            _buildButton('Inmovilizacion Espinal', _onSpinalImmobilization, color: Colors.orange),
          if (!_completedInterventions.contains('needleCric') && _scenario.requiredInterventions.any((i) => i == TraumaIntervention.needleCric))
            _buildButton('Pericardiocentesis', _onNeedleCric, color: const Color(0xFFEF4444)),
          if (_completedInterventions.length >= _scenario.requiredInterventions.length)
            _buildButton('Evaluacion Secundaria ->', _onSecondarySurvey, color: const Color(0xFF10B981)),
        ]);
      case _TraumaPhase.secondarySurvey:
        return _buildButton('Decidir Destino -> Transporte', _onTransport, color: const Color(0xFFF59E0B));
      case _TraumaPhase.transport:
        return _buildButton('Finalizar Evaluacion', _onComplete, color: const Color(0xFF10B981));
      case _TraumaPhase.completed:
        return Column(children: [
          _buildButton('Repetir Escenario', _reset, color: const Color(0xFF3B82F6)),
          _buildButton('Volver', () => Navigator.pop(context), color: const Color(0xFF6B7280)),
        ]);
    }
  }
}
