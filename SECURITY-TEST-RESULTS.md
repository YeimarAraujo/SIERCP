# SIERCP — Security Implementation Test Results

**Date:** 2026-05-22  
**Scope:** Phases 1–5 of the security hardening initiative  
**Engineer:** Yeimar Araujo  
**Stack:** Next.js 16 App Router · Firebase Admin SDK · Flutter/Riverpod · Wompi · Resend

---

## Summary

| Phase | Area | Status | Critical Issues |
|-------|------|--------|-----------------|
| 1 | Input validation & Zod schemas | ✅ PASS | None |
| 2 | Rate limiting & audit logging | ✅ PASS | None |
| 3 | Wompi webhook HMAC validation | ✅ PASS | None |
| 4 | Checkout flow (plan purchase) | ✅ PASS | None |
| 5 | Super Admin console redesign | ✅ PASS | None |

---

## Phase 1 — Input Validation & Schema Hardening

### Tests

#### 1.1 Zod v4 schema validation on `/api/checkout`
**File:** `SIERCP-WEB/src/lib/schemas.ts`

| Test case | Input | Expected | Result |
|-----------|-------|----------|--------|
| Valid course slug | `{ cursoSlug: "rcp-basico" }` | 200 + redirectUrl | ✅ PASS |
| Empty slug | `{ cursoSlug: "" }` | 400 validation error | ✅ PASS |
| Price override attempt | `{ cursoSlug: "x", priceCOP: 1 }` | Price ignored, server-side price used | ✅ PASS |
| XSS in institution name | `<script>alert(1)</script>` | 400 + Zod string rejection | ✅ PASS |
| SQL injection in email | `admin'--@x.com` | 400 email format rejection | ✅ PASS |
| NIT format invalid | `123` | 400 regex rejection | ✅ PASS |
| NIT format valid | `900123456-1` | Accepted | ✅ PASS |
| Oversized institution name | 200-char string | 400 max(120) rejection | ✅ PASS |

#### 1.2 Server-side price resolution
**File:** `functions/src/index.ts` — `createWompiCourseTransaction`

- Client sends only `cursoSlug`; price is always resolved server-side from Firestore or static table.
- Any `amount`, `price`, or `priceCOP` field sent by client is **ignored**.
- Verified: modifying the Flutter request body to include a fake `amountCents` has zero effect on the actual Wompi payment link amount.

**Result:** ✅ Client cannot control payment amounts.

#### 1.3 `PlanCheckoutRequestSchema` validation
**File:** `SIERCP-WEB/src/lib/schemas.ts`

| Field | Constraint | Test | Result |
|-------|-----------|------|--------|
| `planType` | enum of 6 values | `planType: "free"` rejected | ✅ PASS |
| `institutionName` | min 2, max 120 | Single char rejected | ✅ PASS |
| `institutionNit` | regex `^\d{7,10}(-\d)?$` | `abc-def` rejected | ✅ PASS |
| `adminEmail` | email format | `notanemail` rejected | ✅ PASS |
| `adminPhone` | optional, default `''` | Omitted → `''` | ✅ PASS |

---

## Phase 2 — Rate Limiting & Audit Logging

### 2.1 Distributed rate limiter (Firestore-backed)
**File:** `SIERCP-WEB/src/lib/rate-limiter.ts`

| Endpoint | Limit | Window | Test | Result |
|----------|-------|--------|------|--------|
| `/api/checkout` | 5 req | 60s | 6th request → 429 | ✅ PASS |
| `/api/checkout/plan` | 3 req | 60s | 4th request → 429 | ✅ PASS |
| `/api/wompi-webhook` | No limit | — | Unlimited (Wompi IP) | ✅ N/A |

- Rate limit counter is incremented atomically via Firestore `FieldValue.increment(1)`.
- Window key: `${endpoint}:${ip}:${Math.floor(Date.now() / windowMs)}`.
- Counter expires after window naturally; no TTL delete needed.

### 2.2 Audit log events
**File:** `SIERCP-WEB/src/lib/audit-logger.ts`

All critical events write to `audit_logs/{id}` in Firestore:

| Event | Trigger | Verified |
|-------|---------|----------|
| `checkout_started` | POST `/api/checkout` | ✅ |
| `payment_approved` | Wompi webhook APPROVED | ✅ |
| `course_enrollment` | After confirmed payment | ✅ |
| `plan_subscription_activated` | Plan webhook confirmed | ✅ |
| `institution_created` | New institution created post-payment | ✅ |
| `new_institution_checkout_started` | POST `/api/checkout/plan` | ✅ |

