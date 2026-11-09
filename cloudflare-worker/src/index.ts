/**
 * SIERCP — Emisor de notificaciones push FCM (Cloudflare Worker, tier gratuito).
 *
 * ¿Por qué un Worker? Para enviar push a un celular con la app CERRADA hace
 * falta llamar a la API FCM HTTP v1 con un token OAuth firmado por una cuenta
 * de servicio. Eso NO se puede hacer de forma segura desde el cliente (web o
 * Flutter) porque expondría la clave privada. Cloudflare Workers tiene tier
 * gratuito (100k req/día) sin tarjeta de crédito y sin Cloud Functions de pago.
 *
 * Flujo:
 *   1. La web/admin obtiene el ID token de Firebase del usuario logueado.
 *   2. Llama POST /send con  Authorization: Bearer <idToken>.
 *   3. El Worker verifica el ID token y que el usuario sea admin (rol en
 *      Firestore), firma un JWT de la cuenta de servicio, obtiene un access
 *      token OAuth y envía a FCM (a tópico o a tokens concretos).
 *
 * Secrets (wrangler secret put ...):
 *   - FIREBASE_SERVICE_ACCOUNT -> JSON completo de la cuenta de servicio.
 * Vars (wrangler.toml):
 *   - PROJECT_ID -> id del proyecto Firebase.
 *
 * Endpoints:
 *   POST /send     -> envío inmediato (requiere admin).
 *   GET  /cron     -> procesa recordatorios programados (lo llama el Cron Trigger).
 *   GET  /health   -> estado.
 */

export interface Env {
  FIREBASE_SERVICE_ACCOUNT: string;
  PROJECT_ID: string;
  // Cron → Vercel API routes (plan Spark, sin Vercel Pro). Opcionales: si no
  // están configurados, los cron de plataforma simplemente no corren.
  APP_URL?: string;        // p.ej. https://siercp.com
  CRON_SECRET?: string;    // secret: wrangler secret put CRON_SECRET
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri: string;
}

interface SendRequest {
  topic?: string; // "all" | "role_student" | "inst_<id>" | ...
  tokens?: string[]; // tokens FCM concretos
  title: string;
  body: string;
  link?: string; // ruta interna para deep-link (p.ej. "/notifications")
  data?: Record<string, string>;
}

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') return new Response(null, { headers: CORS });
    const url = new URL(request.url);
    try {
      if (url.pathname === '/health') return json({ status: 'ok', ts: Date.now() });
      if (url.pathname === '/diag') return await handleDiag(env);
      if (url.pathname === '/send' && request.method === 'POST') return await handleSend(request, env);
      if (url.pathname === '/cron') return await handleCron(env);
      return json({ error: 'Not found' }, 404);
    } catch (err) {
      return json({ error: (err as Error).message }, 500);
    }
  },

  // Cron Triggers (wrangler.toml). Se ramifica por la expresión cron:
  //   */5 * * * * -> recordatorios push (handleCron)
  //   0 * * * *   -> métricas de plataforma (Vercel)
  //   0 9 * * *   -> alertas de vencimiento de plan/SST (Vercel)
  //   0 3 1 * *   -> reset mensual de uso (Vercel)
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    switch (event.cron) {
      case '0 * * * *':
        ctx.waitUntil(callVercelCron(env, 'platform-metrics'));
        ctx.waitUntil(callVercelCron(env, 'check-cohorts'));
        return;
      case '0 9 * * *':
        ctx.waitUntil(callVercelCron(env, 'plan-expiry'));
        return;
      case '0 3 1 * *':
        ctx.waitUntil(callVercelCron(env, 'reset-usage'));
        return;
      default:
        // */5 * * * * → recordatorios push + reconciliar provisionamiento de planes
        // (re-aloja onInstitutionCreated: los triggers Firestore no corren en Spark).
        ctx.waitUntil(handleCron(env).then(() => undefined));
        ctx.waitUntil(callVercelCron(env, 'reconcile-provisioning'));
    }
  },
};

