/**
 * Script de setup inicial de Firestore para SIERCP.
 *
 * Crea:
 *   - institutions/RCP-PRUEBA  (si no existe)
 *   - memberships/<auto-id>    para Admin SIERCP (si no existe)
 *
 * Requisitos:
 *   npm install firebase-admin
 *
 * Uso:
 *   1. Descarga tu Service Account desde Firebase Console →
 *      Configuración del proyecto → Cuentas de servicio → Generar nueva clave privada
 *   2. Guárdala como scripts/service-account.json (NO la subas a git)
 *   3. node scripts/seed_firestore.js
 */

const admin = require('firebase-admin');
const path  = require('path');

// ── Configuración ─────────────────────────────────────────────────────────────

const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'service-account.json');

const INSTITUTION_ID   = 'RCP-PRUEBA';
const ADMIN_SIERCP_UID = 'qsXu5nFciDS7TL8zlpJOKZKT2uw1';

// ── Documentos a crear ────────────────────────────────────────────────────────

const institutionDoc = {
  id:                 INSTITUTION_ID,
  name:               'RCP PRUEBA',
  nit:                null,
  type:               'company',
  status:             'active',
  logoUrl:            null,
  contactEmail:       'admin@rcpprueba.com',
  phoneNumber:        null,
  address:            null,
  city:               'Bogotá',
  country:            'Colombia',
  primaryAdminId:     ADMIN_SIERCP_UID,
  memberCount:        1,
  activeCoursesCount: 0,
  totalSessionsCount: 0,
  createdAt:          admin.firestore.FieldValue.serverTimestamp(),
  updatedAt:          admin.firestore.FieldValue.serverTimestamp(),
  config:             {},
};

const membershipDoc = {
  userId:                     ADMIN_SIERCP_UID,
  institutionId:              INSTITUTION_ID,
  role:                       'ADMIN',
  status:                     'approved',
  isActive:                   true,
  approvedBy:                 'system',
  planType:                   'business',
  planExpiresAt:              null,
  creditBalance:              0,
  sstLicenseNumber:           null,
  sstLicenseVerified:         false,
  sstLicenseExpiresAt:        null,
  usageCurrentUsers:          1,
  usageCurrentCourses:        0,
  usageCertificatesThisMonth: 0,
  usagePeriodStart:           admin.firestore.FieldValue.serverTimestamp(),
  createdAt:                  admin.firestore.FieldValue.serverTimestamp(),
  updatedAt:                  admin.firestore.FieldValue.serverTimestamp(),
};

// ── Runner ────────────────────────────────────────────────────────────────────

async function main() {
  // Inicializar Firebase Admin
  let serviceAccount;
  try {
    serviceAccount = require(SERVICE_ACCOUNT_PATH);
  } catch {
    console.error(
      '\n❌  No se encontró scripts/service-account.json\n' +
      '   Descárgalo desde Firebase Console → Configuración → Cuentas de servicio\n'
    );
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  const db = admin.firestore();

  // ── 1. Institución ──────────────────────────────────────────────────────────
  const instRef = db.collection('institutions').doc(INSTITUTION_ID);
  const instSnap = await instRef.get();

  if (instSnap.exists) {
    console.log(`ℹ️  institutions/${INSTITUTION_ID} ya existe — omitiendo.`);
  } else {
    await instRef.set(institutionDoc);
    console.log(`✅  institutions/${INSTITUTION_ID} creado.`);
  }

  // ── 2. Membership para Admin SIERCP ────────────────────────────────────────
  const membSnap = await db
    .collection('memberships')
    .where('userId',        '==', ADMIN_SIERCP_UID)
    .where('institutionId', '==', INSTITUTION_ID)
    .limit(1)
    .get();

  if (!membSnap.empty) {
    const existing = membSnap.docs[0];
    const data = existing.data();

    // Si existe pero no está aprobado/activo, actualizarlo
    if (data.status !== 'approved' || !data.isActive) {
      await existing.ref.update({
        status:    'approved',
        isActive:  true,
        approvedBy: 'system',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`🔄  memberships/${existing.id} actualizado → status=approved, isActive=true`);
    } else {
      console.log(`ℹ️  Membership de Admin SIERCP ya existe y está activo — omitiendo.`);
    }
  } else {
    const newRef = db.collection('memberships').doc();
    await newRef.set({ id: newRef.id, ...membershipDoc });
    console.log(`✅  memberships/${newRef.id} creado para Admin SIERCP.`);
  }

  console.log('\n🎉  Setup completo. El Admin SIERCP ya puede iniciar sesión.\n');
  process.exit(0);
}

main().catch(err => {
  console.error('❌  Error:', err);
  process.exit(1);
});
