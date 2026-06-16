# Diseño — Sedes (multi-sede) + Enforcement de plan

Fecha: 2026-06-15 · Decisiones tomadas con el usuario.

## 1. Vencimiento de plan (IMPLEMENTADO)

Política: **gracia de 7 días → suspensión reversible**.

```
activa ──(planExpiresAt < now)──► past_due ──(7 días sin pago)──► suspended
  ▲                                                                   │
  └──────────────────── pago (webhook Wompi) ◄────────────────────────┘
```

- Fuente de verdad de la expiración: `institutions/{id}/planMembership/current.planExpiresAt`
  (provisionada por `cron/reconcile-provisioning`).
- `cron/plan-expiry` (diario):
  - 3 días antes → alerta (ya existía).
  - vencido y `status != past_due` → marca `past_due` + `pastDueSince` + aviso en calendario.
  - `past_due` ≥ 7 días → `suspendInstitution()`.
- `suspendInstitution()` (`src/lib/plan-enforcement.ts`) pone `isActive=false` y marca
  `suspendedByPlan=true` en: institución (`status='suspended'`), `planMembership/current`,
  **usuarios** de la institución (excepto SUPER_ADMIN), **membresías**, **cursos** y **sedes**.
  Efecto: los admins no entran al panel web (`withAuth` exige `isActive`), los usuarios
  pierden acceso en Flutter (memberships inactivas) y los cursos quedan ocultos.
- Pago → `activatePlanSubscription()` renueva la subcolección + doc de institución y llama
  `reactivateInstitution()`, que re-habilita **solo** lo marcado `suspendedByPlan`
  (preserva desactivaciones manuales del admin). Todo idempotente, sin borrados.

> Nota de datos: el sistema tenía 3 representaciones del plan (top-level `planType/planExpiresAt`,
> map `planMembership` en el doc, y subcolección `planMembership/current`). El webhook ahora
> escribe las tres de forma consistente; la subcolección es la canónica para el cron.

## 2. Sedes — Arquitectura elegida: **scope dentro de la institución**

Una institución = un plan = una factura. Las sedes son sub-unidades.

### Modelo de datos
```
institutions/{inst}                      ← plan, facturación
  sedes/{sede}  { institutionId, name, city, address, adminId, isActive }
users/{uid}        { institutionId, role, sedeId? }      ← sedeId opcional
memberships/{uid_inst} { institutionId, role, sedeId? }  ← scope del usuario
courses/{cid}      { institutionId, sedeId? }            ← curso de una sede
```

### Roles
- **Admin principal** (`primaryAdminId` / membership ADMIN sin `sedeId`): ve y gestiona toda la institución y todas las sedes.
- **Admin de sede** (membership `role='ADMIN'` + `sedeId`): gestiona SOLO usuarios/cursos de su `sedeId`. Es el `sede.adminId`.
- Usuarios/instructores llevan `sedeId` → cuelgan de una sede.

### Límite por plan (IMPLEMENTADO — la parte de seguridad)
- `POST /api/admin/sedes` valida el límite del plan **en el servidor** (`count()` de sedes activas vs `BRANCH_LIMITS[planType]`).
- `firestore.rules`: `sedes` create = `false` (solo Admin SDK) → el límite ya no es evadible desde el cliente.
- La UI (`admin/sedes/page.tsx`) ahora llama a la API.

### Pendiente (fase mayor — requiere tu OK, toca varios archivos y Flutter)
1. **Asignar admin de sede**: en `/admin/sedes/[sedeId]`, elegir un usuario → setear `sede.adminId` + su membership `sedeId` + (opcional) promover a ADMIN-scoped. Endpoint `PUT /api/admin/sedes/[id]/admin`.
2. **Scoping de lectura/escritura por sede** en reglas: un admin de sede solo lee/edita usuarios/cursos con su `sedeId`. Helper `callerSedeId(inst)` desde la membership.
3. **Filtros por sede** en paneles de students/instructors/courses (web) y en `OrgContext` (Flutter) para mostrar solo la sede activa.
4. **Asignar `sedeId`** al crear usuarios/cursos (heredar del admin de sede que los crea).
5. **Reportes**: agregación por sede en el dashboard.

> Alternativa descartada: "cada sede = institución propia con su plan" (aislamiento total/franquicias).
> Más caro de operar y factura por separado; no es lo que se quiere aquí.
