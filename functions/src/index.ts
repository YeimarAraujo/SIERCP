import * as admin from "firebase-admin";
import {
  onCall,
  HttpsError,
  onRequest,
} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

const XP_REWARDS: Record<string, number> = {
  quiz_passed: 20,
  quiz_perfect: 50,
  session_approved: 30,
  session_completed: 15,
  course_completed: 100,
  certificate_earned: 75,
  first_daily_quiz: 25,
};

const BADGES: Record<string, { name: string; icon: string; condition: string }> = {
  first_quiz:      { name: "Primer Quiz",       icon: "🧠", condition: "primer quiz completado" },
  quiz_perfect:    { name: "Quiz Perfecto",      icon: "⭐", condition: "100% en un quiz" },
  quiz_master:     { name: "Quiz Master",        icon: "🏆", condition: "5 quizzes con 90%+" },
  first_rcp:       { name: "Primer Rescate",     icon: "🫀", condition: "primera sesión RCP completada" },
  certified:       { name: "Certificado",        icon: "🏅", condition: "primer certificado emitido" },
  streak_7:        { name: "7 días seguidos",    icon: "🔥", condition: "7 días de práctica consecutivos" },
  all_topics:      { name: "Explorador",         icon: "🌐", condition: "quiz completado en 5 temas diferentes" },
  perfect_session: { name: "Técnica Perfecta",   icon: "💎", condition: "sesión RCP con score 100" },
};

const LEVEL_THRESHOLDS = [0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5500];

function calculateLevel(xp: number): number {
  return LEVEL_THRESHOLDS.filter((t) => xp >= t).length;
}

// ─────────────────────────────────────────────────────────────────────────────
// CF 1 — getQuizQuestions
// Callable: retorna N preguntas de un topicId SIN correctOption ni explanation
// ─────────────────────────────────────────────────────────────────────────────
export const getQuizQuestions = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Se requiere autenticación.");
  }

  const { topicId, count = 10 } = request.data as { topicId: string; count?: number };

  if (!topicId) {
    throw new HttpsError("invalid-argument", "topicId es requerido.");
  }

  // Verificar que el topic existe y está activo
  const topicDoc = await db.collection("quizTopics").doc(topicId).get();
  if (!topicDoc.exists || !topicDoc.data()?.isActive) {
    throw new HttpsError("not-found", "Tema no encontrado o inactivo.");
  }

  const topicData = topicDoc.data()!;

  // Verificar plan si el tema requiere uno
  if (topicData.requiresPlan) {
    const userId = request.auth.uid;
    const userDoc = await db.collection("users").doc(userId).get();
    const institutionId = userDoc.data()?.institutionId;
    if (institutionId) {
      const planDoc = await db
        .doc(`institutions/${institutionId}/planMembership/current`)
        .get();
      const planType = planDoc.data()?.planType;
      const planOrder = ["pyme", "business", "corporate", "enterprise"];
      const required = planOrder.indexOf(topicData.requiresPlan);
      const current = planOrder.indexOf(planType);
      if (current < required) {
        throw new HttpsError("permission-denied", "Tu plan no incluye este tema.");
      }
    }
  }

  // Obtener todas las preguntas activas del topic
  const qSnap = await db
    .collection("quizQuestions")
    .where("topicId", "==", topicId)
    .where("isActive", "==", true)
    .get();

  if (qSnap.empty) {
    throw new HttpsError("not-found", "No hay preguntas para este tema.");
  }

  const allQuestions = qSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const selected = shuffle(allQuestions).slice(0, Math.min(count, allQuestions.length));

  // Remover respuestas del payload — el servidor las valida al submit
  return {
    questions: selected.map((q: any) => ({
      id: q.id,
      text: q.text,
      options: q.options,
      imageUrl: q.imageUrl ?? null,
      level: q.level,
      // correctOption y explanation NO se envían al cliente
    })),
    topicTitle: topicData.title,
    timePerQuestion: topicData.timePerQuestion,
    timeLimitSeconds: topicData.timePerQuestion * count,
    passingScore: topicData.passingScore,
  };
});

