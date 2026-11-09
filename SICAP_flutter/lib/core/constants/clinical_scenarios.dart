import 'package:siercp/features/courses/data/models/alert_course.dart';

/// Lista maestra de escenarios clínicos SIERCP.
///
/// REGLA: Esta es la ÚNICA fuente de verdad para escenarios.
/// NO duplicar en componentes, no crear listas recortadas.
/// Todos los selects, filtros y módulos de práctica deben importar desde aquí.
///
/// Sincronizado con: SIERCP-WEB/src/shared/constants/clinical-scenarios.ts
const List<ClinicalScenario> kClinicalScenarios = [
  ClinicalScenario(
    id: 'paroCardiaco',
    title: 'Paro cardíaco en casa',
    description: 'Familiar inconsciente en el suelo. Sin pulso ni respiración.',
    audioIntroText: 'Adulto de 52 años. Sin pulso. Inicie RCP de inmediato.',
    patientAge: 'Adulto (52 años)',
    patientType: 'adult',
    category: ScenarioCategory.paroCardiaco,
    difficulty: 'medium',
    relatedGuideId: 'guide_001',
  ),
  ClinicalScenario(
    id: 'accidenteTransito',
    title: 'Accidente de tránsito',
    description: 'Víctima en la vía, sin respuesta. Múltiples traumas.',
    audioIntroText: 'Adulto de 35 años. Accidente vial. Sin respuesta. Evalúa la escena.',
    patientAge: 'Adulto (35 años)',
    patientType: 'adult',
    category: ScenarioCategory.accidenteTransito,
    difficulty: 'hard',
  ),
  ClinicalScenario(
    id: 'ahogamiento',
    title: 'Ahogamiento en piscina',
    description: 'Rescatado del agua. Protocolo especial: ventilaciones primero.',
    audioIntroText: 'Adulto rescatado de la piscina. Sin respiración. Ventile primero.',
    patientAge: 'Adulto',
    patientType: 'adult',
    category: ScenarioCategory.ahogamiento,
    difficulty: 'hard',
    relatedGuideId: 'guide_005',
    isNew: false,
  ),
  ClinicalScenario(
    id: 'colapsoEjercicio',
    title: 'Colapso durante ejercicio',
    description: 'Atleta en el gimnasio. Posible fibrilación ventricular.',
    audioIntroText: 'Adulto de 28 años. Colapso en gimnasio. Usa el DEA disponible.',
    patientAge: 'Adulto (28 años)',
    patientType: 'adult',
    category: ScenarioCategory.colapsoEjercicio,
    difficulty: 'medium',
    relatedGuideId: 'guide_003',
  ),
  ClinicalScenario(
    id: 'atragantamiento',
    title: 'Atragantamiento severo',
    description: 'Obstrucción de vía aérea. Heimlich + RCP si pierde el conocimiento.',
    audioIntroText: 'Adulto. Atragantamiento durante cena. Aplica Heimlich primero.',
    patientAge: 'Adulto',
    patientType: 'adult',
    category: ScenarioCategory.atragantamiento,
    difficulty: 'medium',
  ),
  ClinicalScenario(
    id: 'descargaElectrica',
    title: 'Descarga eléctrica',
    description: 'Accidente laboral. Asegurar escena antes de actuar.',
    audioIntroText: 'Adulto electrocutado. Asegura la escena. Sin pulso ni respiración.',
    patientAge: 'Adulto',
    patientType: 'adult',
    category: ScenarioCategory.descargaElectrica,
    difficulty: 'hard',
  ),
  ClinicalScenario(
    id: 'sobredosis',
    title: 'Sobredosis por opioides',
    description: 'Intoxicación con respiración lenta. Naloxona + RCP si hay paro.',
    audioIntroText: 'Adulto con sobredosis. Respiración muy lenta. Administra Naloxona si disponible.',
    patientAge: 'Adulto',
    patientType: 'adult',
    category: ScenarioCategory.sobredosis,
    difficulty: 'hard',
  ),
  ClinicalScenario(
    id: 'infarto',
    title: 'Infarto que evoluciona a paro',
    description: 'Dolor torácico que evoluciona a paro cardíaco. Actúa rápido.',
    audioIntroText: 'Adulto de 60 años. Dolor torácico severo. Ahora pierde el conocimiento.',
    patientAge: 'Adulto (60 años)',
    patientType: 'adult',
    category: ScenarioCategory.infarto,
    difficulty: 'hard',
    relatedGuideId: 'guide_002',
  ),
  ClinicalScenario(
    id: 'pediatricoParo',
    title: 'Paro cardíaco pediátrico',
    description: 'Niño de 6 años. Sin respuesta. Protocolo pediátrico AHA 2025.',
    audioIntroText: 'Niño de 6 años. Sin pulso. Aplica protocolo pediátrico: 2 dedos, 30:2.',
    patientAge: 'Pediátrico (6 años)',
    patientType: 'pediatric',
    category: ScenarioCategory.paroCardiaco,
    difficulty: 'very_hard',
    isNew: true,
  ),
  ClinicalScenario(
    id: 'ahogamientoPediatrico',
    title: 'Ahogamiento pediátrico',
    description: 'Niño rescatado de piscina. Hipotermia secundaria.',
    audioIntroText: 'Niño de 4 años rescatado de piscina. Sin respiración. Ventilaciones primero.',
    patientAge: 'Pediátrico (4 años)',
    patientType: 'pediatric',
    category: ScenarioCategory.ahogamiento,
    difficulty: 'very_hard',
    isNew: true,
  ),
  ClinicalScenario(
    id: 'rvNeonatal',
    title: 'Reanimación neonatal',
    description: 'Recién nacido sin llanto. Protocolo NRP/AAP.',
    audioIntroText: 'Neonato. Sin llanto al nacer. Inicia pasos NRP inmediatamente.',
    patientAge: 'Neonato',
    patientType: 'infant',
    category: ScenarioCategory.paroCardiaco,
    difficulty: 'very_hard',
    locked: true,
  ),
  ClinicalScenario(
    id: 'traumaCraneo',
    title: 'Trauma craneoencefálico con paro',
    description: 'Accidente de moto. Trauma craneal y paro cardíaco simultáneo.',
    audioIntroText: 'Adulto. Trauma craneoencefálico severo. Ha perdido el pulso. Actúa con precaución.',
    patientAge: 'Adulto (25 años)',
    patientType: 'adult',
    category: ScenarioCategory.accidenteTransito,
    difficulty: 'very_hard',
    locked: true,
  ),
];