- Audit logs include: `type`, `userId`, `institutionId`, `amountCents`, `ip`, `userAgent`, `timestamp`.
- No PII (passwords, tokens) is ever logged.

---

## Phase 3 — Wompi Webhook Security

### 3.1 HMAC-SHA256 signature validation
**File:** `SIERCP-WEB/src/app/api/wompi-webhook/route.ts`

```
signature = HMAC-SHA256(
  key  = WOMPI_EVENTS_SECRET,
  data = properties_concat + timestamp + checksum
)
```

| Test case | Result |
|-----------|--------|
| Valid signature from Wompi | ✅ 200 processed |
| Tampered payload (amount changed) | ✅ 401 rejected |
| Missing `x-event-checksum` header | ✅ 401 rejected |
| Replay with old timestamp | Not mitigated by timestamp alone (Wompi does not guarantee unique timestamps); idempotency guard prevents duplicate processing |
| Invalid HMAC key (env var wrong) | ✅ All events rejected |

**Critical fix verified:** HMAC secret is read lazily inside the handler function (not at module load time), ensuring the env var is available at runtime in Cloud Functions v2.

### 3.2 Idempotency guard
- `enrolled` flag set on `transactions/{id}` before executing business logic.
- Duplicate webhook delivery for same transaction ID is detected and returns `{ received: true }` immediately.
- Race condition: Firestore write of `enrolled: true` uses a server-side `FieldValue.serverTimestamp()` which does not provide atomic test-and-set. **Acceptable risk** given Wompi's delivery guarantees (typically single delivery; very rare duplicate).

### 3.3 IDOR protection
- For `course_enrollment` and `plan_subscription`: transaction's `user_id` is compared to JWT-verified `uid` from Firebase Auth token.
- If mismatch → webhook still returns `{ received: true }` (to avoid Wompi retry storms) but does **not** enroll the user.
- For `new_institution_plan`: IDOR check is skipped by design — these are new customers with no Firebase account yet. Type is set server-side only; clients cannot forge this type.

---

## Phase 4 — Checkout Flow Security

### 4.1 Zero-trust institution creation
**Critical invariant:** No institution or admin account is created before payment is confirmed.

| Step | When | Verified |
|------|------|----------|
| Institution data stored in `transactions/{id}` | On checkout POST | ✅ Metadata only, no Firestore institution doc |
| Institution doc created | After webhook APPROVED | ✅ |
| Welcome email sent | After institution created | ✅ |
| Admin account linkable | After welcome email, user self-registers | ✅ |

**Before fix:** `planes/page.tsx` routed to `/register-institution` which created the institution before payment.  
**After fix:** `planes/page.tsx` routes to `/checkout/plan?plan=${slug}` — institution only created post-APPROVED.

### 4.2 Duplicate NIT guard
- On checkout POST, Firestore is checked for existing `transactions` with same `institutionNit` and `status: PENDING` created within the last 30 minutes.
- If found: returns the existing Wompi payment link (same `redirectUrl`) instead of creating a new one.
- Prevents duplicate institution creation for double-submits.

### 4.3 Server-side plan pricing
**File:** `SIERCP-WEB/src/app/api/checkout/plan/route.ts`

```typescript
const PLAN_PRICES_COP_CENTS: Record<string, number> = {
  pyme:            35_000_000,
  business:        70_000_000,
  corporate:      150_000_000,
  enterprise:     300_000_000,
  sstSinLicencia:  20_000_000,
  sstConLicencia:  45_000_000,
};
```

Client sends only `planType`; price is looked up server-side. Any price in the request body is ignored.

### 4.4 sessionStorage security
- Checkout wizard stores `siercp_plan_tx` (institution name only) in `sessionStorage` for the confirmation page.
- Cleared immediately on confirmation page mount.
- Contains **no sensitive data** (no payment info, no user credentials, no amounts).
- Used purely for display purposes (showing "Tu institución X está lista").

---

## Phase 5 — Super Admin Console

### 5.1 Access control
- All Super Admin routes are guarded by GoRouter redirect checking `UserModel.role == 'SUPER_ADMIN'`.
- Firestore rules include a top-level `SUPER_ADMIN` allow rule that is checked before tenant-scoped rules.
- Super Admin UID is hardcoded in Firestore rules as an additional safety layer.

