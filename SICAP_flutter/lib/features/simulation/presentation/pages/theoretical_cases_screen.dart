import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/simulation/data/aed/ecg_audio_service.dart';

/// Número de preguntas que se muestran por intento (elegidas al azar del banco).
const int kQuestionsPerSession = 5;

enum _EcgRhythmType { fv, tv, asistolia, aesp, normal, fa, bav, tsv }

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
  final _EcgRhythmType? ecgRhythm;
  final String? ecgRhythmLabel;
  final String? ecgHeartRate;

  const _EvalScenario({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.caseText,
    required this.color,
    required this.icon,
    required this.difficulty,
    required this.questions,
    this.ecgRhythm,
    this.ecgRhythmLabel,
    this.ecgHeartRate,
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
        question: '¿Cuánto tiempo máximo debes emplear en comprobar el pulso?',
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
        question: 'Sin sospecha de trauma cervical, ¿cómo abres la vía aérea?',
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
        question:
            'En niños, ¿es importante permitir el recoil torácico completo?',
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
        question:
            '¿Cómo se abre la vía aérea de un niño sin sospecha de trauma?',
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
        question: 'Las ventilaciones en un niño deben ser...',
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
        question: 'Para desfibrilar a un lactante, lo ideal es...',
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
        question: '¿Es importante el recoil completo del tórax en el lactante?',
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
        question:
            'La seguridad de quién es prioritaria en un rescate acuático?',
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
        question: '¿Se debe usar el DEA en una víctima de ahogamiento en paro?',
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
        question: '¿Por qué se asocia el ahogamiento a riesgo de hipotermia?',
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
        question: 'En el ahogamiento, la secuencia de actuación enfatiza:',
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
        question: '¿Cuál es la señal universal de atragantamiento?',
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
        question: '¿Cuántas veces se repite el ciclo de 5 golpes + 5 empujes?',
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
        question: 'El DEA indica "descarga NO recomendada". ¿Qué haces?',
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
        question: '¿Cada cuánto vuelve a analizar el ritmo el DEA?',
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
        question: '¿Por qué la corriente alterna (AC) suele ser más peligrosa?',
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
        question:
            '¿Cómo se manejan las quemaduras eléctricas en primeros auxilios?',
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
        question: 'La destrucción muscular por la corriente puede provocar...',
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
        question: 'En electrocuciones de alta tensión, el daño suele ser...',
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
        question:
            '¿Qué signo en las pupilas orienta a sobredosis por opioides?',
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
        question:
            '¿Por qué es importante que un reanimador "cuente en voz alta"?',
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
        question: 'Una buena comunicación de equipo durante la RCP incluye:',
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
        question: 'Si llega un tercer reanimador, ¿en qué puede ayudar?',
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
        question: '¿Debe comer o beber un paciente con dolor torácico agudo?',
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
        question:
            '¿Cómo se posiciona al lactante para los golpes en la espalda?',
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
        question:
            'El lactante queda inconsciente durante el atragantamiento. ¿Qué haces?',
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
        question: 'El objetivo prioritario al reanimar a una embarazada es...',
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
        question: 'Lo PRIMERO al rescatar a una víctima de hipotermia es...',
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
        question:
            '¿Por qué NO se debe dar alcohol a una víctima de hipotermia?',
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
        question: 'Si la víctima hipotérmica está en paro, ¿cómo es la RCP?',
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
        question: '¿Quiénes son especialmente vulnerables a la hipotermia?',
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
        question: 'Con ropa mojada, ¿por qué se pierde calor tan rápido?',
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
        question: '¿Cómo distingues una hemorragia arterial de una venosa?',
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
        question: '¿Qué es un agente/apósito hemostático y cuándo se usa?',
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
        question: '¿Cuáles son desencadenantes frecuentes de anafilaxia?',
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
        question: '¿Por qué la adrenalina debe administrarse sin demora?',
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
        question: 'Tras administrar la adrenalina, ¿qué debes hacer siempre?',
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
        question: '¿Qué es una reacción bifásica?',
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
        question: '¿Por qué se debe proteger la cabeza durante la convulsión?',
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
        question: '¿Qué cosas NO debes hacer durante una convulsión?',
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
        question: '¿Es útil cronometrar la duración de la convulsión?',
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
  // ─── ECG ────────────────────────────────────────────────────────────────────
  _EvalScenario(
    id: 'eval_ecg_fv',
    title: 'Fibrilación Ventricular',
    subtitle: 'Ritmo de paro · AHA 2020',
    caseText:
        'Monitor multiparámetro muestra un ritmo caótico, ondulaciones irregulares sin complejos QRS identificables. Paciente inconsciente, sin pulso, sin respiración.',
    color: Color(0xFF10B981),
    icon: Icons.monitor_heart_outlined,
    ecgRhythm: _EcgRhythmType.fv,
    ecgRhythmLabel: 'FV — Caótico',
    ecgHeartRate: '--- lpm',
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question: '¿Qué ritmo observas en el monitor?',
        options: [
          'Fibrilación Ventricular (FV)',
          'Taquicardia Ventricular monomórfica',
          'Fibrilación Auricular',
          'Asistolia',
        ],
        correctIndex: 0,
        explanation:
            'La FV se caracteriza por actividad eléctrica caótica y desorganizada sin complejos QRS. Es un ritmo desfibrilable y la causa más frecuente de paro cardíaco presenciado en adultos.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la primera acción tras confirmar FV?',
        options: [
          'Administrar adrenalina 1 mg IV',
          'Iniciar RCP 30:2 por 2 minutos',
          'Desfibrilar con 200J (bifásico) lo antes posible',
          'Intubar al paciente',
        ],
        correctIndex: 2,
        explanation:
            'La prioridad en FV presenciada es la desfibrilación precoz. Se administra una descarga de 200J en bifásico (360J en monofásico) tan pronto como el desfibrilador esté disponible. Cada minuto de retraso reduce la supervivencia un 7-10%.',
      ),
      _EvalQuestion(
        question: 'Tras la primera descarga, ¿qué haces?',
        options: [
          'Revisar el pulso inmediatamente',
          'Reanudar RCP 30:2 por 2 minutos, luego revisar ritmo',
          'Dar una segunda descarga de inmediato',
          'Administrar amiodarona 300 mg',
        ],
        correctIndex: 1,
        explanation:
            'Tras la descarga se reanuda RCP inmediatamente (sin revisar pulso ni ritmo) durante 2 minutos. Luego se revisa el ritmo. Esto maximiza el flujo coronario y cerebral entre descargas.',
      ),
      _EvalQuestion(
        question: '¿Cuándo se administra adrenalina en este escenario?',
        options: [
          'Antes de la primera descarga',
          'Después de la segunda descarga, durante la RCP',
          'Solo si el ritmo persiste tras 3 descargas',
          'No está indicada en FV',
        ],
        correctIndex: 1,
        explanation:
            'La adrenalina 1 mg IV/IO se administra después de la segunda descarga, durante la RCP. Luego se repite cada 3-5 minutos. La amiodarona 300 mg se da tras la tercera descarga si la FV persiste (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la causa más frecuente de paro cardíaco en adultos?',
        options: [
          'Asistolia',
          'Fibrilación Ventricular (FV)',
          'AESP',
          'Taquicardia Ventricular',
        ],
        correctIndex: 1,
        explanation:
            'La FV es la causa más frecuente de paro cardíaco presenciado en adultos (50-60% de los casos). La desfibrilación precoz es el factor más importante para la supervivencia.',
      ),
      _EvalQuestion(
        question: '¿Qué energía se recomienda en la primera descarga con desfibrilador bifásico?',
        options: [
          '120J',
          '200J',
          '360J',
          '100J',
        ],
        correctIndex: 1,
        explanation:
            'La dosis inicial recomendada para desfibrilación bifásica es 200J. Para desfibriladores monofásicos es 360J. Se pueden usar dosis más altas si persiste la FV (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Dónde se colocan los parches del desfibrilador en posición anterolateral?',
        options: [
          'Ápex (izquierdo, línea axilar media) + esternal (derecho, infraclavicular)',
          'Ambos en el tórax anterior',
          'Uno en tórax anterior y otro en espalda',
          'Ambos en el abdomen',
        ],
        correctIndex: 0,
        explanation:
            'Posición anterolateral: parche esternal en tórax superior derecho (infraclavicular) y parche apical en tórax inferior izquierdo (línea axilar media). Alternativa: anteroposterior (esternal + espalda). Evitar sobre los parches de medicación transdérmica o marcapasos.',
      ),
      _EvalQuestion(
        question: '¿Qué antiarrítmico se administra si la FV persiste tras 3 descargas?',
        options: [
          'Lidocaína 1.5 mg/kg',
          'Amiodarona 300 mg en bolo IV/IO',
          'Magnesio 2 g IV',
          'Procainamida 50 mg/min',
        ],
        correctIndex: 1,
        explanation:
            'Amiodarona 300 mg IV/IO en bolo es el antiarrítmico de elección en FV/TVSP refractaria. Puede repetirse a 150 mg si persiste. Lidocaína 1.5 mg/kg es alternativa si no hay amiodarona (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuándo se debe asegurar la vía aérea durante la reanimación?',
        options: [
          'Inmediatamente al iniciar RCP',
          'Solo después de 3 descargas sin éxito',
          'Idealmente después de 2 ciclos de RCP, minimizando interrupciones',
          'No es necesario si la saturación es > 90%',
        ],
        correctIndex: 2,
        explanation:
            'La vía aérea avanzada (tubo endotraqueal o supraglótico) se coloca después de los primeros ciclos de RCP, minimizando las interrupciones de las compresiones. Se prefiere la vía aérea supraglótica si el operador tiene menos experiencia (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Qué frecuencia de compresiones torácicas se recomienda en RCP?',
        options: [
          '80-100 compresiones/minuto',
          '100-120 compresiones/minuto',
          '120-140 compresiones/minuto',
          '60-80 compresiones/minuto',
        ],
        correctIndex: 1,
        explanation:
            'La frecuencia recomendada de compresiones es 100-120/minuto. La profundidad debe ser de 5-6 cm en adultos. Retorno completo del tórax entre compresiones. Relación 30:2 (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Qué signo indica retorno de la circulación espontánea (ROSC)?',
        options: [
          'Pulso palpable + aumento ETCO2 > 40 mmHg',
          'FV en el monitor',
          'Frecuencia cardíaca < 40 lpm',
          'Disminución de la Sat O2',
        ],
        correctIndex: 0,
        explanation:
            'Signos de ROSC: pulso palpable, aumento súbito y sostenido del ETCO2 (>40 mmHg), aumento de la presión arterial, onda de pulso espontánea en el monitor arterial. La ETCO2 es el indicador más precoz durante la RCP (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuál es el objetivo de oxigenación post-ROSC?',
        options: [
          'Sat O2 100% con FiO2 al 100%',
          'Sat O2 94-98% con la menor FiO2 posible',
          'Sat O2 > 90% sin importar FiO2',
          'Sat O2 88-92% con FiO2 al 100%',
        ],
        correctIndex: 1,
        explanation:
            'Post-ROSC: titular FiO2 para mantener Sat O2 94-98%. Evitar hiperoxia (Sat O2 100%) porque empeora el daño por reperfusión. Una vez confirmado ROSC, reducir FiO2 gradualmente (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuál de las siguientes es una causa reversible (5H) de paro cardíaco?',
        options: [
          'Hipertensión arterial',
          'Hipertermia',
          'Hipovolemia',
          'Hiperglucemia',
        ],
        correctIndex: 2,
        explanation:
            'Las 5H: Hipovolemia, Hipoxia, H+ (acidosis), Hipo/Hiperpotasemia, Hipotermia. Las 5T: Trombosis coronaria, Trombosis pulmonar (TEP), Taponamiento cardíaco, Tóxicos, Tensión (neumotórax a tensión) (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Qué diferencia hay entre desfibrilador bifásico y monofásico?',
        options: [
          'El bifásico usa una corriente que invierte polaridad; el monofásico no',
          'El monofásico es más efectivo que el bifásico',
          'El bifásico solo se usa en pacientes pediátricos',
          'No hay diferencia clínicamente relevante',
        ],
        correctIndex: 0,
        explanation:
            'El desfibrilador bifásico administra corriente que fluye en una dirección positiva y luego se invierte a negativa. Requiere menos energía (200J vs 360J) y produce menos daño miocárdico que el monofásico. Los bifásicos tienen mayor tasa de éxito en primera descarga.',
      ),
      _EvalQuestion(
        question: 'En FV refractaria, ¿cuándo se administra la segunda dosis de amiodarona?',
        options: [
          '150 mg IV/IO si la FV persiste',
          'No hay segunda dosis',
          '300 mg adicionales en la siguiente RCP',
          '450 mg en infusión continua',
        ],
        correctIndex: 0,
        explanation:
            'Si la FV/TVSP persiste tras 5 descargas, se puede administrar una segunda dosis de amiodarona 150 mg IV/IO. Dosis máxima acumulada: 450 mg en 24 horas. Lidocaína es alternativa (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la relación compresión-ventilación en RCP con vía aérea avanzada?',
        options: [
          '30:2 sin pausas',
          '15:2 con pausas de 5 segundos',
          'Compresiones continuas a 100-120/min + 1 ventilación cada 6 segundos (10/min)',
          '5:1 con pausas',
        ],
        correctIndex: 2,
        explanation:
            'Con vía aérea avanzada (tubo ET o supraglótico): compresiones continuas a 100-120/min sin pausas + 1 ventilación cada 6 segundos (10 ventilaciones/minuto). No hay pausas para ventilación (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Qué porcentaje de supervivencia se pierde por cada minuto sin desfibrilar en FV?',
        options: [
          '1-3%',
          '7-10%',
          '15-20%',
          '25-30%',
        ],
        correctIndex: 1,
        explanation:
            'Por cada minuto que se retrasa la desfibrilación en FV, la supervivencia disminuye 7-10%. Si se inicia RCP inmediata, la tasa de disminución es más lenta (3-4% por minuto). La desfibrilación en los primeros 3-5 minutos da la mejor oportunidad de supervivencia.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la profundidad correcta de compresiones en RCP de adulto?',
        options: [
          '3-4 cm',
          '5-6 cm',
          '7-8 cm',
          '2-3 cm',
        ],
        correctIndex: 1,
        explanation:
            'Profundidad: al menos 5 cm pero no más de 6 cm en adulto promedio. Permitir retorno completo del tórax entre compresiones. Esto optimiza el flujo sanguíneo coronario y cerebral (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuándo se debe detener la RCP durante el análisis del DEA?',
        options: [
          'Cuando el DEA está analizando el ritmo, NO se toca al paciente',
          'Se continúa RCP mientras el DEA analiza',
          'Solo se detiene si el paciente se mueve',
          'Se detiene después de 5 minutos de RCP',
        ],
        correctIndex: 0,
        explanation:
            'Durante el análisis del DEA: NO tocar al paciente. Las compresiones y la ventilación deben detenerse para que el DEA analice correctamente el ritmo. Seguir las indicaciones del DEA (AHA 2020).',
      ),
    ],
  ),
  _EvalScenario(
    id: 'eval_ecg_tvsp',
    title: 'Taquicardia Ventricular sin Pulso',
    subtitle: 'Ritmo de paro · AHA 2020',
    caseText:
        'Monitor muestra complejos QRS anchos (>0.12s) y regulares a ~180 lpm. No se palpan pulsos centrales. Paciente inconsciente. Sin respiración espontánea.',
    color: Color(0xFF10B981),
    icon: Icons.monitor_heart_outlined,
    ecgRhythm: _EcgRhythmType.tv,
    ecgRhythmLabel: 'TV — QRS ancho regular',
    ecgHeartRate: '~180 lpm',
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question: '¿Qué ritmo muestra el monitor?',
        options: [
          'Taquicardia Sinusal',
          'Fibrilación Auricular',
          'Taquicardia Ventricular sin Pulso (TVSP)',
          'Bloqueo AV de 3er grado',
        ],
        correctIndex: 2,
        explanation:
            'La TVSP se reconoce por complejos QRS anchos y regulares (>0.12s, generalmente >150 lpm) más AUSENCIA de pulso. Es un ritmo desfibrilable y se trata igual que la FV en el algoritmo de paro.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el tratamiento inmediato?',
        options: [
          'Cardioversión sincronizada',
          'Desfibrilación con 200J (bifásico)',
          'Adrenalina 1 mg IV',
          'Adenosina 6 mg IV',
        ],
        correctIndex: 1,
        explanation:
            'Al igual que la FV, la TVSP se trata con desfibrilación a 200J bifásico. La cardioversión sincronizada NO está indicada porque no hay pulso. La adenosina solo funciona en taquicardias de QRS estrecho.',
      ),
      _EvalQuestion(
        question:
            '¿Qué fármaco se administra si la TVSP persiste tras 3 descargas?',
        options: [
          'Lidocaína 1.5 mg/kg',
          'Amiodarona 300 mg en bolo IV/IO',
          'Magnesio 2 g IV',
          'Atropina 1 mg IV',
        ],
        correctIndex: 1,
        explanation:
            'Si la TV/FV persiste después de 3 descargas, se administra amiodarona 300 mg en bolo IV/IO. La lidocaína es alternativa si no hay amiodarona. El magnesio está indicado específicamente en TV torsade de pointes.',
      ),
      _EvalQuestion(
        question: '¿Qué diferencia a la TVSP de la TV con pulso?',
        options: [
          'El ancho del QRS',
          'La presencia o ausencia de pulso palpable',
          'La frecuencia cardíaca',
          'La regularidad del ritmo',
        ],
        correctIndex: 1,
        explanation:
            'La TVSP y la TV con pulso tienen el mismo patrón ECG (QRS ancho, regular, >150 lpm). La diferencia es la presencia de pulso palpable. TVSP se trata como FV (desfibrilación), TV con pulso se trata según estabilidad (cardioversión o antiarrítmicos).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la frecuencia más común de TVSP?',
        options: [
          '100-150 lpm',
          '150-250 lpm',
          '250-300 lpm',
          '< 100 lpm',
        ],
        correctIndex: 1,
        explanation:
            'La TVSP típicamente presenta una frecuencia de 150-250 lpm con complejos QRS anchos (>0.12s) y regulares. Frecuencias >250 lpm sugieren aleteo ventricular, que es una variante de alta frecuencia.',
      ),
      _EvalQuestion(
        question: '¿Cuándo se considera que la TV es monomórfica?',
        options: [
          'Todos los complejos QRS tienen la misma morfología',
          'Los complejos QRS varían en forma',
          'La frecuencia es irregular',
          'Hay ondas P visibles',
        ],
        correctIndex: 0,
        explanation:
            'TV monomórfica: todos los complejos QRS son iguales (misma morfología). TV polimórfica: los QRS varían en morfología (la torsade de pointes es un tipo de TV polimórfica con QT prolongado asociado).',
      ),
      _EvalQuestion(
        question: '¿Cuál de las siguientes causas NO es típica de TVSP?',
        options: [
          'Cardiopatía isquémica',
          'Miocardiopatía dilatada',
          'Estenosis mitral reumática',
          'Trastornos electrolíticos (hipopotasemia)',
        ],
        correctIndex: 2,
        explanation:
            'La TVSP se asocia a cardiopatía isquémica (causa más común), miocardiopatías, trastornos electrolíticos (hipopotasemia, hipomagnesemia), fármacos proarrítmicos, síndromes hereditarios (QT largo, Brugada). La estenosis mitral causa FA, no TV.',
      ),
      _EvalQuestion(
        question: 'En TVSP, ¿cómo se administra la amiodarona?',
        options: [
          'En bolo IV/IO de 300 mg diluido en 20 mL de D5%',
          'En infusión lenta durante 1 hora',
          'En bolo IV de 150 mg sin diluir',
          'Por vía intraósea no es posible',
        ],
        correctIndex: 0,
        explanation:
            'Amiodarona 300 mg IV/IO en bolo, diluido en 20 mL de D5% o SF. Administrar rápidamente durante la RCP. Segunda dosis: 150 mg si persiste la TV/FV. La vía IO es equivalente a la IV para la administración de fármacos en paro.',
      ),
      _EvalQuestion(
        question: '¿Qué ritmo puede aparecer después de desfibrilar una TVSP?',
        options: [
          'Asistolia transitoria o ritmo organizado',
          'Siempre FA',
          'Bloqueo AV de 1er grado',
          'Ritmo sinusal sin excepción',
        ],
        correctIndex: 0,
        explanation:
            'Tras la desfibrilación puede aparecer asistolia transitoria, ritmo organizado con pulso, o persistencia de TV/FV. Si hay asistolia, continuar RCP y administrar adrenalina. Si aparece ritmo organizado con pulso, iniciar cuidados post-ROSC.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la dosis de lidocaína como alternativa en TVSP?',
        options: [
          '1-1.5 mg/kg IV/IO en bolo inicial',
          '0.5 mg/kg en bolo',
          '3 mg/kg en infusión',
          '100 mg en bolo independiente del peso',
        ],
        correctIndex: 0,
        explanation:
            'Lidocaína: dosis inicial 1-1.5 mg/kg IV/IO. Dosis de mantenimiento: 0.5-0.75 mg/kg cada 5-10 minutos, dosis máxima 3 mg/kg. Es alternativa cuando no hay amiodarona (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Qué indica la presencia de TV polimórfica?',
        options: [
          'Posible torsade de pointes con QT prolongado o isquemia activa',
          'Siempre es benigna',
          'Indica bloqueo de rama',
          'Es característica de la FA',
        ],
        correctIndex: 0,
        explanation:
            'TV polimórfica: QRS varían en amplitud y morfología. Torsade de pointes es TV polimórfica con QT prolongado. Causas: hipopotasemia, hipomagnesemia, fármacos (antiarrítmicos clase IA/III), isquemia miocárdica, bradicardia severa.',
      ),
      _EvalQuestion(
        question: 'En torsade de pointes, ¿qué tratamiento específico está indicado?',
        options: [
          'Magnesio 2 g IV en bolo',
          'Amiodarona 300 mg IV',
          'Lidocaína 1.5 mg/kg',
          'Cardioversión sincronizada',
        ],
        correctIndex: 0,
        explanation:
            'En torsade de pointes, el magnesio 2 g IV diluido en 10 mL de D5% administrado en bolo lento (1-2 min) es el tratamiento de elección. Si no hay pulso, seguir algoritmo de FV/TVSP (desfibrilar + amiodarona). Corregir potasio a 4.5-5.0 mmol/L.',
      ),
      _EvalQuestion(
        question: '¿Cuándo está indicada la desfibrilación sincronizada?',
        options: [
          'En TVSP (sin pulso)',
          'En TV con pulso estable o inestable',
          'En FV',
          'En asistolia',
        ],
        correctIndex: 1,
        explanation:
            'La cardioversión/desfibrilación sincronizada se usa cuando hay pulso presente (TV con pulso, FA, aleteo auricular, TSV). La desfibrilación NO sincronizada se usa en FV y TVSP. La sincronización evita descargar en la onda T (reduce riesgo de FV).',
      ),
      _EvalQuestion(
        question: '¿Qué energía se usa para cardioversión de TV monomórfica estable?',
        options: [
          '200J bifásico sincronizado',
          '100J bifásico sincronizado',
          '360J bifásico no sincronizado',
          '50J bifásico sincronizado',
        ],
        correctIndex: 1,
        explanation:
            'TV monomórfica con pulso estable: cardioversión sincronizada con 100J bifásico inicial. Si no hay respuesta, aumentar escalonadamente (200J, 300J, 360J). TV polimórfica: usar dosis mayores (200J) porque es más inestable.',
      ),
      _EvalQuestion(
        question: '¿Qué fármaco está contraindicado en TVSP?',
        options: [
          'Amiodarona',
          'Lidocaína',
          'Verapamilo',
          'Magnesio',
        ],
        correctIndex: 2,
        explanation:
            'Los bloqueadores de canales de calcio no dihidropiridínicos (verapamilo, diltiazem) están contraindicados en taquicardias de QRS ancho porque pueden causar hipotensión severa y deterioro a FV. Siempre asumir QRS ancho como TV hasta confirmar lo contrario.',
      ),
      _EvalQuestion(
        question: '¿Cuál de los siguientes fármacos puede causar TV polimórfica?',
        options: [
          'Amiodarona',
          'Procainamida (Clase IA)',
          'Adenosina',
          'Atropina',
        ],
        correctIndex: 1,
        explanation:
            'Procainamida (Clase IA) y sotalol (Clase III) pueden prolongar el QT y causar torsade de pointes. Otros: eritromicina, haloperidol, antidepresivos tricíclicos, metadona. Monitorear QT en ECG seriados.',
      ),
      _EvalQuestion(
        question: 'Si la TVSP se presenta en un paciente con QT normal, ¿qué antiarrítmico NO debe usarse?',
        options: [
          'Lidocaína (Clase IB)',
          'Amiodarona (Clase III)',
          'Procainamida (Clase IA)',
          'Ninguno, todos son seguros',
        ],
        correctIndex: 2,
        explanation:
            'En TVSP con QT normal, se prefiere amiodarona o lidocaína. La procainamida está contraindicada en disfunción ventricular o insuficiencia cardíaca porque tiene efecto inotrópico negativo y puede empeorar el pronóstico. En TV polimórfica con QT prolongado, evitar procainamida y sotalol.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el mejor predictor de TVSP en un paciente con cardiopatía isquémica?',
        options: [
          'Fracción de eyección del ventrículo izquierdo < 40%',
          'Hipertensión arterial',
          'Edad > 70 años',
          'Diabetes mellitus',
        ],
        correctIndex: 0,
        explanation:
            'La fracción de eyección del VI deprimida (<40%) es el predictor más fuerte de muerte súbita cardíaca por TV/FV en pacientes con cardiopatía isquémica. Estos pacientes se benefician de DAI (desfibrilador automático implantable) para prevención secundaria.',
      ),
      _EvalQuestion(
        question: '¿Cada cuánto se debe administrar adrenalina durante el paro por TVSP?',
        options: [
          'Cada 1 minuto',
          'Cada 3-5 minutos',
          'Cada 10 minutos',
          'Dosis única de 2 mg',
        ],
        correctIndex: 1,
        explanation:
            'Adrenalina 1 mg IV/IO cada 3-5 minutos durante la RCP, independientemente del ritmo. En FV/TVSP, se administra después de la segunda descarga y luego se repite cada 3-5 minutos. La amiodarona se administra tras la tercera descarga.',
      ),
    ],
  ),
  _EvalScenario(
    id: 'eval_ecg_asistolia',
    title: 'Asistolia',
    subtitle: 'Ritmo no desfibrilable · AHA 2020',
    caseText:
        'Monitor muestra una línea isoeléctrica plana sin actividad eléctrica ventricular. Se confirma en dos derivaciones. Paciente inconsciente, sin pulso, sin respiración.',
    color: Color(0xFF10B981),
    icon: Icons.show_chart_rounded,
    ecgRhythm: _EcgRhythmType.asistolia,
    ecgRhythmLabel: 'Asistolia — Línea plana',
    ecgHeartRate: '0 lpm',
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question: '¿Cuál es la primera prioridad en asistolia?',
        options: [
          'Desfibrilar inmediatamente',
          'Iniciar RCP de alta calidad y administrar adrenalina',
          'Colocar marcapasos transcutáneo',
          'Administrar atropina',
        ],
        correctIndex: 1,
        explanation:
            'La asistolia NO es un ritmo desfibrilable. El tratamiento es RCP de alta calidad 30:2, adrenalina 1 mg IV/IO lo antes posible, y buscar causas reversibles (5H y 5T). El marcapasos NO está indicado en asistolia.',
      ),
      _EvalQuestion(
        question: '¿Cuánta adrenalina se administra y cada cuánto?',
        options: [
          '1 mg cada 3-5 minutos',
          '0.5 mg cada 10 minutos',
          '2 mg en dosis única',
          '1 mg cada 1 minuto',
        ],
        correctIndex: 0,
        explanation:
            'La adrenalina 1 mg IV/IO se administra lo antes posible y se repite cada 3-5 minutos durante la RCP. Es el fármaco principal en ritmos no desfibrilables (asistolia y AESP).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál de las siguientes NO es una causa reversible de asistolia?',
        options: [
          'Hipoxia',
          'Hipotermia',
          'Hipertensión arterial',
          'Taponamiento cardíaco',
        ],
        correctIndex: 2,
        explanation:
            'Las causas reversibles (5H y 5T) son: Hipoxia, Hipotermia, Hipovolemia, Hipo/Hiperpotasemia, H+ (acidosis), Trombosis coronaria/pulmonar, Taponamiento cardíaco, Tóxicos, Tensión (neumotórax). La hipertensión arterial no es causa de paro en asistolia.',
      ),
      _EvalQuestion(
        question: '¿Qué es la asistolia?',
        options: [
          'Actividad ventricular desorganizada sin QRS',
          'Ausencia completa de actividad eléctrica cardíaca (línea isoeléctrica)',
          'QRS anchos sin pulso',
          'Ritmo irregularmente irregular sin ondas P',
        ],
        correctIndex: 1,
        explanation:
            'Asistolia: ausencia de toda actividad eléctrica ventricular. Se confirma verificando en dos derivaciones diferentes (aumentar ganancia y verificar que no haya cables sueltos). Es un ritmo NO desfibrilable.',
      ),
      _EvalQuestion(
        question: '¿Cuántas derivaciones se deben revisar para confirmar asistolia?',
        options: [
          'Solo una derivación es suficiente',
          'Al menos dos derivaciones diferentes',
          'Todas las 12 derivaciones',
          'No es necesario confirmar en más de una',
        ],
        correctIndex: 1,
        explanation:
            'La asistolia debe confirmarse en al menos dos derivaciones diferentes para descartar fibrilación ventricular de baja amplitud (FV fina). También verificar que los cables estén conectados correctamente y la ganancia esté adecuada.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el pronóstico de la asistolia comparado con otros ritmos de paro?',
        options: [
          'Mejor pronóstico que FV',
          'Similar pronóstico a TVSP',
          'Peor pronóstico, menor tasa de supervivencia',
          'El mejor pronóstico de todos',
        ],
        correctIndex: 2,
        explanation:
            'La asistolia tiene el peor pronóstico de todos los ritmos de paro cardíaco. La supervivencia al alta hospitalaria es < 5%. Esto se debe a que generalmente representa un corazón muy dañado o un paro prolongado con daño miocárdico extenso.',
      ),
      _EvalQuestion(
        question: '¿Está indicado el marcapasos en asistolia?',
        options: [
          'Sí, marcapasos transcutáneo inmediato',
          'Sí, marcapasos transvenoso',
          'No, el marcapasos no está indicado en asistolia',
          'Solo si hay bradicardia',
        ],
        correctIndex: 2,
        explanation:
            'El marcapasos NO está indicado en asistolia. No hay actividad eléctrica que capturar. El tratamiento es RCP de alta calidad + adrenalina + búsqueda de causas reversibles. El marcapasos solo funciona si hay actividad eléctrica (bradicardia sintomática).',
      ),
      _EvalQuestion(
        question: '¿Qué causa reversible de asistolia está asociada a pacientes renales crónicos?',
        options: [
          'Hipovolemia',
          'Hiperpotasemia',
          'Neumotórax a tensión',
          'Trombosis coronaria',
        ],
        correctIndex: 1,
        explanation:
            'La hiperpotasemia es causa frecuente de asistolia en pacientes con enfermedad renal crónica, diálisis, o uso de inhibidores del SRAA. El ECG típico muestra ondas T picudas, QRS ancho, y evolución a asistolia. Tratamiento: gluconato de calcio + insulina/D5% + kayexalato.',
      ),
      _EvalQuestion(
        question: '¿Qué dosis de adrenalina se administra en el primer ciclo en asistolia?',
        options: [
          '1 mg IV/IO lo antes posible',
          '0.5 mg IV/IO',
          '2 mg IV/IO en bolo',
          'Adrenalina no está indicada en asistolia',
        ],
        correctIndex: 0,
        explanation:
            'Adrenalina 1 mg IV/IO lo antes posible, luego repetir cada 3-5 minutos. Es el único fármaco con beneficio demostrado en ritmos no desfibrilables (asistolia y AESP). La administración precoz se asocia a mejores resultados.',
      ),
      _EvalQuestion(
        question: '¿Cuál de las siguientes es una causa 5T de asistolia?',
        options: [
          'Hipoxia',
          'Hipovolemia',
          'Neumotórax a tensión',
          'Hipotermia',
        ],
        correctIndex: 2,
        explanation:
            '5T: Trombosis coronaria (IAM), Trombosis pulmonar (TEP), Taponamiento cardíaco, Tóxicos (sobredosis), Tensión (neumotórax a tensión). 5H: Hipoxia, Hipovolemia, H+, Hipo/Hiperpotasemia, Hipotermia.',
      ),
      _EvalQuestion(
        question: '¿Qué hallazgo en la ecografía FAST puede ayudar en asistolia?',
        options: [
          'Actividad cardíaca coordinada',
          'Ausencia de movimiento cardíaco (actividad eléctrica sin pulso)',
          'Derrame pericárdico indicando taponamiento',
          'Fracción de eyección normal',
        ],
        correctIndex: 2,
        explanation:
            'La ecografía FAST durante el paro puede identificar causas reversibles: derrame pericárdico (taponamiento), hipovolemia (VCI colapsada), neumotórax (ausencia de deslizamiento pulmonar), y actividad cardíaca (diferenciar asistolia verdadera de AESP fino).',
      ),
      _EvalQuestion(
        question: 'En asistolia, ¿cómo se administra la adrenalina?',
        options: [
          'Solo por vía IV central',
          'IV/IO en bolo, seguido de flush de 20 mL de SF',
          'Por vía endotraqueal a dosis triple',
          'En infusión continua',
        ],
        correctIndex: 1,
        explanation:
            'Adrenalina 1 mg IV/IO en bolo, seguido de flush de 20 mL de SF y elevar el brazo 10-20 segundos para facilitar la llegada central. Si no hay acceso IV/IO, se puede administrar por vía endotraqueal a dosis de 2-2.5 mg.',
      ),
      _EvalQuestion(
        question: '¿Cuándo se debe considerar terminar la reanimación en asistolia?',
        options: [
          'Después de 10 minutos de RCP sin ROSC',
          'Después de 20 minutos de RCP sin ROSC y sin causas reversibles identificadas',
          'Solo si el paciente lo solicitó anticipadamente',
          'La reanimación nunca debe detenerse',
        ],
        correctIndex: 1,
        explanation:
            'La decisión de terminar la reanimación es clínica. Generalmente, si tras 20-30 minutos de RCP avanzada no hay ROSC y no hay causas reversibles identificadas, se puede considerar terminar. Factores: paro no presenciado, ritmo inicial no desfibrilable, edad avanzada, comorbilidades.',
      ),
      _EvalQuestion(
        question: '¿Qué ritmo puede confundirse con asistolia en el monitor?',
        options: [
          'FV de baja amplitud (FV fina)',
          'TAV (TV de alta frecuencia)',
          'FA con RVR',
          'TSV',
        ],
        correctIndex: 0,
        explanation:
            'La FV fina (baja amplitud) puede confundirse con asistolia en el monitor. Por eso se confirma en dos derivaciones y se aumenta la ganancia. Si hay duda, tratar como FV (desfibrilar) porque la desfibrilación no empeora la asistolia verdadera.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la primera prioridad al confirmar asistolia?',
        options: [
          'Administrar atropina',
          'Iniciar RCP de alta calidad y establecer acceso IV/IO',
          'Colocar vía aérea avanzada inmediatamente',
          'Desfibrilar',
        ],
        correctIndex: 1,
        explanation:
            'Prioridad en asistolia: RCP 30:2 de alta calidad, establecer acceso IV/IO, administrar adrenalina 1 mg IV/IO lo antes posible, e identificar causas reversibles. La vía aérea avanzada se coloca idealmente después de 2 ciclos de RCP.',
      ),
      _EvalQuestion(
        question: '¿Qué diferencia a la AESP de la asistolia?',
        options: [
          'En AESP hay actividad eléctrica organizada pero sin pulso palpable',
          'No hay diferencia',
          'AESP tiene QRS anchos',
          'AESP siempre tiene pulso',
        ],
        correctIndex: 0,
        explanation:
            'AESP: hay actividad eléctrica cardíaca organizada (complejos QRS visibles) pero NO se palpa pulso ni hay gasto cardíaco efectivo. Asistolia: ausencia total de actividad eléctrica. Ambos son ritmos no desfibrilables y se tratan igual (RCP + adrenalina + causas reversibles).',
      ),
      _EvalQuestion(
        question: '¿Qué técnica de RCP se recomienda particularmente en asistolia para maximizar chances?',
        options: [
          'Compresiones de alta calidad con retroceso completo del tórax',
          'Compresiones lentas (60/min) para permitir llenado cardíaco',
          'Ventilaciones cada 2 segundos sin pausas',
          'Compresiones solo si hay ritmo en monitor',
        ],
        correctIndex: 0,
        explanation:
            'RCP de alta calidad: compresiones 100-120/min, profundidad 5-6 cm, retroceso completo del tórax, minimizar interrupciones (<10 segundos), relación 30:2. La calidad de las compresiones es el factor modificable más importante en el resultado del paro.',
      ),
      _EvalQuestion(
        question: '¿Cuándo se administra la primera dosis de adrenalina en asistolia?',
        options: [
          'Inmediatamente al confirmar el ritmo',
          'Después del primer ciclo de RCP (2 minutos)',
          'Después de 10 minutos de RCP',
          'Solo si no hay respuesta a la RCP',
        ],
        correctIndex: 0,
        explanation:
            'En ritmos no desfibrilables (asistolia/AESP), la adrenalina 1 mg IV/IO se administra lo antes posible. A diferencia de FV/TVSP donde se da tras la segunda descarga, en asistolia no hay demora porque la desfibrilación no está indicada.',
      ),
      _EvalQuestion(
        question: '¿Qué nivel de potasio sérico causa típicamente asistolia?',
        options: [
          'K+ > 6.5 mEq/L',
          'K+ < 3.0 mEq/L',
          'K+ 4.0-5.0 mEq/L',
          'K+ 5.5 mEq/L',
        ],
        correctIndex: 0,
        explanation:
            'Hiperpotasemia severa (K+ > 6.5 mEq/L) puede causar asistolia. Secuencia ECG: ondas T picudas → intervalo PR prolongado → pérdida de onda P → QRS ancho → fusión con T → asistolia. Tratamiento agudo: gluconato de calcio IV para estabilizar membrana.',
      ),
    ],
  ),
  _EvalScenario(
    id: 'eval_ecg_tsv',
    title: 'Taquicardia Supraventricular',
    subtitle: 'Ritmo estable · AHA 2020',
    caseText:
        'Mujer de 35 años, palpitaciones súbitas, dolor torácico leve, mareo. Frecuencia cardíaca 210 lpm. Monitor muestra QRS estrecho y regular. PA 110/70. Pulso presente.',
    color: Color(0xFF10B981),
    icon: Icons.monitor_heart_outlined,
    ecgRhythm: _EcgRhythmType.tsv,
    ecgRhythmLabel: 'TSV — QRS estrecho regular',
    ecgHeartRate: '~210 lpm',
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question: '¿Qué ritmo observas?',
        options: [
          'Taquicardia Ventricular',
          'Taquicardia Supraventricular (QRS estrecho)',
          'Fibrilación Auricular',
          'Bloqueo AV de 2do grado',
        ],
        correctIndex: 1,
        explanation:
            'TSV: QRS estrecho (<0.12s), regular, frecuencia >150 lpm (generalmente 180-250). Es un ritmo estable con pulso presente. A diferencia de la TV, los complejos son estrechos porque el origen está por encima del haz de His.',
      ),
      _EvalQuestion(
        question: 'La paciente está estable. ¿Cuál es la primera maniobra?',
        options: [
          'Cardioversión sincronizada inmediata',
          'Adenosina 6 mg en bolo IV rápido',
          'Manobras vagales (Valsalva o masaje carotídeo)',
          'Amiodarona 300 mg IV',
        ],
        correctIndex: 2,
        explanation:
            'En pacientes estables, primero se intentan maniobras vagales (Valsalva, masaje carotídeo unilateral). Si fallan, se administra adenosina 6 mg IV en bolo rápido. La cardioversión solo está indicada si hay inestabilidad.',
      ),
      _EvalQuestion(
        question: 'Si las maniobras vagales fallan, ¿qué fármaco usas?',
        options: [
          'Verapamilo 5 mg IV',
          'Adenosina 6 mg IV en bolo rápido',
          'Betabloqueante oral',
          'Digoxina',
        ],
        correctIndex: 1,
        explanation:
            'Adenosina 6 mg IV en bolo rápido (seguido de flush de SF) es el fármaco de elección para TSV estable. Puede repetirse a 12 mg si no hay respuesta. El verapamilo es alternativa si la adenosina está contraindicada (ej. asma severo).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la dosis inicial de adenosina en TSV?',
        options: [
          '3 mg IV en bolo rápido',
          '6 mg IV en bolo rápido',
          '12 mg IV en bolo rápido',
          '1 mg IV lento',
        ],
        correctIndex: 1,
        explanation:
          'Adenosina 6 mg IV en bolo rápido (1-3 segundos), seguido de flush de 20 mL de SF y elevar el brazo. Si no hay conversión en 1-2 minutos, administrar 12 mg IV. Dosis máxima: 12 mg. Tiene vida media < 10 segundos.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el mecanismo de acción de la adenosina?',
        options: [
          'Bloquea canales de calcio tipo L',
          'Activa receptores A1 de adenosina en el nodo AV, causando bloqueo AV transitorio',
          'Bloquea canales de sodio',
          'Estimula receptores beta-adrenérgicos',
        ],
        correctIndex: 1,
        explanation:
          'La adenosina activa receptores A1 en el nodo AV, produciendo hiperpolarización y bloqueo AV transitorio. Esto interrumpe el circuito de reentrada en la TSV. Efectos: enrojecimiento facial, disnea transitoria, dolor torácico, y bloqueo AV breve.',
      ),
      _EvalQuestion(
        question: '¿Qué es la maniobra de Valsalva modificada?',
        options: [
          'Soplar en una jeringa de 10 mL por 15 segundos en decúbito supino + elevar piernas',
          'Masaje carotídeo bilateral simultáneo',
          'Inmersión facial en agua fría',
          'Toser repetidamente',
        ],
        correctIndex: 0,
        explanation:
          'Valsalva modificada: paciente en posición semisentado, sopla en jeringa de 10 mL por 15 segundos (40 mmHg). Luego se acuesta en decúbito supino y se elevan las piernas a 45° por 15 segundos. Esto aumenta la precarga y la respuesta vagal. Tasa de éxito: ~43% (vs 17% Valsalva estándar).',
      ),
      _EvalQuestion(
        question: '¿Cuándo está indicada la cardioversión sincronizada en TSV?',
        options: [
          'Siempre como primera opción',
          'Solo si hay inestabilidad hemodinámica (PA < 90, dolor torácico, disnea, alteración conciencia)',
          'Nunca está indicada',
          'Solo si la FC > 250 lpm',
        ],
        correctIndex: 1,
        explanation:
          'Cardioversión sincronizada indicada en TSV inestable: hipotensión, dolor torácico, disnea, alteración del estado de conciencia. Energía inicial: 50-100J bifásico sincronizado. Si estable: primero maniobras vagales, luego adenosina.',
      ),
      _EvalQuestion(
        question: '¿Qué precaución tomar al administrar adenosina?',
        options: [
          'Administrar por vía IM si no hay acceso IV',
          'Tener desfibrilador disponible porque puede inducir FV en corazones con preexcitación (WPW)',
          'Mezclar con bicarbonato para evitar flebitis',
          'Administrar diluido en 250 mL de SF',
        ],
        correctIndex: 1,
        explanation:
          'La adenosina puede causar FA (1-3%) y, en pacientes con WPW (pre-excitación), puede degenerar a FV. Siempre tener desfibrilador disponible. Administrar en bolo rápido IV seguido de flush. No usar en asmáticos severos (puede causar broncoespasmo).',
      ),
      _EvalQuestion(
        question: '¿Qué caracteriza el masaje carotídeo como maniobra vagal?',
        options: [
          'Se masajea sobre el seno carotídeo (borde anterior del ECM, a nivel del cartílago tiroides) unilateralmente y con auscultación previa de carótidas',
          'Se masajean ambas carótidas simultáneamente',
          'Se masajea la carótida derecha durante 5 minutos',
          'No requiere precauciones especiales',
        ],
        correctIndex: 0,
        explanation:
          'Masaje carotídeo: auscultar carótidas primero (descartar soplos). Masajear el seno carotídeo derecho (lado más sensible) con movimientos circulares firmes por 5-10 segundos. Si no funciona, intentar izquierdo. NO bilateral simultáneo. Contraindicado si hay soplos carotídeos, ACV reciente, o enfermedad carotídea conocida.',
      ),
      _EvalQuestion(
        question: '¿Qué es el aleteo auricular típico?',
        options: [
          'Ritmo regular con ondas P en diente de sierra (ondas F) a ~300/min y conducción AV variable',
          'Ritmo irregular sin ondas P',
          'QRS anchos regulares',
          'Ritmo sinusal con PR prolongado',
        ],
        correctIndex: 0,
        explanation:
          'Aleteo auricular típico: circuito de reentrada en la aurícula derecha. Ondas F en "diente de sierra" a 250-350/min. La conducción AV suele ser 2:1 (FC ventricular ~150). Tratamiento: cardioversión sincronizada, ablación con radiofrecuencia, o control de frecuencia.',
      ),
      _EvalQuestion(
        question: '¿Qué ritmo se caracteriza por QRS estrecho, regular, sin ondas P visibles a 150-250 lpm?',
        options: [
          'Taquicardia Sinusal',
          'TSV por reentrada nodal AV',
          'FA con RVR',
          'Taquicardia Ventricular',
        ],
        correctIndex: 1,
        explanation:
          'TSV por reentrada nodal AV (la más común, ~60% de TSV): QRS estrecho, regular, frecuencia 150-250 lpm. Las ondas P están retrógradas y ocultas en el QRS o al final (pseudo-r en V1). Inicio y terminación súbita. Responde bien a adenosina.',
      ),
      _EvalQuestion(
        question: '¿Cómo diferenciar TSV de TV en ECG?',
        options: [
          'QRS estrecho (<0.12s) favorece TSV; QRS ancho (>0.12s) favorece TV',
          'La frecuencia cardíaca',
          'La edad del paciente',
          'La respuesta a la adenosina',
        ],
        correctIndex: 0,
        explanation:
          'QRS estrecho (<0.12s): supraventricular. QRS ancho (>0.12s): ventricular o supraventricular con aberrancia. Criterios de Brugada para diferenciar: ausencia de RS en todas las precordiales, RS > 100ms, disociación AV, criterios morfológicos en V1-V2.',
      ),
      _EvalQuestion(
        question: '¿En qué pacientes está contraindicada la adenosina?',
        options: [
          'Asma severo, WPW con FA, bloqueo AV de 2do/3er grado (sin marcapasos)',
          'Hipertensión arterial',
          'Diabetes mellitus',
          'Insuficiencia cardíaca crónica',
        ],
        correctIndex: 0,
        explanation:
          'Contraindicaciones de adenosina: asma severo (broncoespasmo), WPW con FA (riesgo de degeneración a FV), bloqueo AV de alto grado sin marcapasos, síndrome del seno enfermo, e hipersensibilidad. Usar con precaución en trasplantados cardíacos (dosis reducida a 1/3).',
      ),
      _EvalQuestion(
        question: '¿Qué fármaco de segunda línea se usa si adenosina falla?',
        options: [
          'Verapamilo 2.5-5 mg IV o diltiazem 0.25 mg/kg IV',
          'Amiodarona 300 mg IV en bolo',
          'Lidocaína 1.5 mg/kg IV',
          'Atropina 1 mg IV',
        ],
        correctIndex: 0,
        explanation:
          'Si adenosina falla o está contraindicada: verapamilo 2.5-5 mg IV (o diltiazem 0.25 mg/kg IV). NO usar betabloqueantes IV si hay asma/EPOC. La cardioversión sincronizada es otra opción. Esquema alternativo: betabloqueante IV (metoprolol 2.5-5 mg) si no hay contraindicación.',
      ),
      _EvalQuestion(
        question: 'En TSV con preexcitación (WPW), ¿qué fármaco está contraindicado?',
        options: [
          'Adenosina',
          'Verapamilo y digoxina (aceleran conducción por vía accesoria)',
          'Procainamida',
          'Amiodarona',
        ],
        correctIndex: 1,
        explanation:
          'En WPW con FA o TSV, los bloqueadores del nodo AV (verapamilo, diltiazem, digoxina) están contraindicados porque pueden acelerar la conducción por la vía accesoria y degenerar a FV. El fármaco de elección es procainamida o cardioversión eléctrica si inestable.',
      ),
      _EvalQuestion(
        question: '¿Qué energía se usa para cardioversión de TSV estable?',
        options: [
          '50-100J bifásico sincronizado',
          '200J bifásico no sincronizado',
          '360J bifásico sincronizado',
          '25J bifásico sincronizado',
        ],
        correctIndex: 0,
        explanation:
          'Cardioversión sincronizada de TSV: 50-100J bifásico inicial. Si falla, aumentar a 100-200J. Recordar activar la sincronización para evitar descargar en la onda T. La TSV generalmente requiere menos energía que la FA o el aleteo auricular.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la causa más frecuente de TSV en adultos jóvenes?',
        options: [
          'Reentrada nodal AV (vía lenta-rápida)',
          'Cardiopatía isquémica',
          'Insuficiencia cardíaca',
          'Hipertiroidismo',
        ],
        correctIndex: 0,
        explanation:
          'La TSV por reentrada nodal AV es la más frecuente en adultos jóvenes sin cardiopatía estructural. Es causada por un circuito de reentrada dentro del nodo AV (vía lenta y vía rápida). La ablación con radiofrecuencia tiene >95% de éxito y es curativa.',
      ),
      _EvalQuestion(
        question: '¿Qué hallazgo ECG sugiere taquicardia sinusal inapropiada (no TSV)?',
        options: [
          'Frecuencia 100-130 lpm, ondas P visibles y normales, inicio y fin gradual',
          'Frecuencia >150 lpm con inicio súbito',
          'QRS ancho con disociación AV',
          'Ritmo irregularmente irregular',
        ],
        correctIndex: 0,
        explanation:
          'Taquicardia sinusal: frecuencia 100-180 lpm, ondas P positivas en II, inicio y terminación gradual (no súbito). TSV por reentrada: inicio súbito (paroxístico), frecuencia 150-250 lpm, generalmente sin ondas P visibles. La taquicardia sinusal es una respuesta fisiológica normal.',
      ),
    ],
  ),
  _EvalScenario(
    id: 'eval_ecg_bav',
    title: 'Bloqueo AV de 3er Grado',
    subtitle: 'Bloqueo completo · AHA 2020',
    caseText:
        'Hombre de 70 años, presíncope, fatiga extrema, FC 35 lpm. Monitor muestra disociación auriculoventricular completa: ondas P regulares a 80/min, QRS lentos a 35/min, independientes entre sí.',
    color: Color(0xFF10B981),
    icon: Icons.monitor_heart_outlined,
    ecgRhythm: _EcgRhythmType.bav,
    ecgRhythmLabel: 'BAV 3er Grado — Disociación AV',
    ecgHeartRate: '35 lpm (V) / 80 lpm (A)',
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question: '¿Qué bloqueo AV presenta el paciente?',
        options: [
          'Bloqueo AV de 1er grado',
          'Bloqueo AV de 2do grado Mobitz I',
          'Bloqueo AV de 2do grado Mobitz II',
          'Bloqueo AV de 3er grado (completo)',
        ],
        correctIndex: 3,
        explanation:
            'BAV de 3er grado: hay disociación AV completa. Las aurículas y ventrículos laten independientemente. No hay conducción de impulsos supraventriculares a los ventrículos. La frecuencia ventricular de escape suele ser 30-45 lpm.',
      ),
      _EvalQuestion(
        question: 'El paciente está sintomático. ¿Cuál es el tratamiento?',
        options: [
          'Atropina 1 mg IV',
          'Isoproterenol en infusión',
          'Marcapasos transcutáneo',
          'Adrenalina en infusión',
        ],
        correctIndex: 2,
        explanation:
            'El paciente sintomático con BAV de 3er grado requiere marcapasos transcutáneo. Si no hay respuesta, se procede a marcapasos transvenoso. La atropina rara vez es efectiva en BAV de 3er grado. El isoproterenol es alternativa puente hasta marcapasos definitivo.',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es una causa común de BAV de 3er grado en adultos mayores?',
        options: [
          'Enfermedad cardíaca isquémica',
          'Hipertiroidismo',
          'Miocardiopatía hipertrófica',
          'Estenosis aórtica',
        ],
        correctIndex: 0,
        explanation:
            'La enfermedad cardíaca isquémica (IAM inferoposterior) es la causa más común de BAV de 3er grado adquirido. Otras causas: enfermedad degenerativa del sistema de conducción, fármacos (betabloqueantes, Ca-antagonistas), miocarditis, y trastornos infiltrativos.',
      ),
      _EvalQuestion(
        question: '¿Qué caracteriza al BAV de 3er grado en el ECG?',
        options: [
          'PR progresivamente prolongado',
          'Disociación AV completa: P y QRS independientes',
          'Intervalo PR fijo > 0.20s',
          'Ondas P en diente de sierra',
        ],
        correctIndex: 1,
        explanation:
            'BAV de 3er grado: ninguna onda P conduce a los ventrículos. Hay disociación AV completa. Las aurículas laten a su propio ritmo (generalmente 60-100/min por el nodo sinusal) y los ventrículos a un ritmo de escape (40-60/min si escape nodal, 30-45/min si escape ventricular).',
      ),
      _EvalQuestion(
        question: '¿Qué frecuencia ventricular suele tener un BAV de 3er grado con escape ventricular?',
        options: [
          '60-80 lpm',
          '30-45 lpm',
          '100-120 lpm',
          '> 120 lpm',
        ],
        correctIndex: 1,
        explanation:
          'Escape ventricular (idioventricular): QRS anchos (aberrantes) a 30-45 lpm. Escape nodal (juncional): QRS estrechos a 40-60 lpm. La frecuencia ventricular lenta es la causa de los síntomas (fatiga, presíncope, síncope, disnea de esfuerzo).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la primera línea de tratamiento en BAV de 3er grado sintomático?',
        options: [
          'Atropina 1 mg IV',
          'Marcapasos transcutáneo',
          'Isoproterenol en infusión',
          'Adrenalina 1 mg IV',
        ],
        correctIndex: 1,
        explanation:
          'Marcapasos transcutáneo (externo) es el tratamiento inmediato en BAV de 3er grado sintomático. Se colocan parches adhesivos en posición anteroposterior. Se programa frecuencia 60-80 lpm y se titula la salida (mA) hasta captura. Luego marcapasos transvenoso definitivo.',
      ),
      _EvalQuestion(
        question: '¿Qué es el fenómeno de Stokes-Adams?',
        options: [
          'Síncope súbito por asistolia o bradicardia extrema en BAV de alto grado',
          'Hipertensión arterial maligna',
          'IAM sin elevación del ST',
          'Edema pulmonar agudo',
        ],
        correctIndex: 0,
        explanation:
          'Crisis de Stokes-Adams: pérdida súbita del conocimiento por asistencia ventricular prolongada (pausa > 5-10 segundos). Ocurre típicamente en la transición de BAV de 2do grado a 3er grado completo (mientras el escape ventricular emerge). Puede causar convulsiones (confundido con epilepsia).',
      ),
      _EvalQuestion(
        question: '¿Qué bloqueo AV se asocia típicamente a IAM inferoposterior?',
        options: [
          'BAV de 1er grado y BAV de 2do grado Mobitz I (Wenckebach)',
          'BAV de 2do grado Mobitz II',
          'BAV de 3er grado con QRS estrecho',
          'BAV de 3er grado con QRS ancho',
        ],
        correctIndex: 0,
        explanation:
          'IAM inferoposterior (CD o CX): causa BAV a nivel del nodo AV (generalmente reversible). Se presenta como BAV 1er grado → Mobitz I (Wenckebach) → BAV 3er grado con QRS estrecho (escape nodal). IAM anterior (DA): causa BAV infranodal (Mobitz II o BAV 3er grado con QRS ancho y escape ventricular), peor pronóstico.',
      ),
      _EvalQuestion(
        question: '¿Qué bloqueo AV requiere marcapasos definitivo independientemente de síntomas?',
        options: [
          'BAV de 3er grado (completo)',
          'BAV de 1er grado aislado',
          'Mobitz I asintomático',
          'Bloqueo sinoauricular',
        ],
        correctIndex: 0,
        explanation:
          'El BAV de 3er grado (completo) es indicación clase I de marcapasos definitivo permanente, independientemente de los síntomas, porque el riesgo de muerte súbita es alto. Mobitz II sintomático también requiere marcapasos. Mobitz I asintomático NO requiere marcapasos (excepto si es infranodal).',
      ),
      _EvalQuestion(
        question: '¿Cómo se reconoce el BAV de 1er grado en el ECG?',
        options: [
          'Intervalo PR > 0.20s con todos los QRS precedidos por onda P',
          'Intervalo PR progresivamente prolongado hasta QRS perdido',
          'Intervalo PR constante con QRS ocasionalmente no conducido',
          'Disociación AV completa',
        ],
        correctIndex: 0,
        explanation:
          'BAV de 1er grado: intervalo PR > 0.20s (200ms). Todas las ondas P conducen a QRS. Generalmente benigno y asintomático. Puede ser por aumento del tono vagal, fármacos (betabloqueantes, Ca-antagonistas, digoxina), o enfermedad del nodo AV.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el patrón de Wenckebach (Mobitz I)?',
        options: [
          'PR se prolonga progresivamente hasta que una onda P no conduce',
          'PR constante con QRS perdido intermitentemente',
          'PR > 0.20s fijo',
          'P y QRS completamente independientes',
        ],
        correctIndex: 0,
        explanation:
          'Wenckebach: el intervalo PR se alarga progresivamente latido a latido hasta que una onda P no conduce (QRS perdido). Luego el PR se acorta y el ciclo se repite. Típicamente en el nodo AV (reversible, asociado a IAM inferior). Buen pronóstico.',
      ),
      _EvalQuestion(
        question: '¿Qué caracteriza al Mobitz II?',
        options: [
          'PR constante con QRS no conducidos intermitentemente (proporción 2:1, 3:1)',
          'PR progresivamente prolongado',
          'PR variable',
          'P y QRS independientes',
        ],
        correctIndex: 0,
        explanation:
          'Mobitz II: el intervalo PR es constante. De repente, una onda P no conduce (QRS perdido). Generalmente indica enfermedad infranodal (sistema His-Purkinje). Más riesgo de progresar a BAV completo. Requiere marcapasos si es sintomático o hay QRS ancho.',
      ),
      _EvalQuestion(
        question: '¿Qué relación AV es característica del BAV 2:1?',
        options: [
          'Dos ondas P por cada QRS (una conduce, una no)',
          'Tres ondas P por cada QRS',
          'Una onda P por cada dos QRS',
          'P y QRS independientes',
        ],
        correctIndex: 0,
        explanation:
          'BAV 2:1: dos ondas P por cada QRS. La primera P conduce, la segunda no. No se puede clasificar como Mobitz I o II porque se necesita ver el comportamiento del PR en latidos consecutivos. Si el PR del QRS conducido es normal y el QRS es ancho, sugiere Mobitz II (infranodal).',
      ),
      _EvalQuestion(
        question: '¿Qué fármaco PUEDE usarse temporalmente como puente al marcapasos en BAV de 3er grado sintomático?',
        options: [
          'Atropina 0.5-1 mg IV',
          'Isoproterenol en infusión (2-10 mcg/min)',
          'Adenosina 6 mg IV',
          'Verapamilo 5 mg IV',
        ],
        correctIndex: 1,
        explanation:
          'Isoproterenol (infusión 2-10 mcg/min) aumenta la frecuencia del escape ventricular transitoriamente hasta colocar marcapasos. NO usar en cardiopatía isquémica (aumenta consumo miocárdico). La atropina rara vez es efectiva en BAV infranodal o de 3er grado.',
      ),
      _EvalQuestion(
        question: 'En BAV de 3er grado, ¿cómo se confirma la disociación AV?',
        options: [
          'Las ondas P no tienen relación fija con los QRS; la frecuencia auricular > ventricular',
          'Las ondas P y QRS tienen la misma frecuencia',
          'El intervalo PR es constante',
          'No hay ondas P visibles',
        ],
        correctIndex: 0,
        explanation:
          'Disociación AV: aurículas y ventrículos laten independientemente. La frecuencia auricular (marcapasos sinusal) es > ventricular (escape). No hay relación PR constante. Las ondas P pueden "cabalgar" sobre los QRS (ocultas dentro del complejo). Confirmar con tira larga de ritmo.',
      ),
      _EvalQuestion(
        question: '¿Qué ancho de QRS sugiere escape ventricular en BAV completo?',
        options: [
          'QRS estrecho (<0.12s)',
          'QRS ancho (>0.12s, generalmente >0.14s)',
          'QRS variable',
          'No hay QRS',
        ],
        correctIndex: 1,
        explanation:
          'Escape ventricular: QRS anchos (aberrados) a 30-45 lpm. Escape nodal (juncional): QRS estrechos a 40-60 lpm. Si el escape tiene QRS ancho, el bloqueo es infranodal (en el sistema His-Purkinje), asociado a peor pronóstico y mayor riesgo de muerte súbita.',
      ),
      _EvalQuestion(
        question: '¿Qué precaución tomar al colocar marcapasos transcutáneo?',
        options: [
          'Usar analgesia/sedación porque la estimulación es dolorosa',
          'Colocar parches en el abdomen',
          'Usar la mínima frecuencia posible (30 lpm)',
          'No es necesario monitorizar ECG',
        ],
        correctIndex: 0,
        explanation:
          'Marcapasos transcutáneo: requiere analgesia/sedación (la corriente estimula músculos pectorales e intercostales). Parches en posición anteroposterior (esternal izquierdo + espalda). Verificar captura eléctrica (QRS ancho tras espiga) y captura mecánica (pulso palpable). Programar 60-80 lpm.',
      ),
      _EvalQuestion(
        question: '¿Qué bloqueo AV se asocia a sobredosis de betabloqueantes o verapamilo?',
        options: [
          'BAV de 1er grado',
          'BAV de cualquier grado, incluyendo 3er grado',
          'Mobitz I exclusivamente',
          'Ninguno, estos fármacos no causan bloqueo AV',
        ],
        correctIndex: 1,
        explanation:
          'Betabloqueantes y bloqueadores de canales de calcio (no dihidropiridínicos) pueden causar BAV de cualquier grado. Tratamiento: suspender fármaco, glucagón (para betabloqueantes), calcio IV (para Ca-antagonistas), atropina, marcapasos. El BAV inducido por fármacos suele ser reversible.',
      ),
      _EvalQuestion(
        question: '¿Cuándo se considera que un BAV de 3er grado es paroxístico?',
        options: [
          'Cuando aparece y desaparece espontáneamente, alternando con conducción 1:1',
          'Cuando nunca hay conducción',
          'Cuando es asintomático',
          'Cuando la frecuencia ventricular es > 50 lpm',
        ],
        correctIndex: 0,
        explanation:
          'BAV paroxístico: episodios transitorios de BAV completo que alternan con conducción normal. Puede ocurrir en pacientes con enfermedad del sistema de conducción intermitente, IAM inferior transitorio, o fármacos. Síntomas: presíncope/síncope recurrente (Stokes-Adams).',
      ),
    ],
  ),
  _EvalScenario(
    id: 'eval_ecg_fa_rvr',
    title: 'Fibrilación Auricular con RVR',
    subtitle: 'Ritmo irregular · AHA 2020',
    caseText:
        'Mujer de 65 años, disnea súbita, palpitaciones, FC 150 lpm. Monitor muestra ritmo irregularmente irregular sin ondas P distinguibles. PA 100/60. Sat O2 94%. Pulso presente.',
    color: Color(0xFF10B981),
    icon: Icons.favorite_rounded,
    ecgRhythm: _EcgRhythmType.fa,
    ecgRhythmLabel: 'FA — Irregularmente irregular',
    ecgHeartRate: '~150 lpm (RVR)',
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question: '¿Qué caracteriza este ritmo?',
        options: [
          'Complejos QRS estrechos con ritmo regular',
          'Ritmo irregularmente irregular sin ondas P',
          'Ondas P en diente de sierra',
          'Complejos QRS anchos con disociación AV',
        ],
        correctIndex: 1,
        explanation:
            'La FA se caracteriza por ritmo irregularmente irregular, ausencia de ondas P y línea basal caótica. La respuesta ventricular rápida (RVR) ocurre cuando la frecuencia es >100 lpm. Es el tipo más común de arritmia sostenida.',
      ),
      _EvalQuestion(
        question: 'La paciente está inestable. ¿Qué haces?',
        options: [
          'Cardioversión sincronizada',
          'Betabloqueante IV',
          'Amiodarona en infusión',
          'Anticoagulación oral',
        ],
        correctIndex: 0,
        explanation:
            'Paciente inestable con FA + RVR: cardioversión sincronizada inmediata (100-200J bifásico). Si está estable, se puede controlar frecuencia con betabloqueantes o calcio-antagonistas. La anticoagulación se evalúa después de estabilizar.',
      ),
      _EvalQuestion(
        question: '¿Qué puntuación se usa para valorar riesgo de ACV en FA?',
        options: [
          'APACHE II',
          'CHADS-VASc',
          'SOFA',
          'TIMI',
        ],
        correctIndex: 1,
        explanation:
            'El score CHADS-VASc (Insuficiencia Cardíaca, Hipertensión, Edad ≥75, Diabetes, ACV/AIT, Enfermedad Vascular, Edad 65-74, Sexo femenino) evalúa el riesgo de ACV en FA. Puntuación ≥2 en hombres o ≥3 en mujeres indica anticoagulación. El score HAS-BLED evalúa riesgo de sangrado.',
      ),
      _EvalQuestion(
        question: '¿Qué significa RVR en FA?',
        options: [
          'Respuesta Ventricular Rápida (frecuencia ventricular > 100 lpm)',
          'Ritmo Ventricular Regular',
          'Recuperación Ventricular Retrógrada',
          'Resistencia Vascular Renal',
        ],
        correctIndex: 0,
        explanation:
          'RVR = Respuesta Ventricular Rápida (Rapid Ventricular Rate). En FA, la frecuencia ventricular (respuesta ventricular) es > 100 lpm. Esto ocurre porque la conducción AV es rápida a través del nodo AV. El objetivo del control de frecuencia es mantener FC < 80 lpm en reposo y < 110 lpm en esfuerzo leve.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la primera línea para control de frecuencia en FA aguda estable?',
        options: [
          'Betabloqueantes IV (metoprolol 2.5-5 mg o esmolol)',
          'Amiodarona en bolo',
          'Digoxina 0.5 mg IV',
          'Cardioversión eléctrica',
        ],
        correctIndex: 0,
        explanation:
          'Betabloqueantes IV (metoprolol, esmolol, propranolol) son primera línea para control de frecuencia en FA aguda en pacientes estables. Alternativa: diltiazem 0.25 mg/kg IV si los betabloqueantes están contraindicados (asma, EPOC). Digoxina es de segunda línea (menos efectiva en estados hiperadrenérgicos).',
      ),
      _EvalQuestion(
        question: '¿Cuándo se prefiere control de ritmo sobre control de frecuencia en FA?',
        options: [
          'FA sintomática a pesar de control de frecuencia, FA paroxística, FA en jóvenes sin cardiopatía',
          'Siempre se prefiere control de ritmo',
          'En pacientes > 80 años siempre control de frecuencia',
          'En FA asintomática',
        ],
        correctIndex: 0,
        explanation:
          'Control de ritmo (intentar convertir a sinusal) se prefiere en: FA sintomática persistente, FA paroxística, pacientes jóvenes, primera aparición de FA, o cuando falla control de frecuencia. Opciones: cardioversión eléctrica, antiarrítmicos (amiodarona, flecainida, propafenona, sotalol) o ablación.',
      ),
      _EvalQuestion(
        question: '¿Qué score evalúa el riesgo de sangrado por anticoagulación en FA?',
        options: [
          'CHA2DS2-VASc',
          'HAS-BLED (Hipertensión, Insuf Renal/Hepática, ACV, Sangrado, INR lábil, Edad >65, Drogas/Alcohol)',
          'TIMI',
          'GRACE',
        ],
        correctIndex: 1,
        explanation:
          'HAS-BLED: H=Hipertensión (1), A=Insuficiencia Renal/Hepática (1-2), S=ACV previo (1), B=Sangrado previo/predisposición (1), L=INR lábil (1), E=Edad >65 (1), D=Drogas (1) + Alcohol (1). Puntuación ≥3 indica alto riesgo de sangrado y requiere revisión de indicación de anticoagulación y seguimiento estrecho.',
      ),
      _EvalQuestion(
        question: '¿Qué fármaco antiarrítmico puede usarse para cardioversión farmacológica de FA aguda?',
        options: [
          'Flecainida 2 mg/kg IV o 300 mg VO (si no hay cardiopatía estructural)',
          'Lidocaína 1.5 mg/kg IV',
          'Adenosina 6 mg IV',
          'Atropina 1 mg IV',
        ],
        correctIndex: 0,
        explanation:
          'Flecainida (Clase IC) es efectiva en cardioversión farmacológica de FA aguda (píldora en el bolsillo). Contraindicada en cardiopatía estructural (IAM previo, FEVI < 40%, hipertrofia VI) por riesgo proarrítmico (CAST trial). Alternativa: propafenona, amiodarona, ibutilida.',
      ),
      _EvalQuestion(
        question: '¿Qué es el fenómeno de "lone atrial fibrillation"?',
        options: [
          'FA en pacientes < 60 años sin cardiopatía estructural ni factores de riesgo cardiovascular',
          'FA con FC > 200 lpm',
          'FA persistente > 1 año',
          'FA post-operatoria',
        ],
        correctIndex: 0,
        explanation:
          'Lone FA (FA aislada): ocurre en pacientes menores de 60 años sin evidencia de cardiopatía estructural (ECG normal, ECO normal) ni factores de riesgo (HTA, DM, obesidad). Tiene bajo riesgo de tromboembolismo (CHA2DS2-VASc = 0 en hombres, 1 en mujeres) y puede no requerir anticoagulación, aunque guías recientes sugieren reevaluar periódicamente.',
      ),
      _EvalQuestion(
        question: '¿Cuándo se debe anticoagular en FA antes de cardioversión?',
        options: [
          'FA de < 48h: anticoagulación no es necesaria si no hay factores de riesgo',
          'FA > 48h o duración desconocida: anticoagular 3 semanas previas + 4 semanas post cardioversión',
          'Nunca es necesaria',
          'Solo si CHA2DS2-VASc ≥ 2',
        ],
        correctIndex: 1,
        explanation:
          'FA > 48h o duración desconocida: requiere anticoagulación terapéutica (warfarina INR 2-3 o DOAC) por ≥ 3 semanas antes de cardioversión Y continuar ≥ 4 semanas después. Alternativa: ECO transesofágico (ETE) para descartar trombos auriculares izquierdos antes de cardioversión (pero igual anticoagular 4 semanas post).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la energía recomendada para cardioversión de FA?',
        options: [
          '50-100J bifásico sincronizado',
          '100-200J bifásico sincronizado',
          '360J bifásico no sincronizado',
          '200J monofásico no sincronizado',
        ],
        correctIndex: 1,
        explanation:
          'Cardioversión de FA: 100-200J bifásico sincronizado. Si falla, aumentar a 360J bifásico. Aleteo auricular requiere menos energía (50-100J). Usar parches adhesivos en posición anteroposterior para mejor vector de corriente. Sincronizar para evitar descargar en la onda T.',
      ),
      _EvalQuestion(
        question: '¿Qué es la miocardiopatía inducida por taquicardia?',
        options: [
          'Disfunción ventricular izquierda reversible causada por FA persistente con RVR',
          'Cardiopatía isquémica por taquicardia',
          'Miocarditis viral',
          'Cardiopatía hipertrófica',
        ],
        correctIndex: 0,
        explanation:
          'Miocardiopatía por taquicardia: FA rápida y persistente que causa disfunción VI reversible (taquimiocardiopatía). El tratamiento es control de ritmo (cardioversión + antiarrítmico) o control estricto de frecuencia (FC < 80). La función VI mejora en semanas a meses tras restaurar ritmo/frecuencia normal.',
      ),
      _EvalQuestion(
        question: '¿Qué DOAC está contraindicado en FA con estenosis mitral reumática moderada-severa?',
        options: [
          'Rivaroxabán',
          'Apixabán',
          'Todos los DOACs están contraindicados (preferir warfarina)',
          'Edoxabán',
        ],
        correctIndex: 2,
        explanation:
          'Los DOACs (apixabán, rivaroxabán, edoxabán, dabigatrán) están contraindicados en FA con estenosis mitral reumática moderada-severa y en válvulas mecánicas. En estos casos usar warfarina (INR 2-3 o 2.5-3.5 según tipo de válvula). DOACs están indicados en FA no valvular (incluyendo estenosis mitral leve, insuficiencia mitral, estenosis aórtica).',
      ),
      _EvalQuestion(
        question: '¿Qué ritmo se caracteriza por ondas F en "diente de sierra" (aleteo)?',
        options: [
          'Fibrilación Auricular',
          'Aleteo Auricular típico (Flutter)',
          'Taquicardia Supraventricular',
          'Taquicardia Sinusal',
        ],
        correctIndex: 1,
        explanation:
          'Aleteo auricular: ondas F en "diente de sierra" a 250-350/min, especialmente visibles en II, III, aVF. Típicamente hay conducción AV 2:1 (FC ventricular ~150). Es un circuito de reentrada en la aurícula derecha (istmo cavotricuspídeo). Tratamiento: ablación del istmo (>95% curación), o cardioversión + antiarrítmico.',
      ),
      _EvalQuestion(
        question: '¿Qué fármaco aumenta el riesgo de ACV en FA y debe evitarse?',
        options: [
          'AINEs (antiinflamatorios no esteroideos)',
          'Paracetamol',
          'Estatinas',
          'IECA',
        ],
        correctIndex: 0,
        explanation:
          'Los AINEs (incluyendo aspirina en dosis altas) aumentan el riesgo de sangrado gastrointestinal y renal en pacientes con FA anticoagulados. Además, los AINEs aumentan el riesgo de ACV y eventos cardiovasculares por mecanismos pro-trombóticos y de retención de sodio/agua que pueden descompensar la insuficiencia cardíaca.',
      ),
      _EvalQuestion(
        question: 'En FA, ¿cuándo se usa amiodarona como antiarrítmico de elección?',
        options: [
          'En pacientes con cardiopatía estructural (FEVI < 40% o IAM previo)',
          'En FA aislada en jóvenes',
          'Solo para cardioversión aguda',
          'Nunca, siempre hay mejores opciones',
        ],
        correctIndex: 0,
        explanation:
          'Amiodarona es el antiarrítmico más seguro en pacientes con cardiopatía estructural (FEVI reducida, IAM previo) porque tiene menor riesgo proarrítmico que otros antiarrítmicos (flecainida, propafenona, sotalol). Efectos adversos: toxicidad tiroidea, pulmonar, hepática, corneal, fotosensibilidad. Requiere monitoreo periódico.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la definición de FA paroxística?',
        options: [
          'FA que se autolimita en < 7 días (generalmente < 48h)',
          'FA que dura > 7 días',
          'FA persistente > 1 año',
          'FA permanente (se acepta la arritmia)',
        ],
        correctIndex: 0,
        explanation:
          'FA paroxística: episodios que terminan espontáneamente en < 7 días (la mayoría < 48h). FA persistente: dura > 7 días o requiere cardioversión. FA persistente de larga duración: > 1 año. FA permanente: se acepta la arritmia y se controla frecuencia. La FA paroxística tiene más riesgo de recurrencia pero mejor respuesta a control de ritmo.',
      ),
      _EvalQuestion(
        question: '¿Qué intervención quirúrgica se realiza junto a cirugía cardíaca para tratar FA?',
        options: [
          'Cox-Maze (laberinto)',
          'Revascularización miocárdica',
          'Reemplazo valvular aórtico',
          'Cierre de orejuela izquierda',
        ],
        correctIndex: 0,
        explanation:
          'Procedimiento Cox-Maze (laberinto): se crean líneas de ablación quirúrgica en ambas aurículas para aislar las venas pulmonares y eliminar circuitos de reentrada para la FA. Se realiza concomitante a cirugía cardíaca (CABG, reemplazo valvular) en pacientes con FA sintomática. Tasa de éxito > 90% a 1 año.',
      ),
    ],
  ),
  // ─── NUEVOS CASOS CLÍNICOS ──────────────────────────────────────────────────
  _EvalScenario(
    id: 'eval_infeccion_neumonia',
    title: 'Neumonía Grave',
    subtitle: 'Sepsis por neumonía adquirida en comunidad · AHA 2020',
    caseText:
        'Hombre de 65 años con fiebre, disnea y expectoración purulenta. FR 32 rpm, SatO2 85% al aire, PA 90/50, confuso. Rx tórax: consolidación lóbulo inferior derecho.',
    color: AppColors.orange,
    icon: Icons.local_hospital_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question: '¿Qué criterios definen el shock séptico?',
        options: [
          'Infección + hipotensión que requiere vasopresores para PAM ≥ 65 + lactato > 2 mmol/L a pesar de reanimación con volumen',
          'Infección + fiebre > 38.5°C',
          'Infección + leucocitosis',
          'Infección + taquicardia',
        ],
        correctIndex: 0,
        explanation:
            'Shock séptico: hipotensión persistente que requiere vasopresores para mantener PAM ≥ 65 mmHg Y lactato sérico > 2 mmol/L a pesar de reanimación adecuada con volumen (Surviving Sepsis Campaign 2021).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la primera hora crítica en sepsis?',
        options: [
          'Cultivos + antibiótico de amplio espectro + medición de lactato dentro de la primera hora de reconocimiento',
          'Esperar resultados de cultivos',
          'Solo administrar antipiréticos',
          'Iniciar vasopresores inmediatamente sin líquidos',
        ],
        correctIndex: 0,
        explanation:
            'Cumplir el paquete de 1 hora: medir lactato, obtener hemocultivos, administrar antibiótico de amplio espectro, iniciar cristaloides 30 mL/kg si hipotensión/lactato elevado, iniciar vasopresores si PAM < 65 (Surviving Sepsis Campaign 2021).',
      ),
      _EvalQuestion(
        question:
            '¿Qué antibiótico empírico se recomienda en neumonía grave adquirida en comunidad?',
        options: [
          'Beta-lactámico (ceftriaxona/piperacilina-tazobactam) + macrólido (azitromicina)',
          'Vancomicina sola',
          'Ciprofloxacino oral',
          'Metronidazol + gentamicina',
        ],
        correctIndex: 0,
        explanation:
            'Neumonía grave: beta-lactámico + macrólido. Opciones: ceftriaxona + azitromicina, o piperacilina-tazobactam + azitromicina. Cubrir S. pneumoniae, Legionella, S. aureus incluyendo MRSA si hay factores de riesgo (IDSA/ATS 2019).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el objetivo de presión arterial media en shock séptico?',
        options: [
          'PAM ≥ 65 mmHg',
          'PAM ≥ 80 mmHg',
          'PAM ≥ 50 mmHg',
          'PAS ≥ 90 mmHg',
        ],
        correctIndex: 0,
        explanation:
            'Objetivo inicial: PAM ≥ 65 mmHg. En pacientes con hipertensión crónica o aterosclerosis, considerar objetivo más alto (PAM 80-85) si hay evidencia de hipoperfusión persistente (Surviving Sepsis Campaign 2021).',
      ),
      _EvalQuestion(
        question: '¿Qué vasopresor es de primera línea en shock séptico?',
        options: [
          'Noradrenalina (norepinefrina)',
          'Dopamina',
          'Fenilefrina',
          'Vasopresina',
        ],
        correctIndex: 0,
        explanation:
            'Noradrenalina es el vasopresor de primera línea. Iniciar a 5-15 mcg/min y titular para PAM ≥ 65. Si dosis altas requieren segundo agente: añadir vasopresina (0.03-0.04 U/min) o adrenalina (Surviving Sepsis Campaign 2021).',
      ),
    ],
  ),
  // Infección: Urosepsis
  _EvalScenario(
    id: 'eval_infeccion_urosepsis',
    title: 'Urosepsis',
    subtitle: 'Sepsis de origen urinario · AHA 2020',
    caseText:
        'Mujer de 78 años con DM tipo 2, portadora de sonda vesical permanente, presenta fiebre 39°C, hipotensión PA 80/40, confusión. Uroanálisis: piuria + nitritos +. Creatinina 2.5 mg/dL.',
    color: AppColors.orange,
    icon: Icons.medical_services_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question: '¿Cuál es el germen más frecuente en urosepsis?',
        options: [
          'Escherichia coli (gram-negativo)',
          'Staphylococcus aureus',
          'Enterococcus faecalis',
          'Pseudomonas aeruginosa',
        ],
        correctIndex: 0,
        explanation:
            'E. coli es el microorganismo más frecuente (50-60% de las infecciones urinarias complicadas y urosepsis). Otros: Klebsiella, Proteus, Enterobacter, Pseudomonas (en pacientes con instrumentación o antibióticos previos) (IDSA 2020, Surviving Sepsis Campaign 2021).',
      ),
      _EvalQuestion(
        question: '¿Qué factor de riesgo es más relevante en esta paciente?',
        options: [
          'Sonda vesical permanente (dispositivo urinario)',
          'Edad avanzada sola',
          'Diabetes mellitus sola',
          'Sexo femenino',
        ],
        correctIndex: 0,
        explanation:
            'La sonda vesical es el factor de riesgo más importante para bacteriuria y urosepsis, especialmente en pacientes mayores con comorbilidades. La sonda debe retirarse lo antes posible (cultivo de punta al retirar). Foco de infección nosocomial más frecuente (IDSA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuándo deben obtenerse los cultivos en sospecha de sepsis?',
        options: [
          'Antes de administrar antibióticos (idealmente en los primeros 45 min de reconocimiento)',
          'Después de la primera dosis de antibiótico',
          'Solo si el paciente tiene fiebre > 38.5°C',
          'Los cultivos no son necesarios si hay urocultivo',
        ],
        correctIndex: 0,
        explanation:
            'Obtener hemocultivos (2 frascos) y urocultivo antes de antibióticos. Esto no debe retrasar > 45 min la administración del antibiótico. Si no se pueden obtener inmediatamente, administrar antibiótico y obtener cultivos después (Surviving Sepsis Campaign 2021).',
      ),
      _EvalQuestion(
        question:
            '¿Qué antibiótico empírico se recomienda en urosepsis comunitaria?',
        options: [
          'Ceftriaxona 2g IV cada 24h + posible aminoglucósido si shock',
          'Trimetroprim-sulfametoxazol VO',
          'Nitrofurantoina IV',
          'Ciprofloxacino 500 mg VO cada 12h',
        ],
        correctIndex: 0,
        explanation:
            'Ceftriaxona cubre gram-negativos incluyendo la mayoría de E. coli y Klebsiella. En shock séptico o resistencia, añadir aminoglucósido (amikacina/gentamicina). Si sospecha de Pseudomonas (hospitalización reciente): piperacilina-tazobactam o cefepime (IDSA 2020).',
      ),
      _EvalQuestion(
        question: '¿Qué manejo de la sonda se recomienda?',
        options: [
          'Retirar la sonda y colocar nueva si es necesaria; cultivo de punta de sonda',
          'Cambiar la sonda cada 24h con antibióticos profilácticos',
          'Mantener la sonda y administrar antibióticos intravenosos',
          'Retirar la sonda permanentemente sin reemplazo',
        ],
        correctIndex: 0,
        explanation:
            'La sonda debe retirarse y reemplazarse por una nueva si aún se requiere monitoreo de diuresis. El cultivo de la punta de la sonda retirada ayuda a guiar la terapia antibiótica. La sonda es cuerpo extraño que perpetúa la infección (IDSA 2020, Surviving Sepsis 2021).',
      ),
    ],
  ),
  // Infección: Endocarditis Infecciosa
  _EvalScenario(
    id: 'eval_infeccion_endocarditis',
    title: 'Endocarditis Infecciosa',
    subtitle: 'Endocarditis bacteriana aguda · ESC 2023',
    caseText:
        'Varón de 45 años, adicto a heroína IV, presenta fiebre 39.5°C, soplo cardíaco nuevo, petequias conjuntivales y dedo en martillo. Hemocultivos positivos para S. aureus.',
    color: AppColors.orange,
    icon: Icons.favorite_border_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuáles son los criterios mayores de Duke modificados para endocarditis infecciosa?',
        options: [
          'Hemocultivo positivo (2 frascos separados para microorganismo típico) + ecocardiograma con vegetación/absceso/nueva dehiscencia de válvula protésica',
          'Fiebre + soplo cardíaco + esplenomegalia',
          'PCR elevada + leucocitosis + anemia',
          'Ecocardiograma anormal + fiebre sin otra causa',
        ],
        correctIndex: 0,
        explanation:
            'Criterios mayores de Duke: (1) Hemocultivos positivos para microorganismo típico (S. aureus, S. viridans, Enterococcus) en ≥ 2 muestras separadas, (2) Evidencia de compromiso endocárdico: ecocardiograma (vegetación, absceso, dehiscencia valvular protésica nueva) o regurgitación valvular nueva (ESC 2023).',
      ),
      _EvalQuestion(
        question: '¿Qué válvula es más frecuentemente afectada en ADIV?',
        options: [
          'Válvula tricúspide (endocarditis derecha)',
          'Válvula mitral',
          'Válvula aórtica',
          'Válvula pulmonar',
        ],
        correctIndex: 0,
        explanation:
            'En ADIV (adicto a drogas intravenosas), la válvula tricúspide es la más afectada (40-60%) por S. aureus. Las embolias sépticas pulmonares múltiples son características. La endocarditis derecha tiene mejor pronóstico que la izquierda (ESC 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el tratamiento antibiótico empírico en endocarditis aguda por S. aureus?',
        options: [
          'Oxacilina/cefazolina + gentamicina (si sensible) o vancomicina si MRSA',
          'Vancomicina + rifampicina + gentamicina siempre',
          'Penicilina G + gentamicina',
          'Ceftriaxona 2g IV cada 24h sola',
        ],
        correctIndex: 0,
        explanation:
            'S. aureus sensible a meticilina: oxacilina/cefazolina + gentamicina (sinergia). MRSA (sospechar si nosocomial o resistencia previa): vancomicina o daptomicina. Duración 4-6 semanas para válvula nativa, ≥ 6 semanas para válvula protésica (AHA 2020, ESC 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo está indicada la cirugía valvular urgente en endocarditis?',
        options: [
          'Insuficiencia cardíaca refractaria, infección no controlada (absceso/fístula), embolias recurrentes a pesar de antibióticos, vegetación > 10 mm con embolia',
          'Siempre que se diagnostique endocarditis',
          'Solo cuando hay fiebre persistente > 7 días',
          'Cuando el paciente tiene soplo cardíaco nuevo',
        ],
        correctIndex: 0,
        explanation:
            'Indicaciones de cirugía urgente: IC refractaria, infección no controlada (absceso perianular, fístula, bloqueo AV), embolias recurrentes a pesar de antibióticos, vegetación grande (> 10 mm) con episodio embólico, endocarditis fúngica (ESC 2023, AHA 2020).',
      ),
    ],
  ),
  // Metabólico: Acidosis Láctica
  _EvalScenario(
    id: 'eval_metabolico_acidosis_lactica',
    title: 'Acidosis Láctica',
    subtitle: 'Lactato elevado en el paciente crítico · AHA 2020',
    caseText:
        'Hombre de 60 años en shock séptico presenta lactato de 8.5 mmol/L, pH 7.12, HCO3 10 mEq/L, PCO2 25 mmHg. PA 70/40 con noradrenalina a 20 mcg/min.',
    color: AppColors.brand,
    icon: Icons.science_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question: '¿Qué tipo de acidosis láctica tiene este paciente?',
        options: [
          'Tipo A: hipoperfusión tisular/hipoxia (shock séptico)',
          'Tipo B: metabolismo aumentado sin hipoxia',
          'Tipo C: por disfunción hepática',
          'No es acidosis láctica, es cetoacidosis',
        ],
        correctIndex: 0,
        explanation:
            'Acidosis láctica TIPO A: por hipoperfusión tisular global. El lactato es marcador de hipoxia tisular y gravedad. Tipo B (sin hipoxia aparente): convulsiones, metformina, leucemia, VIH, intoxicación por etanol/metanol. Tipo C: disfunción hepática congénita rara. En sepsis, el lactato refleja hipoperfusión + hipermetabolismo (Surviving Sepsis 2021).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la meta de aclaramiento de lactato en las primeras 6 horas?',
        options: [
          'Reducción ≥ 20% del lactato inicial o lactato < 2 mmol/L en 6 horas',
          'Lactato normal en 2 horas',
          'Reducción del 50% en 24 horas',
          'El lactato no se usa como guía terapéutica',
        ],
        correctIndex: 0,
        explanation:
            'El aclaramiento de lactato ≥ 20% en 6 horas se asocia con menor mortalidad. Es un marcador de respuesta a la reanimación. Si no se aclara, intensificar la reanimación y buscar focos ocultos de hipoperfusión/isquemia (Surviving Sepsis Campaign 2021).',
      ),
      _EvalQuestion(
        question: '¿Cuándo se debe considerar bicarbonato en acidosis láctica?',
        options: [
          'No recomendado de rutina; solo considerar si pH < 7.15 y falla renal/shock refractario',
          'Siempre que el pH < 7.35',
          'Nunca usar bicarbonato en acidosis láctica',
          'Administrar bicarbonato para pH < 7.30 en todos los pacientes',
        ],
        correctIndex: 0,
        explanation:
            'Bicarbonato NO recomendado de rutina en acidosis láctica (no mejora mortalidad y puede empeorar acidosis intracelular). Considerar si pH < 7.15 con falla renal o shock refractario a vasopresores. La prioridad es tratar la causa (hipoperfusión) (AHA 2020, Surviving Sepsis 2021).',
      ),
      _EvalQuestion(
        question:
            '¿Qué marcador adicional ayuda a diferenciar tipo A de tipo B?',
        options: [
          'Relación lactato/piruvato (> 25:1 en tipo A, < 15:1 en tipo B)',
          'pH arterial',
          'Bicarbonato sérico',
          'Potasio sérico',
        ],
        correctIndex: 0,
        explanation:
            'La relación lactato/piruvato diferencia tipo A (> 25:1, indica hipoxia citopática) de tipo B (< 15:1). Sin embargo, en la práctica clínica, la medición de piruvato no está disponible rutinariamente; el diagnóstico se basa en el contexto clínico y la respuesta al tratamiento (AHA 2020, Critical Care Medicine 2019).',
      ),
    ],
  ),
  // Metabólico: Tormenta Tiroidea
  _EvalScenario(
    id: 'eval_metabolico_tormenta_tiroidea',
    title: 'Tormenta Tiroidea',
    subtitle: 'Crisis tirotóxica descompensada · ATA 2023',
    caseText:
        'Mujer de 32 años con hipertiroidismo no tratado (abandonó metimazol) presenta fiebre 40°C, FC 170 lpm, PA 100/50, agitación psicomotriz, vómito y diarrea. Exoftalmos y bocio difuso palpable.',
    color: AppColors.brand,
    icon: Icons.monitor_heart_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es el tratamiento de primera línea para controlar la taquicardia en tormenta tiroidea?',
        options: [
          'Betabloqueante IV (propranolol 1-2 mg IV cada 5 min o esmolol infusión)',
          'Adenosina IV',
          'Amiodarona IV',
          'Cardioversión eléctrica sincronizada',
        ],
        correctIndex: 0,
        explanation:
            'Betabloqueantes: propranolol (bloquea conversión periférica T4→T3 además de control de frecuencia) o esmolol (ultracorto, más seguro en inestabilidad hemodinámica). Propranolol 60-80 mg VO cada 4h o 1-2 mg IV cada 5 min. Esmolol: bolo 500 μg/kg + infusión 50-200 μg/kg/min (ATA 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué medicamento debe administrarse PRIMERO en la tormenta tiroidea?',
        options: [
          'Betabloqueante primero (control adrenérgico) + tioamida 1 hora después',
          'Tioamida primero (metimazol/PTU) + betabloqueante después',
          'Yodo saturado primero',
          'Glucocorticoides primero',
        ],
        correctIndex: 0,
        explanation:
            'ADMINISTRAR BETABLOQUEANTE PRIMERO para controlar los efectos adrenérgicos graves (taquiarritmias, hipertensión, hipertermia). La tioamida (metimazol 20-30 mg VO/SNG cada 6h o PTU 200-400 mg VO/SNG cada 4h) se da 1 hora después. El yodo (SSKI/Lugol) se administra al menos 1 hora DESPUÉS de la tioamida para evitar que el yodo empeore la tormenta al proveer sustrato para síntesis hormonal adicional (ATA 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo están indicados los glucocorticoides en tormenta tiroidea?',
        options: [
          'En todos los pacientes: hidrocortisona 300 mg IV bolo luego 100 mg cada 8h (inhibe conversión T4→T3 + previene insuficiencia suprarrenal relativa)',
          'Solo si hay hipotensión refractaria',
          'No están indicados nunca',
          'Solo si el paciente tiene fiebre > 39°C',
        ],
        correctIndex: 0,
        explanation:
            'Glucocorticoides en TODOS los pacientes con tormenta tiroidea: inhiben la conversión periférica de T4 a T3, tienen efecto antipirético, y previenen la insuficiencia suprarrenal relativa por el hipermetabolismo extremo. Hidrocortisona 300 mg IV bolo, luego 100 mg cada 8h (ATA 2023).',
      ),
      _EvalQuestion(
        question: '¿Qué puntaje confirma tormenta tiroidea?',
        options: [
          'Puntaje de Burch-Wartofsky ≥ 45: tormenta tiroidea probable',
          'TSH < 0.01 mU/L',
          'T4 libre > 5 ng/dL',
          'T3 total > 500 ng/dL',
        ],
        correctIndex: 0,
        explanation:
            'Puntaje de Burch-Wartofsky: evalúa termorregulación (temperatura), SNC (agitación/delirio/coma), GI (náusea/diarrea/ictericia), cardiovascular (FC/FA/ICC) y factor precipitante. ≥ 45: tormenta tiroidea. 25-44: tormenta inminente. Laboratorios confirman pero el diagnóstico es clínico (ATA 2023).',
      ),
    ],
  ),
  // Metabólico: Insuficiencia Suprarrenal Aguda
  _EvalScenario(
    id: 'eval_metabolico_insuficiencia_suprarrenal',
    title: 'Insuficiencia Suprarrenal Aguda',
    subtitle: 'Crisis suprarrenal · Endocrine Society 2016',
    caseText:
        'Mujer de 55 años con artritis reumatoide en tratamiento con prednisona 20 mg/día, suspendió abruptamente hace 3 días. Presenta hipotensión PA 70/40 refractaria a volumen, hiperpigmentación, hiponatremia (Na 128), hiperkalemia (K 5.8).',
    color: AppColors.brand,
    icon: Icons.medication_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question: '¿Cuál es el tratamiento inmediato de la crisis suprarrenal?',
        options: [
          'Hidrocortisona 100 mg IV bolo + solución salina 0.9% 1L en 30-60 min',
          'Fludrocortisona VO + agua libre IV',
          'Solo solución salina 0.9% sin corticoides',
          'Dexametasona 10 mg IM + dextrosa al 5%',
        ],
        correctIndex: 0,
        explanation:
            'Hidrocortisona 100 mg IV bolo (luego 200 mg/día en infusión continua o 50-100 mg cada 6h) + reanimación con cristaloides (1-2L de solución salina 0.9% en la primera hora). Hidrocortisona tiene efecto glucocorticoide + mineralocorticoide. La hipotensión por crisis suprarrenal es refractaria a volumen sin corticoides (Endocrine Society 2016, JCEM 2020).',
      ),
      _EvalQuestion(
        question: '¿Qué prueba diagnóstica confirma insuficiencia suprarrenal?',
        options: [
          'Prueba de estimulación con cosintropina (ACTH sintético 250 μg): cortisol < 18 μg/dL a los 30-60 min',
          'Cortisol sérico basal aleatorio',
          'Niveles de ACTH plasmática',
          'Prueba de tolerancia a la insulina',
        ],
        correctIndex: 0,
        explanation:
            'La prueba de estimulación con ACTH (cosintropina 250 μg IV o IM) es el gold standard. Cortisol sérico < 18 μg/dL (500 nmol/L) a los 30 o 60 minutos post-estimulación confirma insuficiencia suprarrenal. ACTH elevada (> 100 pg/mL) confirma origen primario (Endocrine Society Clinical Practice Guideline 2016).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la causa más común de crisis suprarrenal aguda en pacientes con corticosteroides crónicos?',
        options: [
          'Supresión del eje HPA por corticoides exógenos + suspensión abrupta o estrés agudo',
          'Hemorragia suprarrenal bilateral (Waterhouse-Friderichsen)',
          'Metástasis suprarrenales bilaterales',
          'Tuberculosis suprarrenal',
        ],
        correctIndex: 0,
        explanation:
            'La causa más frecuente es la supresión del eje HPA por uso crónico de corticoides exógenos (> 3 semanas equivalentes a prednisona ≥ 5 mg/día), seguida de estrés agudo (infección, cirugía, trauma) o suspensión abrupta. Requieren cobertura con estrés-dosis de hidrocortisona (Endocrine Society 2016, JCEM 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué precaución debe tomarse al tratar la hiponatremia en la crisis suprarrenal?',
        options: [
          'La corrección ocurre espontáneamente con hidrocortisona y solución salina isotónica; evitar corrección rápida que pueda causar desmielinización osmótica',
          'Administrar solución salina hipertónica 3% de inmediato',
          'Restringir líquidos a 500 mL/día',
          'Usar vasopresina para elevar la presión arterial primero',
        ],
        correctIndex: 0,
        explanation:
            'En crisis suprarrenal, la hiponatremia es hipervolémica por déficit de aldosterona. Con hidrocortisona (efecto mineralocorticoide) + solución salina isotónica, el sodio se normaliza gradualmente. Evitar corrección muy rápida (> 8-10 mEq/L en 24 h) para prevenir síndrome de desmielinización osmótica (NEJM 2019, Endocrine Society 2016).',
      ),
    ],
  ),
  // RCP Vía Aérea Avanzada
  _EvalScenario(
    id: 'eval_rcp_via_aerea_avanzada',
    title: 'Vía Aérea Avanzada en RCP',
    subtitle: 'Manejo avanzado de la vía aérea · AHA 2020',
    caseText:
        'Paciente de 68 años en paro cardíaco extrahospitalario con tubo endotraqueal colocado. Se requiere continuar maniobras de RCP de alta calidad con ventilación sincronizada.',
    color: AppColors.red,
    icon: Icons.air,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la frecuencia de ventilación recomendada durante RCP con vía aérea avanzada?',
        options: [
          'Una ventilación cada 6 segundos (10 ventilaciones/minuto)',
          'Una ventilación cada 3 segundos (20 ventilaciones/minuto)',
          'Dos ventilaciones cada 30 compresiones',
          'Una ventilación cada 10 segundos (6 ventilaciones/minuto)',
        ],
        correctIndex: 0,
        explanation:
            'Con vía aérea avanzada (tubo endotraqueal o supraglótico), se administra UNA ventilación cada 6 segundos (10/min) SIN pausar las compresiones. La relación 30:2 ya no aplica. Esto asegura ventilación alveolar adecuada sin interrumpir las compresiones (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cómo deben realizarse las compresiones torácicas con vía aérea avanzada?',
        options: [
          'Compresiones continuas a 100-120/min sin pausas para ventilación',
          'Ciclos de 30 compresiones seguidas de 2 ventilaciones',
          'Compresiones a 80-100/min con pausas para ventilación cada 2 minutos',
          'Ciclos de 15 compresiones con 1 ventilación',
        ],
        correctIndex: 0,
        explanation:
            'Con vía aérea avanzada, las compresiones torácicas son CONTINUAS a 100-120/min. NO se pausan para ventilación. Esto maximiza la presión de perfusión coronaria y cerebral al evitar la caída de presión diastólica durante las pausas (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el dispositivo de vía aérea avanzada considerado gold standard durante la RCP?',
        options: [
          'Tubo endotraqueal',
          'Mascarilla laríngea',
          'Tubo esofágico-traqueal (Combitube)',
          'Cánula orofaríngea',
        ],
        correctIndex: 0,
        explanation:
            'El tubo endotraqueal es el gold standard porque aísla completamente la vía aérea, permite ventilación con presión positiva, protege contra broncoaspiración y permite capnografía continua. Los dispositivos supraglóticos son alternativas aceptables (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el límite de tiempo para interrumpir compresiones al intentar intubación?',
        options: [
          'Máximo 10 segundos',
          'Máximo 30 segundos',
          'Máximo 60 segundos',
          'Se pueden detener las compresiones completamente hasta colocar el tubo',
        ],
        correctIndex: 0,
        explanation:
            'La intubación no debe interrumpir las compresiones por más de 10 segundos. Si no se logra en ese tiempo, se reanudan compresiones y se intenta nuevamente después. La prioridad es minimizar el tiempo sin flujo sanguíneo (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el método más confiable para confirmar la colocación correcta del tubo endotraqueal?',
        options: [
          'Capnografía de forma de onda (EtCO2) más auscultación y elevación torácica',
          'Auscultación de ambos campos pulmonares únicamente',
          'Elevación y expansión torácica simétrica solamente',
          'Radiografía de tórax portátil',
        ],
        correctIndex: 0,
        explanation:
            'La capnografía de forma de onda es el método más confiable y permite monitoreo continuo. Detecta inmediatamente desplazamiento del tubo, obstrucción o desconexión. Debe combinarse con auscultación y observación del movimiento torácico (AHA 2020).',
      ),
    ],
  ),
  // Hands-Only RCP
  _EvalScenario(
    id: 'eval_rcp_hands_only',
    title: 'Hands-Only RCP',
    subtitle: 'RCP solo con compresiones · AHA 2020',
    caseText:
        'Una persona presencia un colapso súbito en la vía pública y no tiene entrenamiento en RCP convencional. Debe brindar asistencia mientras llegan los servicios de emergencia.',
    color: AppColors.red,
    icon: Icons.favorite,
    difficulty: 'Básico',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la profundidad de compresión recomendada en hands-only RCP para adultos?',
        options: [
          'Al menos 5 cm (2 pulgadas) sin exceder 6 cm (2.4 pulgadas)',
          'Aproximadamente 2.5 cm (1 pulgada)',
          'Al menos 7.5 cm (3 pulgadas)',
          'Entre 3 y 4 cm (1.2-1.6 pulgadas)',
        ],
        correctIndex: 0,
        explanation:
            'La profundidad recomendada es de al menos 5 cm (2 pulgadas) sin exceder 6 cm (2.4 pulgadas) para evitar lesiones. En hands-only RCP aplica el mismo estándar que en RCP convencional (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la frecuencia de compresiones en hands-only RCP?',
        options: [
          '100 a 120 compresiones por minuto',
          '80 a 100 compresiones por minuto',
          '120 a 140 compresiones por minuto',
          '60 a 80 compresiones por minuto',
        ],
        correctIndex: 0,
        explanation:
            'La frecuencia debe ser de 100 a 120 compresiones por minuto, al ritmo de la canción "Stayin\' Alive" de los Bee Gees. Esta frecuencia maximiza el gasto cardíaco y la perfusión coronaria (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿En qué situación está indicada la hands-only RCP?',
        options: [
          'Adulto con paro cardíaco extrahospitalario presenciado por reanimador no entrenado',
          'Niño menor de 8 años en paro cardíaco',
          'Ahogamiento o asfixia',
          'Paciente pediátrico con paro presenciado',
        ],
        correctIndex: 0,
        explanation:
            'Hands-only RCP está indicada para adultos con paro cardíaco extrahospitalario presenciado, especialmente cuando el reanimador no está entrenado. En ahogamiento, asfixia y paros pediátricos se requiere RCP convencional con ventilaciones (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo debe cambiar un reanimador no entrenado de hands-only a RCP convencional?',
        options: [
          'Cuando llegue un reanimador entrenado y dispuesto a realizar ventilaciones',
          'Después de 5 minutos de compresiones continuas',
          'Inmediatamente después de cada descarga del DEA',
          'Nunca, hands-only es siempre superior',
        ],
        correctIndex: 0,
        explanation:
            'El reanimador no entrenado debe continuar hands-only hasta que llegue ayuda. Si alguien entrenado se ofrece a realizar RCP convencional con ventilaciones, se puede hacer la transición. Hands-only no es superior, es una alternativa efectiva cuando no hay disposición/entrenamiento para ventilaciones (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué debe hacer primero la persona no entrenada al presenciar un colapso súbito?',
        options: [
          'Llamar al 911 y luego iniciar compresiones torácicas',
          'Iniciar compresiones torácicas y luego llamar al 911',
          'Esperar a que llegue la ambulancia',
          'Buscar un DEA antes de tocar al paciente',
        ],
        correctIndex: 0,
        explanation:
            'La secuencia es: 1) Verificar inconsciencia, 2) Llamar al 911, 3) Iniciar compresiones torácicas fuertes y rápidas. Si hay un DEA disponible, debe solicitarse mientras se continúa con compresiones. La activación temprana del SEM es prioritaria (AHA 2020).',
      ),
    ],
  ),
  // RCP + DEA
  _EvalScenario(
    id: 'eval_rcp_dea',
    title: 'RCP y DEA',
    subtitle: 'Integración del desfibrilador externo automático · AHA 2020',
    caseText:
        'Paciente de 55 años en paro cardíaco presenciado en un centro comercial. Un DEA está disponible en el lugar. Se debe integrar correctamente el uso del desfibrilador con las compresiones torácicas.',
    color: AppColors.amber,
    icon: Icons.bolt,
    difficulty: 'Básico',
    questions: [
      _EvalQuestion(
        question: '¿Cada cuánto tiempo debe el DEA analizar el ritmo cardíaco?',
        options: [
          'Cada 2 minutos de RCP',
          'Cada 30 segundos de RCP',
          'Cada 5 minutos de RCP',
          'Solo al inicio, no se repite el análisis',
        ],
        correctIndex: 0,
        explanation:
            'El DEA analiza el ritmo cada 2 minutos. Durante ese tiempo se realizan 5 ciclos de 30:2 (aproximadamente 2 minutos) antes de la siguiente pausa para análisis. Esto minimiza las interrupciones y maximiza la probabilidad de éxito (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué debe hacerse inmediatamente antes de que el DEA administre una descarga?',
        options: [
          'Asegurarse de que NADIE esté en contacto con el paciente (zona despejada)',
          'Continuar compresiones durante la descarga',
          'Verificar pulso carotídeo antes de la descarga',
          'Administrar ventilaciones durante la descarga',
        ],
        correctIndex: 0,
        explanation:
            'Antes de la descarga, el reanimador debe decir "¡Todos fuera!" y verificar visualmente que nadie toque al paciente. El contacto durante la descarga puede causar lesiones al reanimador y reducir la energía transmitida al corazón (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué acción debe realizarse INMEDIATAMENTE después de que el DEA administra una descarga?',
        options: [
          'Reanudar RCP comenzando con compresiones torácicas',
          'Verificar pulso carotídeo',
          'Esperar a que el DEA reanalice el ritmo',
          'Administrar dos ventilaciones de rescate',
        ],
        correctIndex: 0,
        explanation:
            'Inmediatamente después de la descarga, se reanuda RCP comenzando con compresiones torácicas. NO se verifica pulso ni ritmo. El DEA reanalizará después de 2 minutos de RCP. Esto minimiza el tiempo sin compresiones (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Dónde deben colocarse los parches del DEA en un adulto?',
        options: [
          'Posición anterolateral: parche derecho en infraclavicular derecha y parche izquierdo en línea axilar media izquierda',
          'Ambos parches en el tórax anterior',
          'Ambos parches en la espalda',
          'Un parche en el brazo derecho y otro en la pierna izquierda',
        ],
        correctIndex: 0,
        explanation:
            'La posición anterolateral es la estándar: un parche en el lado derecho del tórax (debajo de la clavícula) y el otro en el lado izquierdo (línea axilar media, a nivel del corazón). Alternativas: anteroposterior si los parches se tocan o hay dispositivos implantados (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuánto tiempo debe transcurrir entre la última compresión y la descarga del DEA?',
        options: [
          'El menor tiempo posible, idealmente < 5 segundos',
          'Al menos 15 segundos para permitir el análisis',
          '30 segundos para asegurar ritmo adecuado',
          'No importa, la pausa no afecta el resultado',
        ],
        correctIndex: 0,
        explanation:
            'La pausa pre-descarga debe ser la MÍNIMA posible (< 5-10 segundos). La pausa incluye el análisis del DEA (que es automático) más la descarga. Las pausas prolongadas reducen la presión de perfusión coronaria y la probabilidad de éxito (AHA 2020).',
      ),
    ],
  ),
  // DEA Marcapasos
  _EvalScenario(
    id: 'eval_dea_marcapasos',
    title: 'DEA y Marcapasos',
    subtitle: 'Desfibrilación con marcapasos implantado · AHA 2020',
    caseText:
        'Paciente de 72 años con marcapasos cardíaco en región pectoral izquierda sufre un paro cardíaco. Se debe utilizar el DEA de forma segura y efectiva sin interferir con el dispositivo implantado.',
    color: AppColors.amber,
    icon: Icons.dynamic_feed,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿A qué distancia del generador del marcapasos deben colocarse los parches del DEA?',
        options: [
          'Al menos 2.5 cm (1 pulgada) de distancia del generador',
          'Directamente sobre el generador del marcapasos',
          'Al menos 10 cm (4 pulgadas) de distancia',
          'No importa la distancia, se colocan en cualquier posición',
        ],
        correctIndex: 0,
        explanation:
            'Los parches del DEA deben colocarse a AL MENOS 2.5 cm (1 pulgada) del generador del marcapasos. Colocar el parche directamente sobre el dispositivo puede interferir con la desfibrilación, dañar el marcapasos y causar falla en la captura (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué es importante NO colocar el parche del DEA sobre el generador del marcapasos?',
        options: [
          'Puede interferir con la desfibrilación y dañar el dispositivo',
          'El marcapasos explotará con la descarga',
          'La descarga no será dolorosa para el paciente',
          'El parche no se adhiere correctamente sobre el metal',
        ],
        correctIndex: 0,
        explanation:
            'El generador del marcapasos puede bloquear la corriente de desfibrilación (derivándola), reducir la energía que llega al corazón, dañar el circuito del marcapasos, y causar falla en la captura post-RCP. La distancia mínima de seguridad es 2.5 cm (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es una posición alternativa de los parches cuando hay un marcapasos en la posición anterolateral estándar?',
        options: [
          'Posición anteroposterior (un parche en tórax anterior y otro en espalda)',
          'Ambos parches en el abdomen',
          'Ambos parches en la espalda baja',
          'Un parche en cada hombro',
        ],
        correctIndex: 0,
        explanation:
            'La posición anteroposterior o anterolateral modificada (alejando el parche del generador) son alternativas aceptables. La posición ántero-posterior coloca un parche en el tórax anterior izquierdo y el otro en la espalda izquierda (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Es seguro usar un DEA en un paciente con marcapasos?',
        options: [
          'Sí, es seguro siempre que los parches no estén sobre el generador',
          'No, está contraindicado el DEA en pacientes con marcapasos',
          'Solo si el marcapasos se desactiva primero con un imán',
          'Solo en el hospital, nunca en el campo',
        ],
        correctIndex: 0,
        explanation:
            'El DEA es seguro y efectivo en pacientes con marcapasos. La única precaución es colocar los parches a más de 2.5 cm del generador. No se requiere desactivar el marcapasos ni usar imán. La desfibrilación oportuna salva vidas (AHA 2020).',
      ),
    ],
  ),
  // DEA Parches Medicamentosos
  _EvalScenario(
    id: 'eval_dea_parches',
    title: 'DEA y Parches Medicamentosos',
    subtitle: 'Parches transdérmicos y desfibrilación · AHA 2020',
    caseText:
        'Paciente de 60 años en paro cardíaco lleva un parche transdérmico de nitroglicerina en el tórax. Se requiere colocar correctamente los electrodos del DEA.',
    color: AppColors.amber,
    icon: Icons.healing,
    difficulty: 'Básico',
    questions: [
      _EvalQuestion(
        question:
            '¿Qué debe hacerse con el parche transdérmico antes de colocar los electrodos del DEA?',
        options: [
          'Retirar el parche con guantes y limpiar la zona',
          'Dejar el parche y colocar el electrodo directamente encima',
          'Cortar el parche por la mitad',
          'Cubrir el parche con gasa antes de colocar el electrodo',
        ],
        correctIndex: 0,
        explanation:
            'El parche transdérmico debe RETIRARSE con guantes y la piel debe limpiarse y secarse antes de colocar el electrodo. No colocar el electrodo sobre el parche porque puede bloquear la descarga y causar quemaduras (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué deben retirarse los parches transdérmicos antes de la desfibrilación?',
        options: [
          'Pueden causar quemaduras en la piel y reducir la efectividad de la descarga',
          'Mejoran la conducción eléctrica del parche del DEA',
          'Evitan que el paciente sienta dolor durante la descarga',
          'Aumentan la absorción del medicamento',
        ],
        correctIndex: 0,
        explanation:
            'Los parches transdérmicos contienen un reservorio de medicamento (nitratos, opioides, nicotina) que puede actuar como aislante eléctrico y, al calentarse con la descarga, causar quemaduras dérmicas. Además, el adhesivo del parche interfiere con la adhesión del electrodo (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué deben usarse guantes al retirar el parche transdérmico?',
        options: [
          'Evitar que el medicamento entre en contacto con la piel del reanimador',
          'Proteger al reanimador de una descarga eléctrica',
          'Evitar infección cruzada',
          'Evitar manchar los dedos con el adhesivo',
        ],
        correctIndex: 0,
        explanation:
            'Los guantes evitan que el medicamento del parche entre en contacto con la piel del reanimador. Por ejemplo, la nitroglicerina puede causar cefalea intensa e hipotensión si se absorbe a través de la piel del reanimador. Siga las precauciones estándar (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Qué debe hacerse después de retirar el parche?',
        options: [
          'Limpiar y secar completamente la piel antes de colocar el electrodo',
          'Aplicar alcohol para desinfectar la zona',
          'Colocar el electrodo inmediatamente sobre la piel húmeda',
          'Aplicar ungüento antibiótico antes del electrodo',
        ],
        correctIndex: 0,
        explanation:
            'Después de retirar el parche, la piel debe limpiarse para eliminar residuos del medicamento y adhesivo, y SECARSE completamente para asegurar una buena adhesión del electrodo del DEA. La piel húmeda interfiere con la conducción eléctrica (AHA 2020).',
      ),
    ],
  ),
  // DEA Vello Torácico
  _EvalScenario(
    id: 'eval_dea_vello',
    title: 'DEA y Vello Torácico',
    subtitle: 'Mala adherencia por vello excesivo · AHA 2020',
    caseText:
        'Paciente varón de 65 años en paro cardíaco con vello torácico abundante. Al colocar los parches del DEA, la máquina indica "Revisar electrodos" por mala adherencia.',
    color: AppColors.amber,
    icon: Icons.people_outline,
    difficulty: 'Básico',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la mejor acción cuando el vello torácico impide la adherencia de los parches del DEA?',
        options: [
          'Rasurar el vello en las áreas donde se colocarán los parches',
          'Presionar con mucha fuerza los parches sin rasurar',
          'Colocar los parches en el abdomen donde no hay vello',
          'No usar el DEA y solo realizar compresiones',
        ],
        correctIndex: 0,
        explanation:
            'Se debe rasurar el vello torácico donde se colocarán los parches. La mayoría de los kits de DEA incluyen una rasuradora desechable. Si no hay, se pueden usar los mismos parches para depilar: presionar firmemente, arrancar y luego colocar los nuevos (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué alternativa existe si no hay rasuradora disponible en el kit del DEA?',
        options: [
          'Usar el primer juego de parches para depilar el vello (presionar y arrancar) y colocar el segundo juego',
          'Aplicar gel conductor sobre el vello sin rasurar',
          'Cubrir el vello con cinta adhesiva',
          'Usar los parches en los antebrazos del paciente',
        ],
        correctIndex: 0,
        explanation:
            'Si no hay rasuradora, una alternativa es usar el primer juego de parches como "depilador": presionar firmemente sobre el vello y arrancar rápidamente. Esto elimina suficiente vello para que los parches nuevos del segundo juego se adhieran correctamente (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué es crítico eliminar el vello torácico excesivo antes de la desfibrilación?',
        options: [
          'El vello atrapa aire entre el parche y la piel, impidiendo la conducción eléctrica y causando arco eléctrico',
          'El vello conduce electricidad directamente al corazón',
          'El vello causa dolor excesivo al paciente durante la descarga',
          'El vello mancha los electrodos del DEA permanentemente',
        ],
        correctIndex: 0,
        explanation:
            'El vello impide el contacto directo parche-piel necesario para la conducción eléctrica. Pueden quedar bolsas de aire que causan arco eléctrico (chispas) durante la descarga, reduciendo la energía transmitida al corazón y potencialmente quemando la piel (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Qué área debe rasurarse para colocar los parches del DEA?',
        options: [
          'Solo el área donde se colocarán los parches (no todo el tórax)',
          'Todo el tórax completamente',
          'Solo la espalda del paciente',
          'No se debe rasurar nada, solo aplicar gel conductor',
        ],
        correctIndex: 0,
        explanation:
            'Solo debe rasurarse el área específica donde se colocarán los parches. Rasurar todo el tórax retrasa innecesariamente la desfibrilación. El tiempo es crítico: cada minuto sin desfibrilación reduce la supervivencia 7-10% (AHA 2020).',
      ),
    ],
  ),
  // Ahogamiento Agua Salada vs Dulce
  _EvalScenario(
    id: 'eval_ahogamiento_agua_salada',
    title: 'Ahogamiento: Agua Salada vs Dulce',
    subtitle: 'Fisiopatología comparada del ahogamiento · AHA 2020',
    caseText:
        'Dos pacientes ingresan a urgencias por ahogamiento: uno en alberca (agua dulce) y otro en el mar (agua salada). Se deben conocer las diferencias fisiopatológicas y el manejo específico de cada tipo.',
    color: AppColors.cyan,
    icon: Icons.water,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Qué efecto fisiopatológico ocurre en el ahogamiento por agua DULCE?',
        options: [
          'El agua hipotónica elimina el surfactante, causando colapso alveolar',
          'El agua hiperosmolar atrae líquido al intersticio pulmonar',
          'Provoca hipernatremia severa por absorción de sodio',
          'Causa broncoespasmo irreversible',
        ],
        correctIndex: 0,
        explanation:
            'El agua dulce es hipotónica. Al llegar a los alvéolos, diluye y elimina el surfactante pulmonar, causando inestabilidad alveolar y colapso (atelectasias). También pasa al torrente sanguíneo (dilución), pudiendo causar hiponatremia e hipervolemia transitoria (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué efecto fisiopatológico ocurre en el ahogamiento por agua SALADA?',
        options: [
          'El agua hipertónica (3.5% sal) crea gradiente osmótico que atrae líquido al alvéolo, causando edema pulmonar',
          'El agua salada protege el surfactante pulmonar',
          'La sal provoca vasoconstricción pulmonar protectora',
          'Causa hiponatremia por dilución de electrolitos',
        ],
        correctIndex: 0,
        explanation:
            'El agua salada (3.5% NaCl) es hipertónica comparada con el plasma. El gradiente osmótico atrae agua del capilar hacia el alvéolo, causando edema pulmonar agudo e hipoxemia severa. También puede causar hipernatremia e hipercloremia (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la vía final común en ambos tipos de ahogamiento?',
        options: [
          'Hipoxemia severa por alteración de la membrana alvéolo-capilar',
          'Hipercapnia por hipoventilación',
          'Acidosis metabólica primaria',
          'Hipotermia como mecanismo principal de lesión',
        ],
        correctIndex: 0,
        explanation:
            'Independientemente del tipo de agua, la vía final común del ahogamiento es la HIPOXEMIA severa por alteración de la membrana alvéolo-capilar y deterioro del intercambio gaseoso. La hipoxemia lleva a paro cardíaco si no se corrige rápidamente (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Hay diferencias en el tratamiento entre ahogamiento por agua dulce y salada?',
        options: [
          'No, el manejo es el mismo: oxigenación/ventilación y soporte vital',
          'Sí, agua dulce requiere diuréticos y agua salada requiere expansión con cristaloides',
          'Sí, agua dulce necesita corticoides y agua salada antibióticos',
          'Sí, el agua salada necesita lavado bronquial con solución salina',
        ],
        correctIndex: 0,
        explanation:
            'El tratamiento es el MISMO para ambos tipos: asegurar vía aérea, oxigenación suplementaria, ventilación mecánica si es necesario y soporte circulatorio. NO hay indicación de corticoides, antibióticos profilácticos, ni tratamientos específicos según el tipo de agua (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la prioridad inmediata en el manejo del paciente ahogado?',
        options: [
          'Oxigenación y ventilación para corregir la hipoxemia',
          'Desfibrilación inmediata',
          'Administración de bicarbonato de sodio',
          'Calentamiento activo del paciente',
        ],
        correctIndex: 0,
        explanation:
            'La prioridad absoluta es corregir la hipoxemia mediante oxigenación y ventilación. Iniciar con oxígeno al 100% y ventilación con bolsa-mascarilla o intubación si es necesario. La hipoxemia es la causa principal del daño orgánico y paro cardíaco en ahogamiento (AHA 2020).',
      ),
    ],
  ),
  // Ahogamiento con Lesión Cervical
  _EvalScenario(
    id: 'eval_ahogamiento_lesion_cervical',
    title: 'Ahogamiento con Lesión Cervical',
    subtitle: 'Protección espinal en rescate acuático · AHA 2020',
    caseText:
        'Joven de 22 años sufre accidente al lanzarse de cabeza en un lago poco profundo. Se encuentra flotando boca abajo e inconsciente. Se sospecha lesión cervical.',
    color: AppColors.cyan,
    icon: Icons.airline_seat_flat,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Qué técnica de apertura de vía aérea debe utilizarse en este paciente?',
        options: [
          'Tracción mandibular (jaw thrust) sin extensión del cuello',
          'Hiperextensión del cuello para alinear vía aérea',
          'Elevación del mentón con inclinación de cabeza',
          'Traqueotomía de emergencia',
        ],
        correctIndex: 0,
        explanation:
            'La tracción mandibular (jaw thrust) SIN extensión del cuello es la maniobra de elección cuando se sospecha lesión cervical. NO se debe usar la inclinación de cabeza-elevación de mentón ni hiperextensión, ya que pueden desplazar una fractura cervical inestable (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la forma correcta de inmovilización cervical en estos pacientes?',
        options: [
          'Estabilización manual en línea recta por un ayudante',
          'Colocar collarín cervical rígido de inmediato',
          'Inmovilizar solo con férula espinal larga',
          'No inmovilizar, el agua amortigua el impacto',
        ],
        correctIndex: 0,
        explanation:
            'La estabilización MANUAL en línea recta (manteniendo cabeza-cuello-tronco alineados) es el método inicial de elección. Un ayudante mantiene la cabeza inmóvil manualmente. Los collarines rígidos pueden dificultar el manejo de la vía aérea (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué dispositivo NO se recomienda en el manejo de vía aérea en ahogamiento con lesión cervical?',
        options: [
          'Collarín cervical rígido (puede impedir la apertura de vía aérea)',
          'Cánula orofaríngea',
          'Mascarilla laríngea',
          'Tubo endotraqueal',
        ],
        correctIndex: 0,
        explanation:
            'El collarín cervical rígido está CONTRAINDICADO porque impide la apertura adecuada de la vía aérea y retrasa la ventilación. Se recomienda estabilización manual. La prioridad es la ventilación sobre cualquier intento de inmovilización (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la prioridad en el manejo de este paciente?',
        options: [
          'Proporcionar respiración de rescate con estabilización manual simultánea',
          'Inmovilizar completamente antes de cualquier intervención',
          'Sacar al paciente del agua sin mover el cuello',
          'Esperar al personal de rescate especializado',
        ],
        correctIndex: 0,
        explanation:
            'La prioridad es la VENTILACIÓN/RESPIRACIÓN DE RESCATE. La inmovilización cervical no debe retrasar la apertura de la vía aérea ni la ventilación. Se debe mantener estabilización manual mientras se proporciona ventilación con bolsa-mascarilla o boca a boca (AHA 2020).',
      ),
    ],
  ),
  // Ahogamiento en Vehículo
  _EvalScenario(
    id: 'eval_ahogamiento_vehiculo',
    title: 'Ahogamiento en Vehículo Sumergido',
    subtitle: 'Rescate en vehículo sumergido en agua · AHA 2020',
    caseText:
        'Automóvil se precipita a un canal de agua profunda. Los ocupantes están atrapados mientras el vehículo comienza a hundirse. Se requiere rescate inmediato.',
    color: AppColors.cyan,
    icon: Icons.directions_car,
    difficulty: 'Básico',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la primera acción recomendada para los ocupantes de un vehículo que se hunde?',
        options: [
          'Bajar los vidrios y salir del vehículo inmediatamente',
          'Permanecer dentro del vehículo y llamar al 911',
          'Esperar a que el vehículo toque el fondo y se iguale la presión',
          'Subir los vidrios para evitar que entre agua',
        ],
        correctIndex: 0,
        explanation:
            'La prioridad es BAJAR LOS VIDRIOS y SALIR INMEDIATAMENTE. Los vehículos modernos tienen sistemas eléctricos que fallan al mojarse; los vidrios pueden no funcionar después de sumergirse. Una vez que el agua cubre las ventanas, la presión impide abrir las puertas (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuándo deben iniciarse las maniobras de reanimación?',
        options: [
          'Inmediatamente después de extraer al paciente del agua, evaluar respiración',
          'Solo hasta que el paciente esté en el hospital',
          'Después de secar completamente al paciente',
          'Únicamente si el paciente está en paro cardíaco confirmado',
        ],
        correctIndex: 0,
        explanation:
            'La reanimación debe iniciarse TAN PRONTO como el paciente sea extraído del agua y se evalúe que no respira. No esperar al hospital. Iniciar con 2 respiraciones de rescate seguidas de compresiones. La hipoxia es la causa del paro en ahogamiento (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Debe realizarse inmovilización cervical en estos pacientes?',
        options: [
          'Solo si el mecanismo del accidente sugiere lesión espinal (ej. volcadura, impacto a alta velocidad)',
          'Siempre, en todos los accidentes vehiculares',
          'Nunca, en ahogamiento no se inmoviliza',
          'Solo si hay signos neurológicos evidentes',
        ],
        correctIndex: 0,
        explanation:
            'La inmovilización cervical se realiza según el mecanismo de lesión. En vehículos sumergidos, considerar si hubo volcadura, impacto violento o salida del vehículo traumática. No retrasar la ventilación por inmovilización excesiva (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué técnica de respiración de rescate se recomienda al extraer al paciente?',
        options: [
          'Ventilación boca a boca o con bolsa-mascarilla con oxígeno suplementario',
          'Compresiones torácicas únicamente',
          'Ventilación con dispositivo mecánico únicamente',
          'Solo administrar oxígeno por mascarilla no reinhalante',
        ],
        correctIndex: 0,
        explanation:
            'Se recomienda ventilación boca a boca (si no hay equipo) o con bolsa-mascarilla con oxígeno suplementario al 100%. En ahogamiento, las ventilaciones son prioritarias porque el paro es por asfixia/hipoxia, no por fibrilación ventricular primaria (AHA 2020).',
      ),
    ],
  ),
  // OVACE Niño > 1 año
  _EvalScenario(
    id: 'eval_ovace_nino',
    title: 'OVACE en Niño > 1 Año',
    subtitle: 'Obstrucción de vía aérea por cuerpo extraño · AHA 2020',
    caseText:
        'Niño de 7 años comienza a sofocarse mientras come uvas en la escuela. No puede toser ni emitir sonidos y se lleva las manos al cuello.',
    color: AppColors.blue,
    icon: Icons.child_care,
    difficulty: 'Básico',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la primera acción ante un niño con obstrucción completa de la vía aérea?',
        options: [
          'Preguntar "¿Te estás ahogando?" y animarlo a toser',
          'Realizar compresiones torácicas inmediatamente',
          'Dar golpes en la espalda repetidamente',
          'Introducir el dedo en la boca para extraer el objeto',
        ],
        correctIndex: 0,
        explanation:
            'La primera acción es PREGUNTAR: "¿Te estás ahogando?" y animarlo a toser. Si el niño puede toser, la obstrucción es parcial y la tos es más efectiva que cualquier maniobra. Si NO puede toser ni hablar, es obstrucción COMPLETA y se deben iniciar maniobras de desobstrucción (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la maniobra de elección para obstrucción severa en niño > 1 año?',
        options: [
          'Compresiones abdominales (maniobra de Heimlich)',
          'Golpes en la espalda con el niño inclinado hacia adelante',
          'Compresiones torácicas igual que en RCP',
          'Laringoscopia directa con extracción del objeto',
        ],
        correctIndex: 0,
        explanation:
            'La maniobra de Heimlich (compresiones abdominales) es la de elección en niños > 1 año. Se realizan compresiones rápidas hacia arriba y hacia adentro por encima del ombligo. En niños < 1 año se usan golpes en la espalda y compresiones torácicas (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Qué hacer si el niño con OVACE pierde el conocimiento?',
        options: [
          'Iniciar RCP comenzando con compresiones, revisar la boca antes de las ventilaciones',
          'Continuar con maniobra de Heimlich indefinidamente',
          'Esperar a que llegue la ambulancia antes de iniciar RCP',
          'Colocar al niño en posición de recuperación',
        ],
        correctIndex: 0,
        explanation:
            'Si el niño pierde el conocimiento, se inicia RCP (30:2). Antes de cada ventilación, se REVISA LA BOCA para ver si el objeto es visible y extraíble. NO hacer barrido digital a ciegas porque puede empujar el objeto más profundamente (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Qué maniobra está CONTRAINDICADA en el manejo de OVACE?',
        options: [
          'Barrido digital a ciegas (blind finger sweep)',
          'Compresiones abdominales',
          'Revisión visual de la cavidad oral',
          'Compresiones torácicas en niño inconsciente',
        ],
        correctIndex: 0,
        explanation:
            'El barrido digital a CIEGAS está contraindicado porque puede empujar el objeto más distalmente en la vía aérea, empeorar la obstrucción o causar lesiones de la mucosa. Solo se extrae un objeto si es VISIBLE durante la revisión de la boca (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el signo universal de obstrucción de la vía aérea por cuerpo extraño?',
        options: [
          'Llevarse las manos al cuello (signo de asfixia)',
          'Frotarse el pecho repetidamente',
          'Señalar la boca abierta',
          'Agitar los brazos descontroladamente',
        ],
        correctIndex: 0,
        explanation:
            'El signo universal de asfixia es llevarse las manos al cuello. Reconocer esta señal permite una intervención temprana. Preguntar "¿Te estás ahogando?" confirma el diagnóstico si la persona puede asentir pero no hablar (AHA 2020).',
      ),
    ],
  ),
  // OVACE Obesidad
  _EvalScenario(
    id: 'eval_ovace_obesidad',
    title: 'OVACE en Paciente con Obesidad',
    subtitle: 'Maniobras modificadas en paciente con obesidad · AHA 2020',
    caseText:
        'Paciente con obesidad mórbida (IMC > 40) presenta obstrucción severa de la vía aérea por un trozo de carne. El reanimador no puede rodear el abdomen con los brazos.',
    color: AppColors.blue,
    icon: Icons.fitness_center,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Qué modificación se requiere en la maniobra de desobstrucción para un paciente con obesidad?',
        options: [
          'Realizar compresiones torácicas en lugar de abdominales',
          'Aumentar la fuerza de las compresiones abdominales estándar',
          'Usar dos reanimadores para la maniobra de Heimlich',
          'Realizar únicamente golpes en la espalda',
        ],
        correctIndex: 0,
        explanation:
            'En pacientes con obesidad severa donde no se pueden rodear los brazos alrededor del abdomen, se deben realizar compresiones TORÁCICAS (igual que en pacientes embarazadas). La mano se coloca en el esternón (mitad inferior) similar a la posición de RCP (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué las compresiones abdominales son difíciles o inefectivas en obesidad mórbida?',
        options: [
          'El exceso de tejido adiposo impide la compresión efectiva del abdomen y no se genera suficiente presión intraabdominal',
          'El diafragma está más elevado en obesidad',
          'El estómago está desplazado en pacientes con obesidad',
          'La maniobra de Heimlich no funciona en adultos',
        ],
        correctIndex: 0,
        explanation:
            'En obesidad mórbida, el tejido adiposo abdominal impide que las compresiones generen suficiente presión intraabdominal para expulsar el cuerpo extraño. Además, los brazos del reanimador no pueden rodear el abdomen adecuadamente para la técnica correcta (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Dónde debe colocarse el puño para las compresiones torácicas en un paciente con obesidad con OVACE?',
        options: [
          'En la mitad inferior del esternón (misma posición que RCP)',
          'En el epigastrio, por encima del ombligo',
          'En el reborde costal derecho',
          'En la región lumbar posterior',
        ],
        correctIndex: 0,
        explanation:
            'Las compresiones torácicas se realizan en la MITAD INFERIOR DEL ESTERNÓN, la misma posición anatómica que las compresiones de RCP. Se utiliza un puño o la base de la mano para realizar compresiones rápidas y firmes hacia adentro (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué hacer si el paciente con obesidad pierde el conocimiento por OVACE?',
        options: [
          'Iniciar RCP estándar (30:2), revisar boca antes de ventilaciones',
          'Continuar compresiones torácicas en posición vertical',
          'Colocar en posición de recuperación y esperar',
          'Realizar traqueostomía de emergencia',
        ],
        correctIndex: 0,
        explanation:
            'Si el paciente pierde el conocimiento, se inicia RCP estándar (30 compresiones: 2 ventilaciones). Antes de cada ventilación se revisa la cavidad oral para extraer el objeto si es visible. No hay modificaciones especiales en la RCP por obesidad (AHA 2020).',
      ),
    ],
  ),
  // OVACE Embarazada
  _EvalScenario(
    id: 'eval_ovace_embarazada',
    title: 'OVACE en Paciente Embarazada',
    subtitle: 'Obstrucción de vía aérea en gestación avanzada · AHA 2020',
    caseText:
        'Mujer de 32 semanas de gestación comienza a sofocarse mientras come en un restaurante. Presenta signos de obstrucción completa de la vía aérea por cuerpo extraño.',
    color: AppColors.blue,
    icon: Icons.pregnant_woman,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la maniobra de elección en una embarazada con OVACE completa?',
        options: [
          'Compresiones torácicas en la mitad inferior del esternón',
          'Compresiones abdominales (Heimlich) estándar',
          'Golpes en la espalda en posición supina',
          'Compresiones abdominales modificadas en hipocondrio derecho',
        ],
        correctIndex: 0,
        explanation:
            'En embarazadas (especialmente > 20 semanas) se realizan compresiones TORÁCICAS en la mitad inferior del esternón, NO abdominales. Las compresiones abdominales pueden lesionar el útero grávido y el feto al ejercer presión directamente sobre el abdomen (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué están contraindicadas las compresiones abdominales en el tercer trimestre?',
        options: [
          'Riesgo de lesión uterina, desprendimiento de placenta o daño fetal',
          'El diafragma está más elevado y las compresiones son inefectivas',
          'El útero grávido bloquea el movimiento del diafragma',
          'Las compresiones abdominales causan dolor excesivo',
        ],
        correctIndex: 0,
        explanation:
            'Las compresiones abdominales en el tercer trimestre pueden causar lesiones graves como desprendimiento de placenta, rotura uterina, hemorragia intraabdominal y lesión fetal directa. Por eso se usan compresiones torácicas como alternativa segura (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Dónde se coloca el puño para las compresiones torácicas en la embarazada con OVACE?',
        options: [
          'Mitad inferior del esternón (unos 5 cm por encima del apéndice xifoides)',
          'Sobre el útero grávido',
          'En el hemitórax derecho',
          'En la parte superior del abdomen, debajo del esternón',
        ],
        correctIndex: 0,
        explanation:
            'El puño se coloca en la mitad inferior del esternón, aproximadamente 5 cm por encima del apéndice xifoides (la misma posición anatómica que las compresiones de RCP). Se realizan compresiones firmes y rápidas hacia adentro (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué maniobra adicional debe considerarse si la embarazada con OVACE pierde el conocimiento?',
        options: [
          'Iniciar RCP con desplazamiento manual del útero hacia la izquierda para mejorar retorno venoso',
          'Colocar a la paciente en posición Trendelenburg',
          'Administrar oxitocina para inducir el parto',
          'Colocar a la paciente boca abajo para drenar el objeto',
        ],
        correctIndex: 0,
        explanation:
            'Al iniciar RCP en una embarazada > 20 semanas, se debe realizar desplazamiento manual del útero hacia la izquierda (Left Uterine Displacement, LUD) para aliviar la compresión aorto-cava y mejorar el retorno venoso durante las compresiones (AHA 2020).',
      ),
    ],
  ),
  // Electrocución Pediátrica
  _EvalScenario(
    id: 'eval_electrocucion_pediatrica',
    title: 'Electrocución Pediátrica',
    subtitle: 'Lesión eléctrica por bajo voltaje en niños · AHA 2020',
    caseText:
        'Niño de 3 años es llevado a urgencias tras morder un cable eléctrico. Presenta una pequeña quemadura en la comisura labial y perdió el conocimiento brevemente.',
    color: AppColors.orange,
    icon: Icons.child_friendly,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la lesión más característica de la electrocución pediátrica por morder un cable?',
        options: [
          'Quemadura en la comisura de los labios (entrada) con posible quemadura en mano (salida)',
          'Quemadura extensa en toda la cavidad oral',
          'Lesión exclusivamente en las manos',
          'Sin lesión visible, solo alteración del ritmo cardíaco',
        ],
        correctIndex: 0,
        explanation:
            'Al morder un cable, la corriente entra por la comisura labial (niños pequeños humedecen el cable con saliva) y sale típicamente por una mano. La quemadura oral puede parecer pequeña inicialmente pero puede sangrar días después cuando se desprende la escara (día 7-14) (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la principal complicación cardíaca en electrocución pediátrica?',
        options: [
          'Arritmias cardíacas retardadas (hasta 24 horas después)',
          'Paro cardíaco inmediato siempre',
          'Hipertensión arterial severa',
          'Miocarditis eléctrica',
        ],
        correctIndex: 0,
        explanation:
            'Las arritmias cardíacas pueden presentarse de forma retardada, incluso horas después de la exposición. Las más comunes incluyen fibrilación ventricular, taquicardia ventricular y bloqueos AV. Se recomienda monitoreo cardíaco continuo por 24 horas (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué complicación oral tardía debe vigilarse en estos pacientes?',
        options: [
          'Hemorragia por desprendimiento de la escara de la quemadura labial (día 7-14)',
          'Infección intraoral fulminante',
          'Fusión mandibular completa',
          'Parálisis facial permanente',
        ],
        correctIndex: 0,
        explanation:
            'La escara de la quemadura labial se desprende entre los días 7-14 post-lesión, momento en que puede ocurrir una HEMORRAGIA significativa de la arteria labial. Los padres deben ser advertidos y el niño debe ser monitoreado. Puede requerir reparación quirúrgica (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué las contracciones musculares tetánicas en electrocución pueden causar lesiones adicionales?',
        options: [
          'Pueden causar fracturas óseas y luxaciones articulares',
          'Siempre causan rabdomiólisis masiva',
          'Provocan hipertermia maligna',
          'Causan ruptura esplénica',
        ],
        correctIndex: 0,
        explanation:
            'La corriente alterna (CA) de 60 Hz causa contracciones musculares tetánicas sostenidas que pueden ser más fuertes que la contracción voluntaria, causando fracturas por avulsión, luxaciones (especialmente de hombro) y compresión vertebral. La persona puede quedar "pegada" al contacto eléctrico (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué voltaje tiene típicamente la corriente doméstica en México?',
        options: [
          '110-127 voltios (bajo voltaje)',
          '220-240 voltios (alto voltaje)',
          '440-480 voltios',
          '12-24 voltios',
        ],
        correctIndex: 0,
        explanation:
            'En México, el voltaje doméstico es de 127V (similar a 110-120V en EE.UU.). Aunque se considera "bajo voltaje", la corriente alterna a 60 Hz puede ser letal, especialmente en niños pequeños cuya resistencia eléctrica es menor y la corriente pasa más fácilmente al corazón (AHA 2020).',
      ),
    ],
  ),
  // Electrocución Bañera
  _EvalScenario(
    id: 'eval_electrocucion_banera',
    title: 'Electrocución en Bañera',
    subtitle: 'Secador de pelo en la bañera · AHA 2020',
    caseText:
        'Mujer de 35 años se encuentra inconsciente en la bañera después de que un secador de pelo cayera al agua. Está en paro cardíaco y el agua continúa electrificada.',
    color: AppColors.orange,
    icon: Icons.bathtub,
    difficulty: 'Básico',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la PRIMERA acción del reanimador al presenciar esta escena?',
        options: [
          'Desconectar el secador de la corriente o cortar el suministro eléctrico principal',
          'Sacar a la víctima del agua inmediatamente',
          'Iniciar compresiones torácicas directamente en el agua',
          'Llamar al 911 sin mover a la víctima',
        ],
        correctIndex: 0,
        explanation:
            'La prioridad es CORTAR LA FUENTE DE ENERGÍA. NO tocar a la víctima mientras esté en contacto con el agua electrificada porque el reanimador también sufrirá electrocución. Desconectar el aparato o bajar el interruptor principal (breaker) antes de cualquier otra acción (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué es extremadamente peligroso tocar a la víctima sin desconectar la corriente?',
        options: [
          'El agua es conductora eléctrica y el reanimador también se electrocutará al tocar a la víctima',
          'El agua está caliente y puede causar quemaduras',
          'La víctima puede dar una descarga refleja',
          'El reanimador puede resbalar y caer',
        ],
        correctIndex: 0,
        explanation:
            'El agua es un excelente conductor eléctrico. Al tocar a la víctima, el reanimador completa el circuito eléctrico a tierra, recibiendo una descarga potencialmente fatal. SIEMPRE desconectar la fuente de poder antes de tocar a la víctima (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué ritmo cardíaco es más probable en electrocución por agua?',
        options: [
          'Fibrilación ventricular o asistolia',
          'Taquicardia sinusal',
          'Fibrilación auricular',
          'Ritmo de la unión AV',
        ],
        correctIndex: 0,
        explanation:
            'La electrocución frecuentemente causa fibrilación ventricular (FV) o asistolia. La FV es el ritmo más común cuando la corriente atraviesa el corazón durante la fase vulnerable del ciclo cardíaco. La asistolia ocurre por parálisis del centro respiratorio si la corriente atraviesa el tronco encefálico (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué pueden requerirse esfuerzos de reanimación prolongados en electrocución en bañera?',
        options: [
          'La hipotermia por inmersión puede tener efecto neuroprotector y la reanimación prolongada puede ser exitosa',
          'El agua caliente mantiene la perfusión cerebral',
          'La corriente eléctrica preserva los órganos vitales',
          'Los pacientes con electrocución no responden a reanimación breve',
        ],
        correctIndex: 0,
        explanation:
            'La inmersión en agua puede causar hipotermia, que tiene un efecto neuroprotector al disminuir el metabolismo cerebral. Se han reportado casos de recuperación neurológica completa después de RCP prolongada (> 30 min) en electrocución por hipotermia. No suspender prematuramente (AHA 2020).',
      ),
    ],
  ),
  // Electrocución Arco Eléctrico
  _EvalScenario(
    id: 'eval_electrocucion_arco',
    title: 'Electrocución por Arco Eléctrico',
    subtitle: 'Quemadura por alto voltaje y arco voltaico · AHA 2020',
    caseText:
        'Trabajador de 45 años sufre quemadura eléctrica severa por arco voltaico de 13,000V en una subestación eléctrica. Presenta lesiones extensas en mano derecha y pie izquierdo.',
    color: AppColors.orange,
    icon: Icons.whatshot,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Qué tipo de lesión caracteriza al arco eléctrico de alto voltaje?',
        options: [
          'Quemaduras profundas de espesor total con punto de entrada (mano) y salida (pie), con daño tisular interno extenso',
          'Quemaduras superficiales exclusivamente en la piel externa',
          'Solo daño cardíaco sin lesiones externas visibles',
          'Quemaduras exclusivamente en la vía aérea por inhalación',
        ],
        correctIndex: 0,
        explanation:
            'El arco eléctrico de alto voltaje (> 1000V) causa quemaduras de ESPESOR TOTAL con puntos de entrada y salida característicos. El daño tisular interno (músculo, nervios, vasos) suele ser mucho más extenso que la aparente lesión cutánea superficial. La corriente viaja a través de tejidos de menor resistencia (vasos, nervios) (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la complicación musculoesquelética más grave que debe vigilarse?',
        options: [
          'Síndrome compartimental que requiere fasciotomía',
          'Fractura expuesta de fémur',
          'Luxación de cadera bilateral',
          'Atrofia muscular irreversible inmediata',
        ],
        correctIndex: 0,
        explanation:
            'El edema muscular severo post-electrocución puede causar SÍNDROME COMPARTIMENTAL en extremidades afectadas. La presión intracompartimental aumenta por necrosis muscular y edema, comprometiendo la perfusión distal. Requiere fasciotomía de urgencia para salvar la extremidad (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué complicación sistémica por necrosis muscular requiere manejo agresivo?',
        options: [
          'Rabdomiólisis con insuficiencia renal aguda por mioglobinuria',
          'Insuficiencia hepática fulminante',
          'Pancreatitis necrohemorrágica',
          'Insuficiencia suprarrenal aguda',
        ],
        correctIndex: 0,
        explanation:
            'La necrosis muscular masiva libera mioglobina que precipita en los túbulos renales causando insuficiencia renal aguda. Requiere hidratación agresiva con cristaloides (mantener gasto urinario > 100 mL/h), bicarbonato para alcalinizar la orina y posiblemente hemodiálisis (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué se recomienda monitoreo cardíaco extendido en estos pacientes?',
        options: [
          'Las arritmias pueden presentarse hasta 24-48 horas después por necrosis miocárdica o lesión de conducción',
          'El corazón se detiene permanentemente 72 horas después',
          'La pericarditis es universal en electrocución',
          'El infarto al miocardio es inevitable',
        ],
        correctIndex: 0,
        explanation:
            'La corriente de alto voltaje puede causar necrosis miocárdica, alteraciones de la conducción (bloqueos AV, BRIHH) y arritmias ventriculares tardías. Se recomienda monitoreo cardíaco continuo por 24-48 horas y ECG seriado con enzimas cardíacas (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el manejo inicial de líquidos en un paciente con quemadura eléctrica de alto voltaje?',
        options: [
          'Hidratación agresiva con cristaloides para mantener gasto urinario > 100 mL/h y prevenir insuficiencia renal',
          'Restricción hídrica para evitar sobrecarga pulmonar',
          'Solo solución salina al 0.45% a 50 mL/h',
          'Coloides exclusivamente (albúmina) para mantener presión oncótica',
        ],
        correctIndex: 0,
        explanation:
            'Se requiere hidratación AGRESIVA con Ringer Lactato o solución salina para mantener gasto urinario > 100 mL/h (adultos). Esto previene la precipitación de mioglobina en los túbulos renales. El volumen requerido puede ser mayor que en quemaduras térmicas por el daño muscular oculto (AHA 2020).',
      ),
    ],
  ),
  // Sobredosis de Antidepresivos Tricíclicos
  _EvalScenario(
    id: 'eval_sobredosis_triciclicos',
    title: 'Sobredosis de Antidepresivos Tricíclicos',
    subtitle: 'Toxicidad cardíaca por ATC · AHA 2020',
    caseText:
        'Mujer de 35 años con antecedentes de depresión mayor ingerida 30 tabletas de amitriptilina 50 mg hace 2 horas. Llega somnolienta, con PA 90/60 mmHg, FC 120 lpm, FR 14 rpm, saturación 94%. El ECG muestra QRS ancho (>140 ms) y desviación del eje a la derecha. Pupilas midriáticas, piel seca y caliente.',
    color: AppColors.accent,
    icon: Icons.medication_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es el hallazgo electrocardiográfico más característico de la toxicidad por antidepresivos tricíclicos?',
        options: [
          'Intervalo PR corto y onda delta',
          'Complejo QRS ancho (>100 ms) con desviación del eje a la derecha',
          'Intervalo QT corto',
          'Supradesnivel ST en cara inferior',
        ],
        correctIndex: 1,
        explanation:
            'Los ATC bloquean los canales de sodio rápidos del corazón, causando ensanchamiento del QRS (>100 ms) y desviación del eje a la derecha (terminal R en aVR). QRS >140 ms predice convulsiones y >160 ms predice arritmias ventriculares. Es el marcador más sensible de toxicidad grave (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el tratamiento de primera línea para el QRS ancho por toxicidad por ATC?',
        options: [
          'Lidocaína IV',
          'Bicarbonato de sodio 1-2 mEq/kg IV en bolo',
          'Amiodarona IV',
          'Sulfato de magnesio IV',
        ],
        correctIndex: 1,
        explanation:
            'El bicarbonato de sodio es el tratamiento de primera línea. Corrige la acidosis metabólica y proporciona sodio extracelular para superar el bloqueo de canales de sodio. Dosis: 1-2 mEq/kg IV en bolo, repetir hasta QRS <120 ms. El objetivo es pH sérico 7.50-7.55 (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué complicación neurológica es característica de la toxicidad por ATC antes de las arritmias?',
        options: [
          'Estado epiléptico refractario',
          'Convulsiones tónico-clónicas generalizadas',
          'Accidente cerebrovascular isquémico',
          'Hemiparesia transitoria',
        ],
        correctIndex: 1,
        explanation:
            'Las convulsiones son una manifestación temprana de toxicidad severa por ATC, precediendo típicamente a las arritmias ventriculares. Ocurren por bloqueo de canales de sodio en el SNC. Un QRS >140 ms predice su aparición. Deben tratarse con benzodiacepinas; la fenitoína está contraindicada (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué signo anticolinérgico periférico es típico en la sobredosis por ATC?',
        options: [
          'Piel seca y caliente, midriasis, íleo paralítico, retención urinaria',
          'Diaforesis profusa y miosis',
          'Salivación excesiva y lagrimeo',
          'Piel fría y húmeda con miosis',
        ],
        correctIndex: 0,
        explanation:
            'Los ATC tienen potente efecto anticolinérgico. La tríada clásica incluye: piel seca y caliente, midriasis pupilar, íleo/retener urinaria. Taquicardia sinusal también es común. Esto ayuda a diferenciar de sobredosis por opioides (miosis, bradipnea) o colinérgicos (salivación, lagrimeo) (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo está indicada la administración de grasa intravenosa (Intralipid) en intoxicación por ATC?',
        options: [
          'En todos los pacientes con QRS >120 ms',
          'En paro cardíaco refractario o inestabilidad hemodinámica severa que no responde al bicarbonato',
          'Como tratamiento de primera línea antes del bicarbonato',
          'No está indicada en intoxicación por ATC',
        ],
        correctIndex: 1,
        explanation:
            'La emulsión lipídica intravenosa (Intralipid 20%) está indicada en toxicidad cardiovascular grave refractaria al bicarbonato. Actúa como "sumidero" lipídico que extrae el fármaco del miocardio. Dosis: 1.5 mL/kg en bolo, seguido de 0.25 mL/kg/min. No reemplaza al bicarbonato como primera línea (AHA 2020).',
      ),
    ],
  ),

  // Sobredosis de Paracetamol
  _EvalScenario(
    id: 'eval_sobredosis_paracetamol',
    title: 'Sobredosis de Paracetamol',
    subtitle: 'Toxicidad hepática por paracetamol · AHA 2020',
    caseText:
        'Adolescente de 16 años ingerida 30 tabletas de paracetamol 500 mg (15 g) hace 4 horas en intento autolítico. Llega asintomática, consciente, con PA 110/70, FC 88, SatO2 98%. Niega dolor abdominal. Tiene antecedentes de depresión. Se solicita nivel sérico de paracetamol.',
    color: AppColors.accent,
    icon: Icons.medication_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuándo debe realizarse la determinación del nivel sérico de paracetamol para usar el nomograma de Rumack-Matthew?',
        options: [
          'Inmediatamente al llegar a emergencias',
          'A partir de las 4 horas postingesta',
          'Solo a las 24 horas',
          'No requiere nivel sérico, el tratamiento es clínico',
        ],
        correctIndex: 1,
        explanation:
            'El nomograma de Rumack-Matthew es válido SOLO a partir de las 4 horas postingesta (tiempo necesario para absorción completa). Niveles antes de 4 horas no son interpretables. Si se desconoce la hora exacta, tratar como si estuviera en rango de toxicidad. Nivel >150 mcg/mL a las 4 horas indica toxicidad hepática probable (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el antídoto para la intoxicación por paracetamol y cuándo debe iniciarse?',
        options: [
          'N-acetilcisteína (NAC) oral o IV, idealmente dentro de las primeras 8 horas postingesta',
          'Carbón activado en dosis única, independientemente del tiempo',
          'Flumazenilo IV 0.2 mg',
          'Bicarbonato de sodio 1 mEq/kg',
        ],
        correctIndex: 0,
        explanation:
            'La N-acetilcisteína (NAC) es el antídoto específico. Reconstituye los depósitos de glutatión hepático. Es más efectiva si se administra dentro de las primeras 8 horas postingesta. Puede administrarse oral (140 mg/kg de carga, luego 70 mg/kg c/4 h x 17 dosis) o IV (protocolo de 20-21 horas). Pasadas 24 horas tiene utilidad limitada pero debe administrarse igual (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué dosis de paracetamol se considera potencialmente hepatotóxica en adultos?',
        options: [
          'Cualquier dosis >4 g en 24 horas',
          'Dosis única >7.5-10 g o >150 mg/kg',
          '>2 g en 24 horas',
          '>15 g siempre',
        ],
        correctIndex: 1,
        explanation:
            'En adultos, dosis únicas >7.5-10 g o >150 mg/kg tienen riesgo de hepatotoxicidad. Dosis >12-15 g pueden causar necrosis hepática severa. Sin embargo, pacientes con depleción de glutatión (alcoholismo, desnutrición, inductores enzimáticos) pueden presentar toxicidad con dosis menores (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué estudios de laboratorio deben monitorizarse para evaluar daño hepático?',
        options: [
          'AST, ALT, INR, bilirrubinas y creatinina cada 6-12 horas',
          'Solo ALT a las 24 horas',
          'Gasometría arterial y electrolitos',
          'Amilasa y lipasa séricas',
        ],
        correctIndex: 0,
        explanation:
            'El daño hepático se evalúa con transaminasas (AST/ALT). AST >1000 U/L indica necrosis hepática. El INR mide la función sintética hepática (INR >2 sugiere falla hepática severa). La creatinina evalúa daño renal asociado (síndrome hepatorrenal). Deben monitorizarse cada 6-12 horas hasta que estén en descenso (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué criterio indica la necesidad de trasplante hepático en falla hepática por paracetamol?',
        options: [
          'ALT >5000 U/L',
          'Criterios de King\'s College: pH <7.3 (tras reanimación) o INR >6.5 + creatinina >3.4 mg/dL + encefalopatía grado III-IV',
          'Bilirrubina >20 mg/dL',
          'AST >1000 U/L con ALT normal',
        ],
        correctIndex: 1,
        explanation:
            'Los criterios de King\'s College para trasplante hepático urgente en intoxicación por paracetamol son: pH arterial <7.3 luego de reanimación hídrica, o la tríada: INR >6.5, creatinina >3.4 mg/dL y encefalopatía hepática grado III-IV. Tienen alta especificidad para predecir mortalidad sin trasplante (AHA 2020).',
      ),
    ],
  ),

  // IAM Anterior
  _EvalScenario(
    id: 'eval_infarto_anterior',
    title: 'IAM Anterior Extenso',
    subtitle: 'STEMI anterior por oclusión de la DA · AHA 2020',
    caseText:
        'Hombre de 55 años, fumador, hipertenso y diabético, presenta dolor torácico opresivo retroesternal de 1 hora de evolución, irradiado a brazo izquierdo, acompañado de disnea, diaforesis y náuseas. PA 150/90 mmHg, FC 95 lpm, FR 20 rpm, SatO2 96%. ECG muestra supradesnivel ST >2 mm en V1-V6, I y aVL.',
    color: AppColors.red,
    icon: Icons.favorite_border,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Qué arteria está ocluida en un IAM anterior extenso con supradesnivel ST de V1 a V6?',
        options: [
          'Arteria coronaria derecha (CD)',
          'Arteria descendente anterior (DA) proximal',
          'Arteria circunfleja (Cx)',
          'Tronco de la coronaria izquierda',
        ],
        correctIndex: 1,
        explanation:
            'El supradesnivel ST de V1 a V6 (anterior extenso) indica oclusión de la arteria descendente anterior (DA) proximal, antes de la primera rama septal. Es un infarto de alto riesgo con gran masa miocárdica en riesgo y mal pronóstico si no se revasculariza precozmente (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la ventana de tiempo recomendada para ICP primaria en un STEMI?',
        options: [
          'ICP dentro de las primeras 12 horas del inicio de síntomas, idealmente <90 min desde el primer contacto médico',
          'ICP dentro de las primeras 6 horas solamente',
          'ICP solo si han pasado >24 horas',
          'ICP dentro de los primeros 30 minutos obligatoriamente',
        ],
        correctIndex: 0,
        explanation:
            'La ICP primaria está indicada dentro de las primeras 12 horas del inicio de síntomas. El objetivo es un tiempo puerta-balón <90 minutos desde el primer contacto médico. En pacientes que llegan dentro de las primeras 2 horas y con infarto extenso, el tiempo puerta-balón debe ser <60 minutos (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            'Si el tiempo de traslado a un centro con ICP es >120 minutos, ¿cuál es la alternativa?',
        options: [
          'Fibrinólisis dentro de los primeros 30 minutos de la llegada al hospital',
          'Manejo médico exclusivo sin reperfusión',
          'Esperar y trasladar para ICP sin fibrinólisis',
          'Cirugía de revascularización miocárdica urgente',
        ],
        correctIndex: 0,
        explanation:
            'Si el tiempo esperado hasta ICP es >120 minutos, debe administrarse fibrinólisis en los primeros 30 minutos del ingreso (tiempo puerta-aguja <30 min), siempre que no haya contraindicaciones. Luego trasladar a centro con capacidad de ICP para angiografía en 2-24 horas (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué medicación debe administrarse en las primeras horas del STEMI independientemente de la estrategia de reperfusión?',
        options: [
          'Aspirina 300 mg masticable, clopidogrel 600 mg o ticagrelor 180 mg, y heparina (no fraccionada o de bajo peso molecular)',
          'Solo aspirina 100 mg',
          'Warfarina 5 mg más aspirina',
          'Rivaroxabán más aspirina sin antiagregantes',
        ],
        correctIndex: 0,
        explanation:
            'La terapia antitrombótica inicial incluye: aspirina 300 mg (dosis de carga masticable), un segundo antiagregante (clopidogrel 600 mg o ticagrelor 180 mg), y anticoagulación (heparina no fraccionada 60 UI/kg bolo o enoxaparina 30 mg IV + 1 mg/kg SC). La doble antiagregación debe continuar 12 meses (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué complicación mecánica es más temida en el IAM anterior extenso en los primeros 3-7 días?',
        options: [
          'Derrame pericárdico leve',
          'Ruptura de la pared libre del VI con taponamiento cardíaco y muerte súbita',
          'Pericarditis aguda benigna',
          'Aneurisma de la aorta torácica',
        ],
        correctIndex: 1,
        explanation:
            'La ruptura de la pared libre del ventrículo izquierdo es una complicación catastrófica del IAM anterior extenso transmural, más frecuente entre el 3° y 7° día. Se presenta como colapso cardiovascular súbito por taponamiento cardíaco. También pueden ocurrir ruptura del septo interventricular o insuficiencia mitral por disfunción/isquemia del músculo papilar (AHA 2020).',
      ),
    ],
  ),

  // Shock Cardiogénico post-IAM
  _EvalScenario(
    id: 'eval_infarto_shock_cardiogenico',
    title: 'Shock Cardiogénico post-IAM',
    subtitle: 'Falla de bomba post-infarto · AHA 2020',
    caseText:
        'Hombre de 62 años con IAM anterior extenso de 6 horas de evolución presenta hipotensión persistente (PA 70/40 mmHg), taquicardia (FC 125 lpm), piel fría y diaforética, oliguria (<20 mL/h), confusión mental y SatO2 88% con edema pulmonar. No responde a cristaloides. Se coloca catéter de arteria pulmonar.',
    color: AppColors.red,
    icon: Icons.favorite_border,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es el vasopresor de primera línea en el shock cardiogénico post-IAM?',
        options: [
          'Dobutamina en monoterapia',
          'Noradrenalina (norepinefrina) para mantener PAM >65 mmHg',
          'Dopamina a dosis altas >10 mcg/kg/min',
          'Fenilefrina como agonista alfa puro',
        ],
        correctIndex: 1,
        explanation:
            'La noradrenalina es el vasopresor de primera línea en shock cardiogénico (AHA clase I). Aumenta la PAM sin aumentar significativamente la frecuencia cardíaca. La dobutamina se usa como inotrópico si hay gasto cardíaco bajo con PAM >70 mmHg, o combinada con noradrenalina. Dopamina se asocia a más arritmias (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo está indicado el uso de balón de contrapulsación intraaórtico (BCIAo)?',
        options: [
          'En todos los pacientes con shock cardiogénico post-IAM de rutina',
          'Como puente a revascularización o como soporte en shock refractario al tratamiento médico',
          'Solo si hay insuficiencia aórtica severa',
          'Contraindicado en shock cardiogénico',
        ],
        correctIndex: 1,
        explanation:
            'El BCIAo NO se usa de rutina (ensayos IABP-SHOCK II no mostraron beneficio en mortalidad). Está indicado como soporte hemodinámico puente a revascularización (ICP o cirugía) en shock refractario. Mejora la presión de perfusión coronaria diastólica y reduce la poscarga del VI (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la estrategia de revascularización recomendada en shock cardiogénico?',
        options: [
          'Revascularización completa de todas las lesiones en el mismo procedimiento',
          'ICP de la arteria culpable únicamente, con revascularización diferida de otras lesiones',
          'Fibrinólisis exclusivamente',
          'Cirugía de revascularización miocárdica como primera opción',
        ],
        correctIndex: 1,
        explanation:
            'En shock cardiogénico, la estrategia es ICP de la lesión culpable (arteria relacionada al infarto) tan pronto como sea posible. La revascularización completa de múltiples lesiones en el mismo procedimiento aumenta el riesgo. Las lesiones no culpables se revascularizan de forma diferida (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué Índice cardíaco (IC) y presión capilar pulmonar (PCP) confirman el diagnóstico de shock cardiogénico?',
        options: [
          'IC >2.5 L/min/m² y PCP <12 mmHg',
          'IC <2.2 L/min/m² y PCP >15 mmHg con PAS <90 mmHg',
          'IC <1.5 L/min/m² y PCP <10 mmHg',
          'IC normal con PCP elevada',
        ],
        correctIndex: 1,
        explanation:
            'El shock cardiogénico se define hemodinámicamente por: PAS <90 mmHg (o necesidad de vasopresores), IC <2.2 L/min/m² (o <1.8 sin soporte) y PCP >15 mmHg. Refleja disfunción ventricular izquierda severa con hipoperfusión tisular a pesar de volumen intravascular adecuado (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué dispositivo de soporte circulatorio mecánico debe considerarse en shock refractario?',
        options: [
          'ECMO veno-arterial (VA-ECMO) o dispositivo Impella',
          'Desfibrilador automático implantable',
          'Ventilador mecánico',
          'Balón de contrapulsación intraaórtico como única opción',
        ],
        correctIndex: 0,
        explanation:
            'En shock cardiogénico refractario pese a vasopresores y BCIAo, debe considerarse soporte circulatorio mecánico avanzado: VA-ECMO (oxigenación por membrana extracorpórea) o Impella (bomba de flujo axial transvalvular aórtica). El ECMO provee soporte biventricular completo y oxigenación. Son puentes a recuperación, trasplante o dispositivo de larga duración (AHA 2020).',
      ),
    ],
  ),

  // IAM Ventrículo Derecho
  _EvalScenario(
    id: 'eval_infarto_derecho',
    title: 'IAM de Ventrículo Derecho',
    subtitle: 'Infarto del VD complicando IAM inferior · AHA 2020',
    caseText:
        'Hombre de 58 años con IAM inferior (supradesnivel ST en II, III, aVF) presenta hipotensión (PA 80/50 mmHg), distensión yugular marcada, signo de Kussmaul y campos pulmonares limpios a la auscultación. FC 110 lpm, SatO2 93%. Recibió nitroglicerina sublingual hace 10 minutos con empeoramiento de la hipotensión.',
    color: AppColors.red,
    icon: Icons.favorite_border,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Qué hallazgo electrocardiográfico confirma el diagnóstico de IAM de ventrículo derecho?',
        options: [
          'Supradesnivel ST en V1 y V2',
          'Supradesnivel ST >0.5 mm en V4R (derivaciones derechas)',
          'Infradesnivel ST en II, III, aVF',
          'Ondas T invertidas en V5-V6',
        ],
        correctIndex: 1,
        explanation:
            'El supradesnivel ST >0.5 mm en V4R (derivación precordial derecha) es el marcador más sensible y específico de IAM de VD. Debe solicitarse ECG con derivaciones derechas (V1R a V6R) en todo IAM inferior con hipotensión. V4R tiene >90% de sensibilidad para infarto de VD (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué los nitratos están contraindicados en el IAM de ventrículo derecho?',
        options: [
          'Porque causan taquicardia refleja que empeora la isquemia',
          'Porque reducen la precarga, empeorando el gasto cardíaco del VD isquémico y la hipotensión',
          'Porque causan broncoespasmo',
          'Porque aumentan la poscarga del VD',
        ],
        correctIndex: 1,
        explanation:
            'Los nitratos son venodilatadores que reducen la precarga. En el IAM de VD, el ventrículo derecho isquémico depende de una precarga adecuada para mantener el gasto cardíaco. La reducción de la precarga por nitratos colapsa el gasto del VD, causando hipotensión severa. Están contraindicados (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el tratamiento de primera línea para la hipotensión en el IAM de VD?',
        options: [
          'Vasopresores como noradrenalina',
          'Carga de volumen intravenoso con cristaloides (500-1000 mL)',
          'Furosemida IV para reducir la precarga',
          'Nitroglicerina IV titulada',
        ],
        correctIndex: 1,
        explanation:
            'La carga de volumen (500-1000 mL de cristaloides en bolo) es el tratamiento de primera línea para la hipotensión en el IAM de VD. Aumenta la precarga del VD isquémico, mejorando el gasto cardíaco. Si persiste la hipotensión, agregar noradrenalina. Evitar diuréticos y nitratos (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la tríada clásica del infarto de ventrículo derecho?',
        options: [
          'Hipotensión, distensión yugular y campos pulmonares limpios',
          'Dolor torácico, disnea y edema pulmonar',
          'Hipotensión, ingurgitación yugular y crepitantes pulmonares',
          'Hipertensión, bradicardia y edema',
        ],
        correctIndex: 0,
        explanation:
            'La tríada clásica del IAM de VD es: hipotensión (por bajo gasto del VD), distensión yugular (presión venosa central elevada) y campos pulmonares limpios (sin congestión pulmonar). Esto contrasta con el IAM de VI donde la hipotensión se acompaña de edema pulmonar. El signo de Kussmaul (aumento de la presión yugular en inspiración) también es característico (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la complicación más frecuente en la evolución del IAM de VD?',
        options: [
          'Insuficiencia cardíaca derecha crónica',
          'Bloqueo AV completo e hipotensión refractaria en la fase aguda',
          'Ruptura de pared libre del VD',
          'Embolia pulmonar masiva',
        ],
        correctIndex: 1,
        explanation:
            'El bloqueo AV completo es una complicación frecuente del IAM inferior/VD. La hipotensión refractaria en la fase aguda del IAM de VD es la principal causa de mortalidad. La insuficiencia cardíaca derecha suele mejorar con la reperfusión y generalmente es transitoria. Requiere manejo con volumen, evitar nitratos y marcapasos si hay BAV (AHA 2020).',
      ),
    ],
  ),

  // DEA en Niños
  _EvalScenario(
    id: 'eval_dea_pediatrico',
    title: 'DEA en Niños',
    subtitle: 'Uso del DEA en niños · AHA 2020',
    caseText:
        'Niño de 5 años colapsa súbitamente mientras juega en el parque. Está inconsciente, no respira y no tiene pulso. Un transeúnte trae un DEA del centro comercial cercano. El niño pesa aproximadamente 18 kg. Se inicia RCP mientras se prepara el DEA.',
    color: AppColors.amber,
    icon: Icons.electric_bolt,
    difficulty: 'Básico',
    questions: [
      _EvalQuestion(
        question:
            '¿A partir de qué edad se recomienda el uso del DEA en niños?',
        options: [
          'Mayores de 1 año',
          'Mayores de 8 años',
          'Cualquier edad, incluyendo lactantes menores de 1 año',
          'Solo mayores de 12 años',
        ],
        correctIndex: 0,
        explanation:
            'El DEA se recomienda en niños ≥1 año con paro cardíaco extrahospitalario. En lactantes <1 año no hay suficiente evidencia, pero puede usarse si no hay alternativa. En niños de 1-8 años deben usarse parches pediátricos con atenuador de dosis si están disponibles (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Qué tipo de parches debe usarse en un niño de 5 años?',
        options: [
          'Parches pediátricos con atenuador de dosis si están disponibles',
          'Solo parches de adulto, no hay diferencia',
          'Parches pediátricos solo si el niño pesa <10 kg',
          'No debe usarse DEA en niños',
        ],
        correctIndex: 0,
        explanation:
            'En niños de 1-8 años deben usarse parches pediátricos con atenuador de dosis si están disponibles. El atenuador reduce la energía de descarga a un nivel apropiado (50-75 J). Si no hay parches pediátricos, pueden usarse parches de adulto asegurando que no se toquen entre sí (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            'Si no hay parches pediátricos disponibles para el niño, ¿qué debe hacerse?',
        options: [
          'No usar el DEA',
          'Usar parches de adulto colocándolos en posición anterolateral o anteroposterior sin que se toquen',
          'Realizar solo RCP manual hasta llegar al hospital',
          'Usar parches de adulto en los muslos',
        ],
        correctIndex: 1,
        explanation:
            'Si no hay parches pediátricos, pueden usarse parches de adulto. Es fundamental asegurar que no se toquen entre sí para evitar arcos eléctricos. Si el tórax es muy pequeño, puede usarse posición anteroposterior (un parche en el pecho, otro en la espalda) (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿En qué niños debe usarse un DEA estándar con parches de adulto sin atenuador?',
        options: [
          'En niños mayores de 8 años o con peso >25 kg',
          'Nunca, siempre deben usarse parches pediátricos',
          'En niños menores de 1 año',
          'Solo si el niño está en paro por ahogamiento',
        ],
        correctIndex: 0,
        explanation:
            'En niños ≥8 años o con peso >25 kg debe usarse el DEA estándar con parches de adulto y dosis estándar (full dose). El sistema de atenuación pediátrica se recomienda solo para niños de 1-8 años (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la secuencia de acciones al usar el DEA en un niño en paro cardíaco?',
        options: [
          'Colocar parches, encender DEA, alejarse, analizar ritmo, descargar si indica, reanudar RCP',
          'RCP por 2 minutos antes de colocar el DEA',
          'Administrar 5 descargas consecutivas antes de RCP',
          'Encender DEA primero, luego RCP 2 minutos, luego parches',
        ],
        correctIndex: 0,
        explanation:
            'La secuencia es: 1) RCP hasta tener DEA, 2) encender DEA, 3) colocar parches en tórax seco, 4) alejarse (no tocar al paciente), 5) dejar que el DEA analice, 6) si indica descarga, asegurar que nadie toca y presionar botón, 7) reanudar RCP inmediatamente 2 minutos, 8) repetir análisis. Minimizar interrupciones <10 segundos (AHA 2020).',
      ),
    ],
  ),

  // DEA Superficie Mojada
  _EvalScenario(
    id: 'eval_dea_superficie_mojada',
    title: 'DEA en Superficie Mojada',
    subtitle: 'Seguridad del DEA con agua · AHA 2020',
    caseText:
        'Mujer de 45 años es encontrada inconsciente en el suelo mojado junto a una alberca pública. No responde, no respira, no tiene pulso. El suelo está completamente mojado con charcos alrededor. Un socorrista trae un DEA. La víctima está tendida sobre un charco de agua.',
    color: AppColors.amber,
    icon: Icons.electric_bolt,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Es seguro usar un DEA en una víctima que está sobre una superficie mojada?',
        options: [
          'Sí, siempre que se tomen precauciones como secar el tórax y alejar el agua',
          'No, nunca debe usarse un DEA en presencia de agua',
          'Solo si la víctima no está completamente mojada',
          'Sí, sin ninguna precaución, los DEA modernos son waterproof',
        ],
        correctIndex: 0,
        explanation:
            'El DEA puede usarse en entornos húmedos tomando precauciones: secar el tórax vigorosamente, alejar a la víctima de charcos si es posible, asegurar buena adherencia de parches y evitar que el agua conduzca electricidad durante la descarga (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la primera precaución al usar DEA sobre una víctima mojada?',
        options: [
          'Secar el pecho vigorosamente antes de colocar los parches',
          'Conectar el DEA a un regulador de voltaje',
          'Colocar una manta aislante bajo la víctima',
          'Usar parches pediátricos en lugar de adultos',
        ],
        correctIndex: 0,
        explanation:
            'El tórax debe estar seco para garantizar adherencia completa de los parches y evitar que el agua forme puentes conductores que dispersen la corriente o causen quemaduras. Secar con toalla o paño seco antes de colocar parches (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué riesgo específico existe al aplicar parches de DEA sobre piel mojada?',
        options: [
          'El DEA no analiza correctamente el ritmo',
          'El agua puede conducir electricidad causando arcos eléctricos, quemaduras o descarga a reanimadores',
          'Los parches se despegan inmediatamente',
          'El DEA se apaga al detectar humedad',
        ],
        correctIndex: 1,
        explanation:
            'La humedad en la piel conduce electricidad. Durante la descarga, el agua puede crear caminos eléctricos alternos (arcos) que queman la piel o transmiten la descarga a los reanimadores que tocan a la víctima o el charco. Secar bien minimiza este riesgo (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué debe hacerse si la víctima está sobre un charco de agua significativo?',
        options: [
          'Mover a la víctima a una superficie seca si es seguro hacerlo, antes de aplicar el DEA',
          'Aplicar el DEA directamente sobre el agua, no hay problema',
          'Esperar a que el agua se evapore',
          'No usar el DEA bajo ninguna circunstancia',
        ],
        correctIndex: 0,
        explanation:
            'Si es posible y seguro, debe moverse a la víctima a una superficie seca. Si no es posible, alejar el agua (secar el piso alrededor) y secar el tórax. El reanimador no debe estar en contacto con agua durante la descarga (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Debe retirarse el agua del tórax de la víctima antes de la RCP además de para el DEA?',
        options: [
          'Sí, aunque la prioridad es iniciar RCP; si hay agua visible, secar el tórax superficialmente sin demorar las compresiones',
          'No, el agua no interfiere con las compresiones',
          'Solo si se va a usar el DEA',
          'No, el agua ayuda a la conductividad de las compresiones',
        ],
        correctIndex: 0,
        explanation:
            'El exceso de agua en el tórax puede interferir con la colocación de manos para compresiones efectivas (resbalan) y con la ventilación. Secar superficialmente el tórax sin demorar significativamente el inicio de RCP es razonable. La prioridad sigue siendo iniciar compresiones rápidamente (AHA 2020).',
      ),
    ],
  ),

  // Ahogamiento en Agua Fría
  _EvalScenario(
    id: 'eval_ahogamiento_agua_fria',
    title: 'Ahogamiento en Agua Fría',
    subtitle: 'Rescate en hipotermia por inmersión · AHA 2020',
    caseText:
        'Buzo de 35 años rescatado del mar tras 25 minutos sumergido en agua a 8°C. Está inconsciente, no respira, no tiene pulso. Temperatura corporal estimada 28°C. Piel pálida y fría, pupilas midriáticas no reactivas. El equipo de rescate dispone de DEA, bolsa-mascarilla y oxígeno. Se inicia RCP.',
    color: AppColors.cyan,
    icon: Icons.water_drop,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la secuencia inicial de reanimación en ahogamiento por agua fría?',
        options: [
          'Iniciar con 30 compresiones torácicas sin ventilación',
          'Administrar 2 ventilaciones de rescate iniciales, luego continuar RCP 30:2',
          'Aplicar DEA antes de iniciar cualquier maniobra',
          'Esperar 1 minuto a ver si revive espontáneamente por el reflejo de inmersión',
        ],
        correctIndex: 1,
        explanation:
            'En ahogamiento, la hipoxia es la causa del paro. La prioridad es la ventilación. AHA 2020 recomienda: dar 2 ventilaciones de rescate iniciales (incluso en el agua si es seguro), luego continuar RCP 30:2. Activar DEA tan pronto como esté disponible. El reflejo de inmersión mamífero (bradicardia + apnea + vasoconstricción periférica) puede proteger órganos pero no revive al paciente (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo debe considerarse suspender la reanimación en hipotermia severa por inmersión?',
        options: [
          'Después de 30 minutos de RCP sin respuesta',
          'Solo cuando el paciente esté recalentado (>35°C) y continúe sin signos vitales',
          'Después de 3 descargas del DEA sin éxito',
          'Si las pupilas están midriáticas y no reactivas',
        ],
        correctIndex: 1,
        explanation:
            'Principio fundamental: "nadie está muerto hasta que está caliente y muerto". El frío protege el SNC al disminuir el metabolismo cerebral. Se han reportado supervivencias neurológicas intactas tras >60 minutos de paro en agua helada. La midriasis no es confiable en hipotermia. NO suspender RCP hasta recalentamiento (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            'En hipotermia severa (<30°C) con FV en el DEA, ¿cuántas descargas deben administrarse?',
        options: [
          'Descargas ilimitadas hasta convertir el ritmo',
          'Hasta 3 descargas, luego diferir más descargas hasta T° >30°C',
          'Ninguna descarga hasta alcanzar normotermia',
          '1 descarga cada 10 minutos',
        ],
        correctIndex: 1,
        explanation:
            'Se recomiendan hasta 3 descargas por episodio de FV/TV si T° <30°C. Si persiste la FV, se difieren descargas adicionales hasta que la temperatura supere 30°C, priorizando el recalentamiento. El miocardio hipotérmico es refractario a desfibrilación (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué pueden requerirse esfuerzos de reanimación prolongados en ahogamiento por agua fría?',
        options: [
          'El reflejo de inmersión mamífero preserva oxígeno cerebral, permitiendo RCP prolongada exitosa',
          'El agua fría mantiene la perfusión cerebral',
          'La salinidad del mar preserva los órganos',
          'La presión del agua mantiene el gasto cardíaco',
        ],
        correctIndex: 0,
        explanation:
            'El reflejo de inmersión mamífero (apnea, bradicardia, vasoconstricción periférica) desvía sangre oxigenada al cerebro y corazón. La hipotermia reduce el metabolismo cerebral en ~6% por cada °C. Esto permite períodos prolongados de hipoxia sin daño neurológico significativo, justificando RCP prolongada (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué precaución debe tomarse con el DEA en un paciente mojado rescatado del agua?',
        options: [
          'No usar DEA hasta que el paciente esté completamente seco (30 min)',
          'Secar el tórax vigorosamente antes de colocar parches, igual que en entorno húmedo',
          'Usar parches pediátricos porque la piel está fría',
          'No usar DEA, solo desfibrilación manual',
        ],
        correctIndex: 1,
        explanation:
            'El paciente rescatado está mojado. Debe secarse el tórax vigorosamente antes de colocar los parches para garantizar adherencia y evitar conducción eléctrica por agua. Esto aplica tanto para el DEA como para desfibrilación manual (AHA 2020).',
      ),
    ],
  ),

  // Ahogamiento Pediátrico
  _EvalScenario(
    id: 'eval_ahogamiento_pediatrico',
    title: 'Ahogamiento Pediátrico',
    subtitle: 'Reanimación en niños por inmersión · AHA 2020',
    caseText:
        'Niña de 3 años rescatada de una piscina familiar tras 3 minutos sin supervisión. Está inconsciente, no responde. Presenta respiración agónica (boqueadas ocasionales). No se palpa pulso. Pesa aproximadamente 14 kg. La piscina es de agua dulce.',
    color: AppColors.cyan,
    icon: Icons.water_drop,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la primera acción al rescatar a un niño inconsciente del agua?',
        options: [
          'Iniciar compresiones torácicas inmediatamente',
          'Abrir vía aérea y administrar 2 ventilaciones de rescate',
          'Aplicar DEA antes de cualquier otra acción',
          'Colocar en posición lateral de seguridad',
        ],
        correctIndex: 1,
        explanation:
            'En ahogamiento pediátrico, la hipoxia es la causa del paro. AHA 2020 recomienda dar 2 ventilaciones de rescate iniciales tan pronto como sea seguro (incluso en el agua si es viable). Luego continuar RCP 30:2 y activar DEA. Sin ventilación, las compresiones no oxigenan la sangre (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué indica la presencia de respiración agónica (boqueadas) en un niño inconsciente tras ahogamiento?',
        options: [
          'Que respira adecuadamente y no necesita RCP',
          'Que está en paro cardíaco y debe iniciarse RCP inmediatamente',
          'Que debe colocarse en posición de recuperación',
          'Que solo necesita oxígeno por mascarilla',
        ],
        correctIndex: 1,
        explanation:
            'La respiración agónica (gasping/boqueadas) NO es respiración efectiva. Es un reflejo del tronco encefálico ante hipoxia severa y se considera signo de paro cardíaco. AHA 2020 indica que ante respiración agónica debe iniciarse RCP inmediatamente (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la relación compresiones-ventilaciones en RCP pediátrica con un solo reanimador?',
        options: [
          '30:2',
          '15:2',
          '20:2',
          '5:1',
        ],
        correctIndex: 0,
        explanation:
            'AHA 2020 unifica la relación para reanimadores no entrenados o únicos: 30:2 en TODAS las edades (adultos, niños y lactantes). Con dos reanimadores en pediatría se usa 15:2 para garantizar más ventilaciones dada la etiología respiratoria del paro pediátrico (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo debe aplicarse el DEA en un paro cardíaco pediátrico por ahogamiento?',
        options: [
          'Solo después de 10 minutos de RCP',
          'Tan pronto como esté disponible, minimizando interrupciones',
          'Solo si pesa >25 kg',
          'No debe usarse DEA en paros por ahogamiento',
        ],
        correctIndex: 1,
        explanation:
            'El DEA debe aplicarse tan pronto como esté disponible, con interrupción mínima de compresiones (<10 segundos). Se usa en niños ≥1 año con paro cardíaco extrahospitalario. No hay contraindicación por ahogamiento; solo secar el tórax antes de colocar parches (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué profundidad de compresiones torácicas se recomienda en una niña de 3 años?',
        options: [
          '2 cm',
          'Al menos 1/3 del diámetro anteroposterior del tórax (aproximadamente 5 cm)',
          '6 cm',
          '3 cm',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020 recomienda comprimir al menos 1/3 del diámetro anteroposterior del tórax. En niños pequeños esto equivale aproximadamente a 5 cm. En lactantes es aproximadamente 4 cm. Debe permitir reexpansión completa del tórax entre compresiones (AHA 2020).',
      ),
    ],
  ),

  // OVACE Adulto Inconsciente
  _EvalScenario(
    id: 'eval_ovace_adulto_inconsciente',
    title: 'OVACE en Adulto Inconsciente',
    subtitle: 'Manejo de obstrucción de vía aérea en inconsciente · AHA 2020',
    caseText:
        'Mujer de 60 años se atraganta mientras come en un restaurante. Inicialmente se lleva las manos al cuello, no puede hablar ni toser. Intentan compresiones abdominales (Heimlich) sin éxito. Pierde la conciencia y cae al suelo. Está inconsciente, no respira. Al abrir la vía aérea no se ve el objeto.',
    color: AppColors.blue,
    icon: Icons.air,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            'Ante una víctima inconsciente por OVACE, ¿cuál es la conducta inicial según AHA 2020?',
        options: [
          'Realizar barrido digital a ciegas',
          'Iniciar RCP comenzando con compresiones torácicas (30 compresiones)',
          'Dar golpes en la espalda con la víctima en el suelo',
          'Colocar en posición de recuperación',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020 indica que ante víctima inconsciente por OVACE se debe iniciar RCP. Las compresiones torácicas generan presión intratorácica que puede desalojar el objeto (similar a la maniobra de Heimlich). No debe hacerse barrido digital a ciegas (puede empujar el objeto más profundamente) (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cada cuándo debe revisarse la cavidad oral durante RCP por OVACE?',
        options: [
          'Cada 30 compresiones, al abrir vía aérea para las 2 ventilaciones',
          'Cada 2 minutos',
          'Solo al inicio',
          'Cada 5 compresiones',
        ],
        correctIndex: 0,
        explanation:
            'Cada vez que se abra la vía aérea para administrar las 2 ventilaciones (tras cada ciclo de 30 compresiones), debe inspeccionarse la cavidad oral. Si el objeto se ve, debe retirarse con los dedos (barrido digital solo si está visible). Si no se ve, continuar RCP (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuándo está indicado el barrido digital en OVACE?',
        options: [
          'Siempre al iniciar la reanimación',
          'Solo si el objeto es visible en la cavidad oral',
          'Cada ciclo de RCP, rutinariamente',
          'Nunca está indicado',
        ],
        correctIndex: 1,
        explanation:
            'El barrido digital a ciegas está contraindicado porque puede empujar el objeto más profundamente hacia la laringe o faringe, empeorando la obstrucción. Solo debe retirarse un objeto si es visible directamente al abrir la boca (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            'Si al ventilar el aire no pasa (no se eleva el tórax), ¿qué debe hacerse?',
        options: [
          'Reposicionar la cabeza (extensión del cuello/elevación del mentón) y reintentar ventilar',
          'Aumentar la fuerza de la ventilación bruscamente',
          'Suspender ventilación y solo dar compresiones',
          'Administrar compresiones abdominales con la víctima acostada',
        ],
        correctIndex: 0,
        explanation:
            'Si el aire no pasa al ventilar, primero debe reposicionarse la vía aérea (extensión de cabeza-elevación de mentón). Si aún así no pasa el aire, se continúa con compresiones torácicas que pueden ayudar a desalojar el objeto. No forzar ventilación contra obstrucción completa (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la principal diferencia en el manejo de OVACE entre víctima consciente e inconsciente?',
        options: [
          'En la inconsciente se usan compresiones torácicas (RCP); en la consciente se usan compresiones abdominales (Heimlich)',
          'En la inconsciente no se ventila; en la consciente sí',
          'En la inconsciente se usa oxígeno; en la consciente no',
          'No hay diferencia en el manejo',
        ],
        correctIndex: 0,
        explanation:
            'En la víctima consciente con OVACE se realizan compresiones abdominales (maniobra de Heimlich) y/o golpes interescapulares estando de pie. En la inconsciente se inicia RCP estándar (30 compresiones + 2 ventilaciones) porque las compresiones torácicas ejercen presión similar sobre el objeto al aumentar la presión intratorácica (AHA 2020).',
      ),
    ],
  ),

  // Electrocución Alto Voltaje
  _EvalScenario(
    id: 'eval_electrocucion_alto_voltaje',
    title: 'Electrocución de Alto Voltaje',
    subtitle: 'Quemaduras eléctricas y paro cardíaco · AHA 2020',
    caseText:
        'Electricista de 34 años sufre descarga eléctrica de alto voltaje (aproximadamente 13,000V) en subestación eléctrica. Es encontrado inconsciente, sin respuesta, sin respiración y sin pulso. Presenta quemadura de entrada en mano derecha y quemadura de salida en talón izquierdo. Ritmo en DEA: FV.',
    color: AppColors.orange,
    icon: Icons.bolt,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la primera prioridad al llegar a la escena de una electrocución de alto voltaje?',
        options: [
          'Iniciar RCP inmediatamente sin verificar la escena',
          'Verificar que la fuente de energía esté desconectada y aislada antes de acercarse',
          'Aplicar el DEA sin tocar a la víctima',
          'Cubrir las quemaduras con apósitos estériles',
        ],
        correctIndex: 1,
        explanation:
            'La seguridad de la escena es primordial. En alto voltaje (>1000V), el arco eléctrico puede saltar hasta 10 metros. Nunca debe tocarse a la víctima hasta confirmar que la fuente está desconectada. La corriente puede saltar por el aire o a través del suelo. Solo cuando sea seguro, iniciar RCP (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué tipo de daño interno es característico de la electrocución de alto voltaje?',
        options: [
          'Daño limitado a la superficie de la piel',
          'Daño tisular profundo desproporcionado a la lesión cutánea, con necrosis muscular y rabdomiólisis',
          'Solo daño neurológico transitorio',
          'Daño exclusivamente cardíaco',
        ],
        correctIndex: 1,
        explanation:
            'La corriente de alto voltaje genera calor intenso (efecto Joule) al pasar por tejidos de menor resistencia (vasos, nervios, músculo). Causa necrosis muscular profunda muy extensa, desproporcionada a la pequeña quemadura cutánea visible. Esto provoca rabdomiólisis masiva con riesgo de insuficiencia renal aguda y síndrome compartimental (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el manejo del ritmo FV en electrocución de alto voltaje?',
        options: [
          'No desfibrilar, el corazón está demasiado dañado',
          'Desfibrilación con DEA según algoritmo estándar: 1 descarga + 2 min RCP',
          'RCP continua sin desfibrilar hasta llegar al hospital',
          'Solo lidocaína IV sin desfibrilar',
        ],
        correctIndex: 1,
        explanation:
            'La FV por electrocución se trata con desfibrilación estándar según AHA 2020. El DEA debe aplicarse tan pronto como sea seguro. Se administra 1 descarga seguida de 2 minutos de RCP, igual que en cualquier otra FV. No hay modificación del algoritmo por la causa eléctrica (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué complicación musculoesquelética debe vigilarse activamente en las horas posteriores?',
        options: [
          'Síndrome compartimental que requiere fasciotomía',
          'Fractura expuesta de fémur',
          'Luxación de cadera',
          'Atrofia muscular irreversible inmediata',
        ],
        correctIndex: 0,
        explanation:
            'El edema muscular masivo post-electrocución dentro de las fascias cerradas de las extremidades causa síndrome compartimental. La presión intracompartimental aumenta por necrosis muscular y edema, comprometiendo la perfusión distal. Requiere fasciotomía urgente. Se debe medir presión intracompartimental si hay sospecha clínica (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué complicación renal por necrosis muscular requiere manejo agresivo?',
        options: [
          'Rabdomiólisis con insuficiencia renal aguda por mioglobinuria',
          'Insuficiencia hepática fulminante',
          'Pancreatitis necrohemorrágica',
          'Insuficiencia suprarrenal',
        ],
        correctIndex: 0,
        explanation:
            'La necrosis muscular masiva libera mioglobina que precipita en los túbulos renales causando insuficiencia renal aguda. Requiere hidratación agresiva (mantener gasto urinario >100 mL/h), bicarbonato para alcalinizar orina (pH >6.5) para prevenir precipitación de mioglobina, y posiblemente hemodiálisis si falla (AHA 2020).',
      ),
    ],
  ),

  // Sobredosis de Benzodiacepinas
  _EvalScenario(
    id: 'eval_sobredosis_benzodiacepinas',
    title: 'Sobredosis de Benzodiacepinas',
    subtitle: 'Depresión respiratoria por BDZ · AHA 2020',
    caseText:
        'Hombre de 45 años encontrado con somnolencia profunda y frascos vacíos de alprazolam 2 mg. FR 6 rpm, SatO2 82%, pupilas puntiformes, GCS 8 (responde solo al dolor). Glucemia capilar normal. PA 110/70, FC 95 lpm.',
    color: AppColors.accent,
    icon: Icons.medication_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la primera intervención en la sobredosis por benzodiacepinas?',
        options: [
          'Administrar flumazenilo IV inmediatamente',
          'Asegurar vía aérea, ventilar con bolsa-mascarilla y administrar oxígeno',
          'Realizar lavado gástrico',
          'Administrar carbón activado oral',
        ],
        correctIndex: 1,
        explanation:
            'La prioridad absoluta es el manejo de la vía aérea y la ventilación. La depresión respiratoria es la causa de muerte evitable. Se debe administrar O2, ventilar con bolsa-mascarilla si FR <10 o SatO2 <90%, y considerar intubación si el paciente no protege la vía aérea. El flumazenilo no reemplaza la ventilación (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo está indicado administrar flumazenilo en sobredosis por BDZ?',
        options: [
          'En todos los pacientes con sospecha de sobredosis por BDZ',
          'Solo en depresión respiratoria severa y preferiblemente en pacientes sin dependencia crónica conocida',
          'Nunca está indicado por riesgo de convulsiones',
          'Solo en pacientes pediátricos',
        ],
        correctIndex: 1,
        explanation:
            'El flumazenilo está indicado en depresión respiratoria severa por sobredosis confirmada de BDZ, pero con precaución. En pacientes con dependencia crónica puede precipitar convulsiones refractarias. No es tratamiento de primera línea; la prioridad es la ventilación. La co-ingesta de antidepresivos tricíclicos aumenta el riesgo de convulsiones por flumazenilo (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Por qué debe evitarse el uso rutinario de flumazenilo?',
        options: [
          'Porque es caro y difícil de conseguir',
          'Porque puede inducir convulsiones, especialmente con dependencia crónica o co-ingesta de proconvulsivantes',
          'Porque su vida media es más larga que las BDZ',
          'Porque solo revierte efectos ansiolíticos, no sedantes',
        ],
        correctIndex: 1,
        explanation:
            'El flumazenilo puede precipitar convulsiones refractarias al tratamiento en pacientes con dependencia crónica a BDZ, co-ingesta de proconvulsivantes (ATC, cocaína) o epilepsia conocida. Las convulsiones pueden ser prolongadas y difíciles de controlar. Además, en intoxicación mixta, flumazenilo puede dejar al paciente expuesto a los efectos de otros fármacos (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué examen complementario es más útil para descartar co-ingesta en sobredosis por BDZ?',
        options: [
          'Radiografía de tórax',
          'Electrocardiograma (ECG)',
          'Tomografía de cráneo',
          'Ecografía abdominal',
        ],
        correctIndex: 1,
        explanation:
            'El ECG es fundamental para descartar co-ingesta de fármacos que prolongan el QTc (antidepresivos tricíclicos, antipsicóticos) o causan toxicidad cardíaca. La co-ingesta es frecuente en intentos de autólisis y cambia significativamente el manejo. Un QRS ancho puede indicar co-ingesta de ATC que requiere bicarbonato y contraindica flumazenilo (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo está indicada la intubación orotraqueal en la sobredosis por BDZ?',
        options: [
          'GCS <8 es indicación absoluta de intubación',
          'Incapacidad para mantener vía aérea permeable o protegerla de aspiración a pesar de medidas no invasivas',
          'Pupilas puntiformes',
          'Frecuencia cardíaca >100 lpm',
        ],
        correctIndex: 1,
        explanation:
            'La decisión de intubar se basa en la capacidad del paciente para mantener y proteger la vía aérea. Si con medidas no invasivas (posición, cánula orofaríngea, aspiración) el paciente mantiene SatO2 >90% y vía aérea permeable, puede manejarse sin intubación con monitorización estrecha. La intubación está indicada si fracasan las medidas no invasivas o hay riesgo de aspiración (AHA 2020).',
      ),
    ],
  ),

  // Sobredosis de Cocaína
  _EvalScenario(
    id: 'eval_sobredosis_cocaina',
    title: 'Sobredosis de Cocaína',
    subtitle: 'Síndrome coronario agudo por cocaína · AHA 2020',
    caseText:
        'Hombre de 32 años llega a emergencias con dolor torácico opresivo de inicio súbito, disnea, sudoración y palpitaciones. Está agitado, PA 190/110 mmHg, FC 140 lpm, SatO2 94%. ECG: taquicardia sinusal con supradesnivel ST en V1-V4. Admite consumo de cocaína inhalada hace 1 hora.',
    color: AppColors.accent,
    icon: Icons.medication_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es el tratamiento de primera línea para el dolor torácico por toxicidad por cocaína?',
        options: [
          'Betabloqueantes (propranolol) para reducir FC y consumo de O2',
          'Benzodiacepinas (diazepam/lorazepam) más nitroglicerina',
          'Lidocaína IV como antiarrítmico de primera línea',
          'Bloqueantes de canales de calcio en monoterapia',
        ],
        correctIndex: 1,
        explanation:
            'Las benzodiacepinas reducen la toxicidad simpática del SNC y disminuyen FC y PA. La nitroglicerina produce vasodilatación coronaria. La combinación es el tratamiento de primera línea para SCA asociado a cocaína según AHA 2020. Las benzodiacepinas también tratan la agitación y previenen convulsiones (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué están contraindicados los betabloqueantes en la toxicidad por cocaína?',
        options: [
          'Porque aumentan la PA por vasoconstricción periférica',
          'Porque causan vasoconstricción coronaria no antagonizada al bloquear receptores beta-2, empeorando la isquemia',
          'Porque causan bradicardia severa',
          'Porque interfieren con el metabolismo hepático de la cocaína',
        ],
        correctIndex: 1,
        explanation:
            'Los betabloqueantes no selectivos bloquean receptores beta-2 (vasodilatadores coronarios), dejando la estimulación alfa-1 adrenérgica por cocaína no antagonizada. Esto produce vasoconstricción coronaria exacerbada que puede empeorar la isquemia e incluso causar muerte. Están formalmente contraindicados (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            'En IAM por cocaína, ¿cuál es la estrategia de reperfusión recomendada?',
        options: [
          'Fibrinólisis inmediata como primera opción',
          'ICP primaria si está disponible en <90 minutos',
          'No reperfundir, manejo médico exclusivo',
          'Solo aspirina y observación',
        ],
        correctIndex: 1,
        explanation:
            'AHA 2020 recomienda ICP primaria como estrategia de reperfusión en SCA por cocaína. La fibrinólisis es menos efectiva en estos pacientes (mayor riesgo de complicaciones hemorrágicas, menor efectividad por el estado protrombótico inducido por cocaína). Si no hay ICP disponible, se puede considerar fibrinólisis en casos seleccionados (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el antiarrítmico de elección para taquiarritmias por toxicidad por cocaína?',
        options: [
          'Amiodarona',
          'Lidocaína',
          'Adenosina',
          'Bicarbonato de sodio',
        ],
        correctIndex: 0,
        explanation:
            'La amiodarona es el antiarrítmico más seguro en toxicidad por cocaína (bloquea canales de potasio sin afectar canales de sodio significativamente). La lidocaína tiene potencial proconvulsivante en estos pacientes y su uso es controvertido. La adenosina solo es útil en taquicardias supraventriculares (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué tratamiento específico se recomienda para la hipertensión severa por intoxicación por cocaína?',
        options: [
          'Betabloqueantes IV como esmolol',
          'Vasodilatadores: nitroprusiato o fentolamina (alfa-bloqueante)',
          'Diuréticos de asa IV',
          'IECA sublingual',
        ],
        correctIndex: 1,
        explanation:
            'La fentolamina es un alfa-bloqueante que antagoniza directamente los efectos simpáticos de la cocaína. El nitroprusiato es otra opción. Ambos reducen la poscarga y mejoran la isquemia miocárdica sin los riesgos de los betabloqueantes. Las benzodiacepinas también ayudan a reducir la presión al disminuir la descarga simpática central (AHA 2020).',
      ),
    ],
  ),

  // IAM con Edema Pulmonar
  _EvalScenario(
    id: 'eval_infarto_edema_pulmonar',
    title: 'IAM con Edema Pulmonar',
    subtitle:
        'IAM complicado con insuficiencia cardíaca aguda Killip III · AHA 2020',
    caseText:
        'Hombre de 65 años, fumador, hipertenso, con dolor torácico opresivo de 2 horas irradiado a brazo izquierdo. Está severamente disneico, ortopneico, con expectoración rosada espumosa. PA 160/95, FC 110, FR 32, SatO2 82%. Crepitantes bibasales hasta campos medios. ECG: supradesnivel ST en V1-V6.',
    color: AppColors.red,
    icon: Icons.favorite_border,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la intervención inicial más importante en IAM con edema pulmonar agudo?',
        options: [
          'MONA: morfina, oxígeno, nitratos, aspirina',
          'Ventilación no invasiva (CPAP/BiPAP) más nitratos intravenosos',
          'Intubación orotraqueal inmediata',
          'Fibrinólisis intravenosa de primera línea',
        ],
        correctIndex: 1,
        explanation:
            'La prioridad es corregir la hipoxemia severa. La CPAP mejora oxigenación, reduce trabajo respiratorio y disminuye la precarga. Los nitratos IV reducen precarga y mejoran isquemia. Esta combinación es la primera línea en IAM con edema pulmonar (Killip III). La intubación se reserva si fracasa VNI (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es la estrategia de reperfusión en IAM anterior extenso con edema pulmonar?',
        options: [
          'Fibrinólisis inmediata por ser más rápida',
          'ICP primaria de emergencia con soporte ventilatorio durante el procedimiento',
          'Manejo médico exclusivo hasta estabilizar edema',
          'Cirugía de revascularización urgente',
        ],
        correctIndex: 1,
        explanation:
            'La ICP primaria es la estrategia de elección. Aunque la fibrinólisis es más rápida de administrar, la ICP ofrece mejores resultados en Killip III-IV. El soporte ventilatorio (VNI o IOT) debe iniciarse antes y mantenerse durante el procedimiento. No debe demorarse la ICP por "estabilizar" al paciente: el edema pulmonar es una indicación de ICP urgente (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué fármaco debe usarse con precaución en el edema pulmonar por IAM?',
        options: [
          'Nitroglicerina IV',
          'Furosemida IV',
          'Morfina IV en dosis altas',
          'Oxígeno suplementario',
        ],
        correctIndex: 2,
        explanation:
            'La morfina en dosis altas puede causar depresión respiratoria, hipotensión y vasodilatación excesiva. Aunque alivia la disnea y la ansiedad, debe usarse en dosis bajas (2-4 mg) con precaución. Estudios observacionales han asociado el uso rutinario de morfina con peor pronóstico en IAM. Los nitratos y furosemida son seguros y efectivos (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué clasificación Killip corresponde a este paciente con edema pulmonar agudo?',
        options: [
          'Killip I: sin signos de IC',
          'Killip II: crepitantes, galope S3, ingurgitación yugular',
          'Killip III: edema pulmonar agudo franco',
          'Killip IV: shock cardiogénico',
        ],
        correctIndex: 2,
        explanation:
            'Killip III se define por edema pulmonar agudo con crepitantes >50% de campos pulmonares y disnea severa. Killip II tiene crepitantes limitados, galope S3 o ingurgitación yugular leve. Killip IV es shock cardiogénico. La clasificación Killip tiene valor pronóstico: mortalidad Killip I ~6%, Killip III ~40% (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo está indicado el balón de contrapulsación intraaórtico (BCIAo) en este contexto?',
        options: [
          'En todos los pacientes IAM con edema pulmonar de rutina',
          'Si persiste inestabilidad hemodinámica a pesar de ICP y soporte médico óptimo',
          'Solo si hay insuficiencia mitral severa',
          'Contraindicado en edema pulmonar',
        ],
        correctIndex: 1,
        explanation:
            'El BCIAo está indicado como soporte hemodinámico en shock cardiogénico o edema pulmonar refractario al tratamiento médico y a la revascularización. Mejora perfusión coronaria diastólica y reduce poscarga. No se usa de rutina (ensayos no mostraron beneficio en mortalidad en todos los pacientes con IAM complicado) (AHA 2020).',
      ),
    ],
  ),

  // IAM Inferior con BAV
  _EvalScenario(
    id: 'eval_infarto_inferior_bav',
    title: 'IAM Inferior con Bloqueo AV',
    subtitle: 'IAM inferior complicado con BAV completo · AHA 2020',
    caseText:
        'Hombre de 55 años, hipertenso y diabético, con dolor epigástrico y torácico de 3 horas, náuseas y diaforesis. PA 85/50 mmHg, FC 40 lpm, SatO2 94%. ECG: supradesnivel ST en II, III, aVF con BAV completo (tercer grado) con ritmo de escape ventricular a 38 lpm. Paciente somnoliento con piel fría.',
    color: AppColors.red,
    icon: Icons.favorite_border,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la primera intervención en IAM inferior con BAV completo e hipotensión?',
        options: [
          'Administrar atropina 0.5 mg IV y preparar para marcapasos transcutáneo',
          'Iniciar dobutamina a dosis altas',
          'Colocar en Trendelenburg y dar 500 mL cristaloides',
          'Administrar adenosina para evaluar el bloqueo',
        ],
        correctIndex: 0,
        explanation:
            'La atropina (0.5 mg IV cada 3-5 min, máx 3 mg) puede aumentar la frecuencia del nodo AV en bloqueos infranodales y es el tratamiento de primera línea. Si no hay respuesta o hay inestabilidad hemodinámica, iniciar marcapasos transcutáneo. La atropina suele ser efectiva en IAM inferior porque la isquemia del nodo AV suele ser reversible al reperfundir la CD (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué el IAM inferior se complica más con BAV que el anterior?',
        options: [
          'Porque la arteria coronaria derecha irriga el nodo AV en ~85-90% de las personas',
          'Porque el IAM inferior es siempre más extenso',
          'Porque el VI tiene más receptores colinérgicos',
          'Porque libera más potasio',
        ],
        correctIndex: 0,
        explanation:
            'En el 85-90% de las personas, la arteria coronaria derecha (CD) irriga el nodo AV a través de la rama del nodo AV. La oclusión proximal de la CD causa isquemia del nodo AV, produciendo bloqueos AV. En el IAM anterior, el BAV suele ser por daño extenso del sistema de Purkinje y tiene peor pronóstico (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            'Si el marcapasos transcutáneo no logra captura, ¿cuál es el siguiente paso?',
        options: [
          'Duplicar atropina hasta 3 mg total',
          'Colocar marcapasos venoso transvenoso urgente guiado por ecografía o fluoroscopia',
          'Administrar isoproterenol en perfusión',
          'Cardioversión eléctrica sincronizada',
        ],
        correctIndex: 1,
        explanation:
            'El marcapasos transvenoso es el método más fiable de estimulación cardíaca urgente. Si el transcutáneo no captura (especialmente en tórax grande, enfisema, obesidad o derrame pericárdico), debe colocarse un marcapasos transvenoso lo antes posible. Idealmente guiado por ecografía o fluoroscopia (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el manejo definitivo de este paciente con IAM inferior y BAV?',
        options: [
          'Manejo médico exclusivo, el BAV es transitorio',
          'ICP primaria urgente de la arteria culpable (generalmente la CD)',
          'Cirugía de revascularización urgente',
          'Marcapasos definitivo permanente antes de cualquier intervención',
        ],
        correctIndex: 1,
        explanation:
            'La ICP primaria urgente es el tratamiento definitivo. La reperfusión precoz de la arteria culpable (generalmente la CD) permite recuperar la función del nodo AV. El BAV por IAM inferior suele ser transitorio y no requiere marcapasos permanente si se logra reperfusión exitosa. El marcapasos permanente se considera si persiste BAV >7 días post-IAM (AHA 2020).',
      ),
      _EvalQuestion(
        question:
            '¿Qué debe sospecharse si el IAM inferior cursa con hipotensión refractaria y distensión yugular?',
        options: [
          'Taponamiento cardíaco',
          'Infarto de ventrículo derecho asociado',
          'Embolia pulmonar masiva',
          'Disección aórtica',
        ],
        correctIndex: 1,
        explanation:
            'El infarto de VD es una complicación frecuente del IAM inferior (oclusión proximal de la CD antes de la rama marginal derecha). Cursa con hipotensión, distensión yugular (PVC elevada) y campos pulmonares limpios. El tratamiento incluye carga de volumen y evitar vasodilatadores como nitratos. Las derivaciones derechas (V4R) confirman el diagnóstico (AHA 2020).',
      ),
    ],
  ),
  // Hipotermia Neonatal
  _EvalScenario(
    id: 'eval_hipotermia_neonatal',
    title: 'Hipotermia Neonatal',
    subtitle: 'Recién nacido con hipotermia · OMS 2023',
    caseText:
        'Recién nacido a término, parto domiciliario no planificado. Temperatura axilar 34.2°C, letargo, succión débil, llanto débil. Peso 3200g, APGAR 7/9 al nacer.',
    color: AppColors.green,
    icon: Icons.child_care_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la primera intervención en hipotermia neonatal moderada?',
        options: [
          'Contacto piel a piel con la madre y ambiente cálido',
          'Baño con agua tibia para recalentar rápidamente',
          'Administrar antibióticos de amplio espectro empíricos',
          'Colocar al recién nacido en incubadora a 40°C',
        ],
        correctIndex: 0,
        explanation:
            'El contacto piel a piel (método canguro) es la intervención inicial recomendada para hipotermia neonatal leve a moderada. Proporciona calor por conducción directa, estabiliza la frecuencia cardíaca y promueve el vínculo madre-hijo. La OMS lo recomienda como primera línea antes de la incubadora.',
      ),
      _EvalQuestion(
        question:
            '¿Qué velocidad de recalentamiento es la adecuada en hipotermia neonatal?',
        options: [
          'Recalentamiento rápido a 1°C cada 10 minutos',
          'Recalentamiento gradual a 0.5°C por hora',
          'No recalentar activamente, dejar que el bebé se caliente solo',
          'Recalentamiento ultrarrápido con lámpara infrarroja',
        ],
        correctIndex: 1,
        explanation:
            'El recalentamiento debe ser GRADUAL (0.5°C por hora) para evitar complicaciones como apnea, arritmias, hipotensión y acidosis metabólica por vasodilatación súbita. El recalentamiento rápido puede causar shunting de sangre fría periférica al centro (afterdrop). La OMS recomienda incubadora precalentada con temperatura controlada.',
      ),
      _EvalQuestion(
        question:
            '¿A partir de qué temperatura axilar se clasifica hipotermia neonatal severa?',
        options: [
          '<36.5°C',
          '<34.0°C',
          '<35.5°C',
          '<33.0°C',
        ],
        correctIndex: 1,
        explanation:
            'Clasificación OMS de hipotermia neonatal: Estrés por frío (36.0-36.4°C), Hipotermia moderada (34.0-35.9°C), Hipotermia SEVERA (<34.0°C). La hipotermia severa requiere manejo en unidad neonatal con incubadora, monitoreo continuo, recalentamiento gradual controlado y evaluación de complicaciones (hipoglucemia, acidosis, coagulopatía).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál de las siguientes prácticas NO está recomendada en hipotermia neonatal?',
        options: [
          'Secar al bebé inmediatamente después del nacimiento y cubrirlo con gorro',
          'Bañar al bebé en agua tibia para estimular la circulación periférica',
          'Contacto piel a piel con la madre en posición canguro',
          'Colocar al bebé en incubadora precalentada a 36-37°C',
        ],
        correctIndex: 1,
        explanation:
            'NO se recomienda bañar al recién nacido hipotérmico. El baño puede empeorar la pérdida de calor por evaporación al retirar al bebé del agua, y el agua tibia mal regulada puede causar quemaduras en piel neonatal sensible. Las medidas correctas incluyen secado inmediato, gorro, contacto piel a piel e incubadora precalentada (OMS 2023).',
      ),
    ],
  ),

  // Hemorragia por TCE
  _EvalScenario(
    id: 'eval_hemorragia_tce',
    title: 'Hemorragia por TCE',
    subtitle: 'Trauma craneoencefálico severo · ATLS 2023',
    caseText:
        'Hombre de 28 años, accidente en motocicleta sin casco. GCS 8, pupilas anisocóricas (derecha 4mm, izquierda 2mm). TAC muestra hematoma subdural agudo con efecto de masa y desviación de línea media.',
    color: AppColors.red,
    icon: Icons.medical_services_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la primera prioridad en el manejo de este paciente?',
        options: [
          'Asegurar vía aérea y ventilación (intubación orotraqueal)',
          'Administrar manitol al 20% IV en bolo',
          'Solicitar TAC de cráneo urgente',
          'Colocar drenaje ventricular externo',
        ],
        correctIndex: 0,
        explanation:
            'La prioridad es A-B-C: asegurar vía aérea con intubación orotraqueal. GCS ≤8 es indicación de intubación para proteger la vía aérea y mantener PaCO2 en 35-40 mmHg. La hiperventilación profiláctica está contraindicada porque reduce el flujo sanguíneo cerebral. Mantener PAM >80 mmHg para perfusión cerebral (ATLS 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué medida está indicada para controlar la hipertensión intracraneana?',
        options: [
          'Hiperventilación agresiva con PaCO2 <30 mmHg',
          'Manitol 0.25-1 g/kg IV en bolo y elevación de cabecera a 30°',
          'Dexametasona 10 mg IV cada 6 horas',
          'Hipotensión controlada con PAM <60 mmHg',
        ],
        correctIndex: 1,
        explanation:
            'Manitol IV (0.25-1 g/kg) reduce la PIC por efecto osmótico. La elevación de la cabecera a 30° favorece el retorno venoso cerebral. La hiperventilación agresiva se reserva para deterioro agudo por herniación por tiempo limitado. Los corticosteroides NO están indicados en TCE (aumentan mortalidad). Mantener PAM >80 mmHg (ATLS 2023).',
      ),
      _EvalQuestion(
        question: '¿Qué hallazgo sugiere hernia cerebral inminente?',
        options: [
          'Pupila derecha dilatada y no reactiva con deterioro neurológico',
          'GCS estable en 10',
          'Reflejo corneal presente bilateralmente',
          'Movimiento ocular espontáneo y simétrico',
        ],
        correctIndex: 0,
        explanation:
            'La pupila dilatada y no reactiva unilateral (anisocoria) con deterioro del nivel de conciencia es signo clásico de hernia del uncus del lóbulo temporal que comprime el III par craneal (oculomotor). Esto constituye una emergencia quirúrgica que requiere craniectomía descompresiva urgente (ATLS/BTF 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo está indicada la craneotomía evacuadora urgente en hematoma subdural?',
        options: [
          'Hematoma subdural >10 mm de espesor o desviación de línea media >5 mm',
          'Siempre que haya sangrado intracraneal visible en la TAC',
          'Solo si el paciente tiene GCS <12 al ingreso',
          'Después de 48 horas de manejo médico sin mejoría',
        ],
        correctIndex: 0,
        explanation:
            'Indicaciones quirúrgicas para hematoma subdural agudo: espesor >10 mm o desviación de línea media >5 mm en TAC, independientemente del GCS. También si hay deterioro neurológico o PIC refractaria al tratamiento médico. La craniectomía descompresiva se considera cuando la PIC no se controla médicamente (ATLS/BTF 2023).',
      ),
    ],
  ),

  // Hemorragia Postparto
  _EvalScenario(
    id: 'eval_hemorragia_postparto',
    title: 'Hemorragia Postparto',
    subtitle: 'Sangrado postparto severo · FIGO 2023',
    caseText:
        'Mujer de 32 años, primigesta, parto vaginal con desgarro perineal. Sangrado vaginal abundante (>1000ml), útero atónico a la palpación, taquicardia 120 lpm, PA 85/50.',
    color: AppColors.red,
    icon: Icons.bloodtype_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la primera intervención mecánica para la atonía uterina?',
        options: [
          'Masaje uterino bimanual y administración de oxitocina IV',
          'Colocar balón de taponamiento intrauterino',
          'Realizar ligadura de arterias uterinas',
          'Administrar ácido tranexámico 1g IV',
        ],
        correctIndex: 0,
        explanation:
            'El masaje uterino bimanual y la oxitocina son las primeras intervenciones en atonía uterina. El masaje estimula la contracción miometrial. La oxitocina (10 UI IM o 20-40 UI en infusión IV) es el fármaco de primera línea. El ácido tranexámico es coadyuvante, no primera línea (FIGO 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo está indicado el ácido tranexámico en hemorragia postparto?',
        options: [
          'Solo si la hemorragia no responde a oxitocina y masaje',
          'Administrar lo antes posible, idealmente dentro de las primeras 3 horas del sangrado',
          'Únicamente si se requiere transfusión sanguínea',
          'No está indicado en hemorragia postparto',
        ],
        correctIndex: 1,
        explanation:
            'El ácido tranexámico (1g IV en 10 min, repetir a los 30 min si persiste sangrado) debe administrarse lo antes posible dentro de las 3 horas del inicio de la hemorragia postparto (estudio WOMAN). Reduce mortalidad por sangrado sin aumentar eventos tromboembólicos. No esperar a que fallen otras medidas (FIGO 2023).',
      ),
      _EvalQuestion(
        question: '¿Qué hallazgo es el más específico de atonía uterina?',
        options: [
          'Útero blando, no contraído ("blando como masa") que no responde al masaje',
          'Sangrado vaginal con coágulos oscuros y mal olor',
          'Dolor abdominal tipo cólico intenso y continuo',
          'Hipotensión y taquicardia severas desde el inicio',
        ],
        correctIndex: 0,
        explanation:
            'El hallazgo clásico de atonía uterina es un útero blando, no contraído ("boggy uterus") que no se endurece al masaje. La atonía es la causa más frecuente de hemorragia postparto (70-80%). El sangrado suele ser intermitente con coágulos. El útero normal postparto debe palparse firme a nivel del ombligo (FIGO 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el siguiente fármaco si la oxitocina no controla el sangrado?',
        options: [
          'Metilergonovina 0.2 mg IM (si no hay HTA) o misoprostol 800-1000 mcg SL/PR',
          'Carboprost (PGF2α) 250 mcg IM cada 15 min como primera elección',
          'Sulfato de magnesio 4g IV en bolo para contraer el útero',
          'Heparina sódica 5000 UI IV para prevenir coagulación intravascular diseminada',
        ],
        correctIndex: 0,
        explanation:
            'La metilergonovina (0.2 mg IM) es el segundo fármaco, contraindicada en HTA/preeclampsia. El misoprostol (800-1000 mcg sublingual o rectal) es alternativa segura si hay HTA o asma. El carboprost (PGF2α) se usa si persiste sangrado, pero está contraindicado en asma. El sulfato de magnesio NO es útero-tónico (FIGO 2023).',
      ),
    ],
  ),

  // Anafilaxia por Picadura
  _EvalScenario(
    id: 'eval_anafilaxia_picadura',
    title: 'Anafilaxia por Picadura',
    subtitle: 'Reacción alérgica severa por himenóptero · WAO 2023',
    caseText:
        'Hombre de 45 años, picadura de abeja en brazo izquierdo. 10 minutos después: urticaria generalizada, edema facial, estridor, disnea severa, PA 70/40.',
    color: AppColors.orange,
    icon: Icons.bug_report_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es el tratamiento de primera línea en anafilaxia con hipotensión?',
        options: [
          'Epinefrina IM 0.3-0.5 mg (1:1000) en cara anterolateral del muslo',
          'Epinefrina IV 1 mg en bolo directo',
          'Difenhidramina 50 mg IV en bolo',
          'Metilprednisolona 125 mg IV',
        ],
        correctIndex: 0,
        explanation:
            'La epinefrina IM (0.3-0.5 mg, 1:1000) en el vasto lateral del muslo es el tratamiento de PRIMERA LÍNEA. La vía IM es más segura que IV (menor riesgo de arritmias e isquemia miocárdica). Los antihistamínicos y corticosteroides son de segunda línea y no revierten la obstrucción de la vía aérea ni la hipotensión (WAO 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Por qué la epinefrina IM en el muslo es superior a la vía subcutánea?',
        options: [
          'La absorción IM en el muslo es más rápida y alcanza mayores concentraciones plasmáticas',
          'Es menos dolorosa y más aceptada por los pacientes',
          'El muslo tiene menos terminaciones nerviosas que el brazo',
          'La epinefrina solo funciona administrada por vía intramuscular',
        ],
        correctIndex: 0,
        explanation:
            'La absorción IM en el vasto lateral del muslo es significativamente más rápida que la SC, alcanzando concentraciones plasmáticas pico más altas en menor tiempo. Esto es crítico en anafilaxia donde la perfusión tisular está comprometida por hipotensión y vasodilatación. El muslo tiene mayor flujo sanguíneo que el brazo en reposo (WAO 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué antihistamínico se administra como coadyuvante en anafilaxia aguda?',
        options: [
          'Clorfenamina 10 mg IV o difenhidramina 25-50 mg IM/IV lento',
          'Loratadina 10 mg por vía oral',
          'Cetirizina 10 mg por vía oral',
          'Fexofenadina 180 mg por vía oral',
        ],
        correctIndex: 0,
        explanation:
            'Los antihistamínicos H1 intravenosos (clorfenamina 10 mg IV, difenhidramina 25-50 mg IM/IV) se administran como COADYUVANTES después de la epinefrina para aliviar urticaria y prurito. Son de segunda línea, nunca reemplazan a la epinefrina. Los antihistamínicos orales no son apropiados en la fase aguda (WAO 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el tiempo mínimo de observación tras una reacción anafiláctica por picadura?',
        options: [
          'Mínimo 6-8 horas por riesgo de reacción bifásica',
          '30 minutos si el paciente responde bien al tratamiento inicial',
          '24 horas en unidad de cuidados intensivos obligatoriamente',
          '2 horas y alta si los síntomas han desaparecido completamente',
        ],
        correctIndex: 0,
        explanation:
            'Se recomienda observación por 6-8 horas (mínimo 4-6 horas) por el riesgo de REACCIÓN BIFÁSICA (1-20% de los casos), donde los síntomas reaparecen 1-8 horas después de la resolución inicial. Las reacciones bifásicas pueden ser tan severas como la inicial. Los pacientes con asma o reacciones severas tienen mayor riesgo (WAO 2023).',
      ),
    ],
  ),

  // Anafilaxia por Alimento
  _EvalScenario(
    id: 'eval_anafilaxia_alimento',
    title: 'Anafilaxia por Alimento',
    subtitle: 'Reacción alérgica alimentaria severa · WAO 2023',
    caseText:
        'Mujer de 22 años, 15 minutos después de comer maní. Urticaria generalizada, angioedema facial y lingual, sibilancias, disnea, PA 85/50. Antecedentes de alergia al maní conocida.',
    color: AppColors.orange,
    icon: Icons.restaurant_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es el dispositivo de elección para administrar epinefrina en esta paciente?',
        options: [
          'Auto-inyector de epinefrina 0.3 mg IM en el vasto lateral del muslo',
          'Ampolla de epinefrina 1:1000 con jeringa y aguja convencional',
          'Epinefrina nebulizada en mascarilla',
          'Auto-inyector de epinefrina en el músculo deltoides',
        ],
        correctIndex: 0,
        explanation:
            'El auto-inyector de epinefrina (0.3 mg para adultos, 0.15 mg para <25 kg) en el muslo es el dispositivo de elección. Permite dosificación precisa y administración rápida incluso por personal no sanitario. NO se administra en deltoides (mayor riesgo de inyección intravascular accidental). La dosis IM es 0.3 mg (1:1000) (WAO 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué caracteriza a la reacción anafiláctica bifásica por alimentos?',
        options: [
          'Síntomas que reaparecen 1-8 horas tras la resolución inicial, sin nueva exposición al alérgeno',
          'Síntomas que aparecen exclusivamente después de 24 horas del contacto',
          'Reacción alérgica que solo se desencadena si hay ejercicio posterior',
          'Síntomas que duran menos de 30 minutos y desaparecen sin tratamiento',
        ],
        correctIndex: 0,
        explanation:
            'Reacción bifásica: reaparición de síntomas de anafilaxis 1-8 horas después de la resolución completa de la reacción inicial, sin nueva exposición al alérgeno. Ocurre en 1-20% de casos. Las reacciones por alimentos tienen mayor riesgo de bifásica. Por esto se recomienda observación prolongada y prescripción de auto-inyector al alta (WAO 2023).',
      ),
      _EvalQuestion(
        question: '¿Qué debe recibir la paciente al alta?',
        options: [
          'Prescripción de auto-inyector de epinefrina con entrenamiento y plan de acción escrito',
          'Solo antihistamínicos orales para tomar según necesidad',
          'Indicación de evitar frutos secos sin necesidad de más seguimiento',
          'Corticoides orales por 7 días sin necesidad de auto-inyector',
        ],
        correctIndex: 0,
        explanation:
            'Todo paciente con anafilaxia debe recibir al alta: 1) Prescripción de auto-inyector de epinefrina con entrenamiento demostrado, 2) Plan de acción escrito y personalizado, 3) Derivación a alergología para estudio (IgE específica, pruebas cutáneas, reto oral si aplica), 4) Educación sobre evitación del alérgeno y reconocimiento de síntomas (WAO 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué factor aumenta el riesgo de anafilaxia severa por alimentos?',
        options: [
          'Asma mal controlada, ejercicio concomitante, consumo de alcohol o AINEs',
          'Edad mayor de 60 años exclusivamente',
          'Sexo masculino sin otros factores',
          'Haber tenido pruebas cutáneas positivas en el pasado',
        ],
        correctIndex: 0,
        explanation:
            'El asma bronquial mal controlada es el factor de riesgo más importante para anafilaxia severa fatal por alimentos. Otros cofactores: ejercicio, alcohol, AINEs, infecciones agudas, estrés emocional y menstruación. Estos factores disminuyen el umbral de activación de mastocitos y basófilos, aumentando la severidad de la reacción (WAO 2023).',
      ),
    ],
  ),

  // Status Epiléptico
  _EvalScenario(
    id: 'eval_convulsion_status',
    title: 'Status Epiléptico',
    subtitle: 'Convulsión continua y prolongada · ILAE 2023',
    caseText:
        'Hombre de 35 años con antecedentes de epilepsia focal, traído por familiares por convulsión tónico-clónica generalizada que no cede. Duración estimada >8 minutos.',
    color: AppColors.brand,
    icon: Icons.flash_on_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es el fármaco de primera línea en status epiléptico establecido (>5 min)?',
        options: [
          'Benzodiacepina: diazepam 0.2 mg/kg IV/rectal o lorazepam 0.1 mg/kg IV',
          'Fenitoína 20 mg/kg IV en carga',
          'Ácido valproico 30 mg/kg IV',
          'Propofol 2 mg/kg IV en bolo',
        ],
        correctIndex: 0,
        explanation:
            'Las benzodiacepinas (diazepam 0.2 mg/kg IV/rectal, lorazepam 0.1 mg/kg IV, midazolam 0.2 mg/kg IM o intranasal) son la PRIMERA LÍNEA en status epiléptico. Deben administrarse dentro de los primeros 5 minutos de convulsión continua. La vía intravenosa es preferible si hay acceso venoso (ILAE 2023).',
      ),
      _EvalQuestion(
        question:
            'Si la convulsión persiste tras la primera dosis de benzodiacepina, ¿qué se hace?',
        options: [
          'Repetir benzodiacepina en 5 minutos; si persiste, iniciar fenitoína o levetiracetam IV',
          'Intubar inmediatamente y administrar tiopental sódico',
          'Administrar sulfato de magnesio 4g IV en bolo',
          'Esperar 20 minutos antes de decidir el siguiente paso',
        ],
        correctIndex: 0,
        explanation:
            'Si persiste a los 5 minutos: repetir segunda dosis de benzodiacepina. Si continúa (status establecido, >10 min), administrar antiepiléptico de segunda línea: fenitoína (20 mg/kg IV), levetiracetam (60 mg/kg IV) o ácido valproico (40 mg/kg IV). La elección depende de disponibilidad y comorbilidades (ILAE 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo se considera status epiléptico refractario y qué se administra?',
        options: [
          'Persistencia >30 min pese a benzodiacepinas y un antiepiléptico: anestésicos IV (propofol, midazolam, barbitúricos)',
          'Persistencia >60 min: repetir dosis de benzodiacepinas indefinidamente',
          'Si no responde a 4 dosis de benzodiacepinas: cirugía de epilepsia de emergencia',
          'Persistencia >15 min: iniciar fenobarbital en bolo',
        ],
        correctIndex: 0,
        explanation:
            'Status epiléptico REFRACTARIO: convulsión que persiste >30 minutos pese a benzodiacepinas y al menos un antiepiléptico de segunda línea. Requiere inducción de coma con anestésicos IV: propofol, midazolam en infusión continua, o tiopental/pentobarbital, con monitoreo EEG continuo y soporte ventilatorio (ILAE 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué complicación sistémica es más frecuente en status epiléptico prolongado?',
        options: [
          'Hipertermia, acidosis láctica, rabdomiólisis e hipoglucemia',
          'Hipertensión arterial sistémica severa',
          'Alcalosis respiratoria por hiperventilación',
          'Hipercalcemia e hiperpotasemia',
        ],
        correctIndex: 0,
        explanation:
            'El status epiléptico prolongado (>30 min) causa: hipertermia (actividad muscular sostenida), acidosis láctica (metabolismo anaeróbico), rabdomiólisis (puede llevar a falla renal aguda), hipoglucemia (aumento del consumo cerebral de glucosa), hipoxemia, arritmias cardíacas, edema cerebral y falla multiorgánica. La mortalidad aumenta significativamente con la duración (ILAE 2023).',
      ),
    ],
  ),

  // Crisis Febril en Niño
  _EvalScenario(
    id: 'eval_convulsion_febril',
    title: 'Crisis Febril en Niño',
    subtitle: 'Niño con convulsión y fiebre · AAP 2023',
    caseText:
        'Niño de 2 años, fiebre de 39.5°C por infección respiratoria alta. Convulsión tónico-clónica generalizada de 2 minutos de duración. Ahora somnoliento pero despierto, sin déficit neurológico focal.',
    color: AppColors.brand,
    icon: Icons.thermostat_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question: '¿Qué define una crisis febril simple?',
        options: [
          'Crisis generalizada, <15 minutos, única en 24h, sin déficit postictal, en niño de 6 meses a 5 años',
          'Crisis focal de cualquier duración en un niño febril',
          'Crisis que dura más de 30 minutos con fiebre',
          'Múltiples crisis en 24 horas en un niño menor de 6 meses',
        ],
        correctIndex: 0,
        explanation:
            'Crisis febril SIMPLE: crisis generalizada (tónico-clónica), <15 minutos de duración, única en 24 horas, sin déficit neurológico postictal, en niño de 6 meses a 5 años con fiebre >38°C sin infección intracraneana. Las crisis COMPLEJAS son focales, >15 min, múltiples en 24h o con déficit postictal (AAP 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Requiere este niño tratamiento anticonvulsivante de largo plazo?',
        options: [
          'No; las crisis febriles simples no requieren tratamiento antiepiléptico de mantención',
          'Sí, fenobarbital por 2 años para prevenir recurrencias',
          'Sí, ácido valproico de por vida',
          'Sí, levetiracetam por 6 meses',
        ],
        correctIndex: 0,
        explanation:
            'NO se recomienda tratamiento antiepiléptico profiláctico para crisis febriles simples. Los efectos adversos de los anticonvulsivantes (fenobarbital: alteraciones cognitivas y conductuales) superan los beneficios. El riesgo de desarrollar epilepsia posterior es solo ligeramente mayor que en la población general (1-2% vs 0.5%) (AAP 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo está indicada la punción lumbar en un niño con crisis febril?',
        options: [
          'Signos meníngeos, fontanela abombada, <12 meses con vacunación incompleta, o sospecha de meningitis',
          'En todas las crisis febriles de forma rutinaria',
          'Solo si la temperatura es >40°C al ingreso',
          'Si el niño tiene más de 3 años de edad',
        ],
        correctIndex: 0,
        explanation:
            'Indicaciones de punción lumbar en crisis febril: signos meníngeos (rigidez de nuca, Kernig, Brudzinski), fontanela abombada, niños <12 meses con vacunación incompleta para Hib y neumococo, o en cualquier edad si hay sospecha clínica de meningitis o encefalitis. NO es rutinaria en crisis febril simple sin signos de alarma (AAP 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué deben hacer los padres si el niño presenta otra crisis febril en casa?',
        options: [
          'Colocar al niño de lado (posición de seguridad), cronometrar la crisis, no introducir nada en la boca, llamar a emergencias si dura >5 min',
          'Sujetar al niño firmemente contra el suelo para evitar movimientos bruscos',
          'Introducir un objeto duro entre los dientes para evitar que se muerda la lengua',
          'Sumergir al niño en agua fría para bajar la fiebre inmediatamente',
        ],
        correctIndex: 0,
        explanation:
            'Manejo domiciliario: 1) Mantener la calma, 2) Posición de LADO (decúbito lateral) para proteger vía aérea, 3) NO introducir nada en la boca (riesgo de obstrucción, fractura dental o aspiración), 4) NO sujetar artificialmente (riesgo de lesiones), 5) Cronometrar la crisis, 6) Llamar a emergencias si dura >5 minutos o si es la primera crisis (AAP 2023).',
      ),
    ],
  ),

  // Eclampsia
  _EvalScenario(
    id: 'eval_embarazada_eclampsia',
    title: 'Eclampsia',
    subtitle: 'Preeclampsia con convulsiones · ACOG 2023',
    caseText:
        'Primigesta de 20 años, 36 semanas de gestación. PA 170/110, proteinuria +++, edema generalizado. Presenta convulsión tónico-clónica de 3 minutos en urgencias.',
    color: AppColors.accent,
    icon: Icons.pregnant_woman,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es el fármaco de elección para tratar y prevenir las convulsiones en eclampsia?',
        options: [
          'Sulfato de magnesio: 4-6 g IV en bolo, luego infusión de mantención 1-2 g/hora',
          'Diazepam 10 mg IV en bolo',
          'Fenitoína 20 mg/kg IV en carga',
          'Lorazepam 4 mg IV en bolo',
        ],
        correctIndex: 0,
        explanation:
            'El sulfato de magnesio es el fármaco de ELECCIÓN para prevención y tratamiento de convulsiones en preeclampsia/eclampsia. Dosis: 4-6 g IV en 15-20 minutos, seguido de infusión de mantención 1-2 g/hora por 24 horas. Es superior a diazepam, fenitoína y lorazepam para este propósito específico (ensayo Magpie) (ACOG 2023).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la única cura definitiva para la eclampsia?',
        options: [
          'Finalización del embarazo (inducción del parto o cesárea)',
          'Administrar sulfato de magnesio por 7 días continuos',
          'Hidralazina IV para control estricto de la presión arterial',
          'Reposo absoluto en cama con monitoreo fetal',
        ],
        correctIndex: 0,
        explanation:
            'La ÚNICA cura definitiva para la preeclampsia/eclampsia es la finalización del embarazo. El momento y la vía del parto dependen de la severidad, edad gestacional y condiciones materno-fetales. El sulfato de magnesio previene convulsiones pero no cura la enfermedad de base. El parto resuelve el síndrome al retirar la placenta (ACOG 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué antihipertensivo está indicado para PA >160/110 en eclampsia?',
        options: [
          'Labetalol 20 mg IV, hidralazina 5-10 mg IV, o nifedipino 10 mg VO',
          'Enalaprilato 1.25 mg IV (IECA)',
          'Losartán 50 mg VO (ARA-II)',
          'Metoprolol 50 mg VO cada 12 horas',
        ],
        correctIndex: 0,
        explanation:
            'Para PA >160/110 en embarazo: labetalol (20 mg IV, duplicar cada 10-20 min hasta 300 mg), hidralazina (5-10 mg IV cada 20 min hasta 30 mg) o nifedipino (10 mg VO cada 20 min). Los IECA y ARA-II están CONTRAINDICADOS en embarazo (riesgo de oligohidramnios, insuficiencia renal fetal y malformaciones). Meta: PA 140-155/90-105 (ACOG 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué signo clínico indica toxicidad por sulfato de magnesio?',
        options: [
          'Reflejos osteotendíneos abolidos y frecuencia respiratoria <12/min',
          'Bradicardia fetal en el monitoreo',
          'Cefalea frontal persistente que no cede a analgésicos',
          'Hipertermia >38.5°C',
        ],
        correctIndex: 0,
        explanation:
            'Toxicidad por magnesio (según niveles séricos): 1) 8-12 mg/dL: pérdida de reflejos osteotendíneos (ROT), 2) 12-16 mg/dL: depresión respiratoria (FR <12/min), 3) >16 mg/dL: paro cardíaco. Antídoto: gluconato de calcio 1g IV en 3-5 min. Monitoreo estricto: ROT, FR, diuresis, saturación de O2 cada hora (ACOG 2023).',
      ),
    ],
  ),

  // Crisis Hipertensiva
  _EvalScenario(
    id: 'eval_crisis_hipertensiva',
    title: 'Crisis Hipertensiva',
    subtitle: 'Emergencia hipertensiva con daño a órgano blanco · AHA/ACC 2023',
    caseText:
        'Hombre de 55 años, antecedentes de HTA mal controlada. PA 240/130, cefalea intensa, visión borrosa, disnea. Fondo de ojo: papiledema, hemorragias retinianas en llama.',
    color: AppColors.red,
    icon: Icons.favorite_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la meta de reducción de PA en la primera hora en emergencia hipertensiva?',
        options: [
          'Reducir PAM en 20-25% o PA diastólica a 100-105 mmHg en la primera hora',
          'Normalizar la PA completamente (<120/80) en la primera hora',
          'Reducir PA sistólica a <180 mmHg solo si hay síntomas',
          'No reducir la PA en la primera hora para evitar hipoperfusión',
        ],
        correctIndex: 0,
        explanation:
            'En emergencia hipertensiva, reducir PAM en 20-25% (o PA diastólica a 100-105 mmHg) en la PRIMERA hora. Reducción más agresiva puede causar hipoperfusión cerebral, renal o coronaria. En las siguientes 2-6 horas, reducir a 160/100. En 24-48 horas, normalizar gradualmente. "Lo importante no es bajar la PA, sino cómo se baja" (AHA/ACC 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué fármaco IV es el de elección en emergencia hipertensiva?',
        options: [
          'Labetalol o nicardipino en infusión IV continua titulable',
          'Nifedipino sublingual en cápsula mordida',
          'Enalaprilato IV en bolo',
          'Furosemida 40 mg IV en bolo como primera línea',
        ],
        correctIndex: 0,
        explanation:
            'Fármacos de elección en emergencia hipertensiva: labetalol (bloqueador α-β, 10-20 mg IV, infusión 0.5-2 mg/min) o nicardipino (bloqueador canales de calcio, infusión 5-15 mg/h). Nifedipino sublingual está CONTRAINDICADO (hipotensión severa no controlable, riesgo de IAM/ACV). Furosemida no es primera línea, solo si hay sobrecarga de volumen (AHA/ACC 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo está indicado el nitroprusiato de sodio en emergencia hipertensiva?',
        options: [
          'Reservado para casos refractarios por riesgo de intoxicación por tiocianato',
          'Como primera línea en todas las emergencias hipertensivas',
          'Solo en crisis hipertensivas secundarias a feocromocitoma',
          'No se utiliza nunca por su perfil de seguridad desfavorable',
        ],
        correctIndex: 0,
        explanation:
            'Nitroprusiato de sodio (0.3-10 µg/kg/min) se reserva para casos REFRACTARIOS. Riesgo de intoxicación por tiocianato (especialmente en insuficiencia renal) y cianuro, especialmente con uso prolongado >24-48h. Requiere monitoreo de niveles de tiocianato y cianuro. Ha sido reemplazado en gran medida por labetalol y nicardipino (AHA/ACC 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué estudios se deben solicitar para evaluar daño a órgano blanco?',
        options: [
          'ECG, troponinas, BNP, creatinina, sedimento urinario y TAC cerebral',
          'Solo ECG y radiografía de tórax',
          'Ecocardiograma y resonancia magnética cardíaca',
          'Angiografía coronaria urgente',
        ],
        correctIndex: 0,
        explanation:
            'Evaluación de daño a órgano blanco: Cardíaco (ECG, troponinas, BNP/NT-proBNP), Renal (creatinina, sedimento urinario, albuminuria), Cerebral (TAC cerebral para descartar hemorragia/ACV isquémico), Retiniano (fondo de ojo). La presencia de daño a órgano blanco diferencia emergencia (hospitalización, tratamiento IV) de urgencia hipertensiva (manejo oral) (AHA/ACC 2023).',
      ),
    ],
  ),

  // Shock Hipovolémico
  _EvalScenario(
    id: 'eval_shock_hipovolemico',
    title: 'Shock Hipovolémico',
    subtitle: 'Choque hemorrágico por trauma penetrante · ATLS 2023',
    caseText:
        'Hombre de 30 años, herida por arma blanca en abdomen. PA 70/40, FC 140 lpm, FR 30/min, piel fría y pálida, oliguria. Signos de irritación peritoneal.',
    color: AppColors.red,
    icon: Icons.water_drop_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la prioridad inmediata en shock hemorrágico por trauma?',
        options: [
          'Control de la hemorragia (compresión, torniquete, cirugía de control de daños)',
          'Administrar 2 litros de cristaloides IV en bolo rápido',
          'Solicitar TAC abdominal con contraste urgente',
          'Colocar sonda vesical y nasogástrica antes de cualquier otra medida',
        ],
        correctIndex: 0,
        explanation:
            'La prioridad es DETENER la hemorragia (control de daños). La reanimación con fluidos debe ser RESTRICTIVA (hipotensiva permisiva, PAM 60-65 mmHg) hasta el control quirúrgico definitivo. La administración masiva de cristaloides empeora la coagulopatía por dilución de factores, aumenta el sangrado y la mortalidad (ATLS 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué estrategia de reanimación hídrica se usa en trauma penetrante con shock?',
        options: [
          'Reanimación hipotensiva permisiva: mantener PAM 60-65 mmHg hasta control quirúrgico',
          'Cristaloides en proporción 3:1 respecto a la pérdida estimada',
          'Coloides (albúmina o hidroxietilalmidón) como primera línea',
          'No administrar líquidos hasta llegar al quirófano',
        ],
        correctIndex: 0,
        explanation:
            'Reanimación HIPOTENSIVA PERMISIVA: mantener PAM 60-65 mmHg para perfusión de órganos vitales sin aumentar el sangrado por PA alta que desaloje coágulos. Contraindicada en TCE (requiere PAM >80 mmHg para perfusión cerebral). Se prefiere sangre y hemocomponentes precoces sobre cristaloides. Evitar coloides sintéticos (ATLS 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo está indicado el uso de torniquete en trauma de extremidad?',
        options: [
          'Hemorragia exanguinante en extremidad que no cede con compresión directa',
          'En toda herida de extremidad como medida preventiva',
          'Solo en heridas de la extremidad inferior',
          'No se recomienda el uso de torniquetes en la actualidad',
        ],
        correctIndex: 0,
        explanation:
            'Torniquete indicado en HEMORRAGIA EXANGUINANTE de extremidad no controlable con compresión directa (amputaciones traumáticas, heridas masivas con lesión arterial). Colocar 5-7 cm proximal a la herida, registrar hora. Puede mantenerse hasta 2 horas sin daño irreversible. NO usar profilácticamente. Liberar solo en ambiente hospitalario con control quirúrgico (ATLS 2023).',
      ),
      _EvalQuestion(
        question: '¿Qué es REBOA y cuándo se utiliza en shock hemorrágico?',
        options: [
          'Balón de oclusión aórtica endovascular para hemorragia subdiafragmática no compresible',
          'Dispositivo de fijación externa para fracturas pélvicas inestables',
          'Catéter de medición de presión venosa central',
          'Técnica de depuración extrarrenal en shock séptico',
        ],
        correctIndex: 0,
        explanation:
            'REBOA (Resuscitative Endovascular Balloon Occlusion of the Aorta) es un balón endovascular que ocluye temporalmente la aorta para controlar hemorragia subdiafragmática no compresible (sangrado pélvico masivo, trauma hepático/abdominal). Es un puente hasta el control quirúrgico definitivo. Zonas: Zona I (torácica, sangrado abdominal), Zona III (infrarrenal, sangrado pélvico) (ATLS 2023).',
      ),
    ],
  ),

  // Crisis Hipertensiva en Embarazo
  _EvalScenario(
    id: 'eval_presion_crisis_embarazo',
    title: 'Crisis Hipertensiva en Embarazo',
    subtitle: 'Preeclampsia severa con crisis hipertensiva · ACOG 2023',
    caseText:
        'Mujer de 28 años, 34 semanas de gestación, PA 200/120, cefalea frontal intensa, escotomas visuales, dolor en epigastrio. Proteinuria 2g/24h.',
    color: AppColors.red,
    icon: Icons.monitor_heart_outlined,
    difficulty: 'Avanzado',
    questions: [
      _EvalQuestion(
        question:
            '¿Qué antihipertensivo está indicado para PA >160/110 en el embarazo?',
        options: [
          'Labetalol 20 mg IV, hidralazina 5-10 mg IV, o nifedipino 10 mg VO',
          'Enalapril 10 mg IV (IECA de acción corta)',
          'Losartán 50 mg VO (ARA-II)',
          'Nitroprusiato de sodio en infusión continua',
        ],
        correctIndex: 0,
        explanation:
            'Fármacos seguros en embarazo para PA >160/110: labetalol IV (20 mg, duplicar cada 10-20 min), hidralazina IV (5-10 mg cada 20 min) o nifedipino VO (10 mg cada 20 min). IECA y ARA-II están ABSOLUTAMENTE CONTRAINDICADOS (malformaciones fetales, oligohidramnios, insuficiencia renal fetal). Nitroprusiato puede causar toxicidad fetal por tiocianato (ACOG 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué medicamento se administra para prevenir la progresión a eclampsia?',
        options: [
          'Sulfato de magnesio 4-6 g IV en bolo, luego infusión 1-2 g/hora',
          'Diazepam 10 mg IV en bolo',
          'Fenitoína 1 g IV en carga',
          'Carbamazepina 400 mg VO',
        ],
        correctIndex: 0,
        explanation:
            'El sulfato de magnesio reduce el riesgo de eclampsia en 50-60% y es el fármaco de elección para profilaxis de convulsiones en preeclampsia severa. Dosis: 4-6 g IV en 15-20 min, luego infusión 1-2 g/h por 24 horas. Ajustar dosis en insuficiencia renal. Monitorear reflejos osteotendíneos y FR cada hora. Diazepam y fenitoína son inferiores (ACOG 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Cuándo está indicada la finalización del embarazo en preeclampsia severa?',
        options: [
          'Independientemente de la edad gestacional, una vez que la madre está estabilizada',
          'No finalizar antes de las 37 semanas bajo ninguna circunstancia',
          'Solo si hay signos evidentes de sufrimiento fetal en el monitoreo',
          'Esperar 48 horas para administrar corticoides madurativos pulmonares',
        ],
        correctIndex: 0,
        explanation:
            'En preeclampsia severa con síntomas de alarma (cefalea severa, escotomas, dolor epigástrico, PA no controlable), la finalización del embarazo está indicada independientemente de la edad gestacional, una vez que la madre está estabilizada. Si <34 semanas, administrar corticoides para maduración pulmonar fetal si es posible, sin retrasar el parto innecesariamente (ACOG 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué criterio diferencia preeclampsia severa de preeclampsia sin severidad?',
        options: [
          'PA ≥160/110, plaquetas <100,000, creatinina >1.1, enzimas hepáticas elevadas ×2, dolor epigástrico, síntomas visuales o neurológicos',
          'Solo el valor de PA >140/90 con proteinuria positiva',
          'La presencia de edema en miembros inferiores y manos',
          'El aumento de peso >1 kg por semana en el tercer trimestre',
        ],
        correctIndex: 0,
        explanation:
            'Criterios de PREECLAMPSIA SEVERA (ACOG): PA ≥160/110 en dos tomas separadas 4h, trombocitopenia (<100,000/µL), creatinina >1.1 mg/dL, enzimas hepáticas ×2 del valor normal, dolor epigástrico/hipocondrio derecho, edema pulmonar, cefalea severa que no cede, síntomas visuales (escotomas, visión borrosa). Cualquier criterio clasifica como severa (ACOG 2023).',
      ),
    ],
  ),

  // Anafilaxia Inducida por Ejercicio
  _EvalScenario(
    id: 'eval_anafilaxia_ejercicio',
    title: 'Anafilaxia Inducida por Ejercicio',
    subtitle: 'Anafilaxia desencadenada por esfuerzo físico · WAO 2023',
    caseText:
        'Hombre de 25 años, 20 minutos después de iniciar carrera de 5 km, presenta urticaria generalizada, prurito palmoplantar, edema facial y disnea. Ingirió mariscos 2 horas antes del ejercicio.',
    color: AppColors.orange,
    icon: Icons.directions_run_outlined,
    difficulty: 'Intermedio',
    questions: [
      _EvalQuestion(
        question:
            '¿Cuál es la primera medida en anafilaxia inducida por ejercicio?',
        options: [
          'Detener el ejercicio inmediatamente y administrar epinefrina IM 0.3 mg en el muslo',
          'Continuar el ejercicio a menor intensidad para "sudar" el alérgeno',
          'Tomar antihistamínicos orales y continuar trotando',
          'Realizar estiramientos musculares para aliviar los síntomas',
        ],
        correctIndex: 0,
        explanation:
            'La PRIMERA medida es DETENER el ejercicio de inmediato (continuar empeora la reacción y puede llevar a colapso cardiovascular). Administrar epinefrina IM 0.3 mg (1:1000) en el vasto lateral del muslo. Repetir cada 5-15 minutos si no hay respuesta. No hay contraindicación para usar auto-inyector de epinefrina durante el ejercicio (WAO 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Cuál es el mecanismo de la anafilaxia dependiente de alimentos y ejercicio?',
        options: [
          'El ejercicio aumenta la permeabilidad intestinal, facilitando la absorción de alérgenos no digeridos, activando mastocitos',
          'El ejercicio produce histamina directamente por el esfuerzo muscular independientemente de los alimentos',
          'Los alimentos se convierten en alérgenos solo al ser metabolizados durante el ejercicio intenso',
          'El ejercicio disminuye la temperatura corporal y desencadena liberación de histamina por frío',
        ],
        correctIndex: 0,
        explanation:
            'En FDEIA (Food-Dependent Exercise-Induced Anaphylaxis), el alimento desencadenante (trigo, mariscos, vegetales) consumido antes del ejercicio provoca que el esfuerzo físico aumente la permeabilidad intestinal y la absorción de alérgenos intactos, activando mastocitos y basófilos. Los pacientes toleran el alimento en reposo y el ejercicio sin el alimento (WAO 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué período entre ingesta y ejercicio tiene mayor riesgo de desencadenar anafilaxia?',
        options: [
          '2-4 horas antes del ejercicio',
          'Inmediatamente después del ejercicio (hasta 30 minutos post-ejercicio)',
          'Más de 6 horas antes del ejercicio',
          'Durante el sueño nocturno posterior al ejercicio',
        ],
        correctIndex: 0,
        explanation:
            'El mayor riesgo ocurre cuando el alimento desencadenante se consume 2-4 horas ANTES del ejercicio. Recomendaciones: 1) No ingerir el alimento desencadenante 4-6 horas antes del ejercicio, 2) Evitar ejercicio en climas extremos (calor, frío, humedad alta), 3) No realizar ejercicio si hay cofactores como AINEs, alcohol o infecciones agudas (WAO 2023).',
      ),
      _EvalQuestion(
        question:
            '¿Qué medidas preventivas se recomiendan para pacientes con anafilaxia por ejercicio?',
        options: [
          'Llevar auto-inyector de epinefrina siempre, evitar alimento desencadenante 4-6h antes del ejercicio y evitar cofactores',
          'No realizar ejercicio físico nunca más bajo ninguna circunstancia',
          'Tomar antihistamínicos profilácticos antes de cada sesión de ejercicio',
          'Realizar solo ejercicio en ayunas completas de 12 horas',
        ],
        correctIndex: 0,
        explanation:
            'Medidas preventivas: 1) Llevar SIEMPRE auto-inyector de epinefrina, 2) Evitar el alimento desencadenante 4-6h antes y 2h después del ejercicio, 3) Evitar cofactores (AINEs, alcohol, clima extremo), 4) Entrenar a compañeros de ejercicio en uso del auto-inyector, 5) Tener plan de acción escrito. El ejercicio NO está contraindicado; se debe identificar el trigger específico (WAO 2023).',
      ),
    ],
  ),

  // ─── Ritmos ECG con mini-monitor ──────────────────────────────────────
  _EvalScenario(
    id: 'eval_ritmo_fv',
    title: 'Identificación - Fibrilación Ventricular',
    subtitle: 'Ritmo desfibrilable · Monitorización',
    caseText: 'Mujer de 68 años, sin pulso. Monitor muestra ritmo caótico, sin ondas P, segmento QRS ni ondas T distinguibles.',
    color: Color(0xFF10B981),
    icon: Icons.monitor_heart_outlined,
    difficulty: 'Intermedio',
    ecgRhythm: _EcgRhythmType.fv,
    ecgRhythmLabel: 'FV — Ondulación caótica',
    ecgHeartRate: '--- lpm',
    questions: [
      _EvalQuestion(
        question: '¿Qué ritmo observa en el monitor?',
        options: ['Fibrilación Ventricular', 'Taquicardia Ventricular', 'Asistolia', 'AESP'],
        correctIndex: 0,
        explanation: 'La FV se caracteriza por actividad eléctrica caótica, desorganizada, sin complejos QRS distinguibles. Es un ritmo desfibrilable. La supervivencia disminuye 7-10% por cada minuto sin desfibrilación.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la primera acción?',
        options: ['Desfibrilación inmediata', 'Iniciar RCP y esperar DEA', 'Administrar adrenalina', 'Intubación orotraqueal'],
        correctIndex: 0,
        explanation: 'En FV presenciada con DEA disponible, la desfibrilación es la primera prioridad. Por cada minuto que se retrasa, la supervivencia cae 7-10%.',
      ),
      _EvalQuestion(
        question: 'Si el DEA indica "Descarga recomendada", ¿qué debe verificar antes de presionar el botón?',
        options: ['Que nadie toque al paciente', 'Que el paciente tenga pulso', 'Que la vía aérea esté asegurada', 'Que haya acceso venoso'],
        correctIndex: 0,
        explanation: 'Antes de cualquier descarga, DEBE verificar que NADIE esté tocando al paciente (incluyendo camilla, oxígeno, etc.).',
      ),
      _EvalQuestion(
        question: 'Después de la descarga, ¿qué debe hacer inmediatamente?',
        options: ['RCP 30:2 durante 2 minutos', 'Verificar pulso', 'Analizar ritmo nuevamente', 'Administrar adrenalina'],
        correctIndex: 0,
        explanation: 'Tras la descarga, reinicie RCP inmediatamente durante 2 minutos (5 ciclos de 30:2) antes de re-evaluar el ritmo.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la característica principal del electrocardiograma en la fibrilación ventricular (FV)?',
        options: ['Complejos QRS anchos y regulares', 'Actividad eléctrica caótica sin complejos QRS ni ondas P definidas', 'Ondas P seguidas de QRS estrechos', 'Complejos QRS estrechos con frecuencia > 150 lpm'],
        correctIndex: 1,
        explanation: 'La FV se caracteriza por una actividad eléctrica caótica, desorganizada y rápida, sin complejos QRS ni ondas P identificables. El trazado muestra oscilaciones de amplitud y frecuencia variables (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la energía recomendada para la primera descarga en desfibrilación bifásica de un adulto en FV?',
        options: ['120 J', '200 J', '360 J', 'La energía máxima recomendada por el fabricante, generalmente 120-200 J, pudiendo escalar en descargas posteriores'],
        correctIndex: 3,
        explanation: 'La AHA 2020 recomienda usar la energía bifásica recomendada por el fabricante (típicamente 120-200 J). Si se desconoce, usar la dosis máxima disponible. En monofásico usar 360 J.',
      ),
      _EvalQuestion(
        question: '¿Qué debe verificar el reanimador inmediatamente antes de presionar el botón de descarga?',
        options: ['Que el carro de paros esté completo', 'Que nadie esté en contacto con el paciente (zona segura)', 'Que haya vía aérea avanzada', 'Que se administró adrenalina'],
        correctIndex: 1,
        explanation: 'Antes de administrar la descarga, el reanimador debe verificar que nadie esté tocando al paciente ni en contacto con la camilla o equipos conectados, garantizando la zona de seguridad (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Qué debe hacerse inmediatamente después de administrar una descarga por FV?',
        options: ['Tomar un ECG de 12 derivaciones', 'Verificar pulso carotídeo durante 10 segundos', 'Reiniciar RCP durante 2 minutos', 'Administrar adrenalina 1 mg EV'],
        correctIndex: 2,
        explanation: 'Tras la descarga, se debe reiniciar RCP inmediatamente durante 2 minutos antes de volver a verificar el ritmo. No se debe retrasar las compresiones para verificar pulso (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿En qué momento del algoritmo de FV se administra la primera dosis de adrenalina?',
        options: ['Antes de la primera descarga', 'Después de la segunda descarga (primer ciclo de RCP)', 'Después de la tercera descarga', 'Solo si la FV persiste después de 10 minutos'],
        correctIndex: 1,
        explanation: 'En el algoritmo de FV/TV sin pulso, la adrenalina 1 mg EV/IO se administra después de la segunda descarga, es decir, tras el primer ciclo de RCP post-descarga (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿En qué momento del algoritmo de FV se administra amiodarona?',
        options: ['Antes de la primera descarga', 'Después de la tercera descarga, si la FV persiste', 'Después de la primera descarga', 'Junto con la adrenalina en el primer ciclo'],
        correctIndex: 1,
        explanation: 'La amiodarona (300 mg EV/IO, luego 150 mg) se administra después de la tercera descarga, cuando la FV persiste a pesar de las descargas y la adrenalina (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la diferencia principal entre FV gruesa y FV fina?',
        options: ['La FV gruesa tiene mejor pronóstico y responde mejor a la desfibrilación; la FV fina tiene baja amplitud (< 3 mm) y peor pronóstico', 'La FV fina requiere el doble de energía', 'La FV fina es más rápida que la gruesa', 'No existe diferencia clínica significativa'],
        correctIndex: 0,
        explanation: 'La FV gruesa (> 3 mm de amplitud) tiene mayor probabilidad de responder a la desfibrilación. La FV fina (< 3 mm) tiene peor pronóstico y puede confundirse con asistolia (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuál de las siguientes es una causa potencialmente reversible de FV?',
        options: ['Fibrosis miocárdica crónica', 'Hiperpotasemia severa', 'Miocardiopatía dilatada terminal', 'Estenosis aórtica calcificada severa'],
        correctIndex: 1,
        explanation: 'Las causas reversibles de paro cardíaco incluyen las 5 H y 5 T. La hiperpotasemia es una causa electrolítica tratable que puede desencadenar FV.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la diferencia principal entre desfibrilación bifásica y monofásica?',
        options: ['La bifásica administra corriente que fluye en ambas direcciones y logra mayor efectividad con menor energía; la monofásica fluye en una sola dirección', 'La monofásica es más segura', 'La bifásica solo se usa en pediatría', 'La monofásica requiere menos mantenimiento'],
        correctIndex: 0,
        explanation: 'La desfibrilación bifásica administra corriente que fluye en dirección positiva y negativa, requiriendo menos energía (120-200 J) para lograr la desfibrilación. La monofásica usa 360 J y corriente unidireccional (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la posición correcta de las palas o parches de desfibrilación en un adulto?',
        options: ['Ambos en el tórax anterior (lado izquierdo)', 'Uno en el ángulo escapular derecho y otro en el ángulo escapular izquierdo', 'Uno infraclavicular derecho (anterolateral) y otro en el ápex cardíaco (anterolateral izquierdo)', 'Ambos en el abdomen'],
        correctIndex: 2,
        explanation: 'La posición anterolateral es la más usada: un parche a la derecha del esternón, bajo la clavícula, y el otro en el ápex cardíaco (línea axilar media izquierda, a nivel del 5°-6° EIC). Alternativa: anteroposterior.',
      ),
      _EvalQuestion(
        question: '¿Cuánto tiempo debe realizarse RCP entre descargas en FV?',
        options: ['30 segundos', '1 minuto', '2 minutos', '5 minutos'],
        correctIndex: 2,
        explanation: 'Tras cada descarga, se debe realizar RCP durante 2 minutos (aproximadamente 5 ciclos de 30:2) antes de volver a verificar el ritmo. Esto maximiza la perfusión coronaria y cerebral (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuánto disminuye la supervivencia por cada minuto sin desfibrilación en FV?',
        options: ['1-2 %', '5-7 %', '7-10 %', '10-15 %'],
        correctIndex: 2,
        explanation: 'Por cada minuto que pasa sin desfibrilación en un paciente con FV, la supervivencia disminuye entre un 7-10 %. La desfibrilación temprana es el factor más crítico para la supervivencia (AHA 2020).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la dosis de energía recomendada para desfibrilación pediátrica en FV?',
        options: ['2 J/kg inicial, luego 4 J/kg', '4 J/kg, dosis única independientemente del peso', '1 J/kg', '5 J/kg para todas las edades'],
        correctIndex: 0,
        explanation: 'La AHA 2020 recomienda una dosis inicial de 2 J/kg para la primera descarga, y 4 J/kg para descargas posteriores, sin exceder la dosis máxima para adultos.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el mecanismo electrofisiológico que explica el mantenimiento de la fibrilación ventricular?',
        options: ['Automacidad aumentada de un solo foco ectópico', 'Bloqueo AV completo con ritmo de escape', 'Múltiples ondas de reentrada que circulan alrededor de áreas de bloqueo funcional o anatómico', 'Posdespolarizaciones tardías en fibras de Purkinje'],
        correctIndex: 2,
        explanation: 'La FV se mantiene por mecanismos de reentrada múltiple: frentes de onda eléctricos que circulan caóticamente alrededor de áreas de bloqueo, fragmentándose y generando nuevos frentes (AHA 2020).',
      ),
      _EvalQuestion(
        question: 'En un paciente hipotérmico con FV, ¿cuál es la modificación al protocolo estándar?',
        options: ['Limitar la desfibrilación a un máximo de 3 descargas hasta alcanzar > 30°C', 'Administrar adrenalina cada 2 minutos', 'Usar dosis de energía el doble de lo estándar', 'No desfibrilar hasta alcanzar normotermia'],
        correctIndex: 0,
        explanation: 'En hipotermia severa (< 30°C), se recomienda limitar las descargas a un máximo de 3 hasta que el paciente se caliente > 30°C, ya que el miocardio hipotérmico puede no responder.',
      ),
    ],
  ),
  _EvalScenario(
    id: 'eval_ritmo_tv',
    title: 'Identificación - TV sin pulso',
    subtitle: 'Ritmo desfibrilable · Monitorización',
    caseText: 'Hombre de 72 años con infarto previo. Inconsciente, sin pulso. El monitor muestra complejos QRS anchos y regulares a 180 lpm.',
    color: Color(0xFF10B981),
    icon: Icons.monitor_heart_outlined,
    difficulty: 'Intermedio',
    ecgRhythm: _EcgRhythmType.tv,
    ecgRhythmLabel: 'TV — QRS ancho regular',
    ecgHeartRate: '~180 lpm',
    questions: [
      _EvalQuestion(
        question: '¿Qué ritmo identifica?',
        options: ['Taquicardia Ventricular sin pulso', 'Fibrilación Ventricular', 'Taquicardia Sinusal', 'TSV'],
        correctIndex: 0,
        explanation: 'TV sin pulso: QRS ancho (>0.12s), regular, frecuencia >100 lpm, sin pulso palpable. Es un ritmo desfibrilable.',
      ),
      _EvalQuestion(
        question: '¿La TV sin pulso es un ritmo desfibrilable?',
        options: ['Sí, igual que la FV', 'No, solo RCP', 'Solo si es monomórfica', 'Depende de la frecuencia'],
        correctIndex: 0,
        explanation: 'La TV sin pulso es un ritmo desfibrilable. Se trata con descarga de igual energía que la FV. La prioridad es desfibrilación temprana.',
      ),
      _EvalQuestion(
        question: 'Si tras la descarga persiste TV sin pulso, ¿qué indica el algoritmo?',
        options: ['Nueva descarga + RCP 2 min + adrenalina', 'Solo RCP 5 minutos', 'Cardioversión sincronizada', 'Administrar amiodarona y esperar'],
        correctIndex: 0,
        explanation: 'TV/FV refractaria: descarga → RCP 2 min → adrenalina → descarga → RCP 2 min → amiodarona. Ciclos de 2 minutos entre descargas.',
      ),
      _EvalQuestion(
        question: 'En el ECG de 12 derivaciones, ¿cuál de los siguientes hallazgos es MÁS sugestivo de taquicardia ventricular (TV) como origen de una taquicardia de QRS ancho?',
        options: ['Complejo QRS en V1 con patrón de rama derecha y R monofásica > 30 ms', 'Disociación auriculoventricular', 'Eje eléctrico normal entre -30° y +90°', 'Complejo QRS < 120 ms'],
        correctIndex: 1,
        explanation: 'La disociación AV es el hallazgo más específico para TV. La presencia de latidos de fusión o captura también confirman TV.',
      ),
      _EvalQuestion(
        question: 'Según los criterios de Brugada para taquicardia de QRS ancho, ¿cuál es el primer paso del algoritmo?',
        options: ['Presencia de complejos QRS predominantemente negativos en V4-V6', 'Disociación AV evidente en todas las derivaciones', 'Falta de complejos RS en todas las derivaciones precordiales', 'Intervalo RS > 100 ms en una derivación precordial'],
        correctIndex: 2,
        explanation: 'El primer paso del algoritmo de Brugada es determinar si hay ausencia de complejos RS en todas las derivaciones precordiales. Si es así, se diagnostica TV.',
      ),
      _EvalQuestion(
        question: 'En el algoritmo de Vereckei para taquicardia de QRS ancho, el criterio del "intervalo vi/vt" se mide en:',
        options: ['Derivaciones II y aVF simultáneamente', 'Derivaciones precordiales V1-V3', 'Derivación aVR únicamente', 'Derivación I y aVL simultáneamente'],
        correctIndex: 2,
        explanation: 'El algoritmo de Vereckei utiliza aVR como derivación principal. El criterio vi/vt (velocidad inicial vs velocidad terminal) se evalúa en aVR. Un vi/vt ≤ 1 sugiere TV.',
      ),
      _EvalQuestion(
        question: 'Paciente con taquicardia de QRS ancho (160 lpm), hemodinámicamente estable. ECG muestra QRS > 140 ms, eje superior izquierdo (-120°) y concordancia negativa en precordiales. ¿Cuál es el diagnóstico más probable?',
        options: ['Taquicardia supraventricular con aberrancia', 'Taquicardia ventricular', 'Fibrilación auricular con preexcitación (WPW)', 'Taquicardia sinusal con bloqueo de rama'],
        correctIndex: 1,
        explanation: 'La concordancia negativa en precordiales (QS en V1-V6), QRS ancho > 140 ms y eje superior izquierdo son muy sugestivos de TV.',
      ),
      _EvalQuestion(
        question: '¿Cuál de los siguientes hallazgos favorece el diagnóstico de TV sobre TSV con aberrancia en una taquicardia de QRS ancho?',
        options: ['Patrón de RS en V1 con R mayor que S', 'Complejo QRS en V1 con patrón trifásico (rSR\')', 'Eje del QRS entre -90° y -180° (eje extremo o "no man\'s land")', 'Duración del QRS de 110 ms'],
        correctIndex: 2,
        explanation: 'Un eje en el cuadrante de -90° a -180° (conocido como "no man\'s land" o eje extremo) es altamente sugestivo de TV. Este eje es muy raro en la aberrancia.',
      ),
      _EvalQuestion(
        question: 'Paciente joven (28 años) con TV de QRS relativamente estrecho (120 ms) con morfología de bloqueo de rama derecha y eje desviado a la izquierda. ¿Cuál es el diagnóstico más probable?',
        options: ['TV polimórfica', 'Taquicardia ventricular fascicular izquierda (Belhassen)', 'TV por cicatriz postinfarto', 'TV del tracto de salida del ventrículo derecho'],
        correctIndex: 1,
        explanation: 'La TV fascicular izquierda (TV de Belhassen) típicamente se presenta en adultos jóvenes sin cardiopatía estructural, con morfología de BRD y eje izquierdo, QRS relativamente estrecho (120-140 ms).',
      ),
      _EvalQuestion(
        question: 'Característica electrocardiográfica típica de la taquicardia ventricular del tracto de salida del ventrículo derecho (TVOTVD):',
        options: ['Morfología de bloqueo de rama izquierda con eje inferior (positivo en II, III, aVF)', 'Morfología de bloqueo de rama derecha con eje superior', 'Disociación AV prominente', 'QRS > 200 ms'],
        correctIndex: 0,
        explanation: 'La TV del tracto de salida del VD (TVOTVD) clásicamente presenta morfología de BRI con eje inferior (complejo QRS positivo en II, III y aVF). Es la TV idiopática más frecuente.',
      ),
      _EvalQuestion(
        question: 'En la displasia arritmogénica del ventrículo derecho (DAVD), ¿cuál de los siguientes hallazgos apoya el diagnóstico?',
        options: ['Morfología de BRI con QRS ancho y onda epsilon en V1-V3', 'Morfología de BRD con R monofásica en V1', 'Eje superior derecho', 'Concordancia positiva en precordiales'],
        correctIndex: 0,
        explanation: 'La DAVD típicamente presenta TV con morfología de BRI (origen en VD) con QRS ensanchado. La onda epsilon (muescas al final del QRS en V1-V3) es un marcador característico.',
      ),
      _EvalQuestion(
        question: 'Relación entre isquemia miocárdica y taquicardia ventricular: ¿cuál de las siguientes afirmaciones es correcta?',
        options: ['La isquemia aguda siempre produce TV monomórfica sostenida', 'La isquemia aguda suele producir TV polimórfica o fibrilación ventricular, no TV monomórfica sostenida', 'La TV monomórfica sostenida en isquemia aguda responde siempre a antiarrítmicos clase I', 'La isquemia no se asocia con arritmias ventriculares'],
        correctIndex: 1,
        explanation: 'La isquemia miocárdica aguda típicamente desencadena TV polimórfica/fibrilación ventricular (no TV monomórfica sostenida). La TV monomórfica sostenida se asocia más frecuentemente con cicatriz postinfarto.',
      ),
      _EvalQuestion(
        question: 'En un paciente con infarto de miocardio previo y TV monomórfica sostenida, el sustrato arritmogénico más frecuente es:',
        options: ['Isquemia aguda del miocardio', 'Cicatriz miocárdica con canales de conducción lenta en el borde', 'Trastorno electrolítico aislado', 'Espasmo coronario'],
        correctIndex: 1,
        explanation: 'La TV monomórfica sostenida postinfarto se debe típicamente a un sustrato de reentrada alrededor de la cicatriz miocárdica. Los canales de conducción lenta en el borde de la cicatriz son el sustrato electrofisiológico clásico.',
      ),
      _EvalQuestion(
        question: 'En el manejo agudo de la TV monomórfica sostenida estable con QRS ancho, ¿cuál antiarrítmico está indicado como primera línea?',
        options: ['Lidocaína (clase IB)', 'Procainamida (clase IA) o amiodarona (clase III)', 'Adenosina', 'Verapamilo'],
        correctIndex: 1,
        explanation: 'En TV monomórfica estable, procainamida o amiodarona son los antiarrítmicos de elección. La lidocaína ha mostrado menor eficacia en TV con cardiopatía estructural.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la indicación de terapia de ablación en pacientes con taquicardia ventricular?',
        options: ['TV monomórfica recurrente a pesar de tratamiento antiarrítmico o pacientes con tormenta arrítmica', 'Todo paciente con un solo episodio de TV', 'TV polimórfica durante isquemia aguda', 'TV no sostenida asintomática'],
        correctIndex: 0,
        explanation: 'La ablación está indicada en TV monomórfica recurrente refractaria a fármacos, en tormenta arrítmica, o en pacientes con ICD que presentan descargas recurrentes.',
      ),
      _EvalQuestion(
        question: 'Paciente con ICD que recibe una descarga apropiada por TV. ¿Cuál es el siguiente paso más adecuado?',
        options: ['Cambiar el ICD sin más evaluación', 'Evaluar causa subyacente, optimizar fármacos, revisar umbrales y programación del ICD', 'Administrar lidocaína en bolo y suspender antiarrítmicos', 'Derivar directamente a ablación sin evaluación médica'],
        correctIndex: 1,
        explanation: 'Ante una descarga apropiada del ICD se debe evaluar la causa subyacente (isquemia, electrolitos, progresión de enfermedad), optimizar el tratamiento médico y revisar la programación del ICD.',
      ),
      _EvalQuestion(
        question: 'Definición de tormenta arrítmica (electrical storm):',
        options: ['3 o más episodios de TV/FV en 24 horas', 'Una descarga inapropiada del ICD en un mes', 'TV no sostenida asintomática en el Holter', 'TV monomórfica única estable'],
        correctIndex: 0,
        explanation: 'La tormenta arrítmica se define como 3 o más episodios de TV/FV (o descargas apropiadas del ICD) en 24 horas. Requiere manejo agresivo con antiarrítmicos, sedación y posible ablación.',
      ),
      _EvalQuestion(
        question: '¿Cuál de los siguientes trastornos metabólicos puede desencadenar TV polimórfica tipo torsade de pointes?',
        options: ['Hipercalcemia', 'Hipomagnesemia', 'Hipernatremia', 'Hipoglucemia'],
        correctIndex: 1,
        explanation: 'La hipomagnesemia y la hipopotasemia son desencadenantes metabólicos clásicos de torsade de pointes (TV polimórfica asociada a QT prolongado). El magnesio intravenoso es el tratamiento de primera línea.',
      ),
      _EvalQuestion(
        question: 'En pacientes con TV y cardiopatía estructural (miocardiopatía dilatada), ¿cuál antiarrítmico ha demostrado reducir la mortalidad?',
        options: ['Amiodarona sola', 'Amiodarona combinada con betabloqueante', 'Lidocaína', 'Flecainida'],
        correctIndex: 1,
        explanation: 'En cardiopatía estructural, los antiarrítmicos clase I están contraindicados por su efecto proarrítmico. La amiodarona combinada con betabloqueantes es la terapia más segura y efectiva.',
      ),
    ],
  ),
  _EvalScenario(
    id: 'eval_ritmo_asistolia',
    title: 'Identificación - Asistolia',
    subtitle: 'Ritmo no desfibrilable · Monitorización',
    caseText: 'Mujer de 80 años encontrada en el suelo. Sin pulso ni respiración. Monitor muestra línea plana.',
    color: Color(0xFF10B981),
    icon: Icons.monitor_heart_outlined,
    difficulty: 'Intermedio',
    ecgRhythm: _EcgRhythmType.asistolia,
    ecgRhythmLabel: 'Asistolia — Sin actividad',
    ecgHeartRate: '0 lpm',
    questions: [
      _EvalQuestion(
        question: '¿Qué ritmo observa?',
        options: ['Asistolia', 'Fibrilación Ventricular', 'AESP', 'Disociación electromecánica'],
        correctIndex: 0,
        explanation: 'Asistolia: ausencia total de actividad eléctrica cardíaca (línea plana). Ritmo NO desfibrilable. La supervivencia es muy baja si no se identifica causa reversible.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el tratamiento principal?',
        options: ['RCP de alta calidad + adrenalina cada 3-5 min', 'Desfibrilación inmediata', 'Cardioversión sincronizada', 'Marcapasos transcutáneo'],
        correctIndex: 0,
        explanation: 'Asistolia: RCP 30:2 inmediata, adrenalina 1 mg IV/IO cada 3-5 minutos, identificar causas reversibles (5H y 5T). NO está indicada la desfibrilación.',
      ),
      _EvalQuestion(
        question: '¿Cuánto tiempo debe realizar RCP antes de re-evaluar el ritmo?',
        options: ['2 minutos (5 ciclos)', '1 minuto', '5 minutos', 'Hasta que llegue la ambulancia'],
        correctIndex: 0,
        explanation: 'En todos los ritmos de parada, RCP 2 minutos (5 ciclos de 30:2) antes de re-evaluar. Minimizar pausas en compresiones.',
      ),
      _EvalQuestion(
        question: '¿Cuál de los siguientes describe mejor el ritmo terminal en un paciente moribundo antes de la asistolia?',
        options: ['Taquicardia ventricular monomórfica', 'Ritmo idioventricular lento que progresivamente disminuye en frecuencia y amplitud hasta desaparecer', 'Fibrilación auricular rápida', 'Ritmo sinusal normal con descargas del ICD'],
        correctIndex: 1,
        explanation: 'El ritmo terminal o "dying heart rhythm" típicamente consiste en un ritmo idioventricular (o nodal) que lentamente disminuye su frecuencia y amplitud QRS hasta convertirse en asistolia.',
      ),
      _EvalQuestion(
        question: 'Ante una línea plana en el monitor, ¿cuál es el primer paso para descartar pseudo-asistolia?',
        options: ['Administrar adrenalina inmediatamente', 'Verificar conexión de electrodos y aumentar ganancia, revisando en múltiples derivaciones', 'Realizar cardioversión', 'Administrar atropina'],
        correctIndex: 1,
        explanation: 'La pseudo-asistolia es una "línea plana" falsa debida a electrodos desconectados, derivación incorrecta o ganancia baja. Siempre debe verificarse la conexión de electrodos, aumentar la ganancia y revisar en múltiples derivaciones.',
      ),
      _EvalQuestion(
        question: 'Durante una reanimación, aparece asistolia en el monitor. ¿Qué verificación inmediata de los electrodos debe realizarse?',
        options: ['Comprobar que los electrodos estén bien adheridos y conectados al cable del monitor/desfibrilador', 'Cambiar la batería del monitor', 'Reiniciar el desfibrilador', 'Aplicar gel conductor en los electrodos'],
        correctIndex: 0,
        explanation: 'Ante una aparente asistolia, siempre verificar que los electrodos estén correctamente colocados y conectados. Una desconexión o mala adherencia puede simular asistolia y retrasar el tratamiento adecuado.',
      ),
      _EvalQuestion(
        question: 'Al visualizar una línea plana en el monitor, ¿qué ajuste debe realizarse para confirmar asistolia real?',
        options: ['Disminuir la ganancia al mínimo', 'Aumentar la ganancia para detectar actividad eléctrica de baja amplitud', 'Desactivar el filtro de línea', 'Cambiar a monitorización invasiva de presión arterial'],
        correctIndex: 1,
        explanation: 'Aumentar la ganancia permite detectar actividad eléctrica de muy baja amplitud que podría no verse con la ganancia estándar. Si con ganancia máxima sigue en línea plana, es más probable asistolia real.',
      ),
      _EvalQuestion(
        question: '¿Por qué es importante verificar la asistolia en más de una derivación electrocardiográfica?',
        options: ['Porque una derivación puede estar desconectada o mostrar isoelectricidad mientras otras derivaciones muestran actividad cardíaca', 'Porque las ondas T se ven mejor en derivaciones diferentes', 'Porque el eje cardíaco cambia en paro', 'No es necesario verificar más de una derivación'],
        correctIndex: 0,
        explanation: 'Una derivación desconectada o con mala señal puede mostrar una línea plana mientras otras derivaciones evidencian actividad eléctrica viable. Es esencial revisar al menos 2 derivaciones antes de confirmar asistolia.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el orden correcto de la nemotecnia de las "H y T" en el manejo de la asistolia?',
        options: ['H: Hipoxia, Hipovolemia, H+ (ácido), Hipo-/Hiper-K, Hipotermia. T: Taponamiento, Tórax a tensión, Trombosis (coronaria/pulmonar), Tóxicos', 'H: Hemorragia, HTA, Hipertermia. T: Taquicardia, Trauma', 'No existe una nemotecnia estándar', 'Solo hay causas H, no T'],
        correctIndex: 0,
        explanation: 'Las H y T son causas reversibles de paro: Hipoxia, Hipovolemia, Hidrogenión (acidosis), Hipo/Hiperpotasemia, Hipotermia; Taponamiento, Tórax a tensión, Trombosis coronaria/pulmonar, Tóxicos.',
      ),
      _EvalQuestion(
        question: 'En el manejo de la asistolia por hipoxia severa, ¿cuál es la intervención prioritaria?',
        options: ['Administrar bicarbonato de sodio', 'Ventilación con oxígeno al 100% y asegurar vía aérea avanzada', 'Administrar calcio intravenoso', 'Realizar pericardiocentesis'],
        correctIndex: 1,
        explanation: 'La hipoxia como causa de asistolia requiere ventilación efectiva con oxígeno al 100% y aseguramiento de la vía aérea (intubación o dispositivo supraglótico). Sin oxigenación adecuada, otras medidas son ineficaces.',
      ),
      _EvalQuestion(
        question: '¿Cuáles son los signos clínicos de hipovolemia severa como posible causa de asistolia?',
        options: ['Hipertensión y bradicardia', 'Ingurgitación yugular y edema pulmonar', 'Hipotensión, piel fría, taquicardia, pulsos débiles, y eventualmente paro en asistolia sin RCP efectiva', 'Crepitantes pulmonares bilaterales'],
        correctIndex: 2,
        explanation: 'La hipovolemia severa cursa con signos de shock: hipotensión, taquicardia, extremidades frías, relleno capilar lento, piel marmórea. Puede progresar a paro cardíaco en asistolia si no se repone volumen.',
      ),
      _EvalQuestion(
        question: 'La tríada de Beck para el taponamiento cardíaco incluye:',
        options: ['Hipotensión, ruidos cardíacos apagados, ingurgitación yugular', 'Hipertensión, taquicardia, edema pulmonar', 'Dolor torácico, fiebre, derrame pleural', 'Cianosis, disnea, hemoptisis'],
        correctIndex: 0,
        explanation: 'La tríada de Beck (hipotensión, ruidos cardíacos apagados, ingurgitación yugular) es clásica del taponamiento cardíaco. En paro por esta causa, la pericardiocentesis urgente es la intervención que salva la vida.',
      ),
      _EvalQuestion(
        question: 'En el neumotórax a tensión, ¿cuál de los siguientes hallazgos es característico?',
        options: ['Desviación traqueal hacia el lado afectado y distensión yugular', 'Desviación traqueal hacia el lado contrario al afectado, ingurgitación yugular e hipotensión', 'Crepitantes húmedos bilaterales y fiebre', 'Derrame pleural bilateral'],
        correctIndex: 1,
        explanation: 'En neumotórax a tensión, la tráquea se desvía al lado contrario (alejándose) del neumotórax, y la presión intratorácica elevada causa ingurgitación yugular y compromiso hemodinámico. Requiere descompresión con aguja inmediata.',
      ),
      _EvalQuestion(
        question: 'Ante una sospecha de tromboembolia pulmonar masiva como causa de paro en asistolia, ¿cuál de los siguientes signos es más característico?',
        options: ['Signo de McConnell en ecocardiografía', 'Ondas T picudas en ECG', 'Elevación del segmento ST en V1-V2', 'Hipoxemia leve que mejora con oxígeno'],
        correctIndex: 0,
        explanation: 'El signo de McConnell (hipocinesia de la pared libre del VD con preservación del ápex) es característico de TEP masivo. En paro por TEP, la fibrinólisis o embolectomía son las intervenciones que pueden ser salvadoras.',
      ),
      _EvalQuestion(
        question: 'En la evaluación de toxicidad como causa de asistolia, ¿cuál es el estudio de laboratorio más relevante?',
        options: ['Hemograma completo', 'Cribado toxicológico en sangre y orina', 'Velocidad de sedimentación globular', 'Proteína C reactiva'],
        correctIndex: 1,
        explanation: 'El cribado toxicológico (screening de drogas y tóxicos) es esencial en la sospecha de intoxicación. Sobredosis de betabloqueantes, bloqueadores de canales de calcio, antidepresivos tricíclicos o digitálicos pueden causar asistolia.',
      ),
      _EvalQuestion(
        question: 'En el ECG de un paciente con hiperpotasemia severa que puede progresar a asistolia, ¿cuál es la secuencia característica de cambios?',
        options: ['Ondas U prominentes y QT prolongado', 'Ondas T picudas y altas, luego QRS ancho, pérdida de onda P y finalmente onda sinusoidal', 'Inversión de onda T y presencia de onda Q patológica', 'Elevación del ST y ondas T hiperagudas'],
        correctIndex: 1,
        explanation: 'La hiperpotasemia severa progresa desde ondas T picudas → QRS ancho → pérdida de onda P → patrón sinusoidal → paro cardíaco (asistolia o FV). El reconocimiento temprano permite tratamiento con calcio, insulina-glucosa.',
      ),
      _EvalQuestion(
        question: 'La presencia de ondas U prominentes en el ECG sugiere:',
        options: ['Hiperpotasemia', 'Hipopotasemia', 'Hipercalcemia', 'Hipermagnesemia'],
        correctIndex: 1,
        explanation: 'Las ondas U se asocian clásicamente con hipopotasemia. La hipopotasemia severa puede causar arritmias ventriculares (torsade de pointes) y progresar a asistolia. Es importante corregir el potasio durante la reanimación.',
      ),
      _EvalQuestion(
        question: '¿Cuál de los siguientes hallazgos electrocardiográficos es característico de hipotermia severa?',
        options: ['Ondas J (Osborn) y bradicardia', 'Ondas T picudas simétricas', 'QT corto', 'Onda P mitral'],
        correctIndex: 0,
        explanation: 'Las ondas J de Osborn (deflexión positiva al final del QRS) son patognomónicas de hipotermia. La hipotermia severa causa bradicardia progresiva que puede llevar a asistolia. El manejo incluye recalentamiento activo.',
      ),
    ],
  ),
  _EvalScenario(
    id: 'eval_ritmo_aesp',
    title: 'Identificación - AESP',
    subtitle: 'Ritmo no desfibrilable · Monitorización',
    caseText: 'Paciente de 65 años con sepsis, hipotenso y ahora inconsciente. Sin pulso. Monitor muestra ritmo sinusal organizado a 80 lpm.',
    color: Color(0xFF10B981),
    icon: Icons.monitor_heart_outlined,
    difficulty: 'Avanzado',
    ecgRhythm: _EcgRhythmType.aesp,
    ecgRhythmLabel: 'AESP — Ritmo sin pulso',
    ecgHeartRate: '~80 lpm (sin pulso)',
    questions: [
      _EvalQuestion(
        question: '¿Qué condición describe este escenario?',
        options: ['AESP (Actividad Eléctrica Sin Pulso)', 'Asistolia', 'Bloqueo AV completo', 'Taquicardia Sinusal'],
        correctIndex: 0,
        explanation: 'AESP: actividad eléctrica organizada en el monitor SIN pulso palpable. NO es desfibrilable. El tratamiento se enfoca en identificar la causa subyacente.',
      ),
      _EvalQuestion(
        question: '¿Cuál de las siguientes NO es una causa reversible de AESP?',
        options: ['Fibrilación Ventricular', 'Hipovolemia', 'Neumotórax a tensión', 'Taponamiento cardíaco'],
        correctIndex: 0,
        explanation: 'Causas de AESP (5H + 5T): Hipovolemia, Hipoxia, Hidrogenión (acidosis), Hipo/Hiperkalemia, Hipotermia, Tensión neumotórax, Taponamiento cardíaco, Tóxicos, Trombosis pulmonar, Trombosis coronaria.',
      ),
      _EvalQuestion(
        question: 'Además de RCP de alta calidad, ¿qué tratamiento específico se administra en AESP?',
        options: ['Adrenalina 1 mg IV/IO cada 3-5 min', 'Desfibrilación bifásica 200J', 'Amiodarona 300 mg', 'Lidocaína 1.5 mg/kg'],
        correctIndex: 0,
        explanation: 'AESP: RCP 30:2 + adrenalina 1 mg cada 3-5 minutos. Identificar y tratar causa reversible. No está indicada desfibrilación ni antiarrítmicos.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el factor pronóstico más importante en pacientes con AESP?',
        options: ['La causa subyacente del AESP y la presencia de actividad contráctil en ecocardiografía', 'La edad del paciente', 'El ritmo específico en el ECG', 'La frecuencia cardíaca exacta'],
        correctIndex: 0,
        explanation: 'La supervivencia en AESP depende críticamente de la causa subyacente y si es reversible, y de la presencia o ausencia de contractilidad miocárdica (pseudo-AESP tiene mejor pronóstico que AESP verdadero).',
      ),
      _EvalQuestion(
        question: '¿Cuál es la lista de causas potencialmente reversibles a evaluar sistemáticamente en todo paciente con AESP?',
        options: ['H\'s y T\'s: Hipoxia, Hipovolemia, H+, Hipo/Hiper-K, Hipotermia, Taponamiento, Tórax a tensión, Trombosis coronaria/pulmonar, Tóxicos', 'ABCDE primario: vía aérea, respiración, circulación', 'Evaluación neurológica completa', 'Signos vitales seriados'],
        correctIndex: 0,
        explanation: 'La búsqueda sistemática de causas reversibles en AESP sigue las H\'s y T\'s. Identificar y tratar una causa reversible (como taponamiento, TEP, neumotórax, hipovolemia o tóxicos) es la intervención más efectiva para lograr ROSC.',
      ),
      _EvalQuestion(
        question: 'En el algoritmo de AESP, ¿cuándo debe administrarse adrenalina?',
        options: ['Cada 3-5 minutos durante la RCP tan pronto como se accede a la vía IV/IO', 'Solo después de 20 minutos de RCP', 'Cada 10 minutos', 'No está indicada la adrenalina en AESP'],
        correctIndex: 0,
        explanation: 'En AESP, se administra adrenalina 1 mg IV/IO cada 3-5 minutos durante la RCP, tan pronto como se tenga acceso vascular. La adrenalina aumenta el flujo sanguíneo coronario y cerebral durante las compresiones.',
      ),
      _EvalQuestion(
        question: '¿Qué es el pseudo-AESP y cómo se diferencia del AESP verdadero?',
        options: ['Pseudo-AESP es un ritmo con actividad contráctil miocárdica detectable por ecografía pero sin pulso palpable; el AESP verdadero no tiene contractilidad miocárdica significativa', 'Pseudo-AESP es asistolia con artefactos de movimiento', 'Pseudo-AESP es TV polimórfica de baja amplitud', 'Pseudo-AESP y AESP verdadero son sinónimos'],
        correctIndex: 0,
        explanation: 'El pseudo-AESP se refiere a pacientes en los que hay evidencia ecocardiográfica de contractilidad miocárdica pero sin pulso palpable (por shock severo, hipotensión extrema). Estos pacientes tienen mejor pronóstico que el AESP verdadero.',
      ),
      _EvalQuestion(
        question: '¿Cómo se diferencia un paciente con AESP verdadero de uno con shock severo (pseudo-AESP)?',
        options: ['Ecocardiografía a pie de cama (POCUS) que demuestre contractilidad miocárdica permitiendo diferenciar entre ausencia total de contractilidad vs. contractilidad débil', 'ECG de 12 derivaciones', 'Radiografía de tórax', 'Análisis de gases arteriales'],
        correctIndex: 0,
        explanation: 'La ecografía a pie de cama es la herramienta clave para diferenciar pseudo-AESP (presenta algún grado de contractilidad miocárdica) de AESP verdadero (sin contractilidad). El pseudo-AESP tiene un pronóstico más favorable.',
      ),
      _EvalQuestion(
        question: '¿Qué ritmo se espera observar tras una desfibrilación exitosa de FV/TV sin pulso que no recupera pulso?',
        options: ['AESP o ritmo organizado sin pulso', 'Asistolia inmediata', 'FV recurrente', 'Ritmo sinusal normal con pulso inmediato'],
        correctIndex: 0,
        explanation: 'Tras desfibrilación exitosa puede presentarse AESP (ritmo organizado pero sin pulso). Esto se denomina AESP post-desfibrilación y requiere continuar RCP, administrar adrenalina y buscar causas reversibles.',
      ),
      _EvalQuestion(
        question: 'En el abordaje inicial de la AESP con ecografía (POCUS), ¿qué debe evaluarse primero?',
        options: ['Medición exacta de la fracción de eyección', 'Actividad cardíaca y contractilidad miocárdica en ventana subcostal o apical', 'Doppler color de las válvulas cardíacas', 'Medición del diámetro de la aorta abdominal'],
        correctIndex: 1,
        explanation: 'El POCUS en AESP debe evaluar rápidamente si hay actividad contráctil miocárdica. Diferenciar entre AESP verdadera (sin contractilidad) y pseudo-AESP (con contractilidad pero sin pulso) cambia el pronóstico y el manejo.',
      ),
      _EvalQuestion(
        question: 'Hallazgo ecocardiográfico característico de taponamiento cardíaco en un paciente con AESP:',
        options: ['Colapso telediastólico del ventrículo derecho', 'Hipertrofia ventricular izquierda severa', 'Fracción de eyección > 60%', 'Aurícula izquierda dilatada'],
        correctIndex: 0,
        explanation: 'El colapso telediastólico (o mesodiastólico) del VD es el hallazgo más sensible y específico de taponamiento cardíaco en ecocardiografía. Requiere pericardiocentesis urgente para revertir el cuadro.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el signo ecocardiográfico de McConnell en el contexto de AESP por tromboembolia pulmonar masiva?',
        options: ['Hipocinesia de la pared libre del VD con movimiento normal del ápex del VD', 'Aurícula derecha dilatada con colapso del VD', 'Válvula tricúspide prolapsada', 'Flujo Doppler reverso en la vena cava inferior'],
        correctIndex: 0,
        explanation: 'El signo de McConnell (hipocinesia de la pared libre del VD con preservación de la contractilidad apical) sugiere TEP masivo como causa de AESP. La presencia de este signo orienta a fibrinólisis o embolectomía.',
      ),
      _EvalQuestion(
        question: 'En el neumotórax a tensión como causa de AESP, ¿cuál es el hallazgo ecográfico distintivo?',
        options: ['Deslizamiento pleural conservado bilateral', '"Punto pulmonar" (lung point) y ausencia de deslizamiento pleural del lado afectado', 'Derrame pleural ipsilateral masivo', 'Consolidación pulmonar con broncograma aéreo'],
        correctIndex: 1,
        explanation: 'El punto pulmonar (lung point) es el hallazgo ecográfico más específico de neumotórax. Se identifica como el punto donde reaparece el deslizamiento pleural en el borde del neumotórax.',
      ),
      _EvalQuestion(
        question: 'Hallazgo ecográfico de hipovolemia severa como causa de AESP:',
        options: ['Colapso completo de la vena cava inferior (IVC) con ausencia de variación respiratoria', 'Vena cava inferior dilatada > 2.5 cm sin colapso', 'Ventrículo derecho dilatado', 'Pericardio engrosado'],
        correctIndex: 0,
        explanation: 'La vena cava inferior colapsada (diámetro < 1.5 cm con colapso inspiratorio completo) sugiere hipovolemia severa. El manejo es la reposición agresiva de volumen intravenoso y tratar la causa de la hipovolemia.',
      ),
      _EvalQuestion(
        question: '¿Cuál de los siguientes fármacos puede causar AESP por sus efectos hemodinámicos?',
        options: ['Betabloqueantes y bloqueadores de canales de calcio en sobredosis', 'Paracetamol en dosis terapéuticas', 'Omeprazol intravenoso', 'Heparina de bajo peso molecular'],
        correctIndex: 0,
        explanation: 'Los betabloqueantes y bloqueadores de calcio en sobredosis causan depresión miocárdica, bradicardia y vasodilatación que pueden producir AESP. El tratamiento incluye calcio intravenoso, glucagón y soporte vasopresor.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el protocolo ecocardiográfico recomendado durante la reanimación de un paciente con AESP?',
        options: ['Protocolo FEEL (Focused Echocardiography Evaluation in Life Support) o protocolo RUSH para evaluar rápida y sistemáticamente causas reversibles', 'Ecocardiograma transtorácico completo con todas las mediciones', 'Ecocardiograma transesofágico sin limitación de tiempo', 'Doppler color de todas las válvulas'],
        correctIndex: 0,
        explanation: 'El protocolo FEEL (Focus Echo Evaluation in Life Support) es el más recomendado. Evalúa sistemáticamente contractilidad cardíaca, derrame pericárdico, signos de TEP, volemia (IVC) y descarta neumotórax, todo durante pausas breves de compresiones.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la tasa de supervivencia al alta hospitalaria en pacientes con AESP extrahospitalaria?',
        options: ['Aproximadamente 3-5%', 'Aproximadamente 50%', 'Aproximadamente 80%', 'Aproximadamente 90%'],
        correctIndex: 0,
        explanation: 'La supervivencia al alta en AESP extrahospitalaria es muy baja (alrededor del 3-5%). Es peor que en FV/TV pero ligeramente mejor que en asistolia. La identificación precoz de causas reversibles es el factor que puede mejorar este pronóstico.',
      ),
      _EvalQuestion(
        question: 'En el paciente traumatológico con AESP, ¿cuál es la causa más frecuente y potencialmente reversible?',
        options: ['Hemorragia severa/hipovolemia, neumotórax a tensión y taponamiento cardíaco (en trauma torácico penetrante)', 'Hemorragia intracraneal masiva', 'Lesión medular cervical', 'Fractura de pelvis estable'],
        correctIndex: 0,
        explanation: 'En trauma, el AESP se debe comúnmente a hemorragia severa con hipovolemia. Otras causas reversibles incluyen neumotórax a tensión y taponamiento cardíaco (especialmente en heridas penetrantes). La toracotomía de reanimación puede estar indicada.',
      ),
      _EvalQuestion(
        question: '¿Cuál de las siguientes alteraciones metabólicas puede causar AESP?',
        options: ['Hipercalcemia severa (calcio > 14 mg/dL)', 'Hipoglucemia severa y mixedema', 'Hiperuricemia asintomática', 'Hipertrigliceridemia'],
        correctIndex: 1,
        explanation: 'La hipoglucemia severa y el mixedema (hipotiroidismo severo) son causas metabólicas de AESP. Otras incluyen insuficiencia suprarrenal, hiperpotasemia, hipopotasemia y acidosis severa.',
      ),
    ],
  ),
  _EvalScenario(
    id: 'eval_ritmo_tsv',
    title: 'Identificación - Taquicardia SupraVentricular',
    subtitle: 'Ritmo estable/inestable · Monitorización',
    caseText: 'Mujer de 35 años con palpitaciones, mareo, frecuencia cardíaca 190 lpm. Monitor muestra QRS estrecho, regular, sin ondas P visibles.',
    color: Color(0xFF10B981),
    icon: Icons.monitor_heart_outlined,
    difficulty: 'Avanzado',
    ecgRhythm: _EcgRhythmType.tsv,
    ecgRhythmLabel: 'TSV — QRS estrecho',
    ecgHeartRate: '~190 lpm',
    questions: [
      _EvalQuestion(
        question: '¿Qué ritmo identifica?',
        options: ['TSV (Taquicardia SupraVentricular)', 'TV (Taquicardia Ventricular)', 'FA con RVR', 'Flutter Auricular'],
        correctIndex: 0,
        explanation: 'TSV: QRS estrecho (<0.12s), regular, frecuencia 150-250 lpm, ondas P generalmente no visibles. Origen supraventricular.',
      ),
      _EvalQuestion(
        question: 'Si la paciente está inestable (hipotensa, dolor torácico), ¿qué tratamiento?',
        options: ['Cardioversión sincronizada', 'Adenosina 6 mg IV', 'Betabloqueantes IV', 'Manobras vagales'],
        correctIndex: 0,
        explanation: 'TSV inestable: cardioversión sincronizada inmediata. TSV estable: manobras vagales → adenosina 6 mg → 12 mg → betabloqueantes/calcioantagonistas.',
      ),
      _EvalQuestion(
        question: '¿Por qué la cardioversión debe ser sincronizada?',
        options: ['Para evitar desencadenar FV', 'Porque tiene mejor eficacia', 'Para reducir la energía necesaria', 'Para evitar dolor al paciente'],
        correctIndex: 0,
        explanation: 'La cardioversión sincronizada evita que la descarga caiga en el período vulnerable de la onda T, lo que podría desencadenar FV. La descarga se sincroniza con el complejo QRS.',
      ),
      _EvalQuestion(
        question: '¿Cuál de los siguientes hallazgos en el ECG es más característico de una taquicardia supraventricular (TSV) que de una taquicardia sinusal?',
        options: ['Anchura del QRS > 0,12 s', 'Frecuencia cardiaca > 150 lpm y QRS estrecho', 'Onda P negativa en V1', 'Intervalo PR constante con cada latido'],
        correctIndex: 1,
        explanation: 'Las TSV típicamente presentan frecuencia >150 lpm con QRS estrecho (<0,12 s), mientras que la taquicardia sinusal rara vez supera 150 lpm en reposo.',
      ),
      _EvalQuestion(
        question: 'En una TSV con QRS estrecho, la presencia de ondas P invertidas en las derivaciones inferiores (II, III, aVF) sugiere:',
        options: ['Taquicardia sinusal', 'Taquicardia auricular', 'AVNRT o AVRT (taquicardia por reentrada intranodal o vía accesoria)', 'Flutter auricular típico'],
        correctIndex: 2,
        explanation: 'Las ondas P invertidas en II, III y aVF indican activación auricular retrógrada (de abajo arriba), característica de AVNRT y AVRT.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el hallazgo electrocardiográfico que permite diferenciar AVNRT de AVRT ortodrómica?',
        options: ['La duración del QRS', 'La morfología de la onda P y el intervalo RP', 'La frecuencia cardiaca', 'La presencia de onda delta'],
        correctIndex: 1,
        explanation: 'En AVRT el intervalo RP es más largo (>70 ms) porque la activación ventricular precede a la auricular retrógrada por la vía accesoria; en AVNRT el RP es corto (<70 ms) por activación simultánea aurículo-ventricular.',
      ),
      _EvalQuestion(
        question: 'Una TSV con intervalo RP corto (RP < PR) y onda P muy cercana al QRS sugiere:',
        options: ['Taquicardia auricular', 'Flutter auricular', 'AVNRT típica (slow-fast)', 'AVRT ortodrómica'],
        correctIndex: 2,
        explanation: 'La AVNRT slow-fast es la TSV más frecuente. El estímulo desciende por la vía lenta y asciende por la vía rápida, activando aurículas y ventrículos casi simultáneamente, produciendo RP muy corto.',
      ),
      _EvalQuestion(
        question: 'Ante una TSV estable que no responde a maniobras vagales, la administración de adenosina (6-12 mg en bolo IV rápido) puede:',
        options: ['Solo disminuir la frecuencia sin revertir la taquicardia', 'Terminar la mayoría de las AVNRT y AVRT, pero no las taquicardias auriculares ni el flutter', 'Ser ineficaz en todas las TSV', 'Provocar siempre bloqueo AV completo irreversible'],
        correctIndex: 1,
        explanation: 'La adenosina bloquea transitoriamente el nodo AV, terminando las taquicardias que dependen del nodo AV (AVNRT, AVRT). En taquicardia auricular o flutter puede no terminar la arritmia pero revela la actividad auricular subyacente.',
      ),
      _EvalQuestion(
        question: '¿Cuál de los siguientes signos ECG es patognomónico de preexcitación ventricular (WPW)?',
        options: ['QRS estrecho con ondas P invertidas', 'Onda delta (empastamiento inicial del QRS) con PR corto', 'Intervalo QT prolongado', 'Segmento ST elevado en precordiales'],
        correctIndex: 1,
        explanation: 'La onda delta es el empastamiento ascendente del QRS por activación ventricular precoz a través de la vía accesoria, acompañado de PR corto (<0,12 s).',
      ),
      _EvalQuestion(
        question: 'En el síndrome de WPW, la taquicardia con QRS ancho e irregular sugiere:',
        options: ['AVRT ortodrómica', 'AVRT antidrómica o fibrilación auricular preexcitada', 'Taquicardia ventricular monomórfica', 'AVNRT con bloqueo de rama'],
        correctIndex: 1,
        explanation: 'En la AVRT antidrómica el estímulo desciende por la vía accesoria (QRS ancho por activación ventricular anómala) y asciende por el nodo AV. En FA con WPW, la conducción por la vía accesoria produce QRS ancho e irregular.',
      ),
      _EvalQuestion(
        question: 'Un paciente presenta taquicardia regular a 150 lpm con QRS estrecho y ondas en "diente de sierra" en II, III y aVF. El diagnóstico más probable es:',
        options: ['AVNRT', 'Taquicardia auricular multifocal', 'Flutter auricular típico con conducción AV 2:1', 'Taquicardia sinusal'],
        correctIndex: 2,
        explanation: 'El flutter auricular típico (istmo-dependiente) produce ondas de aleteo (sawtooth) a ~300 lpm, con conducción AV 2:1 dando frecuencia ventricular de ~150 lpm, que es la presentación clásica.',
      ),
      _EvalQuestion(
        question: 'Para diferenciar una taquicardia sinusal de una TSV, el hallazgo más útil es:',
        options: ['La presencia de ondas P visibles', 'La variabilidad de la frecuencia cardiaca con los cambios de posición y respiración', 'Frecuencia cardiaca exacta > 150 lpm', 'La duración del intervalo QT'],
        correctIndex: 1,
        explanation: 'La taquicardia sinusal varía su frecuencia con la respiración, el ejercicio y los cambios posturales, mientras que las TSV paroxísticas suelen ser muy regulares y no varían con estos estímulos.',
      ),
      _EvalQuestion(
        question: '¿Cuándo debe sospecharse que una taquicardia de QRS ancho es realmente una TSV con aberrancia?',
        options: ['Cuando hay disociación AV', 'Cuando hay morfología de bloqueo de rama derecha con complejo rsR\' en V1', 'Cuando los complejos son totalmente negativos en V1-V6', 'Cuando la frecuencia es > 200 lpm'],
        correctIndex: 1,
        explanation: 'La morfología rsR\' en V1 (como bloqueo de rama derecha) es típica de aberrancia. La disociación AV, complejos concordantes negativos en precordiales y morfología de BRD con R monofásica o QR en V1 favorecen TV.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la técnica correcta para realizar la maniobra de Valsalva como tratamiento de una TSV?',
        options: ['Inspirar profundamente y mantener 30 segundos', 'Espirar forzadamente contra la glotis cerrada durante 10-15 segundos (similar a pujar al defecar)', 'Toser repetidamente con fuerza', 'Realizar compresión ocular bilateral'],
        correctIndex: 1,
        explanation: 'El paciente debe espirar contra una resistencia (glotis cerrada o jeringa de 10 mL) durante 10-15 segundos, generando presión intratorácica que estimula el vago. La versión modificada (supino con elevación de piernas) aumenta la eficacia.',
      ),
      _EvalQuestion(
        question: 'El hallazgo de disociación AV en una taquicardia de QRS ancho es diagnóstico de:',
        options: ['AVRT ortodrómica', 'Taquicardia supraventricular con aberrancia', 'Taquicardia ventricular', 'Flutter auricular'],
        correctIndex: 2,
        explanation: 'La disociación AV (aurículas y ventrículos laten independientemente) es el signo más específico de taquicardia ventricular. En las TSV la relación AV suele ser 1:1.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la tasa de éxito de la ablación por catéter para la AVNRT y la AVRT?',
        options: ['Aproximadamente 50%', 'Aproximadamente 70%', '> 95% en centros con experiencia', 'No hay datos concluyentes'],
        correctIndex: 2,
        explanation: 'La ablación por radiofrecuencia para AVNRT y AVRT tiene tasas de éxito agudo >95% en centros experimentados, con baja tasa de recurrencia (<5%) y bajo riesgo de complicaciones mayores.',
      ),
      _EvalQuestion(
        question: 'En un paciente pediátrico con TSV estable, el fármaco de elección es:',
        options: ['Adenosina (0,1-0,3 mg/kg IV)', 'Amiodarona IV', 'Lidocaína IV', 'Cardioversión eléctrica sincronizada'],
        correctIndex: 0,
        explanation: 'La adenosina es el fármaco de primera línea en TSV pediátrica estable por su vida media ultracorta (<10 s) y perfil de seguridad. La dosis inicial es 0,1 mg/kg (máx 6 mg) en bolo IV rápido.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la conducta recomendada ante una taquicardia supraventricular en una embarazada?',
        options: ['Cardioversión eléctrica inmediata sin importar la edad gestacional', 'Maniobras vagales y adenosina como primera línea si no hay inestabilidad', 'Solo observación, pues los fármacos están contraindicados en el embarazo', 'Administrar verapamilo oral'],
        correctIndex: 1,
        explanation: 'En la embarazada con TSV estable se inicia con maniobras vagales; si fracasan, adenosina IV es segura en el embarazo. La cardioversión eléctrica es segura si hay inestabilidad, con monitorización fetal.',
      ),
      _EvalQuestion(
        question: '¿Cuál de los siguientes NO es un criterio para el diagnóstico diferencial de taquicardia de QRS estrecho?',
        options: ['Regularidad del ritmo', 'Presencia y morfología de la onda P', 'Relación entre ondas P y complejos QRS (RP/PR)', 'Duración del intervalo QT corregido'],
        correctIndex: 3,
        explanation: 'El intervalo QT no es útil para diferenciar TSV. Los criterios clave son: regularidad (regular vs irregular), presencia/morfología de P, relación RP/PR, y respuesta a adenosina/maniobras vagales.',
      ),
    ],
  ),
  _EvalScenario(
    id: 'eval_ritmo_fa',
    title: 'Identificación - Fibrilación Auricular',
    subtitle: 'Ritmo irregular · Monitorización',
    caseText: 'Hombre de 75 años con antecedente de HTA, disnea y palpitaciones. Pulso irregular. Monitor muestra ritmo irregular sin ondas P.',
    color: Color(0xFF10B981),
    icon: Icons.monitor_heart_outlined,
    difficulty: 'Intermedio',
    ecgRhythm: _EcgRhythmType.fa,
    ecgRhythmLabel: 'FA — Irregular',
    ecgHeartRate: 'Variable (~140 lpm)',
    questions: [
      _EvalQuestion(
        question: '¿Qué ritmo observa?',
        options: ['Fibrilación Auricular', 'Flutter Auricular', 'TSV', 'Extrasístoles frecuentes'],
        correctIndex: 0,
        explanation: 'FA: ritmo irregularmente irregular, sin ondas P (ondas f), QRS estrecho. La ausencia de contracción auricular aumenta el riesgo de tromboembolismo.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el principal riesgo de la FA no tratada?',
        options: ['ACV (Accidente Cerebrovascular)', 'Infarto agudo al miocardio', 'Parada cardíaca súbita', 'Shock cardiogénico'],
        correctIndex: 0,
        explanation: 'El riesgo principal de la FA es el ACV tromboembólico por estasis sanguínea en la aurícula izquierda. La anticoagulación reduce el riesgo.',
      ),
      _EvalQuestion(
        question: 'Si el paciente está inestable con FA de inicio reciente, ¿qué tratamiento?',
        options: ['Cardioversión sincronizada + anticoagulación', 'Amiodarona VO', 'Digoxina IV', 'Anticoagulación sola'],
        correctIndex: 0,
        explanation: 'FA inestable: cardioversión sincronizada. Se requiere anticoagulación posterior según CHA2DS2-VASc. FA >48h requiere ECO transesofágico o 3 semanas de anticoagulación previa.',
      ),
      _EvalQuestion(
        question: '¿Qué puntuación se usa para estimar el riesgo de ACV en FA?',
        options: ['CHA2DS2-VASc', 'HAS-BLED', 'SOFA', 'APACHE II'],
        correctIndex: 0,
        explanation: 'CHA2DS2-VASc: Insuficiencia Cardíaca, HTA, Edad ≥75 (2pts), Diabetes, ACV/AIT (2pts), Enfermedad Vascular, Edad 65-74, Sexo femenino. Puntaje ≥2 en hombres o ≥3 en mujeres = anticoagulación.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el hallazgo electrocardiográfico más característico de la fibrilación auricular?',
        options: ['Ondas P negativas en III', 'Intervalos R-R irregulares sin ondas P visibles, con ondas f (fibrilatorias)', 'QRS ancho con ondas P en diente de sierra', 'Ondas P bifásicas en V1'],
        correctIndex: 1,
        explanation: 'La FA se caracteriza por intervalos R-R irregularmente irregulares, ausencia de ondas P y presencia de ondas f (de fibrilación) de morfología, amplitud y frecuencia variables.',
      ),
      _EvalQuestion(
        question: 'En un ECG con FA, la ausencia total de ondas P se debe a:',
        options: ['Bloqueo sinoauricular', 'Actividad auricular desorganizada y caótica sin contractilidad coordenada', 'Hipertrofia auricular izquierda severa', 'Fibrilación ventricular concomitante'],
        correctIndex: 1,
        explanation: 'En la FA la actividad eléctrica auricular es desorganizada (multiples frentes de reentrada) sin contractilidad auricular efectiva, generando ondas f de fibrilación en lugar de ondas P.',
      ),
      _EvalQuestion(
        question: '¿Qué caracteriza la fibrilación auricular paroxística?',
        options: ['Episodios que terminan espontáneamente en <7 días (usualmente <48 h)', 'FA continua por >7 días que requiere cardioversión', 'FA aceptada como ritmo permanente sin intentos de revertir', 'FA que solo aparece tras cirugía cardíaca'],
        correctIndex: 0,
        explanation: 'FA paroxística: episodios autolimitados que terminan solos en <7 días (típicamente <48 h). Persistente: >7 días. Permanente: aceptada sin intentar revertir.',
      ),
      _EvalQuestion(
        question: 'Según la escala CHA₂DS₂-VASc, ¿cuál de los siguientes puntajes corresponde a "edad ≥ 75 años"?',
        options: ['0 puntos', '1 punto', '2 puntos', '3 puntos'],
        correctIndex: 2,
        explanation: 'En CHA₂DS₂-VASc: edad ≥75 años = 2 puntos. Edad 65-74 años = 1 punto. El resto de componentes (IC, HTA, DM, vasculopatía, sexo femenino) = 1 punto cada uno, excepto ACV/AIT previo = 2 puntos.',
      ),
      _EvalQuestion(
        question: 'Un paciente con FA y CHA₂DS₂-VASc de 0 (varón) o 1 (mujer por sexo femenino únicamente):',
        options: ['Debe recibir anticoagulación con DOAC', 'No requiere anticoagulación (riesgo tromboembólico muy bajo)', 'Debe recibir aspirina', 'Debe recibir warfarina'],
        correctIndex: 1,
        explanation: 'Según guías, pacientes con CHA₂DS₂-VASc 0 (varón) o 1 (mujer por sexo solamente) tienen riesgo muy bajo y no requieren anticoagulación. Con puntaje ≥1 en varones o ≥2 en mujeres se considera anticoagular.',
      ),
      _EvalQuestion(
        question: 'La escala HAS-BLED se utiliza para evaluar:',
        options: ['Riesgo de accidente cerebrovascular en FA', 'Riesgo de sangrado en pacientes anticoagulados con FA', 'Probabilidad de éxito de cardioversión', 'Riesgo de recurrencia de FA tras ablación'],
        correctIndex: 1,
        explanation: 'HAS-BLED estima el riesgo de sangrado mayor en pacientes con FA que reciben anticoagulación. Un score ≥3 indica alto riesgo y requiere monitorización estrecha, pero no contraindica la anticoagulación.',
      ),
      _EvalQuestion(
        question: 'En la estrategia de "control de frecuencia" en FA, ¿cuál es el objetivo de frecuencia cardiaca en reposo?',
        options: ['< 50 lpm', '< 80-110 lpm', '110-130 lpm', 'Frecuencia perfectamente regular'],
        correctIndex: 1,
        explanation: 'El control de frecuencia busca frecuencia <80-110 lpm en reposo (estricto: <80 lpm en reposo y <110 lpm con ejercicio moderado). El control de ritmo busca restaurar el ritmo sinusal con fármacos o cardioversión.',
      ),
      _EvalQuestion(
        question: '¿Cuál de los siguientes DOAC (anticoagulante oral directo) no requiere monitorización rutinaria de coagulación?',
        options: ['Warfarina', 'Acenocumarol', 'Apixabán', 'Heparina no fraccionada'],
        correctIndex: 2,
        explanation: 'Los DOAC (apixabán, rivaroxabán, edoxabán, dabigatrán) no requieren monitorización rutinaria de INR a diferencia de los antivitamina K (warfarina, acenocumarol). Tienen dosis fijas y menor riesgo de sangrado intracraneal.',
      ),
      _EvalQuestion(
        question: '¿Cuál es la energía recomendada para la cardioversión eléctrica sincronizada de FA?',
        options: ['50 J bifásico', 'Monofásico 100-200 J o bifásico 120-200 J', '360 J monofásico siempre', 'Energía máxima desde el inicio'],
        correctIndex: 1,
        explanation: 'La cardioversión de FA se realiza con 100-200 J bifásico o 200 J monofásico inicialmente. Si fracasa se aumenta. Siempre debe ser sincronizada (para evitar desencadenar TV/FV) y con sedación.',
      ),
      _EvalQuestion(
        question: '¿Cuál es el fármaco de elección para cardioversión farmacológica de FA de reciente comienzo (<48 h) en un paciente sin cardiopatía estructural?',
        options: ['Digoxina oral', 'Flecainida o propafenona (vía oral o IV) "pill-in-the-pocket"', 'Amiodarona IV en bolo', 'Lidocaína IV'],
        correctIndex: 1,
        explanation: 'La flecainida y propafenona son antiarrítmicos clase IC efectivos para convertir FA reciente a ritmo sinusal en pacientes sin cardiopatía estructural. Pueden usarse en pauta "pill-in-the-pocket" en episodios paroxísticos.',
      ),
      _EvalQuestion(
        question: 'Antes de realizar una cardioversión eléctrica electiva en un paciente con FA >48 h de duración, es necesario:',
        options: ['Solicitar una radiografía de tórax', 'Iniciar amiodarona oral 4 semanas antes', 'Realizar ecocardiograma transesofágico (ETE) para descartar trombo en orejuela izquierda o asegurar 3-4 semanas de anticoagulación terapéutica', 'Administrar lidocaína profiláctica'],
        correctIndex: 2,
        explanation: 'El riesgo de trombo en aurícula izquierda (especialmente orejuela) requiere ETE que lo descarte o bien 3-4 semanas de anticoagulación terapéutica previa a la cardioversión, más anticoagulación posterior ≥4 semanas.',
      ),
      _EvalQuestion(
        question: 'El principal riesgo de no realizar ETE ni anticoagular adecuadamente antes de cardioversión de FA >48 h es:',
        options: ['Infarto de miocardio', 'Accidente cerebrovascular embólico por movilización de trombo auricular', 'Muerte súbita por TV/FV', 'Pericarditis post-cardioversión'],
        correctIndex: 1,
        explanation: 'Al restaurar el ritmo sinusal, la contracción auricular recuperada puede movilizar un trombo de la orejuela izquierda, causando ACV embólico. El riesgo de ictus embólico sin protección es ~5-7%.',
      ),
      _EvalQuestion(
        question: '¿Cuáles son los fármacos de primera línea para control de frecuencia ventricular en FA?',
        options: ['Digoxina exclusivamente', 'Betabloqueantes (metoprolol, bisoprolol) o calcioantagonistas no dihidropiridínicos (verapamilo, diltiazem)', 'Amiodarona oral', 'Flecainida'],
        correctIndex: 1,
        explanation: 'Betabloqueantes y calcioantagonistas (verapamilo/diltiazem) son los fármacos de primera línea para control de frecuencia en FA, actuando sobre el nodo AV. Digoxina es segunda línea o en FA con IC.',
      ),
      _EvalQuestion(
        question: 'La digoxina en la fibrilación auricular:',
        options: ['Es el fármaco de primera línea para control de frecuencia', 'Tiene efecto predominantemente vagotónico sobre el nodo AV, eficaz en reposo pero no durante el ejercicio', 'Convierte FA a ritmo sinusal con alta eficacia', 'Está contraindicada en la FA'],
        correctIndex: 1,
        explanation: 'La digoxina aumenta el tono vagal sobre el nodo AV, siendo eficaz para control de frecuencia en reposo pero no durante el ejercicio (porque el tono simpático predomina). Es de segunda línea y útil en FA + insuficiencia cardíaca.',
      ),
    ],
  ),
];

const Map<String, List<String>> kCaseTypeMap = {
  'rcp': [
    'eval_adulto_rcp',
    'eval_pediatrico',
    'eval_lactante',
    'eval_dos_rescatadores',
    'eval_rcp_via_aerea_avanzada',
    'eval_rcp_hands_only',
    'eval_rcp_dea',
  ],
  'dea': [
    'eval_dea_fv',
    'eval_dea_pediatrico',
    'eval_dea_superficie_mojada',
    'eval_dea_marcapasos',
    'eval_dea_parches',
    'eval_dea_vello',
  ],
  'ahogamiento': [
    'eval_ahogamiento',
    'eval_ahogamiento_agua_fria',
    'eval_ahogamiento_pediatrico',
    'eval_ahogamiento_agua_salada',
    'eval_ahogamiento_lesion_cervical',
    'eval_ahogamiento_vehiculo',
  ],
  'ovace': [
    'eval_ovace_adulto',
    'eval_ovace_lactante',
    'eval_ovace_adulto_inconsciente',
    'eval_ovace_nino',
    'eval_ovace_obesidad',
    'eval_ovace_embarazada',
  ],
  'electrocucion': [
    'eval_electrocucion',
    'eval_electrocucion_alto_voltaje',
    'eval_electrocucion_rayo',
    'eval_electrocucion_pediatrica',
    'eval_electrocucion_banera',
    'eval_electrocucion_arco',
  ],
  'sobredosis': [
    'eval_sobredosis',
    'eval_sobredosis_benzodiacepinas',
    'eval_sobredosis_cocaina',
    'eval_sobredosis_opioides',
    'eval_sobredosis_triciclicos',
    'eval_sobredosis_paracetamol',
  ],
  'infarto': [
    'eval_infarto_paro',
    'eval_infarto_edema_pulmonar',
    'eval_infarto_inferior_bav',
    'eval_infarto_anterior',
    'eval_infarto_shock_cardiogenico',
    'eval_infarto_derecho',
  ],
  'hipotermia': [
    'eval_hipotermia',
    'eval_hipotermia_avalancha',
    'eval_hipotermia_neonatal',
  ],
  'hemorragia': [
    'eval_hemorragia',
    'eval_hemorragia_tce',
    'eval_hemorragia_postparto',
  ],
  'anafilaxia': [
    'eval_anafilaxia',
    'eval_anafilaxia_picadura',
    'eval_anafilaxia_alimento',
    'eval_anafilaxia_ejercicio',
  ],
  'convulsion': [
    'eval_convulsion',
    'eval_convulsion_status',
    'eval_convulsion_febril',
  ],
  'embarazada': [
    'eval_embarazada',
    'eval_embarazada_eclampsia',
  ],
  'presion': [
    'eval_crisis_hipertensiva',
    'eval_shock_hipovolemico',
    'eval_presion_crisis_embarazo',
  ],
  'infeccion': [
    'eval_sepsis',
    'eval_infeccion_shock_pediatrico',
    'eval_infeccion_meningitis',
    'eval_infeccion_neumonia',
    'eval_infeccion_urosepsis',
    'eval_infeccion_endocarditis',
  ],
  'metabolico': [
    'eval_cetoacidosis',
    'eval_metabolico_hiperosmolar',
    'eval_metabolico_hipoglucemia',
    'eval_metabolico_acidosis_lactica',
    'eval_metabolico_tormenta_tiroidea',
    'eval_metabolico_insuficiencia_suprarrenal',
  ],
  'ecg': [
    'eval_ecg_fv',
    'eval_ecg_tvsp',
    'eval_ecg_asistolia',
    'eval_ecg_tsv',
    'eval_ecg_bav',
    'eval_ecg_fa_rvr',
    'eval_ritmo_fv',
    'eval_ritmo_tv',
    'eval_ritmo_asistolia',
    'eval_ritmo_aesp',
    'eval_ritmo_tsv',
    'eval_ritmo_fa',
  ],
};

// ─── FILTRO POR TIPO ─────────────────────────────────────────────────────────

List<_EvalScenario> _filteredCases(String? type) {
  if (type == null || type.isEmpty) return kTheoreticalCases;
  final ids = kCaseTypeMap[type] ?? <String>[];
  if (ids.isEmpty) return kTheoreticalCases;
  return kTheoreticalCases.where((c) => ids.contains(c.id)).toList();
}

// ─── Pantalla de lista ────────────────────────────────────────────────────────
class TheoreticalCasesScreen extends StatelessWidget {
  final String? type;
  const TheoreticalCasesScreen({super.key, this.type});

  @override
  Widget build(BuildContext context) {
    final cases = _filteredCases(type);
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
                          '${cases.length} casos · Decisiones de protocolo AHA 2020/2025',
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
                      '${cases.length} casos',
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
                itemCount: cases.length,
                itemBuilder: (ctx, i) {
                  final eval = cases[i];
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

// ─── Mini-monitor ECG ─────────────────────────────────────────────────────────
class _EcgMiniWave extends StatelessWidget {
  final _EcgRhythmType rhythm;
  final double height;
  final String? label;
  final String? heartRate;

  const _EcgMiniWave({
    required this.rhythm,
    this.height = 72,
    this.label,
    this.heartRate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A1628) : const Color(0xFFF0F4F8);
    final traceColor = isDark ? const Color(0xFF00FF88) : const Color(0xFF059669);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: CustomPaint(
              painter: _EcgTracePainter(rhythm: rhythm, color: traceColor),
            ),
          ),
        ),
        if (label != null || heartRate != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: TextStyle(
                      color: traceColor.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (label != null && heartRate != null)
                  Text('  ·  ', style: TextStyle(color: traceColor.withValues(alpha: 0.4), fontSize: 9)),
                if (heartRate != null)
                  Text(
                    heartRate!,
                    style: TextStyle(
                      color: traceColor.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EcgTracePainter extends CustomPainter {
  final _EcgRhythmType rhythm;
  final Color color;

  _EcgTracePainter({required this.rhythm, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final midY = size.height / 2;
    final w = size.width;
    final h = size.height;

    final path = Path();
    final samples = _generateSamples(w);

    if (samples.isEmpty) return;

    path.moveTo(0, midY + samples[0] * h * 0.35);
    for (int i = 1; i < samples.length; i++) {
      final x = (i / samples.length) * w;
      path.lineTo(x, midY + samples[i] * h * 0.35);
    }

    canvas.drawPath(path, paint);

    // Grid lines
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;
    for (double y = 0; y < h; y += h / 4) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    for (double x = 0; x < w; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
  }

  List<double> _generateSamples(double width) {
    final n = (width / 1.5).round().clamp(80, 400);
    final rnd = Random(rhythm.index);
    switch (rhythm) {
      case _EcgRhythmType.fv:
        return List.generate(n, (_) => (rnd.nextDouble() - 0.5) * 1.8);
      case _EcgRhythmType.tv:
        return _wideComplexRhythm(n, 6, 120);
      case _EcgRhythmType.asistolia:
        return _asystole(n);
      case _EcgRhythmType.aesp:
        return _sinusRhythm(n, 75, 0.3);
      case _EcgRhythmType.normal:
        return _sinusRhythm(n, 72, 0.6);
      case _EcgRhythmType.fa:
        return _irregularRhythm(n);
      case _EcgRhythmType.bav:
        return _bavRhythm(n);
      case _EcgRhythmType.tsv:
        return _sinusRhythm(n, 180, 0.5);
    }
  }

  List<double> _sinusRhythm(int n, int bpm, double amplitude) {
    final samplesPerBeat = (n / (bpm / 60.0 * 2)).round();
    final result = <double>[];
    for (int i = 0; i < n; i++) {
      final pos = i % samplesPerBeat;
      final beatProgress = pos / samplesPerBeat;
      double val = 0;
      if (beatProgress < 0.02) {
        val = -amplitude * 0.3;
      } else if (beatProgress < 0.04) {
        val = amplitude * (beatProgress - 0.02) / 0.02;
      } else if (beatProgress < 0.08) {
        val = amplitude * (1 - (beatProgress - 0.04) / 0.04);
      } else if (beatProgress > 0.85 && beatProgress < 0.92) {
        val = amplitude * 0.25 * sin((beatProgress - 0.85) / 0.07 * pi);
      }
      result.add(val);
    }
    return result;
  }

  List<double> _wideComplexRhythm(int n, int rate, double amplitude) {
    final samplesPerBeat = (n / (rate / 60.0 * 2)).round();
    final result = <double>[];
    for (int i = 0; i < n; i++) {
      final pos = i % samplesPerBeat;
      final beatProgress = pos / samplesPerBeat;
      double val = 0;
      if (beatProgress < 0.02) {
        val = -amplitude * 0.2;
      } else if (beatProgress < 0.10) {
        val = amplitude * ((beatProgress - 0.02) / 0.08);
      } else if (beatProgress < 0.20) {
        val = amplitude * (1 - (beatProgress - 0.10) / 0.10);
      } else if (beatProgress < 0.22) {
        val = -amplitude * 0.15;
      }
      result.add(val);
    }
    return result;
  }

  List<double> _asystole(int n) => List.filled(n, 0);

  List<double> _irregularRhythm(int n) {
    final result = <double>[];
    final rnd = Random();
    int beatCounter = 0;
    int nextBeat = 15 + rnd.nextInt(15);
    for (int i = 0; i < n; i++) {
      if (beatCounter == nextBeat) {
        result.addAll(_qrsComplex(8, 0.5));
        beatCounter = 0;
        nextBeat = 12 + rnd.nextInt(18);
      } else {
        result.add(rnd.nextDouble() * 0.08);
        beatCounter++;
      }
    }
    return result;
  }

  List<double> _bavRhythm(int n) {
    final result = <double>[];
    int pCounter = 0;
    int qrsCounter = 0;
    for (int i = 0; i < n; i++) {
      double val = 0;
      if (pCounter % 14 < 2) {
        val = 0.15 * sin((pCounter % 14) / 2.0 * pi);
      }
      if (qrsCounter % 42 < 8) {
        val += 0.5 * sin((qrsCounter % 42) / 8.0 * pi);
      }
      result.add(val);
      pCounter++;
      qrsCounter++;
    }
    return result;
  }

  List<double> _qrsComplex(int length, double amplitude) {
    return List.generate(length, (i) {
      final p = i / length;
      if (p < 0.2) return -amplitude * 0.3;
      if (p < 0.5) return amplitude * ((p - 0.2) / 0.3);
      return amplitude * (1 - (p - 0.5) / 0.5);
    });
  }

  @override
  bool shouldRepaint(_EcgTracePainter oldDelegate) =>
      oldDelegate.rhythm != rhythm || oldDelegate.color != color;
}

// ─── Pantalla de evaluación ───────────────────────────────────────────────────
class _EvalDetailScreen extends StatefulWidget {
  final _EvalScenario eval;
  const _EvalDetailScreen({super.key, required this.eval});

  @override
  State<_EvalDetailScreen> createState() => _EvalDetailScreenState();
}

class _EvalDetailScreenState extends State<_EvalDetailScreen>
    with SingleTickerProviderStateMixin {
  int _currentQ = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _correctCount = 0;
  bool _finished = false;
  final List<bool> _results = [];
  int _xpEarned = 0;
  int _levelAfter = 0;
  final EcgAudioService _audio = EcgAudioService();
  bool _audioReady = false;
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  Timer? _questionTimer;
  int _timeLeft = 30;
  int _totalTimeUsed = 0;
  final List<int> _timePerQuestion = [];

  @override
  void initState() {
    super.initState();
    _audio.init().then((_) {
      if (mounted) {
        setState(() => _audioReady = true);
        _playEcgRhythm();
      }
    });
    _ticker = createTicker((elapsed) {
      setState(() => _elapsed = elapsed);
      if (!_audio.muted && !_answered && _audioReady) {
        _tickSound();
      }
    })..start();
    _startTimer();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _audio.dispose();
    _questionTimer?.cancel();
    super.dispose();
  }

  EcgRhythmTypeForAudio _toAudioType(_EcgRhythmType? t) {
    switch (t) {
      case _EcgRhythmType.fv: return EcgRhythmTypeForAudio.fv;
      case _EcgRhythmType.tv: return EcgRhythmTypeForAudio.tv;
      case _EcgRhythmType.asistolia: return EcgRhythmTypeForAudio.asistolia;
      case _EcgRhythmType.aesp: return EcgRhythmTypeForAudio.aesp;
      case _EcgRhythmType.normal: return EcgRhythmTypeForAudio.normal;
      case _EcgRhythmType.fa: return EcgRhythmTypeForAudio.fa;
      case _EcgRhythmType.bav: return EcgRhythmTypeForAudio.bav;
      case _EcgRhythmType.tsv: return EcgRhythmTypeForAudio.tsv;
      default: return EcgRhythmTypeForAudio.normal;
    }
  }

  void _playEcgRhythm() {
    final rt = widget.eval.ecgRhythm;
    if (rt != null && _audioReady) {
      _audio.playRhythmLoop(_toAudioType(rt));
    }
  }

  int _lastTickSecond = -1;
  void _tickSound() {
    final sec = _elapsed.inSeconds;
    if (sec != _lastTickSecond) {
      _lastTickSecond = sec;
      _audio.playTick();
    }
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
          _audio.playWrong();
          HapticFeedback.heavyImpact();
          _selectAnswer(-1);
        }
      });
    });
  }

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
    _questionTimer?.cancel();
    final timeUsed = 30 - _timeLeft;
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
      _timePerQuestion.add(timeUsed);
      _totalTimeUsed += timeUsed;
      final correct = idx >= 0 && idx == _sessionQuestions[_currentQ].correctIndex;
      if (correct) {
        _correctCount++;
        _audio.playCorrect();
      } else {
        _audio.playWrong();
      }
      _results.add(correct);
    });
  }

  void _next() {
    _questionTimer?.cancel();
    if (_currentQ < _sessionQuestions.length - 1) {
      _lastTickSecond = -1;
      setState(() {
        _currentQ++;
        _selectedAnswer = null;
        _answered = false;
      });
      _startTimer();
      _playEcgRhythm();
    } else {
      setState(() => _finished = true);
      _audio.playCompletionChime();
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
        'topicId': widget.eval.id,
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
                  const SizedBox(width: 6),
                  // Timer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    decoration: BoxDecoration(
                      color: _timeLeft <= 10
                          ? Colors.red.withValues(alpha: 0.15)
                          : widget.eval.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _timeLeft <= 10 ? Icons.timer_off_outlined : Icons.timer_outlined,
                          size: 12,
                          color: _timeLeft <= 10 ? Colors.red : widget.eval.color,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${_timeLeft}s',
                          style: TextStyle(
                            color: _timeLeft <= 10 ? Colors.red : widget.eval.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Mute button
                  GestureDetector(
                    onTap: () => setState(() => _audio.muted = !_audio.muted),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: _audio.muted
                            ? Colors.grey.withValues(alpha: 0.2)
                            : widget.eval.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        _audio.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        size: 16,
                        color: _audio.muted ? Colors.grey : widget.eval.color,
                      ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                    if (widget.eval.ecgRhythm != null) ...[
                      const SizedBox(height: 10),
                      _EcgMiniWave(
                        rhythm: widget.eval.ecgRhythm!,
                        height: 60,
                        label: widget.eval.ecgRhythmLabel,
                        heartRate: widget.eval.ecgHeartRate,
                      ),
                    ],
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
