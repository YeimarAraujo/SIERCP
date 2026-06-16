// lib/screens/scenario_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:siercp/core/widgets/app_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:siercp/core/utils/connection_guard.dart';

// ─── Modelo de datos del escenario ───────────────────────────────────────────
class ScenarioDetailData {
  final String id;
  final String titulo;
  final String subtitulo;
  final String nombrePaciente;
  final String edadDescripcion;
  final double pesoKg;
  final String descripcionClinica;
  final String situacion;
  final double profMinMm;
  final double profMaxMm;
  final double fuerzaMinKg;
  final double fuerzaMaxKg;
  final int frecMinPpm;
  final int frecMaxPpm;
  final String relacionVentilacion;
  final String tecnica;
  final Color color;
  final IconData icono;
  final String audioFile;

  const ScenarioDetailData({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.nombrePaciente,
    required this.edadDescripcion,
    required this.pesoKg,
    required this.descripcionClinica,
    required this.situacion,
    required this.profMinMm,
    required this.profMaxMm,
    required this.fuerzaMinKg,
    required this.fuerzaMaxKg,
    required this.frecMinPpm,
    required this.frecMaxPpm,
    required this.relacionVentilacion,
    required this.tecnica,
    required this.color,
    required this.icono,
    required this.audioFile,
  });
}

