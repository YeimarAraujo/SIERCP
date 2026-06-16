import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:siercp/core/theme/theme.dart';

/// Número de preguntas que se muestran por intento (elegidas al azar del banco).
const int kQuestionsPerSession = 5;

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

// ─── Casos clínicos teóricos (MCQ basadas en guías AHA) ──────────────────────
const List<_EvalScenario> kTheoreticalCases = [
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
      _EvalQuestion(
        question:
            'Con un solo rescatador, ¿cuál es la relación compresión:ventilación en adultos?',
        options: ['15:2', '30:2', '5:1', '15:1'],
        correctIndex: 1,
        explanation:
            'AHA 2020: La relación estándar en adultos es 30 compresiones por cada 2 ventilaciones, tanto con uno como con dos rescatadores.',
      ),
      _EvalQuestion(
        question: '¿Cómo compruebas si la persona responde?',
        options: [
          'Le echas agua en la cara',
          'La tocas en los hombros y preguntas en voz alta "¿está bien?"',
          'Le tomas el pulso primero',
          'La sacudes con fuerza por los brazos',
        ],
        correctIndex: 1,
        explanation:
            'Se golpetea suavemente los hombros y se le habla en voz alta. Si no hay respuesta, se activa el sistema de emergencias y se evalúa respiración y pulso.',
      ),
      _EvalQuestion(
        question:
            'La víctima presenta respiración agónica (boqueo o "gasping"). ¿Qué significa?',
        options: [
          'Que respira con normalidad, no hagas nada',
          'No es respiración normal: trátala como paro e inicia RCP',
          'Que está despertando',
          'Que solo necesita oxígeno',
        ],
        correctIndex: 1,
        explanation:
            'El boqueo agónico NO es respiración efectiva. Es un signo de paro cardíaco; debe iniciarse RCP de inmediato.',
      ),
      _EvalQuestion(
        question:
            '¿Cuánto tiempo máximo debes emplear en comprobar el pulso?',
        options: [
          'No más de 10 segundos',
          'Al menos 30 segundos',
          '1 minuto completo',
          'El tiempo que haga falta',
        ],
        correctIndex: 0,
        explanation:
            'AHA 2020: La comprobación de pulso no debe superar los 10 segundos para no retrasar el inicio de las compresiones.',
      ),
      _EvalQuestion(
        question: '¿Dónde se palpa el pulso en un adulto?',
        options: [
          'Arteria radial (muñeca)',
          'Arteria carótida (cuello)',
          'Arteria braquial (brazo)',
          'Arteria pedia (pie)',
        ],
        correctIndex: 1,
        explanation:
            'En adultos se palpa la arteria carótida, en el surco entre la tráquea y el músculo del cuello, durante un máximo de 10 segundos.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la posición correcta de las manos para comprimir?',
        options: [
          'Sobre el abdomen, encima del ombligo',
          'En el talón de una mano sobre la mitad inferior del esternón, la otra encima',
          'En el lado izquierdo del pecho',
          'Sobre las costillas laterales',
        ],
        correctIndex: 1,
        explanation:
            'El talón de una mano se apoya en el centro del pecho (mitad inferior del esternón) y la otra mano encima, con los dedos entrelazados y los brazos rectos.',
      ),
      _EvalQuestion(
        question: '¿Sobre qué superficie debe realizarse la RCP?',
        options: [
          'Sobre una superficie firme y plana',
          'Sobre un colchón blando',
          'Da igual la superficie',
          'Sobre una almohada',
        ],
        correctIndex: 0,
        explanation:
            'La RCP debe hacerse sobre una superficie firme y plana (por ejemplo, el suelo). Una superficie blanda absorbe la fuerza y reduce la eficacia de las compresiones.',
      ),
      _EvalQuestion(
        question: '¿Por qué se debe evitar la hiperventilación durante la RCP?',
        options: [
          'Porque cansa al rescatador',
          'Aumenta la presión intratorácica y reduce el retorno venoso y el gasto cardíaco',
          'No tiene ningún efecto negativo',
          'Porque enfría al paciente',
        ],
        correctIndex: 1,
        explanation:
            'Ventilar en exceso eleva la presión dentro del tórax, dificulta el retorno de sangre al corazón y disminuye el flujo generado por las compresiones. Se dan ventilaciones medidas, no rápidas ni forzadas.',
      ),
      _EvalQuestion(
        question: '¿Qué volumen debe tener cada ventilación de rescate?',
        options: [
          'El máximo posible, soplando con fuerza',
          'El suficiente para ver elevarse el tórax, durante aprox. 1 segundo',
          'Dos soplidos muy rápidos y fuertes',
          'Lo mínimo posible',
        ],
        correctIndex: 1,
        explanation:
            'Cada insuflación dura alrededor de 1 segundo y solo debe ser suficiente para producir una elevación visible del tórax. Más volumen provoca distensión gástrica y regurgitación.',
      ),
      _EvalQuestion(
        question:
            'Eres un testigo no entrenado. ¿Qué tipo de RCP recomienda la AHA?',
        options: [
          'No intervenir hasta que llegue ayuda',
          'RCP solo con las manos (compresiones continuas, sin ventilaciones)',
          'Solo ventilaciones boca a boca',
          'Esperar instrucciones del DEA',
        ],
        correctIndex: 1,
        explanation:
            'AHA: Para reanimadores legos no entrenados se recomienda la RCP solo con las manos (Hands-Only): compresiones continuas a 100–120/min hasta que llegue ayuda o un DEA.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la fracción de compresión torácica (CCF) deseable?',
        options: [
          'Menos del 30%',
          'Alrededor del 50%',
          'Al menos el 60% (idealmente ≥80%)',
          'No importa mientras se comprima fuerte',
        ],
        correctIndex: 2,
        explanation:
            'La CCF es el porcentaje del tiempo total de RCP en que se está comprimiendo. Debe ser ≥60%, idealmente ≥80%, minimizando las interrupciones.',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la interrupción máxima recomendada de las compresiones?',
        options: [
          'Menos de 10 segundos',
          'Menos de 30 segundos',
          '1 minuto',
          'No hay límite',
        ],
        correctIndex: 0,
        explanation:
            'Las pausas (para ventilar, analizar con el DEA o cambiar de rescatador) deben durar menos de 10 segundos para mantener la perfusión coronaria y cerebral.',
      ),
      _EvalQuestion(
        question: 'Llega un DEA mientras haces RCP. ¿Qué haces?',
        options: [
          'Lo ignoras y sigues solo con compresiones',
          'Lo enciendes y sigues sus indicaciones lo antes posible',
          'Esperas a que llegue el personal médico para usarlo',
          'Lo usas solo si el paciente es joven',
        ],
        correctIndex: 1,
        explanation:
            'En cuanto haya un DEA disponible, se enciende y se siguen sus instrucciones, minimizando la interrupción de las compresiones. La desfibrilación precoz es clave en la FV.',
      ),
      _EvalQuestion(
        question: '¿En qué situación puedes detener la RCP?',
        options: [
          'Cuando te canses un poco',
          'Cuando llega el SEM y asume el control, la víctima da signos de vida, o estás físicamente agotado',
          'Después de 5 minutos siempre',
          'En cuanto llegue cualquier persona',
        ],
        correctIndex: 1,
        explanation:
            'La RCP se mantiene hasta que: el equipo de emergencias se hace cargo, la víctima muestra signos evidentes de vida (respira, se mueve), o el rescatador queda exhausto y no puede continuar.',
      ),
      _EvalQuestion(
        question:
            'Sin sospecha de trauma cervical, ¿cómo abres la vía aérea?',
        options: [
          'Maniobra frente-mentón (inclinar cabeza y elevar mentón)',
          'Tracción mandibular sin mover el cuello',
          'Girando la cabeza a un lado',
          'Flexionando el cuello hacia adelante',
        ],
        correctIndex: 0,
        explanation:
            'La maniobra frente-mentón (head-tilt/chin-lift) es la apertura estándar de vía aérea cuando no hay sospecha de lesión cervical.',
      ),
      _EvalQuestion(
        question:
            'Si sospechas lesión de columna cervical, ¿qué maniobra usas para la vía aérea?',
        options: [
          'Frente-mentón con fuerza',
          'Tracción mandibular (jaw thrust) sin extender el cuello',
          'Girar la cabeza de lado',
          'No abrir la vía aérea',
        ],
        correctIndex: 1,
        explanation:
            'Ante sospecha de trauma cervical se usa la tracción mandibular (jaw thrust), que abre la vía aérea minimizando el movimiento del cuello. Si no se logra ventilar, prima la vía aérea.',
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
        question:
            '¿Con cuántas manos se realizan las compresiones en niños (1–8 años)?',
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
      _EvalQuestion(
        question: '¿Cuál es la frecuencia de compresiones en niños?',
        options: [
          '60–80 por minuto',
          '80–100 por minuto',
          '100–120 por minuto, igual que en adultos',
          'Más de 140 por minuto',
        ],
        correctIndex: 2,
        explanation:
            'La frecuencia es 100–120 compresiones por minuto, igual que en adultos y lactantes.',
      ),
      _EvalQuestion(
        question:
            'Para el BLS, ¿hasta qué edad se considera "niño" (pediátrico)?',
        options: [
          'Hasta los 3 años',
          'Desde 1 año hasta el inicio de la pubertad',
          'Hasta los 16 años',
          'Solo el primer mes de vida',
        ],
        correctIndex: 1,
        explanation:
            'En BLS, "niño" abarca desde 1 año hasta los signos de pubertad. Por debajo de 1 año es lactante; a partir de la pubertad se aplica el protocolo de adulto.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la causa más frecuente de paro en niños?',
        options: [
          'Infarto de miocardio',
          'Causa respiratoria / hipoxia',
          'Fibrilación ventricular primaria',
          'Sobredosis',
        ],
        correctIndex: 1,
        explanation:
            'A diferencia del adulto, el paro pediátrico suele ser secundario a hipoxia (problema respiratorio). Por eso la ventilación tiene un papel central.',
      ),
      _EvalQuestion(
        question:
            'Un niño tiene pulso < 60/min con signos de mala perfusión pese a oxigenación y ventilación adecuadas. ¿Qué haces?',
        options: [
          'Esperar a que baje más el pulso',
          'Iniciar compresiones torácicas',
          'Solo dar ventilaciones',
          'No intervenir mientras tenga pulso',
        ],
        correctIndex: 1,
        explanation:
            'AHA: En el niño, una bradicardia < 60/min con mala perfusión a pesar de oxigenar y ventilar es indicación de iniciar compresiones torácicas.',
      ),
      _EvalQuestion(
        question:
            'Con dos rescatadores entrenados, ¿cuál es la relación compresión:ventilación en niños?',
        options: ['30:2', '15:2', '10:2', '5:1'],
        correctIndex: 1,
        explanation:
            'Con dos rescatadores entrenados en pediatría se usa 15:2 para aumentar el número de ventilaciones, dado el origen respiratorio del paro.',
      ),
      _EvalQuestion(
        question: '¿Dónde puedes palpar el pulso en un niño?',
        options: [
          'Solo en la muñeca',
          'En la carótida (cuello) o la femoral (ingle)',
          'Solo en el pie',
          'En la arteria braquial únicamente',
        ],
        correctIndex: 1,
        explanation:
            'En niños se palpa el pulso carotídeo o femoral, durante un máximo de 10 segundos.',
      ),
      _EvalQuestion(
        question: '¿Qué profundidad de compresión se busca en un niño?',
        options: [
          'Al menos 1/3 del diámetro del tórax (aprox. 5 cm)',
          '1–2 cm',
          'Más de 7 cm',
          'No importa la profundidad',
        ],
        correctIndex: 0,
        explanation:
            'Se comprime al menos un tercio del diámetro anteroposterior del tórax, aproximadamente 5 cm en niños.',
      ),
      _EvalQuestion(
        question:
            'Presencias el colapso súbito de un niño estando solo (posible causa cardíaca). ¿Qué haces?',
        options: [
          'RCP 2 minutos y luego llamar',
          'Llamar al 123 y buscar un DEA primero, por la posibilidad de FV',
          'No llamar hasta que reaccione',
          'Solo dar ventilaciones',
        ],
        correctIndex: 1,
        explanation:
            'En un colapso SÚBITO y presenciado (sugiere arritmia/FV), se prioriza activar el SEM y conseguir un DEA rápidamente, igual que en el adulto. En el paro NO presenciado se hacen 2 min de RCP primero.',
      ),
      _EvalQuestion(
        question: '¿Cómo se usa el DEA en un niño menor de 8 años?',
        options: [
          'No se puede usar DEA en niños',
          'Con parches pediátricos o atenuador de dosis; si no hay, se usan los de adulto',
          'Solo con parches de adulto siempre',
          'Únicamente en mayores de 12 años',
        ],
        correctIndex: 1,
        explanation:
            'Se prefieren parches pediátricos o sistema atenuador de energía en menores de 8 años (o < 25 kg). Si no se dispone de ellos, se usan los parches de adulto: es preferible desfibrilar a no hacerlo.',
      ),
      _EvalQuestion(
        question: 'En niños, ¿es importante permitir el recoil torácico completo?',
        options: [
          'No, solo importa en adultos',
          'Sí, permite el llenado cardíaco entre compresiones',
          'Solo si hay dos rescatadores',
          'Solo en lactantes',
        ],
        correctIndex: 1,
        explanation:
            'El recoil (reexpansión) completo del tórax entre compresiones es igual de importante en niños: permite el retorno venoso y mejora el gasto cardíaco generado.',
      ),
      _EvalQuestion(
        question: '¿Cómo se abre la vía aérea de un niño sin sospecha de trauma?',
        options: [
          'Tracción mandibular siempre',
          'Maniobra frente-mentón',
          'Girando la cabeza de lado',
          'Hiperextendiendo al máximo el cuello',
        ],
        correctIndex: 1,
        explanation:
            'Se usa la maniobra frente-mentón. Una hiperextensión excesiva puede colapsar la vía aérea en niños; si hay sospecha de trauma, se usa tracción mandibular.',
      ),
      _EvalQuestion(
        question:
            'Las ventilaciones en un niño deben ser...',
        options: [
          'Lo más fuertes posible',
          'Las suficientes para ver elevarse el tórax, sin hiperventilar',
          'Muy rápidas y numerosas',
          'No se dan ventilaciones en niños',
        ],
        correctIndex: 1,
        explanation:
            'Cada ventilación dura ~1 segundo y solo debe lograr una elevación visible del tórax. La hiperventilación reduce el retorno venoso y distiende el estómago.',
      ),
      _EvalQuestion(
        question:
            'Cuando comprimes con una mano en un niño pequeño, ¿dónde la colocas?',
        options: [
          'Sobre el abdomen',
          'En la mitad inferior del esternón, en el centro del pecho',
          'En el lado izquierdo, sobre el corazón',
          'En la parte alta del pecho',
        ],
        correctIndex: 1,
        explanation:
            'La compresión se realiza en el centro del pecho, sobre la mitad inferior del esternón, ya sea con una o dos manos según el tamaño del niño.',
      ),
      _EvalQuestion(
        question:
            'En la RCP pediátrica, ¿qué fracción de tiempo deberías estar comprimiendo?',
        options: [
          'Menos del 30%',
          'Al menos el 60% del tiempo, con interrupciones < 10 s',
          'No importa',
          'Como mucho el 40%',
        ],
        correctIndex: 1,
        explanation:
            'Igual que en adultos, se busca una fracción de compresión ≥ 60% y mantener cualquier interrupción por debajo de 10 segundos.',
      ),
      _EvalQuestion(
        question:
            'Signos de mala perfusión que orientan a iniciar/continuar RCP en un niño son:',
        options: [
          'Piel rosada y caliente',
          'Palidez o cianosis, llenado capilar lento y letargo',
          'Llanto vigoroso',
          'Pulso fuerte y rápido',
        ],
        correctIndex: 1,
        explanation:
            'La palidez/cianosis, el relleno capilar enlentecido y la alteración de la conciencia indican mala perfusión; junto a bradicardia, justifican iniciar compresiones.',
      ),
      _EvalQuestion(
        question:
            '¿Cada cuánto se alternan los rescatadores en la RCP pediátrica?',
        options: [
          'Cada 2 minutos para evitar fatiga',
          'Cada 10 minutos',
          'Nunca',
          'Solo si se cansan mucho',
        ],
        correctIndex: 0,
        explanation:
            'Como en adultos, los rescatadores se relevan cada 2 minutos (coincidiendo con el análisis del DEA) para mantener compresiones de alta calidad.',
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
        question:
            '¿Qué técnica se usa para comprimir el tórax de un lactante con un rescatador?',
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
        question:
            '¿Cuál es la profundidad correcta de compresión en lactantes?',
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
      _EvalQuestion(
        question: '¿Cuál es la frecuencia de compresiones en un lactante?',
        options: [
          '60–80 por minuto',
          '100–120 por minuto',
          '140–160 por minuto',
          'La que se pueda',
        ],
        correctIndex: 1,
        explanation:
            'La frecuencia es 100–120 compresiones por minuto, igual que en niños y adultos.',
      ),
      _EvalQuestion(
        question:
            'Con un solo rescatador, ¿cuál es la relación compresión:ventilación en lactantes?',
        options: ['30:2', '15:2', '5:1', '10:2'],
        correctIndex: 0,
        explanation:
            'Con un único rescatador se usa 30:2. Con dos rescatadores entrenados se cambia a 15:2.',
      ),
      _EvalQuestion(
        question:
            'Con DOS rescatadores, ¿qué técnica de compresión se prefiere en lactantes?',
        options: [
          'Dos dedos sobre el esternón',
          'Dos pulgares con las manos rodeando el tórax',
          'Una mano completa',
          'El talón de la mano',
        ],
        correctIndex: 1,
        explanation:
            'Con dos rescatadores se prefiere la técnica de los dos pulgares rodeando el tórax con las manos: genera mejor presión de perfusión coronaria que los dos dedos.',
      ),
      _EvalQuestion(
        question: '¿Dónde se colocan los dedos para comprimir a un lactante?',
        options: [
          'Sobre el ombligo',
          'En el esternón, justo por debajo de la línea entre los pezones',
          'En el lado izquierdo del tórax',
          'En la parte alta del pecho',
        ],
        correctIndex: 1,
        explanation:
            'Se comprime en el esternón, inmediatamente por debajo de la línea intermamilar (entre los pezones), evitando el extremo inferior del esternón.',
      ),
      _EvalQuestion(
        question: '¿Cómo compruebas si un lactante responde?',
        options: [
          'Lo sacudes con fuerza',
          'Le golpeteas suavemente la planta del pie y lo estimulas, sin sacudirlo',
          'Le echas agua',
          'Le aprietas el abdomen',
        ],
        correctIndex: 1,
        explanation:
            'En lactantes se estimula golpeteando la planta del pie y hablándole. NUNCA se sacude a un bebé (riesgo de lesión cerebral).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la causa más frecuente de paro en lactantes?',
        options: [
          'Fibrilación ventricular',
          'Causa respiratoria / hipoxia',
          'Infarto',
          'Sobredosis',
        ],
        correctIndex: 1,
        explanation:
            'Como en los niños, el paro del lactante es habitualmente secundario a hipoxia. La ventilación efectiva es prioritaria.',
      ),
      _EvalQuestion(
        question:
            'Estás solo con un lactante en paro NO presenciado. ¿Qué haces primero?',
        options: [
          'Llamar al 123 antes de tocar al bebé',
          'Hacer 2 minutos de RCP y luego llamar al 123 (o usar el altavoz)',
          'Buscar un DEA y esperar',
          'No iniciar RCP en lactantes',
        ],
        correctIndex: 1,
        explanation:
            'Al ser un paro de probable origen respiratorio, se realizan 2 minutos de RCP antes de dejar al bebé para llamar, o se activa el altavoz del teléfono mientras se reanima.',
      ),
      _EvalQuestion(
        question:
            'Al abrir la vía aérea de un lactante, la cabeza debe quedar en...',
        options: [
          'Hiperextensión máxima',
          'Posición neutra o de "olfateo", sin hiperextender',
          'Flexionada hacia el pecho',
          'Girada hacia un lado',
        ],
        correctIndex: 1,
        explanation:
            'En lactantes se coloca la cabeza en posición neutra/olfateo. La hiperextensión excesiva puede colapsar la tráquea, que es muy blanda a esta edad.',
      ),
      _EvalQuestion(
        question: '¿Qué profundidad de compresión se busca en un lactante?',
        options: [
          'Aprox. 4 cm (1/3 del diámetro del tórax)',
          '5–6 cm',
          '1 cm',
          'Más de 6 cm',
        ],
        correctIndex: 0,
        explanation:
            'Se comprime aproximadamente 4 cm, equivalente a un tercio del diámetro anteroposterior del tórax del lactante.',
      ),
      _EvalQuestion(
        question:
            'Un lactante tiene pulso < 60/min con mala perfusión pese a ventilar y oxigenar bien. ¿Qué haces?',
        options: [
          'Esperar',
          'Iniciar compresiones torácicas',
          'Solo ventilar',
          'Nada mientras tenga pulso',
        ],
        correctIndex: 1,
        explanation:
            'Una bradicardia < 60/min con signos de mala perfusión, a pesar de oxigenación y ventilación adecuadas, es indicación de iniciar compresiones en el lactante.',
      ),
      _EvalQuestion(
        question:
            'Para desfibrilar a un lactante, lo ideal es...',
        options: [
          'No desfibrilar nunca a un lactante',
          'Un desfibrilador manual; si no, DEA con parches/atenuador pediátrico; en último caso, DEA de adulto',
          'Solo parches de adulto',
          'Esperar al hospital siempre',
        ],
        correctIndex: 1,
        explanation:
            'En lactantes se prefiere un desfibrilador manual. Si no se dispone, un DEA con atenuador/parches pediátricos; y si tampoco, un DEA estándar, porque desfibrilar es mejor que no hacerlo.',
      ),
      _EvalQuestion(
        question:
            '¿Es importante el recoil completo del tórax en el lactante?',
        options: [
          'No, da igual en bebés',
          'Sí, permite el llenado del corazón entre compresiones',
          'Solo con dos pulgares',
          'Solo si hay DEA',
        ],
        correctIndex: 1,
        explanation:
            'Permitir la reexpansión completa del tórax entre compresiones favorece el retorno venoso y mejora la eficacia de la RCP también en lactantes.',
      ),
      _EvalQuestion(
        question: '¿Cómo deben ser las ventilaciones en un lactante?',
        options: [
          'Soplidos fuertes con todo el aire de tus pulmones',
          'Pequeñas insuflaciones (bocanadas) hasta ver elevarse el tórax',
          'Muy rápidas y repetidas',
          'No se ventila a los lactantes',
        ],
        correctIndex: 1,
        explanation:
            'Se usan insuflaciones suaves (con el aire de las mejillas/bocanadas), solo hasta ver una elevación visible del tórax. El exceso de volumen distiende el estómago y provoca regurgitación.',
      ),
      _EvalQuestion(
        question:
            '¿Durante cuánto tiempo y dónde compruebas el pulso en un lactante?',
        options: [
          'Carótida, 30 segundos',
          'Braquial, máximo 10 segundos',
          'Radial, 1 minuto',
          'Femoral, 20 segundos',
        ],
        correctIndex: 1,
        explanation:
            'El pulso del lactante se palpa en la arteria braquial (cara interna del brazo) durante un máximo de 10 segundos.',
      ),
      _EvalQuestion(
        question: '¿Sobre qué superficie se comprime a un lactante?',
        options: [
          'Una superficie firme (mesa, suelo o tu antebrazo con la mano bajo la espalda)',
          'Siempre sobre un cojín blando',
          'En el aire, sin apoyo',
          'Sobre una manta gruesa',
        ],
        correctIndex: 0,
        explanation:
            'Se necesita una superficie firme. Puede usarse una mesa o el suelo, o sostener al bebé sobre el antebrazo apoyando la otra mano en su espalda para dar firmeza.',
      ),
      _EvalQuestion(
        question:
            '¿Cada cuánto deberían relevarse los rescatadores en la RCP del lactante?',
        options: [
          'Cada 2 minutos',
          'Cada 10 minutos',
          'Nunca',
          'Cada 30 segundos',
        ],
        correctIndex: 0,
        explanation:
            'El relevo cada 2 minutos mantiene la calidad de las compresiones también en lactantes, aprovechando los análisis del desfibrilador.',
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
        question:
            '¿Por qué el paro en ahogamiento es diferente al paro cardíaco súbito?',
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
        question:
            'El paciente tiene pulso débil pero no respira. ¿Qué debes hacer?',
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
        question:
            '¿Cuántas ventilaciones de rescate iniciales se dan si el paciente evoluciona a paro completo (sin pulso)?',
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
        question:
            '¿Cuál es el riesgo de aplicar compresiones torácicas cuando hay pulso en ahogamiento?',
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
      _EvalQuestion(
        question:
            'Una víctima de ahogamiento no respira y NO tiene pulso. ¿Qué haces?',
        options: [
          'Solo ventilaciones de rescate',
          'RCP completa con compresiones y ventilaciones (ciclos 30:2)',
          'Esperar a que expulse el agua',
          'Posición de recuperación',
        ],
        correctIndex: 1,
        explanation:
            'Si no hay pulso, es un paro: se inicia RCP completa. En ahogamiento se prioriza la oxigenación, por lo que las ventilaciones son especialmente importantes.',
      ),
      _EvalQuestion(
        question:
            '¿Debe intentarse drenar el agua de los pulmones antes de la RCP?',
        options: [
          'Sí, presionando el abdomen o colgando a la víctima boca abajo',
          'No, no se debe retrasar la RCP intentando "sacar el agua"',
          'Sí, siempre primero',
          'Solo en niños',
        ],
        correctIndex: 1,
        explanation:
            'No se deben hacer maniobras para extraer agua (ni Heimlich ni colgar boca abajo): retrasan la RCP y provocan regurgitación y aspiración. Se inicia la reanimación de inmediato.',
      ),
      _EvalQuestion(
        question:
            'La frecuencia de las ventilaciones de rescate (con pulso) es de:',
        options: [
          '1 cada 5–6 segundos (10–12 por minuto)',
          '1 cada 2 segundos',
          '1 cada 20 segundos',
          '30 por minuto',
        ],
        correctIndex: 0,
        explanation:
            'Con pulso presente y sin respiración, se da 1 ventilación cada 5–6 segundos (10–12 por minuto), reevaluando el pulso cada 2 minutos.',
      ),
      _EvalQuestion(
        question:
            '¿Qué riesgo aumenta tras un episodio de ahogamiento, aunque la persona parezca recuperarse?',
        options: [
          'No hay riesgo posterior',
          'Deterioro respiratorio tardío: debe ser valorada médicamente',
          'Solo cansancio',
          'Únicamente hipotermia leve',
        ],
        correctIndex: 1,
        explanation:
            'Tras un ahogamiento puede aparecer dificultad respiratoria horas después (lesión pulmonar). Toda víctima debe ser evaluada por personal sanitario aunque parezca estar bien.',
      ),
      _EvalQuestion(
        question:
            'En el rescate acuático, ¿cuándo pueden iniciarse las ventilaciones?',
        options: [
          'Solo en tierra firme siempre',
          'Pueden iniciarse en el agua por rescatadores entrenados si es seguro',
          'Nunca en el agua',
          'Solo tras 10 minutos',
        ],
        correctIndex: 1,
        explanation:
            'Personal entrenado puede iniciar ventilaciones de rescate en el agua si es seguro hacerlo, ya que la hipoxia es el problema central. Las compresiones, en cambio, requieren una superficie firme.',
      ),
      _EvalQuestion(
        question: 'La seguridad de quién es prioritaria en un rescate acuático?',
        options: [
          'Siempre la de la víctima primero',
          'La del rescatador: no debe convertirse en una segunda víctima',
          'No importa',
          'La de los espectadores',
        ],
        correctIndex: 1,
        explanation:
            'La seguridad del rescatador es lo primero. Si no se está entrenado, se intenta el rescate desde fuera (alcanzar, lanzar objetos flotantes) en vez de entrar al agua.',
      ),
      _EvalQuestion(
        question:
            '¿Se debe usar el DEA en una víctima de ahogamiento en paro?',
        options: [
          'No, el agua lo impide siempre',
          'Sí: sacar a la víctima del agua, secar el tórax y aplicar el DEA',
          'Solo si lleva más de 1 hora',
          'Nunca en mojados',
        ],
        correctIndex: 1,
        explanation:
            'Se usa el DEA con normalidad. Antes hay que retirar a la víctima del agua y secar bien el tórax para que los parches se adhieran y la descarga sea efectiva y segura.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué se asocia el ahogamiento a riesgo de hipotermia?',
        options: [
          'Por el agua fría que enfría rápidamente el cuerpo',
          'Porque el agua siempre está caliente',
          'No tiene relación',
          'Solo en piscinas climatizadas',
        ],
        correctIndex: 0,
        explanation:
            'La inmersión, sobre todo en agua fría, produce pérdida de calor rápida. La hipotermia puede coexistir con el paro y modifica el manejo (manipulación cuidadosa, recalentamiento).',
      ),
      _EvalQuestion(
        question:
            'Al sacar del agua a una víctima de ahogamiento por zambullida, ¿qué debes considerar?',
        options: [
          'Nada especial',
          'Posible lesión cervical: proteger la columna si hubo salto/clavado',
          'Que siempre tiene fractura de pierna',
          'Que no se puede mover',
        ],
        correctIndex: 1,
        explanation:
            'Si el ahogamiento se asocia a una zambullida o salto, hay que sospechar lesión de columna cervical y movilizar con protección, usando tracción mandibular para la vía aérea.',
      ),
      _EvalQuestion(
        question: 'La causa fundamental del daño en el ahogamiento es:',
        options: [
          'La hipoxia (falta de oxígeno)',
          'La deshidratación',
          'La hipertensión',
          'El exceso de oxígeno',
        ],
        correctIndex: 0,
        explanation:
            'El mecanismo central es la hipoxia por interrupción del intercambio gaseoso. Por eso la ventilación/oxigenación precoz es la intervención más determinante.',
      ),
      _EvalQuestion(
        question:
            'Tras recuperar pulso y respiración, ¿en qué posición colocas a la víctima inconsciente?',
        options: [
          'Boca arriba sin moverla',
          'Posición lateral de seguridad para drenar secreciones y mantener la vía aérea',
          'Sentada',
          'Boca abajo',
        ],
        correctIndex: 1,
        explanation:
            'Si recupera circulación y respiración pero sigue inconsciente y no hay sospecha de trauma, se coloca en posición lateral de seguridad y se vigila de forma continua.',
      ),
      _EvalQuestion(
        question:
            'Si la víctima vomita durante la RCP (frecuente en ahogamiento), ¿qué haces?',
        options: [
          'Detienes la RCP definitivamente',
          'Giras la cabeza/cuerpo de lado, limpias la boca y reanudas la RCP',
          'Sigues sin hacer nada',
          'Le das agua',
        ],
        correctIndex: 1,
        explanation:
            'El vómito es muy común. Se gira a la víctima de lado, se limpia la vía aérea (con un dedo o aspiración si hay) y se reanuda la RCP lo antes posible.',
      ),
      _EvalQuestion(
        question:
            'En el ahogamiento, la secuencia de actuación enfatiza:',
        options: [
          'C-A-B estricto sin variaciones',
          'Iniciar con ventilaciones/oxigenación dada la causa hipóxica',
          'Solo desfibrilar',
          'Solo compresiones',
        ],
        correctIndex: 1,
        explanation:
            'Aunque el esquema general es C-A-B, en el ahogamiento se enfatiza la ventilación temprana porque el paro es de origen respiratorio (hipóxico).',
      ),
      _EvalQuestion(
        question:
            'Un niño es rescatado del agua, inconsciente y sin respirar. Estás solo. ¿Qué haces?',
        options: [
          'Llamar al 123 antes de tocarlo',
          'Dar 5 ventilaciones de rescate e iniciar RCP; llamar tras ~2 min',
          'Buscar un DEA y esperar',
          'No intervenir',
        ],
        correctIndex: 1,
        explanation:
            'En el ahogamiento pediátrico (causa hipóxica) se prioriza la oxigenación: ventilaciones iniciales y RCP de inmediato; si estás solo, activas el SEM tras unos 2 minutos o por altavoz.',
      ),
      _EvalQuestion(
        question:
            'Mientras das ventilaciones de rescate con pulso presente, ¿qué reevalúas y cada cuánto?',
        options: [
          'El pulso, cada 2 minutos',
          'Nada, hasta que llegue ayuda',
          'La temperatura, cada 10 minutos',
          'El color de los ojos',
        ],
        correctIndex: 0,
        explanation:
            'Se reevalúa el pulso aproximadamente cada 2 minutos. Si en algún momento desaparece, se inicia RCP completa con compresiones.',
      ),
      _EvalQuestion(
        question:
            'La víctima rescatada tose, respira y está agitada. ¿Qué haces?',
        options: [
          'La dejas ir, ya está bien',
          'La mantienes en reposo, abrigada y vigilada, y procuras valoración médica',
          'La haces nadar de nuevo',
          'Le das de comer',
        ],
        correctIndex: 1,
        explanation:
            'Aunque respire y tosa, toda víctima de ahogamiento debe quedar en reposo, abrigada (riesgo de hipotermia) y vigilada, con valoración médica por el riesgo de deterioro respiratorio tardío.',
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
        question:
            '¿Qué cambio introdujo AHA 2025 para OVACE en adultos conscientes?',
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
        question:
            '¿Cómo se posiciona a la víctima para los golpes en la espalda?',
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
        question:
            'La víctima pierde el conocimiento durante las maniobras. ¿Qué debes hacer?',
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
        question:
            'En un paciente obeso o embarazada, ¿qué reemplaza a los empujes abdominales?',
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
      _EvalQuestion(
        question:
            '¿Cómo distingues una obstrucción LEVE de una GRAVE de la vía aérea?',
        options: [
          'No se pueden distinguir',
          'Leve: tose con fuerza y habla. Grave: no puede toser, hablar ni respirar',
          'Leve: está inconsciente. Grave: está consciente',
          'Por el color de la ropa',
        ],
        correctIndex: 1,
        explanation:
            'En la obstrucción leve la persona tose eficazmente y puede hablar; en la grave no puede toser, hablar ni respirar (a menudo se lleva las manos al cuello).',
      ),
      _EvalQuestion(
        question:
            'La persona se atraganta pero TOSE con fuerza y puede hablar. ¿Qué haces?',
        options: [
          'Empujes abdominales de inmediato',
          'Animarla a seguir tosiendo y vigilarla de cerca',
          'Golpes en la espalda fuertes',
          'Iniciar RCP',
        ],
        correctIndex: 1,
        explanation:
            'Si la tos es eficaz (obstrucción leve), NO se interviene con maniobras: se la anima a toser y se la vigila por si la obstrucción empeora.',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la señal universal de atragantamiento?',
        options: [
          'Levantar los brazos',
          'Llevarse ambas manos al cuello',
          'Cerrar los ojos',
          'Señalar el pecho',
        ],
        correctIndex: 1,
        explanation:
            'Llevarse las manos al cuello es el signo universal de asfixia por obstrucción. Conviene preguntar "¿te estás atragantando?" para confirmar.',
      ),
      _EvalQuestion(
        question:
            '¿Dónde se colocan las manos para los empujes abdominales (Heimlich)?',
        options: [
          'Sobre el esternón',
          'Un puño entre el ombligo y el extremo inferior del esternón, y se empuja hacia adentro y arriba',
          'Sobre las costillas',
          'En la espalda baja',
        ],
        correctIndex: 1,
        explanation:
            'Se coloca el puño con el pulgar hacia el abdomen, ligeramente por encima del ombligo y por debajo del esternón, y se realizan empujes rápidos hacia adentro y hacia arriba.',
      ),
      _EvalQuestion(
        question:
            'Tras resolver un atragantamiento con empujes abdominales, ¿qué se recomienda?',
        options: [
          'Nada, puede irse a casa',
          'Valoración médica por posible lesión interna de los empujes',
          'Comer de inmediato',
          'Repetir los empujes por seguridad',
        ],
        correctIndex: 1,
        explanation:
            'Los empujes abdominales pueden causar lesiones internas. Toda persona a la que se le hayan aplicado debe ser valorada por personal sanitario.',
      ),
      _EvalQuestion(
        question:
            'Estás SOLO y te estás atragantando (obstrucción grave). ¿Qué puedes hacer?',
        options: [
          'Esperar a que pase',
          'Autoempujes abdominales con tus manos o apoyándote sobre el respaldo de una silla',
          'Beber agua',
          'Acostarte',
        ],
        correctIndex: 1,
        explanation:
            'Puedes realizarte empujes abdominales con tu propio puño o presionando el abdomen contra un objeto firme (respaldo de silla, borde de mesa) para generar la fuerza.',
      ),
      _EvalQuestion(
        question:
            'La víctima inconsciente por OVACE recibe RCP. ¿Cuándo revisas la boca?',
        options: [
          'Nunca',
          'Antes de cada intento de ventilación, retirando el objeto solo si lo ves',
          'Solo al final',
          'Cada 10 minutos',
        ],
        correctIndex: 1,
        explanation:
            'Tras cada serie de compresiones, al abrir la vía aérea para ventilar, se inspecciona la boca y se retira el objeto únicamente si es visible. El barrido a ciegas está contraindicado.',
      ),
      _EvalQuestion(
        question: '¿Por qué está contraindicado el barrido digital a ciegas?',
        options: [
          'Porque es lento',
          'Porque puede empujar el objeto más adentro y empeorar la obstrucción',
          'Porque ensucia las manos',
          'No está contraindicado',
        ],
        correctIndex: 1,
        explanation:
            'Introducir el dedo sin ver puede impactar el cuerpo extraño más profundamente y lesionar la vía aérea. Solo se retira si el objeto es visible y accesible.',
      ),
      _EvalQuestion(
        question:
            'Al perder el conocimiento durante el atragantamiento, las compresiones de la RCP también sirven para...',
        options: [
          'Calentar a la víctima',
          'Generar presión que puede ayudar a expulsar el objeto',
          'Nada relacionado con el objeto',
          'Reactivar la tos',
        ],
        correctIndex: 1,
        explanation:
            'Las compresiones torácicas elevan la presión intratorácica, lo que además de circular la sangre puede contribuir a desalojar el cuerpo extraño.',
      ),
      _EvalQuestion(
        question:
            'Antes de aplicar las maniobras a un adulto consciente atragantado, conviene...',
        options: [
          'Confirmar preguntando "¿te estás atragantando?" y avisar/activar el SEM',
          'No decir nada',
          'Darle agua primero',
          'Acostarlo en el suelo',
        ],
        correctIndex: 0,
        explanation:
            'Se confirma la obstrucción ("¿te estás atragantando?, ¿puedes hablar?") y se pide a alguien que active el sistema de emergencias mientras se inician las maniobras.',
      ),
      _EvalQuestion(
        question:
            'En una persona en silla de ruedas que se atraganta y está consciente, ¿qué puedes hacer?',
        options: [
          'Nada, no se puede ayudar',
          'Golpes en la espalda y empujes abdominales adaptando tu posición detrás de ella',
          'Solo esperar',
          'Acostarla en el suelo de inmediato',
        ],
        correctIndex: 1,
        explanation:
            'Las maniobras se adaptan: puedes situarte detrás de la silla para los golpes interescapulares y los empujes abdominales, frenando antes la silla.',
      ),
      _EvalQuestion(
        question:
            'En el protocolo AHA 2025, los golpes en la espalda se dan...',
        options: [
          'En la zona lumbar',
          'Entre los omóplatos, con el talón de la mano',
          'En la nuca',
          'En el centro del pecho',
        ],
        correctIndex: 1,
        explanation:
            'Los 5 golpes se aplican firmemente entre los omóplatos (zona interescapular) con el talón de la mano, con la víctima inclinada hacia adelante.',
      ),
      _EvalQuestion(
        question:
            'Si las maniobras no resuelven la obstrucción y no hay mejoría, ¿qué es prioritario?',
        options: [
          'Detenerse y esperar',
          'Mantener las maniobras y asegurar que el SEM está en camino; iniciar RCP si pierde la conciencia',
          'Darle de beber',
          'Sacudir a la víctima',
        ],
        correctIndex: 1,
        explanation:
            'Se continúan los ciclos de golpes y empujes mientras esté consciente, con el SEM activado; en cuanto pierda el conocimiento, se inicia RCP.',
      ),
      _EvalQuestion(
        question:
            '¿En qué se diferencian las maniobras de OVACE en una embarazada avanzada?',
        options: [
          'Se usan empujes torácicos en lugar de abdominales',
          'No se hace nada',
          'Se dan más golpes en la espalda solamente',
          'Se acuesta siempre primero',
        ],
        correctIndex: 0,
        explanation:
            'En el embarazo avanzado (o en personas con obesidad) el abdomen no permite empujes seguros: se sustituyen por empujes torácicos sobre el esternón.',
      ),
      _EvalQuestion(
        question:
            'Una obstrucción inicialmente leve se vuelve grave (la tos se hace débil y silenciosa). ¿Qué haces?',
        options: [
          'Sigues solo observando',
          'Pasas a aplicar golpes en la espalda y empujes abdominales',
          'Le das agua',
          'Esperas a que se resuelva sola',
        ],
        correctIndex: 1,
        explanation:
            'Si la obstrucción progresa a grave (tos inefectiva, no puede hablar/respirar), se interviene de inmediato con el ciclo de 5 golpes en la espalda + 5 empujes abdominales.',
      ),
      _EvalQuestion(
        question:
            '¿Cuántas veces se repite el ciclo de 5 golpes + 5 empujes?',
        options: [
          'Solo una vez',
          'Se repite el ciclo hasta expulsar el objeto o hasta que la víctima pierda el conocimiento',
          'Exactamente 3 veces',
          'Hasta 10 minutos',
        ],
        correctIndex: 1,
        explanation:
            'Se alternan los ciclos de 5 golpes interescapulares y 5 empujes abdominales de forma continua hasta que se expulsa el cuerpo extraño o la persona pierde la conciencia (entonces se inicia RCP).',
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
        question:
            '¿Cuánto reduce la supervivencia cada minuto sin desfibrilación en FV?',
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
        question:
            '¿Cuándo se detienen las compresiones para el análisis del DEA?',
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
      _EvalQuestion(
        question: '¿Qué es lo primero que debes hacer al obtener un DEA?',
        options: [
          'Aplicar los parches sin encenderlo',
          'Encenderlo y seguir sus instrucciones de voz',
          'Esperar a que llegue un médico',
          'Verificar el pulso primero',
        ],
        correctIndex: 1,
        explanation:
            'Se enciende el DEA en cuanto está disponible y se siguen sus indicaciones por voz, que guían paso a paso la colocación de parches y la descarga.',
      ),
      _EvalQuestion(
        question:
            'El DEA dice "Análisis del ritmo, no toque al paciente". ¿Qué haces?',
        options: [
          'Sigues comprimiendo',
          'Te apartas y te aseguras de que nadie toque a la víctima',
          'Tomas el pulso',
          'Apagas el DEA',
        ],
        correctIndex: 1,
        explanation:
            'Durante el análisis nadie debe tocar a la víctima, ya que el movimiento interfiere con la lectura del ritmo. Se reanudan las compresiones en cuanto termina el análisis (si no indica descarga).',
      ),
      _EvalQuestion(
        question:
            'El DEA indica "descarga recomendada". Antes de pulsar el botón, ¿qué confirmas?',
        options: [
          'Que el paciente respira',
          'Que nadie toca a la víctima ("yo libre, tú libre, todos libres")',
          'Que hay un médico presente',
          'Que la batería está al 100%',
        ],
        correctIndex: 1,
        explanation:
            'Antes de descargar, el operador verifica visualmente que nadie esté en contacto con la víctima para evitar que reciban la descarga. Luego pulsa el botón.',
      ),
      _EvalQuestion(
        question:
            'El DEA indica "descarga NO recomendada". ¿Qué haces?',
        options: [
          'Apagar el DEA y esperar',
          'Reanudar RCP de inmediato (compresiones), 2 minutos hasta el siguiente análisis',
          'Quitar los parches',
          'Verificar pulso durante 1 minuto',
        ],
        correctIndex: 1,
        explanation:
            'Si no se recomienda descarga (ritmo no desfibrilable), se reanuda inmediatamente la RCP durante 2 minutos, hasta que el DEA vuelva a analizar.',
      ),
      _EvalQuestion(
        question: '¿Qué ritmos detecta y trata el DEA con descarga?',
        options: [
          'Cualquier ritmo cardíaco',
          'Ritmos desfibrilables: fibrilación ventricular y taquicardia ventricular sin pulso',
          'Solo la asistolia',
          'La bradicardia',
        ],
        correctIndex: 1,
        explanation:
            'El DEA solo recomienda descarga ante ritmos desfibrilables: la fibrilación ventricular (FV) y la taquicardia ventricular sin pulso (TVSP). La asistolia y la AESP no son desfibrilables.',
      ),
      _EvalQuestion(
        question:
            'El paciente tiene el pecho muy mojado (sudor, agua). ¿Qué haces antes de poner los parches?',
        options: [
          'Aplicarlos directamente',
          'Secar bien el tórax para que los parches se adhieran y la descarga sea efectiva',
          'Echar más agua',
          'No usar el DEA',
        ],
        correctIndex: 1,
        explanation:
            'Un tórax mojado dispersa la corriente y reduce la adherencia. Se seca rápidamente antes de colocar los parches.',
      ),
      _EvalQuestion(
        question:
            'El paciente tiene mucho vello en el pecho y los parches no se adhieren. ¿Qué haces?',
        options: [
          'Aplicas más presión y ya',
          'Rasuras rápidamente la zona (o usas el primer par de parches para depilar) y colocas parches nuevos',
          'No usas el DEA',
          'Pones los parches en la espalda',
        ],
        correctIndex: 1,
        explanation:
            'Si el vello impide el contacto, se rasura rápido la zona o se usa el primer juego de parches para arrancar el vello y se aplican parches nuevos. El buen contacto es esencial.',
      ),
      _EvalQuestion(
        question:
            'El paciente lleva un parche de medicación (p. ej. nitroglicerina) en el pecho. ¿Qué haces?',
        options: [
          'Pegar el electrodo encima del parche',
          'Retirar el parche de medicación, limpiar la zona y colocar el electrodo',
          'No usar el DEA',
          'Da igual dónde se ponga',
        ],
        correctIndex: 1,
        explanation:
            'No se coloca el electrodo sobre un parche de medicación (puede causar quemaduras y reducir la energía). Se retira con un guante, se limpia la piel y se coloca el electrodo.',
      ),
      _EvalQuestion(
        question:
            'El paciente tiene un marcapasos visible bajo la piel. ¿Dónde pones el electrodo?',
        options: [
          'Justo encima del marcapasos',
          'Al menos a unos 2,5 cm del dispositivo, evitando colocarlo encima',
          'No se puede usar el DEA',
          'En la pierna',
        ],
        correctIndex: 1,
        explanation:
            'El electrodo se coloca al menos a 2–3 cm del marcapasos/desfibrilador implantado para no reducir la eficacia ni dañar el dispositivo, manteniendo la posición anterolateral.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué se reanuda la RCP inmediatamente tras la descarga, sin comprobar el pulso?',
        options: [
          'Porque el pulso nunca vuelve',
          'Porque comprobar el pulso interrumpe el flujo y el corazón tarda en recuperar ritmo de perfusión',
          'Por ahorrar tiempo solamente',
          'No hace falta volver a comprimir',
        ],
        correctIndex: 1,
        explanation:
            'Tras la descarga, aunque revierta la FV, el corazón suele tardar en generar pulso efectivo. Reanudar de inmediato las compresiones mantiene la perfusión; el pulso se valora en el siguiente análisis.',
      ),
      _EvalQuestion(
        question:
            '¿Cada cuánto vuelve a analizar el ritmo el DEA?',
        options: [
          'Cada 30 segundos',
          'Cada 2 minutos (aprox. 5 ciclos de 30:2)',
          'Cada 10 minutos',
          'Solo una vez',
        ],
        correctIndex: 1,
        explanation:
            'El DEA indica detener las compresiones para reanalizar el ritmo aproximadamente cada 2 minutos, coincidiendo con el cambio de rescatador.',
      ),
      _EvalQuestion(
        question:
            '¿Se puede usar un DEA si la víctima está sobre una superficie metálica o mojada?',
        options: [
          'Sí, sin precauciones',
          'Conviene moverla a una superficie seca/no conductora si es posible, y secarla',
          'Nunca se puede usar',
          'Solo si llueve',
        ],
        correctIndex: 1,
        explanation:
            'Para seguridad y eficacia, se retira a la víctima de superficies metálicas o charcos cuando sea factible y se seca el tórax; no debe haber contacto con agua que conecte rescatador y víctima.',
      ),
      _EvalQuestion(
        question:
            'En un colapso súbito presenciado, el factor que MÁS mejora la supervivencia es:',
        options: [
          'Esperar a la ambulancia',
          'RCP precoz de calidad + desfibrilación temprana',
          'Administrar agua',
          'Tomar la tensión arterial',
        ],
        correctIndex: 1,
        explanation:
            'La cadena de supervivencia muestra que la combinación de RCP precoz de alta calidad y desfibrilación temprana es lo que más aumenta la supervivencia en la FV.',
      ),
      _EvalQuestion(
        question:
            'Si solo tienes parches de DEA de adulto y la víctima es un niño de 6 años, ¿qué haces?',
        options: [
          'No desfibrilar',
          'Usar los parches de adulto evitando que se toquen (uno delante y otro en la espalda si es necesario)',
          'Esperar parches pediátricos siempre',
          'Cortar los parches por la mitad',
        ],
        correctIndex: 1,
        explanation:
            'Si no hay parches pediátricos, se usan los de adulto: es preferible desfibrilar. Si no caben sin tocarse, se colocan en posición anteroposterior (pecho y espalda). Nunca se recortan los parches.',
      ),
      _EvalQuestion(
        question:
            'Después de pulsar el botón de descarga, ¿qué hace el rescatador?',
        options: [
          'Espera 1 minuto sin tocar a la víctima',
          'Reanuda compresiones de inmediato, empezando por el tórax',
          'Comprueba el pulso 30 segundos',
          'Retira los parches',
        ],
        correctIndex: 1,
        explanation:
            'Inmediatamente después de la descarga se reinician las compresiones, minimizando la pausa post-descarga a menos de 5 segundos.',
      ),
      _EvalQuestion(
        question: 'El DEA no se enciende o parece fallar. ¿Qué haces?',
        options: [
          'Te detienes a repararlo',
          'Continúas la RCP de alta calidad sin interrupción mientras se consigue otro DEA',
          'Dejas de reanimar',
          'Esperas a que se arregle solo',
        ],
        correctIndex: 1,
        explanation:
            'Si el DEA falla, lo prioritario es no interrumpir la RCP. Se mantienen las compresiones y ventilaciones mientras alguien consigue otro DEA o llega el SEM.',
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
        question:
            '¿Cuál es el primer paso ANTES de tocar a la víctima de electrocución?',
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
        question:
            '¿Por qué se debe mantener el DEA listo en víctimas de electrocución incluso si inicialmente responden?',
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
        question:
            '¿Qué característica especial tienen las quemaduras por electrocución?',
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
        question:
            'La víctima recupera el pulso después de RCP. ¿Cuándo puedes cesar la vigilancia?',
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
      _EvalQuestion(
        question:
            'Si no puedes cortar la corriente, ¿cómo separas a la víctima de la fuente?',
        options: [
          'Tirando de ella con las manos',
          'Con un objeto seco no conductor (madera, plástico), nunca con las manos',
          'Echándole agua',
          'No se puede separar',
        ],
        correctIndex: 1,
        explanation:
            'Si no se puede desconectar la energía, se aparta la fuente o a la víctima con material aislante y seco (madera, plástico). Tocarla directamente te electrocutaría.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué la corriente alterna (AC) suele ser más peligrosa?',
        options: [
          'Porque no produce quemaduras',
          'Porque provoca tetania muscular que impide soltar la fuente y favorece la FV',
          'Porque es más débil',
          'Porque no afecta al corazón',
        ],
        correctIndex: 1,
        explanation:
            'La corriente alterna causa contracción muscular sostenida (tetania) que "pega" la mano a la fuente y prolonga la exposición, además de ser muy arritmogénica (induce FV).',
      ),
      _EvalQuestion(
        question:
            'Ante un cable de ALTA TENSIÓN caído cerca de la víctima, ¿qué haces?',
        options: [
          'Te acercas a retirarlo',
          'Mantienes la distancia (varios metros), alejas a los presentes y llamas a la compañía eléctrica/emergencias',
          'Lo apartas con la mano enguantada',
          'Lo riegas con agua',
        ],
        correctIndex: 1,
        explanation:
            'La alta tensión puede saltar (arco) o transmitirse por el suelo (tensión de paso). Hay que mantener una distancia de seguridad amplia y esperar a que profesionales corten el suministro.',
      ),
      _EvalQuestion(
        question:
            '¿Qué trayecto de la corriente por el cuerpo es más peligroso para el corazón?',
        options: [
          'De un pie a otro',
          'El que atraviesa el tórax (mano a mano o mano a pie contralateral)',
          'De una mano a la misma muñeca',
          'Ninguno afecta al corazón',
        ],
        correctIndex: 1,
        explanation:
            'Cuando la corriente cruza el tórax (por ejemplo mano-mano o mano-pie opuesto), atraviesa el corazón y aumenta el riesgo de arritmias mortales como la FV.',
      ),
      _EvalQuestion(
        question:
            'Al examinar a la víctima, ¿qué buscas en relación con las quemaduras eléctricas?',
        options: [
          'Una sola quemadura',
          'Dos lesiones: un punto de entrada y otro de salida de la corriente',
          'Quemaduras solo en la cara',
          'No hay quemaduras nunca',
        ],
        correctIndex: 1,
        explanation:
            'La corriente entra y sale del cuerpo, dejando habitualmente una quemadura de entrada y otra de salida. Localizarlas ayuda a estimar el trayecto y la gravedad del daño interno.',
      ),
      _EvalQuestion(
        question: '¿Cómo se manejan las quemaduras eléctricas en primeros auxilios?',
        options: [
          'Aplicando cremas o pasta de dientes',
          'Cubriéndolas con un apósito limpio y seco y derivando a valoración médica',
          'Reventando las ampollas',
          'Frotándolas con hielo',
        ],
        correctIndex: 1,
        explanation:
            'Se cubren con un apósito limpio y seco, sin cremas ni remedios caseros, y se trasladan para valoración: el daño interno suele superar lo que se ve en la piel.',
      ),
      _EvalQuestion(
        question:
            'Tras una electrocución con caída o contractura intensa, ¿qué lesiones asociadas debes sospechar?',
        options: [
          'Ninguna',
          'Fracturas, luxaciones y posible lesión de columna cervical',
          'Solo un resfriado',
          'Únicamente quemaduras leves',
        ],
        correctIndex: 1,
        explanation:
            'La descarga puede provocar caídas y contracciones musculares violentas que causan fracturas, luxaciones o lesión cervical. Se moviliza con protección de la columna.',
      ),
      _EvalQuestion(
        question:
            'La destrucción muscular por la corriente puede provocar...',
        options: [
          'Nada relevante',
          'Rabdomiólisis y daño renal (orina oscura por mioglobina)',
          'Mejor función renal',
          'Aumento de la visión',
        ],
        correctIndex: 1,
        explanation:
            'El daño muscular libera mioglobina que puede dañar los riñones (rabdomiólisis). La orina oscura es un signo de alarma; requiere atención médica e hidratación.',
      ),
      _EvalQuestion(
        question:
            'Un niño muerde un cable eléctrico y presenta una quemadura en la comisura del labio. ¿Qué advertencia es importante?',
        options: [
          'No hay riesgo posterior',
          'Riesgo de hemorragia tardía de la arteria labial al desprenderse la escara (días después)',
          'Solo dolerá un poco',
          'Se cura sin control médico',
        ],
        correctIndex: 1,
        explanation:
            'Las quemaduras orales por morder cables pueden sangrar de forma importante días después, al caer la costra sobre la arteria labial. Requieren seguimiento médico.',
      ),
      _EvalQuestion(
        question:
            'En una FULGURACIÓN por rayo con varias víctimas, ¿cómo se prioriza (triaje)?',
        options: [
          'Igual que en otros incidentes: los aparentemente muertos al final',
          'Triaje inverso: atender primero a quienes están en paro, porque pueden recuperarse',
          'No se atiende a nadie',
          'Solo a los conscientes',
        ],
        correctIndex: 1,
        explanation:
            'En las víctimas de rayo se aplica un triaje inverso: se prioriza la RCP de los que están en paro, ya que muchos responden bien a la reanimación precoz (el rayo causa paro transitorio).',
      ),
      _EvalQuestion(
        question:
            'Confirmas que ya no hay corriente y la víctima está en paro. ¿Qué protocolo aplicas?',
        options: [
          'Uno especial solo para electrocución',
          'El BLS estándar: RCP de alta calidad + DEA',
          'Solo ventilaciones',
          'Esperar sin actuar',
        ],
        correctIndex: 1,
        explanation:
            'Una vez asegurada la escena, el manejo del paro por electrocución sigue el protocolo BLS habitual: compresiones de calidad, ventilaciones y desfibrilación con DEA.',
      ),
      _EvalQuestion(
        question:
            'La víctima está consciente tras la descarga pero refiere palpitaciones y dolor torácico. ¿Qué haces?',
        options: [
          'La dejas ir a casa',
          'Activas el SEM para valoración y ECG; vigila por arritmias',
          'Le das un analgésico y nada más',
          'Le pides que camine',
        ],
        correctIndex: 1,
        explanation:
            'Aunque esté consciente, los síntomas cardíacos tras una electrocución obligan a valoración médica y monitorización (ECG) por el riesgo de arritmias diferidas.',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la prioridad absoluta al llegar a la escena de una electrocución?',
        options: [
          'Iniciar RCP cuanto antes tocando a la víctima',
          'La seguridad de la escena: garantizar que no hay corriente activa',
          'Buscar quemaduras',
          'Llamar a la familia',
        ],
        correctIndex: 1,
        explanation:
            'La seguridad de la escena es lo primero. Tocar a una víctima aún conectada a la corriente convertiría al rescatador en una segunda víctima.',
      ),
      _EvalQuestion(
        question:
            'En electrocuciones de alta tensión, el daño suele ser...',
        options: [
          'Solo superficial',
          'Mucho mayor en los tejidos profundos que en la piel visible',
          'Inexistente',
          'Solo estético',
        ],
        correctIndex: 1,
        explanation:
            'La alta tensión genera calor al atravesar tejidos de mayor resistencia (músculo, hueso), causando daño profundo extenso que puede no reflejarse en quemaduras cutáneas pequeñas.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué hay que mantener el DEA y la vigilancia incluso si la víctima parece estable?',
        options: [
          'Por costumbre',
          'Porque pueden aparecer arritmias (incluida FV) de forma tardía',
          'Para medir la fiebre',
          'No es necesario vigilar',
        ],
        correctIndex: 1,
        explanation:
            'Las lesiones eléctricas pueden desencadenar arritmias diferidas. Se mantiene la monitorización y el DEA disponible hasta la entrega al equipo médico avanzado.',
      ),
      _EvalQuestion(
        question:
            'Tras una electrocución de alta tensión, aunque la persona se sienta bien, lo correcto es...',
        options: [
          'Que siga trabajando',
          'Trasladarla para monitorización por el riesgo de arritmias y de daño interno no visible',
          'Darle agua y dejarla descansar en casa',
          'No hacer nada',
        ],
        correctIndex: 1,
        explanation:
            'Las lesiones por alta tensión pueden tener consecuencias internas (cardíacas, musculares, renales) que no se ven al inicio. Siempre se traslada para valoración y monitorización.',
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
        question:
            'La paciente tiene pulso. ¿Cuál es la intervención prioritaria?',
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
        question:
            '¿La naloxona debe retrasar o interrumpir la RCP si el paciente evoluciona a paro?',
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
        question:
            '¿Cada cuánto tiempo se puede repetir la dosis de naloxona intranasal?',
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
        question:
            '¿Por qué es crítico monitorizar a la paciente incluso después de que responda a la naloxona?',
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
      _EvalQuestion(
        question: '¿Cuál es la tríada clásica de la sobredosis por opioides?',
        options: [
          'Fiebre, tos y dolor',
          'Disminución del nivel de conciencia, depresión respiratoria y pupilas mióticas (puntiformes)',
          'Hipertensión, taquicardia y sudor',
          'Convulsiones, fiebre y rigidez',
        ],
        correctIndex: 1,
        explanation:
            'La tríada típica es: depresión del sistema nervioso central (somnolencia/coma), respiración lenta o ausente y pupilas puntiformes (miosis).',
      ),
      _EvalQuestion(
        question: '¿Qué signo en las pupilas orienta a sobredosis por opioides?',
        options: [
          'Pupilas muy dilatadas (midriasis)',
          'Pupilas puntiformes (miosis)',
          'Pupilas desiguales',
          'No hay cambios pupilares',
        ],
        correctIndex: 1,
        explanation:
            'Los opioides producen miosis: pupilas muy pequeñas (puntiformes). Es un signo muy característico, aunque puede faltar en sobredosis mixtas o por hipoxia severa.',
      ),
      _EvalQuestion(
        question: '¿Qué es y cómo actúa la naloxona?',
        options: [
          'Un sedante que duerme al paciente',
          'Un antagonista opioide que revierte la depresión respiratoria',
          'Un analgésico opioide',
          'Un antibiótico',
        ],
        correctIndex: 1,
        explanation:
            'La naloxona es un antagonista que desplaza al opioide de sus receptores, revirtiendo rápidamente la depresión respiratoria y del nivel de conciencia.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué vías puede administrarla un reanimador lego con más facilidad?',
        options: [
          'Solo intravenosa',
          'Intranasal o intramuscular',
          'Solo intraósea',
          'Solo oral',
        ],
        correctIndex: 1,
        explanation:
            'Para uso comunitario, la naloxona se presenta en formato intranasal (espray) o intramuscular (autoinyector), seguros y fáciles de aplicar sin acceso venoso.',
      ),
      _EvalQuestion(
        question: '¿Cómo se administra correctamente la naloxona intranasal?',
        options: [
          'Repartida en ambas fosas a la vez con medio dispositivo en cada una',
          'El dispositivo completo en una sola fosa nasal',
          'Por la boca',
          'En el ojo',
        ],
        correctIndex: 1,
        explanation:
            'El dispositivo intranasal se aplica completo en una sola fosa nasal. Si no hay respuesta, se repite con un dispositivo nuevo (en la otra fosa) a los 2–3 minutos.',
      ),
      _EvalQuestion(
        question:
            'La persona no respira pero TIENE pulso. ¿Qué haces además de la naloxona?',
        options: [
          'Compresiones torácicas',
          'Ventilaciones de rescate (1 cada 5–6 s) hasta que recupere la respiración',
          'Nada, solo esperar',
          'Posición sentada',
        ],
        correctIndex: 1,
        explanation:
            'Con pulso pero sin respiración eficaz, se dan ventilaciones de rescate (10–12/min) mientras actúa la naloxona. La oxigenación es la prioridad inmediata.',
      ),
      _EvalQuestion(
        question:
            '¿Es necesario activar el sistema de emergencias aunque tengas naloxona?',
        options: [
          'No, la naloxona resuelve todo',
          'Sí, siempre: la persona necesita evaluación y la sedación puede recurrir',
          'Solo si no despierta',
          'Solo si es menor de edad',
        ],
        correctIndex: 1,
        explanation:
            'Siempre se llama al 123. La naloxona puede agotarse antes que el opioide y reaparecer la depresión respiratoria; además puede haber otras causas o complicaciones.',
      ),
      _EvalQuestion(
        question:
            'La persona despierta tras la naloxona, agitada y con náuseas. ¿Qué ocurre?',
        options: [
          'Es una reacción alérgica grave',
          'Es un síndrome de abstinencia precipitado por la naloxona; mantén la calma y vigila',
          'Está teniendo otra sobredosis',
          'No tiene explicación',
        ],
        correctIndex: 1,
        explanation:
            'La reversión brusca puede provocar abstinencia aguda (agitación, náuseas, vómitos). Se tranquiliza a la persona, se la vigila y se previene la broncoaspiración.',
      ),
      _EvalQuestion(
        question:
            'Administras naloxona pero la causa NO era un opioide (p. ej. benzodiacepinas). ¿Qué pasa?',
        options: [
          'Causa un daño grave',
          'No produce efecto adverso relevante; simplemente no revierte el cuadro',
          'Empeora siempre la situación',
          'Provoca un paro inmediato',
        ],
        correctIndex: 1,
        explanation:
            'La naloxona es segura: si no hay opioides de por medio, no causa daño significativo, solo no hará efecto. Por eso puede administrarse ante la sospecha sin confirmar.',
      ),
      _EvalQuestion(
        question:
            'Con opioides muy potentes como el fentanilo, ¿qué puede ocurrir con la naloxona?',
        options: [
          'Basta siempre una sola dosis',
          'Pueden requerirse varias dosis para revertir la depresión respiratoria',
          'No funciona en absoluto',
          'Hay que esperar 1 hora entre dosis',
        ],
        correctIndex: 1,
        explanation:
            'El fentanilo y análogos son muy potentes; a menudo se necesitan dosis repetidas de naloxona cada 2–3 minutos hasta lograr respiración efectiva.',
      ),
      _EvalQuestion(
        question:
            'La persona recupera la respiración y la conciencia. ¿En qué posición la dejas mientras llega el SEM?',
        options: [
          'Boca arriba',
          'Posición lateral de seguridad, por el riesgo de vómito',
          'Sentada en una silla',
          'De pie',
        ],
        correctIndex: 1,
        explanation:
            'Se coloca en posición lateral de seguridad para proteger la vía aérea (riesgo de vómito y broncoaspiración) y se vigila de forma continua por si recurre la depresión.',
      ),
      _EvalQuestion(
        question:
            'La persona despierta y dice estar bien. ¿Puedes dejarla sola?',
        options: [
          'Sí, si camina',
          'No: la naloxona puede agotarse antes que el opioide y volver la depresión respiratoria',
          'Sí, si firma un papel',
          'Sí, tras 5 minutos',
        ],
        correctIndex: 1,
        explanation:
            'No se debe dejar sola. La duración del opioide suele superar a la de la naloxona, por lo que la depresión respiratoria puede reaparecer. Se mantiene la vigilancia hasta el SEM.',
      ),
      _EvalQuestion(
        question:
            'La persona evoluciona a paro (sin pulso). ¿Qué tiene prioridad?',
        options: [
          'Administrar naloxona antes de comprimir',
          'RCP de alta calidad y DEA; la naloxona no debe retrasar las compresiones',
          'Solo ventilaciones',
          'Esperar otra dosis de naloxona',
        ],
        correctIndex: 1,
        explanation:
            'En paro cardíaco, la RCP y el DEA son prioridad absoluta. La naloxona puede darse en paralelo si hay otro reanimador, pero nunca a costa de interrumpir las compresiones.',
      ),
      _EvalQuestion(
        question:
            'Respecto a tu seguridad al asistir una sobredosis, ¿qué es correcto?',
        options: [
          'El contacto casual con fentanilo en la piel te provocará una sobredosis',
          'El riesgo por contacto casual es bajo; usa guantes y ventila la zona, sin demorar la ayuda',
          'No debes tocar a la persona bajo ningún concepto',
          'Debes tomar naloxona preventiva',
        ],
        correctIndex: 1,
        explanation:
            'El riesgo de intoxicación por simple contacto cutáneo es muy bajo. Se usan guantes y sentido común, pero el miedo no debe retrasar las ventilaciones ni la naloxona.',
      ),
      _EvalQuestion(
        question:
            'Tras administrar naloxona, si no hay respuesta a los 2–3 minutos, ¿qué haces?',
        options: [
          'Te detienes',
          'Repites la dosis y continúas con las ventilaciones/RCP según corresponda',
          'Esperas 30 minutos',
          'Le das agua',
        ],
        correctIndex: 1,
        explanation:
            'Si no hay mejoría, se repite la naloxona cada 2–3 minutos mientras se mantienen las ventilaciones de rescate (o la RCP si está en paro) y la vigilancia.',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el principal signo de que la naloxona ha hecho efecto?',
        options: [
          'Aumenta la fiebre',
          'La recuperación de la respiración (mejora la frecuencia y profundidad respiratoria)',
          'Las pupilas se hacen más pequeñas',
          'Se duerme más profundamente',
        ],
        correctIndex: 1,
        explanation:
            'El objetivo de la naloxona es revertir la depresión respiratoria; el signo clave de eficacia es que la persona vuelve a respirar de forma adecuada, junto con cierta recuperación de la conciencia.',
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
        question:
            '¿Cada cuánto tiempo deben cambiarse los roles entre los dos rescatadores?',
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
        question:
            '¿Cuándo debe ocurrir el cambio de rol durante la RCP con dos rescatadores?',
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
        question:
            'Con dos rescatadores entrenados en pediatría y un niño en paro, ¿qué relación se usa?',
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
        question:
            '¿Cuál es la máxima interrupción permitida en las compresiones durante RCP?',
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
      _EvalQuestion(
        question:
            'Con dos rescatadores, ¿cuál es la relación compresión:ventilación en un adulto?',
        options: ['15:2', '30:2', '5:1', '10:2'],
        correctIndex: 1,
        explanation:
            'En adultos la relación es 30:2 tanto con uno como con dos rescatadores. La diferencia es que se reparten las tareas y se relevan.',
      ),
      _EvalQuestion(
        question:
            'Mientras un rescatador comprime, ¿qué hace el segundo rescatador?',
        options: [
          'Observa sin hacer nada',
          'Maneja la vía aérea y las ventilaciones, prepara el DEA y se cuenta para el relevo',
          'Toma el pulso continuamente',
          'Llama por teléfono solamente',
        ],
        correctIndex: 1,
        explanation:
            'El segundo rescatador se encarga de la vía aérea/ventilaciones, coloca y opera el DEA y vigila la calidad de las compresiones, preparándose para el relevo cada 2 minutos.',
      ),
      _EvalQuestion(
        question:
            '¿Cómo se minimiza la interrupción durante el cambio de rescatadores?',
        options: [
          'Cambiando lentamente con calma',
          'Anunciando el cambio con antelación y haciéndolo en menos de 5 segundos, idealmente durante el análisis del DEA',
          'Parando 30 segundos',
          'No avisando',
        ],
        correctIndex: 1,
        explanation:
            'El cambio se anticipa verbalmente y se ejecuta en el momento de las ventilaciones o del análisis del DEA, en menos de 5 segundos, para no perder fracción de compresión.',
      ),
      _EvalQuestion(
        question: '¿Por qué es importante que un reanimador "cuente en voz alta"?',
        options: [
          'Para hacer ruido',
          'Para coordinar el ritmo, marcar las ventilaciones y avisar del relevo',
          'No sirve de nada',
          'Para calmar a los testigos',
        ],
        correctIndex: 1,
        explanation:
            'Contar en voz alta mantiene la frecuencia (100–120/min), señala cuándo dar las ventilaciones tras 30 compresiones y permite coordinar el relevo del equipo.',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es una ventaja principal de la RCP con dos rescatadores frente a uno solo?',
        options: [
          'Permite descansar más tiempo',
          'Mantiene compresiones de alta calidad (menos fatiga) y reduce las interrupciones',
          'No tiene ventajas',
          'Permite usar menos fuerza',
        ],
        correctIndex: 1,
        explanation:
            'Al alternarse, se evita la fatiga que degrada la profundidad y frecuencia, y se reparten tareas (ventilar, DEA), logrando una RCP más continua y eficaz.',
      ),
      _EvalQuestion(
        question:
            'Con vía aérea avanzada colocada (p. ej. tubo), ¿cómo cambian las compresiones y ventilaciones?',
        options: [
          'Se mantienen los ciclos 30:2 con pausas',
          'Compresiones continuas (100–120/min) y 1 ventilación cada 6 segundos, sin pausar para ventilar',
          'Se detienen las compresiones para ventilar',
          'Se ventila cada 2 segundos',
        ],
        correctIndex: 1,
        explanation:
            'Con vía aérea avanzada se dan compresiones continuas sin pausa y una ventilación cada 6 segundos (10/min), de forma asíncrona.',
      ),
      _EvalQuestion(
        question:
            'El que comprime nota que se fatiga antes de los 2 minutos. ¿Qué se debe hacer?',
        options: [
          'Aguantar hasta los 2 minutos pase lo que pase',
          'Adelantar el relevo, ya que la fatiga reduce la calidad de las compresiones',
          'Comprimir más despacio',
          'Dejar de comprimir',
        ],
        correctIndex: 1,
        explanation:
            'Si hay signos de fatiga antes de los 2 minutos, conviene adelantar el cambio: la profundidad y frecuencia caen con el cansancio, comprometiendo la perfusión.',
      ),
      _EvalQuestion(
        question:
            '¿Quién y cuándo coloca los parches del DEA en la RCP con dos rescatadores?',
        options: [
          'Se detiene toda la RCP para colocarlos',
          'El segundo rescatador los coloca mientras el primero sigue comprimiendo, sin interrumpir',
          'No se usa DEA con dos rescatadores',
          'Solo tras 10 minutos',
        ],
        correctIndex: 1,
        explanation:
            'Mientras un reanimador comprime de forma continua, el otro coloca los parches del DEA. Solo se interrumpen las compresiones cuando el DEA va a analizar o descargar.',
      ),
      _EvalQuestion(
        question:
            'En un lactante con dos rescatadores, además de cambiar a 15:2, se prefiere comprimir con...',
        options: [
          'Dos dedos',
          'La técnica de los dos pulgares rodeando el tórax',
          'Una mano',
          'El talón de la mano',
        ],
        correctIndex: 1,
        explanation:
            'Con dos reanimadores, en el lactante se usa la técnica de dos pulgares con las manos rodeando el tórax, que genera mejor presión de perfusión.',
      ),
      _EvalQuestion(
        question:
            'Una buena comunicación de equipo durante la RCP incluye:',
        options: [
          'Hablar todos a la vez',
          'Mensajes claros y en bucle cerrado (confirmar órdenes), roles definidos y feedback de la calidad',
          'Guardar silencio absoluto',
          'Discutir las decisiones',
        ],
        correctIndex: 1,
        explanation:
            'Una RCP en equipo eficaz usa comunicación en bucle cerrado, roles claros y retroalimentación continua sobre frecuencia, profundidad y recoil para corregir en tiempo real.',
      ),
      _EvalQuestion(
        question:
            'Durante las ventilaciones con bolsa-mascarilla por el segundo rescatador, se busca...',
        options: [
          'Apretar la bolsa al máximo',
          'Un sellado correcto y un volumen que eleve visiblemente el tórax, sin hiperventilar',
          'Ventilar muy rápido',
          'No sellar la mascarilla',
        ],
        correctIndex: 1,
        explanation:
            'Con bolsa-mascarilla se prioriza un buen sellado (técnica C-E) y volúmenes que solo eleven el tórax. La hiperventilación reduce el retorno venoso.',
      ),
      _EvalQuestion(
        question:
            '¿Cómo se mantiene la frecuencia de compresiones correcta en equipo?',
        options: [
          'Comprimiendo lo más rápido posible',
          'A 100–120/min, ayudándose de contar en voz alta o de un metrónomo',
          'A 60/min',
          'Sin controlar la frecuencia',
        ],
        correctIndex: 1,
        explanation:
            'Se mantienen 100–120 compresiones por minuto; contar en voz alta o usar un metrónomo (o el del DEA) ayuda a no ir ni demasiado lento ni demasiado rápido.',
      ),
      _EvalQuestion(
        question:
            'Tras 2 minutos de RCP el DEA va a analizar. ¿Qué hace el equipo?',
        options: [
          'Sigue comprimiendo durante el análisis',
          'Detiene las compresiones solo durante el análisis, aprovecha para relevarse y se aparta si va a descargar',
          'Apaga el DEA',
          'Comprueba el pulso 1 minuto',
        ],
        correctIndex: 1,
        explanation:
            'Coincidiendo con el análisis del DEA cada 2 minutos, se hace el relevo de compresor y, si se indica descarga, todos se apartan; luego se reanuda de inmediato.',
      ),
      _EvalQuestion(
        question:
            'Si llega un tercer reanimador, ¿en qué puede ayudar?',
        options: [
          'En nada, solo estorba',
          'Relevándose en las compresiones, gestionando el DEA o coordinando la llegada del SEM',
          'Tomando el pulso sin parar',
          'Comprimiendo a la vez que el primero',
        ],
        correctIndex: 1,
        explanation:
            'Un tercer reanimador permite relevos más frecuentes, libera a otro para el DEA o la vía aérea, y puede recibir/guiar al equipo de emergencias.',
      ),
      _EvalQuestion(
        question:
            'El objetivo global de la RCP en equipo respecto a las interrupciones es:',
        options: [
          'Que sean largas pero pocas',
          'Minimizarlas: mantener la fracción de compresión alta (≥60%) con pausas < 10 s',
          'No importan las interrupciones',
          'Interrumpir cada minuto para evaluar',
        ],
        correctIndex: 1,
        explanation:
            'La meta es maximizar el tiempo comprimiendo (CCF ≥ 60%, idealmente ≥ 80%) manteniendo cualquier pausa por debajo de 10 segundos.',
      ),
      _EvalQuestion(
        question:
            'En una reanimación con varios intervinientes, ¿qué aporta tener un "líder de equipo"?',
        options: [
          'Nada, todos hacen lo mismo',
          'Coordina los roles, supervisa la calidad y toma decisiones, mejorando la organización',
          'Solo da órdenes sin ayudar',
          'Retrasa la reanimación',
        ],
        correctIndex: 1,
        explanation:
            'Un líder asigna tareas (compresiones, ventilación, DEA), vigila la calidad y los tiempos de relevo y coordina con el SEM, lo que hace la reanimación más eficaz y ordenada.',
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
        question:
            'El paciente estaba consciente y colapsó frente a ti. ¿Cuál es tu primera acción?',
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
        question:
            'El paciente tenía síntomas 30 minutos antes del paro. ¿Afecta esto el protocolo de RCP?',
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
        question:
            'Tras 2 minutos de RCP el paciente recupera pulso. ¿Cuál es el siguiente paso?',
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
      _EvalQuestion(
        question: '¿Cuáles son los síntomas típicos de un infarto?',
        options: [
          'Dolor de cabeza y fiebre',
          'Dolor opresivo en el pecho que puede irradiarse a brazo izquierdo, mandíbula o espalda, con sudoración y náuseas',
          'Dolor solo al moverse',
          'Picor generalizado',
        ],
        correctIndex: 1,
        explanation:
            'El cuadro clásico es dolor/opresión retroesternal, a veces irradiado a brazo izquierdo, mandíbula, cuello o espalda, acompañado de sudor frío, náuseas y dificultad para respirar.',
      ),
      _EvalQuestion(
        question:
            'En mujeres, personas mayores y diabéticos, el infarto puede presentarse...',
        options: [
          'Siempre con dolor intenso de pecho',
          'De forma atípica: fatiga, malestar epigástrico, disnea o náuseas, sin dolor torácico marcado',
          'Sin ningún síntoma jamás',
          'Solo con dolor de piernas',
        ],
        correctIndex: 1,
        explanation:
            'Las presentaciones atípicas (cansancio extremo, molestia en "boca del estómago", falta de aire, náuseas) son frecuentes en mujeres, ancianos y diabéticos, y retrasan la consulta.',
      ),
      _EvalQuestion(
        question:
            'Una persona consciente con dolor torácico sugestivo de infarto. ¿Primera acción?',
        options: [
          'Llevarla tú mismo al hospital en coche',
          'Llamar al 123 y mantenerla en reposo',
          'Darle de comer',
          'Que camine para "activarse"',
        ],
        correctIndex: 1,
        explanation:
            'Se activa de inmediato el SEM y se mantiene a la persona en reposo. La ambulancia puede iniciar tratamiento y desfibrilar si entra en paro durante el traslado.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué no es recomendable llevar tú mismo al paciente al hospital?',
        options: [
          'Por el tráfico',
          'Porque la ambulancia puede tratarlo y desfibrilarlo en ruta si sufre un paro',
          'Porque es más caro',
          'No hay ninguna razón',
        ],
        correctIndex: 1,
        explanation:
            'Si el paciente entra en FV durante el trayecto, en un coche particular no se puede hacer nada; en cambio el SEM puede reanimar y desfibrilar de inmediato.',
      ),
      _EvalQuestion(
        question:
            'Respecto a la aspirina en el dolor torácico, ¿qué es correcto?',
        options: [
          'Nunca se da',
          'Puede ayudar masticar aspirina si no hay alergia ni contraindicación, idealmente orientado por el SEM',
          'Se dan 10 comprimidos',
          'Se administra por vía intravenosa por el rescatador',
        ],
        correctIndex: 1,
        explanation:
            'La aspirina masticada (antiagregante) puede ser beneficiosa en el infarto si no hay alergia ni contraindicación; conviene seguir la indicación del operador del 123.',
      ),
      _EvalQuestion(
        question:
            '¿En qué posición conviene mantener a un paciente consciente con dolor torácico?',
        options: [
          'De pie y caminando',
          'En reposo, semisentado y cómodo, evitando esfuerzos',
          'Boca abajo',
          'Corriendo para activar el corazón',
        ],
        correctIndex: 1,
        explanation:
            'El reposo reduce la demanda de oxígeno del corazón. Una posición semisentada cómoda suele aliviar y se evita cualquier esfuerzo físico.',
      ),
      _EvalQuestion(
        question:
            'El paciente tiene nitroglicerina prescrita por su médico. ¿Qué puedes hacer?',
        options: [
          'Darle la de otra persona',
          'Ayudarle a tomar SU propia medicación según indicación, vigilando que no esté hipotenso',
          'Darle el triple de dosis',
          'Prohibirle tomarla',
        ],
        correctIndex: 1,
        explanation:
            'Puedes ayudar al paciente a tomar su propia nitroglicerina prescrita. No se administra la de otra persona y se vigila, ya que puede bajar la tensión.',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el primer eslabón de la cadena de supervivencia extrahospitalaria?',
        options: [
          'La desfibrilación',
          'El reconocimiento del paro y la activación del sistema de emergencias',
          'Los cuidados post-paro',
          'El traslado al hospital',
        ],
        correctIndex: 1,
        explanation:
            'La cadena empieza por reconocer la emergencia y activar el SEM, seguido de RCP precoz, desfibrilación temprana, soporte vital avanzado y cuidados post-paro.',
      ),
      _EvalQuestion(
        question:
            'El paro que sigue a un infarto frecuentemente presenta un ritmo...',
        options: [
          'Asistolia siempre',
          'Desfibrilable (fibrilación ventricular), tratable con DEA',
          'Bradicardia leve',
          'No tiene ritmo definido',
        ],
        correctIndex: 1,
        explanation:
            'El paro por infarto suele iniciarse como fibrilación ventricular, un ritmo desfibrilable. Por eso la desfibrilación precoz es decisiva en estos pacientes.',
      ),
      _EvalQuestion(
        question:
            'Mientras esperas al SEM con el paciente consciente, ¿qué medida de apoyo es adecuada?',
        options: [
          'Darle una comida copiosa',
          'Aflojar la ropa ajustada, tranquilizarlo y vigilar su nivel de conciencia',
          'Hacerle correr',
          'Dejarlo solo',
        ],
        correctIndex: 1,
        explanation:
            'Se afloja la ropa, se tranquiliza (la ansiedad aumenta el consumo de oxígeno) y se vigila estrechamente por si se deteriora y hay que iniciar RCP.',
      ),
      _EvalQuestion(
        question:
            '¿Debe comer o beber un paciente con dolor torácico agudo?',
        options: [
          'Sí, conviene que beba mucha agua',
          'No: se mantiene en ayunas por posibles procedimientos y riesgo de broncoaspiración',
          'Sí, que coma algo dulce',
          'Da igual',
        ],
        correctIndex: 1,
        explanation:
            'Se evita dar comida o bebida: el paciente puede necesitar procedimientos urgentes y, si se deteriora, el estómago lleno aumenta el riesgo de broncoaspiración.',
      ),
      _EvalQuestion(
        question: 'La frase "tiempo es músculo" significa que...',
        options: [
          'Hay que hacer ejercicio',
          'Cuanto antes se restablece el flujo coronario, menos músculo cardíaco se pierde',
          'El músculo crece con el tiempo',
          'No tiene relación con el infarto',
        ],
        correctIndex: 1,
        explanation:
            'En el infarto, cada minuto de oclusión destruye más miocardio. La reperfusión precoz (en el hospital) salva músculo cardíaco y mejora el pronóstico.',
      ),
      _EvalQuestion(
        question:
            'El paciente colapsa: sin pulso ni respiración. ¿Cuánto mejora la RCP precoz su pronóstico?',
        options: [
          'No cambia nada',
          'La RCP precoz de calidad puede duplicar o triplicar la supervivencia',
          'Lo empeora',
          'Solo ayuda en el hospital',
        ],
        correctIndex: 1,
        explanation:
            'Iniciar RCP de inmediato mantiene el flujo a cerebro y corazón y, combinada con desfibrilación temprana, puede duplicar o triplicar las probabilidades de sobrevivir.',
      ),
      _EvalQuestion(
        question:
            'Aunque el paciente esté consciente con dolor torácico, ¿por qué conviene tener el DEA cerca?',
        options: [
          'Por estética',
          'Porque puede deteriorarse a fibrilación ventricular en cualquier momento',
          'Para medir la tensión',
          'No es necesario',
        ],
        correctIndex: 1,
        explanation:
            'El riesgo de arritmia mortal (FV) es alto en las primeras horas del infarto. Tener el DEA preparado permite desfibrilar sin demora si entra en paro.',
      ),
      _EvalQuestion(
        question:
            'Recupera el pulso tras la RCP pero sigue inconsciente. ¿Qué haces?',
        options: [
          'Lo sientas y le das agua',
          'Lo colocas en posición lateral de seguridad (sin trauma), vigilas respiración/pulso y mantienes el DEA listo',
          'Lo dejas solo',
          'Reinicias compresiones igualmente',
        ],
        correctIndex: 1,
        explanation:
            'Tras el ROSC, si respira pero no responde, se coloca en posición lateral de seguridad, se monitorizan constantemente respiración y pulso, y se mantiene el DEA disponible por si recae.',
      ),
      _EvalQuestion(
        question: '¿Qué significa "ROSC"?',
        options: [
          'Un tipo de medicamento',
          'Recuperación de la circulación espontánea (el corazón vuelve a generar pulso eficaz)',
          'Un ritmo desfibrilable',
          'Un modelo de DEA',
        ],
        correctIndex: 1,
        explanation:
            'ROSC (del inglés "Return Of Spontaneous Circulation") es la recuperación de la circulación espontánea: la víctima recupera pulso. Entonces se pasa a los cuidados post-paro y la vigilancia.',
      ),
    ],
  ),

  // 11. Atragantamiento en lactante
  _EvalScenario(
    id: 'eval_ovace_lactante',
    title: 'OVACE Lactante (<1 año)',
    subtitle: 'Golpes en espalda + compresiones torácicas',
    caseText:
        'Bebé de 8 meses se atraganta con un trozo de comida durante el almuerzo. No puede llorar ni toser, se torna cianótico. Obstrucción completa de la vía aérea.',
    color: const Color(0xFFFF6B9D),
    icon: Icons.child_friendly_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la maniobra correcta de desobstrucción en un lactante consciente?',
        options: [
          'Maniobra de Heimlich (empujes abdominales)',
          '5 golpes en la espalda + 5 compresiones torácicas, alternados',
          'Solo barrido digital de la boca',
          'Sacudir al bebé boca abajo',
        ],
        correctIndex: 1,
        explanation:
            'AHA: En lactantes se alternan 5 golpes interescapulares con 5 compresiones torácicas (con dos dedos), en ciclos hasta expulsar el objeto. NUNCA se usan empujes abdominales por riesgo de lesión de órganos.',
      ),
      _EvalQuestion(
        question: '¿Cómo se posiciona al lactante para los golpes en la espalda?',
        options: [
          'Sentado y erguido sobre tus piernas',
          'Boca arriba sobre tu antebrazo',
          'Boca abajo sobre tu antebrazo, con la cabeza más baja que el tronco',
          'De pie, sujetándolo por los brazos',
        ],
        correctIndex: 2,
        explanation:
            'Se coloca boca abajo apoyado sobre tu antebrazo, sujetando la mandíbula, con la cabeza más baja que el tronco. Se dan 5 golpes firmes entre los omóplatos con el talón de la mano.',
      ),
      _EvalQuestion(
        question: 'El lactante pierde el conocimiento. ¿Qué debes hacer?',
        options: [
          'Continuar solo con golpes en la espalda',
          'Hacer un barrido digital a ciegas para sacar el objeto',
          'Iniciar RCP; antes de cada ventilación inspecciona la boca y retira el objeto solo si lo ves',
          'Esperar a que reaccione solo',
        ],
        correctIndex: 2,
        explanation:
            'AHA: Si pierde el conocimiento, inicia RCP. Antes de cada serie de ventilaciones, abre la boca e inspecciona; retira el objeto únicamente si es visible. El barrido digital a ciegas está contraindicado: puede impactar más el objeto.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué NO se usan empujes abdominales (Heimlich) en lactantes?',
        options: [
          'Porque el bebé es demasiado pequeño para sujetarlo',
          'Por el riesgo de lesionar órganos abdominales como el hígado',
          'Porque no son efectivos en ningún caso',
          'Porque solo se permiten en mayores de 5 años',
        ],
        correctIndex: 1,
        explanation:
            'El hígado del lactante es proporcionalmente grande y poco protegido por la parrilla costal. Los empujes abdominales podrían causar lesiones graves, por eso se sustituyen por compresiones torácicas.',
      ),
      _EvalQuestion(
        question:
            'El bebé se atraganta pero TOSE con fuerza y llora. ¿Qué haces?',
        options: [
          'Golpes en la espalda de inmediato',
          'Dejarlo toser y vigilarlo de cerca, sin maniobras',
          'Compresiones torácicas',
          'Meterle el dedo en la boca',
        ],
        correctIndex: 1,
        explanation:
            'Si tose con fuerza y llora (obstrucción leve), la propia tos es el mejor mecanismo. Se vigila estrechamente y solo se interviene si la obstrucción pasa a ser grave.',
      ),
      _EvalQuestion(
        question:
            '¿Cuántos golpes en la espalda y cuántas compresiones torácicas se alternan?',
        options: [
          '3 y 3',
          '5 golpes en la espalda y 5 compresiones torácicas',
          '10 y 10',
          '2 y 2',
        ],
        correctIndex: 1,
        explanation:
            'Se alternan ciclos de 5 golpes interescapulares con 5 compresiones torácicas hasta expulsar el objeto o hasta que el lactante quede inconsciente.',
      ),
      _EvalQuestion(
        question: '¿Con qué das los golpes en la espalda al lactante?',
        options: [
          'Con el puño cerrado',
          'Con el talón de la mano, entre los omóplatos',
          'Con dos dedos',
          'Con toda la palma muy suave',
        ],
        correctIndex: 1,
        explanation:
            'Se dan 5 golpes firmes con el talón de la mano en la zona interescapular, con el bebé boca abajo sobre el antebrazo y la cabeza más baja que el tronco.',
      ),
      _EvalQuestion(
        question:
            '¿Cómo se dan las compresiones torácicas en la maniobra de OVACE del lactante?',
        options: [
          'Con el talón de la mano',
          'Con dos dedos en el centro del pecho (sobre el esternón), bebé boca arriba',
          'Con los dos pulgares solamente',
          'Empujando el abdomen',
        ],
        correctIndex: 1,
        explanation:
            'Se voltea al bebé boca arriba y se dan 5 compresiones con dos dedos en el centro del pecho (mitad inferior del esternón), más lentas y profundas que en la RCP.',
      ),
      _EvalQuestion(
        question:
            'Durante la maniobra, ¿en qué posición debe estar la cabeza del bebé?',
        options: [
          'Más alta que el cuerpo',
          'Más baja que el tronco para favorecer la salida del objeto',
          'Girada al máximo',
          'Da igual la posición',
        ],
        correctIndex: 1,
        explanation:
            'Tanto para los golpes (boca abajo) como para las compresiones (boca arriba), la cabeza se mantiene más baja que el tronco, ayudando a la gravedad a expulsar el cuerpo extraño.',
      ),
      _EvalQuestion(
        question: 'El lactante queda inconsciente durante el atragantamiento. ¿Qué haces?',
        options: [
          'Seguir solo con golpes en la espalda',
          'Iniciar RCP; antes de ventilar, mirar la boca y retirar el objeto solo si lo ves',
          'Barrido digital a ciegas',
          'Esperar a que reaccione',
        ],
        correctIndex: 1,
        explanation:
            'Si pierde el conocimiento, se inicia RCP. Cada vez que se abra la vía aérea para ventilar, se inspecciona la boca y se retira el objeto únicamente si es visible.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué NO se hace barrido digital a ciegas en el lactante?',
        options: [
          'Porque es lento',
          'Porque puede empujar el objeto más adentro y dañar la vía aérea',
          'Porque ensucia',
          'No está contraindicado',
        ],
        correctIndex: 1,
        explanation:
            'El barrido a ciegas puede impactar más el cuerpo extraño y lesionar la boca/faringe del bebé. Solo se extrae si se ve con claridad.',
      ),
      _EvalQuestion(
        question:
            'Tras expulsar el objeto, el bebé respira con normalidad. ¿Qué recomiendas?',
        options: [
          'Nada, todo resuelto',
          'Valoración médica, porque puede quedar material residual o lesión en la vía aérea',
          'Darle de comer enseguida',
          'Repetir las maniobras por seguridad',
        ],
        correctIndex: 1,
        explanation:
            'Aunque mejore, conviene una valoración médica: puede haber restos del objeto, irritación o lesión, especialmente si las maniobras fueron intensas.',
      ),
      _EvalQuestion(
        question:
            'Estás solo con el lactante atragantado e inconsciente. ¿Cuándo llamas al 123?',
        options: [
          'Antes de iniciar cualquier maniobra',
          'Tras unos 2 minutos de RCP, o activando el altavoz mientras reanimas',
          'Nunca',
          'Solo al final',
        ],
        correctIndex: 1,
        explanation:
            'Si estás solo, inicia las maniobras/RCP de inmediato y activa el SEM tras unos 2 minutos, o usa el altavoz del teléfono para no interrumpir la reanimación.',
      ),
      _EvalQuestion(
        question:
            '¿Qué objetos suponen mayor riesgo de atragantamiento en lactantes?',
        options: [
          'Solo líquidos',
          'Trozos de comida (uvas, frutos secos, salchicha) y objetos pequeños (piezas, botones, globos)',
          'Solo el agua',
          'La leche materna',
        ],
        correctIndex: 1,
        explanation:
            'Frutos secos, uvas enteras, trozos grandes de comida y objetos pequeños (monedas, piezas, globos desinflados) son causas frecuentes. La prevención es clave.',
      ),
      _EvalQuestion(
        question:
            'Las compresiones torácicas de la maniobra OVACE comparadas con las de la RCP son...',
        options: [
          'Más rápidas y superficiales',
          'Algo más lentas y enérgicas, buscando generar presión para expulsar el objeto',
          'Idénticas en todo',
          'Sobre el abdomen',
        ],
        correctIndex: 1,
        explanation:
            'En la desobstrucción se busca una compresión algo más lenta y vigorosa para crear presión que expulse el cuerpo extraño, a diferencia del ritmo sostenido de la RCP.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué se sujeta la mandíbula del bebé durante los golpes en la espalda?',
        options: [
          'Para que no hable',
          'Para sostener la cabeza y el cuello, manteniéndolos firmes y seguros',
          'Para abrirle la boca',
          'No se sujeta',
        ],
        correctIndex: 1,
        explanation:
            'Se sostiene la mandíbula y la cabeza con la mano para dar soporte al cuello del lactante mientras está boca abajo sobre el antebrazo, evitando lesiones.',
      ),
      _EvalQuestion(
        question:
            'En el atragantamiento del lactante, ¿se usa alguna vez el Heimlich (empuje abdominal)?',
        options: [
          'Sí, igual que en adultos',
          'No: en lactantes se usan golpes en la espalda y compresiones torácicas, nunca empujes abdominales',
          'Solo si es mayor de 6 meses',
          'Solo si está consciente',
        ],
        correctIndex: 1,
        explanation:
            'El Heimlich no se aplica en lactantes por el riesgo de lesión de órganos abdominales. Siempre se combinan golpes interescapulares y compresiones torácicas.',
      ),
      _EvalQuestion(
        question:
            'Mientras realizas las maniobras, ¿qué vigilas para decidir cómo seguir?',
        options: [
          'El color de la ropa',
          'Si expulsa el objeto, si empieza a toser/llorar, o si pierde el conocimiento',
          'La hora exacta',
          'La temperatura ambiente',
        ],
        correctIndex: 1,
        explanation:
            'Se observa si sale el objeto, si recupera tos/llanto eficaz (entonces se vigila) o si pierde la conciencia (entonces se inicia RCP).',
      ),
      _EvalQuestion(
        question:
            'Si el lactante recupera el llanto y respira tras un episodio leve, lo correcto es:',
        options: [
          'Forzar más maniobras',
          'Mantener la calma, vigilarlo y consultar a un profesional si hay dudas',
          'Acostarlo y dejarlo solo',
          'Darle agua a la fuerza',
        ],
        correctIndex: 1,
        explanation:
            'Si la obstrucción se resuelve y el bebé respira y llora con normalidad, se mantiene la observación y se consulta ante cualquier signo de dificultad respiratoria posterior.',
      ),
      _EvalQuestion(
        question:
            '¿Cómo se PREVIENE el atragantamiento en lactantes y niños pequeños?',
        options: [
          'Dándoles frutos secos enteros',
          'Supervisando las comidas, troceando los alimentos y evitando frutos secos, uvas enteras y objetos pequeños',
          'Dejándolos comer solos sin vigilancia',
          'No tomando ninguna medida',
        ],
        correctIndex: 1,
        explanation:
            'La prevención es clave: supervisar siempre las comidas, trocear los alimentos en piezas pequeñas, evitar frutos secos/uvas enteras y mantener fuera de su alcance objetos pequeños (piezas, botones, globos).',
      ),
    ],
  ),

  // 12. RCP en embarazada
  _EvalScenario(
    id: 'eval_embarazada',
    title: 'Paro en Embarazada',
    subtitle: 'Desplazamiento uterino · Compresión aortocava',
    caseText:
        'Gestante de unas 32 semanas colapsa en la sala de espera. Sin pulso ni respiración. Se confirma paro cardíaco.',
    color: const Color(0xFFEC4899),
    icon: Icons.pregnant_woman_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            'Durante las compresiones, ¿qué maniobra adicional es clave en una embarazada?',
        options: [
          'Comprimir más fuerte de lo habitual',
          'Desplazamiento uterino manual hacia la izquierda',
          'Elevar las piernas de la paciente',
          'Comprimir sobre el abdomen',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020: Se realiza desplazamiento uterino manual hacia la izquierda para liberar la compresión que el útero grávido ejerce sobre la vena cava inferior y la aorta, mejorando el retorno venoso durante la RCP.',
      ),
      _EvalQuestion(
        question: '¿Dónde se colocan las manos para las compresiones?',
        options: [
          'Sobre el abdomen, encima del útero',
          'En el centro del esternón, igual que en un adulto estándar',
          'En el lado izquierdo del tórax',
          'Sobre la parte alta del abdomen',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020: La posición de las manos es la estándar, en el centro del esternón. La frecuencia (100–120/min) y profundidad (5–6 cm) no cambian.',
      ),
      _EvalQuestion(
        question: '¿Se debe usar el DEA en una embarazada en paro?',
        options: [
          'No, está contraindicado en el embarazo',
          'Solo después del parto',
          'Sí, se usa igual que en cualquier adulto',
          'Solo si hay un médico presente',
        ],
        correctIndex: 2,
        explanation:
            'El DEA se usa con normalidad en embarazadas. La desfibrilación no daña al feto y no debe retrasarse. Sigue el protocolo estándar de RCP + DEA.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué el útero grávido compromete la RCP si no se desplaza?',
        options: [
          'Aumenta la temperatura corporal',
          'Comprime la vena cava inferior y la aorta, reduciendo el retorno venoso y el gasto cardíaco',
          'Impide ventilar a la paciente',
          'No tiene ningún efecto real',
        ],
        correctIndex: 1,
        explanation:
            'A partir del segundo trimestre el útero comprime los grandes vasos en posición supina (compresión aortocava), disminuyendo hasta un 30% el gasto cardíaco generado por las compresiones. El desplazamiento manual lo corrige.',
      ),
      _EvalQuestion(
        question:
            '¿Desde qué momento del embarazo cobra importancia el desplazamiento uterino?',
        options: [
          'Desde la primera semana',
          'Cuando el útero es palpable a la altura del ombligo o por encima (aprox. ≥ 20 semanas)',
          'Solo en el parto',
          'Nunca importa',
        ],
        correctIndex: 1,
        explanation:
            'Cuando el fondo uterino alcanza o supera el ombligo (alrededor de las 20 semanas), el útero ya comprime la cava en decúbito supino y se indica el desplazamiento manual a la izquierda.',
      ),
      _EvalQuestion(
        question: '¿Cómo se realiza el desplazamiento uterino manual?',
        options: [
          'Presionando el útero hacia abajo',
          'Empujando/tirando del útero hacia la izquierda de la paciente con una o dos manos',
          'Comprimiéndolo con fuerza',
          'Levantando las piernas',
        ],
        correctIndex: 1,
        explanation:
            'Un reanimador desplaza el útero hacia la izquierda (empujándolo desde la derecha o traccionándolo) para liberar la vena cava, mientras otro mantiene las compresiones.',
      ),
      _EvalQuestion(
        question:
            'Durante la RCP, ¿qué posición de la paciente embarazada se prefiere actualmente?',
        options: [
          'Inclinada lateralmente sobre una cuña',
          'Supina (boca arriba) con desplazamiento uterino manual a la izquierda',
          'Sentada',
          'Boca abajo',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020: Se prefiere mantenerla en decúbito supino con desplazamiento uterino manual, ya que inclinar el cuerpo reduce la eficacia de las compresiones.',
      ),
      _EvalQuestion(
        question:
            'La frecuencia y profundidad de las compresiones en la embarazada son...',
        options: [
          'Más lentas y superficiales',
          'Las mismas que en cualquier adulto (100–120/min, 5–6 cm)',
          'Mucho más profundas',
          'No se comprime en embarazadas',
        ],
        correctIndex: 1,
        explanation:
            'No cambian: 100–120 compresiones por minuto y 5–6 cm de profundidad, en el centro del esternón, con recoil completo.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué la vía aérea de la embarazada se considera de mayor riesgo?',
        options: [
          'No hay diferencias',
          'Hay más edema y mayor riesgo de regurgitación/aspiración',
          'Tienen la tráquea más ancha',
          'Respiran mejor',
        ],
        correctIndex: 1,
        explanation:
            'El edema de la vía aérea y el mayor riesgo de aspiración (por presión abdominal y vaciamiento gástrico lento) hacen la ventilación más delicada; se ventila con cuidado.',
      ),
      _EvalQuestion(
        question:
            '¿Qué procedimiento hospitalario puede plantearse si no hay ROSC en pocos minutos?',
        options: [
          'No hay nada que hacer',
          'Cesárea/histerotomía de reanimación ("perimortem") para mejorar la reanimación materna y salvar al feto',
          'Suspender la RCP',
          'Solo administrar líquidos',
        ],
        correctIndex: 1,
        explanation:
            'Si no se recupera circulación en unos 4–5 minutos de RCP, el equipo hospitalario puede realizar una cesárea de reanimación: mejora la hemodinámica materna y puede salvar al feto.',
      ),
      _EvalQuestion(
        question:
            'Una embarazada avanzada consciente se atraganta (obstrucción grave). ¿Qué maniobra usas?',
        options: [
          'Empujes abdominales (Heimlich) clásicos',
          'Empujes torácicos sobre el esternón, en lugar de abdominales',
          'No se hace nada',
          'Solo golpes en la cabeza',
        ],
        correctIndex: 1,
        explanation:
            'El abdomen grávido impide empujes abdominales seguros: se sustituyen por empujes torácicos (sobre el esternón), alternados con golpes en la espalda.',
      ),
      _EvalQuestion(
        question:
            'Una embarazada consciente se marea al estar boca arriba. ¿Qué haces?',
        options: [
          'La dejas boca arriba',
          'La colocas en decúbito lateral izquierdo para aliviar la compresión de la cava',
          'La pones de pie',
          'La sientas inclinada hacia adelante',
        ],
        correctIndex: 1,
        explanation:
            'El síndrome de hipotensión supina mejora colocándola sobre su lado izquierdo, lo que descomprime la vena cava inferior y restaura el retorno venoso.',
      ),
      _EvalQuestion(
        question: '¿Se usa el DEA y se administran las descargas igual?',
        options: [
          'No, se reducen a la mitad',
          'Sí, con la energía habitual; la desfibrilación no daña al feto',
          'Solo media descarga',
          'No se desfibrila nunca en el embarazo',
        ],
        correctIndex: 1,
        explanation:
            'La desfibrilación se realiza con la energía estándar. Es segura para el feto y no debe retrasarse en un ritmo desfibrilable.',
      ),
      _EvalQuestion(
        question:
            'Si hay varios reanimadores, ¿quién se encarga del desplazamiento uterino?',
        options: [
          'Nadie, no es necesario',
          'Un reanimador dedicado, mientras otro comprime y otro ventila',
          'El que comprime, soltando el pecho',
          'Se turnan sin comprimir',
        ],
        correctIndex: 1,
        explanation:
            'Lo ideal es que un reanimador se ocupe en exclusiva del desplazamiento uterino izquierdo de forma continua, sin interferir con las compresiones del otro.',
      ),
      _EvalQuestion(
        question:
            '¿Debe retrasarse el inicio de la RCP por tratarse de una embarazada?',
        options: [
          'Sí, hay que esperar a un ginecólogo',
          'No: se inicia RCP de inmediato, añadiendo el desplazamiento uterino',
          'Sí, hasta confirmar las semanas de gestación',
          'Solo se ventila',
        ],
        correctIndex: 1,
        explanation:
            'La RCP de alta calidad se inicia sin demora; el desplazamiento uterino es una medida añadida, no un motivo para retrasar las compresiones.',
      ),
      _EvalQuestion(
        question:
            'Tras recuperar el pulso (ROSC), si la embarazada queda inconsciente y respira, ¿qué posición?',
        options: [
          'Boca arriba sin más',
          'Decúbito lateral izquierdo (posición de seguridad sobre el lado izquierdo)',
          'Sentada',
          'Sobre el lado derecho',
        ],
        correctIndex: 1,
        explanation:
            'Se coloca sobre el lado izquierdo: mantiene la vía aérea y evita la compresión aortocava, mejorando el retorno venoso mientras se vigila y llega el SEM.',
      ),
      _EvalQuestion(
        question:
            'Las causas de paro propias del embarazo incluyen, entre otras:',
        options: [
          'Solo el infarto',
          'Hemorragia, embolia, preeclampsia/eclampsia, sepsis y complicaciones anestésicas',
          'Únicamente alergias',
          'Ninguna específica',
        ],
        correctIndex: 1,
        explanation:
            'Las emergencias obstétricas como hemorragia masiva, embolia (incluida la de líquido amniótico), eclampsia, sepsis o causas anestésicas son etiologías frecuentes que el equipo tratará.',
      ),
      _EvalQuestion(
        question:
            'Al ventilar a una embarazada en paro, hay que tener especial cuidado con...',
        options: [
          'Hiperventilar sin límite',
          'La regurgitación y la broncoaspiración; ventilar con volúmenes medidos',
          'No ventilar nunca',
          'Ventilar a máxima presión',
        ],
        correctIndex: 1,
        explanation:
            'Por el riesgo aumentado de regurgitación, se ventila con volúmenes que solo eleven el tórax, evitando insuflar el estómago, y se protege la vía aérea.',
      ),
      _EvalQuestion(
        question:
            'El objetivo prioritario al reanimar a una embarazada es...',
        options: [
          'Atender primero al feto',
          'Reanimar bien a la madre: la mejor forma de ayudar al feto es lograr el ROSC materno',
          'Esperar a la cesárea',
          'Solo monitorizar',
        ],
        correctIndex: 1,
        explanation:
            'La supervivencia fetal depende de la circulación materna. Por eso la prioridad es una RCP materna de alta calidad con desplazamiento uterino, desfibrilación y soporte avanzado.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué la embarazada dessatura (le baja el oxígeno) más rápido?',
        options: [
          'Tiene más reserva de oxígeno',
          'Tiene menor reserva de oxígeno y mayor consumo, por lo que la ventilación precoz es muy importante',
          'No respira durante el embarazo',
          'El feto le aporta oxígeno',
        ],
        correctIndex: 1,
        explanation:
            'En el embarazo la capacidad funcional pulmonar disminuye y el consumo de oxígeno aumenta, por lo que la hipoxia se instaura más rápido. La oxigenación y ventilación tempranas son prioritarias.',
      ),
    ],
  ),

  // 13. Hipotermia severa
  _EvalScenario(
    id: 'eval_hipotermia',
    title: 'Paro por Hipotermia',
    subtitle: '"No está muerto hasta calentar y muerto"',
    caseText:
        'Excursionista rescatado de la montaña tras varias horas en la nieve. Inconsciente, piel muy fría, no se palpa pulso con claridad. Hipotermia severa.',
    color: AppColors.cyan,
    icon: Icons.ac_unit_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            'En hipotermia severa, ¿cuánto tiempo se evalúa pulso y respiración antes de iniciar RCP?',
        options: [
          'Solo 5 segundos como siempre',
          'Hasta 30–60 segundos, porque puede haber bradicardia extrema',
          '5 minutos completos',
          'No se evalúa, se inicia RCP de inmediato',
        ],
        correctIndex: 1,
        explanation:
            'AHA: En hipotermia se evalúan pulso y respiración durante 30–60 segundos. El frío produce bradicardia y bradipnea extremas que pueden confundirse con paro; comprimir sobre un corazón que aún late podría inducir FV.',
      ),
      _EvalQuestion(
        question:
            '¿Qué significa el principio "no está muerto hasta que está caliente y muerto"?',
        options: [
          'Que se debe declarar la muerte de inmediato por el frío',
          'Que se continúa la RCP y el recalentamiento; la hipotermia protege el cerebro y puede haber recuperación',
          'Que solo se aplica a niños',
          'Que no se debe iniciar RCP en pacientes fríos',
        ],
        correctIndex: 1,
        explanation:
            'La hipotermia reduce el consumo de oxígeno cerebral y puede ser neuroprotectora. Se han descrito recuperaciones completas tras paros prolongados en frío, por lo que la reanimación se mantiene durante el recalentamiento.',
      ),
      _EvalQuestion(
        question:
            'El paciente está en FV. ¿Cómo se maneja la desfibrilación en hipotermia severa (<30 °C)?',
        options: [
          'Descargas repetidas sin límite hasta revertir',
          'Dar las descargas indicadas y priorizar el recalentamiento; pueden ser inefectivas hasta calentar',
          'No desfibrilar nunca en hipotermia',
          'Esperar 10 minutos entre cada descarga',
        ],
        correctIndex: 1,
        explanation:
            'En hipotermia severa el miocardio frío responde mal a la desfibrilación. Se administran las descargas indicadas pero la prioridad es continuar RCP y recalentar; conforme sube la temperatura, el corazón responde mejor a los choques.',
      ),
      _EvalQuestion(
        question: '¿Qué precaución es importante al manipular a la víctima?',
        options: [
          'Moverla rápidamente y con energía',
          'Manipularla con suavidad, retirar ropa mojada y aislarla del frío',
          'Frotar enérgicamente las extremidades',
          'Sumergirla en agua caliente de inmediato',
        ],
        correctIndex: 1,
        explanation:
            'Los movimientos bruscos pueden desencadenar fibrilación ventricular en el corazón hipotérmico. Manipula con cuidado, retira la ropa húmeda, aísla del frío y abriga; evita frotar las extremidades.',
      ),
      _EvalQuestion(
        question: '¿Qué es la hipotermia?',
        options: [
          'Temperatura corporal mayor de 38 °C',
          'Descenso de la temperatura central por debajo de 35 °C',
          'Temperatura normal',
          'Solo sensación de frío en las manos',
        ],
        correctIndex: 1,
        explanation:
            'La hipotermia es el descenso de la temperatura central por debajo de 35 °C. Se clasifica en leve, moderada y severa según la temperatura y los signos clínicos.',
      ),
      _EvalQuestion(
        question:
            '¿Qué signo es característico de la hipotermia leve y desaparece en la severa?',
        options: [
          'Sudoración',
          'Los escalofríos (temblor); desaparecen al agravarse la hipotermia',
          'Fiebre',
          'Pupilas dilatadas',
        ],
        correctIndex: 1,
        explanation:
            'En la hipotermia leve hay temblor intenso (mecanismo para generar calor). Cuando la hipotermia es severa, los escalofríos cesan, lo que es un signo de gravedad.',
      ),
      _EvalQuestion(
        question:
            'Lo PRIMERO al rescatar a una víctima de hipotermia es...',
        options: [
          'Darle alcohol para que entre en calor',
          'Sacarla del ambiente frío, retirar ropa mojada y aislarla del suelo y del viento',
          'Hacerla correr',
          'Frotarle fuerte las extremidades',
        ],
        correctIndex: 1,
        explanation:
            'Se interrumpe la pérdida de calor: retirar a la víctima del frío, quitar la ropa húmeda y aislarla del suelo y el viento, abrigándola con material seco.',
      ),
      _EvalQuestion(
        question: '¿Por qué NO se debe dar alcohol a una víctima de hipotermia?',
        options: [
          'Porque sabe mal',
          'Porque dilata los vasos de la piel y aumenta la pérdida de calor',
          'Porque la despierta demasiado',
          'No hay problema en darlo',
        ],
        correctIndex: 1,
        explanation:
            'El alcohol produce vasodilatación cutánea: da sensación de calor pero en realidad acelera la pérdida de calor central y empeora la hipotermia.',
      ),
      _EvalQuestion(
        question:
            'En la víctima consciente con hipotermia leve, ¿qué recalentamiento es adecuado?',
        options: [
          'Sumergirla en agua muy caliente',
          'Recalentamiento pasivo/externo suave: mantas, ambiente cálido y bebidas calientes azucaradas si está despierta y puede tragar',
          'Frotar con nieve',
          'Aplicar calor directo intenso en las extremidades',
        ],
        correctIndex: 1,
        explanation:
            'En hipotermia leve se usa recalentamiento pasivo (mantas, ambiente cálido) y, si está consciente y puede tragar, bebidas calientes y azucaradas. Se evita el calor intenso brusco.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué se evita recalentar bruscamente las extremidades primero?',
        options: [
          'Porque tarda más',
          'Por el riesgo de "afterdrop": sangre fría periférica que retorna al centro y puede causar colapso o arritmias',
          'No hay ningún riesgo',
          'Porque duele',
        ],
        correctIndex: 1,
        explanation:
            'Calentar agresivamente las extremidades moviliza sangre fría y ácida hacia el corazón (fenómeno de afterdrop), pudiendo provocar hipotensión y arritmias. Se prioriza el recalentamiento del tronco.',
      ),
      _EvalQuestion(
        question:
            '¿Cómo afecta la hipotermia a la evaluación de pulso y respiración?',
        options: [
          'No afecta',
          'Bradicardia y bradipnea extremas pueden hacerlos casi imperceptibles; por eso se evalúa 30–60 s',
          'Acelera todo mucho',
          'Hace que el pulso sea muy fuerte',
        ],
        correctIndex: 1,
        explanation:
            'El frío enlentece mucho el corazón y la respiración. Por eso se dedica más tiempo (30–60 s) a comprobar signos de vida antes de iniciar compresiones.',
      ),
      _EvalQuestion(
        question:
            'En hipotermia severa, ¿por qué hay que mover a la víctima con extrema suavidad?',
        options: [
          'Para no despertarla',
          'Porque los movimientos bruscos pueden desencadenar fibrilación ventricular',
          'Por estética',
          'No hace falta tener cuidado',
        ],
        correctIndex: 1,
        explanation:
            'El miocardio hipotérmico es muy irritable; manipulaciones bruscas o movimientos vigorosos pueden inducir FV. La movilización debe ser cuidadosa y suave.',
      ),
      _EvalQuestion(
        question:
            'Si la víctima hipotérmica está en paro, ¿cómo es la RCP?',
        options: [
          'No se hace RCP en hipotérmicos',
          'Se realiza RCP estándar; puede ser prolongada y se mantiene durante el recalentamiento',
          'Solo ventilaciones',
          'Compresiones muy lentas',
        ],
        correctIndex: 1,
        explanation:
            'La RCP sigue el protocolo estándar y suele prolongarse, ya que la hipotermia protege los órganos. No se suspende basándose solo en el tiempo, sino tras recalentar.',
      ),
      _EvalQuestion(
        question:
            '¿Qué fuentes de calor son adecuadas para una víctima de hipotermia grave en el medio prehospitalario?',
        options: [
          'Calor directo y muy intenso sobre la piel',
          'Calor suave aplicado al tronco (axilas, ingles, tórax) y aislamiento, evitando quemaduras',
          'Sumergirla en agua hirviendo',
          'Frotar con las manos sin parar',
        ],
        correctIndex: 1,
        explanation:
            'Se aplica calor suave en zonas centrales (tronco, axilas, ingles) y se aísla del frío. Se evita el calor intenso directo (riesgo de quemaduras en piel poco sensible) y el masaje de extremidades.',
      ),
      _EvalQuestion(
        question:
            'El principio "no está muerto hasta que está caliente y muerto" implica que...',
        options: [
          'Hay que declarar la muerte rápido',
          'La reanimación debe continuar mientras se recalienta, pues la hipotermia puede ser neuroprotectora',
          'No se reanima a los hipotérmicos',
          'Solo aplica a niños',
        ],
        correctIndex: 1,
        explanation:
            'La hipotermia reduce el metabolismo cerebral y puede permitir recuperación tras paros prolongados. Por eso se mantiene la reanimación hasta haber recalentado a la víctima.',
      ),
      _EvalQuestion(
        question:
            '¿Quiénes son especialmente vulnerables a la hipotermia?',
        options: [
          'Solo los deportistas',
          'Ancianos, lactantes, personas sin hogar, intoxicados por alcohol y politraumatizados',
          'Solo los jóvenes',
          'Nadie en particular',
        ],
        correctIndex: 1,
        explanation:
            'Los extremos de la vida (ancianos y lactantes), las personas en situación de calle, los intoxicados y los pacientes con traumatismos tienen mayor riesgo por menor termorregulación o exposición.',
      ),
      _EvalQuestion(
        question:
            'La víctima hipotérmica en FV no responde a la desfibrilación. ¿Qué prima?',
        options: [
          'Descargar sin parar',
          'Continuar RCP y recalentar; el corazón frío responde mejor a las descargas al subir la temperatura',
          'Suspender la reanimación',
          'Esperar sin hacer nada',
        ],
        correctIndex: 1,
        explanation:
            'El miocardio muy frío suele ser refractario a la desfibrilación. Se dan las descargas indicadas, pero la clave es mantener la RCP y recalentar para recuperar la respuesta eléctrica.',
      ),
      _EvalQuestion(
        question:
            'Una víctima parece "muerta" (rígida, fría, sin pulso evidente) tras exposición al frío. ¿Qué haces?',
        options: [
          'Asumir que está muerta y no actuar',
          'Comprobar signos de vida durante 30–60 s e iniciar RCP si procede; no suspender solo por el aspecto',
          'Frotarla con fuerza para "revivirla"',
          'Darle alcohol',
        ],
        correctIndex: 1,
        explanation:
            'El aspecto puede ser engañoso en la hipotermia profunda. Se evalúa con más tiempo y, si no hay signos de vida, se inicia RCP y recalentamiento; la decisión de cesar es del equipo médico tras recalentar.',
      ),
      _EvalQuestion(
        question:
            'Para prevenir más pérdida de calor durante el traslado, ¿qué medida es clave?',
        options: [
          'Dejarla con la ropa mojada',
          'Aislarla del suelo, protegerla del viento y de la humedad, y cubrirla con material seco',
          'Abrir las ventanas del vehículo',
          'Quitarle toda la ropa y dejarla destapada',
        ],
        correctIndex: 1,
        explanation:
            'El suelo, el viento y la humedad roban calor. Se aísla del suelo, se protege del viento y se cubre con mantas/material seco, manteniendo un ambiente cálido durante el traslado.',
      ),
      _EvalQuestion(
        question:
            'Con ropa mojada, ¿por qué se pierde calor tan rápido?',
        options: [
          'El agua aísla del frío',
          'El agua conduce y evapora el calor mucho más rápido que el aire; por eso se retira la ropa húmeda',
          'No influye la ropa mojada',
          'La ropa mojada calienta',
        ],
        correctIndex: 1,
        explanation:
            'El agua transfiere el calor mucho más rápido que el aire (conducción y evaporación). Mantener ropa mojada acelera la pérdida de calor, por lo que se retira y se seca/abriga a la víctima.',
      ),
    ],
  ),

  // 14. Hemorragia masiva
  _EvalScenario(
    id: 'eval_hemorragia',
    title: 'Hemorragia Masiva',
    subtitle: 'Control de sangrado · Uso de torniquete',
    caseText:
        'Tras un accidente, un hombre presenta una herida profunda en el muslo con sangrado abundante en chorro. Está consciente pero pálido.',
    color: AppColors.red,
    icon: Icons.bloodtype_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question: '¿Cuál es la primera acción para controlar el sangrado?',
        options: [
          'Aplicar un torniquete de inmediato',
          'Presión directa firme y sostenida sobre la herida',
          'Elevar la pierna y esperar',
          'Limpiar la herida con agua antes de actuar',
        ],
        correctIndex: 1,
        explanation:
            'La primera medida es la presión directa firme y continua sobre la herida con un apósito o paño limpio. Controla la mayoría de las hemorragias externas.',
      ),
      _EvalQuestion(
        question:
            'La presión directa no detiene el sangrado arterial. ¿Qué debes hacer?',
        options: [
          'Soltar y volver a presionar varias veces',
          'Colocar un torniquete proximal a la herida (entre la herida y el corazón)',
          'Esperar a que el sangrado se detenga solo',
          'Aplicar hielo sobre la herida',
        ],
        correctIndex: 1,
        explanation:
            'Si la hemorragia de una extremidad no se controla con presión directa, se coloca un torniquete proximal a la herida y se aprieta hasta que cese el sangrado.',
      ),
      _EvalQuestion(
        question: '¿Cómo se coloca correctamente un torniquete?',
        options: [
          'Sobre la propia herida',
          'Sobre la articulación más cercana',
          'Unos 5–7 cm por encima de la herida, nunca sobre una articulación, anotando la hora',
          'Lo más lejos posible de la herida',
        ],
        correctIndex: 2,
        explanation:
            'El torniquete se coloca 5–7 cm por encima de la herida (proximal), nunca sobre una articulación. Se aprieta hasta detener el sangrado y se anota la hora de colocación para el equipo médico.',
      ),
      _EvalQuestion(
        question: 'Una vez colocado el torniquete, ¿se debe aflojar?',
        options: [
          'Sí, cada 10 minutos para que circule la sangre',
          'No, no se afloja hasta que lo haga personal médico',
          'Sí, en cuanto deje de sangrar',
          'Solo si el paciente siente dolor',
        ],
        correctIndex: 1,
        explanation:
            'Una vez colocado, el torniquete NO se afloja en el ámbito prehospitalario: aflojarlo puede reactivar la hemorragia y provocar shock. Solo el personal médico lo retira en condiciones controladas.',
      ),
      _EvalQuestion(
        question:
            '¿Cómo distingues una hemorragia arterial de una venosa?',
        options: [
          'No se pueden distinguir',
          'La arterial sale a chorros/pulsátil y de color rojo brillante; la venosa fluye continua y más oscura',
          'La arterial es de color azul',
          'La venosa sale a chorros',
        ],
        correctIndex: 1,
        explanation:
            'La sangre arterial es roja brillante y sale a borbotones siguiendo el pulso; la venosa es más oscura y fluye de forma continua. La arterial es la más peligrosa.',
      ),
      _EvalQuestion(
        question:
            'Antes de tocar una herida sangrante de otra persona, ¿qué precaución tomas?',
        options: [
          'Lavarte el pelo',
          'Usar guantes u otra barrera para protegerte de fluidos corporales',
          'Quitarte los zapatos',
          'Ninguna',
        ],
        correctIndex: 1,
        explanation:
            'Siempre que sea posible se usan guantes o una barrera para evitar el contacto con sangre y reducir el riesgo de transmisión de enfermedades.',
      ),
      _EvalQuestion(
        question:
            'La presión directa controla el sangrado pero el apósito se empapa. ¿Qué haces?',
        options: [
          'Quitar el apósito empapado y empezar de nuevo',
          'Añadir más apósitos encima sin retirar los anteriores y seguir presionando',
          'Dejar de presionar',
          'Echar agua sobre la herida',
        ],
        correctIndex: 1,
        explanation:
            'No se retira el apósito empapado (arrastraría el coágulo). Se colocan más apósitos encima y se mantiene la presión firme.',
      ),
      _EvalQuestion(
        question:
            '¿Qué es un agente/apósito hemostático y cuándo se usa?',
        options: [
          'Una crema para el dolor',
          'Una gasa con sustancia que favorece la coagulación, útil en heridas donde no se puede poner torniquete (unión, cuello)',
          'Un tipo de torniquete',
          'Un analgésico oral',
        ],
        correctIndex: 1,
        explanation:
            'Los apósitos hemostáticos contienen agentes que aceleran la coagulación. Se empaquetan en la herida con presión, sobre todo en zonas de unión (ingle, axila) o cuello, donde el torniquete no es aplicable.',
      ),
      _EvalQuestion(
        question:
            'En una hemorragia de una extremidad que no cede, ¿qué es prioritario respecto al tiempo?',
        options: [
          'Esperar a ver si para sola',
          'Actuar rápido: una hemorragia masiva puede causar la muerte en minutos',
          'Tomarle la temperatura primero',
          'Buscar el grupo sanguíneo',
        ],
        correctIndex: 1,
        explanation:
            'La hemorragia exanguinante puede ser mortal en pocos minutos. El control rápido del sangrado (presión directa o torniquete) es la prioridad vital inmediata.',
      ),
      _EvalQuestion(
        question:
            'Tras colocar un torniquete, ¿qué información es esencial registrar?',
        options: [
          'El color de la ropa',
          'La hora exacta de colocación (escribirla, p. ej. en la piel/frente o en el dispositivo)',
          'El peso del paciente',
          'Nada',
        ],
        correctIndex: 1,
        explanation:
            'Se anota la hora de colocación, dato clave para el equipo médico (el tiempo de isquemia condiciona el manejo). Suele escribirse en el propio torniquete o en la piel.',
      ),
      _EvalQuestion(
        question:
            'El torniquete está puesto pero la hemorragia continúa. ¿Qué haces?',
        options: [
          'Aflojarlo',
          'Apretarlo más o colocar un segundo torniquete por encima (proximal) del primero',
          'Quitarlo y usar solo gasa',
          'Esperar',
        ],
        correctIndex: 1,
        explanation:
            'Si sigue sangrando, se aprieta más; si aun así no cede, se coloca un segundo torniquete justo por encima (más proximal) del primero. Nunca se afloja.',
      ),
      _EvalQuestion(
        question:
            '¿Qué signos indican que la víctima está entrando en shock hipovolémico?',
        options: [
          'Piel rosada y caliente, pulso lento',
          'Palidez, piel fría y sudorosa, pulso rápido y débil, mareo y confusión',
          'Fiebre alta',
          'Tensión arterial muy alta',
        ],
        correctIndex: 1,
        explanation:
            'El shock por pérdida de sangre cursa con palidez, piel fría y húmeda, taquicardia con pulso débil, sed, mareo, ansiedad y alteración de la conciencia.',
      ),
      _EvalQuestion(
        question:
            'Una víctima consciente con hemorragia controlada muestra signos de shock. ¿Qué posición es útil?',
        options: [
          'Sentada y caminando',
          'Acostada, abrigada para evitar la hipotermia, y vigilada hasta el SEM',
          'Boca abajo',
          'De pie',
        ],
        correctIndex: 1,
        explanation:
            'Se la mantiene acostada y abrigada (la hipotermia agrava la coagulopatía del shock), tranquilizándola y vigilando su estado mientras llega la ayuda.',
      ),
      _EvalQuestion(
        question:
            'Un objeto está clavado (empalado) en la herida que sangra. ¿Qué haces?',
        options: [
          'Retirarlo de inmediato',
          'NO retirarlo: estabilizarlo en su sitio y controlar el sangrado alrededor',
          'Moverlo de un lado a otro',
          'Empujarlo más adentro',
        ],
        correctIndex: 1,
        explanation:
            'Un objeto empalado puede estar taponando vasos; retirarlo puede provocar hemorragia masiva. Se inmoviliza en su posición y se controla el sangrado a su alrededor.',
      ),
      _EvalQuestion(
        question:
            'La hemorragia es en una zona donde no se puede poner torniquete (p. ej. ingle, cuello, abdomen). ¿Qué haces?',
        options: [
          'Poner torniquete igualmente',
          'Presión directa firme y, si está disponible, empaquetar la herida con gasa (hemostática) manteniendo presión',
          'No hacer nada',
          'Elevar la pierna',
        ],
        correctIndex: 1,
        explanation:
            'En zonas de unión o tronco se aplica presión directa intensa y, si se dispone, se empaqueta la herida con gasa (preferiblemente hemostática), manteniendo la compresión hasta el SEM.',
      ),
      _EvalQuestion(
        question:
            'En el enfoque de trauma con hemorragia exanguinante, ¿qué se atiende primero?',
        options: [
          'La vía aérea siempre antes que nada',
          'El control de la hemorragia masiva (la "C" de catástrofe va primero: MARCH/“C-ABC”)',
          'La temperatura',
          'El dolor',
        ],
        correctIndex: 1,
        explanation:
            'En trauma con sangrado catastrófico se prioriza primero detener la hemorragia (esquemas tipo MARCH o C-ABC), porque la exanguinación mata más rápido que la vía aérea en ese contexto.',
      ),
      _EvalQuestion(
        question:
            '¿Es útil un torniquete improvisado si no tienes uno comercial?',
        options: [
          'No sirve de nada',
          'Sí: una banda ancha (no un cordón fino) con un palo para girar y tensar puede salvar la vida',
          'Solo vale el comercial',
          'Se usa un alambre fino',
        ],
        correctIndex: 1,
        explanation:
            'Si no hay torniquete comercial, se improvisa con una tela ancha y un objeto rígido (palo) que se gira para tensar. Debe ser ancho; los materiales finos (cuerda, alambre) cortan y son menos eficaces.',
      ),
      _EvalQuestion(
        question:
            'Tras controlar el sangrado, ¿por qué conviene NO dar de beber a la víctima?',
        options: [
          'Por educación',
          'Porque puede necesitar cirugía/anestesia y por riesgo de vómito y broncoaspiración',
          'Porque el agua diluye la sangre',
          'No hay motivo',
        ],
        correctIndex: 1,
        explanation:
            'Se mantiene en ayunas ante la posibilidad de cirugía urgente y por el riesgo de vómito y broncoaspiración si se deteriora. Se puede humedecer los labios si tiene mucha sed.',
      ),
      _EvalQuestion(
        question:
            'Mientras aplicas presión, ¿qué más debe hacerse de forma simultánea si hay ayuda?',
        options: [
          'Nada más',
          'Activar el SEM (llamar al 123) cuanto antes',
          'Buscar comida',
          'Tomar fotos',
        ],
        correctIndex: 1,
        explanation:
            'Una hemorragia masiva es una emergencia: mientras un reanimador comprime, otro debe activar el sistema de emergencias de inmediato para el traslado y tratamiento definitivo.',
      ),
      _EvalQuestion(
        question:
            'Una herida en el cuero cabelludo sangra de forma muy aparatosa. ¿Qué haces?',
        options: [
          'Torniquete en el cuello',
          'Presión directa firme con un apósito; suele controlarse bien pese al aspecto llamativo',
          'No tocar la herida',
          'Echar agua a chorro',
        ],
        correctIndex: 1,
        explanation:
            'El cuero cabelludo está muy vascularizado y sangra mucho, pero la presión directa firme suele controlarlo bien. Nunca se pone torniquete en el cuello ni se presiona si se sospecha fractura craneal con hundimiento.',
      ),
    ],
  ),

  // 15. Anafilaxia
  _EvalScenario(
    id: 'eval_anafilaxia',
    title: 'Reacción Anafiláctica',
    subtitle: 'Adrenalina IM · Emergencia alérgica',
    caseText:
        'Tras una picadura de abeja, una mujer presenta urticaria generalizada, dificultad para respirar, hinchazón de labios y sensación de mareo. Reacción anafiláctica.',
    color: AppColors.amber,
    icon: Icons.vaccines_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question: '¿Cuál es el tratamiento de primera línea en la anafilaxia?',
        options: [
          'Antihistamínicos orales',
          'Adrenalina (epinefrina) intramuscular',
          'Corticoides inhalados',
          'Salbutamol nebulizado',
        ],
        correctIndex: 1,
        explanation:
            'La adrenalina IM es el tratamiento de elección y no debe retrasarse. Revierte el broncoespasmo, el edema y la hipotensión. Los antihistamínicos y corticoides son coadyuvantes, no sustituyen a la adrenalina.',
      ),
      _EvalQuestion(
        question:
            '¿Dónde y en qué dosis se administra el autoinyector de adrenalina en un adulto?',
        options: [
          'En el glúteo, 1 mg',
          'En la cara anterolateral del muslo, 0.3 mg IM',
          'Por vía intravenosa directa',
          'En el brazo, 0.01 mg',
        ],
        correctIndex: 1,
        explanation:
            'El autoinyector se aplica en la cara anterolateral del muslo (vasto externo), 0.3 mg en adultos (0.15 mg en niños). Puede administrarse incluso a través de la ropa.',
      ),
      _EvalQuestion(
        question:
            'La paciente está mareada e hipotensa pero respira. ¿Qué posición es la adecuada?',
        options: [
          'Sentada e inclinada hacia adelante',
          'De pie para que circule la sangre',
          'Acostada con las piernas elevadas',
          'Boca abajo',
        ],
        correctIndex: 2,
        explanation:
            'Con compromiso circulatorio, se acuesta a la paciente con las piernas elevadas para favorecer el retorno venoso. NUNCA la pongas de pie de repente: puede causar colapso. Si predomina la dificultad respiratoria, se permite que esté semisentada.',
      ),
      _EvalQuestion(
        question: 'Tras administrar la adrenalina, ¿qué es correcto hacer?',
        options: [
          'Dar el alta si mejora rápidamente',
          'Llamar al 123, vigilar y repetir adrenalina a los 5–15 min si no mejora',
          'Administrar agua y esperar',
          'Suspender toda vigilancia al desaparecer los síntomas',
        ],
        correctIndex: 1,
        explanation:
            'Siempre se activa el sistema de emergencias. Si no hay mejoría, se repite la adrenalina cada 5–15 minutos. La vigilancia debe mantenerse por el riesgo de reacción bifásica (los síntomas pueden reaparecer horas después).',
      ),
      _EvalQuestion(
        question: '¿Qué es la anafilaxia?',
        options: [
          'Una reacción alérgica leve y local',
          'Una reacción alérgica grave, de instauración rápida, que afecta a varios sistemas y puede ser mortal',
          'Una infección',
          'Una bajada de azúcar',
        ],
        correctIndex: 1,
        explanation:
            'La anafilaxia es una reacción alérgica sistémica, grave y de rápida progresión, que compromete la vía aérea, la respiración y/o la circulación, con riesgo vital.',
      ),
      _EvalQuestion(
        question:
            '¿Cuáles son desencadenantes frecuentes de anafilaxia?',
        options: [
          'Solo el polen',
          'Alimentos (frutos secos, marisco), picaduras de insectos, medicamentos y látex',
          'Solo el frío',
          'El ejercicio únicamente',
        ],
        correctIndex: 1,
        explanation:
            'Los desencadenantes habituales son ciertos alimentos, venenos de insectos (abejas, avispas), fármacos (antibióticos, AINE) y el látex.',
      ),
      _EvalQuestion(
        question:
            '¿Qué signos respiratorios indican gravedad en una reacción alérgica?',
        options: [
          'Estornudos solamente',
          'Dificultad para respirar, sibilancias, estridor, sensación de cierre de garganta o ronquera',
          'Picor de nariz aislado',
          'Lagrimeo leve',
        ],
        correctIndex: 1,
        explanation:
            'El estridor, las sibilancias, la disnea, la voz ronca o la sensación de cierre de la garganta indican compromiso de la vía aérea/respiración: criterio de anafilaxia y de adrenalina inmediata.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué la adrenalina debe administrarse sin demora?',
        options: [
          'Porque es opcional',
          'Porque el retraso se asocia a mayor mortalidad; revierte rápidamente el cuadro',
          'Porque tarda horas en actuar',
          'Porque solo sirve para el picor',
        ],
        correctIndex: 1,
        explanation:
            'La administración precoz de adrenalina es la medida que salva vidas en la anafilaxia; el retraso se asocia a peor evolución y muerte. No debe sustituirse ni demorarse por antihistamínicos.',
      ),
      _EvalQuestion(
        question:
            'El autoinyector se aplica en el muslo y... ¿cuánto tiempo se mantiene?',
        options: [
          'Se retira al instante',
          'Se mantiene presionado varios segundos (según el dispositivo) para asegurar la dosis completa',
          'Se deja una hora',
          'No hace falta mantenerlo',
        ],
        correctIndex: 1,
        explanation:
            'Tras pinchar en la cara anterolateral del muslo, se mantiene el dispositivo firme unos segundos (3–10 según el modelo) para administrar toda la dosis; luego se masajea brevemente la zona.',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la dosis del autoinyector de adrenalina en un niño?',
        options: [
          '0,3 mg igual que el adulto',
          '0,15 mg (autoinyector pediátrico)',
          '1 mg',
          'No se usa en niños',
        ],
        correctIndex: 1,
        explanation:
            'El autoinyector pediátrico contiene 0,15 mg de adrenalina (frente a 0,3 mg del de adulto), indicado según el peso del niño.',
      ),
      _EvalQuestion(
        question:
            'Tras administrar la adrenalina, ¿qué debes hacer siempre?',
        options: [
          'Dejar marchar al paciente si mejora',
          'Llamar al 123 / trasladar al hospital, aunque mejore',
          'Darle de comer',
          'Suspender la vigilancia',
        ],
        correctIndex: 1,
        explanation:
            'Toda anafilaxia tratada con adrenalina requiere atención médica y observación hospitalaria por el riesgo de reacción bifásica y por si se necesitan más dosis.',
      ),
      _EvalQuestion(
        question:
            '¿Qué es una reacción bifásica?',
        options: [
          'Una alergia que solo da una vez',
          'La reaparición de los síntomas horas después de la mejoría inicial, sin nueva exposición',
          'Una reacción que dura segundos',
          'Una reacción que solo afecta a la piel',
        ],
        correctIndex: 1,
        explanation:
            'En la reacción bifásica los síntomas vuelven horas después (típicamente hasta 4–12 h) tras una mejoría inicial. Por eso se mantiene la observación tras tratar la anafilaxia.',
      ),
      _EvalQuestion(
        question:
            'El paciente deja de respirar y no tiene pulso tras la anafilaxia. ¿Qué haces?',
        options: [
          'Solo más adrenalina',
          'Iniciar RCP de inmediato (compresiones + ventilaciones) y usar el DEA',
          'Esperar a que actúe la adrenalina',
          'Posición de recuperación',
        ],
        correctIndex: 1,
        explanation:
            'Si evoluciona a paro cardíaco, se inicia RCP estándar de alta calidad y se usa el DEA, sin que ello impida administrar adrenalina si hay otro reanimador.',
      ),
      _EvalQuestion(
        question:
            'Si tras la primera dosis no hay mejoría, ¿cuándo se repite la adrenalina?',
        options: [
          'Nunca se repite',
          'A los 5–15 minutos si persisten o reaparecen los síntomas',
          'Cada 30 segundos',
          'A las 2 horas',
        ],
        correctIndex: 1,
        explanation:
            'Se puede repetir la adrenalina cada 5–15 minutos si no hay respuesta o los síntomas reaparecen, idealmente usando un segundo autoinyector y con el SEM en camino.',
      ),
      _EvalQuestion(
        question:
            '¿Qué papel tienen los antihistamínicos y corticoides en la anafilaxia?',
        options: [
          'Son el tratamiento principal y sustituyen a la adrenalina',
          'Son tratamientos secundarios/coadyuvantes; NUNCA sustituyen ni retrasan la adrenalina',
          'Empeoran el cuadro',
          'No se usan jamás',
        ],
        correctIndex: 1,
        explanation:
            'Antihistamínicos y corticoides actúan lento y solo alivian síntomas cutáneos o previenen recaídas. El tratamiento que salva la vida es la adrenalina, que no debe demorarse por ellos.',
      ),
      _EvalQuestion(
        question:
            'Si el paciente tiene dificultad respiratoria predominante (sin hipotensión), ¿qué posición prefiere?',
        options: [
          'Acostado boca abajo',
          'Sentado o semisentado, que le facilita respirar',
          'De pie caminando',
          'Cabeza más baja que el cuerpo',
        ],
        correctIndex: 1,
        explanation:
            'Si predomina la dificultad respiratoria, se le permite estar sentado/semisentado. Si predomina el compromiso circulatorio, se le acuesta con las piernas elevadas.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué es peligroso poner de pie de golpe a un paciente anafiláctico hipotenso?',
        options: [
          'Porque se cansa',
          'Por el riesgo de colapso cardiovascular ("síndrome del ventrículo vacío") y muerte súbita',
          'Porque le da vergüenza',
          'No es peligroso',
        ],
        correctIndex: 1,
        explanation:
            'Incorporar bruscamente a un paciente hipotenso puede reducir aún más el retorno venoso y causar colapso fatal. Se mantiene acostado con las piernas elevadas.',
      ),
      _EvalQuestion(
        question:
            'Un paciente con alergia conocida lleva su propio autoinyector. ¿Qué es correcto?',
        options: [
          'No usarlo sin un médico',
          'Ayudarle a usar SU adrenalina ante signos de anafilaxia, sin demora',
          'Guardarlo para más tarde',
          'Darle el de otra persona con otra dosis',
        ],
        correctIndex: 1,
        explanation:
            'Ante una anafilaxia, se ayuda al paciente a usar su propio autoinyector de inmediato. El miedo no debe retrasar la adrenalina, que es el tratamiento de elección.',
      ),
      _EvalQuestion(
        question:
            'Si es posible y no agrava la situación, ¿qué medida sobre el desencadenante conviene?',
        options: [
          'Seguir exponiendo al paciente',
          'Retirar/evitar el desencadenante (p. ej. quitar el aguijón, suspender el fármaco), sin retrasar la adrenalina',
          'Buscar el origen durante 10 minutos antes de actuar',
          'Dar más del alérgeno',
        ],
        correctIndex: 1,
        explanation:
            'Se elimina la exposición cuando sea factible (retirar el aguijón raspando, detener una infusión), pero esto nunca debe retrasar la administración de adrenalina ni la activación del SEM.',
      ),
      _EvalQuestion(
        question:
            '¿La anafilaxia siempre presenta síntomas en la piel (urticaria)?',
        options: [
          'Sí, siempre hay ronchas',
          'No: puede no haber síntomas cutáneos; no esperes a ver urticaria para actuar',
          'Solo afecta a la piel',
          'La piel es lo único importante',
        ],
        correctIndex: 1,
        explanation:
            'En una parte de los casos no aparecen síntomas cutáneos. Si hay compromiso respiratorio o circulatorio tras una exposición a un alérgeno, se trata como anafilaxia aunque no haya urticaria.',
      ),
    ],
  ),

  // 16. Crisis convulsiva
  _EvalScenario(
    id: 'eval_convulsion',
    title: 'Crisis Convulsiva',
    subtitle: 'Primeros auxilios · Qué hacer y qué NO',
    caseText:
        'Un hombre cae al suelo en la calle con movimientos tónico-clónicos generalizados, rigidez y sacudidas. Crisis convulsiva en curso.',
    color: AppColors.brand,
    icon: Icons.psychology_alt_outlined,
    difficulty: 'Básico',
    questions: [
      _EvalQuestion(
        question: '¿Qué debes hacer DURANTE la convulsión?',
        options: [
          'Sujetar firmemente a la persona para que deje de moverse',
          'Proteger su cabeza y retirar objetos peligrosos del entorno',
          'Introducir un objeto en la boca para que no se ahogue',
          'Darle agua para calmarla',
        ],
        correctIndex: 1,
        explanation:
            'Lo correcto es proteger la cabeza (con algo blando), retirar objetos con los que pueda lesionarse y cronometrar la duración. NO se debe sujetar a la persona ni restringir sus movimientos.',
      ),
      _EvalQuestion(
        question:
            '¿Es correcto introducir algo en la boca para evitar que "se trague la lengua"?',
        options: [
          'Sí, siempre hay que poner algo entre los dientes',
          'No, nunca se introduce nada en la boca',
          'Solo una cuchara de metal',
          'Solo si la persona lo pide',
        ],
        correctIndex: 1,
        explanation:
            'Es un mito peligroso: no se puede "tragar la lengua". Introducir objetos en la boca puede romper dientes, lesionar la vía aérea o causar obstrucción. Nunca se mete nada en la boca.',
      ),
      _EvalQuestion(
        question:
            'Terminó la convulsión y la persona respira pero está somnolienta. ¿Qué haces?',
        options: [
          'La pones de pie de inmediato',
          'La colocas en posición lateral de seguridad y la acompañas mientras se recupera',
          'La dejas boca arriba sin moverla',
          'Le das comida para reanimarla',
        ],
        correctIndex: 1,
        explanation:
            'En la fase postictal se coloca a la persona en posición lateral de seguridad para mantener la vía aérea permeable y permitir el drenaje de secreciones. Se la acompaña con calma mientras recupera la conciencia.',
      ),
      _EvalQuestion(
        question: '¿Cuándo se debe llamar al 123 ante una convulsión?',
        options: [
          'Nunca, las convulsiones siempre ceden solas',
          'Solo si la persona se lesiona la cabeza',
          'Si dura más de 5 min, se repite, no recupera la conciencia, es la primera vez, hay embarazo o lesión',
          'Solo si es un niño',
        ],
        correctIndex: 2,
        explanation:
            'Se activa el 123 si la crisis dura más de 5 minutos (estado epiléptico), se repite sin recuperar la conciencia, es una primera convulsión, ocurre en una embarazada, hay lesión o dificultad respiratoria tras la crisis.',
      ),
      _EvalQuestion(
        question: '¿Qué es el estado epiléptico?',
        options: [
          'Una convulsión de pocos segundos',
          'Una crisis que dura más de 5 minutos o crisis repetidas sin recuperar la conciencia entre ellas',
          'El estado normal entre crisis',
          'Una crisis que solo afecta a un brazo',
        ],
        correctIndex: 1,
        explanation:
            'El estado epiléptico es una emergencia: convulsión prolongada (>5 min) o crisis sucesivas sin recuperación de la conciencia. Requiere activación inmediata del SEM.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué se debe proteger la cabeza durante la convulsión?',
        options: [
          'Para que no hable',
          'Para evitar traumatismos por los golpes contra el suelo u objetos',
          'Para sujetarla quieta',
          'No es necesario',
        ],
        correctIndex: 1,
        explanation:
            'Las sacudidas pueden golpear la cabeza contra superficies duras. Se coloca algo blando bajo la cabeza y se retiran objetos peligrosos para prevenir lesiones.',
      ),
      _EvalQuestion(
        question:
            '¿Es correcto sujetar con fuerza a la persona para frenar las sacudidas?',
        options: [
          'Sí, hay que inmovilizarla',
          'No: sujetarla puede causar lesiones musculares o articulares; se la deja convulsionar protegiéndola',
          'Solo los brazos',
          'Solo si es un niño',
        ],
        correctIndex: 1,
        explanation:
            'No se debe restringir el movimiento: forzar contra las sacudidas puede provocar fracturas o luxaciones. Se protege el entorno y se deja que la crisis siga su curso.',
      ),
      _EvalQuestion(
        question: '¿Cuánto suele durar una crisis convulsiva típica?',
        options: [
          'Más de 30 minutos siempre',
          'Habitualmente menos de 2–3 minutos, cediendo de forma espontánea',
          'Varias horas',
          'Exactamente 10 minutos',
        ],
        correctIndex: 1,
        explanation:
            'La mayoría de las crisis ceden solas en 1–3 minutos. Si se prolonga más de 5 minutos, se considera estado epiléptico y es una emergencia.',
      ),
      _EvalQuestion(
        question:
            'Durante la convulsión la persona no respira bien y se pone azulada. ¿Qué haces?',
        options: [
          'Iniciar RCP de inmediato',
          'Mantener la calma: durante las sacudidas la respiración puede ser irregular; protégela y reevalúa al ceder la crisis',
          'Meterle aire con la boca',
          'Sacudirla',
        ],
        correctIndex: 1,
        explanation:
            'Durante la fase tónico-clónica puede haber cianosis transitoria por respiración irregular. Se protege a la persona; al ceder la crisis se valora la respiración y, si no respira, se inicia RCP.',
      ),
      _EvalQuestion(
        question:
            'Tras la convulsión, la persona está confusa y somnolienta. ¿Cómo se llama esta fase?',
        options: [
          'Fase de aura',
          'Fase postictal',
          'Fase tónica',
          'Fase preictal',
        ],
        correctIndex: 1,
        explanation:
            'La fase postictal es el período de recuperación tras la crisis: confusión, somnolencia y desorientación. Se acompaña a la persona con calma hasta que se recupera.',
      ),
      _EvalQuestion(
        question:
            '¿Por qué se coloca en posición lateral de seguridad en la fase postictal?',
        options: [
          'Para que descanse mejor',
          'Para mantener la vía aérea abierta y permitir el drenaje de saliva o vómito',
          'Por estética',
          'Para despertarla antes',
        ],
        correctIndex: 1,
        explanation:
            'La posición lateral evita que la lengua o las secreciones obstruyan la vía aérea y reduce el riesgo de broncoaspiración mientras recupera la conciencia.',
      ),
      _EvalQuestion(
        question:
            'Una persona con epilepsia conocida tiene una crisis breve y se recupera. ¿Hay que llamar siempre al 123?',
        options: [
          'Sí, siempre obligatoriamente',
          'No necesariamente, si es su patrón habitual y se recupera; sí si dura >5 min, se repite, se lesiona o no se recupera',
          'Nunca se llama',
          'Solo si es de noche',
        ],
        correctIndex: 1,
        explanation:
            'En epilepsia conocida con crisis típica y recuperación, puede no requerir emergencia. Se llama si se prolonga, se repite, hay lesión, dificultad respiratoria, embarazo, o no recupera la conciencia.',
      ),
      _EvalQuestion(
        question:
            '¿Qué cosas NO debes hacer durante una convulsión?',
        options: [
          'Proteger la cabeza y cronometrar',
          'Meter objetos en la boca, sujetar a la fuerza o dar agua/comida',
          'Retirar objetos peligrosos',
          'Acompañar a la persona',
        ],
        correctIndex: 1,
        explanation:
            'Nunca se introduce nada en la boca, no se sujeta a la fuerza ni se ofrece comida o bebida durante la crisis (riesgo de asfixia y lesiones).',
      ),
      _EvalQuestion(
        question:
            '¿Es útil cronometrar la duración de la convulsión?',
        options: [
          'No sirve para nada',
          'Sí: si supera los 5 minutos es estado epiléptico (emergencia) y es un dato clave para el SEM',
          'Solo en niños',
          'Solo si hay un reloj de pared',
        ],
        correctIndex: 1,
        explanation:
            'Cronometrar permite identificar el estado epiléptico (>5 min) y aporta información valiosa al personal sanitario sobre la duración y evolución de la crisis.',
      ),
      _EvalQuestion(
        question:
            'Un niño tiene fiebre alta y convulsiona (crisis febril). ¿Qué haces?',
        options: [
          'Sumergirlo en agua helada',
          'Protegerlo igual que cualquier convulsión, posición lateral al ceder y buscar valoración médica',
          'Sujetarlo con fuerza',
          'Darle medicación por la boca durante la crisis',
        ],
        correctIndex: 1,
        explanation:
            'La crisis febril se maneja como cualquier convulsión: proteger, no sujetar ni meter nada en la boca, posición lateral al terminar y valoración médica. No se sumerge en agua helada.',
      ),
      _EvalQuestion(
        question:
            'Si presencias el inicio de la crisis y la persona está de pie, ¿qué procuras?',
        options: [
          'Dejar que caiga libremente',
          'Ayudarla a tumbarse o amortiguar la caída para evitar golpes',
          'Sentarla en una silla alta',
          'Sujetarla en pie',
        ],
        correctIndex: 1,
        explanation:
            'Se intenta acompañar a la persona al suelo de forma controlada para evitar traumatismos por la caída, despejando el entorno de objetos peligrosos.',
      ),
      _EvalQuestion(
        question:
            'Tras una primera convulsión en alguien sin antecedentes, ¿qué se recomienda?',
        options: [
          'No hacer nada',
          'Activar el SEM / buscar valoración médica para estudiar la causa',
          'Esperar a que se repita',
          'Darle un calmante',
        ],
        correctIndex: 1,
        explanation:
            'Una primera convulsión siempre debe ser valorada por personal médico para investigar la causa (metabólica, neurológica, etc.), aunque la persona se recupere.',
      ),
      _EvalQuestion(
        question:
            'La persona se ha mordido la lengua y sangra un poco durante la crisis. ¿Qué haces?',
        options: [
          'Meter los dedos para sujetar la lengua',
          'No introducir nada en la boca; al ceder la crisis, posición lateral para que drene y vigilar',
          'Darle agua para limpiar',
          'Abrirle la boca a la fuerza',
        ],
        correctIndex: 1,
        explanation:
            'La mordedura de lengua es frecuente y no se previene metiendo objetos (que causan más daño). Se deja a la persona, y al terminar se coloca de lado para que la sangre/saliva drene.',
      ),
      _EvalQuestion(
        question:
            'Mientras llega la ayuda en un estado epiléptico, ¿qué información conviene anotar?',
        options: [
          'Nada relevante',
          'La hora de inicio, la duración, cómo fue la crisis y si la persona tiene antecedentes o medicación',
          'El color de su ropa',
          'Su número de teléfono',
        ],
        correctIndex: 1,
        explanation:
            'Anotar la hora de inicio, la duración, las características de la crisis y los antecedentes/medicación ayuda enormemente al equipo de emergencias a tratarla adecuadamente.',
      ),
      _EvalQuestion(
        question:
            'Cuando la persona recupera la conciencia tras la crisis, ¿cómo la tratas?',
        options: [
          'La interrogas con muchas preguntas de golpe',
          'Con calma: la tranquilizas, la orientas, le das privacidad y permaneces con ella',
          'La haces levantarse y caminar de inmediato',
          'La dejas sola',
        ],
        correctIndex: 1,
        explanation:
            'Tras la fase postictal la persona puede estar confusa o avergonzada. Se la tranquiliza, se la orienta poco a poco, se le da privacidad (apartar curiosos) y se la acompaña hasta su completa recuperación.',
      ),
    ],
  ),
];

