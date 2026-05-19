import 'package:flutter/material.dart';
import 'package:siercp/core/theme/theme.dart';

// ─── Modelo de evaluación práctica ───────────────────────────────────────────
class _EvalScenario {
  final String id;
  final String title;
  final String subtitle;
  final String caseText;
  final Color color;
  final IconData icon;
  final String difficulty;
  final List<_EvalQuestion> questions;

  const _EvalScenario({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.caseText,
    required this.color,
    required this.icon,
    required this.difficulty,
    required this.questions,
  });
}

class _EvalQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const _EvalQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

// ─── 10 Evaluaciones prácticas ────────────────────────────────────────────────
const List<_EvalScenario> kPracticalEvals = [
  // 1. RCP Adulto estándar
  _EvalScenario(
    id: 'eval_adulto_rcp',
    title: 'RCP Adulto Estándar',
    subtitle: 'Protocolo BLS adulto · AHA 2020',
    caseText:
        'Hombre de 55 años colapsa en la vía pública. Sin respuesta, sin pulso, sin respiración. Testigo avisa y tú llegas primero.',
    color: AppColors.red,
    icon: Icons.monitor_heart_outlined,
    difficulty: 'Básico',
    questions: [
      _EvalQuestion(
        question: '¿Cuál es el primer paso tras confirmar que no responde?',
        options: [
          'Iniciar compresiones torácicas inmediatamente',
          'Activar el sistema de emergencias (llamar al 123)',
          'Colocar al paciente en posición de recuperación',
          'Intentar ventilación boca a boca primero',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020: Activar el sistema de emergencias y pedir un DEA es el primer paso. Luego, iniciar RCP de alta calidad.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la frecuencia correcta de compresiones?',
        options: [
          '60–80 compresiones por minuto',
          '80–100 compresiones por minuto',
          '100–120 compresiones por minuto',
          'Más de 120 compresiones por minuto',
        ],
        correctIndex: 2,
        explanation:
            'AHA 2020: La frecuencia óptima es 100–120 cpm. Por debajo hay menos flujo coronario; por encima se reduce el llenado cardíaco.',
      ),
      _EvalQuestion(
        question: '¿Cuánto debe medir la profundidad de compresión en adultos?',
        options: [
          '2–3 cm (1 pulgada)',
          '4–5 cm (1.5–2 pulgadas)',
          '5–6 cm (2–2.4 pulgadas)',
          'Más de 6 cm',
        ],
        correctIndex: 2,
        explanation:
            'AHA 2020: La profundidad correcta es 5–6 cm. Menos es inefectiva; más puede causar fracturas costales.',
      ),
      _EvalQuestion(
        question: '¿Qué es el recoil completo y por qué es importante?',
        options: [
          'La velocidad a la que comprimes el tórax',
          'Permitir que el tórax se expanda totalmente entre compresiones',
          'La fuerza máxima aplicada en cada compresión',
          'La relación entre compresiones y ventilaciones',
        ],
        correctIndex: 1,
        explanation:
            'El recoil completo permite el llenado cardíaco venoso entre compresiones. Apoyarse en el tórax reduce el retorno venoso y disminuye el gasto cardíaco hasta un 50%.',
      ),
    ],
  ),

  // 2. RCP Pediátrico
  _EvalScenario(
    id: 'eval_pediatrico',
    title: 'RCP Pediátrico (1–8 años)',
    subtitle: 'BLS pediátrico · Diferencias clave vs adulto',
    caseText:
        'Niño de 4 años encontrado inconsciente en el jardín. Sin respuesta, sin pulso, sin respiración. Estás solo con el niño.',
    color: AppColors.accent,
    icon: Icons.child_care_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            'En RCP pediátrico con un rescatador único, ¿cuál es la relación compresión:ventilación?',
        options: [
          '15:2',
          '30:2',
          '30:1',
          '15:1',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020: Con un solo rescatador, la relación es 30:2 igual que en adultos. Con dos rescatadores entrenados en pediatría, se usa 15:2.',
      ),
      _EvalQuestion(
        question: '¿Con cuántas manos se realizan las compresiones en niños (1–8 años)?',
        options: [
          'Siempre con dos manos',
          'Siempre con una mano',
          'Una o dos manos según el tamaño del niño',
          'Con dos dedos únicamente',
        ],
        correctIndex: 2,
        explanation:
            'En niños, se adapta según el tamaño: una mano para niños pequeños, dos manos para niños más grandes. La profundidad objetivo es 5 cm (aprox. 1/3 del diámetro anteroposterior).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la profundidad de compresión en niños (1–8 años)?',
        options: [
          '3–4 cm',
          'Aproximadamente 5 cm (1/3 del diámetro del tórax)',
          '5–6 cm',
          '1–2 cm',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020: En niños se comprimen aproximadamente 5 cm, equivalente a 1/3 del diámetro anteroposterior del tórax.',
      ),
      _EvalQuestion(
        question: 'Estás solo con un niño en paro. ¿Qué debes hacer primero?',
        options: [
          'Ir a buscar un DEA antes de iniciar RCP',
          'Llamar al 123 y luego empezar RCP',
          'Hacer 2 minutos de RCP antes de llamar al 123',
          'Gritar pidiendo ayuda e iniciar RCP inmediatamente; llamar después de 2 min',
        ],
        correctIndex: 3,
        explanation:
            'AHA 2020: Si estás solo con un niño, inicia RCP inmediatamente (el paro pediátrico suele ser de causa respiratoria). Llama al 123 tras 2 minutos o activa el altavoz mientras realizas RCP.',
      ),
    ],
  ),

  // 3. Lactante (< 1 año)
  _EvalScenario(
    id: 'eval_lactante',
    title: 'RCP Lactante (<1 año)',
    subtitle: 'Técnica de dos dedos · Protocolo infantil',
    caseText:
        'Bebé de 6 meses encontrado sin respuesta en su cuna. Sin respiración espontánea. No hay pulso braquial palpable.',
    color: const Color(0xFFFF6B9D),
    icon: Icons.baby_changing_station_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question: '¿Dónde se palpa el pulso en un lactante?',
        options: [
          'Arteria carótida (cuello)',
          'Arteria radial (muñeca)',
          'Arteria braquial (cara interna del brazo)',
          'Arteria femoral (ingle)',
        ],
        correctIndex: 2,
        explanation:
            'En lactantes, el cuello es corto y dificulta la palpación carotídea. La arteria braquial (cara interna del brazo) es la referencia estándar AHA.',
      ),
      _EvalQuestion(
        question: '¿Qué técnica se usa para comprimir el tórax de un lactante con un rescatador?',
        options: [
          'Dos manos con los pulgares superpuestos',
          'Dos dedos (índice y medio) sobre el esternón',
          'Una sola mano completa',
          'Palma de la mano',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020: Con un solo rescatador se usan dos dedos (índice y medio) justo por debajo de la línea intermamilar. Con dos rescatadores se prefiere la técnica de dos pulgares con las manos rodeando el tórax.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la profundidad correcta de compresión en lactantes?',
        options: [
          '2–3 cm (aprox. 4 cm o 1/3 del diámetro del tórax)',
          '5–6 cm',
          '1 cm',
          '4–5 cm',
        ],
        correctIndex: 0,
        explanation:
            'AHA 2020: En lactantes la profundidad es aproximadamente 4 cm, equivalente a 1/3 del diámetro anteroposterior del tórax.',
      ),
      _EvalQuestion(
        question: '¿Cómo se realizan las ventilaciones en un lactante?',
        options: [
          'Solo boca a boca como en adultos',
          'Boca a boca-nariz cubriendo boca Y nariz simultáneamente',
          'Solo insuflando por la nariz',
          'Con mascarilla de adulto',
        ],
        correctIndex: 1,
        explanation:
            'En lactantes, la boca del rescatador cubre boca Y nariz del bebé simultáneamente (técnica boca a boca-nariz). Se insufla suavemente el volumen suficiente para ver elevación del tórax.',
      ),
    ],
  ),

  // 4. Ahogamiento
  _EvalScenario(
    id: 'eval_ahogamiento',
    title: 'Ahogamiento con Pulso',
    subtitle: 'Ventilaciones prioritarias · AHA 2020',
    caseText:
        'Hombre de 30 años rescatado de una piscina. Inconsciente. Sin respiración. TIENE pulso carotídeo débil pero presente.',
    color: AppColors.cyan,
    icon: Icons.water_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question: '¿Por qué el paro en ahogamiento es diferente al paro cardíaco súbito?',
        options: [
          'No hay diferencia; se tratan igual',
          'El paro es de causa RESPIRATORIA, no cardíaca primaria',
          'Solo afecta a niños',
          'No se puede hacer RCP en víctimas de ahogamiento',
        ],
        correctIndex: 1,
        explanation:
            'El ahogamiento produce hipoxia antes que el paro cardíaco. La causa primaria es respiratoria, por lo que la ventilación es la intervención más crítica.',
      ),
      _EvalQuestion(
        question: 'El paciente tiene pulso débil pero no respira. ¿Qué debes hacer?',
        options: [
          'Iniciar compresiones torácicas de inmediato',
          'Dar solo ventilaciones de rescate (1 cada 5–6 seg) sin compresiones',
          'Esperar a que recupere el pulso',
          'Solo observar y no intervenir',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020: Si hay pulso pero no hay respiración, dar ventilaciones de rescate (1 cada 5–6 segundos = 10–12 rpm). Verificar pulso cada 2 minutos. NO comprimir mientras haya pulso.',
      ),
      _EvalQuestion(
        question: '¿Cuántas ventilaciones de rescate iniciales se dan si el paciente evoluciona a paro completo (sin pulso)?',
        options: [
          'Ninguna; ir directo a 30 compresiones',
          '2 ventilaciones iniciales',
          '5 ventilaciones de rescate iniciales, luego ciclos 30:2',
          '10 ventilaciones antes de comprimir',
        ],
        correctIndex: 2,
        explanation:
            'AHA 2020 (Drowning): Si el paciente evoluciona a paro completo, dar 5 ventilaciones de rescate iniciales para tratar la hipoxia, luego ciclos estándar 30:2.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el riesgo de aplicar compresiones torácicas cuando hay pulso en ahogamiento?',
        options: [
          'No hay riesgo adicional',
          'Puede inducir fibrilación ventricular en un corazón que late',
          'Solo se desperdicia tiempo',
          'Puede mejorar la ventilación',
        ],
        correctIndex: 1,
        explanation:
            'Aplicar compresiones en un corazón que aún late puede desencadenar arritmias incluyendo fibrilación ventricular. Por eso se deben dar solo ventilaciones mientras haya pulso.',
      ),
    ],
  ),

  // 5. Atragantamiento adulto consciente (AHA 2025)
  _EvalScenario(
    id: 'eval_ovace_adulto',
    title: 'OVACE Adulto Consciente',
    subtitle: 'Nuevo protocolo AHA 2025 · 5+5',
    caseText:
        'Mujer de 45 años en un restaurante. Se lleva las manos al cuello, no puede hablar ni toser eficazmente. Obstrucción completa de vía aérea.',
    color: AppColors.amber,
    icon: Icons.medical_services_outlined,
    difficulty: 'Básico',
    questions: [
      _EvalQuestion(
        question: '¿Qué cambio introdujo AHA 2025 para OVACE en adultos conscientes?',
        options: [
          'Solo empujes abdominales (Heimlich)',
          'Solo golpes en la espalda',
          '5 golpes en la espalda + 5 empujes abdominales alternados',
          'No hay cambios respecto a 2020',
        ],
        correctIndex: 2,
        explanation:
            'AHA 2025 CPR/ECC Update: El nuevo protocolo alterna 5 golpes interescapulares con el talón de la mano + 5 empujes abdominales (Heimlich), en ciclos hasta expulsar el objeto. Antes (2020) solo se usaban empujes abdominales.',
      ),
      _EvalQuestion(
        question: '¿Cómo se posiciona a la víctima para los golpes en la espalda?',
        options: [
          'De pie, erguida y con la cabeza hacia atrás',
          'De pie, inclinada hacia adelante, con la cabeza por debajo del tórax',
          'Acostada en el suelo',
          'Sentada sin modificar la posición',
        ],
        correctIndex: 1,
        explanation:
            'La víctima debe estar inclinada hacia adelante (cabeza más baja que el tórax) para que la gravedad ayude a expulsar el objeto. Párate detrás y da 5 golpes firmes entre los omóplatos con el talón de la mano.',
      ),
      _EvalQuestion(
        question: 'La víctima pierde el conocimiento durante las maniobras. ¿Qué debes hacer?',
        options: [
          'Continuar con los golpes en la espalda estando en el suelo',
          'Recostarlo con cuidado, iniciar RCP 30:2 e inspeccionar la boca antes de cada ventilación',
          'Hacer solo empujes abdominales en el suelo',
          'Esperar a que recupere la conciencia',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2025: Si pierde el conocimiento, recuesta a la víctima con cuidado. Inicia RCP 30:2. Antes de cada ventilación, abre la boca e inspecciona visualmente. Retira el objeto solo si lo ves claramente (NUNCA barrido ciego).',
      ),
      _EvalQuestion(
        question: 'En un paciente obeso o embarazada, ¿qué reemplaza a los empujes abdominales?',
        options: [
          'Más golpes en la espalda',
          'Empujes torácicos (sobre el esternón) en lugar de abdominales',
          'Compresiones torácicas de RCP directamente',
          'No se puede intervenir',
        ],
        correctIndex: 1,
        explanation:
            'En pacientes obesos o embarazadas, los empujes abdominales no son efectivos ni seguros. Se reemplazan por empujes torácicos: manos sobre el esternón (igual que RCP), empujando hacia atrás.',
      ),
    ],
  ),

  // 6. DEA y fibrilación ventricular
  _EvalScenario(
    id: 'eval_dea_fv',
    title: 'Desfibrilación con DEA',
    subtitle: 'Colapso súbito + FV · Uso del DEA',
    caseText:
        'Joven de 25 años colapsa en el gimnasio. Sin pulso ni respiración. Alta probabilidad de fibrilación ventricular. Hay un DEA disponible en el local.',
    color: AppColors.brand,
    icon: Icons.bolt_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question: '¿Cuánto reduce la supervivencia cada minuto sin desfibrilación en FV?',
        options: [
          '1–2% por minuto',
          '5% por minuto',
          '7–10% por minuto',
          'No importa el tiempo',
        ],
        correctIndex: 2,
        explanation:
            'AHA 2020: En fibrilación ventricular, cada minuto sin desfibrilación reduce la supervivencia entre 7–10%. El DEA más rápido = mayor probabilidad de sobrevivir.',
      ),
      _EvalQuestion(
        question: '¿Cuándo se detienen las compresiones para el análisis del DEA?',
        options: [
          'Solo cuando el DEA lo indique',
          'Cada 2 minutos independientemente del DEA',
          'Nunca; el DEA analiza mientras se comprimen',
          'Tras el primer choque',
        ],
        correctIndex: 0,
        explanation:
            'Se detienen las compresiones SOLO cuando el DEA indica "Analizando". Minimiza siempre la pausa pre-descarga a menos de 5 segundos entre la última compresión y el choque.',
      ),
      _EvalQuestion(
        question: 'Tras la descarga del DEA, ¿qué debes hacer inmediatamente?',
        options: [
          'Verificar el pulso durante 10 segundos',
          'Esperar 2 minutos antes de tocar al paciente',
          'Reanudar RCP inmediatamente comenzando por compresiones, sin verificar pulso',
          'Revisar el ritmo en el monitor',
        ],
        correctIndex: 2,
        explanation:
            'AHA 2020: Tras la descarga, reinicia compresiones de inmediato. No verifiques el pulso. Continúa 2 minutos y permite al DEA analizar de nuevo. La verificación de pulso interrumpe el flujo coronario.',
      ),
      _EvalQuestion(
        question: '¿Dónde se colocan los electrodos del DEA en un adulto?',
        options: [
          'Ambos en el lado izquierdo del tórax',
          'Uno en la clavícula derecha y otro en el costado inferior izquierdo (posición anterolateral)',
          'Ambos en el centro del pecho',
          'Uno en el pecho y otro en la espalda siempre',
        ],
        correctIndex: 1,
        explanation:
            'Posición estándar anterolateral: un electrodo debajo de la clavícula derecha (esternón) y el otro en el costado izquierdo debajo de la axila. Sigue siempre las ilustraciones del DEA.',
      ),
    ],
  ),

  // 7. Descarga eléctrica
  _EvalScenario(
    id: 'eval_electrocucion',
    title: 'Electrocución',
    subtitle: 'Seguridad de escena · Riesgo de FV tardía',
    caseText:
        'Electricista de 40 años electrocutado en una obra. Inconsciente, sin pulso ni respiración. El interruptor principal fue desconectado.',
    color: const Color(0xFFFFC107),
    icon: Icons.electrical_services_outlined,
    difficulty: 'Básico',
    questions: [
      _EvalQuestion(
        question: '¿Cuál es el primer paso ANTES de tocar a la víctima de electrocución?',
        options: [
          'Iniciar RCP de inmediato',
          'Verificar que la fuente eléctrica esté completamente desconectada',
          'Llamar al 123',
          'Aplicar el DEA',
        ],
        correctIndex: 1,
        explanation:
            'Seguridad de escena primero. Si la fuente eléctrica no está desconectada, el rescatador puede electrocutarse también. Confirma que el corte es total antes de tocar a la víctima.',
      ),
      _EvalQuestion(
        question: '¿Por qué se debe mantener el DEA listo en víctimas de electrocución incluso si inicialmente responden?',
        options: [
          'Solo por protocolo, no hay riesgo real',
          'Las quemaduras internas pueden causar dolor tardío',
          'Las lesiones eléctricas pueden causar fibrilación ventricular tardía',
          'El DEA solo sirve para evaluar quemaduras',
        ],
        correctIndex: 2,
        explanation:
            'AHA 2020: Las corrientes eléctricas de alta tensión pueden provocar arritmias cardíacas (incluida la FV) con retraso, incluso en pacientes que inicialmente están conscientes. El DEA debe estar disponible durante toda la atención.',
      ),
      _EvalQuestion(
        question: '¿Qué característica especial tienen las quemaduras por electrocución?',
        options: [
          'Solo hay quemaduras visibles en la superficie',
          'Suelen tener lesiones internas mucho más graves que las externas visibles',
          'Son siempre superficiales',
          'No causan daño orgánico interno',
        ],
        correctIndex: 1,
        explanation:
            'La corriente eléctrica viaja por el cuerpo siguiendo los tejidos de menor resistencia (nervios, vasos). El daño interno (muscular, cardiaco, renal) suele ser mucho mayor que las quemaduras de entrada/salida visibles.',
      ),
      _EvalQuestion(
        question: 'La víctima recupera el pulso después de RCP. ¿Cuándo puedes cesar la vigilancia?',
        options: [
          'Inmediatamente al recuperar el pulso',
          'Tras 5 minutos de pulso estable',
          'Solo cuando el equipo médico avanzado asuma el control',
          'Tras 30 minutos de observación',
        ],
        correctIndex: 2,
        explanation:
            'La vigilancia no termina hasta que llegue el equipo de emergencias avanzado. El riesgo de fibrilación ventricular tardía persiste. Continúa monitorizando signos vitales y mantén el DEA preparado.',
      ),
    ],
  ),

  // 8. Sobredosis opioides
  _EvalScenario(
    id: 'eval_sobredosis',
    title: 'Sobredosis por Opioides',
    subtitle: 'Naloxona + RCP · Protocolo AHA 2023',
    caseText:
        'Mujer de 28 años encontrada inconsciente. Respiración muy lenta (2 rpm), pupilas mióticas. TIENE pulso débil. Sospecha de sobredosis de opioides.',
    color: AppColors.accent,
    icon: Icons.medication_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question: 'La paciente tiene pulso. ¿Cuál es la intervención prioritaria?',
        options: [
          'Iniciar compresiones torácicas inmediatamente',
          'Administrar naloxona y dar ventilaciones de soporte',
          'Solo observar y esperar',
          'Colocarla en posición de recuperación y esperar',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2023 Opioid Update: Si hay pulso, la prioridad es la naloxona + ventilaciones de soporte. Las compresiones solo se inician si desaparece el pulso. La naloxona revierte la depresión respiratoria por opioides.',
      ),
      _EvalQuestion(
        question: '¿La naloxona debe retrasar o interrumpir la RCP si el paciente evoluciona a paro?',
        options: [
          'Sí, administrar naloxona antes de comprimir',
          'No, RCP y DEA tienen PRIORIDAD ABSOLUTA sobre la naloxona en paro cardíaco',
          'Depende de la dosis de opioide',
          'La naloxona y la RCP no se pueden dar simultáneamente',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2023: Si el paciente evoluciona a paro cardíaco completo, RCP y DEA tienen prioridad absoluta. La naloxona NO debe retrasar ni interrumpir las compresiones. Puede administrarse en paralelo si hay otro rescatador.',
      ),
      _EvalQuestion(
        question: '¿Cada cuánto tiempo se puede repetir la dosis de naloxona intranasal?',
        options: [
          'Cada 30 segundos',
          'Cada 2–3 minutos según respuesta',
          'Solo una dosis única',
          'Cada 10 minutos',
        ],
        correctIndex: 1,
        explanation:
            'La naloxona intranasal (4 mg) puede repetirse cada 2–3 minutos si no hay respuesta. La vida media de muchos opioides supera la de la naloxona, por lo que pueden necesitarse múltiples dosis.',
      ),
      _EvalQuestion(
        question: '¿Por qué es crítico monitorizar a la paciente incluso después de que responda a la naloxona?',
        options: [
          'No es necesario si ya responde',
          'Porque la naloxona tiene una vida media más corta que muchos opioides; puede recurrir la depresión',
          'Solo por protocolo administrativo',
          'Para documentar la intervención',
        ],
        correctIndex: 1,
        explanation:
            'La naloxona tiene una vida media de 30–90 min, mucho menor que fentanilo, metadona u otros opioides. La sedación puede recurrir cuando la naloxona se metaboliza. Monitorización continua es esencial.',
      ),
    ],
  ),

  // 9. RCP en 2 rescatadores
  _EvalScenario(
    id: 'eval_dos_rescatadores',
    title: 'RCP con Dos Rescatadores',
    subtitle: 'Coordinación y relevos · Calidad sostenida',
    caseText:
        'Colega y tú responden a una emergencia. Mujer de 60 años, paro cardíaco confirmado. Tienen que organizarse para dar RCP de alta calidad.',
    color: const Color(0xFF059669),
    icon: Icons.people_alt_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question: '¿Cada cuánto tiempo deben cambiarse los roles entre los dos rescatadores?',
        options: [
          'Cada 5 minutos',
          'Cada 2 minutos (o antes si el compresor se fatiga)',
          'Cada 10 minutos',
          'No es necesario cambiar roles',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020: Los rescatadores deben alternarse cada 2 minutos para mantener la calidad de las compresiones. La fatiga reduce la profundidad y la frecuencia en menos de 2 minutos de RCP sostenida.',
      ),
      _EvalQuestion(
        question: '¿Cuándo debe ocurrir el cambio de rol durante la RCP con dos rescatadores?',
        options: [
          'En cualquier momento, pausando las compresiones',
          'Solo cuando llegue el DEA',
          'Al finalizar el ciclo de 30 compresiones, antes de las 2 ventilaciones',
          'Solo si el rescatador lo pide expresamente',
        ],
        correctIndex: 2,
        explanation:
            'El cambio debe hacerse de forma coordinada al finalizar las 30 compresiones, antes de dar las 2 ventilaciones. Esto minimiza la interrupción del flujo y mantiene el ritmo del ciclo.',
      ),
      _EvalQuestion(
        question: 'Con dos rescatadores entrenados en pediatría y un niño en paro, ¿qué relación se usa?',
        options: [
          '30:2 igual que en adultos',
          '15:2',
          '10:2',
          '20:2',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020: Con dos rescatadores entrenados en pediatría, la relación es 15:2 para maximizar las ventilaciones (el paro pediátrico es predominantemente de causa respiratoria).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la máxima interrupción permitida en las compresiones durante RCP?',
        options: [
          'Menos de 5 segundos',
          'Menos de 10 segundos',
          'Menos de 15 segundos',
          'No hay límite establecido',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020: Las pausas en las compresiones deben ser menores a 10 segundos. La fracción de compresión torácica (CCF) debe ser ≥ 60% del tiempo total de RCP.',
      ),
    ],
  ),

  // 10. Infarto con evolución a paro
  _EvalScenario(
    id: 'eval_infarto_paro',
    title: 'Infarto → Paro Cardíaco',
    subtitle: 'Reconocimiento STEMI · Respuesta inmediata',
    caseText:
        'Hombre de 62 años con 30 minutos de dolor torácico opresivo, irradiado al brazo izquierdo. De repente pierde el conocimiento: sin pulso ni respiración.',
    color: AppColors.red,
    icon: Icons.favorite_border_rounded,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question: 'El paciente estaba consciente y colapsó frente a ti. ¿Cuál es tu primera acción?',
        options: [
          'Esperar 1 minuto para confirmar el paro',
          'Iniciar RCP de inmediato sin perder tiempo',
          'Administrar aspirina primero',
          'Colocarlo en posición lateral',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020: Paro presenciado = iniciar RCP de inmediato. Cada segundo cuenta. El dolor torácico previo hace alta la probabilidad de FV, que responde muy bien a la RCP precoz + DEA rápido.',
      ),
      _EvalQuestion(
        question: '¿Por qué se pide el DEA urgentemente en este caso?',
        options: [
          'El DEA siempre se pide en cualquier emergencia',
          'Los paros post-infarto frecuentemente presentan FV, que es tratable con desfibrilación',
          'El DEA ayuda a dar ventilaciones',
          'Para confirmar que el paciente está en paro',
        ],
        correctIndex: 1,
        explanation:
            'El infarto agudo con evolución a paro frecuentemente presenta fibrilación ventricular (FV), un ritmo desfibrilable. Cada minuto sin descarga reduce la supervivencia ~10%. El DEA precoz es crucial.',
      ),
      _EvalQuestion(
        question: 'El paciente tenía síntomas 30 minutos antes del paro. ¿Afecta esto el protocolo de RCP?',
        options: [
          'Sí, no se hace RCP si llevan más de 10 minutos',
          'No, se sigue el protocolo estándar de BLS independientemente del tiempo de inicio de síntomas',
          'Solo se dan ventilaciones, no compresiones',
          'Se reduce la frecuencia de compresiones',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020: El protocolo BLS no cambia por el tiempo de inicio de síntomas. Se aplica RCP estándar de alta calidad + DEA. La decisión de continuar o cesar la reanimación avanzada es del equipo médico.',
      ),
      _EvalQuestion(
        question: 'Tras 2 minutos de RCP el paciente recupera pulso. ¿Cuál es el siguiente paso?',
        options: [
          'Dar 30 compresiones más por si acaso',
          'Colocarlo en posición de recuperación y monitorizar mientras llega el equipo avanzado',
          'Dejarlo en el suelo sin moverse',
          'Administrar agua para la hidratación',
        ],
        correctIndex: 1,
        explanation:
            'Al recuperar el pulso (ROSC), coloca al paciente en posición lateral de seguridad (si no hay trauma cervical), monitoriza respiración y pulso constantemente, y mantén el DEA listo hasta que llegue el equipo médico avanzado.',
      ),
    ],
  ),
];