### 5.2 Sensitive operations confirmed
| Operation | Guard |
|-----------|-------|
| Approve certificate → upgrade role to INSTRUCTOR | SuperAdmin only (Firestore rule) |
| Reject certificate | SuperAdmin only |
| Activate/suspend institution | SuperAdmin only |
| Delete user | SuperAdmin only |
| Change user role globally | SuperAdmin only (via `changeRoleUseCase`) |

### 5.3 New home screen KPIs
- `pendingTransactionsCountProvider` reads `transactions` collection with `status == 'PENDING'`.
- Shows count in both the "pending actions" section and the transactions summary card.
- Read-only from the UI — no write operations from the dashboard KPI cards.

---

## Known Limitations & Accepted Risks

| Item | Severity | Status | Notes |
|------|----------|--------|-------|
| Webhook replay attacks | LOW | Accepted | Idempotency guard prevents duplicate processing; Wompi typically delivers once |
| `enrolled` race condition | LOW | Accepted | Extremely rare; Wompi retry gap is >60s; double-enrollment has no financial impact |
| sessionStorage data on page refresh | INFO | Accepted | Contains only display text (institution name), no sensitive data |
| `prefer_const_constructors` lint hints | INFO | Accepted | Pre-existing style hints; zero security impact |
| `activeColor` deprecated in Switch | INFO | Pre-existing | Unrelated to security; pre-existing in settings screen |

---

## Security Constraints Compliance

The following constraints set at project inception are verified as upheld:

- ✅ **"Ninguna compra puede ocurrir sin checkout"** — All payment flows go through `/api/checkout` or `/api/checkout/plan`.
- ✅ **"Ningún pago puede activarse sin confirmación backend"** — Wompi webhook is the only place that activates plans/enrollments.
- ✅ **"Ningún plan puede asignarse manualmente sin pago validado"** — Plan assignment in webhook is gated on `tx.status === 'APPROVED'`.
- ✅ **"No ejecutar destrucciones en Firestore producción sin backup previo"** — No destructive operations executed.
- ✅ **"No desactivar Firestore Rules ni siquiera temporalmente"** — Rules unchanged; only additive changes.
- ✅ **"No dejar console.log con datos personales en producción"** — Removed unused `userData` logging; no PII in logs.
- ✅ **"No crear endpoints sin withAuth salvo los explícitamente públicos"** — `/api/checkout/plan` is intentionally public (new customers); all other endpoints use `withAuth`.
- ✅ **"No confiar en ningún input del cliente para precios, montos, roles, institutionId, userId"** — All prices from server-side tables; roles/IDs from JWT/Firestore.
- ✅ **"Si la compra no se realiza o se cancela no se crean esas cuentas admins"** — Institution creation is entirely in the webhook post-APPROVED path.

---

## Files Modified (Phases 1–5)

### SIERCP-WEB (Next.js)
| File | Change |
|------|--------|
| `src/lib/schemas.ts` | Added `PlanCheckoutRequestSchema` |
| `src/lib/audit-logger.ts` | Added 3 new event types |
| `src/app/api/checkout/plan/route.ts` | New endpoint (public, rate-limited, Zod-validated) |
| `src/app/api/wompi-webhook/route.ts` | Added payment-link metadata lookup, `new_institution_plan` branch, `plan_subscription` branch |
| `src/services/notification.service.ts` | Added `sendInstitutionWelcome()` |
| `src/app/checkout/plan/page.tsx` | New 5-step checkout wizard |
| `src/app/pago/plan/confirmacion/page.tsx` | New post-payment confirmation page |
| `src/app/tienda/page.tsx` | New store catalog with plans + courses |
| `src/app/planes/page.tsx` | Fixed critical routing bug (pre-payment institution creation) |

### Firebase Cloud Functions
| File | Change |
|------|--------|
| `functions/src/index.ts` | Added `createWompiPlanTransaction`, `createWompiCourseTransaction`; removed unused `BADGES` and `userData` |

### siercp_flutter (Flutter)
| File | Change |
|------|--------|
| `lib/core/services/payment_service.dart` | Complete rewrite replacing dead Stripe stub with Wompi Cloud Functions integration |
| `lib/features/super_admin/data/super_admin_providers.dart` | Added `pendingTransactionsCountProvider` |
| `lib/features/super_admin/presentation/pages/super_admin_home_screen.dart` | Complete redesign with premium dashboard, pending actions, transactions KPI |
| `lib/features/super_admin/presentation/pages/super_admin_dashboard.dart` | Tab count badges from live KPI data |
