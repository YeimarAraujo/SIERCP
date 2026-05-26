/**
 * Seed script: populates quizTopics and quizQuestions in Firestore.
 * Run from the functions/ directory:
 *   node seed-quiz-data.js
 *
 * Requires firebase-admin (already installed) and GOOGLE_APPLICATION_CREDENTIALS
 * OR the Firebase emulator running locally.
 */

const admin = require("firebase-admin");

const path = require("path");

if (!admin.apps.length) {
  const serviceAccount = require(path.join(__dirname, "../scripts/service-account.json"));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

// ─── Topics ──────────────────────────────────────────────────────────────────

const topics = [
  {
    id: "rcp_adulto_bls",
    title: "RCP Adulto — BLS",
    description: "Fundamentos del soporte vital básico en adultos según AHA 2020/2025.",
    category: "rcp",
    questionCount: 10,
    durationSeconds: 600,
    timePerQuestion: 60,
    passingScore: 70,
    isActive: true,
    order: 1,
  },
  {
    id: "dea_desfibrilacion",
    title: "DEA y Desfibrilación",
    description: "Uso del desfibrilador externo automático y manejo de ritmos desfibrilables.",
    category: "rcp",
    questionCount: 10,
    durationSeconds: 600,
    timePerQuestion: 60,
    passingScore: 70,
    isActive: true,
    order: 2,
  },
  {
    id: "rcp_pediatrico",
    title: "RCP Pediátrico y Lactante",
    description: "Soporte vital básico en niños y lactantes: diferencias clave vs adulto.",
    category: "pediatrico",
    questionCount: 10,
    durationSeconds: 600,
    timePerQuestion: 60,
    passingScore: 70,
    isActive: true,
    order: 3,
  },
  {
    id: "ovace_primeros_auxilios",
    title: "OVACE y Primeros Auxilios",
    description: "Manejo de obstrucción de vía aérea y situaciones de emergencia frecuentes.",
    category: "rcp",
    questionCount: 10,
    durationSeconds: 600,
    timePerQuestion: 60,
    passingScore: 70,
    isActive: true,
    order: 4,
  },
  {
    id: "ecg_basico",
    title: "Electrocardiografía Básica",
    description: "Reconocimiento de ritmos cardíacos críticos: FV, TVSP, asistolia y AESP.",
    category: "ecg",
    questionCount: 10,
    durationSeconds: 600,
    timePerQuestion: 60,
    passingScore: 70,
    isActive: true,
    order: 5,
  },
];

// ─── Questions per topic ──────────────────────────────────────────────────────

const questions = {

  rcp_adulto_bls: [
    {
      text: "¿Cuál es la frecuencia correcta de compresiones torácicas en adultos según AHA 2020?",
      options: ["60–80 compresiones/min", "80–100 compresiones/min", "100–120 compresiones/min", "Más de 120 compresiones/min"],
      correctOption: "C",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Cuál es la profundidad de compresión correcta en adultos?",
      options: ["2–3 cm", "3–4 cm", "5–6 cm", "Más de 6 cm"],
      correctOption: "C",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Qué significa 'recoil completo' y por qué es importante?",
      options: [
        "La velocidad a la que comprimes el tórax",
        "Permitir que el tórax se expanda totalmente entre compresiones",
        "La fuerza máxima en cada compresión",
        "La relación compresión/ventilación",
      ],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Cuál es la relación compresión:ventilación estándar en RCP para adultos con un rescatador?",
      options: ["15:2", "30:2", "30:1", "15:1"],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "Encuentras a un adulto inconsciente. ¿Cuál es tu primer paso?",
      options: [
        "Iniciar compresiones de inmediato",
        "Verificar seguridad de la escena y luego verificar respuesta",
        "Dar 2 ventilaciones iniciales",
        "Buscar el DEA",
      ],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Cuánto tiempo máximo debes dedicar a verificar el pulso antes de iniciar RCP?",
      options: ["5 segundos", "10 segundos", "15 segundos", "30 segundos"],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Cuál es la fracción de compresión torácica (CCF) mínima recomendada por AHA?",
      options: ["≥ 40%", "≥ 50%", "≥ 60%", "≥ 80%"],
      correctOption: "C",
      level: "intermediate",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Cuántos cm³ de aire se insuflan en cada ventilación de rescate para adultos?",
      options: [
        "El suficiente para elevar el tórax visiblemente (500–600 mL)",
        "1000–1200 mL para asegurar oxigenación",
        "300–400 mL como en neonatos",
        "No importa el volumen, solo la velocidad",
      ],
      correctOption: "A",
      level: "intermediate",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Con qué frecuencia deben alternarse los rescatadores durante la RCP para mantener la calidad?",
      options: ["Cada 5 minutos", "Cada 2 minutos", "Cada 10 minutos", "Solo cuando uno se canse"],
      correctOption: "B",
      level: "intermediate",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "AHA 2025 actualizó el protocolo de OVACE en adultos. ¿Cuál es el cambio principal?",
      options: [
        "Solo golpes en la espalda, sin empujes abdominales",
        "5 golpes interescapulares + 5 empujes abdominales alternados",
        "10 empujes abdominales continuos",
        "No hubo cambios respecto a 2020",
      ],
      correctOption: "B",
      level: "advanced",
      source: "AHA 2025 CPR/ECC Update",
    },
  ],

  dea_desfibrilacion: [
    {
      text: "¿Cuánto reduce la supervivencia en FV cada minuto sin desfibrilación?",
      options: ["1–2% por minuto", "5% por minuto", "7–10% por minuto", "15% por minuto"],
      correctOption: "C",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Dónde se colocan los electrodos del DEA (posición estándar anterolateral)?",
      options: [
        "Ambos en el lado izquierdo del tórax",
        "Uno bajo la clavícula derecha y otro en el costado izquierdo bajo la axila",
        "Ambos en el centro del pecho",
        "Uno en el pecho y otro siempre en la espalda",
      ],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "Tras la descarga del DEA, ¿qué debes hacer inmediatamente?",
      options: [
        "Verificar el pulso durante 10 segundos",
        "Esperar 2 minutos antes de tocar al paciente",
        "Reanudar RCP de inmediato, comenzando por compresiones",
        "Revisar el ritmo en el monitor",
      ],
      correctOption: "C",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Cuándo debes pausar las compresiones para el análisis del DEA?",
      options: [
        "Solo cuando el DEA lo indique",
        "Cada 2 minutos independientemente",
        "Nunca, el DEA analiza mientras se comprimen",
        "Tras el primer choque",
      ],
      correctOption: "A",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Cuál es el ritmo más frecuente en el paro cardíaco súbito en adultos?",
      options: ["Asistolia", "AESP (Actividad Eléctrica sin Pulso)", "Fibrilación Ventricular (FV)", "Bradicardia sinusal"],
      correctOption: "C",
      level: "intermediate",
      source: "AHA 2020 ACLS Guidelines",
    },
    {
      text: "¿Cuál es la máxima pausa permitida entre la última compresión y la descarga del DEA?",
      options: ["5 segundos", "10 segundos", "15 segundos", "No hay límite"],
      correctOption: "A",
      level: "intermediate",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "El DEA indica 'No se recomienda descarga'. ¿Qué significa esto?",
      options: [
        "El paciente no tiene arritmia; verifica el pulso y continúa RCP si no hay pulso",
        "El paciente se ha recuperado completamente",
        "El DEA está defectuoso",
        "Debes aumentar la frecuencia de compresiones",
      ],
      correctOption: "A",
      level: "intermediate",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "Un niño de 6 años está en paro. ¿Cuáles son los electrodos correctos del DEA?",
      options: [
        "Electrodos de adulto, posición estándar",
        "Electrodos pediátricos (< 8 años / < 25 kg); si no hay, usar de adulto sin sobreposición",
        "Solo los de adulto, los pediátricos no existen",
        "No se usa DEA en menores de 8 años",
      ],
      correctOption: "B",
      level: "advanced",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Qué ritmos son DESFIBRILABLES?",
      options: [
        "Asistolia y AESP",
        "Fibrilación ventricular (FV) y Taquicardia ventricular sin pulso (TVSP)",
        "Bradicardia y bloqueo AV completo",
        "Todos los ritmos anormales",
      ],
      correctOption: "B",
      level: "intermediate",
      source: "AHA 2020 ACLS Guidelines",
    },
    {
      text: "¿Por qué NO se debe verificar el pulso inmediatamente después de cada descarga del DEA?",
      options: [
        "No hay razón, sí se debe verificar",
        "Porque la verificación interrumpe el flujo coronario; se reanuda RCP de inmediato",
        "Porque el DEA sigue analizando",
        "Porque la descarga siempre restaura el pulso",
      ],
      correctOption: "B",
      level: "advanced",
      source: "AHA 2020 BLS Guidelines",
    },
  ],

  rcp_pediatrico: [
    {
      text: "Con un solo rescatador y un niño (1–8 años) en paro, ¿cuál es la relación compresión:ventilación?",
      options: ["15:2", "30:2", "30:1", "15:1"],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Cuál es la profundidad de compresión correcta en niños de 1–8 años?",
      options: ["2–3 cm", "Aprox. 5 cm (1/3 diámetro AP tórax)", "5–6 cm igual que adultos", "1–2 cm"],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Dónde se palpa el pulso en un lactante menor de 1 año?",
      options: ["Arteria carótida", "Arteria radial", "Arteria braquial (cara interna del brazo)", "Arteria femoral"],
      correctOption: "C",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "Con dos rescatadores entrenados en pediatría y un niño en paro, ¿qué relación se usa?",
      options: ["30:2", "15:2", "10:2", "20:2"],
      correctOption: "B",
      level: "intermediate",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Qué técnica se usa para comprimir el tórax de un lactante con un solo rescatador?",
      options: [
        "Dos pulgares rodeando el tórax",
        "Dos dedos (índice y medio) sobre el esternón",
        "Una mano completa",
        "Palma de la mano",
      ],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "Estás solo con un niño en paro. ¿Qué haces primero?",
      options: [
        "Ir a buscar un DEA antes de iniciar RCP",
        "Llamar al 123 y luego empezar RCP",
        "Hacer 2 minutos de RCP antes de llamar al 123",
        "Gritar pidiendo ayuda e iniciar RCP; llamar tras 2 minutos",
      ],
      correctOption: "D",
      level: "intermediate",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Cómo se realizan las ventilaciones en un lactante?",
      options: [
        "Solo boca a boca como en adultos",
        "Boca a boca-nariz cubriendo boca Y nariz simultáneamente",
        "Solo insuflando por la nariz",
        "Con mascarilla de adulto",
      ],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Cuál es la profundidad correcta de compresión en lactantes (< 1 año)?",
      options: ["Aprox. 4 cm (1/3 del diámetro AP)", "5–6 cm", "1 cm", "4–5 cm"],
      correctOption: "A",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Por qué el paro cardíaco pediátrico es principalmente de causa respiratoria?",
      options: [
        "Los niños tienen corazones más débiles",
        "Las vías aéreas pediátricas son más pequeñas y se obstruyen fácilmente, causando hipoxia primaria",
        "Es lo mismo que en adultos",
        "Por factores genéticos",
      ],
      correctOption: "B",
      level: "intermediate",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Cuándo está indicado el uso del DEA en lactantes (< 1 año)?",
      options: [
        "No se usa DEA en lactantes",
        "Solo si el lactante pesa más de 5 kg",
        "Sí, si no hay otro recurso; se prefieren electrodos manuales de desfibrilador",
        "Solo en hospitales",
      ],
      correctOption: "C",
      level: "advanced",
      source: "AHA 2020 BLS Guidelines",
    },
  ],

  ovace_primeros_auxilios: [
    {
      text: "¿Cuál es el signo universal de obstrucción de vía aérea (OVACE)?",
      options: [
        "Cianosis perioral",
        "Llevarse las manos al cuello (gesto de asfixia)",
        "Pérdida de consciencia",
        "Tos productiva fuerte",
      ],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "Víctima consciente con obstrucción COMPLETA de vía aérea. ¿Qué haces?",
      options: [
        "Dar 5 golpes en la espalda y 5 empujes abdominales alternados (AHA 2025)",
        "Solo empujes abdominales continuos hasta desobstruir",
        "Solo golpes en la espalda, sin empujes",
        "Colocarla en posición de recuperación y esperar",
      ],
      correctOption: "A",
      level: "basic",
      source: "AHA 2025 CPR/ECC Update",
    },
    {
      text: "En paciente obesa o embarazada con OVACE, ¿qué reemplaza a los empujes abdominales?",
      options: [
        "Más golpes en la espalda",
        "Empujes torácicos sobre el esternón",
        "Compresiones de RCP directamente",
        "No se interviene",
      ],
      correctOption: "B",
      level: "intermediate",
      source: "AHA 2020/2025 BLS Guidelines",
    },
    {
      text: "La víctima con OVACE pierde el conocimiento. ¿Qué haces?",
      options: [
        "Continuar golpes en la espalda en el suelo",
        "Recostarlo con cuidado, iniciar RCP 30:2 e inspeccionar boca antes de cada ventilación",
        "Hacer solo empujes abdominales en el suelo",
        "Esperar a que recupere la consciencia",
      ],
      correctOption: "B",
      level: "intermediate",
      source: "AHA 2025 CPR/ECC Update",
    },
    {
      text: "¿Cuándo está indicada la maniobra de Heimlich en lactantes?",
      options: [
        "Nunca, se usan golpes en la espalda y compresiones torácicas",
        "Siempre que haya OVACE",
        "Solo en lactantes mayores de 6 meses",
        "Solo si el lactante está inconsciente",
      ],
      correctOption: "A",
      level: "intermediate",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Cómo se maneja la OVACE en un lactante consciente?",
      options: [
        "Empujes abdominales como en adultos",
        "5 golpes en la espalda + 5 compresiones torácicas alternados",
        "Solo golpes en la espalda",
        "Solo compresiones torácicas",
      ],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Qué significa OVACE parcial y cómo se maneja?",
      options: [
        "Obstrucción completa; aplicar Heimlich de inmediato",
        "Obstrucción incompleta con tos efectiva; animar a toser, observar",
        "Obstrucción que solo afecta a adultos",
        "Obstrucción que requiere intubación",
      ],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "En una víctima de ahogamiento con pulso débil pero sin respiración, ¿qué intervención es prioritaria?",
      options: [
        "Compresiones torácicas de inmediato",
        "Ventilaciones de rescate (1 cada 5–6 seg) sin compresiones",
        "Colocar en posición de recuperación y esperar",
        "Aplicar DEA antes de ventilar",
      ],
      correctOption: "B",
      level: "advanced",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "¿Cuántas ventilaciones de rescate iniciales se administran en paro por ahogamiento?",
      options: [
        "Ninguna; ir directo a 30 compresiones",
        "2 ventilaciones iniciales como en paro estándar",
        "5 ventilaciones iniciales, luego ciclos 30:2",
        "10 ventilaciones antes de comprimir",
      ],
      correctOption: "C",
      level: "advanced",
      source: "AHA 2020 BLS Guidelines",
    },
    {
      text: "Víctima de electrocución. ¿Cuál es el primer paso ANTES de tocarla?",
      options: [
        "Iniciar RCP de inmediato",
        "Verificar que la fuente eléctrica esté completamente desconectada",
        "Llamar al 123",
        "Aplicar el DEA",
      ],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 BLS Guidelines",
    },
  ],

  ecg_basico: [
    {
      text: "¿Cuál de los siguientes es un ritmo desfibrilable?",
      options: [
        "Asistolia",
        "Actividad eléctrica sin pulso (AESP)",
        "Fibrilación ventricular (FV)",
        "Bradicardia sinusal",
      ],
      correctOption: "C",
      level: "basic",
      source: "AHA 2020 ACLS Guidelines",
    },
    {
      text: "¿Cómo se ve la fibrilación ventricular en el ECG?",
      options: [
        "Línea completamente plana (isoeléctrica)",
        "Complejos QRS anchos y regulares muy rápidos",
        "Ondas caóticas, irregulares, sin QRS identificable",
        "Ondas P normales sin QRS",
      ],
      correctOption: "C",
      level: "basic",
      source: "AHA 2020 ACLS Guidelines",
    },
    {
      text: "¿Cuál es la característica principal de la asistolia en el ECG?",
      options: [
        "Ondas P sin QRS",
        "Línea plana (puede haber ondas P ocasionales)",
        "Complejos QRS anchos y lentos",
        "Ondas de fibrilación finas",
      ],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 ACLS Guidelines",
    },
    {
      text: "¿Qué es la taquicardia ventricular sin pulso (TVSP) y cómo se trata?",
      options: [
        "Ritmo rápido con pulso palpable; se trata con medicación",
        "Complejos QRS anchos y rápidos sin pulso palpable; se trata con desfibrilación",
        "Fibrilación auricular rápida; se trata con cardioversión sincronizada",
        "Ritmo normal acelerado; no requiere tratamiento",
      ],
      correctOption: "B",
      level: "intermediate",
      source: "AHA 2020 ACLS Guidelines",
    },
    {
      text: "¿Qué es la AESP (Actividad Eléctrica Sin Pulso)?",
      options: [
        "Ritmo eléctrico organizado sin pulso palpable (ritmo no desfibrilable)",
        "Fibrilación ventricular fina",
        "Asistolia completa sin actividad eléctrica",
        "Taquicardia supraventricular",
      ],
      correctOption: "A",
      level: "intermediate",
      source: "AHA 2020 ACLS Guidelines",
    },
    {
      text: "¿Por qué la asistolia NO se desfibr ila?",
      options: [
        "El voltaje del DEA no es suficiente",
        "No hay actividad eléctrica caótica que organizar; desfibrilar no produce efecto",
        "Solo se desfibril a en hospitales",
        "La asistolia sí es desfibrilable",
      ],
      correctOption: "B",
      level: "intermediate",
      source: "AHA 2020 ACLS Guidelines",
    },
    {
      text: "Un paciente en FV refractaria recibe su tercer choque. ¿Qué fármaco se administra a continuación según ACLS?",
      options: ["Atropina", "Adenosina", "Amiodarona o Lidocaína", "Dopamina"],
      correctOption: "C",
      level: "advanced",
      source: "AHA 2020 ACLS Guidelines",
    },
    {
      text: "¿Qué patrón ECG se asocia con infarto de miocardio con elevación del ST (STEMI)?",
      options: [
        "Depresión del segmento ST > 0.5 mm",
        "Elevación del segmento ST ≥ 1 mm en ≥ 2 derivaciones contiguas",
        "QT prolongado",
        "Bloqueo de rama izquierda aislado",
      ],
      correctOption: "B",
      level: "intermediate",
      source: "AHA 2020 ACLS Guidelines",
    },
    {
      text: "¿Cuál es la frecuencia cardíaca normal en un adulto en reposo?",
      options: ["40–60 lpm", "60–100 lpm", "100–120 lpm", "Más de 120 lpm"],
      correctOption: "B",
      level: "basic",
      source: "AHA 2020 ACLS Guidelines",
    },
    {
      text: "¿Qué arritmia se reconoce por ondas P irregulares sin relación con QRS y respuesta ventricular irregular?",
      options: [
        "Flutter auricular",
        "Taquicardia sinusal",
        "Fibrilación auricular (FA)",
        "Bloqueo AV de primer grado",
      ],
      correctOption: "C",
      level: "advanced",
      source: "AHA 2020 ACLS Guidelines",
    },
  ],
};

// ─── Seed function ────────────────────────────────────────────────────────────

async function seed() {
  console.log("🌱 Iniciando seed de quiz topics y questions...\n");

  const batch = db.batch();

  // Write topics
  for (const topic of topics) {
    const { id, ...data } = topic;
    const ref = db.collection("quizTopics").doc(id);
    batch.set(ref, {
      ...data,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ✓ Topic: ${data.title} (${id})`);
  }

  await batch.commit();
  console.log("\n✅ Topics guardados.\n");

  // Write questions per topic
  for (const [topicId, qs] of Object.entries(questions)) {
    const qBatch = db.batch();
    for (let i = 0; i < qs.length; i++) {
      const q = qs[i];
      const ref = db.collection("quizQuestions").doc();
      qBatch.set(ref, {
        topicId,
        ...q,
        isActive: true,
        order: i + 1,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await qBatch.commit();
    console.log(`  ✓ ${qs.length} preguntas para: ${topicId}`);
  }

  console.log("\n🎉 Seed completado exitosamente.");
  process.exit(0);
}

seed().catch((err) => {
  console.error("❌ Error durante el seed:", err);
  process.exit(1);
});
