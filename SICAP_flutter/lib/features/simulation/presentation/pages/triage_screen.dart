import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/simulation/data/aed/wav_generator.dart';

class _TriageScenario {
  final String id;
  final String title;
  final String description;
  final String vitals;
  final String correctTriage;
  final String explanation;

  const _TriageScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.vitals,
    required this.correctTriage,
    required this.explanation,
  });
}

const _triageScenarios = <_TriageScenario>[
  _TriageScenario(
    id: 'triage_1',
    title: 'Politraumatizado por accidente vehicular',
    description: 'Hombre de 30 años, accidente automovilístico a 80 km/h. Consciente, confuso. Herida abierta en muslo con sangrado activo. Frecuencia respiratoria: 28 rpm.',
    vitals: 'FR: 28 | FC: 120 | PAS: 85 | Glasgow: 13',
    correctTriage: 'Rojo',
    explanation: 'FR > 30, PAS < 90, Glasgow < 14. Cumple criterios de triage ROJO. Requiere atención inmediata por riesgo de shock hemorrágico y compromiso neurológico.',
  ),
  _TriageScenario(
    id: 'triage_2',
    title: 'Fractura cerrada de tibia',
    description: 'Mujer de 45 años, caída desde 2 metros. Fractura cerrada de tibia derecha. Dolor 8/10. Signos vitales estables. Puede mover el pie.',
    vitals: 'FR: 16 | FC: 88 | PAS: 125 | Glasgow: 15',
    correctTriage: 'Amarillo',
    explanation: 'Paciente estable hemodinámicamente pero con fractura que requiere atención ortopédica y analgesia. No es verde porque no puede deambular y necesita manejo del dolor.',
  ),
  _TriageScenario(
    id: 'triage_3',
    title: 'Quemadura solar leve',
    description: 'Joven de 20 años con eritema en espalda y hombros tras exposición solar prolongada. Sin ampollas. Dolor leve. Camina sin ayuda.',
    vitals: 'FR: 14 | FC: 72 | PAS: 118 | Glasgow: 15',
    correctTriage: 'Verde',
    explanation: 'Lesión menor, paciente ambulatorio. No hay compromiso vital ni riesgo inmediato. Puede esperar para atención.',
  ),
  _TriageScenario(
    id: 'triage_4',
    title: 'Paro cardíaco presenciado',
    description: 'Hombre de 60 años colapsa en la sala de espera. No responde, no respira. Testigos presenciaron el colapso.',
    vitals: 'FR: 0 | FC: 0 | PAS: 0 | Glasgow: 3',
    correctTriage: 'Rojo',
    explanation: 'Paro cardíaco. Requiere RCP y desfibrilación inmediatos. Es la máxima prioridad en cualquier sistema de triage.',
  ),
  _TriageScenario(
    id: 'triage_5',
    title: 'Herida penetrante en tórax',
    description: 'Herido por arma blanca en hemitórax izquierdo. Disnea progresiva, tráquea desviada a la derecha, ingurgitación yugular. Sospecha de neumotórax a tensión.',
    vitals: 'FR: 32 | FC: 130 | PAS: 75 | Glasgow: 12',
    correctTriage: 'Rojo',
    explanation: 'Neumotórax a tensión con compromiso vital. Requiere descompresión inmediata. FR > 30, PAS < 90, Glasgow < 14 → ROJO.',
  ),
  _TriageScenario(
    id: 'triage_6',
    title: 'Crisis hipertensiva asintomática',
    description: 'Mujer de 55 años, PA 200/110 en control rutinario. Asintomática. Sin dolor torácico, sin disnea, sin cefalea.',
    vitals: 'FR: 14 | FC: 76 | PAS: 200 | Glasgow: 15',
    correctTriage: 'Amarillo',
    explanation: 'Crisis hipertensiva severa pero asintomática. Requiere evaluación y tratamiento en horas, no es emergencia inmediata. No es ROJO porque no hay daño a órgano diana activo.',
  ),
  _TriageScenario(
    id: 'triage_7',
    title: 'Reacción alérgica leve',
    description: 'Hombre de 25 años con urticaria generalizada tras comer mariscos. Sin disnea, sin edema facial, sin sibilancias.',
    vitals: 'FR: 16 | FC: 80 | PAS: 120 | Glasgow: 15',
    correctTriage: 'Verde',
    explanation: 'Reacción alérgica leve sin compromiso respiratorio ni hemodinámico. Puede esperar para tratamiento con antihistamínicos.',
  ),
  _TriageScenario(
    id: 'triage_8',
    title: 'Hemorragia digestiva alta',
    description: 'Hombre de 65 años, cirrótico conocido, presenta hematemesis y melenas. Hipotenso, taquicárdico. Piel pálida y sudorosa.',
    vitals: 'FR: 24 | FC: 115 | PAS: 85 | Glasgow: 14',
    correctTriage: 'Rojo',
    explanation: 'Hemorragia activa con inestabilidad hemodinámica. PAS < 90, FC > 100, Glasgow 14. Requiere reanimación y endoscopia urgente.',
  ),
  _TriageScenario(
    id: 'triage_9',
    title: 'Esguince de tobillo',
    description: 'Mujer de 35 años, torcedura de tobillo jugando fútbol. Dolor leve, inflamación mínima. Puede apoyar parcialmente.',
    vitals: 'FR: 14 | FC: 72 | PAS: 118 | Glasgow: 15',
    correctTriage: 'Verde',
    explanation: 'Lesión musculoesquelética menor. Paciente ambulatorio. No hay signos de alarma. Categoría VERDE.',
  ),
  _TriageScenario(
    id: 'triage_10',
    title: 'Traumatismo craneal con pérdida de conciencia',
    description: 'Hombre de 40 años, caída de 3 metros, pérdida de conciencia de 2 minutos. Actualmente despierto pero somnoliento. Vómitos. Amnesia del evento.',
    vitals: 'FR: 18 | FC: 92 | PAS: 130 | Glasgow: 13',
    correctTriage: 'Rojo',
    explanation: 'TCE con GCS < 14, vómitos, amnesia. Requiere TC craneal urgente y valoración neuroquirúrgica. Categoría ROJO.',
  ),
  _TriageScenario(
    id: 'triage_11',
    title: 'Paciente en coma sin signos vitales',
    description: 'Paciente encontrado inconsciente en la vía pública. Sin respuesta. Pupilas midriáticas fijas. Sin respiración tras apertura de vía aérea. Sin pulso.',
    vitals: 'FR: 0 | FC: 0 | PAS: 0 | Glasgow: 3',
    correctTriage: 'Negro',
    explanation: 'Paciente en paro cardíaco sin respuesta a maniobras iniciales. En triage START, si no respira tras abrir vía aérea, se clasifica NEGRO (fallecido).',
  ),
  _TriageScenario(
    id: 'triage_12',
    title: 'Crisis asmática moderada',
    description: 'Mujer de 28 años con asma conocida. Sibilancias audibles, FR elevada, saturación 90%, habla en frases cortas.',
    vitals: 'FR: 26 | FC: 105 | PAS: 110 | Glasgow: 15',
    correctTriage: 'Amarillo',
    explanation: 'Crisis asmática moderada. Requiere broncodilatadores y corticoides en horas. No cumple criterios ROJO (PAS > 90, Glasgow 15, FR < 30).',
  ),
  _TriageScenario(
    id: 'triage_13',
    title: 'Herida por arma de fuego en abdomen',
    description: 'Hombre de 35 años con disparo en cuadrante superior derecho del abdomen. Dolor intenso. Taquicárdico. Defensa abdominal.',
    vitals: 'FR: 22 | FC: 118 | PAS: 90 | Glasgow: 15',
    correctTriage: 'Rojo',
    explanation: 'Herida penetrante abdominal con posible lesión visceral y hemorragia interna. PAS 90 (en límite), FC > 100. Requiere laparotomía exploradora urgente.',
  ),
  _TriageScenario(
    id: 'triage_14',
    title: 'Infección urinaria no complicada',
    description: 'Mujer de 30 años, disuria, polaquiuria, fiebre 37.8°C. Sin dolor lumbar. Sin vómitos. Sin comorbilidades.',
    vitals: 'FR: 14 | FC: 78 | PAS: 120 | Glasgow: 15',
    correctTriage: 'Verde',
    explanation: 'Infección urinaria baja no complicada. Paciente joven sin factores de riesgo. Puede esperar para evaluación y tratamiento antibiótico ambulatorio.',
  ),
  _TriageScenario(
    id: 'triage_15',
    title: 'Sospecha de ACV con ventana terapéutica',
    description: 'Hombre de 70 años, hipertenso, con debilidad en hemicuerpo derecho y desviación de comisura labial. Inicio hace 45 minutos.',
    vitals: 'FR: 16 | FC: 88 | PAS: 155 | Glasgow: 14',
    correctTriage: 'Rojo',
    explanation: 'ACV isquémico dentro de ventana para fibrinólisis (< 4.5h). Cada minuto cuenta. Requiere evaluación y TC cerebral urgente. ROJO por ventana temporal.',
  ),
  _TriageScenario(
    id: 'triage_16',
    title: 'Quemadura de segundo grado en mano',
    description: 'Cocinero con quemadura por aceite caliente en mano derecha. Ampollas abiertas. Dolor intenso. Signos vitales normales.',
    vitals: 'FR: 16 | FC: 82 | PAS: 125 | Glasgow: 15',
    correctTriage: 'Amarillo',
    explanation: 'Quemadura de mano que requiere atención especializada (posible secuela funcional). No es emergencia vital (VERDE) pero tampoco es inmediata (ROJO). Requiere analgesia y curación en horas.',
  ),
  _TriageScenario(
    id: 'triage_17',
    title: 'Paciente diabético con hipoglucemia severa',
    description: 'Mujer de 50 años, diabética tipo 1, encontrada inconsciente. Glucemia capilar 38 mg/dL. Vecinos refieren que "no comió después de la insulina".',
    vitals: 'FR: 10 | FC: 100 | PAS: 110 | Glasgow: 8',
    correctTriage: 'Rojo',
    explanation: 'Hipoglucemia severa con Glasgow < 14. Requiere glucagón o glucosa IV inmediatos. El bajo Glasgow indica neuroglucopenia. ROJO por compromiso neurológico.',
  ),
  _TriageScenario(
    id: 'triage_18',
    title: 'Lumbalgia crónica sin signos de alarma',
    description: 'Hombre de 50 años con dolor lumbar de 3 meses de evolución. Sin irradiación, sin déficit neurológico, sin fiebre. Ya ha sido evaluado previamente.',
    vitals: 'FR: 14 | FC: 74 | PAS: 125 | Glasgow: 15',
    correctTriage: 'Verde',
    explanation: 'Patología crónica sin criterios de urgencia. Sin signos de alarma (banderas rojas). Puede ser derivado a consulta ambulatoria.',
  ),
  _TriageScenario(
    id: 'triage_19',
    title: 'Politraumatizado con lesión severa de pelvis',
    description: 'Accidente de moto a alta velocidad. Pelvis inestable a la palpación. Hematoma perineal. Hipotenso, taquicárdico, pálido.',
    vitals: 'FR: 28 | FC: 130 | PAS: 70 | Glasgow: 12',
    correctTriage: 'Rojo',
    explanation: 'Fractura pélvica inestable con shock hemorrágico. PAS < 90, FC > 120, Glasgow < 14. Mortalidad alta sin control quirúrgico urgente.',
  ),
  _TriageScenario(
    id: 'triage_20',
    title: 'Mordedura de perro en antebrazo',
    description: 'Niño de 10 años mordido por perro en antebrazo derecho. Herida punzante limpia. Sin sangrado activo. Vacunación antirrábica al día.',
    vitals: 'FR: 16 | FC: 90 | PAS: 110 | Glasgow: 15',
    correctTriage: 'Verde',
    explanation: 'Herida por mordedura sin compromiso vascular ni infeccioso agudo. Requiere limpieza, profilaxis antibiótica y evaluación de vacunación. No urgente.',
  ),
  // ── Casos nuevos (21–30) ──────────────────────────────────────────────
  _TriageScenario(
    id: 'triage_21',
    title: 'Intoxicación por organofosforados',
    description: 'Agricultor de 45 años expuesto a pesticida organofosforado. Salivación excesiva, fasciculaciones musculares, miosis bilateral, broncorrea. Inconsciente.',
    vitals: 'FR: 8 | FC: 55 | PAS: 80 | Glasgow: 9',
    correctTriage: 'Rojo',
    explanation: 'Intoxicación severa con compromiso respiratorio (FR < 10, broncorrea) y hemodinámico. Requiere atropina, pralidoxima y soporte ventilatorio urgente. ROJO.',
  ),
  _TriageScenario(
    id: 'triage_22',
    title: 'Dolor abdominal agudo en anciano',
    description: 'Hombre de 78 años con dolor abdominal difuso de inicio súbito, vómitos fecaloides, distensión abdominal. Antecedente de cirugía abdominal hace 10 años.',
    vitals: 'FR: 20 | FC: 100 | PAS: 100 | Glasgow: 14',
    correctTriage: 'Rojo',
    explanation: 'Sospecha de obstrucción intestinal complicada o perforación. PAS limítrofe, taquicardia, Glasgow descendido. Requiere cirugía urgente. ROJO.',
  ),
  _TriageScenario(
    id: 'triage_23',
    title: 'Crisis de angustia',
    description: 'Mujer de 28 años, taquicárdica, hiperventilación, parestesias peribucales y en manos. Refiere sensación de muerte inminente. Sin dolor torácico. Sat O2 99%.',
    vitals: 'FR: 28 | FC: 115 | PAS: 130 | Glasgow: 15',
    correctTriage: 'Verde',
    explanation: 'Crisis de pánico sin compromiso orgánico. Sat O2 normal, PAS normal, Glasgow 15. Requiere contención y valoración por salud mental. Puede esperar.',
  ),
  _TriageScenario(
    id: 'triage_24',
    title: 'Quemadura eléctrica con punto de entrada y salida',
    description: 'Electricista de 35 años recibió descarga de 220V. Presenta punto de entrada en mano derecha y salida en pie izquierdo. Quemadura de tercer grado en mano. ECG con extrasístoles ventriculares.',
    vitals: 'FR: 18 | FC: 105 | PAS: 110 | Glasgow: 15',
    correctTriage: 'Rojo',
    explanation: 'Quemadura eléctrica con arritmia cardíaca (extrasístoles). Puede desarrollar fibrilación ventricular o rabdomiólisis. Requiere monitorización cardíaca continua. ROJO.',
  ),
  _TriageScenario(
    id: 'triage_25',
    title: 'Neutropenia febril en paciente oncológico',
    description: 'Mujer de 55 años con cáncer de mama en quimioterapia. Fiebre 38.9°C, neutropenia grado IV. Astenia, mucositis oral. Sin foco infeccioso claro.',
    vitals: 'FR: 18 | FC: 98 | PAS: 110 | Glasgow: 15',
    correctTriage: 'Amarillo',
    explanation: 'Neutropenia febril que requiere antibióticos parenterales y evaluación en horas. No hay criterios ROJO (PAS normal, Glasgow 15, FR normal). Requiere atención prioritaria.',
  ),
  _TriageScenario(
    id: 'triage_26',
    title: 'Fractura expuesta de tobillo',
    description: 'Hombre de 30 años, caída desde 4 metros. Fractura expuesta de tobillo derecho con protrusión ósea. Sangrado moderado. Dolor 10/10. Pulso distal presente.',
    vitals: 'FR: 18 | FC: 105 | PAS: 120 | Glasgow: 15',
    correctTriage: 'Amarillo',
    explanation: 'Fractura expuesta que requiere lavado quirúrgico, profilaxis antibiótica y reducción en horas. No hay compromiso vascular ni hemodinámico. AMARILLO.',
  ),
  _TriageScenario(
    id: 'triage_27',
    title: 'Cólico renal complicado',
    description: 'Hombre de 40 años con dolor lumbar izquierdo irradiado a testículo, náuseas, vómitos. Afebril. Antecedente de litiasis renal. Dolor refractario a AINEs.',
    vitals: 'FR: 16 | FC: 88 | PAS: 135 | Glasgow: 15',
    correctTriage: 'Amarillo',
    explanation: 'Cólico renal con dolor refractario que requiere analgesia parenteral y posible imagen. Sin signos de sepsis ni obstrucción completa. AMARILLO.',
  ),
  _TriageScenario(
    id: 'triage_28',
    title: 'Síncope vasovagal en adolescente',
    description: 'Mujer de 16 años, síncope durante evento escolar. Recuperó conciencia rápidamente. Sin movimientos tónicoclónicos. Sin antecedentes cardíacos. Recuperación completa.',
    vitals: 'FR: 16 | FC: 76 | PAS: 110 | Glasgow: 15',
    correctTriage: 'Verde',
    explanation: 'Síncope vasovagal típico en paciente joven sin factores de riesgo. Recuperación completa, signos vitales normales. Puede esperar para evaluación.',
  ),
  _TriageScenario(
    id: 'triage_29',
    title: 'IAM con elevación del ST (STEMI)',
    description: 'Hombre de 55 años con dolor opresivo centrotorácico de 2 horas de evolución, irradiado a brazo izquierdo. Diaforesis, náuseas. ECG: ST elevado en V1-V4.',
    vitals: 'FR: 20 | FC: 95 | PAS: 140 | Glasgow: 15',
    correctTriage: 'Rojo',
    explanation: 'STEMI con ventana para intervencionismo. Cada minuto cuenta para salvar miocardio. Requiere activación de código infarto y hemodinamia urgente. ROJO.',
  ),
  _TriageScenario(
    id: 'triage_30',
    title: 'Laceración facial sin compromiso',
    description: 'Niño de 7 años con laceración en ceja derecha por caída jugando. Herida lineal de 2 cm, sin sangrado activo. Sin TEC. Vacunas al día.',
    vitals: 'FR: 16 | FC: 90 | PAS: 100 | Glasgow: 15',
    correctTriage: 'Verde',
    explanation: 'Herida menor sin compromiso vascular, neurológico ni óseo. No hay criterios de gravedad. Requiere limpieza y sutura simple. Puede esperar. VERDE.',
  ),
];

