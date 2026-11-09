enum AirwayCorrectDevice { opa, sga, ett, noDevice, bvmOnly }

enum AirwayComplication { none, cervicalInjury, facialTrauma, pediatrics, difficultIntubation, smokeInhalation, anaphylaxis }

class AirwayScenario {
  final String id;
  final String title;
  final String description;
  final String situation;
  final AirwayCorrectDevice correctDevice;
  final AirwayComplication complication;
  final bool conscious;
  final bool breathing;

  const AirwayScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.situation,
    required this.correctDevice,
    this.complication = AirwayComplication.none,
    this.conscious = false,
    this.breathing = true,
  });
}

const List<AirwayScenario> kAirwayScenarios = [
  AirwayScenario(
    id: 'airway_obstruccion_parcial',
    title: 'Obstrucción Parcial',
    description: 'Obstrucción leve con tos efectiva',
    situation: 'Hombre de 45 años comiendo, se atora con un trozo de carne. Tos fuerte, puede hablar entre tos, saturación 94%.',
    correctDevice: AirwayCorrectDevice.noDevice,
    conscious: true,
    breathing: true,
  ),
  AirwayScenario(
    id: 'airway_obstruccion_total',
    title: 'Obstrucción Total',
    description: 'Obstrucción severa, inconsciente',
    situation: 'Mujer de 60 años en restaurante, súbitamente no puede respirar. Cianótica, inconsciente, sin respiración. No hay tos ni sonidos respiratorios.',
    correctDevice: AirwayCorrectDevice.opa,
    complication: AirwayComplication.none,
    conscious: false,
    breathing: false,
  ),
  AirwayScenario(
    id: 'airway_trauma_facial',
    title: 'Trauma Facial + Cervical',
    description: 'Politrauma con posible lesión cervical',
    situation: 'Accidente automovilístico. Hombre 30 años, Glasgow 10, trauma facial severo, sangrado oral, sospecha de lesión cervical. SatO2 85%.',
    correctDevice: AirwayCorrectDevice.ett,
    complication: AirwayComplication.cervicalInjury,
    conscious: false,
    breathing: true,
  ),
  AirwayScenario(
    id: 'airway_edema_glotico',
    title: 'Edema Glótico (Anafilaxia)',
    description: 'Anafilaxia con compromiso de vía aérea',
    situation: 'Mujer de 25 años, minutos después de recibir penicilina IM. Disnea severa, estridor, urticaria generalizada, edema facial y lingual. SatO2 88% descendiendo.',
    correctDevice: AirwayCorrectDevice.ett,
    complication: AirwayComplication.anaphylaxis,
    conscious: true,
    breathing: true,
  ),
  AirwayScenario(
    id: 'airway_quemadura',
    title: 'Quemadura Inhalatoria',
    description: 'Inhalación de humo con edema de vía aérea',
    situation: 'Bombero de 35 años rescatado de incendio. Quemaduras faciales, vibrisas nasales quemadas, disnea, tos con esputo carbonáceo. SatO2 90%. Estridor inspiratorio.',
    correctDevice: AirwayCorrectDevice.ett,
    complication: AirwayComplication.smokeInhalation,
    conscious: true,
    breathing: true,
  ),
  AirwayScenario(
    id: 'airway_intubacion_dificil',
    title: 'Vía Aérea Difícil',
    description: 'Mallampati IV, intubación difícil anticipada',
    situation: 'Hombre 55 años, obesidad mórbida (IMC 42), cuello corto y grueso, apertura oral limitada, Mallampati IV. Requiere intubación para cirugía de emergencia.',
    correctDevice: AirwayCorrectDevice.sga,
    complication: AirwayComplication.difficultIntubation,
    conscious: true,
    breathing: true,
  ),
  AirwayScenario(
    id: 'airway_pediatrico',
    title: 'Vía Aérea Pediátrica',
    description: 'Obstrucción en niño',
    situation: 'Niño de 3 años, atragantamiento con juguete pequeño. Inconsciente, sin respiración. No hay pulso. Se inicia RCP.',
    correctDevice: AirwayCorrectDevice.opa,
    complication: AirwayComplication.pediatrics,
    conscious: false,
    breathing: false,
  ),
  AirwayScenario(
    id: 'airway_bvm_apnea',
    title: 'Apnea Post-Ictal',
    description: 'Paciente en apnea tras convulsión',
    situation: 'Hombre 40 años, crisis convulsiva presenciada. Ahora post-ictal, apnea, saturación 82% y descendiendo. Pulso presente, 110 lpm.',
    correctDevice: AirwayCorrectDevice.bvmOnly,
    complication: AirwayComplication.none,
    conscious: false,
    breathing: false,
  ),
];
