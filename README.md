# SIERCP
SIERCP es una plataforma tecnológica de grado clínico y educativo diseñada para modernizar, estandarizar y monitorizar el entrenamiento en Reanimación Cardiopulmonar (RCP). 
# Integración de Pagos Wompi — SIERCP

Implementación completa de pagos con **Wompi** para la plataforma SIERCP, incluyendo tarjeta crédito/débito, PSE y transferencia bancaria.

---

## Archivos entregados

```
checkout/
├── services/
│   └── wompi.service.ts          ← Servicio principal de Wompi (tipos, helpers, API)
├── hooks/
│   └── useWompiCheckout.ts       ← Hook que orquesta el flujo de pago completo
├── components/
│   ├── CardForm.tsx              ← Formulario de tarjeta (Luhn, tokenización PCI)
│   └── PSEForm.tsx               ← Formulario PSE (bancos en tiempo real desde Wompi)
├── app/
│   ├── checkout/
│   │   ├── page.tsx              ← Página principal de checkout
│   │   └── resultado/
│   │       └── page.tsx          ← Landing de resultado PSE (polling automático)
│   └── api/
│       ├── wompi/
│       │   └── route.ts          ← API Route: crea transacciones (protege llaves privadas)
│       └── wompi-webhook/
│           └── route.ts          ← API Route: recibe y valida webhooks de Wompi
└── .env.example                  ← Plantilla de variables de entorno
```

---

## Flujos de pago

### Tarjeta (CARD)
```
Cliente                          Wompi API          Tu Servidor (Next.js)
   │                                 │                       │
   ├─ tokenizeCard() ───────────────►│                       │
   │◄─ tok_xxx ──────────────────────┤                       │
   │                                 │                       │
   ├─ POST /api/wompi ──────────────────────────────────────►│
   │  { token, amount, ref, ... }    │                       │
   │                                 │         SHA-256 sign  │
   │                                 │◄── POST /transactions ┤
   │                                 │─── transaction ──────►│
   │◄──────────────────────────────────── { id, status } ───┤
   │                                 │                       │
   ├─ if APPROVED → /student/home    │                       │
```

### PSE
```
Cliente               Tu Servidor          Wompi           Banco
   │                      │                  │               │
   ├─ POST /api/wompi ────►│                  │               │
   │                       ├─ POST /tx PSE ──►│               │
   │                       │◄── redirect_url ─┤               │
   │◄── redirect_url ──────┤                  │               │
   ├─ window.location.href ──────────────────────────────────►│
   │                                          │  (usuario     │
   │                                          │   autentica)  │
   │◄──────────────────── redirect a /checkout/resultado ─────┤
   │                                          │               │
   │  [Webhook] ──────────────────────────────►               │
   │  Wompi → POST /api/wompi-webhook         │               │
   │  → Firestore actualiza + inscribe        │               │
```

---

## Seguridad implementada

| Amenaza | Mitigación |
|---|---|
| Exposición de datos de tarjeta | Tokenización directa en Wompi (PCI SAQ-A). Los datos nunca tocan tu servidor. |
| Llave privada expuesta | `WOMPI_PRIVATE_KEY` solo existe en el servidor (Next.js API Route). |
| Firma de integridad | SHA-256 generado en servidor con `WOMPI_INTEGRITY_KEY` para prevenir manipulación de montos. |
| Webhooks falsos | Validación de firma HMAC-SHA256 con `WOMPI_EVENTS_SECRET` en cada webhook. |
| Doble inscripción | Idempotencia por referencia única + flag `enrolled` en Firestore. |
| Acceso no autenticado | Todas las API Routes verifican el `idToken` de Firebase antes de procesar. |
| Manipulación del monto | El monto se toma de `curso.precioCOP` en el servidor, no del cliente. |

---

## Configuración inicial

### 1. Variables de entorno
```bash
cp .env.example .env.local
# Completa con tus llaves del dashboard de Wompi
```

### 2. Dashboard de Wompi → Webhooks
Configura el webhook apuntando a:
```
https://tu-dominio.com/api/wompi-webhook
```
Eventos: `transaction.updated`

### 3. Cuentas de prueba PSE (sandbox)
En sandbox, Wompi simula PSE. Usa el banco **"Banco de Bogotá (Pruebas)"**.
El estado se puede controlar con montos especiales (ver docs de Wompi).

### 4. Tarjetas de prueba (sandbox)
| Número | Marca | Resultado |
|---|---|---|
| 4242 4242 4242 4242 | Visa | APPROVED |
| 4111 1111 1111 1111 | Visa | DECLINED |
| 5254 1336 3422 1534 | Mastercard | APPROVED |

CVC: cualquier 3 dígitos. Exp: cualquier fecha futura.

---12

## Dependencias requeridas

```bash
npm install firebase firebase-admin
```

No se necesitan SDKs adicionales de Wompi; la integración usa la REST API directamente.

---

## Documentación oficial

- [Wompi Docs](https://docs.wompi.co)
- [Referencia de transacciones](https://docs.wompi.co/docs/colombia/transacciones-de-pago)
- [Webhooks](https://docs.wompi.co/docs/colombia/eventos)
- [PSE](https://docs.wompi.co/docs/colombia/transacciones-de-pago#pse)
- [Tokenización de tarjetas](https://docs.wompi.co/docs/colombia/tokens-de-tarjetas)