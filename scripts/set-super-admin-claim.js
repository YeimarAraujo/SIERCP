/**
 * Establece el custom claim { isSuperAdmin: true } en el JWT de Firebase Auth
 * para el UID del Super Admin (Jomar Segurid).
 *
 * Ejecutar UNA SOLA VEZ por entorno (dev, staging, producción).
 * Es idempotente — volver a ejecutarlo sobreescribe con los mismos valores.
 *
 * Requisitos:
 *   - scripts/service-account.json  (NO subir a git)
 *   - node >= 18
 *
 * Uso:
 *   1. Descarga la service account desde Firebase Console →
 *      Configuración del proyecto → Cuentas de servicio → Generar nueva clave privada
 *   2. Guárdala como scripts/service-account.json
 *   3. node scripts/set-super-admin-claim.js
 *
 * Después de ejecutar:
 *   El token existente de Jomar NO se actualiza automáticamente.
 *   Jomar debe cerrar sesión y volver a entrar para que el claim quede activo.
 *   En la app Flutter también se puede forzar con: user.getIdToken(true)
 */

const admin = require('firebase-admin');
const path  = require('path');

// ── Configuración ─────────────────────────────────────────────────────────────

const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'service-account.json');

// UID del Super Admin — verificar en Firebase Console antes de ejecutar
const SUPER_ADMIN_UID = 'tj7W7lGXYfe25tmZpgrQ49YfrWn1';

// Claims que se establecen en el JWT
const SA_CLAIMS = { isSuperAdmin: true };

// ── Runner ────────────────────────────────────────────────────────────────────

async function main() {
  let serviceAccount;
  try {
    serviceAccount = require(SERVICE_ACCOUNT_PATH);
  } catch {
    console.error(
      '\n❌  No se encontró scripts/service-account.json\n' +
      '   Descárgalo desde Firebase Console → Configuración → Cuentas de servicio\n',
    );
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  // ── 1. Verificar que el UID existe en Firebase Auth ─────────────────────────
  let userRecord;
  try {
    userRecord = await admin.auth().getUser(SUPER_ADMIN_UID);
  } catch (e) {
    console.error(`\n❌  UID no encontrado en Firebase Auth: ${SUPER_ADMIN_UID}`);
    console.error('   Verifica el UID en Firebase Console → Authentication → Users\n');
    process.exit(1);
  }

  console.log(`\n👤  Usuario encontrado: ${userRecord.email} (${userRecord.uid})`);

  // ── 2. Mostrar claims actuales ───────────────────────────────────────────────
  const currentClaims = userRecord.customClaims ?? {};
  console.log(`   Claims actuales:  ${JSON.stringify(currentClaims)}`);
  console.log(`   Claims nuevos:    ${JSON.stringify(SA_CLAIMS)}`);

  if (currentClaims.isSuperAdmin === true) {
    console.log('\nℹ️  El claim isSuperAdmin ya está establecido. Re-aplicando de todas formas.\n');
  }

  // ── 3. Establecer custom claim ───────────────────────────────────────────────
  await admin.auth().setCustomUserClaims(SUPER_ADMIN_UID, SA_CLAIMS);

  // ── 4. Verificar que quedó grabado ───────────────────────────────────────────
  const updated = await admin.auth().getUser(SUPER_ADMIN_UID);
  const savedClaims = updated.customClaims ?? {};

  if (savedClaims.isSuperAdmin !== true) {
    console.error('\n❌  Error: el claim no quedó grabado correctamente.');
    console.error(`   Claims actuales: ${JSON.stringify(savedClaims)}`);
    process.exit(1);
  }

  console.log('✅  Custom claim establecido correctamente.');
  console.log('\n⚠️  IMPORTANTE: El token existente de Jomar sigue siendo válido');
  console.log('   pero no tendrá el claim hasta que se fuerce un refresh.');
  console.log('   → Jomar debe cerrar sesión y volver a entrar, o llamar');
  console.log('     FirebaseAuth.instance.currentUser?.getIdToken(true) en Flutter.\n');

  process.exit(0);
}

main().catch(err => {
  console.error('❌  Error inesperado:', err.message ?? err);
  process.exit(1);
});
