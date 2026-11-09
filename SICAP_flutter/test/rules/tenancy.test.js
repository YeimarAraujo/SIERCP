// Aislamiento entre instituciones (multitenant) y datos personales (Ley 1581 de 2012).
// Corre con: npm test (levanta el emulador de Firestore con las reglas del proyecto).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, documentId, getDoc, getDocs, query, setDoc, updateDoc, where } from 'firebase/firestore';

let env;

const A = 'inst-a';
const B = 'inst-b';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-sicap',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(() => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const user = (id, role, institutionId) =>
      setDoc(doc(db, 'users', id), { email: `${id}@x.co`, firstName: id, lastName: 'T', role, institutionId });
    const member = (id, institutionId, role) =>
      setDoc(doc(db, 'memberships', `${id}_${institutionId}`), { userId: id, institutionId, role, isActive: true, status: 'approved' });

    await setDoc(doc(db, 'institutions', A), { name: 'A', primaryAdminId: 'adminA' });
    await setDoc(doc(db, 'institutions', B), { name: 'B', primaryAdminId: 'adminB' });

    await user('adminA', 'ADMIN', A);
    await user('adminB', 'ADMIN', B);
    await user('instA', 'INSTRUCTOR', A);
    await user('instB', 'INSTRUCTOR', B);
    await user('studentA', 'USUARIO', A);
    await user('freeStudent', 'USUARIO', null);
    await member('adminA', A, 'ADMIN');
    await member('adminB', B, 'ADMIN');
    await member('instA', A, 'INSTRUCTOR');
    await member('instB', B, 'INSTRUCTOR');
    await member('studentA', A, 'STUDENT');

    await setDoc(doc(db, 'sessions', 'sessA'), { studentId: 'studentA', institutionId: A, metrics: { score: 50 } });
    await setDoc(doc(db, 'sessions', 'sessFree'), { studentId: 'freeStudent', institutionId: null });
    await setDoc(doc(db, 'certificates', 'certA'), { userId: 'studentA', institutionId: A });

    // Instructor independiente, sin institución: ve solo las sesiones de su curso.
    await user('indep', 'INSTRUCTOR', null);
    await setDoc(doc(db, 'courses', 'courseX'), { title: 'X', instructorId: 'indep' });
    await setDoc(doc(db, 'courses', 'courseA'), { title: 'A', instructorId: 'instA', institutionId: A });
    await setDoc(doc(db, 'sessions', 'sessCourseX'), { studentId: 'freeStudent', courseId: 'courseX', startedAt: 1 });
    await setDoc(doc(db, 'sessions', 'sessCourseA'), { studentId: 'studentA', institutionId: A, courseId: 'courseA', startedAt: 2 });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();

describe('perfiles de usuario', () => {
  it('el dueño y su institución pueden leerlo', async () => {
    await assertSucceeds(getDoc(doc(as('studentA'), 'users/studentA')));
    await assertSucceeds(getDoc(doc(as('instA'), 'users/studentA')));
    await assertSucceeds(getDoc(doc(as('adminA'), 'users/studentA')));
  });

  it('otra institución no puede leerlo', async () => {
    await assertFails(getDoc(doc(as('instB'), 'users/studentA')));
    await assertFails(getDoc(doc(as('adminB'), 'users/studentA')));
  });

  it('la institución ve a sus miembros aunque su institución activa sea otra', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'memberships', 'freeStudent_' + B), { userId: 'freeStudent', institutionId: B, role: 'STUDENT', isActive: true, status: 'approved' }));
    await assertSucceeds(getDoc(doc(as('instB'), 'users/freeStudent')));
    await assertFails(getDoc(doc(as('instA'), 'users/freeStudent')));
  });

  it('el admin carga a sus miembros por identificador', async () => {
    await assertSucceeds(getDocs(query(collection(as('adminA'), 'users'), where(documentId(), 'in', ['studentA', 'instA']))));
    await assertFails(getDocs(query(collection(as('adminB'), 'users'), where(documentId(), 'in', ['studentA']))));
  });

  it('nadie lista ni busca por cédula a todos los usuarios', async () => {
    await assertFails(getDocs(query(collection(as('instA'), 'users'), where('identification', '==', '123'))));
    await assertFails(getDocs(collection(as('adminA'), 'users')));
  });
});

