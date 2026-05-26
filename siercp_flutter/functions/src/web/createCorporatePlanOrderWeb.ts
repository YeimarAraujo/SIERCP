import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();

// Server-side price table — client never sends amounts
const CORPORATE_MONTHLY_COP: Record<string, number> = {
  pyme: 380_000,
  business: 790_000,
  corporate: 1_580_000,
};

const CORPORATE_DEFAULT_DISCOUNTS: Record<string, number> = {
  pyme: 10,
  business: 15,
  corporate: 25,
};

const CORPORATE_IVA_RATE = 0.19;

/**
 * createCorporatePlanOrderWeb — callable (no auth required)
 *
 * Called from the SIERCP-WEB checkout. Creates an order doc with authoritative
 * server-side pricing. The client sends NO financial amounts.
 */
export const createCorporatePlanOrderWeb = functions
  .region("us-central1")
  .https.onCall(
    async (
      data: {
        planSlug?: string;
        company?: Record<string, unknown>;
        payMethod?: string;
        cardLast4?: string | null;
        bank?: string | null;
      },
      _context
    ) => {
      const { planSlug, company, payMethod, cardLast4 = null, bank = null } =
        data ?? {};

      if (!planSlug || !(planSlug in CORPORATE_MONTHLY_COP)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Plan corporativo inválido."
        );
      }
      if (!payMethod || !["card", "pse", "transfer"].includes(payMethod)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Método de pago inválido."
        );
      }

      // Read discount from Firestore (editable by SuperAdmin)
      let annualDiscountPercent: number =
        CORPORATE_DEFAULT_DISCOUNTS[planSlug] ?? 0;
      try {
        const pricingSnap = await db
          .doc(`pricing_plans/corporativo-${planSlug}`)
          .get();
        if (pricingSnap.exists) {
          const raw = pricingSnap.data()?.annualDiscountPercent;
          if (typeof raw === "number" && raw >= 0 && raw <= 100) {
            annualDiscountPercent = raw;
          }
        }
      } catch {
        // Fallback to hardcoded defaults
      }

      const monthlyBaseCOP = CORPORATE_MONTHLY_COP[planSlug];
      const annualFullCOP = monthlyBaseCOP * 12;
      const discountAmount = Math.round(
        annualFullCOP * (annualDiscountPercent / 100)
      );
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
    }
  );
