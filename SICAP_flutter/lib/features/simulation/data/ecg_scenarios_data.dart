import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/simulation/data/models/ecg_scenario.dart';

/// Catálogo de escenarios de ECG simulado. Fuente de datos desacoplada: agregar
/// un nuevo escenario es tan simple como añadir una entrada a esta lista. La
/// presentación nunca instancia escenarios directamente; los consume a través
/// de [EcgScenarioRepository].
const List<EcgScenario> kEcgScenarios = [
  // ── Ritmos sinusales ───────────────────────────────────────────────────────
  EcgScenario(
    id: 'sinus_normal',
    name: 'Ritmo sinusal normal',
    category: 'Ritmos sinusales',
    summary: 'Ritmo de referencia · 60–100 lpm, P-QRS-T normal.',
    clinicalNote:
        'Onda P antes de cada QRS, intervalo PR constante (0.12–0.20 s) y QRS estrecho. Patrón normal de origen en el nódulo sinusal.',
    rhythm: EcgRhythm.sinusNormal,
    heartRate: 75,
    spo2: 98,
    respRate: 16,
    sysBp: 120,
    diaBp: 80,
    alarm: AlarmLevel.none,
    accent: AppColors.green,
  ),
  EcgScenario(
    id: 'sinus_brady',
    name: 'Bradicardia sinusal',
    category: 'Ritmos sinusales',
    summary: 'Ritmo sinusal lento · < 60 lpm.',
    clinicalNote:
        'Morfología sinusal normal con frecuencia inferior a 60 lpm. Común en atletas o por tono vagal; sintomática si hay hipoperfusión.',
    rhythm: EcgRhythm.sinusBradycardia,
    heartRate: 44,
    spo2: 96,
    respRate: 14,
    sysBp: 108,
    diaBp: 68,
    alarm: AlarmLevel.warning,
    accent: AppColors.amber,
  ),
  EcgScenario(
    id: 'sinus_tachy',
    name: 'Taquicardia sinusal',
    category: 'Ritmos sinusales',
    summary: 'Ritmo sinusal rápido · > 100 lpm.',
    clinicalNote:
        'Ritmo sinusal con frecuencia > 100 lpm. Respuesta a fiebre, dolor, hipovolemia, ansiedad o ejercicio. P normal antes de cada QRS.',
    rhythm: EcgRhythm.sinusTachycardia,
    heartRate: 128,
    spo2: 97,
    respRate: 22,
    sysBp: 124,
    diaBp: 78,
    alarm: AlarmLevel.advisory,
    accent: AppColors.cyan,
  ),
  EcgScenario(
    id: 'sinus_arrhythmia',
    name: 'Arritmia sinusal',
    category: 'Ritmos sinusales',
    summary: 'Variación respiratoria del intervalo R-R.',
    clinicalNote:
        'Ritmo sinusal cuyo intervalo R-R varía con la respiración (acelera en inspiración). Hallazgo benigno, frecuente en jóvenes.',
    rhythm: EcgRhythm.sinusArrhythmia,
    heartRate: 72,
    heartRateLabel: '68–84',
    spo2: 98,
    respRate: 16,
    sysBp: 118,
    diaBp: 76,
    alarm: AlarmLevel.none,
    accent: AppColors.green,
  ),

  // ── Arritmias auriculares ──────────────────────────────────────────────────
  EcgScenario(
    id: 'afib',
    name: 'Fibrilación auricular',
    category: 'Arritmias auriculares',
    summary: 'Sin onda P · R-R irregularmente irregular.',
    clinicalNote:
        'Ausencia de ondas P, línea de base con ondas fibrilatorias y respuesta ventricular irregularmente irregular. Riesgo embólico.',
    rhythm: EcgRhythm.atrialFibrillation,
    heartRate: 112,
    heartRateLabel: 'Irregular',
    spo2: 96,
    respRate: 18,
    sysBp: 116,
    diaBp: 74,
    alarm: AlarmLevel.warning,
    accent: AppColors.amber,
  ),
  EcgScenario(
    id: 'aflutter',
    name: 'Flutter auricular',
    category: 'Arritmias auriculares',
    summary: 'Ondas F en diente de sierra · conducción regular.',
    clinicalNote:
        'Actividad auricular en "diente de sierra" (~300/min) con conducción AV típicamente 2:1. Ritmo ventricular generalmente regular.',
    rhythm: EcgRhythm.atrialFlutter,
    heartRate: 150,
    spo2: 96,
    respRate: 18,
    sysBp: 118,
    diaBp: 76,
    alarm: AlarmLevel.warning,
    accent: AppColors.amber,
  ),
  EcgScenario(
    id: 'svt',
    name: 'Taquicardia supraventricular',
    category: 'Arritmias auriculares',
    summary: 'Taquicardia regular y estrecha · sin P visible.',
    clinicalNote:
        'Taquicardia de complejo estrecho, regular, 150–250 lpm, con ondas P no identificables. Suele responder a maniobras vagales/adenosina.',
    rhythm: EcgRhythm.svt,
    heartRate: 188,
    spo2: 95,
    respRate: 22,
    sysBp: 104,
    diaBp: 66,
    alarm: AlarmLevel.warning,
    accent: AppColors.amber,
  ),

  // ── Arritmias ventriculares / paro ─────────────────────────────────────────
  EcgScenario(
    id: 'vtach',
    name: 'Taquicardia ventricular',
    category: 'Arritmias ventriculares',
    summary: 'Complejos anchos, regulares y rápidos.',
    clinicalNote:
        'Tres o más latidos ventriculares consecutivos > 100 lpm, QRS ancho. Puede tener pulso o no. Riesgo de degeneración a FV.',
    rhythm: EcgRhythm.vtach,
    heartRate: 180,
    spo2: 88,
    respRate: 26,
    sysBp: 78,
    diaBp: 48,
    pulsePresent: true,
    alarm: AlarmLevel.critical,
    accent: AppColors.red,
  ),
  EcgScenario(
    id: 'vfib',
    name: 'Fibrilación ventricular',
    category: 'Arritmias ventriculares',
    summary: 'Actividad caótica · ¡desfibrilable!',
    clinicalNote:
        'Ondulaciones caóticas sin complejos identificables ni gasto cardíaco. Paro cardíaco: RCP inmediata y desfibrilación.',
    rhythm: EcgRhythm.vfib,
    heartRate: 0,
    heartRateLabel: 'FV',
    spo2: 0,
    respRate: 0,
    pulsePresent: false,
    alarm: AlarmLevel.critical,
    accent: AppColors.red,
  ),
  EcgScenario(
    id: 'asystole',
    name: 'Asistolia',
    category: 'Arritmias ventriculares',
    summary: 'Línea isoeléctrica · ausencia de actividad.',
    clinicalNote:
        'Ausencia total de actividad eléctrica ventricular (línea plana). NO desfibrilable: RCP de alta calidad y adrenalina; buscar causas reversibles.',
    rhythm: EcgRhythm.asystole,
    heartRate: 0,
    spo2: 0,
    respRate: 0,
    pulsePresent: false,
    alarm: AlarmLevel.critical,
    accent: AppColors.red,
  ),
  EcgScenario(
    id: 'pea',
    name: 'Actividad eléctrica sin pulso (AESP)',
    category: 'Arritmias ventriculares',
    summary: 'Ritmo organizado SIN pulso palpable.',
    clinicalNote:
        'Existe actividad eléctrica organizada en el monitor pero sin pulso central. NO desfibrilable: RCP y tratar las 5H/5T.',
    rhythm: EcgRhythm.pea,
    heartRate: 58,
    spo2: 0,
    respRate: 0,
    pulsePresent: false,
    alarm: AlarmLevel.critical,
    accent: AppColors.red,
  ),

  // ── Bloqueos AV ────────────────────────────────────────────────────────────
  EcgScenario(
    id: 'av_block_1',
    name: 'Bloqueo AV de primer grado',
    category: 'Bloqueos AV',
    summary: 'PR prolongado y constante (> 0.20 s).',
    clinicalNote:
        'Cada P conduce a un QRS, pero con PR alargado y fijo. Generalmente benigno y asintomático.',
    rhythm: EcgRhythm.avBlock1,
    heartRate: 66,
    spo2: 97,
    respRate: 15,
    sysBp: 122,
    diaBp: 78,
    alarm: AlarmLevel.advisory,
    accent: AppColors.cyan,
  ),
  EcgScenario(
    id: 'av_block_2_i',
    name: 'Bloqueo AV 2.º grado tipo I (Wenckebach)',
    category: 'Bloqueos AV',
    summary: 'PR se alarga hasta caer un QRS.',
    clinicalNote:
        'Alargamiento progresivo del PR hasta que una onda P no conduce (QRS ausente), reiniciando el ciclo. Habitualmente benigno.',
    rhythm: EcgRhythm.avBlock2TypeI,
    heartRate: 58,
    heartRateLabel: 'Variable',
    spo2: 96,
    respRate: 15,
    sysBp: 116,
    diaBp: 74,
    alarm: AlarmLevel.warning,
    accent: AppColors.amber,
  ),
  EcgScenario(
    id: 'av_block_2_ii',
    name: 'Bloqueo AV 2.º grado tipo II',
    category: 'Bloqueos AV',
    summary: 'QRS caídos con PR constante.',
    clinicalNote:
        'PR constante con ondas P que súbitamente no conducen (QRS ausente). Riesgo de progresión a bloqueo completo: vigilar/marcapasos.',
    rhythm: EcgRhythm.avBlock2TypeII,
    heartRate: 50,
    heartRateLabel: 'Variable',
    spo2: 95,
    respRate: 15,
    sysBp: 110,
    diaBp: 70,
    alarm: AlarmLevel.warning,
    accent: AppColors.amber,
  ),
  EcgScenario(
    id: 'av_block_3',
    name: 'Bloqueo AV completo (3.er grado)',
    category: 'Bloqueos AV',
    summary: 'Disociación AV · P y QRS independientes.',
    clinicalNote:
        'Las aurículas y los ventrículos laten de forma independiente. Ritmo de escape lento. Requiere marcapasos.',
    rhythm: EcgRhythm.avBlock3,
    heartRate: 38,
    spo2: 93,
    respRate: 16,
    sysBp: 96,
    diaBp: 60,
    alarm: AlarmLevel.critical,
    accent: AppColors.red,
  ),

  // ── Trastornos de conducción ───────────────────────────────────────────────
  EcgScenario(
    id: 'rbbb',
    name: 'Bloqueo de rama derecha',
    category: 'Trastornos de conducción',
    summary: 'QRS ancho · patrón rSR\' ("orejas de conejo").',
    clinicalNote:
        'QRS ≥ 0.12 s con patrón rSR\' en precordiales derechas. Puede ser un hallazgo normal o asociarse a cardiopatía.',
    rhythm: EcgRhythm.rbbb,
    heartRate: 76,
    spo2: 97,
    respRate: 16,
    sysBp: 120,
    diaBp: 78,
    alarm: AlarmLevel.advisory,
    accent: AppColors.cyan,
  ),
  EcgScenario(
    id: 'lbbb',
    name: 'Bloqueo de rama izquierda',
    category: 'Trastornos de conducción',
    summary: 'QRS ancho con T discordante.',
    clinicalNote:
        'QRS ≥ 0.12 s, ancho y mellado, con repolarización discordante. Nuevo BRI con dolor torácico = posible SCA.',
    rhythm: EcgRhythm.lbbb,
    heartRate: 78,
    spo2: 96,
    respRate: 16,
    sysBp: 118,
    diaBp: 76,
    alarm: AlarmLevel.warning,
    accent: AppColors.amber,
  ),

  // ── Extrasístoles ──────────────────────────────────────────────────────────
  EcgScenario(
    id: 'pac',
    name: 'Extrasístoles auriculares',
    category: 'Extrasístoles',
    summary: 'Latidos auriculares prematuros (P\' anómala).',
    clinicalNote:
        'Complejos prematuros de origen auricular con onda P\' de morfología distinta y QRS estrecho. Generalmente benignos.',
    rhythm: EcgRhythm.pac,
    heartRate: 80,
    spo2: 98,
    respRate: 16,
    sysBp: 120,
    diaBp: 78,
    alarm: AlarmLevel.advisory,
    accent: AppColors.cyan,
  ),
  EcgScenario(
    id: 'pvc',
    name: 'Extrasístoles ventriculares',
    category: 'Extrasístoles',
    summary: 'Latidos ventriculares prematuros y anchos.',
    clinicalNote:
        'Complejos prematuros, anchos y bizarros, sin P previa, con pausa compensadora. Frecuentes; valorar si son numerosos o sintomáticos.',
    rhythm: EcgRhythm.pvc,
    heartRate: 78,
    spo2: 97,
    respRate: 16,
    sysBp: 120,
    diaBp: 78,
    alarm: AlarmLevel.advisory,
    accent: AppColors.cyan,
  ),
  EcgScenario(
    id: 'bigeminy',
    name: 'Bigeminismo ventricular',
    category: 'Extrasístoles',
    summary: 'Un latido normal alternando con un PVC.',
    clinicalNote:
        'Patrón en el que cada latido sinusal va seguido de una extrasístole ventricular, de forma alternante (1:1).',
    rhythm: EcgRhythm.bigeminy,
    heartRate: 74,
    spo2: 96,
    respRate: 16,
    sysBp: 114,
    diaBp: 74,
    alarm: AlarmLevel.warning,
    accent: AppColors.amber,
  ),
  EcgScenario(
    id: 'trigeminy',
    name: 'Trigeminismo ventricular',
    category: 'Extrasístoles',
    summary: 'Dos latidos normales y un PVC (2:1).',
    clinicalNote:
        'Cada dos latidos sinusales aparece una extrasístole ventricular, de forma repetida.',
    rhythm: EcgRhythm.trigeminy,
    heartRate: 76,
    spo2: 97,
    respRate: 16,
    sysBp: 116,
    diaBp: 74,
    alarm: AlarmLevel.advisory,
    accent: AppColors.cyan,
  ),
  EcgScenario(
    id: 'torsades',
    name: 'Torsades de Pointes',
    category: 'Arritmias ventriculares',
    summary: 'TV polimorfa que "gira" sobre la línea de base.',
    clinicalNote:
        'Taquicardia ventricular polimorfa con amplitud que crece y decrece en husos. Asociada a QT largo. Tratar con sulfato de magnesio.',
    rhythm: EcgRhythm.torsades,
    heartRate: 0,
    heartRateLabel: 'TV polim.',
    spo2: 82,
    respRate: 0,
    sysBp: 70,
    diaBp: 0,
    pulsePresent: false,
    alarm: AlarmLevel.critical,
    accent: AppColors.red,
  ),

  // ── Alteraciones metabólicas / isquémicas ──────────────────────────────────
  EcgScenario(
    id: 'hyperkalemia',
    name: 'Hiperkalemia',
    category: 'Alteraciones metabólicas',
    summary: 'Ondas T altas y picudas · QRS ensanchado.',
    clinicalNote:
        'Ondas T picudas y simétricas, aplanamiento de P y ensanchamiento del QRS conforme aumenta el potasio. Emergencia metabólica.',
    rhythm: EcgRhythm.hyperkalemia,
    heartRate: 70,
    spo2: 96,
    respRate: 16,
    sysBp: 128,
    diaBp: 82,
    alarm: AlarmLevel.warning,
    accent: AppColors.amber,
  ),
  EcgScenario(
    id: 'hypokalemia',
    name: 'Hipokalemia',
    category: 'Alteraciones metabólicas',
    summary: 'Onda U prominente · T aplanada, ST descendido.',
    clinicalNote:
        'Aplanamiento/inversión de la onda T, descenso del ST y onda U prominente. Riesgo de arritmias ventriculares.',
    rhythm: EcgRhythm.hypokalemia,
    heartRate: 72,
    spo2: 97,
    respRate: 16,
    sysBp: 124,
    diaBp: 80,
    alarm: AlarmLevel.advisory,
    accent: AppColors.cyan,
  ),
  EcgScenario(
    id: 'ischemia',
    name: 'Isquemia miocárdica',
    category: 'Alteraciones isquémicas',
    summary: 'Descenso del ST e inversión de la onda T.',
    clinicalNote:
        'Descenso del segmento ST y/o inversión de la onda T que reflejan isquemia subendocárdica. Correlacionar con la clínica.',
    rhythm: EcgRhythm.ischemia,
    heartRate: 92,
    spo2: 95,
    respRate: 18,
    sysBp: 138,
    diaBp: 86,
    alarm: AlarmLevel.warning,
    accent: AppColors.amber,
  ),
  EcgScenario(
    id: 'stemi',
    name: 'IAM con elevación del ST',
    category: 'Alteraciones isquémicas',
    summary: 'Elevación significativa del segmento ST.',
    clinicalNote:
        'Elevación del ST en derivaciones contiguas: oclusión coronaria aguda. Activar código infarto y reperfusión urgente.',
    rhythm: EcgRhythm.stemi,
    heartRate: 98,
    spo2: 94,
    respRate: 20,
    sysBp: 142,
    diaBp: 88,
    alarm: AlarmLevel.critical,
    accent: AppColors.red,
  ),
  EcgScenario(
    id: 'nstemi',
    name: 'IAM sin elevación del ST',
    category: 'Alteraciones isquémicas',
    summary: 'Descenso del ST / T invertida, sin elevación.',
    clinicalNote:
        'Descenso del ST y/o inversión de T sin elevación persistente. El diagnóstico se apoya en biomarcadores (troponinas).',
    rhythm: EcgRhythm.nstemi,
    heartRate: 94,
    spo2: 95,
    respRate: 19,
    sysBp: 136,
    diaBp: 84,
    alarm: AlarmLevel.warning,
    accent: AppColors.amber,
  ),
  EcgScenario(
    id: 'pericarditis',
    name: 'Pericarditis',
    category: 'Alteraciones isquémicas',
    summary: 'Elevación difusa y cóncava del ST.',
    clinicalNote:
        'Elevación difusa y cóncava del ST con descenso del PR. Dolor pleurítico que mejora al inclinarse hacia delante.',
    rhythm: EcgRhythm.pericarditis,
    heartRate: 96,
    spo2: 97,
    respRate: 18,
    sysBp: 122,
    diaBp: 78,
    alarm: AlarmLevel.advisory,
    accent: AppColors.cyan,
  ),

  // ── Marcapasos ─────────────────────────────────────────────────────────────
  EcgScenario(
    id: 'paced',
    name: 'Ritmo de marcapasos',
    category: 'Dispositivos',
    summary: 'Espiga de marcapasos seguida de QRS ancho.',
    clinicalNote:
        'Cada complejo va precedido de una espiga vertical estrecha (estímulo del marcapasos) con QRS ancho de captura ventricular.',
    rhythm: EcgRhythm.paced,
    heartRate: 72,
    spo2: 97,
    respRate: 16,
    sysBp: 118,
    diaBp: 76,
    alarm: AlarmLevel.advisory,
    accent: AppColors.cyan,
  ),
];

/// Repositorio simple sobre el catálogo. Aísla a la presentación de la fuente
/// de datos concreta y deja la puerta abierta a, en el futuro, cargar
/// escenarios desde Firestore u otra fuente remota.
class EcgScenarioRepository {
  const EcgScenarioRepository();

  List<EcgScenario> getAll() => kEcgScenarios;

  EcgScenario? getById(String id) {
    for (final s in kEcgScenarios) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Escenarios agrupados por categoría, preservando el orden del catálogo.
  Map<String, List<EcgScenario>> grouped() {
    final map = <String, List<EcgScenario>>{};
    for (final s in kEcgScenarios) {
      map.putIfAbsent(s.category, () => []).add(s);
    }
    return map;
  }
}
