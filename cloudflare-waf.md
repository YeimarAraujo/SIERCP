# SIERCP — Cloudflare WAF Configuration Guide

**Stack:** Next.js (Vercel) behind Cloudflare proxy  
**Audience:** Jomar Segurid (deployment admin)

---

## Prerequisites

- Domain `siercp.com` proxied through Cloudflare (orange cloud ☁️ enabled)
- Cloudflare plan: **Pro** minimum (required for WAF custom rules and rate limiting)
- Vercel deployment with `X-Forwarded-For` header forwarding enabled

---

## 1. DNS & Proxy Setup

```
Type    Name    Value                   Proxy
A       @       76.76.21.21 (Vercel)    ☁️ Proxied
CNAME   www     cname.vercel-dns.com    ☁️ Proxied
```

Set SSL/TLS mode to **Full (strict)** in Cloudflare → SSL/TLS → Overview.

---

## 2. Security Level & Bot Fight Mode

In **Cloudflare → Security → Settings**:

| Setting | Value | Reason |
|---------|-------|--------|
| Security Level | **High** | Challenge suspicious IPs |
| Bot Fight Mode | **ON** | Block automated scraping |
| Browser Integrity Check | **ON** | Reject headless clients without JS |

---

## 3. WAF Custom Rules

Go to **Security → WAF → Custom Rules** and add the following rules in order.

### Rule 1 — Allow Wompi webhook IPs (bypass all checks)

Wompi sends webhooks from a fixed IP range. Allow them to bypass WAF to prevent false positives.

```
Rule name:   Allow Wompi Webhooks
Expression:  (ip.src in {181.143.108.0/24 201.245.20.0/24} and http.request.uri.path eq "/api/wompi-webhook")
Action:      Skip → WAF Managed Rules
```

> **Note:** Verify current Wompi IP ranges at developers.wompi.io — update this rule if they change.

---

### Rule 2 — Block non-POST to webhook

The Wompi webhook endpoint only accepts POST. Reject everything else before it reaches Next.js.

```
Rule name:   Block non-POST to webhook
Expression:  (http.request.uri.path eq "/api/wompi-webhook" and http.request.method ne "POST")
Action:      Block
Status code: 405
```

---

### Rule 3 — Rate limit checkout API (Cloudflare layer)

This is a second layer of rate limiting on top of the app-level Firestore rate limiter. Defense in depth.

```
Rule name:   Rate limit checkout
Expression:  (http.request.uri.path contains "/api/checkout")
Action:      Rate Limit
Rate:        10 requests per 60 seconds per IP
Action when exceeded: Block for 300 seconds
```

---

### Rule 4 — Block common scanner paths

Block paths frequently probed by automated scanners that have no legitimate purpose in this app.

```
Rule name:   Block scanner paths
Expression:  (
  http.request.uri.path contains "/.env" or
  http.request.uri.path contains "/wp-admin" or
  http.request.uri.path contains "/phpinfo" or
  http.request.uri.path contains "/.git/" or
  http.request.uri.path contains "/admin/config" or
  http.request.uri.path contains "/.well-known/acme" or
  http.request.uri.path contains "/xmlrpc.php"
)
Action: Block
Status code: 404
```

---

### Rule 5 — Challenge suspicious checkout traffic

Challenge (JS challenge) any checkout request that has no referer or comes from a non-browser client.

```
Rule name:   Challenge headless checkout
Expression:  (
  http.request.uri.path contains "/api/checkout" and
  not http.referer contains "siercp.com" and
  http.request.method eq "POST"
)
Action:      JS Challenge
```

> This stops simple `curl` attacks on the checkout endpoint while allowing browser-originated requests.

---

### Rule 6 — Block countries without expected users (optional)

If SIERCP serves only Colombia (and maybe neighboring countries), consider geo-blocking.

```
Rule name:   Geo restrict (optional)
Expression:  (
  not ip.geoip.country in {"CO" "VE" "EC" "PA" "MX" "US"}
  and http.request.uri.path contains "/api/"
)
Action:      Block
Status code: 403
```

> Remove this rule or expand the country list if international usage is expected.

---

## 4. Managed WAF Rules

In **Security → WAF → Managed Rules**, enable:

