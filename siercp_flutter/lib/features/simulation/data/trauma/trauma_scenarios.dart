enum TraumaType { tce, neumotorax, hemoneumotorax, taponamiento, hemorragia, quemadura, amputacion, politrauma }

enum TraumaIntervention { decompression, tourniquet, pelvicBinding, chestSeal, fluidResuscitation, spinalImmobilization, needleCric }

class TraumaScenario {
  final String id;
  final String title;
  final String description;
  final String situation;
  final TraumaType type;
  final List<TraumaIntervention> requiredInterventions;
  final bool spinalPrecaution;

  const TraumaScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.situation,
    required this.type,
    this.requiredInterventions = const [],
    this.spinalPrecaution = false,
  });
}

const List<TraumaScenario> kTraumaScenarios = [
  TraumaScenario(
    id: 'trauma_tce_severo',
    title: 'TCE Severo',
    description: 'Glasgow 6 con hipertensión intracraneal',
    situation: 'Hombre 25 años, accidente moto sin casco. GCS 6 (O1 V2 M3). Anisocoria derecha. Signo de Babinski bilateral. PA 160/90, FC 55.',
    type: TraumaType.tce,
    requiredInterventions: [TraumaIntervention.spinalImmobilization],
    spinalPrecaution: true,
  ),
  TraumaScenario(
    id: 'trauma_neumotorax_tension',
    title: 'Neumotórax a Tensión',
    description: 'Trauma penetrante con compromiso ventilatorio',
    situation: 'Hombre 30 años, herida por arma blanca en hemitórax derecho. Disnea severa, desviación traqueal a izquierda, ausencia de ruidos respiratorios derechos, ingurgitación yugular, PA 70/40.',
    type: TraumaType.neumotorax,
    requiredInterventions: [TraumaIntervention.decompression, TraumaIntervention.chestSeal],
  ),
  TraumaScenario(
    id: 'trauma_hemoneumotorax',
    title: 'Hemoneumotórax',
    description: 'Trauma cerrado con sangrado torácico masivo',
    situation: 'Mujer 40 años, accidente automovilístico. Dolor torácico izquierdo, matidez a percusión, ruidos respiratorios disminuidos, PA 85/50, FC 120. Drenaje 1500 mL por tubo pleural.',
    type: TraumaType.hemoneumotorax,
    requiredInterventions: [TraumaIntervention.chestSeal, TraumaIntervention.fluidResuscitation],
    spinalPrecaution: true,
  ),
  TraumaScenario(
    id: 'trauma_taponamiento',
    title: 'Taponamiento Cardíaco',
    description: 'Herida penetrante precordial con signos de Beck',
    situation: 'Hombre 22 años, herida por arma blanca precordial. Tríada de Beck: ingurgitación yugular, hipotensión, ruidos cardíacos apagados. Pulso paradójico. Ecografía FAST: derrame pericárdico.',
    type: TraumaType.taponamiento,
    requiredInterventions: [TraumaIntervention.needleCric, TraumaIntervention.fluidResuscitation],
  ),
  TraumaScenario(
    id: 'trauma_fractura_pelvis',
    title: 'Fractura Pélvica + Shock',
    description: 'Fractura pélvica inestable con shock hemorrágico',
    situation: 'Mujer 65 años, atropellada. Dolor pélvico intenso, deformidad, hematoma perineal. PA 60/40, FC 140. No responde a cristaloides 2L.',
    type: TraumaType.hemorragia,
    requiredInterventions: [TraumaIntervention.pelvicBinding, TraumaIntervention.fluidResuscitation],
    spinalPrecaution: true,
  ),
  TraumaScenario(
    id: 'trauma_quemaduras',
    title: 'Quemaduras Extensas',
    description: '30% SCQ con compromiso de vía aérea',
    situation: 'Bombero rescatado de incendio. Quemaduras faciales, vibrisas nasales quemadas, disnea. Quemaduras de 2do/3er grado en cara, cuello, tórax anterior y brazos (30% SCQ). PA 100/70, FC 110.',
    type: TraumaType.quemadura,
    requiredInterventions: [TraumaIntervention.fluidResuscitation],
  ),
  TraumaScenario(
    id: 'trauma_amputacion_traumatica',
    title: 'Amputación Traumática',
    description: 'Amputación de extremidad inferior con hemorragia masiva',
    situation: 'Hombre 35 años, accidente laboral con sierra. Amputación traumática completa de pierna izquierda (tercio medio). Sangrado profuso. PA 70/40, FC 130, confuso.',
    type: TraumaType.amputacion,
    requiredInterventions: [TraumaIntervention.tourniquet, TraumaIntervention.fluidResuscitation],
  ),
  TraumaScenario(
    id: 'trauma_politrauma',
    title: 'Politrauma Vehicular',
    description: 'Múltiples lesiones por colisión de alta energía',
    situation: 'Hombre 50 años, colisión frontal a 100 km/h. Atrapado 30 min. GCS 9, trauma facial, deformidad torácica derecha, abdomen distendido, fractura abierta de fémur izquierdo, deformidad pélvica. PA 65/40.',
    type: TraumaType.politrauma,
    requiredInterventions: [
      TraumaIntervention.spinalImmobilization, TraumaIntervention.chestSeal,
      TraumaIntervention.pelvicBinding, TraumaIntervention.tourniquet,
      TraumaIntervention.fluidResuscitation,
    ],
    spinalPrecaution: true,
  ),
];