// ─── Pantalla de lista ────────────────────────────────────────────────────────
class PracticalEvaluationsScreen extends StatelessWidget {
  const PracticalEvaluationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon:
                        Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textP),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evaluaciones Prácticas',
                          style: TextStyle(
                            color: textP,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '10 casos clínicos · Decisiones de protocolo',
                          style: TextStyle(color: textS, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      '${kPracticalEvals.length} casos',
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── AHA info strip ────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: isDark ? 0.12 : 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.brand.withValues(alpha: isDark ? 0.3 : 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined,
                      color: AppColors.brand, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Basadas en Guías AHA 2020/2025. Cada caso evalúa decisiones clínicas clave.',
                      style: TextStyle(
                        color: isDark ? AppColors.accent : AppColors.brand,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // ── List ──────────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: kPracticalEvals.length,
                itemBuilder: (ctx, i) {
                  final eval = kPracticalEvals[i];
                  return _EvalCard(
                    eval: eval,
                    index: i,
                    isDark: isDark,
                    textP: textP,
                    textS: textS,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Eval card ────────────────────────────────────────────────────────────────
class _EvalCard extends StatelessWidget {
  final _EvalScenario eval;
  final int index;
  final bool isDark;
  final Color textP;
  final Color textS;

  const _EvalCard({
    required this.eval,
    required this.index,
    required this.isDark,
    required this.textP,
    required this.textS,
  });

  Color get _diffColor {
    switch (eval.difficulty) {
      case 'Básico':
        return const Color(0xFF059669);
      case 'Intermedio':
        return AppColors.amber;
      case 'Avanzado':
        return AppColors.red;
      default:
        return AppColors.brand;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _EvalDetailScreen(eval: eval),
            ));
          },
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 0.5,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top accent
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: eval.color,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: eval.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: eval.color.withValues(alpha: 0.2),
                              width: 0.8),
                        ),
                        child: Icon(eval.icon, color: eval.color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Number badge
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: eval.color.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: eval.color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    eval.title,
                                    style: TextStyle(
                                      color: textP,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              eval.subtitle,
                              style: TextStyle(color: textS, fontSize: 11),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              eval.caseText,
                              style: TextStyle(
                                color: textS.withValues(alpha: 0.8),
                                fontSize: 11,
                                height: 1.45,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                // Difficulty
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _diffColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: _diffColor.withValues(alpha: 0.25)),
                                  ),
                                  child: Text(
                                    eval.difficulty,
                                    style: TextStyle(
                                      color: _diffColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Questions count
                                Text(
                                  '${eval.questions.length} preguntas',
                                  style: TextStyle(
                                    color: textS.withValues(alpha: 0.6),
                                    fontSize: 10,
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.arrow_forward_ios_rounded,
                                    size: 12,
                                    color: textS.withValues(alpha: 0.4)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pantalla de evaluación ───────────────────────────────────────────────────
class _EvalDetailScreen extends StatefulWidget {
  final _EvalScenario eval;
  const _EvalDetailScreen({super.key, required this.eval});

  @override
  State<_EvalDetailScreen> createState() => _EvalDetailScreenState();
}

class _EvalDetailScreenState extends State<_EvalDetailScreen> {
  int _currentQ = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _correctCount = 0;
  bool _finished = false;
  final List<bool> _results = [];

  void _selectAnswer(int idx) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
      final correct =
          idx == widget.eval.questions[_currentQ].correctIndex;
      if (correct) _correctCount++;
      _results.add(correct);
    });
  }

  void _next() {
    if (_currentQ < widget.eval.questions.length - 1) {
      setState(() {
        _currentQ++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      setState(() => _finished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    if (_finished) {
      return _ResultScreen(
        eval: widget.eval,
        correctCount: _correctCount,
        results: _results,
        isDark: isDark,
        textP: textP,
        textS: textS,
      );
    }

    final q = widget.eval.questions[_currentQ];
    final total = widget.eval.questions.length;
    final progress = (_currentQ + (_answered ? 1 : 0)) / total;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: textS),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.eval.title,
                            style: TextStyle(
                                color: textP,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        Text(
                            'Pregunta ${_currentQ + 1} de $total',
                            style: TextStyle(color: textS, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Score chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.eval.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_correctCount/${_results.length}',
                      style: TextStyle(
                          color: widget.eval.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor:
                      widget.eval.color.withValues(alpha: 0.12),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(widget.eval.color),
                  minHeight: 4,
                ),
              ),
            ),
            // ── Caso clínico ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.eval.color.withValues(alpha: isDark ? 0.1 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: widget.eval.color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(widget.eval.icon,
                        size: 16, color: widget.eval.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.eval.caseText,
                        style: TextStyle(
                          color: isDark
                              ? textS
                              : widget.eval.color
                                  .withValues(alpha: 0.9),
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Pregunta + opciones ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.question,
                      style: TextStyle(
                        color: textP,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(q.options.length, (i) {
                      final isSelected = _selectedAnswer == i;
                      final isCorrect = i == q.correctIndex;
                      Color? bg;
                      Color border;
                      Color textColor = textP;
                      IconData? trailingIcon;

                      if (_answered) {
                        if (isCorrect) {
                          bg = const Color(0xFF059669).withValues(alpha: 0.1);
                          border = const Color(0xFF059669).withValues(alpha: 0.5);
                          textColor = const Color(0xFF059669);
                          trailingIcon = Icons.check_circle_outline_rounded;
                        } else if (isSelected) {
                          bg = AppColors.red.withValues(alpha: 0.08);
                          border = AppColors.red.withValues(alpha: 0.4);
                          textColor = AppColors.red;
                          trailingIcon = Icons.cancel_outlined;
                        } else {
                          bg = null;
                          border = theme.colorScheme.outline
                              .withValues(alpha: 0.15);
                          textColor = textS.withValues(alpha: 0.5);
                        }
                      } else {
                        bg = null;
                        border = theme.colorScheme.outline
                            .withValues(alpha: 0.3);
                      }

                      final letter = ['A', 'B', 'C', 'D'][i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => _selectAnswer(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: bg ?? theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: border,
                                  width: isSelected && _answered ? 1.5 : 0.8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Letter badge
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: _answered
                                        ? textColor.withValues(alpha: 0.12)
                                        : theme.colorScheme.outline
                                            .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      letter,
                                      style: TextStyle(
                                        color: _answered
                                            ? textColor
                                            : textS.withValues(alpha: 0.6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    q.options[i],
                                    style: TextStyle(
                                        color: textColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        height: 1.35),
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
                    // Explanation
                    if (_answered) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline_rounded,
                                    size: 14, color: AppColors.amber),
                                const SizedBox(width: 7),
                                Text(
                                  'Explicación',
                                  style: TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              q.explanation,
                              style: TextStyle(
                                  color: textS,
                                  fontSize: 12,
                                  height: 1.55),
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
            // ── Continue button ───────────────────────────────────────────
            if (_answered)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.eval.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _currentQ < total - 1
                          ? 'Siguiente pregunta'
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
}

// ─── Pantalla de resultados ───────────────────────────────────────────────────
class _ResultScreen extends StatelessWidget {
  final _EvalScenario eval;
  final int correctCount;
  final List<bool> results;
  final bool isDark;
  final Color textP;
  final Color textS;

  const _ResultScreen({
    required this.eval,
    required this.correctCount,
    required this.results,
    required this.isDark,
    required this.textP,
    required this.textS,
  });

  @override
  Widget build(BuildContext context) {
    final total = eval.questions.length;
    final pct = (correctCount / total * 100).round();
    final passed = pct >= 75;
    final scoreColor = pct >= 90
        ? const Color(0xFF059669)
        : pct >= 75
            ? AppColors.amber
            : AppColors.red;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B0F19)
          : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Colored header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  eval.color,
                  eval.color.withValues(alpha: 0.7),
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
                    Expanded(
                      child: Text(
                        eval.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(eval.icon, color: Colors.white70, size: 20),
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
              // Score circle
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
                      '$correctCount/$total',
                      style: TextStyle(
                          color: scoreColor.withValues(alpha: 0.7),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                passed ? '¡Evaluación superada!' : 'Necesitas repasar',
                style: TextStyle(
                    color: textP, fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                eval.title,
                style: TextStyle(color: textS, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
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
                          ? 'Excelente dominio del protocolo'
                          : 'Competencia suficiente'
                      : 'Revisa los protocolos AHA',
                  style: TextStyle(
                      color: scoreColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 28),
              // Question results breakdown
              ...List.generate(results.length, (i) {
                final correct = results[i];
                final q = eval.questions[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? (correct
                            ? const Color(0xFF059669).withValues(alpha: 0.08)
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
                        color:
                            correct ? const Color(0xFF059669) : AppColors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'P${i + 1}: ${q.question}',
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
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.list_alt_rounded, size: 16),
                      label: const Text('Volver a la lista'),
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
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => _EvalDetailScreen(eval: eval),
                          ),
                        );
                      },
                      icon: const Icon(Icons.replay_rounded, size: 16),
                      label: const Text('Repetir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: eval.color,
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