const Map<String, ScenarioDetailData> kScenarios = {
  // ── 1. Paro cardíaco ──────────────────────────────────────────────────────
  'paroCardiaco': ScenarioDetailData(
    id: 'paroCardiaco',
    titulo: 'Paro cardíaco en casa',
    subtitulo: 'RCP estándar · Guías AHA 2020',
    nombrePaciente: 'Roberto Suárez',
    edadDescripcion: '52 años',
    pesoKg: 82,
    descripcionClinica:
        'Hombre de 52 años, 82 kg. Familiar lo encuentra inconsciente en el suelo '
        'de la sala. Sin respuesta, sin pulso, sin respiración. '
        'Sin antecedentes cardíacos conocidos.',
    situacion: 'Estás en el domicilio. El servicio de emergencias fue alertado '
        '(ETA 7 minutos). Inicia RCP de inmediato con dos manos sobre el esternón. '
        'Mantén el ritmo 100-120 ppm y profundidad 5-6 cm sin interrupciones.',
    profMinMm: 50,
    profMaxMm: 60,
    fuerzaMinKg: 30,
    fuerzaMaxKg: 60,
    frecMinPpm: 100,
    frecMaxPpm: 120,
    relacionVentilacion: '30:2',
    tecnica: 'Dos manos sobre el esternón',
    // ✅ Sin cambios — parámetros conformes AHA 2020
    color: AppColors.red,
    icono: Icons.monitor_heart_outlined,
    audioFile: 'audio/caso_paroCardiaco.mp3',
  ),

  // ── 2. Accidente de tránsito ──────────────────────────────────────────────
  // ⚠️ CAMBIO: apertura de vía aérea con jaw-thrust (tracción mandibular),
  //    NO con inclinación cabeza-mentón (head-tilt) cuando hay sospecha
  //    de lesión cervical. AHA 2020 Part 9 / Trauma BLS.
  'accidenteTransito': ScenarioDetailData(
    id: 'accidenteTransito',
    titulo: 'Accidente de tránsito',
    subtitulo: 'Trauma múltiple · Protección cervical + jaw-thrust',
    nombrePaciente: 'Diana Morales',
    edadDescripcion: '35 años',
    pesoKg: 62,
    descripcionClinica:
        'Mujer de 35 años, 62 kg. Encontrada en la vía tras colisión vehicular. '
        'Sin respuesta verbal ni motora. Respiración ausente. '
        'Posible trauma cervical — NO inclinar cabeza hacia atrás.',
    situacion:
        'Asegura la escena antes de actuar. Mantén la columna en posición neutra. '
        'Abre la vía aérea con TRACCIÓN MANDIBULAR (jaw-thrust): coloca los pulgares '
        'en los pómulos y los dedos índices bajo el ángulo de la mandíbula; empuja '
        'la mandíbula hacia adelante SIN mover el cuello. '
        'Inicia RCP 30:2 con dos manos. ETA ambulancia: 10 min.',
    profMinMm: 50,
    profMaxMm: 60,
    fuerzaMinKg: 30,
    fuerzaMaxKg: 60,
    frecMinPpm: 100,
    frecMaxPpm: 120,
    relacionVentilacion: '30:2',
    tecnica:
        'Dos manos · Jaw-thrust (tracción mandibular) · Sin movilizar cuello',
    color: AppColors.amber,
    icono: Icons.directions_car_outlined,
    audioFile: 'audio/caso_accidenteTransito.mp3',
  ),

  // ── 3. Ahogamiento ────────────────────────────────────────────────────────
  // ⚠️ CAMBIO IMPORTANTE:
  //   • Paro por ahogamiento es de causa RESPIRATORIA → ventilación es PRIORITARIA.
  //   • Si hay pulso (como en este caso): SOLO ventilaciones de rescate
  //     (1 cada 5-6 seg = 10-12 rpm) SIN compresiones hasta que el pulso desaparezca.
  //   • Si no hay pulso: 5 ventilaciones iniciales → luego ciclos 30:2.
  //   • Los parámetros de compresión solo aplican cuando se confirma paro completo.
  //   AHA 2020 Part 5 + AHA Update 2024 Drowning.
  'ahogamiento': ScenarioDetailData(
    id: 'ahogamiento',
    titulo: 'Ahogamiento en piscina',
    subtitulo: 'Ventilaciones PRIMERO · Solo compresiones si hay paro completo',
    nombrePaciente: 'Andrés Pinto',
    edadDescripcion: '28 años',
    pesoKg: 74,
    descripcionClinica:
        'Hombre de 28 años, 74 kg. Rescatado del fondo de una piscina residencial. '
        'Sin respiración espontánea. PULSO CAROTÍDEO DÉBIL Y LENTO presente. '
        'El paro es de causa respiratoria, no cardíaca primaria.',
    situacion: '⚠️ HAY PULSO: NO inicies compresiones todavía.\n'
        'FASE 1 — SOLO VENTILACIONES (mientras haya pulso):\n'
        '  • Abre vía aérea con inclinación cabeza-mentón.\n'
        '  • Da 1 ventilación cada 5-6 segundos (10-12 rpm).\n'
        '  • Verifica pulso cada 2 minutos.\n\n'
        'FASE 2 — RCP COMPLETA (solo si el pulso desaparece):\n'
        '  • Da 5 ventilaciones de rescate iniciales.\n'
        '  • Luego ciclos 30:2 a 100-120 ppm, 5-6 cm de profundidad.\n\n'
        'ETA: 9 minutos.',
    profMinMm: 50,
    profMaxMm: 60,
    fuerzaMinKg: 30,
    fuerzaMaxKg: 60,
    frecMinPpm: 100,
    frecMaxPpm: 120,
    relacionVentilacion: '30:2',
    tecnica:
        'Solo ventilaciones si hay pulso · 5 iniciales + 30:2 si paro completo',
    color: AppColors.cyan,
    icono: Icons.water_outlined,
    audioFile: 'audio/caso_ahogamiento.mp3',
  ),

  // ── 4. Colapso durante ejercicio ──────────────────────────────────────────
  // ✅ Parámetros correctos. Se agrega nota de urgencia del DEA.
  // AHA 2020: cada minuto sin desfibrilación reduce supervivencia ~10%.
  'colapsoEjercicio': ScenarioDetailData(
    id: 'colapsoEjercicio',
    titulo: 'Colapso durante ejercicio',
    subtitulo: 'Fibrilación ventricular · DEA URGENTE (−10% supervivencia/min)',
    nombrePaciente: 'Julián Torres',
    edadDescripcion: '28 años',
    pesoKg: 78,
    descripcionClinica:
        'Atleta de 28 años, 78 kg. Colapso súbito mientras entrenaba en el gimnasio. '
        'Sin pulso ni respiración. Alta probabilidad de fibrilación ventricular. '
        '⚡ Cada minuto sin descarga reduce la supervivencia un 10%.',
    situacion: 'PASO 1 → Inicia RCP de inmediato (100-120 ppm, 5-6 cm, 30:2).\n'
        'PASO 2 → Envía a alguien por el DEA SIN interrumpir RCP.\n'
        'PASO 3 → En cuanto llegue el DEA: encuéndelo, coloca electrodos y '
        'sigue sus instrucciones. Minimiza la pausa pre-descarga a < 5 seg.\n'
        'PASO 4 → Reanuda RCP inmediatamente tras la descarga sin verificar pulso.\n'
        'ETA emergencias: según contexto.',
    profMinMm: 50,
    profMaxMm: 60,
    fuerzaMinKg: 30,
    fuerzaMaxKg: 60,
    frecMinPpm: 100,
    frecMaxPpm: 120,
    relacionVentilacion: '30:2',
    tecnica:
        'RCP inmediata + DEA lo antes posible · Pausa pre-descarga < 5 seg',
    color: AppColors.brand,
    icono: Icons.fitness_center_outlined,
    audioFile: 'audio/caso_colapsoEjercicio.mp3',
  ),

  // ── 5. Atragantamiento ────────────────────────────────────────────────────
  // ⚠️ CAMBIO CRÍTICO — AHA 2025 CPR/ECC Update:
  //   Nuevo protocolo OVACE adulto consciente:
  //   5 golpes en la espalda (interescapulares) + 5 empujes abdominales (Heimlich),
  //   alternando ciclos hasta expulsar objeto o pérdida de conocimiento.
  //   Antes (AHA 2020): solo empujes abdominales.
  //   Referencia: AHA 2025 Highlights CPR & ECC — FBAO Adult.
  'atragantamiento': ScenarioDetailData(
    id: 'atragantamiento',
    titulo: 'Atragantamiento severo',
    subtitulo: 'OVACE · 5 golpes espalda + 5 Heimlich (AHA 2025) → RCP',
    nombrePaciente: 'Carmen Vega',
    edadDescripcion: '48 años',
    pesoKg: 65,
    descripcionClinica:
        'Mujer de 48 años, 65 kg. Obstrucción completa de vía aérea durante '
        'una cena familiar. Intentos de toser inefectivos. Pierde el conocimiento.',
    situacion: 'MIENTRAS ESTÉ CONSCIENTE (AHA 2025):\n'
        '  1. Párate detrás de la víctima, inclínala hacia adelante.\n'
        '  2. Da 5 GOLPES FIRMES EN LA ESPALDA (entre los omóplatos) '
        'con el talón de la mano.\n'
        '  3. Luego 5 EMPUJES ABDOMINALES (maniobra de Heimlich): '
        'un puño sobre el ombligo, la otra mano encima, empuja hacia adentro y arriba.\n'
        '  4. Alterna ciclos de 5 golpes + 5 empujes hasta expulsar el objeto.\n\n'
        'SI PIERDE EL CONOCIMIENTO:\n'
        '  • Recuesta a la víctima en el suelo con cuidado.\n'
        '  • Inicia RCP 30:2 a 100-120 ppm.\n'
        '  • Antes de cada ventilación: INSPECCIONA la boca y retira el objeto '
        'solo si lo ves claramente (NO hacer barrido ciego).',
    profMinMm: 50,
    profMaxMm: 60,
    fuerzaMinKg: 30,
    fuerzaMaxKg: 60,
    frecMinPpm: 100,
    frecMaxPpm: 120,
    relacionVentilacion: '30:2',
    tecnica: '5 golpes espalda + 5 Heimlich (AHA 2025) → RCP si inconsciente',
    color: AppColors.amber,
    icono: Icons.medical_services_outlined,
    audioFile: 'audio/caso_atragantamiento.mp3',
  ),

  // ── 6. Descarga eléctrica ─────────────────────────────────────────────────
  // ✅ Parámetros correctos. Se agrega advertencia de arritmias tardías y DEA.
  // AHA 2020: electrocución puede causar FV tardía — tener DEA listo.
  'descargaElectrica': ScenarioDetailData(
    id: 'descargaElectrica',
    titulo: 'Descarga eléctrica',
    subtitulo: 'Seguridad de escena · RCP + DEA · Riesgo de arritmia tardía',
    nombrePaciente: 'Miguel Herrera',
    edadDescripcion: '38 años',
    pesoKg: 80,
    descripcionClinica:
        'Hombre de 38 años, 80 kg. Electrocutado en accidente laboral. '
        'Sin pulso ni respiración. Posibles quemaduras internas. '
        'La fuente eléctrica ya fue desconectada. '
        '⚡ Alto riesgo de fibrilación ventricular tardía — tener DEA disponible.',
    situacion:
        'PASO 1 → Confirma que la fuente eléctrica está APAGADA antes de tocar '
        'a la víctima (riesgo de electrocución al rescatador).\n'
        'PASO 2 → Inicia RCP de inmediato: dos manos, 100-120 ppm, 5-6 cm, 30:2.\n'
        'PASO 3 → Solicita un DEA: las víctimas de electrocución tienen alto riesgo '
        'de fibrilación ventricular diferida incluso si inicialmente responden.\n'
        'PASO 4 → Aplica el DEA tan pronto esté disponible y sigue sus instrucciones.\n'
        'ETA: 6 minutos.',
    profMinMm: 50,
    profMaxMm: 60,
    fuerzaMinKg: 30,
    fuerzaMaxKg: 60,
    frecMinPpm: 100,
    frecMaxPpm: 120,
    relacionVentilacion: '30:2',
    tecnica:
        'Dos manos · Verificar escena · Solicitar DEA por riesgo de FV tardía',
    color: Color(0xFFFFC107),
    icono: Icons.bolt_outlined,
    audioFile: 'audio/caso_descargaElectrica.mp3',
  ),

  // ── 7. Sobredosis por opioides ────────────────────────────────────────────
  // ⚠️ CAMBIO: este escenario tiene PULSO Y RESPIRACIÓN MUY LENTA.
  //   → Prioridad: NALOXONA + ventilaciones de soporte, NO compresiones.
  //   → Los parámetros de compresión solo aplican si evoluciona a PARO COMPLETO.
  //   AHA 2020 Part 10.3 + AHA 2023 Opioid Update.
  'sobredosis': ScenarioDetailData(
    id: 'sobredosis',
    titulo: 'Sobredosis por opioides',
    subtitulo: 'Naloxona PRIMERO · RCP solo si hay paro cardíaco completo',
    nombrePaciente: 'Laura Cifuentes',
    edadDescripcion: '32 años',
    pesoKg: 58,
    descripcionClinica:
        'Mujer de 32 años, 58 kg. Encontrada inconsciente con respiración muy lenta '
        '(2 rpm). Pupilas mióticas. Sospecha de sobredosis por opioides. '
        'TIENE PULSO — no está en paro cardíaco aún.',
    situacion:
        '⚠️ TIENE PULSO Y RESPIRA (muy lento) → NO inicies compresiones.\n\n'
        'FASE 1 — SOPORTE RESPIRATORIO + NALOXONA:\n'
        '  • Administra NALOXONA de inmediato si está disponible '
        '(intranasal 4 mg o IM 0.4 mg). Puede repetirse cada 2-3 min.\n'
        '  • Abre vía aérea y da ventilaciones de soporte: '
        '1 ventilación cada 5-6 segundos (10-12 rpm).\n'
        '  • Monitorea pulso y respiración continuamente.\n\n'
        'FASE 2 — Solo si evoluciona a PARO CARDÍACO COMPLETO (sin pulso):\n'
        '  • La naloxona NO debe retrasar ni interrumpir la RCP.\n'
        '  • Inicia RCP: 100-120 ppm, 5-6 cm, 30:2.\n'
        '  • RCP + DEA tienen PRIORIDAD ABSOLUTA sobre naloxona en paro cardíaco.',
    profMinMm: 50,
    profMaxMm: 60,
    fuerzaMinKg: 30,
    fuerzaMaxKg: 60,
    frecMinPpm: 100,
    frecMaxPpm: 120,
    relacionVentilacion: '30:2',
    tecnica:
        'Naloxona + ventilaciones (si hay pulso) · RCP solo si paro completo',
    color: AppColors.accent,
    icono: Icons.medication_outlined,
    audioFile: 'audio/caso_sobredosis.mp3',
  ),

  // ── 8. Infarto que evoluciona a paro ──────────────────────────────────────
  // ✅ Sin cambios — parámetros conformes AHA 2020.
  'infarto': ScenarioDetailData(
    id: 'infarto',
    titulo: 'Infarto que evoluciona a paro',
    subtitulo: 'Dolor torácico → Paro cardíaco súbito',
    nombrePaciente: 'Ernesto Campos',
    edadDescripcion: '60 años',
    pesoKg: 88,
    descripcionClinica:
        'Hombre de 60 años, 88 kg. Refería dolor torácico opresivo hace 20 minutos. '
        'Súbitamente pierde el conocimiento, sin pulso ni respiración. '
        'Antecedente de hipertensión arterial.',
    situacion:
        'El paciente estaba consciente y ahora evoluciona a paro presenciado. '
        'Inicia RCP DE INMEDIATO — no esperes confirmación de ritmo. '
        'Alerta al sistema de emergencias si no lo has hecho. '
        'Solicita un DEA: los paros por infarto pueden presentar FV tratable.',
    profMinMm: 50,
    profMaxMm: 60,
    fuerzaMinKg: 30,
    fuerzaMaxKg: 60,
    frecMinPpm: 100,
    frecMaxPpm: 120,
    relacionVentilacion: '30:2',
    tecnica: 'Dos manos sobre el esternón · Solicitar DEA',
    // ✅ Sin cambios en parámetros — descripción mejorada
    color: AppColors.red,
    icono: Icons.monitor_heart_outlined,
    audioFile: 'audio/caso_infarto.mp3',
  ),

  // ── Alias legado ───────────────────────────────────────────────────────────
  'adulto': ScenarioDetailData(
    id: 'adulto',
    titulo: 'Adulto',
    subtitulo: 'RCP estándar · Guías AHA 2020',
    nombrePaciente: 'Carlos Mendoza',
    edadDescripcion: '45 años',
    pesoKg: 78,
    descripcionClinica:
        'Hombre de 45 años, 78 kg. Encontrado inconsciente en la sala '
        'de su casa por un familiar. No respira y no tiene pulso. '
        'No presenta trauma visible. Sin antecedentes conocidos.',
    situacion: 'Estás en el lugar del incidente. El servicio de emergencias '
        'está en camino (ETA 8 minutos). Debes iniciar RCP de inmediato.',
    profMinMm: 50,
    profMaxMm: 60,
    fuerzaMinKg: 30,
    fuerzaMaxKg: 60,
    frecMinPpm: 100,
    frecMaxPpm: 120,
    relacionVentilacion: '30:2',
    tecnica: 'Dos manos sobre el esternón',
    // ✅ Sin cambios
    color: AppColors.red,
    icono: Icons.monitor_heart_outlined,
    audioFile: 'audio/caso_adulto.mp3',
  ),
};

