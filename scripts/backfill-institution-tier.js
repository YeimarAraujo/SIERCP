/**
 * Backfill del modelo de 3 niveles sobre la colección `institutions`.
 *
 *   - Toda institución sin `tier` → { tier: 'CLIENT', showcase: false }
 *   - La institución de la empresa dueña (JOMAR Academy, id 'jomar-seguridad')
 *     → { tier: 'OWNER', showcase: true }
 *
 * IDEMPOTENTE — solo escribe donde falta `tier`, y siempre asegura el OWNER.
 * Re-ejecutar es seguro.
 *
 * EJECUTAR EN STAGING PRIMERO. Hacer export de backup antes de correr en prod:
 *   gcloud firestore export gs://<bucket>/pre-tier-backfill
 *
 * Uso:
 *   1. scripts/service-account.json  (NO subir a git)
 *   2. node scripts/backfill-institution-tier.js          (dry-run: solo reporta)
 *   3. node scripts/backfill-institution-tier.js --commit  (aplica cambios)
 */

const admin = require('firebase-admin');
const path  = require('path');

const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'service-account.json');
const OWNER_INSTITUTION_ID = 'jomar-seguridad';
const COMMIT = process.argv.includes('--commit');

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
  const now = admin.firestore.FieldValue.serverTimestamp();

  const snap = await db.collection('institutions').get();
  let toBackfill = 0;
  let ownerSet = false;
  const batch = db.batch();

  for (const doc of snap.docs) {
    const d = doc.data();
    const isOwner = doc.id === OWNER_INSTITUTION_ID;

    if (isOwner) {
      // Asegurar siempre OWNER + showcase para la dueña.
      if (d.tier !== 'OWNER' || d.showcase !== true) {
        ownerSet = true;
        if (COMMIT) batch.set(doc.ref, { tier: 'OWNER', showcase: true, updatedAt: now }, { merge: true });
        console.log(`  OWNER  → ${doc.id} (${d.name ?? '—'})`);
      }
      continue;
    }

    if (d.tier === undefined || d.tier === null) {
      toBackfill++;
      if (COMMIT) batch.set(doc.ref, { tier: 'CLIENT', showcase: false, updatedAt: now }, { merge: true });
      console.log(`  CLIENT → ${doc.id} (${d.name ?? '—'})`);
    }
  }

  console.log(`\nInstituciones totales: ${snap.size}`);
  console.log(`A backfill como CLIENT: ${toBackfill}`);
  console.log(`OWNER a fijar:          ${ownerSet ? 1 : 0}`);

  if (!COMMIT) {
    console.log('\nℹ️  DRY-RUN. Nada escrito. Re-ejecuta con --commit para aplicar.\n');
    process.exit(0);
  }

  await batch.commit();
  console.log('\n✅  Backfill aplicado.\n');
  process.exit(0);
}

main().catch((err) => {
  console.error('❌  Error inesperado:', err.message ?? err);
  process.exit(1);
});
