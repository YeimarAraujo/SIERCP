import * as functions from "firebase-functions";
import * as admin     from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();

/**
 * onUserCreated — Firestore trigger
 *
 * Fires whenever a new user document is created in /users/{uid}.
 * Writes an immutable audit log entry and ensures the `role` field
 * is not SUPER_ADMIN (prevents client-side privilege injection at creation time).
 */
export const onUserCreated = functions
  .region("us-central1")
  .firestore.document("users/{uid}")
  .onCreate(async (snap, context) => {
    const db   = admin.firestore();
    const data = snap.data();
    const uid  = context.params.uid;

    // SECURITY: if someone created a user document with role=SUPER_ADMIN via
    // a client SDK call that bypassed the rules (race condition or rules gap),
    // forcibly downgrade it here. Real SUPER_ADMIN promotion is manual/infra.
    if (data.role === "SUPER_ADMIN") {
      await snap.ref.update({ role: "USUARIO" });
      await db.collection("auditLog").add({
        action:    "blocked_superadmin_injection",
        uid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    // Write creation audit log
    await db.collection("auditLog").add({
      action:    "userCreated",
      uid,
      email:     data.email ?? null,
      role:      data.role  ?? "USUARIO",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