// ─────────────────────────────────────────────────────────────────────────────
// CF 2 — submitQuizAnswers
// Callable: valida respuestas server-side, guarda quizSession, actualiza stats
// ─────────────────────────────────────────────────────────────────────────────
export const submitQuizAnswers = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Se requiere autenticación.");
  }

  const uid = request.auth.uid;
  const {
    topicId,
    answers,
    timeUsedSeconds,
    courseId = null,
    moduleId = null,
  } = request.data as {
    topicId: string;
    answers: { questionId: string; selectedOption: string }[];
    timeUsedSeconds: number;
    courseId?: string | null;
    moduleId?: string | null;
  };

  if (!topicId || !answers?.length) {
    throw new HttpsError("invalid-argument", "topicId y answers son requeridos.");
  }

  // Obtener datos del usuario
  const userDoc = await db.collection("users").doc(uid).get();
  const userData = userDoc.data()!;

  // Obtener topic para metadata
  const topicDoc = await db.collection("quizTopics").doc(topicId).get();
  const topicData = topicDoc.data()!;

  // Obtener preguntas reales desde Firestore para validar
  const questionIds = answers.map((a) => a.questionId);
  const questionDocs = await Promise.all(
    questionIds.map((id) => db.collection("quizQuestions").doc(id).get())
  );

  let correct = 0;
  const detailedAnswers: any[] = [];
  const batch = db.batch();

  for (let i = 0; i < answers.length; i++) {
    const answer = answers[i];
    const qDoc = questionDocs[i];
    if (!qDoc.exists) continue;

    const qData = qDoc.data()!;
    const isCorrect = answer.selectedOption === qData.correctOption;
    if (isCorrect) correct++;

    detailedAnswers.push({
      questionId: answer.questionId,
      questionText: qData.text,
      selectedOption: answer.selectedOption,
      correctOption: qData.correctOption,
      isCorrect,
      timeUsedSeconds: 0, // el cliente puede pasar esto por respuesta si lo registra
      explanation: qData.explanation,
    });

    // Actualizar estadísticas de la pregunta
    batch.update(db.collection("quizQuestions").doc(answer.questionId), {
      timesAnswered: admin.firestore.FieldValue.increment(1),
      timesCorrect: admin.firestore.FieldValue.increment(isCorrect ? 1 : 0),
    });
  }

  const total = detailedAnswers.length;
  const score = Math.round((correct / total) * 100);
  const passed = score >= (topicData.passingScore ?? 70);

  // Calcular XP ganado
  let xpEarned = passed ? XP_REWARDS.quiz_passed : 5;
  if (score === 100) xpEarned += XP_REWARDS.quiz_perfect;

  // Verificar si es el primer quiz del día
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todaySnap = await db
    .collection("quizSessions")
    .where("userId", "==", uid)
    .where("completedAt", ">=", admin.firestore.Timestamp.fromDate(today))
    .limit(1)
    .get();
  if (todaySnap.empty) xpEarned += XP_REWARDS.first_daily_quiz;

  // Badges ganados
  const currentBadges: string[] = userData.stats?.badges ?? [];
  const newBadges: string[] = [];

  // Badge: primer quiz
  if (!currentBadges.includes("first_quiz")) newBadges.push("first_quiz");

  // Badge: quiz perfecto
  if (score === 100 && !currentBadges.includes("quiz_perfect")) {
    newBadges.push("quiz_perfect");
  }

  // Verificar quiz_master: 5 quizzes con >= 90%
  if (!currentBadges.includes("quiz_master") && score >= 90) {
    const masterSnap = await db
      .collection("quizSessions")
      .where("userId", "==", uid)
      .where("score", ">=", 90)
      .get();
    if (masterSnap.size >= 4) newBadges.push("quiz_master"); // +1 este mismo
  }

  // Verificar all_topics: quiz en 5 temas distintos
  if (!currentBadges.includes("all_topics")) {
    const topicsSnap = await db
      .collection("quizSessions")
      .where("userId", "==", uid)
      .where("status", "==", "completed")
      .get();
    const uniqueTopics = new Set(topicsSnap.docs.map((d) => d.data().topicId));
    uniqueTopics.add(topicId);
    if (uniqueTopics.size >= 5) newBadges.push("all_topics");
  }

  // Guardar quizSession
  const currentXp = userData.stats?.xp ?? 0;
  const newXp = currentXp + xpEarned;
  const nowRef = admin.firestore.Timestamp.now();

  const sessionRef = db.collection("quizSessions").doc();
  batch.set(sessionRef, {
    userId: uid,
    topicId,
    topicTitle: topicData.title,
    institutionId: userData.institutionId ?? null,
    status: "completed",
    startedAt: nowRef,
    completedAt: nowRef,
    timeUsedSeconds,
    timeLimitSeconds: topicData.timePerQuestion * total,
    questionsTotal: total,
    questionsAnswered: total,
    correctAnswers: correct,
    incorrectAnswers: total - correct,
    score,
    passed,
    answers: detailedAnswers,
    aiRecommendations: null,  // se llenará con trigger si OpenAI está habilitado
    weakAreas: null,
    xpEarned,
    badgesEarned: newBadges,
    isNewRecord: score > (userData.stats?.quizAverageScore ?? 0),
    courseId,
    moduleId,
    createdAt: nowRef,
  });

  // Actualizar stats del usuario
  const allBadges = [...currentBadges, ...newBadges];
  batch.update(db.collection("users").doc(uid), {
    "stats.quizzesCompleted": admin.firestore.FieldValue.increment(1),
    "stats.quizAverageScore": score, // simplificado; en producción calcular running avg
    "stats.xp": newXp,
    "stats.level": calculateLevel(newXp),
    "stats.badges": allBadges,
  });

  await batch.commit();

  return {
    sessionId: sessionRef.id,
    score,
    passed,
    correct,
    incorrect: total - correct,
    total,
    xpEarned,
    newBadges,
    detailedAnswers,
    newLevel: calculateLevel(newXp),
    newXp,
  };
});

