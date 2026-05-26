import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();

const VALID_PLAN_SLUGS = ["pyme", "business", "corporate"];

interface CompanyData {
  razonSocial?: string;
  nit?: string;
  responsable?: string;
  cargo?: string;
  email?: string;
  telefono?: string;
  departamento?: string;
  ciudad?: string;
  direccion?: string;
}

/**
 * provisionCorporateAccount — callable (auth required)
 *
 * Called from SIERCP-WEB after the checkout user is authenticated.
 * Creates: Firestore user doc, institution, admin membership, updates order.
 * Sets custom claims so the Flutter app picks up ADMIN role immediately.
 */
export const provisionCorporateAccount = functions
  .region("us-central1")
  .https.onCall(
    async (
      data: {
        orderId?: string;
        planSlug?: string;
        company?: CompanyData;
      },
      context
    ) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "Autenticación requerida."
        );
      }

      const uid = context.auth.uid;
      const { orderId, planSlug, company } = data ?? {};

      if (!planSlug || !VALID_PLAN_SLUGS.includes(planSlug)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "planSlug inválido."
        );
      }
      if (!company?.razonSocial || !company?.nit || !company?.email) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Datos de empresa incompletos."
        );
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

      // Create institution
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
        adminEmail: company.email.toLowerCase(),
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
      } else {
        const existingRole = userSnap.data()?.role as string | undefined;
        const shouldUpgrade = !["SUPER_ADMIN", "ADMIN"].includes(
          existingRole ?? ""
        );
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

      // Update order (non-fatal if it doesn't exist in dev/demo)
      if (orderId) {
        try {
          await db.collection("orders").doc(orderId).update({
            userId: uid,
            institutionId,
            status: "provisioned",
            provisionedAt: now,
          });
        } catch {
          // Non-fatal
        }
      }

      // Set custom claims for immediate role recognition in Flutter
      await admin.auth().setCustomUserClaims(uid, {
        role: "ADMIN",
        institutionId,
      });

      return { institutionId, uid };
    }
  );
