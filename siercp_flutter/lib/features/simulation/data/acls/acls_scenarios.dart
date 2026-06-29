enum AclsRhythm { vf, tvsp, asistolia, aesp, organized, bradycardia }

enum AclsCause { none, tamponade, massivePe, ischemia, hyperkalemia, hypothermia, toxin, postRosc }

class AclsScenario {
  final String id;
  final String title;
  final String description;
  final String situation;
  final AclsRhythm initialRhythm;
  final AclsCause cause;
  final int cyclesRequired;

  const AclsScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.situation,
    required this.initialRhythm,
    this.cause = AclsCause.none,
    this.cyclesRequired = 2,
  });
}

const List<AclsScenario> kAclsScenarios = [
  AclsScenario(
    id: 'acls_fv_refractaria',
    title: 'FV Refractaria',
    description: 'FV que persiste tras descargas + amiodarona',
    situation: 'Hombre 60 años, IAM anterior. Monitor: FV. Tras 3 descargas y amiodarona 300mg, FV persiste. Intubado, acceso IO.',
    initialRhythm: AclsRhythm.vf,
    cause: AclsCause.ischemia,
    cyclesRequired: 3,
  ),
  AclsScenario(
    id: 'acls_tvsp',
    title: 'TVSP Post-IAM',
    description: 'TV sin pulso con cardiopatía isquémica',
    situation: 'Mujer 55 años, dolor torácico. Monitor: TV monomórfica a 190 lpm. Sin pulso. Inconsciente.',
    initialRhythm: AclsRhythm.tvsp,
    cause: AclsCause.ischemia,
    cyclesRequired: 2,
  ),
  AclsScenario(
    id: 'acls_aesp_taponamiento',
    title: 'AESP por Taponamiento',
    description: 'AESP con causa reversible (tapón pericárdico)',
    situation: 'Hombre 45 años, post-cirugía cardíaca. Hipotenso, ingurgitación yugular, ruidos cardíacos apagados. Monitor: QRS estrecho a 50 lpm. Sin pulso.',
    initialRhythm: AclsRhythm.aesp,
    cause: AclsCause.tamponade,
    cyclesRequired: 2,
  ),
  AclsScenario(
    id: 'acls_aesp_tep',
    title: 'AESP por TEP Masivo',
    description: 'Tromboembolismo pulmonar masivo',
    situation: 'Mujer 70 años, post-operatorio rodilla. Disnea súbita, hipotensión, SatO2 78%. Monitor: QRS estrecho a 60 lpm. Sin pulso. Signos de HD derecha.',
    initialRhythm: AclsRhythm.aesp,
    cause: AclsCause.massivePe,
    cyclesRequired: 2,
  ),
  AclsScenario(
    id: 'acls_asistolia',
    title: 'Asistolia + Hiperpotasemia',
    description: 'Paro en asistolia por hiperpotasemia',
    situation: 'Hombre 65 años, IRC en diálisis. ECG previo: ondas T picudas. Monitor actual: línea plana. Sin pulso.',
    initialRhythm: AclsRhythm.asistolia,
    cause: AclsCause.hyperkalemia,
    cyclesRequired: 2,
  ),
  AclsScenario(
    id: 'acls_post_rosc',
    title: 'Cuidados Post-ROSC',
    description: 'Manejo post-paro con IAM y shock cardiogénico',
    situation: 'Mujer 60 años. ROSC tras 2 descargas por FV. Intubada. PA 80/40, FC 110 lpm (sinusal). SatO2 94%. Glasgow 8. Sin respuesta a órdenes.',
    initialRhythm: AclsRhythm.organized,
    cause: AclsCause.postRosc,
    cyclesRequired: 0,
  ),
  AclsScenario(
    id: 'acls_bradicardia',
    title: 'Bradicardia Sintomática',
    description: 'Bloqueo AV de 3er grado con inestabilidad',
    situation: 'Hombre 75 años, síncope. FC 32 lpm. PA 70/40. Monitor: BAV completo (P a 80, QRS a 32). Mareado, diaforético.',
    initialRhythm: AclsRhythm.bradycardia,
    cause: AclsCause.none,
    cyclesRequired: 0,
  ),
  AclsScenario(
    id: 'acls_fv_ciclo',
    title: 'FV → Ritmo Organizado',
    description: 'FV que responde a tratamiento con conversión',
    situation: 'Hombre 50 años, paro presenciado. Monitor: FV. Desfibrilación precoz + RCP + adrenalina.',
    initialRhythm: AclsRhythm.vf,
    cause: AclsCause.none,
    cyclesRequired: 2,
  ),
];