// ─────────────────────────────────────────────────────────────────────────────
// CF 3 — onInstitutionCreated
// Trigger: crea planMembership/current con plan pyme al crear una institución
// ─────────────────────────────────────────────────────────────────────────────
export const onInstitutionCreated = onDocumentCreated(
  "institutions/{institutionId}",
  async (event) => {
    const institutionId = event.params.institutionId;
    const now = admin.firestore.Timestamp.now();

    // Fecha de expiración: 30 días de prueba
    const trialExpiry = new Date();
    trialExpiry.setDate(trialExpiry.getDate() + 30);

    await db
      .doc(`institutions/${institutionId}/planMembership/current`)
      .set({
        planType: "pyme",
        status: "approved",
        isActive: true,
        planExpiresAt: admin.firestore.Timestamp.fromDate(trialExpiry),
        creditBalance: 0,

        // Límites plan PYME
        maxUsers: 15,
        maxSeats: 1,
        maxActiveCourses: 3,
        maxCertificatesPerMonth: 50,
        maxManikins: 1,
        canUseLiveSessions: false,
        canRecordSessions: false,
        canUseMultiSite: false,
        canUseApi: false,
        canUseBiReports: false,
        historyMonths: 6,
        requiresSstLicense: false,

        // Contadores de uso
        usageCurrentUsers: 0,
        usageCurrentCourses: 0,
        usageCertificatesThisMonth: 0,
        usagePeriodStart: now,

        updatedAt: now,
        updatedBy: "system",
      });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// CF 4 — onSessionCompleted
// Trigger: actualiza UserStats cuando se completa una sesión RCP
// ─────────────────────────────────────────────────────────────────────────────
export const onSessionCompleted = onDocumentUpdated(
  "sessions/{sessionId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!after || before?.status === after.status) return;
    if (after.status !== "completed") return;

    const uid = after.studentId;
    if (!uid) return;

    const score = after.metrics?.score ?? 0;
    const approved = after.metrics?.approved ?? false;
    const durationMinutes = (after.duration ?? 0) / 60;

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const stats = userDoc.data()?.stats ?? {};

    const currentXp = stats.xp ?? 0;
    let xpGained = XP_REWARDS.session_completed;
    if (approved) xpGained += XP_REWARDS.session_approved;
    if (score === 100) xpGained += 20;

    const newXp = currentXp + xpGained;
    const newBadges: string[] = [...(stats.badges ?? [])];

    // Badge: primer RCP
    if (!newBadges.includes("first_rcp")) newBadges.push("first_rcp");
    if (score === 100 && !newBadges.includes("perfect_session")) {
      newBadges.push("perfect_session");
    }

    await userRef.update({
      "stats.totalSessions": admin.firestore.FieldValue.increment(1),
      "stats.totalHours": admin.firestore.FieldValue.increment(durationMinutes / 60),
      "stats.bestScore": Math.max(stats.bestScore ?? 0, score),
      "stats.xp": newXp,
      "stats.level": calculateLevel(newXp),
      "stats.badges": newBadges,
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// CF 5 — onCertificateIssued
// Trigger: decrementa quota mensual de certificados y da XP
// ─────────────────────────────────────────────────────────────────────────────
export const onCertificateIssued = onDocumentCreated(
  "certificates/{certId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { institutionId, userId } = data;

    // Decrementar cuota de certificados
    if (institutionId) {
      await db
        .doc(`institutions/${institutionId}/planMembership/current`)
        .update({
          usageCertificatesThisMonth: admin.firestore.FieldValue.increment(1),
        });
    }

    // XP por certificado
    if (userId) {
      const userRef = db.collection("users").doc(userId);
      const userDoc = await userRef.get();
      const currentXp = userDoc.data()?.stats?.xp ?? 0;
      const currentBadges: string[] = userDoc.data()?.stats?.badges ?? [];
      const newXp = currentXp + XP_REWARDS.certificate_earned;
      const newBadges = [...currentBadges];

      if (!newBadges.includes("certified")) newBadges.push("certified");

      await userRef.update({
        "stats.certificatesEarned": admin.firestore.FieldValue.increment(1),
        "stats.xp": newXp,
        "stats.level": calculateLevel(newXp),
        "stats.badges": newBadges,
      });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// CF 6 — onEnrollmentCreated
// Trigger: incrementa contador de usuarios activos en planMembership
// ─────────────────────────────────────────────────────────────────────────────
export const onEnrollmentCreated = onDocumentCreated(
  "courses/{courseId}/enrollments/{userId}",
  async (event) => {
    const courseId = event.params.courseId;
    const courseDoc = await db.collection("courses").doc(courseId).get();
    const institutionId = courseDoc.data()?.institutionId;
    if (!institutionId) return;

    await db
      .doc(`institutions/${institutionId}/planMembership/current`)
      .update({
        usageCurrentUsers: admin.firestore.FieldValue.increment(1),
      });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// CF 7 — resetMonthlyUsage (Scheduled)
// Cron: resetea contadores mensuales el 1ro de cada mes a las 3AM UTC
// ─────────────────────────────────────────────────────────────────────────────
export const resetMonthlyUsage = onSchedule("0 3 1 * *", async () => {
  const snap = await db
    .collectionGroup("planMembership")
    .where("isActive", "==", true)
    .get();

  const batch = db.batch();
  const now = admin.firestore.Timestamp.now();

  snap.docs.forEach((doc) => {
    batch.update(doc.ref, {
      usageCertificatesThisMonth: 0,
      usagePeriodStart: now,
    });
  });

  await batch.commit();
  console.log(`Reset mensual completado para ${snap.size} instituciones.`);
});

// ─────────────────────────────────────────────────────────────────────────────
// CF 8 — notifyPlanExpiry (Scheduled)
// Cron: alerta 3 días antes del vencimiento del plan y de la licencia SST
// ─────────────────────────────────────────────────────────────────────────────
export const notifyPlanExpiry = onSchedule("0 9 * * *", async () => {
  const threeDaysFromNow = new Date();
  threeDaysFromNow.setDate(threeDaysFromNow.getDate() + 3);

  const fourDaysFromNow = new Date();
  fourDaysFromNow.setDate(fourDaysFromNow.getDate() + 4);

  // Planes próximos a vencer
  const planSnap = await db
    .collectionGroup("planMembership")
    .where("isActive", "==", true)
    .where("planExpiresAt", ">=", admin.firestore.Timestamp.fromDate(threeDaysFromNow))
    .where("planExpiresAt", "<", admin.firestore.Timestamp.fromDate(fourDaysFromNow))
    .get();

  const batch = db.batch();
  const now = admin.firestore.Timestamp.now();

  for (const planDoc of planSnap.docs) {
    // Obtener institutionId del path: institutions/{id}/planMembership/current
    const institutionId = planDoc.ref.parent.parent?.id;
    if (!institutionId) continue;

    // Crear evento de calendario de vencimiento
    const calendarRef = db.collection("calendar").doc();
    batch.set(calendarRef, {
      title: "⚠️ Vencimiento de plan SIERCP",
      description: "Tu suscripción vence en 3 días. Renueva para evitar interrupciones.",
      type: "vencimiento_plan",
      startAt: planDoc.data().planExpiresAt,
      endAt: null,
      allDay: true,
      institutionId,
      targetRole: "ADMIN",
      targetUserIds: [],
      linkedEntityType: null,
      linkedEntityId: null,
      isRecurring: false,
      recurrenceRule: null,
      color: "#D97706",
      icon: "warning",
      isCompleted: false,
      createdBy: "system",
      createdAt: now,
    });
  }

  // Licencias SST próximas a vencer
  const sstSnap = await db
    .collection("users")
    .where("sstLicenseVerified", "==", true)
    .where("sstLicenseExpiresAt", ">=", admin.firestore.Timestamp.fromDate(threeDaysFromNow))
    .where("sstLicenseExpiresAt", "<", admin.firestore.Timestamp.fromDate(fourDaysFromNow))
    .get();

  for (const userDoc of sstSnap.docs) {
    const userData = userDoc.data();
    const notifRef = db.collection("notifications").doc();
    batch.set(notifRef, {
      userId: userDoc.id,
      title: "Licencia SST próxima a vencer",
      body: "Tu licencia SST vence en 3 días. Renueva para mantener el acceso.",
      type: "warning",
      isRead: false,
      createdAt: now,
    });
  }

  await batch.commit();
  console.log(`Alertas enviadas: ${planSnap.size} planes, ${sstSnap.size} licencias SST.`);
});

// ─────────────────────────────────────────────────────────────────────────────
// CF 9 — verifyCertificate (HTTP público)
// GET /verifyCertificate?code=UUID — verifica un certificado sin auth
// ─────────────────────────────────────────────────────────────────────────────
export const verifyCertificate = onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") { res.status(204).send(""); return; }

  const code = req.query.code as string;
  if (!code) { res.status(400).json({ error: "Código requerido." }); return; }

  const snap = await db
    .collection("certificates")
    .where("verificationCode", "==", code)
    .limit(1)
    .get();

  if (snap.empty) { res.status(404).json({ valid: false, error: "Certificado no encontrado." }); return; }

  const cert = snap.docs[0].data();
  res.json({
    valid: cert.isValid ?? true,
    userName: cert.userName,
    institutionName: cert.institutionName,
    title: cert.title,
    issuedAt: cert.issuedAt?.toDate().toISOString(),
    expiresAt: cert.expiresAt?.toDate().toISOString() ?? null,
    score: cert.score,
    type: cert.type,
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// CF 10 — setUserRole (Callable)
// Solo SUPER_ADMIN puede asignar roles como Custom Claims
// ─────────────────────────────────────────────────────────────────────────────
export const setUserRole = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sin autenticación.");

  // Verificar que quien llama es SUPER_ADMIN
  const callerDoc = await db.collection("users").doc(request.auth.uid).get();
  if (callerDoc.data()?.role !== "SUPER_ADMIN") {
    throw new HttpsError("permission-denied", "Solo SUPER_ADMIN puede asignar roles.");
  }

  const { targetUid, role, institutionId } = request.data as {
    targetUid: string;
    role: string;
    institutionId: string;
  };

  const validRoles = ["SUPER_ADMIN", "ADMIN", "INSTRUCTOR", "ESTUDIANTE"];
  if (!validRoles.includes(role)) {
    throw new HttpsError("invalid-argument", "Rol inválido.");
  }

  await admin.auth().setCustomUserClaims(targetUid, { role, institutionId });
  await db.collection("users").doc(targetUid).update({
    role,
    institutionId,
    updatedAt: admin.firestore.Timestamp.now(),
  });

  return { success: true };
});