/** Llama una ruta cron de Vercel con el secreto compartido (plan Spark/Hobby). */
async function callVercelCron(env: Env, path: string): Promise<void> {
  if (!env.APP_URL || !env.CRON_SECRET) {
    console.warn(`[cron ${path}] APP_URL/CRON_SECRET no configurados; omitido`);
    return;
  }
  try {
    const res = await fetch(`${env.APP_URL}/api/cron/${path}`, {
      headers: { Authorization: `Bearer ${env.CRON_SECRET}` },
    });
    if (!res.ok) console.error(`[cron ${path}] HTTP ${res.status}`);
  } catch (e) {
    console.error(`[cron ${path}]`, (e as Error).message);
  }
}

/* ----------------------- Diagnóstico (sin login) ------------------------- */

/**
 * GET /diag — comprueba, paso a paso, que el Worker puede operar:
 *   1) que el secret FIREBASE_SERVICE_ACCOUNT existe y es JSON válido,
 *   2) que el service account puede obtener un access token OAuth (esto FALLA
 *      si la cuenta de servicio fue borrada o la clave es inválida),
 *   3) que puede leer Firestore.
 * No expone secretos; solo dice qué paso falla y por qué.
 */
async function handleDiag(env: Env): Promise<Response> {
  const steps: Record<string, unknown> = {};

  // Paso 1: parsear el service account.
  let sa: ServiceAccount;
  try {
    sa = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT) as ServiceAccount;
    steps.serviceAccount = {
      ok: true,
      client_email: sa.client_email,
      hasPrivateKey: typeof sa.private_key === 'string' && sa.private_key.includes('PRIVATE KEY'),
    };
  } catch (e) {
    return json({ ok: false, step: 'serviceAccount', error: 'El secret FIREBASE_SERVICE_ACCOUNT falta o no es JSON válido: ' + (e as Error).message }, 500);
  }

  steps.projectId = env.PROJECT_ID;

  // Paso 2: obtener access token (prueba real de la cuenta de servicio).
  let accessToken: string;
  try {
    accessToken = await getAccessToken(sa);
    steps.oauth = { ok: true };
  } catch (e) {
    return json({
      ok: false,
      step: 'oauth',
      error: 'No se pudo obtener token OAuth. Lo más común: la cuenta de servicio fue ELIMINADA o la clave es inválida → genera una nueva clave en Firebase y vuelve a subir el secret. Detalle: ' + (e as Error).message,
      steps,
    }, 500);
  }

  // Paso 3: leer Firestore (lista 1 doc de users).
  try {
    const url = `https://firestore.googleapis.com/v1/projects/${env.PROJECT_ID}/databases/(default)/documents/users?pageSize=1`;
    const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
    steps.firestore = { ok: res.ok, status: res.status };
    if (!res.ok) {
      steps.firestoreBody = await res.text();
    }
  } catch (e) {
    steps.firestore = { ok: false, error: (e as Error).message };
  }

  return json({ ok: true, message: 'Service account operativo', steps });
}

/* ----------------------------- Envío ------------------------------------- */

async function handleSend(request: Request, env: Env): Promise<Response> {
  const auth = request.headers.get('Authorization') || '';
  const idToken = auth.replace(/^Bearer\s+/i, '');
  if (!idToken) return json({ error: 'Falta Authorization Bearer <idToken>' }, 401);

  const claims = await verifyFirebaseIdToken(idToken, env.PROJECT_ID);
  if (!claims) return json({ error: 'ID token inválido' }, 401);

  const sa = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT) as ServiceAccount;
  const accessToken = await getAccessToken(sa);

  const caller = await checkCaller(claims.sub, env.PROJECT_ID, accessToken);
  if (!caller.isAdmin) {
    return json(
      {
        error: 'No autorizado (se requiere admin)',
        detail: caller.userDocFound
          ? `Tu usuario tiene rol "${caller.role}", que no es admin. Roles admitidos: ${ADMIN_ROLES.join(', ')}.`
          : `No se encontró el documento users/${claims.sub} en Firestore (o el service account no puede leerlo).`,
        uid: claims.sub,
        role: caller.role,
      },
      403
    );
  }

  const payload = (await request.json()) as SendRequest;
  if (!payload.title || !payload.body) return json({ error: 'title y body son obligatorios' }, 400);
  if (!payload.topic && (!payload.tokens || payload.tokens.length === 0)) {
    return json({ error: 'Indica topic o tokens' }, 400);
  }

  const result = await sendFcm(env.PROJECT_ID, accessToken, payload);
  return json({ ok: true, ...result });
}