describe('sesiones de práctica', () => {
  it('el dueño y su institución pueden leerla', async () => {
    await assertSucceeds(getDoc(doc(as('studentA'), 'sessions/sessA')));
    await assertSucceeds(getDoc(doc(as('instA'), 'sessions/sessA')));
    await assertSucceeds(getDoc(doc(as('adminA'), 'sessions/sessA')));
  });

  it('otra institución no puede leerla, cambiarla ni borrarla', async () => {
    await assertFails(getDoc(doc(as('instB'), 'sessions/sessA')));
    await assertFails(getDoc(doc(as('adminB'), 'sessions/sessA')));
    await assertFails(updateDoc(doc(as('instB'), 'sessions/sessA'), { 'metrics.score': 100 }));
    await assertFails(deleteDoc(doc(as('adminB'), 'sessions/sessA')));
  });

  it('la práctica libre de un estudiante no la lee cualquier instructor', async () => {
    await assertSucceeds(getDoc(doc(as('freeStudent'), 'sessions/sessFree')));
    await assertFails(getDoc(doc(as('instB'), 'sessions/sessFree')));
  });
});

describe('consultas que usan la web y la app', () => {
  const sessions = (uid, ...constraints) => getDocs(query(collection(as(uid), 'sessions'), ...constraints));

  it('el admin lista las sesiones de su institución, no las de otra', async () => {
    await assertSucceeds(sessions('adminA', where('institutionId', '==', A)));
    await assertFails(sessions('adminB', where('institutionId', '==', A)));
  });

  it('el personal ve las sesiones de un estudiante acotadas a su institución', async () => {
    await assertSucceeds(sessions('adminA', where('studentId', '==', 'studentA'), where('institutionId', '==', A)));
    await assertFails(sessions('adminB', where('studentId', '==', 'studentA')));
  });

  it('el instructor y el admin dueño del curso ven las sesiones del curso', async () => {
    await assertSucceeds(sessions('indep', where('courseId', '==', 'courseX')));
    await assertSucceeds(sessions('adminA', where('courseId', '==', 'courseA')));
    await assertSucceeds(sessions('instA', where('studentId', '==', 'studentA'), where('courseId', '==', 'courseA')));
    await assertFails(sessions('instB', where('courseId', '==', 'courseA')));
    await assertFails(sessions('indep', where('courseId', '==', 'courseA')));
  });

  it('el estudiante lista sus propias sesiones', async () => {
    await assertSucceeds(sessions('studentA', where('studentId', '==', 'studentA')));
  });
});

describe('certificados', () => {
  it('el dueño y su institución pueden leerlo', async () => {
    await assertSucceeds(getDoc(doc(as('studentA'), 'certificates/certA')));
    await assertSucceeds(getDoc(doc(as('adminA'), 'certificates/certA')));
  });

  it('otra institución no puede leerlo', async () => {
    await assertFails(getDoc(doc(as('instB'), 'certificates/certA')));
    await assertFails(getDoc(doc(as('adminB'), 'certificates/certA')));
  });
});

describe('autorizaciones de datos (Ley 1581)', () => {
  beforeEach(() => env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), 'consents', 'c1'), { userId: 'studentA', policyVersion: 'v1' })));

  it('el titular ve su autorización; nadie la crea, cambia ni borra desde el cliente', async () => {
    await assertSucceeds(getDoc(doc(as('studentA'), 'consents/c1')));
    await assertFails(getDoc(doc(as('adminA'), 'consents/c1')));
    await assertFails(setDoc(doc(as('studentA'), 'consents/c2'), { userId: 'studentA', policyVersion: 'v1' }));
    await assertFails(updateDoc(doc(as('studentA'), 'consents/c1'), { policyVersion: 'v2' }));
    await assertFails(deleteDoc(doc(as('studentA'), 'consents/c1')));
  });

  it('el usuario no puede escribir su propia constancia de autorización', async () => {
    await assertFails(updateDoc(doc(as('studentA'), 'users/studentA'), { privacy: { policyVersion: 'falsa' } }));
    await assertSucceeds(updateDoc(doc(as('studentA'), 'users/studentA'), { firstName: 'Ana' }));
  });
});

describe('invitaciones a una institución', () => {
  const invite = { userId: 'freeStudent', institutionId: A, role: 'USUARIO', status: 'invited', isActive: false };
  const ref = (uid) => doc(as(uid), 'memberships', `freeStudent_${A}`);

  it('el admin invita a quien ya tiene cuenta, pero no lo aprueba por su cuenta', async () => {
    await assertFails(setDoc(ref('adminA'), { ...invite, status: 'approved', isActive: true }));
    await assertSucceeds(setDoc(ref('adminA'), invite));
    await assertFails(updateDoc(ref('adminA'), { status: 'approved', isActive: true }));
  });

  it('la institución aprueba directo las cuentas que creó', async () => {
    await assertSucceeds(setDoc(doc(as('adminA'), 'memberships', `studentA_${A}`),
      { userId: 'studentA', institutionId: A, role: 'USUARIO', status: 'approved', isActive: true }));
  });

  it('la persona acepta o rechaza; no puede cambiar su rol al aceptar', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'memberships', `freeStudent_${A}`), invite));
    await assertFails(getDoc(doc(as('instA'), 'users/freeStudent')));
    await assertFails(updateDoc(ref('freeStudent'), { status: 'approved', isActive: true, role: 'ADMIN' }));
    await assertSucceeds(updateDoc(ref('freeStudent'), { status: 'approved', isActive: true }));
    await assertSucceeds(getDoc(doc(as('instA'), 'users/freeStudent')));
  });

  it('la persona puede rechazar la invitación', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'memberships', `freeStudent_${A}`), invite));
    await assertSucceeds(deleteDoc(ref('freeStudent')));
  });
});

