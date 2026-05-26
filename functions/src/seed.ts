import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// SEED DATA — quizTopics y quizQuestions
// Ejecutar UNA VEZ: llamar a seedQuizData desde la app de admin
// ─────────────────────────────────────────────────────────────────────────────

export const seedQuizData = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sin auth.");

  const callerDoc = await db.collection("users").doc(request.auth.uid).get();
  if (callerDoc.data()?.role !== "SUPER_ADMIN") {
    throw new HttpsError("permission-denied", "Solo SUPER_ADMIN.");
  }

  const batch = db.batch();
  const now = admin.firestore.Timestamp.now();

  // ── TOPICS ────────────────────────────────────────────────────────────────
  const topics = [
    {
      id: "rcp",
      title: "RCP — Reanimación Cardiopulmonar",
      slug: "rcp",
      description: "Protocolos AHA 2025: frecuencia, profundidad, relaciones compresión-ventilación y ciclos.",
      iconName: "monitor_heart",
      color: "#DC2626",
      level: "basico",
      category: "rcp",
      order: 1,
      totalQuestions: 10,
      questionsPerQuiz: 10,
      passingScore: 70,
      timePerQuestion: 30,
      isActive: true,
      requiresPlan: null,
      imageUrl: null,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "primeros_auxilios",
      title: "Primeros Auxilios",
      slug: "primeros_auxilios",
      description: "Evaluación primaria, control de hemorragias, heridas, quemaduras y traumas.",
      iconName: "medical_services",
      color: "#059669",
      level: "basico",
      category: "primeros_auxilios",
      order: 2,
      totalQuestions: 10,
      questionsPerQuiz: 10,
      passingScore: 70,
      timePerQuestion: 30,
      isActive: true,
      requiresPlan: null,
      imageUrl: null,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "ecg",
      title: "Electrocardiograma Básico",
      slug: "ecg",
      description: "Lectura de ritmos cardíacos, identificación de arritmias y criterios AHA.",
      iconName: "ecg_heart",
      color: "#7C3AED",
      level: "intermedio",
      category: "ecg",
      order: 3,
      totalQuestions: 10,
      questionsPerQuiz: 10,
      passingScore: 75,
      timePerQuestion: 45,
      isActive: true,
      requiresPlan: "business",
      imageUrl: null,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "prehospitalario",
      title: "Atención Prehospitalaria",
      slug: "prehospitalario",
      description: "Triage START, inmovilización cervical, manejo de vía aérea y transporte de pacientes.",
      iconName: "emergency",
      color: "#0F4C81",
      level: "intermedio",
      category: "prehospitalario",
      order: 4,
      totalQuestions: 10,
      questionsPerQuiz: 10,
      passingScore: 75,
      timePerQuestion: 40,
      isActive: true,
      requiresPlan: null,
      imageUrl: null,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "signos_vitales",
      title: "Signos Vitales",
      slug: "signos_vitales",
      description: "Medición e interpretación de PA, FC, FR, temperatura y saturación de oxígeno.",
      iconName: "vital_signs",
      color: "#D97706",
      level: "basico",
      category: "signos_vitales",
      order: 5,
      totalQuestions: 10,
      questionsPerQuiz: 10,
      passingScore: 70,
      timePerQuestion: 25,
      isActive: true,
      requiresPlan: null,
      imageUrl: null,
      createdAt: now,
      updatedAt: now,
    },
  ];

  for (const topic of topics) {
    const { id, ...data } = topic;
    batch.set(db.collection("quizTopics").doc(id), data);
  }

  // ── QUESTIONS — RCP ───────────────────────────────────────────────────────
  const rcpQuestions = [
    {
      text: "¿Cuál es la frecuencia correcta de compresiones torácicas en RCP adulto según AHA 2025?",
      options: [{ id: "A", text: "60–80/min" }, { id: "B", text: "100–120/min" }, { id: "C", text: "120–140/min" }, { id: "D", text: "80–100/min" }],
      correctOption: "B",
      explanation: "AHA 2025 establece 100–120 compresiones/min para adultos. Frecuencias menores reducen el gasto cardíaco; las mayores impiden la descompresión completa.",
      level: "basico", source: "AHA_2025",
    },
    {
      text: "¿Cuál es la profundidad mínima de compresión en un adulto?",
      options: [{ id: "A", text: "2 cm" }, { id: "B", text: "5 cm" }, { id: "C", text: "7 cm" }, { id: "D", text: "3 cm" }],
      correctOption: "B",
      explanation: "La AHA recomienda comprimir al menos 5 cm (2 pulgadas) sin superar los 6 cm para evitar fracturas costales.",
      level: "basico", source: "AHA_2025",
    },
    {
      text: "¿Cuál es la relación compresión-ventilación en RCP básico para adultos?",
      options: [{ id: "A", text: "15:2" }, { id: "B", text: "30:1" }, { id: "C", text: "30:2" }, { id: "D", text: "15:1" }],
      correctOption: "C",
      explanation: "30:2 es la relación estándar para RCP con 1 o 2 reanimadores en adultos. Esto maximiza la perfusión coronaria y cerebral.",
      level: "basico", source: "AHA_2025",
    },
    {
      text: "¿Qué significa CCF (Chest Compression Fraction)?",
      options: [
        { id: "A", text: "Fuerza aplicada en cada compresión" },
        { id: "B", text: "Porcentaje del tiempo en paro que se realizan compresiones" },
        { id: "C", text: "Número de compresiones correctas" },
        { id: "D", text: "Profundidad promedio de compresión" },
      ],
      correctOption: "B",
      explanation: "CCF es la fracción del tiempo total en paro cardíaco en que se realizan compresiones. AHA recomienda un CCF ≥ 80%.",
      level: "intermedio", source: "AHA_2025",
    },
    {
      text: "En RCP con 2 reanimadores y vía aérea avanzada, ¿cuál es la frecuencia de ventilaciones?",
      options: [{ id: "A", text: "10–12/min" }, { id: "B", text: "6–8/min" }, { id: "C", text: "15–20/min" }, { id: "D", text: "1 cada 5 seg" }],
      correctOption: "A",
      explanation: "Con vía aérea avanzada (tubo ET o supraglótico), se dan 10–12 ventilaciones/min de forma asincrónica con las compresiones continuas.",
      level: "intermedio", source: "AHA_2025",
    },
    {
      text: "¿Cuándo se debe usar el DEA en un niño menor de 8 años?",
      options: [
        { id: "A", text: "Nunca; el DEA es solo para adultos" },
        { id: "B", text: "Siempre, con parches de adulto" },
        { id: "C", text: "Sí, preferiblemente con parches pediátricos o dosis reducida" },
        { id: "D", text: "Solo si el niño pesa más de 25 kg" },
      ],
      correctOption: "C",
      explanation: "En niños < 8 años o < 25 kg se prefieren parches pediátricos. Si no están disponibles, se usan los de adulto. El DEA es válido para detectar FV/TV.",
      level: "intermedio", source: "AHA_2025",
    },
    {
      text: "¿Qué se debe hacer INMEDIATAMENTE después de un choque con DEA?",
      options: [
        { id: "A", text: "Revisar pulso durante 10 segundos" },
        { id: "B", text: "Reiniciar RCP comenzando con compresiones" },
        { id: "C", text: "Administrar adrenalina" },
        { id: "D", text: "Esperar el análisis del DEA" },
      ],
      correctOption: "B",
      explanation: "Inmediatamente después del choque se reinician las compresiones sin verificar pulso; el DEA analiza al cabo de 2 minutos de RCP.",
      level: "basico", source: "AHA_2025",
    },
    {
      text: "¿Cuál es la primera acción ante una persona inconsciente en paro cardíaco?",
      options: [
        { id: "A", text: "Iniciar ventilaciones de rescate" },
        { id: "B", text: "Buscar el DEA" },
        { id: "C", text: "Activar el sistema de emergencias y comenzar RCP" },
        { id: "D", text: "Verificar la escena y pedir al testigo que llame al 123" },
      ],
      correctOption: "C",
      explanation: "La secuencia AHA: Reconocer el paro, activar el SEM (Sistema de Emergencias Médicas) e iniciar RCP de inmediato.",
      level: "basico", source: "AHA_2025",
    },
    {
      text: "¿Con qué frecuencia deben alternarse los reanimadores durante RCP prolongada?",
      options: [{ id: "A", text: "Cada 5 minutos" }, { id: "B", text: "Cada 2 minutos" }, { id: "C", text: "Cada 10 minutos" }, { id: "D", text: "Solo si uno se fatiga" }],
      correctOption: "B",
      explanation: "AHA recomienda rotar cada 2 minutos (al finalizar cada ciclo) para mantener la calidad de las compresiones y evitar fatiga.",
      level: "basico", source: "AHA_2025",
    },
    {
      text: "¿Cuál es el objetivo del recoil (descompresión completa) en RCP?",
      options: [
        { id: "A", text: "Reducir el dolor del paciente" },
        { id: "B", text: "Permitir que el corazón se llene de sangre antes de la próxima compresión" },
        { id: "C", text: "Evitar fracturas de costillas" },
        { id: "D", text: "Dar tiempo al reanimador para respirar" },
      ],
      correctOption: "B",
      explanation: "El recoil completo permite la expansión del tórax y el llenado ventricular. Sin él, la precarga y el gasto cardíaco se reducen significativamente.",
      level: "intermedio", source: "AHA_2025",
    },
  ];

  // ── QUESTIONS — Primeros Auxilios ─────────────────────────────────────────
  const primerosAuxiliosQuestions = [
    {
      text: "¿Cuál es el primer paso en la evaluación primaria de un paciente (ABCDE)?",
      options: [{ id: "A", text: "Breathing (respiración)" }, { id: "B", text: "Airway (vía aérea)" }, { id: "C", text: "Circulation (circulación)" }, { id: "D", text: "Disability (neurológico)" }],
      correctOption: "B",
      explanation: "La mnemotecnia ABCDE comienza con Airway: garantizar vía aérea permeable es la prioridad absoluta.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "Para controlar una hemorragia severa en una extremidad, ¿cuál es la técnica de primera elección?",
      options: [{ id: "A", text: "Torniquete" }, { id: "B", text: "Presión directa con apósito" }, { id: "C", text: "Elevación del miembro" }, { id: "D", text: "Vendaje compresivo" }],
      correctOption: "B",
      explanation: "La presión directa y sostenida es la primera línea. El torniquete se reserva para hemorragias que no ceden con presión directa.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "¿Cómo se clasifica una quemadura de 2do grado?",
      options: [
        { id: "A", text: "Solo enrojece la piel" },
        { id: "B", text: "Afecta epidermis y dermis, con ampollas" },
        { id: "C", text: "Carboniza los tejidos" },
        { id: "D", text: "Afecta huesos y tendones" },
      ],
      correctOption: "B",
      explanation: "Las quemaduras de 2do grado afectan epidermis y dermis, produciendo ampollas, dolor intenso y base eritematosa húmeda.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "¿Cuánto tiempo debe aplicarse frío sobre una quemadura leve?",
      options: [{ id: "A", text: "5 minutos" }, { id: "B", text: "10–20 minutos con agua fría" }, { id: "C", text: "30 minutos con hielo directo" }, { id: "D", text: "Hasta que el dolor cese" }],
      correctOption: "B",
      explanation: "Se aplica agua fría corriente por 10–20 min. Nunca hielo directo (produce vasoconstricción y empeora el daño tisular).",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "Un paciente con trauma de cráneo está inconsciente. ¿Cuál es la posición correcta?",
      options: [
        { id: "A", text: "Posición de recuperación (lateral)" },
        { id: "B", text: "Supino con inmovilización cervical" },
        { id: "C", text: "Fowler (semi-sentado)" },
        { id: "D", text: "Trendelenburg (piernas elevadas)" },
      ],
      correctOption: "B",
      explanation: "Ante trauma de cráneo, se presume lesión cervical. Se mantiene decúbito supino con estabilización manual de la columna cervical.",
      level: "intermedio", source: "MINSALUD",
    },
    {
      text: "¿Cuál es el signo característico de una fractura?",
      options: [
        { id: "A", text: "Solo dolor localizado" },
        { id: "B", text: "Crepitación, deformidad y movilidad anormal" },
        { id: "C", text: "Inflamación sin dolor" },
        { id: "D", text: "Hematoma sin deformidad" },
      ],
      correctOption: "B",
      explanation: "La tríada crepitación-deformidad-movilidad anormal es característica de fractura. El dolor es inespecífico.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "En caso de atragantamiento con obstrucción completa en adulto consciente, ¿qué se aplica?",
      options: [
        { id: "A", text: "5 golpes en la espalda solamente" },
        { id: "B", text: "5 golpes en la espalda + 5 compresiones abdominales (Heimlich)" },
        { id: "C", text: "Comprimir el cuello" },
        { id: "D", text: "Iniciar RCP de inmediato" },
      ],
      correctOption: "B",
      explanation: "AHA 2025: 5 golpes interescapulares alternados con 5 compresiones abdominales (maniobra de Heimlich) hasta desobstruir o que el paciente pierda la conciencia.",
      level: "basico", source: "AHA_2025",
    },
    {
      text: "¿Cómo se inmoviliza una fractura de antebrazo en primeros auxilios?",
      options: [
        { id: "A", text: "Sin inmovilizar, elevando el brazo" },
        { id: "B", text: "Fijando la articulación por encima y por debajo de la fractura" },
        { id: "C", text: "Reduciendo manualmente el hueso" },
        { id: "D", text: "Solo con vendaje compresivo" },
      ],
      correctOption: "B",
      explanation: "La inmovilización debe incluir las articulaciones proximal y distal a la fractura. Se usa férula improvizada y vendaje.",
      level: "intermedio", source: "MINSALUD",
    },
    {
      text: "¿Cuál es la posición lateral de seguridad (PLS) y cuándo se usa?",
      options: [
        { id: "A", text: "Boca arriba, cuando el paciente respira" },
        { id: "B", text: "De lado, para paciente inconsciente que respira sin sospecha de trauma cervical" },
        { id: "C", text: "Sentado, en caso de shock" },
        { id: "D", text: "Prono, para trauma abdominal" },
      ],
      correctOption: "B",
      explanation: "La PLS se usa en pacientes inconscientes que respiran espontáneamente para prevenir broncoaspiración, siempre que no haya sospecha de trauma cervical.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "¿Cuál es la definición de shock?",
      options: [
        { id: "A", text: "Pérdida de conciencia súbita" },
        { id: "B", text: "Perfusión tisular inadecuada que no satisface las demandas metabólicas" },
        { id: "C", text: "Presión arterial mayor a 180/110 mmHg" },
        { id: "D", text: "Frecuencia cardíaca por encima de 150/min" },
      ],
      correctOption: "B",
      explanation: "El shock es insuficiencia circulatoria aguda que resulta en hipoperfusión tisular. Puede ser hipovolémico, cardiogénico, distributivo u obstructivo.",
      level: "intermedio", source: "MINSALUD",
    },
  ];

  // ── QUESTIONS — ECG ───────────────────────────────────────────────────────
  const ecgQuestions = [
    {
      text: "¿Cuántos milímetros dura normalmente el intervalo PR en el ECG?",
      options: [{ id: "A", text: "0.08–0.12 seg (2–3 mm)" }, { id: "B", text: "0.12–0.20 seg (3–5 mm)" }, { id: "C", text: "0.20–0.40 seg (5–10 mm)" }, { id: "D", text: "0.04–0.08 seg (1–2 mm)" }],
      correctOption: "B",
      explanation: "El intervalo PR normal es 0.12–0.20 seg. Un PR > 0.20 seg sugiere bloqueo AV de 1er grado.",
      level: "intermedio", source: "AHA_2025",
    },
    {
      text: "¿Qué representa el complejo QRS en el ECG?",
      options: [
        { id: "A", text: "Despolarización auricular" },
        { id: "B", text: "Repolarización ventricular" },
        { id: "C", text: "Despolarización ventricular" },
        { id: "D", text: "Período refractario absoluto" },
      ],
      correctOption: "C",
      explanation: "El complejo QRS representa la despolarización ventricular (contracción). La repolarización ventricular se ve en la onda T.",
      level: "basico", source: "AHA_2025",
    },
    {
      text: "Un ritmo con ondas P ausentes y complejos QRS irregulares y de morfología variable sugiere:",
      options: [{ id: "A", text: "Taquicardia sinusal" }, { id: "B", text: "Fibrilación auricular" }, { id: "C", text: "Bloqueo AV 3er grado" }, { id: "D", text: "Flutter auricular" }],
      correctOption: "B",
      explanation: "La FA se caracteriza por ausencia de ondas P, línea de base irregular (ondas f) y respuesta ventricular irregularmente irregular.",
      level: "intermedio", source: "AHA_2025",
    },
    {
      text: "¿Qué ritmo se trata con RCP + desfibrilación inmediata?",
      options: [
        { id: "A", text: "Asistolia" },
        { id: "B", text: "Actividad eléctrica sin pulso (AESP)" },
        { id: "C", text: "Fibrilación ventricular (FV)" },
        { id: "D", text: "Taquicardia sinusal" },
      ],
      correctOption: "C",
      explanation: "FV y TV sin pulso son ritmos desfibrilables. La desfibrilación precoz es la intervención más efectiva.",
      level: "basico", source: "AHA_2025",
    },
    {
      text: "¿Cuántos mm de elevación del ST en ≥2 derivaciones contiguas se considera significativo para IAMCEST?",
      options: [{ id: "A", text: "0.5 mm" }, { id: "B", text: "1 mm" }, { id: "C", text: "3 mm" }, { id: "D", text: "5 mm" }],
      correctOption: "B",
      explanation: "≥ 1 mm (0.1 mV) de elevación del ST en dos o más derivaciones contiguas es criterio diagnóstico de IAMCEST (infarto con elevación del ST).",
      level: "avanzado", source: "AHA_2025",
    },
    {
      text: "¿Qué ritmo produce ondas en sierra (tipo diente de serrucho) con frecuencia auricular ~300/min?",
      options: [{ id: "A", text: "Fibrilación auricular" }, { id: "B", text: "Flutter auricular" }, { id: "C", text: "Taquicardia ventricular" }, { id: "D", text: "Taquicardia supraventricular" }],
      correctOption: "B",
      explanation: "El flutter auricular produce ondas F en sierra (300/min) con bloqueo fisiológico AV, generando respuesta ventricular de 150/min (2:1).",
      level: "intermedio", source: "AHA_2025",
    },
    {
      text: "¿Cuál es el criterio de duración del QRS para definir bloqueo de rama?",
      options: [{ id: "A", text: "> 0.08 seg" }, { id: "B", text: "> 0.10 seg" }, { id: "C", text: "> 0.12 seg" }, { id: "D", text: "> 0.20 seg" }],
      correctOption: "C",
      explanation: "Un QRS > 0.12 seg (120 ms) define bloqueo de rama completo. Entre 0.10–0.12 seg es bloqueo incompleto.",
      level: "avanzado", source: "AHA_2025",
    },
    {
      text: "La taquicardia de QRS ancho (> 0.12 seg) en un paciente inestable debe tratarse con:",
      options: [
        { id: "A", text: "Adenosina IV" },
        { id: "B", text: "Cardioversión eléctrica sincronizada inmediata" },
        { id: "C", text: "Metoprolol IV" },
        { id: "D", text: "Observación y ECG seriados" },
      ],
      correctOption: "B",
      explanation: "Paciente inestable (hipotensión, alteración de conciencia, dolor torácico) con taquicardia: cardioversión eléctrica sincronizada de inmediato.",
      level: "avanzado", source: "AHA_2025",
    },
    {
      text: "¿Qué onda del ECG representa la repolarización ventricular?",
      options: [{ id: "A", text: "Onda P" }, { id: "B", text: "Onda Q" }, { id: "C", text: "Onda T" }, { id: "D", text: "Onda U" }],
      correctOption: "C",
      explanation: "La onda T representa la repolarización ventricular. La onda U (cuando visible) puede indicar hipopotasemia.",
      level: "basico", source: "AHA_2025",
    },
    {
      text: "En el algoritmo ACLS para paro cardíaco, ¿con qué dosis inicial se administra Epinefrina?",
      options: [{ id: "A", text: "0.5 mg IV" }, { id: "B", text: "1 mg IV cada 3–5 min" }, { id: "C", text: "2 mg IV una sola dosis" }, { id: "D", text: "0.1 mg/kg IV" }],
      correctOption: "B",
      explanation: "Epinefrina 1 mg IV/IO cada 3–5 minutos es la dosis estándar en algoritmo ACLS para FV/TV refractaria y AESP/Asistolia.",
      level: "avanzado", source: "AHA_2025",
    },
  ];

  // ── QUESTIONS — Prehospitalario ───────────────────────────────────────────
  const prehospitalQuestions = [
    {
      text: "En el triage START, ¿qué color identifica a las víctimas que NO respiran después de abrir la vía aérea?",
      options: [{ id: "A", text: "Rojo" }, { id: "B", text: "Amarillo" }, { id: "C", text: "Negro" }, { id: "D", text: "Verde" }],
      correctOption: "C",
      explanation: "En START, si la víctima no respira incluso después de reposicionar la vía aérea, se clasifica como NEGRO (sin expectativa de sobrevida en el contexto de triage masivo).",
      level: "intermedio", source: "MINSALUD",
    },
    {
      text: "¿Cuál es la técnica correcta para apertura de vía aérea en víctima con sospecha de trauma cervical?",
      options: [
        { id: "A", text: "Hiperextensión de cabeza" },
        { id: "B", text: "Tracción mandibular (Jaw Thrust)" },
        { id: "C", text: "Compresión esternal" },
        { id: "D", text: "Rotación lateral de la cabeza" },
      ],
      correctOption: "B",
      explanation: "El Jaw Thrust (tracción mandibular) abre la vía aérea sin extender el cuello, preservando la alineación cervical en trauma.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "¿Qué significa el acrónimo SAMPLE en la valoración prehospitalaria?",
      options: [
        { id: "A", text: "Signos, Alergias, Medicamentos, Patologías, Last meal, Events" },
        { id: "B", text: "Síntomas, Alergias, Medicamentos, Patologías, Última ingesta, Eventos previos" },
        { id: "C", text: "Signos, Antecedentes, Medicamentos, Peso, Laboral, Enfermedades" },
        { id: "D", text: "Saturación, Alerta, Movilidad, Pulso, Laboratorio, Evolución" },
      ],
      correctOption: "B",
      explanation: "SAMPLE: Síntomas (Symptoms), Alergias, Medicamentos, Patologías (Past medical history), Última comida (Last oral intake), Eventos previos.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "La Escala de Coma de Glasgow (ECG) evalúa tres componentes. ¿Cuáles son?",
      options: [
        { id: "A", text: "Apertura ocular, Respuesta verbal, Respuesta motora" },
        { id: "B", text: "Pulso, Respiración, Conciencia" },
        { id: "C", text: "Presión arterial, Glasgow, Saturación" },
        { id: "D", text: "Color de piel, Reflejos, Temperatura" },
      ],
      correctOption: "A",
      explanation: "El Glasgow evalúa: Apertura ocular (1–4), Respuesta verbal (1–5) y Respuesta motora (1–6). Máximo: 15; Mínimo: 3.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "¿Cuál es la clasificación de un paciente con PA sistólica < 90 mmHg y FC > 120/min en triage?",
      options: [{ id: "A", text: "Verde — Menor" }, { id: "B", text: "Amarillo — Diferido" }, { id: "C", text: "Rojo — Inmediato" }, { id: "D", text: "Negro — Expectante" }],
      correctOption: "C",
      explanation: "Shock (hipotensión + taquicardia) indica compromiso hemodinámico grave → triage ROJO: requiere atención inmediata.",
      level: "intermedio", source: "MINSALUD",
    },
    {
      text: "¿Qué tipo de collar cervical se usa en trauma prehospitalario?",
      options: [
        { id: "A", text: "Collar blando o Philadelphia" },
        { id: "B", text: "Collar rígido tipo Philadelphia o similar" },
        { id: "C", text: "Vendaje tubular" },
        { id: "D", text: "Collar solo si hay dolor cervical" },
      ],
      correctOption: "B",
      explanation: "Se usa collar rígido (Philadelphia o equivalente) para inmovilización cervical efectiva. El collar blando no ofrece restricción de movimiento adecuada.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "¿Cuánto tiempo de 'hora dorada' se considera para un paciente con trauma grave?",
      options: [{ id: "A", text: "30 minutos" }, { id: "B", text: "60 minutos" }, { id: "C", text: "90 minutos" }, { id: "D", text: "120 minutos" }],
      correctOption: "B",
      explanation: "La 'hora dorada' de Cowley establece que el manejo definitivo de trauma grave idealmente debe ocurrir dentro de los primeros 60 minutos del accidente.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "¿Cuál es la vía de acceso de segunda línea cuando no es posible el acceso IV periférico en emergencia?",
      options: [
        { id: "A", text: "Vía oral" },
        { id: "B", text: "Acceso intraóseo (IO)" },
        { id: "C", text: "Vía intramuscular" },
        { id: "D", text: "Subcutánea" },
      ],
      correctOption: "B",
      explanation: "El acceso intraóseo (IO) es la vía alternativa de elección cuando el acceso IV periférico falla. Permite administración de líquidos y medicamentos a velocidades similares al IV.",
      level: "intermedio", source: "MINSALUD",
    },
    {
      text: "En un paciente con neumotórax a tensión, ¿cuál es la intervención prehospitalaria?",
      options: [
        { id: "A", text: "Intubación endotraqueal inmediata" },
        { id: "B", text: "Descompresión con aguja en 2do espacio intercostal, línea medioclavicular" },
        { id: "C", text: "RCP inmediato" },
        { id: "D", text: "Traslado urgente sin intervención" },
      ],
      correctOption: "B",
      explanation: "El neumotórax a tensión requiere descompresión inmediata: aguja 14–16G en 2do espacio intercostal línea medioclavicular del lado afectado.",
      level: "avanzado", source: "MINSALUD",
    },
    {
      text: "¿Cuál es el mecanismo principal de la hipotermia terapéutica post-PCR?",
      options: [
        { id: "A", text: "Reduce el gasto cardíaco" },
        { id: "B", text: "Reduce el metabolismo cerebral y el daño por reperfusión" },
        { id: "C", text: "Aumenta la diuresis" },
        { id: "D", text: "Dilata las arterias coronarias" },
      ],
      correctOption: "B",
      explanation: "La hipotermia terapéutica (32–36°C) reduce el metabolismo cerebral en ~6% por cada grado, limitando el daño neurológico por reperfusión post-PCR.",
      level: "avanzado", source: "AHA_2025",
    },
  ];

  // ── QUESTIONS — Signos Vitales ─────────────────────────────────────────────
  const signosVitalesQuestions = [
    {
      text: "¿Cuál es el rango normal de frecuencia cardíaca (FC) en adultos en reposo?",
      options: [{ id: "A", text: "40–60 lpm" }, { id: "B", text: "60–100 lpm" }, { id: "C", text: "100–120 lpm" }, { id: "D", text: "50–90 lpm" }],
      correctOption: "B",
      explanation: "La FC normal en adultos en reposo es 60–100 lpm. < 60 se denomina bradicardia; > 100 taquicardia.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "¿Qué valor de SpO2 (saturación de oxígeno) se considera normal a nivel del mar?",
      options: [{ id: "A", text: "80–90%" }, { id: "B", text: "90–94%" }, { id: "C", text: "95–100%" }, { id: "D", text: "70–80%" }],
      correctOption: "C",
      explanation: "SpO2 normal a nivel del mar: 95–100%. Valores < 95% indican hipoxemia; < 90% es hipoxemia severa y requiere intervención.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "¿Qué es la presión de pulso?",
      options: [
        { id: "A", text: "La presión diastólica" },
        { id: "B", text: "La diferencia entre PA sistólica y diastólica" },
        { id: "C", text: "La presión media arterial" },
        { id: "D", text: "La PA dividida entre la FC" },
      ],
      correctOption: "B",
      explanation: "Presión de pulso = PA sistólica – PA diastólica. Normal: 40–60 mmHg. < 25 puede indicar bajo gasto cardíaco.",
      level: "intermedio", source: "MINSALUD",
    },
    {
      text: "¿Cuál es el rango de temperatura corporal normal?",
      options: [{ id: "A", text: "35.5–37.5°C" }, { id: "B", text: "36.0–37.2°C" }, { id: "C", text: "37.0–38.0°C" }, { id: "D", text: "35.0–36.5°C" }],
      correctOption: "B",
      explanation: "La temperatura normal axilar es 36.0–37.2°C. La rectal es 0.5°C mayor. Fiebre se define ≥ 38°C.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "¿Cómo se calcula la presión arterial media (PAM)?",
      options: [
        { id: "A", text: "PAM = (sistólica + diastólica) / 2" },
        { id: "B", text: "PAM = diastólica + 1/3 × presión de pulso" },
        { id: "C", text: "PAM = sistólica – diastólica" },
        { id: "D", text: "PAM = sistólica / diastólica" },
      ],
      correctOption: "B",
      explanation: "PAM = diastólica + 1/3 × (sistólica – diastólica). También: PAM = (sistólica + 2×diastólica) / 3. Normal: 70–100 mmHg.",
      level: "intermedio", source: "MINSALUD",
    },
    {
      text: "¿Cuál es el rango normal de frecuencia respiratoria (FR) en adultos?",
      options: [{ id: "A", text: "8–12 rpm" }, { id: "B", text: "12–20 rpm" }, { id: "C", text: "20–30 rpm" }, { id: "D", text: "10–16 rpm" }],
      correctOption: "B",
      explanation: "FR normal adulto: 12–20 rpm. < 12 es bradipnea; > 20 taquipnea. > 30 rpm en adulto indica dificultad respiratoria severa.",
      level: "basico", source: "MINSALUD",
    },
    {
      text: "Un paciente con PA de 85/50 mmHg, FC 125 lpm y SpO2 92% tiene:",
      options: [
        { id: "A", text: "Estado hemodinámico normal" },
        { id: "B", text: "Signos de shock — requiere intervención inmediata" },
        { id: "C", text: "Solo deshidratación leve" },
        { id: "D", text: "Ansiedad e hiperventilación" },
      ],
      correctOption: "B",
      explanation: "Hipotensión + taquicardia + hipoxemia = shock. Requiere acceso IV, expansión de volumen y evaluación de causa. No esperar.",
      level: "intermedio", source: "MINSALUD",
    },
    {
      text: "¿Dónde se palpa el pulso central de elección en adultos durante emergencia?",
      options: [{ id: "A", text: "Radial" }, { id: "B", text: "Carotídeo" }, { id: "C", text: "Femoral" }, { id: "D", text: "Braquial" }],
      correctOption: "B",
      explanation: "El pulso carotídeo es el pulso central de elección en adultos. Está disponible sin mover al paciente y es detectado incluso con PA baja.",
      level: "basico", source: "AHA_2025",
    },
    {
      text: "¿Qué es la hipotensión ortostática?",
      options: [
        { id: "A", text: "PA elevada solo de noche" },
        { id: "B", text: "Caída de ≥20 mmHg sistólica o ≥10 mmHg diastólica al pasar de decúbito a bipedestación" },
        { id: "C", text: "PA variable según el brazo medido" },
        { id: "D", text: "FC que aumenta > 100 al pararse" },
      ],
      correctOption: "B",
      explanation: "Hipotensión ortostática: caída de ≥20 mmHg sistólica o ≥10 diastólica en los primeros 3 min al ponerse de pie. Causa: hipovolemia, medicamentos, disautonomía.",
      level: "intermedio", source: "MINSALUD",
    },
    {
      text: "¿Cuál es el sitio correcto para medir SpO2 con oxímetro de pulso?",
      options: [
        { id: "A", text: "Cualquier dedo, siempre en la mano derecha" },
        { id: "B", text: "Dedo índice o medio, evitando uñas pintadas o mala perfusión" },
        { id: "C", text: "Solo en el lóbulo de la oreja" },
        { id: "D", text: "En el centro del pecho" },
      ],
      correctOption: "B",
      explanation: "Se usa preferentemente índice o medio de cualquier mano. Las uñas con esmalte oscuro, frío extremo o mala perfusión afectan la lectura.",
      level: "basico", source: "MINSALUD",
    },
  ];

  // Insertar todas las preguntas en batch
  const questionSets = [
    { topicId: "rcp", questions: rcpQuestions },
    { topicId: "primeros_auxilios", questions: primerosAuxiliosQuestions },
    { topicId: "ecg", questions: ecgQuestions },
    { topicId: "prehospitalario", questions: prehospitalQuestions },
    { topicId: "signos_vitales", questions: signosVitalesQuestions },
  ];

  let questionCount = 0;
  for (const { topicId, questions } of questionSets) {
    for (const q of questions) {
      const ref = db.collection("quizQuestions").doc();
      batch.set(ref, {
        ...q,
        topicId,
        isActive: true,
        timesAnswered: 0,
        timesCorrect: 0,
        imageUrl: null,
        createdAt: now,
      });
      questionCount++;
    }
  }

  await batch.commit();

  return {
    success: true,
    topicsCreated: topics.length,
    questionsCreated: questionCount,
  };
});