async function sendFcm(
  projectId: string,
  accessToken: string,
  p: SendRequest
): Promise<{ sent: number; failed: number }> {
  const endpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  const data: Record<string, string> = { ...(p.data || {}) };
  if (p.link) data.link = p.link;

  const base = {
    notification: { title: p.title, body: p.body },
    data,
    android: { priority: 'HIGH' as const },
    apns: { payload: { aps: { sound: 'default' } } },
  };

  const send = async (message: Record<string, unknown>): Promise<boolean> => {
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ message }),
    });
    return res.ok;
  };

  if (p.topic) {
    const ok = await send({ ...base, topic: p.topic });
    return { sent: ok ? 1 : 0, failed: ok ? 0 : 1 };
  }

  let sent = 0;
  let failed = 0;
  for (const token of p.tokens || []) {
    const ok = await send({ ...base, token });
    if (ok) sent++;
    else failed++;
  }
  return { sent, failed };
}

/* ----------------- Recordatorios programados (Cron) ---------------------- */

/**
 * Lee `scheduled_notifications` donde sent==false y sendAt<=ahora, envía y
 * marca como enviados. Doc: { topic|tokens, title, body, link, sendAt(ts), sent }
 */
async function handleCron(env: Env): Promise<Response> {
  const sa = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT) as ServiceAccount;
  const accessToken = await getAccessToken(sa);
  const nowIso = new Date().toISOString();

  const queryUrl = `https://firestore.googleapis.com/v1/projects/${env.PROJECT_ID}/databases/(default)/documents:runQuery`;
  const res = await fetch(queryUrl, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: 'scheduled_notifications' }],
        where: {
          compositeFilter: {
            op: 'AND',
            filters: [
              { fieldFilter: { field: { fieldPath: 'sent' }, op: 'EQUAL', value: { booleanValue: false } } },
              { fieldFilter: { field: { fieldPath: 'sendAt' }, op: 'LESS_THAN_OR_EQUAL', value: { timestampValue: nowIso } } },
            ],
          },
        },
        limit: 50,
      },
    }),
  });

  const rows = (await res.json()) as Array<{ document?: { name: string; fields: Record<string, FirestoreValue> } }>;
  let processed = 0;
  for (const row of rows) {
    if (!row.document) continue;
    const f = row.document.fields;
    const payload: SendRequest = {
      topic: f.topic?.stringValue,
      tokens: f.tokens?.arrayValue?.values?.map((v) => v.stringValue || '').filter(Boolean),
      title: f.title?.stringValue || 'SIERCP',
      body: f.body?.stringValue || '',
      link: f.link?.stringValue,
    };
    await sendFcm(env.PROJECT_ID, accessToken, payload);
    await markSent(row.document.name, accessToken);
    processed++;
  }
  return json({ ok: true, processed });
}

interface FirestoreValue {
  stringValue?: string;
  booleanValue?: boolean;
  arrayValue?: { values?: FirestoreValue[] };
}

async function markSent(docName: string, accessToken: string): Promise<void> {
  const url = `https://firestore.googleapis.com/v1/${docName}?updateMask.fieldPaths=sent`;
  await fetch(url, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: { sent: { booleanValue: true } } }),
  });
}

/* ----------------- Autorización: rol admin del solicitante --------------- */

