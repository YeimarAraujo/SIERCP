enum AedRhythmType { shockable, nonShockable }

enum AedSpecialCondition {
  none,
  wetSurface,
  pediatric,
  excessiveHair,
  pacemaker,
}

class AedScenario {
  final String id;
  final String title;
  final String description;
  final AedRhythmType rhythmType;
  final bool isDecisionMode;
  final AedSpecialCondition specialCondition;

  const AedScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.rhythmType,
    this.isDecisionMode = false,
    this.specialCondition = AedSpecialCondition.none,
  });

  bool get hasSpecialCondition => specialCondition != AedSpecialCondition.none;
}

final List<AedScenario> kAedScenarios = [
  // ── Shockable ──────────────────────────────────────────────
  const AedScenario(
    id: 'aed_fv',
    title: 'Fibrilación Ventricular',
    description: 'Paciente inconsciente, sin pulso. Ritmo desfibrilable.',
    rhythmType: AedRhythmType.shockable,
  ),
  const AedScenario(
    id: 'aed_tv',
    title: 'Taquicardia Ventricular sin pulso',
    description: 'Paciente en parada. TV sin pulso, requiere descarga.',
    rhythmType: AedRhythmType.shockable,
  ),
  const AedScenario(
    id: 'aed_fv_mojada',
    title: 'FV - Superficie mojada',
    description: 'Paciente en charco de agua. Secar el tórax antes de colocar parches.',
    rhythmType: AedRhythmType.shockable,
    specialCondition: AedSpecialCondition.wetSurface,
  ),
  const AedScenario(
    id: 'aed_fv_pediatrico',
    title: 'FV - Paciente pediátrico',
    description: 'Niño de 4 años en parada. Usar parches pediátricos.',
    rhythmType: AedRhythmType.shockable,
    specialCondition: AedSpecialCondition.pediatric,
  ),
  const AedScenario(
    id: 'aed_fv_vello',
    title: 'FV - Vello excesivo',
    description: 'Tórax con vello que impide adhesión de parches. Afeitar antes.',
    rhythmType: AedRhythmType.shockable,
    specialCondition: AedSpecialCondition.excessiveHair,
  ),
  const AedScenario(
    id: 'aed_fv_marcapasos',
    title: 'FV - Marcapasos',
    description: 'Paciente con marcapasos visible. Colocar parche a 3 cm del dispositivo.',
    rhythmType: AedRhythmType.shockable,
    specialCondition: AedSpecialCondition.pacemaker,
  ),
  const AedScenario(
    id: 'aed_fv_ciclo',
    title: 'FV → Ritmo organizado',
    description: 'FV inicial. Descarga exitosa que restaura ritmo organizado.',
    rhythmType: AedRhythmType.shockable,
  ),

  // ── No Shockable ───────────────────────────────────────────
  const AedScenario(
    id: 'aed_asistolia',
    title: 'Asistolia',
    description: 'Paciente en asistolia. Ritmo no desfibrilable.',
    rhythmType: AedRhythmType.nonShockable,
  ),
  const AedScenario(
    id: 'aed_aesp',
    title: 'AESP',
    description: 'Actividad Eléctrica Sin Pulso. No desfibrilable.',
    rhythmType: AedRhythmType.nonShockable,
  ),

  // ── "¿Qué haría el DEA?" (modo decisión) ──────────────────
  const AedScenario(
    id: 'aed_fv_decision',
    title: '¿Qué haría el DEA? - FV',
    description: 'Analizando ritmo... ¿Descarga recomendada? Decide antes de ver.',
    rhythmType: AedRhythmType.shockable,
    isDecisionMode: true,
  ),
  const AedScenario(
    id: 'aed_asistolia_decision',
    title: '¿Qué haría el DEA? - Asistolia',
    description: 'Analizando ritmo... ¿Descarga o RCP? Tú decides.',
    rhythmType: AedRhythmType.nonShockable,
    isDecisionMode: true,
  ),
  const AedScenario(
    id: 'aed_tv_decision',
    title: '¿Qué haría el DEA? - TV',
    description: 'Ritro rápido y ancho. ¿Desfibrilable? Decide antes de la respuesta.',
    rhythmType: AedRhythmType.shockable,
    isDecisionMode: true,
  ),
  const AedScenario(
    id: 'aed_aesp_decision',
    title: '¿Qué haría el DEA? - AESP',
    description: 'Ritmo organizado pero sin pulso. ¿Descarga o RCP?',
    rhythmType: AedRhythmType.nonShockable,
    isDecisionMode: true,
  ),
];

List<AedScenario> get kAedShockableScenarios =>
    kAedScenarios.where((s) => s.rhythmType == AedRhythmType.shockable).toList();

List<AedScenario> get kAedNonShockableScenarios =>
    kAedScenarios.where((s) => s.rhythmType == AedRhythmType.nonShockable).toList();

List<AedScenario> get kAedDecisionScenarios =>
    kAedScenarios.where((s) => s.isDecisionMode).toList();
