/**
 * Semilla del catálogo de Skills de PLATAFORMA (S2).
 *
 * Crea skillCategories + skills con rúbricas (niveles) y triggers de telemetría AHA.
 * Valores razonables y EDITABLES luego desde el panel Super Admin.
 *
 * IDEMPOTENTE — usa IDs determinísticos (= slug) y { merge: true }.
 *
 * Umbrales alineados con AppConstants (AHA): passScore=70, excellentScore=85.
 *
 * Uso:
 *   1. scripts/service-account.json
 *   2. node scripts/seed-skills-catalog.js
 */
const admin = require('firebase-admin');
const path  = require('path');
const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'service-account.json');

// Niveles estándar (rúbrica sobre qualityScore 0..100)
const LEVELS = [
  { level: 'BASICO',      order: 1, minScore: 60, label: 'Básico' },
  { level: 'INTERMEDIO',  order: 2, minScore: 70, label: 'Intermedio' },
  { level: 'AVANZADO',    order: 3, minScore: 85, label: 'Avanzado' },
  { level: 'PROFESIONAL', order: 4, minScore: 95, label: 'Profesional' },
];

const CATEGORIES = [
  { id: 'reanimacion', area: 'SALUD', name: 'Reanimación', slug: 'reanimacion',
    description: 'Competencias de RCP y soporte vital.', icon: 'bi-heart-pulse', order: 0, active: true },
  { id: 'primeros-auxilios', area: 'SALUD', name: 'Primeros Auxilios', slug: 'primeros-auxilios',
    description: 'Atención inicial de emergencias.', icon: 'bi-bandaid', order: 1, active: true },
];

const SKILLS = [
  {
    id: 'rcp-adulto-aha', categoryId: 'reanimacion', area: 'SALUD',
    name: 'RCP Adulto (AHA)', slug: 'rcp-adulto-aha', code: 'RCP-ADU',
    description: 'Compresiones torácicas de alta calidad en adulto según guías AHA (50–60 mm, 100–120/min).',
    levels: LEVELS,
    triggers: [{ type: 'SESSION', patientType: 'ADULT', minScore: 60, requiresTelemetry: true }],
    issuerType: 'PLATFORM', issuerInstitutionId: null, active: true,
  },
  {
    id: 'rcp-pediatrico-aha', categoryId: 'reanimacion', area: 'SALUD',
    name: 'RCP Pediátrico (AHA)', slug: 'rcp-pediatrico-aha', code: 'RCP-PED',
    description: 'RCP en paciente pediátrico según guías AHA (40–50 mm).',
    levels: LEVELS,
    triggers: [{ type: 'SESSION', patientType: 'CHILD', minScore: 60, requiresTelemetry: true }],
    issuerType: 'PLATFORM', issuerInstitutionId: null, active: true,
  },
  {
    id: 'rcp-lactante-aha', categoryId: 'reanimacion', area: 'SALUD',
    name: 'RCP Lactante (AHA)', slug: 'rcp-lactante-aha', code: 'RCP-LAC',
    description: 'RCP en lactante según guías AHA.',
    levels: LEVELS,
    triggers: [{ type: 'SESSION', patientType: 'INFANT', minScore: 60, requiresTelemetry: true }],
    issuerType: 'PLATFORM', issuerInstitutionId: null, active: true,
  },
];

const BADGES = [
  { id: 'rcp-master', name: 'RCP Master', slug: 'rcp-master', tier: 'GOLD',
    description: 'Obtuvo las tres competencias de RCP (adulto, pediátrico, lactante).',
    imageUrl: null, active: true,
    requirement: { type: 'SKILL_SET', skillIds: ['rcp-adulto-aha', 'rcp-pediatrico-aha', 'rcp-lactante-aha'] } },
  { id: 'primer-skill', name: 'Primera Competencia', slug: 'primer-skill', tier: 'BRONZE',
    description: 'Obtuvo su primera skill verificada.', imageUrl: null, active: true,
    requirement: { type: 'COUNT', count: 1 } },
];

const LEARNING_PATHS = [
  {
    id: 'rcp-completo', name: 'RCP Completo (AHA)', slug: 'rcp-completo',
    description: 'Domina la reanimación en adulto, pediátrico y lactante.',
    level: 'Intermedio', estimatedHours: 24, institutionId: null,
    courseIds: [], skillIds: ['rcp-adulto-aha', 'rcp-pediatrico-aha', 'rcp-lactante-aha'],
    active: true,
  },
];

async function main() {
  let serviceAccount;
  try { serviceAccount = require(SERVICE_ACCOUNT_PATH); }
  catch { console.error('\n❌  Falta scripts/service-account.json\n'); process.exit(1); }

  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const db = admin.firestore();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();

  for (const c of CATEGORIES) batch.set(db.doc(`skillCategories/${c.id}`), { ...c, createdAt: now }, { merge: true });
  for (const s of SKILLS)     batch.set(db.doc(`skills/${s.id}`), { ...s, createdAt: now, createdBy: 'seed-script' }, { merge: true });
  for (const b of BADGES)     batch.set(db.doc(`badges/${b.id}`), { ...b }, { merge: true });
  for (const p of LEARNING_PATHS) batch.set(db.doc(`learningPaths/${p.id}`), { ...p, createdAt: now }, { merge: true });
  // Inicializar contador de skillCode si no existe
  batch.set(db.doc('platform/counters'), { skillSeq: 0 }, { merge: true });

  await batch.commit();
  console.log(`✅  Catálogo semillado: ${CATEGORIES.length} categorías, ${SKILLS.length} skills, ${BADGES.length} badges, ${LEARNING_PATHS.length} rutas.`);
  process.exit(0);
}

main().catch((err) => { console.error('❌ ', err.message ?? err); process.exit(1); });