const ADMIN_ROLES = ['super_admin', 'SUPER_ADMIN', 'institution_admin', 'ADMIN', 'admin'];

/**
 * Lee el rol del solicitante desde Firestore y dice si es admin.
 * Devuelve también el rol y si el doc existe, para diagnosticar rechazos.
 */
async function checkCaller(
  uid: string,
  projectId: string,
  accessToken: string
): Promise<{ isAdmin: boolean; role: string | null; userDocFound: boolean }> {
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (!res.ok) return { isAdmin: false, role: null, userDocFound: false };
  const doc = (await res.json()) as { fields?: { role?: { stringValue?: string } } };
  const role = doc.fields?.role?.stringValue ?? null;
  return { isAdmin: role != null && ADMIN_ROLES.includes(role), role, userDocFound: true };
}

/* ----------------- OAuth: JWT de cuenta de servicio ---------------------- */

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: sa.client_email,
    scope: ['https://www.googleapis.com/auth/firebase.messaging', 'https://www.googleapis.com/auth/datastore'].join(' '),
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
  };

  const enc = new TextEncoder();
  const toB64Url = (obj: unknown) => base64url(enc.encode(JSON.stringify(obj)));
  const unsigned = `${toB64Url(header)}.${toB64Url(claim)}`;

  const key = await importPrivateKey(sa.private_key);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(unsigned));
  const jwt = `${unsigned}.${base64url(new Uint8Array(sig))}`;

  const res = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }),
  });
  const data = (await res.json()) as { access_token?: string; error_description?: string };
  if (!data.access_token) throw new Error(`OAuth falló: ${data.error_description || 'sin access_token'}`);
  return data.access_token;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey('pkcs8', der.buffer, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
}

/* ----------- Verificación del ID token de Firebase (RS256) --------------- */

interface FirebaseClaims {
  sub: string;
  aud: string;
  iss: string;
  exp: number;
  [k: string]: unknown;
}

let cachedCerts: { keys: Record<string, CryptoKey>; expiresAt: number } | null = null;

async function verifyFirebaseIdToken(token: string, projectId: string): Promise<FirebaseClaims | null> {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [headerB64, payloadB64, sigB64] = parts;

  const header = JSON.parse(decodeB64Url(headerB64)) as { kid?: string };
  const claims = JSON.parse(decodeB64Url(payloadB64)) as FirebaseClaims;

  const now = Math.floor(Date.now() / 1000);
  if (claims.exp < now) return null;
  if (claims.aud !== projectId) return null;
  if (claims.iss !== `https://securetoken.google.com/${projectId}`) return null;
  if (!header.kid) return null;

  const key = await getGooglePublicKey(header.kid);
  if (!key) return null;

  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    base64urlToBytes(sigB64),
    new TextEncoder().encode(`${headerB64}.${payloadB64}`)
  );
  return valid ? claims : null;
}

async function getGooglePublicKey(kid: string): Promise<CryptoKey | null> {
  if (cachedCerts && cachedCerts.expiresAt > Date.now() && cachedCerts.keys[kid]) return cachedCerts.keys[kid];
  const res = await fetch('https://www.googleapis.com/robot/v1/metadata/jwk/securetoken@system.gserviceaccount.com');
  const jwks = (await res.json()) as { keys: Array<JsonWebKey & { kid?: string }> };
  const keys: Record<string, CryptoKey> = {};
  for (const jwk of jwks.keys) {
    if (!jwk.kid) continue;
    keys[jwk.kid] = await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
  }
  cachedCerts = { keys, expiresAt: Date.now() + 60 * 60 * 1000 };
  return keys[kid] || null;
}

/* ------------------------- base64url utils ------------------------------- */

function base64url(bytes: Uint8Array): string {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64urlToBytes(s: string): Uint8Array {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(s.length / 4) * 4, '=');
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

function decodeB64Url(s: string): string {
  return new TextDecoder().decode(base64urlToBytes(s));
}
