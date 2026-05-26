import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();

/**
 * migrateLeaderboards — Callable (solo SUPER_ADMIN)
 *
 * Migración inicial: lee todas las sesiones completadas históricas y puebla
 * leaderboards/{institutionId}/students/{uid} para cada usuario con institución.
 *
 * También sincroniza stats.averageScore y stats.totalSessions en users/{uid}
 * para corregir valores que nunca fueron calculados por un trigger.
 *
 * Ejecutar UNA SOLA VEZ desde el panel SUPER_ADMIN tras el primer deploy.
 */
export const migrateLeaderboards = functions
  .region("us-central1")
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .https.onCall(async (_data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Se requiere autenticación.");
    }

    const db          = admin.firestore();
    const callerSnap  = await db.collection("users").doc(context.auth.uid).get();

    if (callerSnap.data()?.role !== "SUPER_ADMIN") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Solo SUPER_ADMIN puede ejecutar la migración de leaderboards."
      );
    }

    const usersSnap = await db.collection("users").get();
    const now       = admin.firestore.Timestamp.now();
    let processed   = 0;
    let skipped     = 0;

    for (const userDoc of usersSnap.docs) {
      const userData      = userDoc.data();
      const uid           = userDoc.id;
      const institutionId = userData.institutionId as string | undefined;

      // Omitir usuarios sin institución real (fallback: institutionId === uid)
      if (!institutionId || institutionId === uid) {
        skipped++;
        continue;
      }

      // Leer todas las sesiones completadas de este usuario
      const sessionsSnap = await db
        .collection("sessions")
        .where("studentId", "==", uid)
        .where("status",    "==", "completed")
        .get();

      const scores = sessionsSnap.docs
        .map((d) => {
          const m = d.data().metrics as Record<string, number> | undefined;
          return (m?.qualityScore ?? m?.score ?? 0) as number;
        })
        .filter((s) => s > 0);

      const avgScore =
        scores.length > 0
          ? Math.round(scores.reduce((a, b) => a + b, 0) / scores.length)
          : 0;

      const totalSessions = sessionsSnap.size;
      const trend: "up" | "down" | "minus" =
        avgScore >= 85 ? "up" : avgScore >= 70 ? "minus" : "down";

      const displayName =
        [userData.firstName as string, userData.lastName as string]
          .filter(Boolean)
          .join(" ")
          .trim() || "Usuario";

      const batch = db.batch();

      // Crear/actualizar entrada de leaderboard
      batch.set(
        db.doc(`leaderboards/${institutionId}/students/${uid}`),
        { uid, displayName, averageScore: avgScore, totalSessions, trend, updatedAt: now },
        { merge: true }
      );

      // Corregir stats del usuario si averageScore nunca fue calculado
      batch.update(db.collection("users").doc(uid), {
        "stats.averageScore":  avgScore,
        "stats.totalSessions": totalSessions,
        updatedAt: now,
      });

      await batch.commit();
      processed++;
    }

    functions.logger.info(
      `migrateLeaderboards completado: procesados=${processed}, omitidos=${skipped}`
    );

    return { processed, skipped, total: usersSnap.size };
  });
