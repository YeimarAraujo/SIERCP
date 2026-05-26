import * as functions from "firebase-functions";
import * as admin     from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();

const db   = admin.firestore();
const auth = admin.auth();

/**
 * deleteAuthUser — callable function (ADMIN only)
 *
 * Deletes both the Firebase Auth account and Firestore document of a user.
 * Must be called from the app after admin confirmation.
 *
 * Security:
 *   - Caller must be authenticated.
 *   - Caller must be ADMIN or SUPER_ADMIN (verified server-side from Firestore).
 *   - A SUPER_ADMIN cannot be deleted via this function (requires manual action).
 *   - The caller cannot delete themselves.
 */
export const deleteAuthUser = functions
  .region("us-central1")
  .https.onCall(async (data: { uid: string }, context) => {
    // 1. Verify caller is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const callerUid = context.auth.uid;
    const targetUid = data?.uid as string | undefined;

    if (!targetUid || typeof targetUid !== "string") {
      throw new functions.https.HttpsError("invalid-argument", "uid requerido.");
    }

    // 2. Prevent self-deletion
    if (callerUid === targetUid) {
      throw new functions.https.HttpsError("invalid-argument", "No puedes eliminarte a ti mismo.");
    }

    // 3. Verify caller role (ADMIN or SUPER_ADMIN) from Firestore — never from client token
    const callerSnap = await db.collection("users").doc(callerUid).get();
    if (!callerSnap.exists) {
      throw new functions.https.HttpsError("permission-denied", "Perfil de administrador no encontrado.");
    }
    const callerRole = callerSnap.data()?.role as string | undefined;
    if (callerRole !== "ADMIN" && callerRole !== "SUPER_ADMIN") {
      throw new functions.https.HttpsError("permission-denied", "Solo admins pueden eliminar usuarios.");
    }

    // 4. Verify target exists and is not a SUPER_ADMIN
    const targetSnap = await db.collection("users").doc(targetUid).get();
    if (!targetSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Usuario no encontrado.");
    }
    const targetRole = targetSnap.data()?.role as string | undefined;
    if (targetRole === "SUPER_ADMIN") {
      throw new functions.https.HttpsError("permission-denied", "No se puede eliminar un SuperAdmin.");
    }

    // 5. If ADMIN (not SUPER_ADMIN), verify they share an organization with the target
    if (callerRole === "ADMIN") {
      const callerMemberships = await db
        .collection("memberships")
        .where("userId", "==", callerUid)
        .where("isActive", "==", true)
        .where("role",     "==", "ADMIN")
        .get();

      const callerOrgIds = new Set(
        callerMemberships.docs.map((d) => d.data().institutionId as string)
      );

      const targetMemberships = await db
        .collection("memberships")
        .where("userId", "==", targetUid)
        .where("isActive", "==", true)
        .get();

      const sharedOrg = targetMemberships.docs.some(
        (d) => callerOrgIds.has(d.data().institutionId as string)
      );

      if (!sharedOrg) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "El usuario no pertenece a ninguna de tus organizaciones."
        );
      }
    }

    // 6. Soft-delete Firestore doc + mark all memberships inactive
    const batch = db.batch();
    batch.update(db.collection("users").doc(targetUid), {
      isActive:      false,
      accountStatus: "deleted",
      deletedAt:     admin.firestore.FieldValue.serverTimestamp(),
      deletedBy:     callerUid,
    });

    const memberships = await db
      .collection("memberships")
      .where("userId", "==", targetUid)
      .where("isActive", "==", true)
      .get();
    memberships.forEach((m) => batch.update(m.ref, { isActive: false }));

    await batch.commit();

    // 7. Delete the Firebase Auth account (hard delete)
    try {
      await auth.deleteUser(targetUid);
    } catch (err: unknown) {
      const code = (err as { code?: string }).code;
      // If the Auth account was already deleted, that's fine
      if (code !== "auth/user-not-found") throw err;
    }

    // 8. Write audit log
    await db.collection("auditLog").add({
      action:    "deleteUser",
      targetUid,
      callerUid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  });