class TriageScreen extends StatefulWidget {
  const TriageScreen({super.key});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  final _rng = Random();
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<_TriageScenario> _scenarios = [];
  int _currentIndex = 0;
  String? _selectedTriage;
  bool _answered = false;
  int _correctCount = 0;
  bool _finished = false;
  final List<bool> _results = [];
  int _xpEarned = 0;
  int _levelAfter = 0;
  Timer? _questionTimer;
  int _timeLeft = 30;
  int _totalTimeUsed = 0;
  final List<int> _timePerQuestion = [];

  static const _triageLevels = ['Rojo', 'Amarillo', 'Verde', 'Negro'];
  static const _triageColors = [
    Color(0xFFDC2626),
    Color(0xFFF59E0B),
    Color(0xFF059669),
    Color(0xFF1F2937),
  ];
  static const _triageIcons = [
    Icons.emergency_rounded,
    Icons.warning_amber_rounded,
    Icons.check_circle_outline,
    Icons.block_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _startNewRound();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTimer() {
    _questionTimer?.cancel();
    _timeLeft = 30;
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0 && !_answered) {
          _questionTimer?.cancel();
          _playTimeoutSound();
          HapticFeedback.heavyImpact();
          _selectTriage('');
        }
      });
    });
  }

  Future<void> _playCorrectSound() async {
    try {
      final samples = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(880, 0.2, amplitude: 0.7),
        5,
        50,
      );
      final gap = WavGenerator.silence(0.05);
      final note2 = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(1108, 0.3, amplitude: 0.7),
        5,
        80,
      );
      final wav = WavGenerator.generateWav(samples: WavGenerator.concat([samples, gap, note2]));
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/triage_correct_${DateTime.now().microsecondsSinceEpoch}.wav');
      await file.writeAsBytes(wav);
      await _audioPlayer.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  Future<void> _playWrongSound() async {
    try {
      final note1 = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(440, 0.12, amplitude: 0.3), 8, 40,
      );
      final gap = WavGenerator.silence(0.03);
      final note2 = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(350, 0.15, amplitude: 0.3), 8, 50,
      );
      final wav = WavGenerator.generateWav(samples: WavGenerator.concat([note1, gap, note2]));
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/triage_wrong_${DateTime.now().microsecondsSinceEpoch}.wav');
      await file.writeAsBytes(wav);
      await _audioPlayer.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  Future<void> _playTimeoutSound() async {
    try {
      final samples = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(220, 0.5, amplitude: 0.5),
        10,
        100,
      );
      final wav = WavGenerator.generateWav(samples: samples);
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/triage_timeout_${DateTime.now().microsecondsSinceEpoch}.wav');
      await file.writeAsBytes(wav);
      await _audioPlayer.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  Future<void> _playCompletionChime() async {
    try {
      final note1 = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(523, 0.2, amplitude: 0.7),
        5,
        50,
      );
      final gap = WavGenerator.silence(0.05);
      final note2 = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(659, 0.3, amplitude: 0.7),
        5,
        80,
      );
      final gap2 = WavGenerator.silence(0.05);
      final note3 = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(784, 0.4, amplitude: 0.7),
        5,
        100,
      );
      final wav = WavGenerator.generateWav(
        samples: WavGenerator.concat([note1, gap, note2, gap2, note3]),
      );
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/triage_complete_${DateTime.now().microsecondsSinceEpoch}.wav');
      await file.writeAsBytes(wav);
      await _audioPlayer.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  void _startNewRound() {
    final pool = List<_TriageScenario>.from(_triageScenarios)..shuffle(_rng);
    setState(() {
      _scenarios = pool.take(min(10, pool.length)).toList();
      _currentIndex = 0;
      _correctCount = 0;
      _finished = false;
      _answered = false;
      _selectedTriage = null;
      _results.clear();
      _xpEarned = 0;
      _levelAfter = 0;
      _totalTimeUsed = 0;
      _timePerQuestion.clear();
    });
    _startTimer();
  }

  void _selectTriage(String level) {
    if (_answered) return;
    _questionTimer?.cancel();
    final timeUsed = 30 - _timeLeft;
    setState(() {
      _selectedTriage = level;
      _answered = true;
      _timePerQuestion.add(timeUsed);
      _totalTimeUsed += timeUsed;
      if (level.isEmpty) {
        _results.add(false);
      } else {
        final correct = level == _scenarios[_currentIndex].correctTriage;
        if (correct) {
          _correctCount++;
          _playCorrectSound();
          HapticFeedback.heavyImpact();
        } else {
          _playWrongSound();
          HapticFeedback.lightImpact();
        }
        _results.add(correct);
      }
    });
  }

  void _next() {
    if (_currentIndex < _scenarios.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedTriage = null;
        _answered = false;
      });
      _startTimer();
    } else {
      setState(() => _finished = true);
      _playCompletionChime();
      _awardXp();
    }
  }

  static const _xpThresholds = [
    0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5500
  ];
  static int _calcLevel(int xp) =>
      _xpThresholds.where((t) => xp >= t).length;

  Future<void> _awardXp() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final total = _scenarios.length;
    final basePct = total == 0 ? 0 : (_correctCount / total * 70);
    final avgTime = _timePerQuestion.isEmpty
        ? 30.0
        : _timePerQuestion.reduce((a, b) => a + b) / _timePerQuestion.length;
    final timeFactor = ((30 - avgTime) / 30).clamp(0.0, 1.0);
    final score = (basePct + timeFactor * 30).round();
    final passed = score >= 70;
    final xpEarned = passed ? (score == 100 ? 50 : 20) : 0;
    final db = FirebaseFirestore.instance;

    try {
      db.collection('quizSessions').add({
        'userId': uid,
        'topicId': 'triage',
        'type': 'theoretical',
        'score': score,
        'timeUsedSeconds': _totalTimeUsed,
        'passed': passed,
        'xpEarned': xpEarned,
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (!passed) return;

      final statsRef = db.collection('userStats').doc(uid);
      int newLevel = 0;
      await db.runTransaction((tx) async {
        final snap = await tx.get(statsRef);
        final data = snap.data() ?? {};
        final currentXp = (data['xp'] as int?) ?? 0;
        final newXp = currentXp + xpEarned;
        newLevel = _calcLevel(newXp);
        tx.set(
            statsRef,
            {
              'xp': newXp,
              'level': newLevel,
              'quizzesCompleted': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });

      if (mounted) {
        setState(() {
          _xpEarned = xpEarned;
          _levelAfter = newLevel;
        });
      }
    } catch (e) {
      debugPrint('[triage] Error guardando XP: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    if (_finished) return _buildResult(theme, isDark, textP, textS);
    return _buildGame(theme, isDark, textP, textS);
  }

  Widget _buildGame(ThemeData theme, bool isDark, Color textP, Color textS) {
    final scenario = _scenarios[_currentIndex];
    final total = _scenarios.length;
    final progress = (_currentIndex + (_answered ? 1 : 0)) / total;
    final isCorrect = _answered && _selectedTriage == scenario.correctTriage;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: textS),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Triage · Clasificación de Pacientes',
                            style: TextStyle(
                                color: textP,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        Text('Caso ${_currentIndex + 1} de $total',
                            style: TextStyle(color: textS, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_correctCount/${_results.length}',
                      style: const TextStyle(
                          color: AppColors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _timeLeft <= 10
                          ? AppColors.red.withValues(alpha: 0.1)
                          : AppColors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _timeLeft <= 10
                              ? Icons.timer_off_outlined
                              : Icons.timer_outlined,
                          size: 12,
                          color: _timeLeft <= 10
                              ? AppColors.red
                              : AppColors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_timeLeft}s',
                          style: TextStyle(
                            color: _timeLeft <= 10
                                ? AppColors.red
                                : AppColors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.amber.withValues(alpha: 0.12),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.amber),
                  minHeight: 4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: isDark ? 0.1 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.emergency_outlined,
                        size: 16, color: AppColors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scenario.title,
                            style: TextStyle(
                              color: isDark
                                  ? textS
                                  : AppColors.amber.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            scenario.description,
                            style: TextStyle(
                              color: isDark
                                  ? textS
                                  : AppColors.amber.withValues(alpha: 0.8),
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              scenario.vitals,
                              style: TextStyle(
                                color: isDark
                                    ? textS
                                    : AppColors.amber.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clasifica al paciente:',
                      style: TextStyle(
                          color: textP,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_triageLevels.length, (i) {
                      final level = _triageLevels[i];
                      final color = _triageColors[i];
                      final icon = _triageIcons[i];
                      final isSelected = level == _selectedTriage;
                      final isLevelCorrect = level == scenario.correctTriage;
                      Color? bg;
                      Color borderColor;
                      Color textColor = textP;
                      IconData? trailingIcon;

                      if (_answered) {
                        if (isLevelCorrect) {
                          bg = const Color(0xFF059669).withValues(alpha: 0.1);
                          borderColor =
                              const Color(0xFF059669).withValues(alpha: 0.5);
                          textColor = const Color(0xFF059669);
                          trailingIcon = Icons.check_circle_outline_rounded;
                        } else if (isSelected) {
                          bg = AppColors.red.withValues(alpha: 0.08);
                          borderColor = AppColors.red.withValues(alpha: 0.4);
                          textColor = AppColors.red;
                          trailingIcon = Icons.cancel_outlined;
                        } else {
                          bg = null;
                          borderColor =
                              theme.colorScheme.outline.withValues(alpha: 0.15);
                          textColor = textS.withValues(alpha: 0.5);
                        }
                      } else {
                        bg = null;
                        borderColor =
                            theme.colorScheme.outline.withValues(alpha: 0.3);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => _selectTriage(level),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: bg ?? theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: borderColor,
                                width:
                                    isSelected && _answered ? 1.5 : 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _answered
                                        ? textColor.withValues(alpha: 0.12)
                                        : color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: _answered ? textColor : color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    level,
                                    style: TextStyle(
                                        color: textColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (trailingIcon != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(trailingIcon,
                                      size: 18, color: textColor),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_answered) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? const Color(0xFF059669).withValues(alpha: 0.08)
                              : AppColors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCorrect
                                ? const Color(0xFF059669)
                                    .withValues(alpha: 0.3)
                                : AppColors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isCorrect
                                      ? Icons.check_circle_outline
                                      : Icons.info_outline,
                                  size: 14,
                                  color: isCorrect
                                      ? const Color(0xFF059669)
                                      : AppColors.red,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  isCorrect ? '¡Correcto!' : 'Incorrecto',
                                  style: TextStyle(
                                    color: isCorrect
                                        ? const Color(0xFF059669)
                                        : AppColors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              TextSpan(
                                text: 'RESPUESTA CORRECTA: ',
                                style: TextStyle(
                                  color: textP,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                                children: [
                                  TextSpan(
                                    text: scenario.correctTriage,
                                    style: TextStyle(
                                      color: _triageColors[_triageLevels
                                          .indexOf(scenario.correctTriage)],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              scenario.explanation,
                              style: TextStyle(
                                  color: textS, fontSize: 11, height: 1.55),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (_answered)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _currentIndex < total - 1
                          ? 'Siguiente caso'
                          : 'Ver resultados',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(ThemeData theme, bool isDark, Color textP, Color textS) {
    final total = _scenarios.length;
    final pct = total == 0 ? 0 : (_correctCount / total * 100).round();
    final passed = pct >= 75;
    final scoreColor = pct >= 90
        ? const Color(0xFF059669)
        : pct >= 75
            ? AppColors.amber
            : AppColors.red;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.amber,
                  AppColors.amber.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Triage · Clasificación de Pacientes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.emergency_outlined,
                        color: Colors.white70, size: 20),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scoreColor.withValues(alpha: 0.08),
                      border: Border.all(
                          color: scoreColor.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$pct%',
                          style: TextStyle(
                            color: scoreColor,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '$_correctCount/$total',
                          style: TextStyle(
                              color: scoreColor.withValues(alpha: 0.7),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    passed
                        ? '¡Evaluación superada!'
                        : 'Necesitas repasar',
                    style: TextStyle(
                        color: textP,
                        fontSize: 20,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Triage · START / ESI',
                    style: TextStyle(color: textS, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (_xpEarned > 0) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              size: 18, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '+$_xpEarned XP ganados',
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (_levelAfter > 0)
                                Text(
                                  'Nivel actual: $_levelAfter',
                                  style: TextStyle(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.75),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else if (passed == false) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.red.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16,
                              color: AppColors.red.withValues(alpha: 0.8)),
                          const SizedBox(width: 8),
                          Text(
                            'Necesitas ≥75% para ganar XP',
                            style: TextStyle(
                              color: AppColors.red.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      passed
                          ? pct >= 90
                              ? 'Excelente dominio del triage'
                              : 'Competencia suficiente'
                          : 'Revisa los criterios START/ESI',
                      style: TextStyle(
                          color: scoreColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ...List.generate(_scenarios.length, (i) {
                    final correct = i < _results.length ? _results[i] : false;
                    final s = _scenarios[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? (correct
                                ? const Color(0xFF059669)
                                    .withValues(alpha: 0.08)
                                : AppColors.red.withValues(alpha: 0.08))
                            : (correct
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFEF2F2)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: correct
                              ? const Color(0xFF059669).withValues(alpha: 0.3)
                              : AppColors.red.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            correct
                                ? Icons.check_circle_outline_rounded
                                : Icons.cancel_outlined,
                            color: correct
                                ? const Color(0xFF059669)
                                : AppColors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Caso ${i + 1}: ${s.title}',
                              style: TextStyle(
                                color: correct
                                    ? const Color(0xFF059669)
                                    : AppColors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.list_alt_rounded, size: 16),
                          label: const Text('Volver'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startNewRound,
                          icon: const Icon(Icons.replay_rounded, size: 16),
                          label: const Text('Nueva ronda'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.amber,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
