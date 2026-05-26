import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();

/**
 * onSessionCompleted — Firestore trigger
 *
 * Fires whenever a session document changes. When `status` transitions
 * to "completed", recalculates the student's averageScore using an
 * incremental weighted average (avoids re-reading all sessions) and
 * writes a public leaderboard projection:
 *
 *   leaderboards/{institutionId}/students/{uid}
 *     → uid, displayName, averageScore, totalSessions, trend, updatedAt
 *
 * Only users with a real institution (institutionId !== uid) are added.
 */
export const onSessionCompleted = functions
  .region("us-central1")
  .firestore.document("sessions/{sessionId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();

    // Ignorar si el estado no cambió o no es "completed"
    if (!after || before.status === after.status) return;
    if (after.status !== "completed") return;

    const uid = after.studentId as string | undefined;
    if (!uid) return;

    const db = admin.firestore();

    // Puntaje de la sesión — qualityScore es el principal, score es alias legacy
    const sessionScore = (
      (after.metrics?.qualityScore ?? after.metrics?.score ?? 0) as number
    );

    // Leer stats actuales del usuario
    const userRef  = db.collection("users").doc(uid);
    const userDoc  = await userRef.get();
    if (!userDoc.exists) return;

    const userData = userDoc.data()!;
    const stats    = (userData.stats ?? {}) as Record<string, number | string[]>;

    // Media ponderada incremental — sin releer todas las sesiones históricas
    const prevTotal    = (stats.totalSessions    as number) ?? 0;
    const prevAvg      = (stats.averageScore     as number) ?? 0;
    const newTotal     = prevTotal + 1;
    const newAvgScore  = Math.round(((prevAvg * prevTotal) + sessionScore) / newTotal);
    const newBestScore = Math.max((stats.bestScore as number) ?? 0, sessionScore);
    const trend: "up" | "down" | "minus" =
      newAvgScore >= 85 ? "up" : newAvgScore >= 70 ? "minus" : "down";

    const now = admin.firestore.Timestamp.now();

    // Actualizar stats del usuario
    await userRef.update({
      "stats.totalSessions": newTotal,
      "stats.averageScore":  newAvgScore,
      "stats.bestScore":     newBestScore,
      updatedAt: now,
    });

    // Actualizar leaderboard solo para usuarios con institución real
    const institutionId = userData.institutionId as string | undefined;
    if (!institutionId || institutionId === uid) return;

    const displayName =
      [userData.firstName as string, userData.lastName as string]
        .filter(Boolean)
        .join(" ")
        .trim() || "Usuario";

    await db
      .doc(`leaderboards/${institutionId}/students/${uid}`)
      .set(
        { uid, displayName, averageScore: newAvgScore, totalSessions: newTotal, trend, updatedAt: now },
        { merge: true }
      );
  });