describe('otros datos personales', () => {
  beforeEach(() => env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'userStats', 'studentA'), { xp: 10 });
    await setDoc(doc(db, 'quizSessions', 'q1'), { userId: 'studentA', institutionId: A });
    await setDoc(doc(db, 'orders', 'o1'), { userId: 'studentA', institutionId: A });
    await setDoc(doc(db, 'transactions', 't1'), { user_id: 'studentA', institutionId: A });
    await setDoc(doc(db, 'user_certificates', 'uc1'), { userId: 'studentA' });
    await setDoc(doc(db, 'supportTickets', 's1'), { userId: 'studentA' });
    await setDoc(doc(db, 'users', 'studentA', 'alerts', 'al1'), { msg: 'x' });
  }));

  it('la propia institución los ve', async () => {
    await assertSucceeds(getDoc(doc(as('instA'), 'userStats/studentA')));
    await assertSucceeds(getDoc(doc(as('instA'), 'quizSessions/q1')));
    await assertSucceeds(getDoc(doc(as('adminA'), 'orders/o1')));
    await assertSucceeds(getDoc(doc(as('adminA'), 'transactions/t1')));
    await assertSucceeds(getDoc(doc(as('instA'), 'users/studentA/alerts/al1')));
    await assertSucceeds(getDocs(query(collection(as('adminA'), 'quizSessions'), where('institutionId', '==', A))));
  });

  it('otra institución no los ve', async () => {
    await assertFails(getDoc(doc(as('instB'), 'userStats/studentA')));
    await assertFails(getDoc(doc(as('instB'), 'quizSessions/q1')));
    await assertFails(getDoc(doc(as('adminB'), 'orders/o1')));
    await assertFails(getDoc(doc(as('adminB'), 'transactions/t1')));
    await assertFails(getDoc(doc(as('adminB'), 'user_certificates/uc1')));
    await assertFails(getDoc(doc(as('adminB'), 'supportTickets/s1')));
    await assertFails(getDoc(doc(as('instB'), 'users/studentA/alerts/al1')));
  });

  it('el dueño ve lo suyo', async () => {
    await assertSucceeds(getDoc(doc(as('studentA'), 'userStats/studentA')));
    await assertSucceeds(getDoc(doc(as('studentA'), 'user_certificates/uc1')));
    await assertSucceeds(getDoc(doc(as('studentA'), 'supportTickets/s1')));
    await assertSucceeds(getDoc(doc(as('studentA'), 'users/studentA/alerts/al1')));
  });
});

describe('nota oficial de la sesión', () => {
  it('el estudiante no puede escribir su nota oficial', async () => {
    await assertFails(setDoc(doc(as('studentA'), 'sessions/nueva'), { studentId: 'studentA', officialGrade: { score: 100 } }));
    await assertSucceeds(setDoc(doc(as('studentA'), 'sessions/nueva'), { studentId: 'studentA', status: 'active' }));
    await assertFails(updateDoc(doc(as('studentA'), 'sessions/sessA'), { officialGrade: { score: 100, approved: true } }));
    await assertSucceeds(updateDoc(doc(as('studentA'), 'sessions/sessA'), { status: 'completed' }));
  });

  it('la señal guardada no se reescribe', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'sessions/sessA/compressions/serie'), { depthTenthsMm: [1, 2] }));
    await assertFails(setDoc(doc(as('studentA'), 'sessions/sessA/compressions/serie'), { depthTenthsMm: [550, 550] }));
  });
});

describe('aprobación del curso', () => {
  it('el estudiante no puede marcarse el curso como aprobado', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'courses/courseA/enrollments/studentA'), { studentId: 'studentA', avgScore: 50 }));
    const ref = doc(as('studentA'), 'courses/courseA/enrollments/studentA');
    await assertFails(updateDoc(ref, { courseApproved: true }));
    await assertFails(updateDoc(ref, { courseApproval: { approved: true } }));
    await assertSucceeds(updateDoc(ref, { avgScore: 60 }));
  });
});

