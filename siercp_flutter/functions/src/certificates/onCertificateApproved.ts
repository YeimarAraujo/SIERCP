import * as functions from "firebase-functions";
import * as admin     from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();

const db   = admin.firestore();
const auth = admin.auth();

/**
 * onCertificateApproved — Firestore trigger
 *
 * Fires when a document in /userCertificates/{certId} transitions to
 * certVerification == "approved".
 *
 * Responsibilities (server-authoritative — never trust client writes for role changes):
 *   1. Promote the user's global role to INSTRUCTOR via Firestore + Auth custom claims.
 *   2. Write an in-app notification to /notifications/{userId}/items/{notifId}.
 *   3. Write an immutable audit log entry.
 *
 * If the document was already approved or the user is already an INSTRUCTOR/SUPER_ADMIN,
 * the function is idempotent and returns early.
 */
export const onCertificateApproved = functions
  .region("us-central1")
  .firestore.document("userCertificates/{certId}")
  .onWrite(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();

    // Only proceed on updates (not creates or deletes)
    if (!change.before.exists || !change.after.exists) return;

    const wasApproved = before?.certVerification === "approved";
    const isApproved  = after?.certVerification  === "approved";

    // Only fire when the field transitions to "approved"
    if (wasApproved || !isApproved) return;

    const userId = after.userId as string | undefined;
    if (!userId) {
      functions.logger.error("onCertificateApproved: missing userId", { certId: context.params.certId });
      return;
    }

    // Fetch current user doc to avoid downgrading a SUPER_ADMIN
    const userSnap = await db.collection("users").doc(userId).get();
    if (!userSnap.exists) {
      functions.logger.error("onCertificateApproved: user not found", { userId });
      return;
    }

    const currentRole = userSnap.data()?.role as string | undefined;

    // Idempotency: nothing to do if already INSTRUCTOR or higher
    if (currentRole === "INSTRUCTOR" || currentRole === "SUPER_ADMIN") {
      functions.logger.info("onCertificateApproved: user already has elevated role — skipping", {
        userId,
        currentRole,
      });
      return;
    }

    const certId      = context.params.certId;
    const approvedBy  = after.approvedBy  as string | undefined;
    const certType    = after.certType    as string | undefined;
    const now         = admin.firestore.FieldValue.serverTimestamp();

    // ── 1. Promote role in Firestore ──────────────────────────────────────────
    await db.collection("users").doc(userId).update({
      role:                 "INSTRUCTOR",
      certVerification:     "approved",
      certVerifiedAt:       now,
      certVerifiedBy:       approvedBy ?? null,
      independentInstructor: true,
    });

    // ── 2. Set custom claim on Auth token (picked up on next token refresh) ──
    try {
      await auth.setCustomUserClaims(userId, { role: "INSTRUCTOR" });
    } catch (err) {
      // Non-fatal: the Firestore role is the source of truth for server checks.
      // The Auth claim just speeds up client-side guard reads.
      functions.logger.warn("onCertificateApproved: failed to set custom claim", { userId, err });
    }

    // ── 3. Write in-app notification ──────────────────────────────────────────
    await db
      .collection("notifications")
      .doc(userId)
      .collection("items")
      .add({
        type:      "certificate_approved",
        title:     "¡Certificado aprobado!",
        body:      "Tu solicitud de instructor independiente fue aprobada. Ya puedes operar sin una organización.",
        certId,
        certType:  certType ?? null,
        isRead:    false,
        createdAt: now,
      });

    // ── 4. Audit log (immutable — Cloud Function is the only writer) ──────────
    await db.collection("auditLog").add({
      action:    "certificateApproved",
      userId,
      certId,
      certType:  certType ?? null,
      approvedBy: approvedBy ?? "unknown",
      newRole:   "INSTRUCTOR",
      timestamp: now,
    });

    functions.logger.info("onCertificateApproved: promoted user to INSTRUCTOR", {
      userId,
      certId,
      approvedBy,
    });
  });