// ─── Pantalla de lista ────────────────────────────────────────────────────────
class TheoreticalCasesScreen extends StatelessWidget {
  const TheoreticalCasesScreen({super.key});

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
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: textP),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Casos Clínicos AHA',
                          style: TextStyle(
                            color: textP,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${kTheoreticalCases.length} casos · Decisiones de protocolo AHA 2020/2025',
                          style: TextStyle(color: textS, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Count badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      '${kTheoreticalCases.length} casos',
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
                    color:
                        AppColors.brand.withValues(alpha: isDark ? 0.3 : 0.15)),
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
                itemCount: kTheoreticalCases.length,
                itemBuilder: (ctx, i) {
                  final eval = kTheoreticalCases[i];
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
                                        color:
                                            _diffColor.withValues(alpha: 0.25)),
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
                                  '$kQuestionsPerSession preguntas de ${eval.questions.length}',
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
  int _xpEarned = 0;
  int _levelAfter = 0;

  // Preguntas de este intento: 5 elegidas al azar del banco del caso,
  // con las opciones (A/B/C/D) barajadas individualmente.
  late final List<_EvalQuestion> _sessionQuestions =
      _buildSession(widget.eval.questions);

  static List<_EvalQuestion> _buildSession(List<_EvalQuestion> pool) {
    final rnd = Random();
    final picked = List<_EvalQuestion>.of(pool)..shuffle(rnd);
    final count =
        pool.length < kQuestionsPerSession ? pool.length : kQuestionsPerSession;
    return picked.take(count).map((q) {
      final correctText = q.options[q.correctIndex];
      final shuffledOptions = List<String>.of(q.options)..shuffle(rnd);
      return _EvalQuestion(
        question: q.question,
        options: shuffledOptions,
        correctIndex: shuffledOptions.indexOf(correctText),
        explanation: q.explanation,
      );
    }).toList();
  }

  void _selectAnswer(int idx) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
      final correct = idx == _sessionQuestions[_currentQ].correctIndex;
      if (correct) _correctCount++;
      _results.add(correct);
    });
  }

  void _next() {
    if (_currentQ < _sessionQuestions.length - 1) {
      setState(() {
        _currentQ++;
        _selectedAnswer = null;
        _answered = false;
      });
    } else {
      setState(() => _finished = true);
      _awardXp();
    }
  }

  static const _xpThresholds = [
    0,
    100,
    300,
    600,
    1000,
    1500,
    2200,
    3000,
    4000,
    5500
  ];
  static int _calcLevel(int xp) => _xpThresholds.where((t) => xp >= t).length;

  Future<void> _awardXp() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final total = _sessionQuestions.length;
    final score = total == 0 ? 0 : (_correctCount / total * 100).round();
    final passed = score >= 75;
    if (!passed) return;

    final xpEarned = score == 100 ? 50 : 20;
    final db = FirebaseFirestore.instance;
    final statsRef = db.collection('userStats').doc(uid);

    try {
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

      // Registro histórico sin bloquear la UI
      db.collection('quizSessions').add({
        'userId': uid,
        'topicId': widget.eval.id,
        'type': 'theoretical',
        'score': score,
        'passed': passed,
        'xpEarned': xpEarned,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[theoretical] Error guardando XP: $e');
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
        questions: _sessionQuestions,
        correctCount: _correctCount,
        results: _results,
        isDark: isDark,
        textP: textP,
        textS: textS,
        xpEarned: _xpEarned,
        levelAfter: _levelAfter,
      );
    }

    final q = _sessionQuestions[_currentQ];
    final total = _sessionQuestions.length;
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
                        Text('Pregunta ${_currentQ + 1} de $total',
                            style: TextStyle(color: textS, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Score chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                  backgroundColor: widget.eval.color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(widget.eval.color),
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
                  color:
                      widget.eval.color.withValues(alpha: isDark ? 0.1 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: widget.eval.color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(widget.eval.icon, size: 16, color: widget.eval.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.eval.caseText,
                        style: TextStyle(
                          color: isDark
                              ? textS
                              : widget.eval.color.withValues(alpha: 0.9),
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
                          border =
                              const Color(0xFF059669).withValues(alpha: 0.5);
                          textColor = const Color(0xFF059669);
                          trailingIcon = Icons.check_circle_outline_rounded;
                        } else if (isSelected) {
                          bg = AppColors.red.withValues(alpha: 0.08);
                          border = AppColors.red.withValues(alpha: 0.4);
                          textColor = AppColors.red;
                          trailingIcon = Icons.cancel_outlined;
                        } else {
                          bg = null;
                          border =
                              theme.colorScheme.outline.withValues(alpha: 0.15);
                          textColor = textS.withValues(alpha: 0.5);
                        }
                      } else {
                        bg = null;
                        border =
                            theme.colorScheme.outline.withValues(alpha: 0.3);
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
                                  color: textS, fontSize: 12, height: 1.55),
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
  final List<_EvalQuestion> questions;
  final int correctCount;
  final List<bool> results;
  final bool isDark;
  final Color textP;
  final Color textS;
  final int xpEarned;
  final int levelAfter;

  const _ResultScreen({
    required this.eval,
    required this.questions,
    required this.correctCount,
    required this.results,
    required this.isDark,
    required this.textP,
    required this.textS,
    this.xpEarned = 0,
    this.levelAfter = 0,
  });

  @override
  Widget build(BuildContext context) {
    final total = questions.length;
    final pct = (correctCount / total * 100).round();
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
                        color: textP,
                        fontSize: 20,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    eval.title,
                    style: TextStyle(color: textS, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  // ── XP & nivel ganado ─────────────────────────────────────
                  if (xpEarned > 0) ...[
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
                                '+$xpEarned XP ganados',
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (levelAfter > 0)
                                Text(
                                  'Nivel actual: $levelAfter',
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
                    final q = questions[i];
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
