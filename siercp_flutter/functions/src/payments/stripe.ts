import * as functions from "firebase-functions";
import * as admin     from "firebase-admin";
import Stripe         from "stripe";

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();

// ── Stripe client ─────────────────────────────────────────────────────────────
// La secret key se almacena en Firebase Secret Manager, nunca en código fuente.
// Para configurarla:
//   firebase functions:secrets:set STRIPE_SECRET_KEY
//   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
function getStripe(): Stripe {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) throw new Error("STRIPE_SECRET_KEY no configurada.");
  return new Stripe(key, { apiVersion: "2024-04-10" });
}

// ── Precios del servidor (NUNCA confiar en el cliente para los montos) ────────
const PLAN_PRICES_COP: Record<string, number> = {
  pyme:           299_000,   // COP
  business:       699_000,
  corporate:    1_499_000,
  enterprise:   2_999_000,
  sstSinLicencia: 149_000,
  sstConLicencia: 249_000,
  credits:         49_000,   // por crédito
};

// Stripe espera centavos — COP no tiene centavos fraccionarios, se multiplica x1
// Para USD usarías x100. Ajusta según la moneda configurada en Stripe.
const COP_TO_STRIPE_UNITS = 1;

// ── Helpers ───────────────────────────────────────────────────────────────────

async function getCallerAdminRole(uid: string): Promise<string | null> {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) return null;
  return snap.data()?.role ?? null;
}

async function assertCallerIsAdminOfInstitution(
  callerUid: string,
  institutionId: string
): Promise<void> {
  const role = await getCallerAdminRole(callerUid);
  if (role === "SUPER_ADMIN") return; // SuperAdmin puede gestionar cualquier org

  if (role !== "ADMIN") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Solo administradores pueden gestionar suscripciones."
    );
  }

  // Verify the admin belongs to this institution
  const institutionSnap = await db.collection("institutions").doc(institutionId).get();
  if (!institutionSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Institución no encontrada.");
  }

  const primaryAdminId = institutionSnap.data()?.primaryAdminId as string | undefined;
  if (primaryAdminId !== callerUid) {
    // Fallback: check membership
    const memberSnap = await db
      .collection("memberships")
      .where("userId",        "==", callerUid)
      .where("institutionId", "==", institutionId)
      .where("role",          "==", "ADMIN")
      .where("isActive",      "==", true)
      .limit(1)
      .get();
    if (memberSnap.empty) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "No eres administrador de esta institución."
      );
    }
  }
}

// ── 1. createStripePaymentIntent ──────────────────────────────────────────────
/**
 * Creates a Stripe PaymentIntent for a plan subscription.
 * Returns only the clientSecret to the client — never the full PaymentIntent.
 *
 * The client uses the clientSecret with the Stripe Flutter SDK to confirm
 * payment without the server secret key ever leaving the server.
 */
export const createStripePaymentIntent = functions
  .region("us-central1")
  .runWith({ secrets: ["STRIPE_SECRET_KEY"] })
  .https.onCall(async (
    data: { plan: string; institutionId: string; couponCode?: string },
    context
  ) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const { plan, institutionId, couponCode } = data;

    if (!plan || !institutionId) {
      throw new functions.https.HttpsError("invalid-argument", "plan e institutionId requeridos.");
    }

    // Validate plan
    const amountCOP = PLAN_PRICES_COP[plan];
    if (!amountCOP) {
      throw new functions.https.HttpsError("invalid-argument", `Plan desconocido: ${plan}`);
    }

    // Verify caller is admin of this institution
    await assertCallerIsAdminOfInstitution(context.auth.uid, institutionId);

    const stripe  = getStripe();
    let   amount  = amountCOP * COP_TO_STRIPE_UNITS;

    // Apply coupon if provided (validate server-side, never trust client amount)
    if (couponCode) {
      try {
        const coupon = await stripe.coupons.retrieve(couponCode);
        if (coupon.valid) {
          if (coupon.percent_off) {
            amount = Math.round(amount * (1 - coupon.percent_off / 100));
          } else if (coupon.amount_off) {
            amount = Math.max(0, amount - coupon.amount_off);
          }
        }
      } catch {
        throw new functions.https.HttpsError("invalid-argument", "Cupón inválido o expirado.");
      }
    }

    // Create PaymentIntent
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency:             "cop",
      automatic_payment_methods: { enabled: true },
      metadata: {
        plan,
        institutionId,
        callerUid: context.auth.uid,
      },
    });

    // Store pending payment record in Firestore
    await db.collection("payments").add({
      paymentIntentId: paymentIntent.id,
      institutionId,
      plan,
      amountCOP:       amount,
      currency:        "cop",
      status:          "pending",
      callerUid:       context.auth.uid,
      createdAt:       admin.firestore.FieldValue.serverTimestamp(),
    });

    // Return only the client secret — the full PaymentIntent stays server-side
    return {
      clientSecret:    paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      amountCents:     amount,
      currency:        "cop",
    };
  });

