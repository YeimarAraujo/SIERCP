/**
 * Crea/actualiza el singleton `platform/config` — capa Nivel 2 (SIERCP SaaS)
 * del modelo de 3 niveles (JOMAR Group › SIERCP SaaS › Instituciones).
 *
 * Contiene: catálogo de planes (límites + precio de referencia), branding global
 * y feature flags del producto. Las reglas permiten lectura a cualquier
 * autenticado y escritura SOLO a SUPER_ADMIN (ver §8b en firestore.rules).
 *
 * IDEMPOTENTE — usa { merge: true }; re-ejecutar es seguro.
 *
 * NOTA: los PRECIOS AUTORITATIVOS para cobro viven server-side en las Cloud
 * Functions (PLAN_PRICES_COP_CENTS). `priceMonthlyCOP` aquí es de REFERENCIA
 * para UI; nunca se usa para calcular montos de cobro.
 *
 * Uso:
 *   1. scripts/service-account.json  (NO subir a git)
 *   2. node scripts/seed-platform-config.js
 */

const admin = require('firebase-admin');
const path  = require('path');

const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'service-account.json');

// Límites por plan. Alineados con onInstitutionCreated (pyme) y el catálogo SaaS.
const PLANS = {
  pyme: {
    label: 'PYME', priceMonthlyCOP: 350000,
    maxStudents: 15, maxInstructors: 1, maxDevices: 1, maxActiveCourses: 3, maxSkillsPerMonth: 50,
    historyMonths: 6, liveSessions: false, biReports: false, api: false, multiSite: false,
  },
  business: {
    label: 'Business', priceMonthlyCOP: 700000,
    maxStudents: 50, maxInstructors: 5, maxDevices: 3, maxActiveCourses: 10, maxSkillsPerMonth: 200,
    historyMonths: 12, liveSessions: true, biReports: false, api: false, multiSite: false,
  },
  corporate: {
    label: 'Corporate', priceMonthlyCOP: 1500000,
    maxStudents: 200, maxInstructors: 20, maxDevices: 10, maxActiveCourses: 40, maxSkillsPerMonth: 1000,
    historyMonths: 24, liveSessions: true, biReports: true, api: true, multiSite: true,
  },
  enterprise: {
    label: 'Enterprise', priceMonthlyCOP: 3000000,
    maxStudents: -1, maxInstructors: -1, maxDevices: -1, maxActiveCourses: -1, maxSkillsPerMonth: -1,
    historyMonths: -1, liveSessions: true, biReports: true, api: true, multiSite: true,
  },
  sstSinLicencia: {
    label: 'SST sin licencia', priceMonthlyCOP: 200000,
    maxStudents: 10, maxInstructors: 1, maxDevices: 1, maxActiveCourses: 10, maxSkillsPerMonth: 50,
    historyMonths: 12, liveSessions: false, biReports: false, api: false, multiSite: false, requiresSstLicense: false,
  },
  sstConLicencia: {
    label: 'SST con licencia', priceMonthlyCOP: 450000,
    maxStudents: 25, maxInstructors: 3, maxDevices: 2, maxActiveCourses: 20, maxSkillsPerMonth: 150,
    historyMonths: 24, liveSessions: true, biReports: true, api: false, multiSite: false, requiresSstLicense: true,
  },
};

const CONFIG = {
  plans: PLANS,
  branding: {
    name: 'SIERCP',
    primaryColor: '#14B8A6',
    logoUrl: null,
  },
  featureFlags: {
    skillsEngine: false,   // se activa en S2
    publicPassport: false, // se activa en S3
  },
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedBy: 'seed-script',
};

async function main() {
  let serviceAccount;
  try {
    serviceAccount = require(SERVICE_ACCOUNT_PATH);
  } catch {
    console.error('\n❌  No se encontró scripts/service-account.json\n');
    process.exit(1);
  }

  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const db = admin.firestore();

  await db.doc('platform/config').set(CONFIG, { merge: true });

  const snap = await db.doc('platform/config').get();
  console.log('✅  platform/config escrito. Planes:', Object.keys(snap.data().plans).join(', '));
  process.exit(0);
}

main().catch((err) => {
  console.error('❌  Error inesperado:', err.message ?? err);
  process.exit(1);
});