// ─── Pantalla principal ───────────────────────────────────────────────────────
class ScenarioDetailScreen extends ConsumerStatefulWidget {
  final String scenarioId;
  const ScenarioDetailScreen({super.key, required this.scenarioId});

  @override
  ConsumerState<ScenarioDetailScreen> createState() =>
      _ScenarioDetailScreenState();
}

class _ScenarioDetailScreenState extends ConsumerState<ScenarioDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scenario = kScenarios[widget.scenarioId];
    if (scenario == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/session?scenario=${widget.scenarioId}');
      });
      return const Scaffold(
        body: const AppLogoLoader(),
      );
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textT = theme.textTheme.bodySmall?.color ?? AppColors.textTertiary;
    final color = scenario.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                _Header(scenario: scenario, isDark: isDark),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _PatientCard(
                          scenario: scenario,
                          isDark: isDark,
                          textP: textP,
                          textS: textS,
                          textT: textT,
                          color: color,
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          icon: Icons.description_outlined,
                          label: 'Caso clínico',
                          color: color,
                          isDark: isDark,
                          textP: textP,
                          textS: textS,
                          child: Text(
                            scenario.descripcionClinica,
                            style: TextStyle(
                              color: textS,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SectionCard(
                          icon: Icons.warning_amber_rounded,
                          label: 'Tu situación',
                          color: AppColors.amber,
                          isDark: isDark,
                          textP: textP,
                          textS: textS,
                          child: Text(
                            scenario.situacion,
                            style: TextStyle(
                              color: textS,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ProtocolCard(
                          scenario: scenario,
                          isDark: isDark,
                          textP: textP,
                          textS: textS,
                          textT: textT,
                          color: color,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _BottomAction(
        scenario: scenario,
        color: color,
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final ScenarioDetailData scenario;
  final bool isDark;
  const _Header({required this.scenario, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/scenarios');
              }
            },
            color: textP,
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scenario.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(scenario.icono, color: scenario.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scenario.titulo,
                  style: TextStyle(
                    color: textP,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  scenario.subtitulo,
                  style: TextStyle(color: textS, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tarjeta del paciente ─────────────────────────────────────────────────────
class _PatientCard extends StatelessWidget {
  final ScenarioDetailData scenario;
  final bool isDark;
  final Color textP, textS, textT, color;

  const _PatientCard({
    required this.scenario,
    required this.isDark,
    required this.textP,
    required this.textS,
    required this.textT,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.1 : 0.06),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.25 : 0.18),
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_outline_rounded, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'PACIENTE',
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  scenario.nombrePaciente,
                  style: TextStyle(
                    color: textP,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.cake_outlined,
                      label: scenario.edadDescripcion,
                      textS: textS,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.monitor_weight_outlined,
                      label: '${scenario.pesoKg} kg',
                      textS: textS,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textS;
  const _InfoChip(
      {required this.icon, required this.label, required this.textS});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 12, color: textS),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: textS, fontSize: 11)),
        ],
      );
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final Color textP, textS;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.textP,
    required this.textS,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ProtocolCard extends StatelessWidget {
  final ScenarioDetailData scenario;
  final bool isDark;
  final Color textP, textS, textT, color;

  const _ProtocolCard({
    required this.scenario,
    required this.isDark,
    required this.textP,
    required this.textS,
    required this.textT,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rule_outlined, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                'PROTOCOLO AHA 2020',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ParamTile(
                  icon: Icons.straighten_outlined,
                  label: 'Profundidad',
                  value:
                      '${scenario.profMinMm.toInt()}–${scenario.profMaxMm.toInt()} mm',
                  color: color,
                  textP: textP,
                  textT: textT,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ParamTile(
                  icon: Icons.speed_outlined,
                  label: 'Frecuencia',
                  value: '${scenario.frecMinPpm}–${scenario.frecMaxPpm} ppm',
                  color: color,
                  textP: textP,
                  textT: textT,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ParamTile(
                  icon: Icons.compress_outlined,
                  label: 'Ventilación',
                  value: scenario.relacionVentilacion,
                  color: color,
                  textP: textP,
                  textT: textT,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ParamTile(
                  icon: Icons.back_hand_outlined,
                  label: 'Técnica',
                  value: scenario.tecnica,
                  color: color,
                  textP: textP,
                  textT: textT,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParamTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color, textP, textT;

  const _ParamTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.textP,
    required this.textT,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(color: textT, fontSize: 9, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: textP, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Bottom CTA ───────────────────────────────────────────────────────────────
class _BottomAction extends ConsumerStatefulWidget {
  final ScenarioDetailData scenario;
  final Color color;
  const _BottomAction({required this.scenario, required this.color});

  @override
  ConsumerState<_BottomAction> createState() => _BottomActionState();
}

class _BottomActionState extends ConsumerState<_BottomAction> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
      ),
    );
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _player.stop();
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // ✅ Bug 3 — el estado lo maneja onPlayerStateChanged automáticamente
      await _player.play(AssetSource(widget.scenario.audioFile));
    } catch (e) {
      debugPrint('❌ Audio error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo reproducir el audio: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, isLandscape ? 12 : 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
      ),
      child: isLandscape
          ? Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _isLoading ? null : _toggleAudio,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLoading)
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: color,
                              ),
                            )
                          else
                            Icon(
                              _isPlaying
                                  ? Icons.stop_circle_outlined
                                  : Icons.volume_up_rounded,
                              color: color,
                              size: 16,
                            ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _isPlaying ? 'Detener' : 'Escuchar caso',
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (ConnectionGuard.checkConnection(context, ref)) {
                          _player.stop();
                          context.go(
                              '/scenario-guide?scenario=${widget.scenario.id}');
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text(
                        'Iniciar simulación',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _isLoading ? null : _toggleAudio,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      border: Border.all(
                        color: color.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isLoading)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          )
                        else
                          Icon(
                            _isPlaying
                                ? Icons.stop_circle_outlined
                                : Icons.volume_up_rounded,
                            color: color,
                            size: 18,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _isPlaying
                              ? 'Detener audio'
                              : 'Escuchar caso clínico',
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (ConnectionGuard.checkConnection(context, ref)) {
                        _player.stop();
                        context.go('/session?scenario=${widget.scenario.id}');
                      }
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text(
                      'Iniciar simulación',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
