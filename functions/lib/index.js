"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createWompiCourseTransaction = exports.createWompiPlanTransaction = exports.provisionCorporateAccount = exports.createCorporatePlanOrderWeb = exports.setUserRole = exports.migrateLeaderboards = exports.verifyCertificate = exports.notifyPlanExpiry = exports.resetMonthlyUsage = exports.onEnrollmentCreated = exports.onCertificateIssued = exports.onSessionCompleted = exports.onInstitutionCreated = exports.submitQuizAnswers = exports.getQuizQuestions = void 0;
const admin = require("firebase-admin");
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
admin.initializeApp();
const db = admin.firestore();
// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
// Actualiza o crea la entrada del leaderboard para un estudiante.
// Debe llamarse SOLO cuando el usuario tiene una institución real
// (institutionId !== uid).
async function updateLeaderboardEntry(uid, institutionId, displayName, avgScore, totalSessions) {
    const trend = avgScore >= 85 ? "up" : avgScore >= 70 ? "minus" : "down";
    await db
        .doc(`leaderboards/${institutionId}/students/${uid}`)
        .set({
        uid,
        displayName,
        averageScore: avgScore,
        totalSessions,
        trend,
        updatedAt: admin.firestore.Timestamp.now(),
    }, { merge: true });
}
function shuffle(arr) {
    const a = [...arr];
    for (let i = a.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
}
const XP_REWARDS = {
    quiz_passed: 20,
    quiz_perfect: 50,
    session_approved: 30,
    session_completed: 15,
    course_completed: 100,
    certificate_earned: 75,
    first_daily_quiz: 25,
};
const LEVEL_THRESHOLDS = [0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5500];
function calculateLevel(xp) {
    return LEVEL_THRESHOLDS.filter((t) => xp >= t).length;
}
// ─────────────────────────────────────────────────────────────────────────────
// CF 1 — getQuizQuestions
// Callable: retorna N preguntas de un topicId SIN correctOption ni explanation
// ─────────────────────────────────────────────────────────────────────────────
exports.getQuizQuestions = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Se requiere autenticación.");
    }
    const { topicId, count = 10 } = request.data;
    if (!topicId) {
        throw new https_1.HttpsError("invalid-argument", "topicId es requerido.");
    }
    // Verificar que el topic existe y está activo
    const topicDoc = await db.collection("quizTopics").doc(topicId).get();
    if (!topicDoc.exists || !topicDoc.data()?.isActive) {
        throw new https_1.HttpsError("not-found", "Tema no encontrado o inactivo.");
    }
    const topicData = topicDoc.data();
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
                throw new https_1.HttpsError("permission-denied", "Tu plan no incluye este tema.");
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
        throw new https_1.HttpsError("not-found", "No hay preguntas para este tema.");
    }
    const allQuestions = qSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
    const selected = shuffle(allQuestions).slice(0, Math.min(count, allQuestions.length));
    // Remover respuestas del payload — el servidor las valida al submit
    return {
        questions: selected.map((q) => ({
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
exports.submitQuizAnswers = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Se requiere autenticación.");
    }
    const uid = request.auth.uid;
    const { topicId, answers, timeUsedSeconds, courseId = null, moduleId = null, } = request.data;
    if (!topicId || !answers?.length) {
        throw new https_1.HttpsError("invalid-argument", "topicId y answers son requeridos.");
    }
    // Obtener datos del usuario
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data();
    // Obtener topic para metadata
    const topicDoc = await db.collection("quizTopics").doc(topicId).get();
    const topicData = topicDoc.data();
    // Obtener preguntas reales desde Firestore para validar
    const questionIds = answers.map((a) => a.questionId);
    const questionDocs = await Promise.all(questionIds.map((id) => db.collection("quizQuestions").doc(id).get()));
    let correct = 0;
    const detailedAnswers = [];
    const batch = db.batch();
    for (let i = 0; i < answers.length; i++) {
        const answer = answers[i];
        const qDoc = questionDocs[i];
        if (!qDoc.exists)
            continue;
        const qData = qDoc.data();
        const isCorrect = answer.selectedOption === qData.correctOption;
        if (isCorrect)
            correct++;
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
    if (score === 100)
        xpEarned += XP_REWARDS.quiz_perfect;
    // Verificar si es el primer quiz del día
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todaySnap = await db
        .collection("quizSessions")
        .where("userId", "==", uid)
        .where("completedAt", ">=", admin.firestore.Timestamp.fromDate(today))
        .limit(1)
        .get();
    if (todaySnap.empty)
        xpEarned += XP_REWARDS.first_daily_quiz;
    // Badges ganados
    const currentBadges = userData.stats?.badges ?? [];
    const newBadges = [];
    // Badge: primer quiz
    if (!currentBadges.includes("first_quiz"))
        newBadges.push("first_quiz");
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
        if (masterSnap.size >= 4)
            newBadges.push("quiz_master"); // +1 este mismo
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
        if (uniqueTopics.size >= 5)
            newBadges.push("all_topics");
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
        aiRecommendations: null, // se llenará con trigger si OpenAI está habilitado
        weakAreas: null,
        xpEarned,
        badgesEarned: newBadges,
        isNewRecord: score > (userData.stats?.quizAverageScore ?? 0),
        courseId,
        moduleId,
        createdAt: nowRef,
    });
    // Actualizar stats del usuario con promedio incremental correcto.
    // Usamos transacción para el promedio y batch para el resto (quizSession, preguntas).
    // La transacción lee el contador actual antes de escribir, evitando race conditions
    // cuando dos quizzes del mismo usuario se envían simultáneamente.
    await batch.commit(); // Primero: guardar quizSession y stats de preguntas
    await db.runTransaction(async (tx) => {
        const userRef = db.collection("users").doc(uid);
        const snap = await tx.get(userRef);
        const currentStats = snap.data()?.stats ?? {};
        const prevCompleted = (currentStats.quizzesCompleted ?? 0);
        const prevAvg = (currentStats.quizAverageScore ?? 0);
        const allBadges = [
            ...(currentStats.badges ?? []),
            ...newBadges.filter((b) => !(currentStats.badges ?? []).includes(b)),
        ];
        // Promedio incremental sin releer todos los registros
        const newAvg = prevCompleted === 0
            ? score
            : Math.round((prevAvg * prevCompleted + score) / (prevCompleted + 1));
        tx.update(userRef, {
            "stats.quizzesCompleted": admin.firestore.FieldValue.increment(1),
            "stats.quizAverageScore": newAvg,
            "stats.xp": admin.firestore.FieldValue.increment(xpEarned),
            "stats.level": calculateLevel(newXp),
            "stats.badges": allBadges,
        });
    });
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
exports.onInstitutionCreated = (0, firestore_1.onDocumentCreated)("institutions/{institutionId}", async (event) => {
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
});
// ─────────────────────────────────────────────────────────────────────────────
// CF 4 — onSessionCompleted
// Trigger: actualiza UserStats y leaderboard cuando se completa una sesión RCP
// ─────────────────────────────────────────────────────────────────────────────
exports.onSessionCompleted = (0, firestore_1.onDocumentUpdated)("sessions/{sessionId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after || before?.status === after.status)
        return;
    if (after.status !== "completed")
        return;
    const uid = after.studentId;
    if (!uid)
        return;
    // qualityScore es el puntaje principal; score es alias de compatibilidad
    const score = (after.metrics?.qualityScore ?? after.metrics?.score ?? 0);
    const approved = (after.metrics?.approved ?? false);
    const durationMinutes = (after.duration ?? 0) / 60;
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.data() ?? {};
    const stats = userData.stats ?? {};
    // ── Running average de puntaje AHA ──────────────────────────────────────
    const prevTotal = (stats.totalSessions ?? 0);
    const prevAvg = (stats.averageScore ?? 0);
    const newTotal = prevTotal + 1;
    // Media ponderada incremental: sin releer todas las sesiones
    const newAvgScore = Math.round(((prevAvg * prevTotal) + score) / newTotal);
    // ── XP y badges ─────────────────────────────────────────────────────────
    let xpGained = XP_REWARDS.session_completed;
    if (approved)
        xpGained += XP_REWARDS.session_approved;
    if (score === 100)
        xpGained += 20;
    const newBadges = [...(stats.badges ?? [])];
    if (!newBadges.includes("first_rcp"))
        newBadges.push("first_rcp");
    if (score === 100 && !newBadges.includes("perfect_session")) {
        newBadges.push("perfect_session");
    }
    // ── Actualizar documento de usuario con transacción atómica ─────────────
    // Evita race condition cuando dos sesiones completan simultáneamente:
    // la transacción re-lee el estado actual antes de calcular el nuevo promedio.
    await db.runTransaction(async (tx) => {
        const freshSnap = await tx.get(userRef);
        const freshStats = freshSnap.data()?.stats ?? {};
        const freshTotal = (freshStats.totalSessions ?? 0);
        const freshAvg = (freshStats.averageScore ?? 0);
        const freshXp = (freshStats.xp ?? 0);
        const actualTotal = freshTotal + 1;
        const actualAvgScore = Math.round((freshAvg * freshTotal + score) / actualTotal);
        const actualXp = freshXp + xpGained;
        const freshBadges = (freshStats.badges ?? []);
        const mergedBadges = [
            ...freshBadges,
            ...newBadges.filter((b) => !freshBadges.includes(b)),
        ];
        tx.update(userRef, {
            "stats.totalSessions": admin.firestore.FieldValue.increment(1),
            "stats.averageScore": actualAvgScore,
            "stats.totalHours": admin.firestore.FieldValue.increment(durationMinutes / 60),
            "stats.bestScore": Math.max((freshStats.bestScore ?? 0), score),
            "stats.xp": actualXp,
            "stats.level": calculateLevel(actualXp),
            "stats.badges": mergedBadges,
        });
    });
    // ── Actualizar leaderboard ───────────────────────────────────────────────
    // Solo si el usuario pertenece a una institución real (no su propio uid)
    const institutionId = userData.institutionId;
    if (institutionId && institutionId !== uid) {
        const displayName = [userData.firstName, userData.lastName]
            .filter(Boolean)
            .join(" ")
            .trim() || "Usuario";
        await updateLeaderboardEntry(uid, institutionId, displayName, newAvgScore, newTotal);
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// CF 5 — onCertificateIssued
// Trigger: decrementa quota mensual de certificados y da XP
// ─────────────────────────────────────────────────────────────────────────────
exports.onCertificateIssued = (0, firestore_1.onDocumentCreated)("certificates/{certId}", async (event) => {
    const data = event.data?.data();
    if (!data)
        return;
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
        const currentBadges = userDoc.data()?.stats?.badges ?? [];
        const newXp = currentXp + XP_REWARDS.certificate_earned;
        const newBadges = [...currentBadges];
        if (!newBadges.includes("certified"))
            newBadges.push("certified");
        await userRef.update({
            "stats.certificatesEarned": admin.firestore.FieldValue.increment(1),
            "stats.xp": newXp,
            "stats.level": calculateLevel(newXp),
            "stats.badges": newBadges,
        });
    }
});
// ─────────────────────────────────────────────────────────────────────────────
// CF 6 — onEnrollmentCreated
// Trigger: incrementa contador de usuarios activos en planMembership
// ─────────────────────────────────────────────────────────────────────────────
exports.onEnrollmentCreated = (0, firestore_1.onDocumentCreated)("courses/{courseId}/enrollments/{userId}", async (event) => {
    const courseId = event.params.courseId;
    const courseDoc = await db.collection("courses").doc(courseId).get();
    const institutionId = courseDoc.data()?.institutionId;
    if (!institutionId)
        return;
    await db
        .doc(`institutions/${institutionId}/planMembership/current`)
        .update({
        usageCurrentUsers: admin.firestore.FieldValue.increment(1),
    });
});
// ─────────────────────────────────────────────────────────────────────────────
// CF 7 — resetMonthlyUsage (Scheduled)
// Cron: resetea contadores mensuales el 1ro de cada mes a las 3AM UTC
// ─────────────────────────────────────────────────────────────────────────────
exports.resetMonthlyUsage = (0, scheduler_1.onSchedule)("0 3 1 * *", async () => {
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
exports.notifyPlanExpiry = (0, scheduler_1.onSchedule)("0 9 * * *", async () => {
    const threeDaysFromNow = new Date();
    threeDaysFromNow.setDate(threeDaysFromNow.getDate() + 3);
    const fourDaysFromNow = new Date();
    fourDaysFromNow.setDate(fourDaysFromNow.getDate() + 4);
    const tsThree = admin.firestore.Timestamp.fromDate(threeDaysFromNow);
    const tsFour = admin.firestore.Timestamp.fromDate(fourDaysFromNow);
    const now = admin.firestore.Timestamp.now();
    const BATCH_SIZE = 400; // Firestore batch limit = 500; dejamos margen
    let totalPlans = 0;
    let totalSst = 0;
    // ── Planes próximos a vencer (paginado) ──────────────────────────────────
    let lastPlanDoc = null;
    while (true) {
        let planQuery = db
            .collectionGroup("planMembership")
            .where("isActive", "==", true)
            .where("planExpiresAt", ">=", tsThree)
            .where("planExpiresAt", "<", tsFour)
            .orderBy("planExpiresAt")
            .limit(BATCH_SIZE);
        if (lastPlanDoc)
            planQuery = planQuery.startAfter(lastPlanDoc);
        const planSnap = await planQuery.get();
        if (planSnap.empty)
            break;
        const batch = db.batch();
        for (const planDoc of planSnap.docs) {
            const institutionId = planDoc.ref.parent.parent?.id;
            if (!institutionId)
                continue;
            batch.set(db.collection("calendar").doc(), {
                title: "Vencimiento de plan SIERCP",
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
        await batch.commit();
        totalPlans += planSnap.size;
        lastPlanDoc = planSnap.docs[planSnap.docs.length - 1];
        if (planSnap.size < BATCH_SIZE)
            break;
    }
    // ── Licencias SST próximas a vencer (paginado) ───────────────────────────
    let lastSstDoc = null;
    while (true) {
        let sstQuery = db
            .collection("users")
            .where("sstLicenseVerified", "==", true)
            .where("sstLicenseExpiresAt", ">=", tsThree)
            .where("sstLicenseExpiresAt", "<", tsFour)
            .orderBy("sstLicenseExpiresAt")
            .limit(BATCH_SIZE);
        if (lastSstDoc)
            sstQuery = sstQuery.startAfter(lastSstDoc);
        const sstSnap = await sstQuery.get();
        if (sstSnap.empty)
            break;
        const batch = db.batch();
        for (const userDoc of sstSnap.docs) {
            batch.set(db.collection("notifications").doc(), {
                userId: userDoc.id,
                title: "Licencia SST próxima a vencer",
                body: "Tu licencia SST vence en 3 días. Renueva para mantener el acceso.",
                type: "warning",
                isRead: false,
                createdAt: now,
            });
        }
        await batch.commit();
        totalSst += sstSnap.size;
        lastSstDoc = sstSnap.docs[sstSnap.docs.length - 1];
        if (sstSnap.size < BATCH_SIZE)
            break;
    }
    console.log(`Alertas enviadas: ${totalPlans} planes, ${totalSst} licencias SST.`);
});
// ─────────────────────────────────────────────────────────────────────────────
// CF 9 — verifyCertificate (HTTP público)
// GET /verifyCertificate?code=UUID — verifica un certificado sin auth
//
// SEGURIDAD:
//  - Rate limiting: 10 req/min por IP (en memoria, por instancia)
//  - CORS: restringido al dominio del app (no wildcard)
//  - Datos devueltos: mínimos — sin userName completo, sin identificación,
//    sin institutionId, sin score exacto
// ─────────────────────────────────────────────────────────────────────────────
// Rate limiter en memoria (por instancia Cloud Function, ventana de 60s)
const _verifyRateMap = new Map();
function _checkVerifyRate(ip, maxPerMin = 10) {
    const now = Date.now();
    const entry = _verifyRateMap.get(ip);
    if (!entry || entry.resetAt < now) {
        _verifyRateMap.set(ip, { count: 1, resetAt: now + 60000 });
        return true;
    }
    if (entry.count >= maxPerMin)
        return false;
    entry.count++;
    return true;
}
exports.verifyCertificate = (0, https_1.onRequest)(async (req, res) => {
    const allowedOrigin = process.env.APP_URL ?? "https://siercp.com";
    res.set("Access-Control-Allow-Origin", allowedOrigin);
    res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
    res.set("Vary", "Origin");
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "GET") {
        res.status(405).json({ error: "Método no permitido." });
        return;
    }
    // Rate limiting por IP
    const ip = req.headers["x-real-ip"] ??
        req.headers["x-forwarded-for"]?.split(",")[0]?.trim() ??
        req.socket.remoteAddress ??
        "unknown";
    if (!_checkVerifyRate(ip)) {
        res.status(429).json({ error: "Demasiadas solicitudes. Intenta en un momento." });
        return;
    }
    const code = (req.query.code ?? "").trim();
    if (!code || code.length < 8 || code.length > 128 || !/^[a-zA-Z0-9_\-]+$/.test(code)) {
        res.status(400).json({ error: "Código inválido." });
        return;
    }
    const snap = await db
        .collection("certificates")
        .where("verificationCode", "==", code)
        .limit(1)
        .get();
    if (snap.empty) {
        res.status(404).json({ valid: false, error: "Certificado no encontrado." });
        return;
    }
    const cert = snap.docs[0].data();
    // Solo retornar datos mínimos — sin PII completa
    res.json({
        valid: cert.isValid === true,
        title: cert.title ?? null,
        type: cert.type ?? null,
        issuedAt: cert.issuedAt?.toDate().toISOString() ?? null,
        expiresAt: cert.expiresAt?.toDate().toISOString() ?? null,
        // Mostrar solo inicial + apellido para privacidad
        holderName: cert.userName
            ? cert.userName.replace(/^(\w)\w+/, "$1.").trim()
            : null,
        institutionName: cert.institutionName ?? null,
        // Score como rango, no exacto
        scoreRange: typeof cert.score === "number"
            ? cert.score >= 90 ? "Excelente" : cert.score >= 70 ? "Aprobado" : "No aprobado"
            : null,
    });
});
// ─────────────────────────────────────────────────────────────────────────────
// CF 11 — migrateLeaderboards (Callable)
// Migración inicial: lee todas las sesiones completadas y puebla
// leaderboards/{institutionId}/students/{uid} para cada usuario con institución.
// Solo ejecutar una vez, por SUPER_ADMIN, después del primer deploy.
// ─────────────────────────────────────────────────────────────────────────────
exports.migrateLeaderboards = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Se requiere autenticación.");
    }
    const callerSnap = await db.collection("users").doc(request.auth.uid).get();
    if (callerSnap.data()?.role !== "SUPER_ADMIN") {
        throw new https_1.HttpsError("permission-denied", "Solo SUPER_ADMIN puede ejecutar la migración.");
    }
    const usersSnap = await db.collection("users").get();
    const now = admin.firestore.Timestamp.now();
    let processed = 0;
    let skipped = 0;
    for (const userDoc of usersSnap.docs) {
        const userData = userDoc.data();
        const uid = userDoc.id;
        const institutionId = userData.institutionId;
        // Omitir usuarios sin institución real (institutionId === uid es el fallback)
        if (!institutionId || institutionId === uid) {
            skipped++;
            continue;
        }
        // Leer todas las sesiones completadas de este usuario
        const sessionsSnap = await db
            .collection("sessions")
            .where("studentId", "==", uid)
            .where("status", "==", "completed")
            .get();
        const scores = sessionsSnap.docs
            .map((d) => {
            const m = d.data().metrics;
            return (m?.qualityScore ?? m?.score ?? 0);
        })
            .filter((s) => s > 0);
        const avgScore = scores.length > 0
            ? Math.round(scores.reduce((a, b) => a + b, 0) / scores.length)
            : 0;
        const totalSessions = sessionsSnap.size;
        const displayName = [userData.firstName, userData.lastName]
            .filter(Boolean)
            .join(" ")
            .trim() || "Usuario";
        const batch = db.batch();
        // Crear/actualizar entrada de leaderboard
        batch.set(db.doc(`leaderboards/${institutionId}/students/${uid}`), {
            uid,
            displayName,
            averageScore: avgScore,
            totalSessions,
            trend: avgScore >= 85 ? "up" : avgScore >= 70 ? "minus" : "down",
            updatedAt: now,
        }, { merge: true });
        // Sincronizar stats del usuario (corrige averageScore si nunca fue calculado)
        batch.update(db.collection("users").doc(uid), {
            "stats.averageScore": avgScore,
            "stats.totalSessions": totalSessions,
            updatedAt: now,
        });
        await batch.commit();
        processed++;
    }
    console.log(`migrateLeaderboards: procesados=${processed}, omitidos=${skipped}`);
    return { processed, skipped, total: usersSnap.size };
});
// ─────────────────────────────────────────────────────────────────────────────
// CF 10 — setUserRole (Callable)
// Solo SUPER_ADMIN puede asignar roles como Custom Claims
// ─────────────────────────────────────────────────────────────────────────────
exports.setUserRole = (0, https_1.onCall)(async (request) => {
    if (!request.auth)
        throw new https_1.HttpsError("unauthenticated", "Sin autenticación.");
    // Verificar que quien llama es SUPER_ADMIN
    const callerDoc = await db.collection("users").doc(request.auth.uid).get();
    if (callerDoc.data()?.role !== "SUPER_ADMIN") {
        throw new https_1.HttpsError("permission-denied", "Solo SUPER_ADMIN puede asignar roles.");
    }
    const { targetUid, role, institutionId } = request.data;
    const validRoles = ["SUPER_ADMIN", "ADMIN", "INSTRUCTOR", "USUARIO_SST", "USUARIO_PROFESIONAL", "USUARIO"];
    if (!validRoles.includes(role)) {
        throw new https_1.HttpsError("invalid-argument", `Rol inválido: ${role}.`);
    }
    // Validar que el usuario destino existe
    const targetSnap = await db.collection("users").doc(targetUid).get();
    if (!targetSnap.exists) {
        throw new https_1.HttpsError("not-found", "Usuario destino no encontrado.");
    }
    // Validar que institutionId existe si fue proporcionado
    if (institutionId) {
        const instSnap = await db.collection("institutions").doc(institutionId).get();
        if (!instSnap.exists) {
            throw new https_1.HttpsError("not-found", `Institución "${institutionId}" no encontrada.`);
        }
    }
    await admin.auth().setCustomUserClaims(targetUid, { role, ...(institutionId ? { institutionId } : {}) });
    await db.collection("users").doc(targetUid).update({
        role,
        ...(institutionId !== undefined ? { institutionId } : {}),
        updatedAt: admin.firestore.Timestamp.now(),
    });
    return { success: true };
});
// ─────────────────────────────────────────────────────────────────────────────
// CF — createCorporatePlanOrderWeb
// Called from SIERCP-WEB corporate checkout (public, no auth required).
// Security: annual price is resolved server-side from the price table below.
// The client sends planSlug + non-financial data only; it NEVER sends amounts.
// ─────────────────────────────────────────────────────────────────────────────
// Hardcoded monthly base prices (COP). Never sent by the client.
const CORPORATE_MONTHLY_COP = {
    pyme: 380000,
    business: 790000,
    corporate: 1580000,
    // enterprise has no online checkout — contact sales
};
// Fallback discounts used only if Firestore pricing_plans document is unavailable.
const CORPORATE_DEFAULT_DISCOUNTS = {
    pyme: 10,
    business: 15,
    corporate: 25,
};
const CORPORATE_IVA_RATE = 0.19;
exports.createCorporatePlanOrderWeb = (0, https_1.onCall)({ cors: true }, async (request) => {
    const { planSlug, company, payMethod, cardLast4 = null, bank = null, } = (request.data ?? {});
    if (!planSlug || !(planSlug in CORPORATE_MONTHLY_COP)) {
        throw new https_1.HttpsError("invalid-argument", "Plan corporativo inválido.");
    }
    if (!payMethod || !["card", "pse", "transfer"].includes(payMethod)) {
        throw new https_1.HttpsError("invalid-argument", "Método de pago inválido.");
    }
    // Read discount from Firestore pricing_plans (editable by SuperAdmin).
    // Falls back to hardcoded defaults if document is missing or unreadable.
    let annualDiscountPercent = CORPORATE_DEFAULT_DISCOUNTS[planSlug] ?? 0;
    try {
        const pricingSnap = await db.doc(`pricing_plans/corporativo-${planSlug}`).get();
        if (pricingSnap.exists) {
            const raw = pricingSnap.data()?.annualDiscountPercent;
            if (typeof raw === "number" && raw >= 0 && raw <= 100) {
                annualDiscountPercent = raw;
            }
        }
    }
    catch {
        // Firestore read failed — use fallback discount, do not block the order
    }
    // Authoritative annual price calculation — client never controls any amount
    const monthlyBaseCOP = CORPORATE_MONTHLY_COP[planSlug];
    const annualFullCOP = monthlyBaseCOP * 12;
    const discountAmount = Math.round(annualFullCOP * (annualDiscountPercent / 100));
    const annualSubtotalCOP = annualFullCOP - discountAmount;
    const ivaCOP = Math.round(annualSubtotalCOP * CORPORATE_IVA_RATE);
    const totalCOP = annualSubtotalCOP + ivaCOP;
    const orderRef = await db.collection("orders").add({
        type: "plan-corporativo",
        planSlug,
        billingPeriod: "annual",
        monthlyBaseCOP,
        annualFullCOP,
        annualDiscountPercent,
        discountAmount,
        annualSubtotalCOP,
        ivaCOP,
        totalCOP,
        company: company ?? null,
        payMethod,
        cardLast4,
        bank,
        status: "pending_payment",
        createdAt: admin.firestore.Timestamp.now(),
    });
    return {
        orderId: orderRef.id,
        monthlyBaseCOP,
        annualFullCOP,
        annualDiscountPercent,
        discountAmount,
        annualSubtotalCOP,
        ivaCOP,
        totalCOP,
    };
});
exports.provisionCorporateAccount = (0, https_1.onCall)({ cors: true }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Autenticación requerida.");
    }
    const uid = request.auth.uid;
    const { orderId, planSlug, company } = (request.data ?? {});
    if (!planSlug || !(planSlug in CORPORATE_MONTHLY_COP)) {
        throw new https_1.HttpsError("invalid-argument", "planSlug inválido.");
    }
    if (!company?.razonSocial || !company?.nit || !company?.email) {
        throw new https_1.HttpsError("invalid-argument", "Datos de empresa incompletos.");
    }
    const now = admin.firestore.Timestamp.now();
    const expiresDate = new Date();
    expiresDate.setFullYear(expiresDate.getFullYear() + 1);
    const planExpiresAt = admin.firestore.Timestamp.fromDate(expiresDate);
    const nit = company.nit.replace(/[.\s-]/g, "");
    // Parse full name into first/last
    const nameParts = (company.responsable ?? "").trim().split(/\s+/);
    const firstName = nameParts[0] ?? "";
    const lastName = nameParts.slice(1).join(" ") || "";
    // Create institution document
    const institutionRef = db.collection("institutions").doc();
    const institutionId = institutionRef.id;
    await institutionRef.set({
        name: company.razonSocial,
        nit,
        type: "company",
        status: "active",
        contactEmail: company.email.toLowerCase(),
        phoneNumber: company.telefono ?? null,
        address: company.direccion ?? null,
        city: company.ciudad ?? null,
        department: company.departamento ?? null,
        country: "Colombia",
        primaryAdminId: uid,
        memberCount: 1,
        activeCoursesCount: 0,
        totalSessionsCount: 0,
        planType: planSlug,
        planActivatedAt: now,
        planExpiresAt,
        createdAt: now,
        updatedAt: now,
        config: {},
    });
    // Create or update user document
    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
        await userRef.set({
            uid,
            email: company.email.toLowerCase(),
            firstName,
            lastName,
            role: "ADMIN",
            isActive: true,
            certVerification: "NONE",
            coursesCreated: 0,
            memberships: [institutionId],
            createdAt: now,
            updatedAt: now,
            stats: {
                totalSessions: 0,
                sessionsToday: 0,
                averageScore: 0,
                bestScore: 0,
                streakDays: 0,
                totalHours: 0,
                averageDepthMm: 0,
                averageRatePerMin: 0,
            },
        });
    }
    else {
        const existingRole = userSnap.data()?.role;
        const shouldUpgrade = !["SUPER_ADMIN", "ADMIN"].includes(existingRole ?? "");
        await userRef.update({
            ...(shouldUpgrade ? { role: "ADMIN" } : {}),
            memberships: admin.firestore.FieldValue.arrayUnion(institutionId),
            updatedAt: now,
        });
    }
    // Create admin membership
    const membershipId = `${uid}_${institutionId}`;
    await db.collection("memberships").doc(membershipId).set({
        userId: uid,
        institutionId,
        role: "ADMIN",
        status: "approved",
        isActive: true,
        planType: planSlug,
        planExpiresAt,
        creditBalance: 0,
        sstLicenseVerified: false,
        usageCurrentUsers: 0,
        usageCurrentCourses: 0,
        usageCertificatesThisMonth: 0,
        createdAt: now,
        updatedAt: now,
    });
    // Update order with provisioning info
    if (orderId) {
        try {
            await db.collection("orders").doc(orderId).update({
                userId: uid,
                institutionId,
                status: "provisioned",
                provisionedAt: now,
            });
        }
        catch {
            // Non-fatal: order may not exist in dev/demo
        }
    }
    // Set custom claims so Flutter app has role immediately
    await admin.auth().setCustomUserClaims(uid, {
        role: "ADMIN",
        institutionId,
    });
    return { institutionId, uid };
});
// ─────────────────────────────────────────────────────────────────────────────
// WOMPI — PLAN SUBSCRIPTION PAYMENT LINK
// ─────────────────────────────────────────────────────────────────────────────
// Server-side price table (COP cents). The client NEVER sends the amount.
const PLAN_PRICES_COP_CENTS = {
    pyme: 35000000, // $350 000 COP/mes
    business: 70000000, // $700 000 COP/mes
    corporate: 150000000, // $1 500 000 COP/mes
    enterprise: 300000000, // $3 000 000 COP/mes
    sstSinLicencia: 20000000, // $200 000 COP/mes
    sstConLicencia: 45000000, // $450 000 COP/mes
};
const VALID_PLAN_TYPES = Object.keys(PLAN_PRICES_COP_CENTS);
/**
 * createWompiPlanTransaction
 *
 * Called by the Flutter app (Admin) to initiate a monthly plan subscription.
 *
 * Security guarantees:
 *  - Caller must be authenticated.
 *  - Caller must be ADMIN of the target institution (or SUPER_ADMIN).
 *  - Amount is resolved server-side from PLAN_PRICES_COP_CENTS; the client
 *    sends NO amount.
 *  - The Wompi payment link is created server-side with the correct amount.
 *  - Transaction metadata is stored in Firestore before returning the URL.
 *
 * Returns: { redirectUrl, transactionId, amountCents }
 * Flutter opens `redirectUrl` via url_launcher; streams `transactions/{transactionId}`
 * to detect APPROVED status.
 */
exports.createWompiPlanTransaction = (0, https_1.onCall)({ cors: true }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    const { planType, institutionId } = (request.data ?? {});
    // Input validation
    if (!planType || !VALID_PLAN_TYPES.includes(planType)) {
        throw new https_1.HttpsError("invalid-argument", "Tipo de plan inválido.");
    }
    if (!institutionId ||
        typeof institutionId !== "string" ||
        institutionId.trim().length === 0 ||
        institutionId.length > 128) {
        throw new https_1.HttpsError("invalid-argument", "institutionId inválido.");
    }
    const callerUid = request.auth.uid;
    // Permission check: SUPER_ADMIN bypasses membership check
    const userDoc = await db.collection("users").doc(callerUid).get();
    if (!userDoc.exists) {
        throw new https_1.HttpsError("unauthenticated", "Usuario no encontrado.");
    }
    const userRole = userDoc.data()?.role;
    if (userRole !== "SUPER_ADMIN") {
        const memberSnap = await db
            .collection("memberships")
            .where("userId", "==", callerUid)
            .where("institutionId", "==", institutionId)
            .where("role", "==", "ADMIN")
            .limit(1)
            .get();
        if (memberSnap.empty) {
            throw new https_1.HttpsError("permission-denied", "Solo el ADMIN de esta institución puede gestionar suscripciones.");
        }
    }
    // Server-side price (client never controls this)
    const amountCents = PLAN_PRICES_COP_CENTS[planType];
    const wompiEnv = process.env.WOMPI_ENV;
    const wompiApiBase = wompiEnv === "production"
        ? "https://production.wompi.co/v1"
        : "https://sandbox.wompi.co/v1";
    const wompiKey = process.env.WOMPI_PRIVATE_KEY;
    if (!wompiKey) {
        console.error("[createWompiPlanTransaction] WOMPI_PRIVATE_KEY not set");
        throw new https_1.HttpsError("internal", "Pasarela de pago no configurada.");
    }
    const appUrl = process.env.APP_URL ?? "https://siercp.com";
    // Call Wompi to create a hosted payment link
    let wompiPaymentLinkId;
    let wompiRedirectUrl;
    try {
        const wompiRes = await fetch(`${wompiApiBase}/payment_links`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${wompiKey}`,
            },
            body: JSON.stringify({
                name: `Plan ${planType} — SIERCP`,
                description: `Suscripción mensual al plan ${planType} para tu institución en SIERCP`,
                single_use: true,
                collect_shipping: false,
                currency: "COP",
                amount_in_cents: amountCents,
                redirect_url: `${appUrl}/pago/plan/confirmacion?institution=${encodeURIComponent(institutionId)}&plan=${encodeURIComponent(planType)}`,
            }),
        });
        if (!wompiRes.ok) {
            const errText = await wompiRes.text();
            console.error("[createWompiPlanTransaction] Wompi API error:", wompiRes.status, errText);
            throw new https_1.HttpsError("internal", "Error al crear enlace de pago. Intenta más tarde.");
        }
        // Wompi returns data.id (payment link ID) and data.url (checkout URL)
        const wompiData = (await wompiRes.json());
        wompiPaymentLinkId = wompiData.data.id;
        // Accept both response shapes: data.url or data.payment_link.url
        wompiRedirectUrl =
            wompiData.data.url ??
                wompiData.data.payment_link?.url ??
                `https://checkout.wompi.co/l/${wompiPaymentLinkId}`;
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        console.error("[createWompiPlanTransaction] fetch error:", err);
        throw new https_1.HttpsError("internal", "No se pudo conectar con la pasarela de pago.");
    }
    // Store transaction metadata in Firestore keyed by Wompi payment link ID.
    // The webhook receives tx.reference = paymentLinkId and looks up this doc.
    await db.collection("transactions").doc(wompiPaymentLinkId).set({
        id: wompiPaymentLinkId,
        type: "plan_subscription",
        planType,
        institutionId,
        user_id: callerUid,
        amount_in_cents: amountCents,
        currency: "COP",
        status: "PENDING",
        enrolled: false,
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
    });
    return {
        redirectUrl: wompiRedirectUrl,
        transactionId: wompiPaymentLinkId,
        amountCents,
    };
});
// ─────────────────────────────────────────────────────────────────────────────
// WOMPI — COURSE PAYMENT LINK (mobile)
// ─────────────────────────────────────────────────────────────────────────────
/**
 * createWompiCourseTransaction
 *
 * Called by the Flutter app (Student) to purchase a course enrollment.
 * The price is resolved server-side from Firestore (cohort → template → slug).
 *
 * Returns: { redirectUrl, transactionId, amountCents, courseTitle }
 */
exports.createWompiCourseTransaction = (0, https_1.onCall)({ cors: true }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    const { cursoSlug, cohortId, templateId, institutionId } = (request.data ?? {});
    if (!cursoSlug ||
        typeof cursoSlug !== "string" ||
        cursoSlug.trim().length === 0 ||
        cursoSlug.length > 100) {
        throw new https_1.HttpsError("invalid-argument", "cursoSlug inválido.");
    }
    const callerUid = request.auth.uid;
    // Verify the caller exists in Firestore
    const userDoc = await db.collection("users").doc(callerUid).get();
    if (!userDoc.exists) {
        throw new https_1.HttpsError("unauthenticated", "Usuario no encontrado.");
    }
    // Server-side price resolution: cohort → template → slug
    let priceCents = 0;
    let courseTitle = cursoSlug;
    let resolvedCohortId = cohortId ?? "";
    let resolvedTemplateId = templateId ?? "";
    if (resolvedCohortId) {
        const cohortDoc = await db.collection("cohorts").doc(resolvedCohortId).get();
        if (cohortDoc.exists) {
            const d = cohortDoc.data();
            priceCents = (d.priceCOP ?? 0) * 100;
            courseTitle = d.courseTitle ?? courseTitle;
            if (!resolvedTemplateId)
                resolvedTemplateId = d.templateId ?? "";
        }
    }
    if (!priceCents && resolvedTemplateId) {
        const tmplDoc = await db.collection("course_templates").doc(resolvedTemplateId).get();
        if (tmplDoc.exists) {
            const d = tmplDoc.data();
            priceCents = (d.priceCOP ?? 0) * 100;
            courseTitle = d.title ?? courseTitle;
        }
    }
    if (!priceCents) {
        const tmplSnap = await db
            .collection("course_templates")
            .where("slug", "==", cursoSlug)
            .limit(1)
            .get();
        if (!tmplSnap.empty) {
            const d = tmplSnap.docs[0].data();
            priceCents = (d.priceCOP ?? 0) * 100;
            courseTitle = d.title ?? courseTitle;
            resolvedTemplateId = tmplSnap.docs[0].id;
        }
    }
    if (!priceCents) {
        throw new https_1.HttpsError("not-found", "Curso no encontrado o sin precio asignado. Contacta al soporte.");
    }
    // Idempotency: reject if already APPROVED for this course
    const existingApproved = await db
        .collection("transactions")
        .where("user_id", "==", callerUid)
        .where("curso_slug", "==", cursoSlug)
        .where("status", "==", "APPROVED")
        .limit(1)
        .get();
    if (!existingApproved.empty) {
        throw new https_1.HttpsError("already-exists", "Ya tienes una inscripción aprobada para este curso.");
    }
    const wompiEnv = process.env.WOMPI_ENV;
    const wompiApiBase = wompiEnv === "production"
        ? "https://production.wompi.co/v1"
        : "https://sandbox.wompi.co/v1";
    const wompiKey = process.env.WOMPI_PRIVATE_KEY;
    if (!wompiKey) {
        throw new https_1.HttpsError("internal", "Pasarela de pago no configurada.");
    }
    const appUrl = process.env.APP_URL ?? "https://siercp.com";
    let wompiPaymentLinkId;
    let wompiRedirectUrl;
    try {
        const wompiRes = await fetch(`${wompiApiBase}/payment_links`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${wompiKey}`,
            },
            body: JSON.stringify({
                name: courseTitle,
                description: `Inscripción al curso ${courseTitle} en SIERCP`,
                single_use: true,
                collect_shipping: false,
                currency: "COP",
                amount_in_cents: priceCents,
                redirect_url: `${appUrl}/checkout/resultado?curso=${encodeURIComponent(cursoSlug)}&cohort=${encodeURIComponent(resolvedCohortId)}`,
            }),
        });
        if (!wompiRes.ok) {
            const errText = await wompiRes.text();
            console.error("[createWompiCourseTransaction] Wompi API error:", wompiRes.status, errText);
            throw new https_1.HttpsError("internal", "Error al crear enlace de pago.");
        }
        const wompiData = (await wompiRes.json());
        wompiPaymentLinkId = wompiData.data.id;
        wompiRedirectUrl =
            wompiData.data.url ??
                wompiData.data.payment_link?.url ??
                `https://checkout.wompi.co/l/${wompiPaymentLinkId}`;
    }
    catch (err) {
        if (err instanceof https_1.HttpsError)
            throw err;
        console.error("[createWompiCourseTransaction] fetch error:", err);
        throw new https_1.HttpsError("internal", "No se pudo conectar con la pasarela de pago.");
    }
    const userData = userDoc.data() ?? {};
    // Store transaction metadata at transactions/{paymentLinkId}
    // The webhook receives tx.reference = paymentLinkId and updates this doc.
    await db.collection("transactions").doc(wompiPaymentLinkId).set({
        id: wompiPaymentLinkId,
        type: "course_enrollment",
        user_id: callerUid,
        customer_email: userData.email ?? "",
        curso_slug: cursoSlug,
        cohort_id: resolvedCohortId,
        template_id: resolvedTemplateId,
        institution_id: institutionId ?? null,
        course_title: courseTitle,
        amount_in_cents: priceCents,
        currency: "COP",
        status: "PENDING",
        enrolled: false,
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
    });
    return {
        redirectUrl: wompiRedirectUrl,
        transactionId: wompiPaymentLinkId,
        amountCents: priceCents,
        courseTitle,
    };
});
//# sourceMappingURL=index.js.map