| Ruleset | Level |
|---------|-------|
| Cloudflare Managed Rules | **High** |
| OWASP Core Rule Set | **Medium** (start here; increase to High after testing) |
| Cloudflare Specials | **ON** |

**Important exceptions — add to WAF Exception list:**

The Wompi webhook sends POST with a JSON body that may trigger OWASP injection rules. Add an exception:

```
Exception name: Wompi webhook bypass
Expression:     (http.request.uri.path eq "/api/wompi-webhook")
Skip:           All managed rules
```

---

## 5. Page Rules (Cache)

Prevent Cloudflare from caching API responses:

| URL pattern | Setting | Value |
|-------------|---------|-------|
| `siercp.com/api/*` | Cache Level | Bypass |
| `siercp.com/api/*` | Disable Apps | ON |

---

## 6. Rate Limiting (Additional — Cloudflare native)

In **Security → Rate Limiting** (requires Pro plan):

### Rule A — Login protection
```
Name:           Login rate limit
URL:            /api/auth/signin
Method:         POST
Rate:           5 per 60 seconds per IP
Action:         Block 600 seconds
```

### Rule B — Checkout plan endpoint
```
Name:           Plan checkout rate limit
URL:            /api/checkout/plan
Method:         POST
Rate:           3 per 60 seconds per IP
Action:         Block 300 seconds
```

---

## 7. Security Headers (via Transform Rules)

In **Rules → Transform Rules → Modify Response Header**, add:

| Header | Value |
|--------|-------|
| `X-Frame-Options` | `DENY` |
| `X-Content-Type-Options` | `nosniff` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` |

> CSP is already set in `next.config.js` via `headers()`. Do not duplicate it here to avoid conflicts.

---

## 8. DDoS Protection (Auto)

Cloudflare automatically applies HTTP DDoS protection at all plan levels. No configuration needed, but verify:

- **Security → DDoS → HTTP DDoS attack protection** → Rule sensitivity: **High**

---

## 9. Real User Monitoring & Alerts

In **Notifications → Create Notification**:

| Notification | Threshold | Channel |
|--------------|-----------|---------|
| Security Events Spike | >100 blocked/hr | Email |
| Rate Limit Events | >50/hr | Email |
| DDoS Attack detected | Any | Email + webhook |

Webhook URL for DDoS alerts (optional): can POST to a Slack channel or internal monitoring endpoint.

---

## 10. Vercel-side: Trust Cloudflare IPs

Since Cloudflare proxies traffic, Vercel sees Cloudflare IPs — not the real client IP. The real IP is in `CF-Connecting-IP` header.

In the app's rate limiter (`src/lib/rate-limiter.ts`), ensure the IP extraction reads from `CF-Connecting-IP` first:

```typescript
// In the rate limiter or API route:
const ip =
  req.headers.get('cf-connecting-ip') ??
  req.headers.get('x-forwarded-for')?.split(',')[0].trim() ??
  '127.0.0.1';
```

> If `CF-Connecting-IP` is not present (local dev), fallback to `X-Forwarded-For` works fine.

---

## 11. Testing the WAF

After deploying rules, verify with:

```bash
# Should be blocked (scanner path)
curl -i https://siercp.com/.env

# Should be blocked (405 Method Not Allowed)
curl -i -X GET https://siercp.com/api/wompi-webhook

# Should be allowed (legitimate checkout)
curl -i -X POST https://siercp.com/api/checkout/plan \
  -H "Content-Type: application/json" \
  -H "Referer: https://siercp.com" \
  -d '{"planType":"pyme","institutionName":"Test SA",...}'

# Should return Cloudflare challenge (no Referer)
curl -i -X POST https://siercp.com/api/checkout/plan \
  -H "Content-Type: application/json" \
  -d '{...}'
```

---

## 12. Ongoing Maintenance

| Task | Frequency |
|------|-----------|
| Review WAF blocked requests log | Weekly |
| Update Wompi IP allowlist if they announce changes | On Wompi announcement |
| Review OWASP false positives and tune exceptions | Monthly |
| Rotate `WOMPI_EVENTS_SECRET` if compromised | Immediately |
| Check rate limit thresholds against real traffic | After launch |