/// Acceso rápido por ID.
ClinicalScenario? getScenarioById(String id) {
  try {
    return kClinicalScenarios.firstWhere((s) => s.id == id);
  } catch (_) {
    return null;
  }
}

/// Escenarios para adultos (por defecto en práctica libre).
List<ClinicalScenario> get kAdultScenarios =>
    kClinicalScenarios.where((s) => s.patientType == 'adult' && !s.locked).toList();

/// Escenarios no bloqueados (disponibles para selección).
List<ClinicalScenario> get kUnlockedScenarios =>
    kClinicalScenarios.where((s) => !s.locked).toList();

// ── ClinicalScenario ──────────────────────────────────────────────────────────

/// Versión const de ScenarioModel para la lista estática local.
/// Equivalente a ScenarioModel pero sin dependencias de Firestore.
class ClinicalScenario {
  final String id;
  final String title;
  final String description;
  final String audioIntroText;
  final String patientAge;
  final String patientType;       // 'adult' | 'pediatric' | 'infant'
  final ScenarioCategory category;
  final String difficulty;        // 'easy' | 'medium' | 'hard' | 'very_hard'
  final bool locked;
  final bool isNew;
  final String? relatedGuideId;

  const ClinicalScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.audioIntroText,
    required this.patientAge,
    required this.patientType,
    required this.category,
    required this.difficulty,
    this.locked = false,
    this.isNew = false,
    this.relatedGuideId,
  });

  String get difficultyLabel => switch (difficulty) {
        'easy'      => 'Fácil',
        'medium'    => 'Medio',
        'hard'      => 'Difícil',
        'very_hard' => 'Muy difícil',
        _           => difficulty,
      };

  /// Convierte a ScenarioModel para compatibilidad con el sistema existente.
  ScenarioModel toScenarioModel() => ScenarioModel(
        id:            id,
        title:         title,
        description:   description,
        audioIntroText: audioIntroText,
        patientAge:    patientAge,
        patientType:   patientType,
        category:      category,
        difficulty:    difficulty,
        locked:        locked,
        isNew:         isNew,
        relatedGuideId: relatedGuideId,
      );
}