// ── 2. confirmStripeSubscription ──────────────────────────────────────────────
/**
 * Called by the client AFTER the Stripe Flutter SDK has confirmed payment.
 * Verifies the PaymentIntent status directly with Stripe (never trusts the client).
 * Updates the institution's subscription in Firestore on success.
 */
export const confirmStripeSubscription = functions
  .region("us-central1")
  .runWith({ secrets: ["STRIPE_SECRET_KEY"] })
  .https.onCall(async (
    data: { paymentIntentId: string; institutionId: string },
    context
  ) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const { paymentIntentId, institutionId } = data;
    if (!paymentIntentId || !institutionId) {
      throw new functions.https.HttpsError("invalid-argument", "paymentIntentId e institutionId requeridos.");
    }

    await assertCallerIsAdminOfInstitution(context.auth.uid, institutionId);

    const stripe        = getStripe();
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    if (paymentIntent.status !== "succeeded") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Pago no completado. Estado: ${paymentIntent.status}`
      );
    }

    // Verify this PaymentIntent belongs to this institution (metadata check)
    if (paymentIntent.metadata?.institutionId !== institutionId) {
      throw new functions.https.HttpsError("permission-denied", "PaymentIntent no corresponde a esta institución.");
    }

    const plan       = paymentIntent.metadata?.plan as string;
    const now        = admin.firestore.Timestamp.now();
    const expiresAt  = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 días
    );

    // Update institution plan membership
    const planRef = db
      .collection("institutions")
      .doc(institutionId)
      .collection("planMembership")
      .doc("current");

    await planRef.set({
      planType:      plan,
      isActive:      true,
      status:        "approved",
      planStartedAt: now,
      planExpiresAt: expiresAt,
      paymentIntentId,
      updatedAt:     now,
    }, { merge: true });

    // Mark payment as completed
    const payments = await db
      .collection("payments")
      .where("paymentIntentId", "==", paymentIntentId)
      .limit(1)
      .get();
    if (!payments.empty) {
      await payments.docs[0].ref.update({
        status:      "succeeded",
        completedAt: now,
      });
    }

    // Audit log
    await db.collection("auditLog").add({
      action:         "subscriptionActivated",
      institutionId,
      plan,
      paymentIntentId,
      callerUid:      context.auth.uid,
      timestamp:      admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, plan, expiresAt: expiresAt.toDate().toISOString() };
  });

// ── 3. cancelStripeSubscription ───────────────────────────────────────────────
export const cancelStripeSubscription = functions
  .region("us-central1")
  .https.onCall(async (
    data: { institutionId: string },
    context
  ) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const { institutionId } = data;
    if (!institutionId) {
      throw new functions.https.HttpsError("invalid-argument", "institutionId requerido.");
    }

    await assertCallerIsAdminOfInstitution(context.auth.uid, institutionId);

    const planRef = db
      .collection("institutions")
      .doc(institutionId)
      .collection("planMembership")
      .doc("current");

    await planRef.update({
      isActive:     false,
      status:       "cancelled",
      cancelledAt:  admin.firestore.FieldValue.serverTimestamp(),
      cancelledBy:  context.auth.uid,
    });

    await db.collection("auditLog").add({
      action:        "subscriptionCancelled",
      institutionId,
      callerUid:     context.auth.uid,
      timestamp:     admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  });

// ── 4. getSubscriptionStatus ──────────────────────────────────────────────────
export const getSubscriptionStatus = functions
  .region("us-central1")
  .https.onCall(async (
    data: { institutionId: string },
    context
  ) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const { institutionId } = data;
    if (!institutionId) {
      throw new functions.https.HttpsError("invalid-argument", "institutionId requerido.");
    }

    await assertCallerIsAdminOfInstitution(context.auth.uid, institutionId);

    const planSnap = await db
      .collection("institutions")
      .doc(institutionId)
      .collection("planMembership")
      .doc("current")
      .get();

    if (!planSnap.exists) {
      return { hasSubscription: false };
    }

    const d = planSnap.data()!;
    return {
      hasSubscription: true,
      plan:            d.planType,
      isActive:        d.isActive,
      status:          d.status,
      expiresAt:       d.planExpiresAt?.toDate?.()?.toISOString() ?? null,
    };
  });

// ── 5. stripeWebhook — HTTP (no callable) ────────────────────────────────────
/**
 * Stripe calls this endpoint directly when payment events occur.
 * NEVER trust event data from the client — always verify via Stripe signature.
 *
 * Handles:
 *   payment_intent.succeeded        → activate subscription
 *   payment_intent.payment_failed   → mark payment failed
 *   customer.subscription.deleted   → deactivate subscription
 */
export const stripeWebhook = functions
  .region("us-central1")
  .runWith({ secrets: ["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET"] })
  .https.onRequest(async (req, res) => {
    const stripe        = getStripe();
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

    if (!webhookSecret) {
      res.status(500).send("STRIPE_WEBHOOK_SECRET no configurado.");
      return;
    }

    const sig = req.headers["stripe-signature"] as string | undefined;
    if (!sig) {
      res.status(400).send("Falta stripe-signature header.");
      return;
    }

    let event: Stripe.Event;
    try {
      // Verify signature — rejects replayed or tampered events
      event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Firma inválida";
      functions.logger.error("Stripe webhook signature failed:", msg);
      res.status(400).send(`Webhook error: ${msg}`);
      return;
    }

    try {
      switch (event.type) {
        case "payment_intent.succeeded": {
          const pi            = event.data.object as Stripe.PaymentIntent;
          const institutionId = pi.metadata?.institutionId;
          const plan          = pi.metadata?.plan;

          if (institutionId && plan) {
            const expiresAt = admin.firestore.Timestamp.fromDate(
              new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
            );
            await db
              .collection("institutions")
              .doc(institutionId)
              .collection("planMembership")
              .doc("current")
              .set({
                planType:       plan,
                isActive:       true,
                status:         "approved",
                planExpiresAt:  expiresAt,
                paymentIntentId: pi.id,
                updatedAt:      admin.firestore.FieldValue.serverTimestamp(),
              }, { merge: true });

            await db.collection("auditLog").add({
              action:         "webhookSubscriptionActivated",
              institutionId,
              plan,
              paymentIntentId: pi.id,
              timestamp:      admin.firestore.FieldValue.serverTimestamp(),
            });
          }
          break;
        }

        case "payment_intent.payment_failed": {
          const pi = event.data.object as Stripe.PaymentIntent;
          const payments = await db
            .collection("payments")
            .where("paymentIntentId", "==", pi.id)
            .limit(1)
            .get();
          if (!payments.empty) {
            await payments.docs[0].ref.update({
              status:   "failed",
              failedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
          break;
        }

        case "customer.subscription.deleted": {
          const sub           = event.data.object as Stripe.Subscription;
          const institutionId = sub.metadata?.institutionId;
          if (institutionId) {
            await db
              .collection("institutions")
              .doc(institutionId)
              .collection("planMembership")
              .doc("current")
              .update({
                isActive:    false,
                status:      "cancelled",
                cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
              });
          }
          break;
        }

        default:
          functions.logger.info(`Evento Stripe no manejado: ${event.type}`);
      }

      res.status(200).json({ received: true });
    } catch (err) {
      functions.logger.error("Error procesando webhook Stripe:", err);
      res.status(500).send("Error interno del servidor.");
    }
  });
