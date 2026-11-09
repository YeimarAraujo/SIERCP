# SIERCP Push — Cloudflare Worker (FCM, gratis)

Emisor de notificaciones push **gratuito** para SIERCP. Reemplaza la necesidad
de Cloud Functions de pago: envía a Firebase Cloud Messaging (FCM HTTP v1)
firmando un token OAuth con la cuenta de servicio de Firebase.

- Tier gratuito de Cloudflare Workers: **100.000 requests/día**, sin tarjeta.
- Cron Trigger gratuito para recordatorios programados.

## 1. Requisitos

- Node 18+ y `npm`.
- Una cuenta gratuita de Cloudflare.
- El **service account JSON** de tu proyecto Firebase:
  Consola Firebase → ⚙️ Configuración del proyecto → *Cuentas de servicio* →
  *Generar nueva clave privada*. Descarga el `.json`.

## 2. Instalar

```bash
cd cloudflare-worker
npm install
```

## 3. Configurar

1. Edita `wrangler.toml` y pon tu `PROJECT_ID` real (el de Firebase).
2. Carga el service account como **secret** (no se sube al repo):

```bash
# Pega el contenido COMPLETO del .json cuando lo pida (una sola línea o pegado tal cual):
npx wrangler secret put FIREBASE_SERVICE_ACCOUNT
```

## 4. Probar en local

```bash
npm run dev
# en otra terminal:
curl http://localhost:8787/health
```

## 5. Desplegar

```bash
npm run deploy
```

Wrangler te dará una URL del estilo `https://siercp-push.<tu-subdominio>.workers.dev`.
Copia esa URL a la web en `NEXT_PUBLIC_PUSH_WORKER_URL` (ver `SIERCP-WEB`).

## 6. Endpoints

### `POST /send` (requiere admin)

Headers: `Authorization: Bearer <Firebase ID token del admin>`

Body (a un tópico):

```json
{ "topic": "all", "title": "Mantenimiento", "body": "El sábado 10pm", "link": "/notifications" }
```

Body (a usuarios concretos por token FCM):

```json
{ "tokens": ["<fcmToken1>", "<fcmToken2>"], "title": "Tu certificado está listo", "body": "Ábrelo aquí", "link": "/profile/certificados" }
```

Tópicos disponibles (a los que la app Flutter se suscribe sola):
`all`, `role_<rol>` (p.ej. `role_USUARIO`), `inst_<institutionId>`.

### `GET /cron`

Procesa la colección `scheduled_notifications` (recordatorios cuyo `sendAt`
ya pasó). Lo invoca el Cron Trigger cada 5 minutos automáticamente; también
puedes llamarlo a mano para probar.

## 7. Seguridad

- Solo usuarios con rol admin (verificado contra Firestore con el ID token)
  pueden usar `/send`.
- La clave privada nunca toca el cliente: vive como secret del Worker.
- El Worker verifica la firma RS256 del ID token contra los certificados
  públicos de Google antes de confiar en él.
