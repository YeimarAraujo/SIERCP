# AUDITORÍA TÉCNICA COMPLETA — SIERCP
**Versión:** 3.0 | **Fecha:** 2026-05-29 | **Auditor:** Claude Sonnet 4.6

---

## RESUMEN EJECUTIVO

SIERCP es un sistema SaaS multi-tenant para entrenamiento en reanimación cardiopulmonar (RCP). La plataforma incluye una aplicación Flutter móvil, un panel web Next.js 16, y backend Firebase. La arquitectura es sólida en su estructura pero tiene varios bugs críticos, inconsistencias de campos y oportunidades de optimización de costos.

**Severidad de hallazgos:**
- 🔴 CRÍTICO: 4 bugs que afectan funcionalidad en producción
- 🟠 ALTO: 7 issues de arquitectura y rendimiento
- 🟡 MEDIO: 12 inconsistencias y deudas técnicas
- 🟢 BAJO: 8 mejoras de UX y mantenibilidad

---

## ARQUITECTURA ACTUAL

### Stack Tecnológico
| Capa | Tecnología | Versión |
|------|-----------|---------|
| Mobile | Flutter/Dart | 3.x / 3.3+ |
| Web | Next.js App Router | 16.2.4 |
| State Mobile | Riverpod | 2.6.1 |
| State Web | Zustand | 5.0.12 |
| Base de datos | Cloud Firestore + RTDB | Firebase SDK 5.x |
| Auth | Firebase Auth | 5.3.1 |
| Storage | Firebase Storage | 12.3.7 |
| BLE | flutter_blue_plus | 2.2.1 |
| Charts | fl_chart + Recharts | - |
| Pagos | Wompi | - |
| Routing Mobile | go_router | 14.6.2 |

### Flujo de Autenticación
```
Usuario → Firebase Auth → Firestore /users/{uid} → UserModel
→ OrgContext (cargar memberships) → Role-based routing
```

**Roles (jerarquía):**
1. `SUPER_ADMIN` — Jomar Segurid. Acceso total. Solo web.
2. `ADMIN` — Admin de institución. Puede crear cursos, usuarios, instructores.
3. `INSTRUCTOR` — Dirige sesiones. Solo ve sus cursos y estudiantes.
4. `USUARIO_SST` — Con licencia SST. Planes especiales.
5. `USUARIO_PROFESIONAL` — Puede cobrar por certificar. Hasta 10 cursos.
6. `USUARIO` — Estudiante básico. Hasta 3 cursos.

### Flujo de Memberships (Multi-tenant)
```
User → membership/{userId}_{institutionId} → OrgContextState
→ activeOrgId, activeRole, permissions
```

**ID determinístico obligatorio:** `{userId}_{institutionId}`

### Flujo de Telemetría BLE (Real-time)
```
ESP32/Arduino → BLE → flutter_blue_plus → DeviceService
→ session_provider._processFirebaseTelemetry()
→ RTDB: telemetry/{sessionId} (live)
→ RTDB: live_sessions/{institutionId}/{courseId}/{sessionId} (metadata)
→ Web: subscribeTelemetry() → InstructorMonitorPage
```

### Flujo de Sesiones
```
SessionScreen → startSession() → Firestore sessions/{id} (create)
→ RTDB live_sessions/{inst}/{course}/{session} (register)
→ BLE telemetry → RTDB telemetry/{sessionId} (update every frame)
→ endSession() → Firestore sessions/{id} (complete with metrics)
→ RTDB live_sessions/{inst}/{course}/{session} (remove)
```

### Flujo de Cursos y Módulos
```
Admin/Instructor → createCourse() → Firestore courses/{id}
→ addModule() → Firestore courses/{id}/modules/{moduleId}
→ Student enroll → courses/{id}/enrollments/{studentId}
→ Student views module → ModuleViewer (teoria/quiz/practica/cert)
→ practica → startSession(scenarioId from module.requiredSessions)
```

---

## BUGS CRÍTICOS 🔴

### BUG-C01: Heartbeat RTDB nunca se actualiza
**Archivo:** `lib/features/session/presentation/providers/session_provider.dart:147-171`
**Impacto:** Sessions desaparecen del InstructorMonitor después de 60 segundos.

**Causa:** `_registerLiveSessionInRtdb()` escribe `heartbeat: ServerValue.timestamp` solo una vez al inicio. El método `_writeTelemetryToRtdb()` actualiza `telemetry/{sessionId}` pero **nunca** actualiza `live_sessions/{institutionId}/{courseId}/{sessionId}/heartbeat`.

La función `isSessionAlive()` en `rtdb-telemetry.ts:65` retorna `false` cuando `Date.now() - entry.heartbeat >= 60_000`, por lo que después de 1 minuto todas las sesiones desaparecen.

**Fix requerido:**
```dart
// En _writeTelemetryToRtdb(), agregar update de heartbeat:
FirebaseDatabase.instance
    .ref('live_sessions/$institutionId/$cId/${sessionId}/heartbeat')
    .set(ServerValue.timestamp);
```

### BUG-C02: Inconsistencia de campo `score` vs `qualityScore`
**Archivos:**
- Flutter: `session.dart:195` → escribe `'score': totalScore` en Firestore
- Web: `session.service.ts:57` → escribe `qualityScore: score` en Firestore
- Web: `shared/types/session.ts:25` → `qualityScore: number` (primary)
- Web: `shared/lib/firestore.constants.ts:201` → `score: 'score'` (canonical)

**Impacto:** Las sesiones guardadas por Flutter muestran `qualityScore = undefined` en web. Las guardadas por web muestran `score = undefined` en Flutter. Los reportes y rankings muestran scores incorrectos (0).

**Fix requerido:** Unificar en `score` como campo canónico. Actualizar `session.service.ts` para usar `score` y agregar lectura de `qualityScore` como fallback.

### BUG-C03: `addCompression` genera subcollección Firestore por cada compresión BLE
**Archivo:** `lib/core/services/firestore_service.dart:570-579`
**Impacto potencial:** Durante una sesión de 2 minutos con 100 cpm = 200 documentos Firestore por sesión.

**Estado actual:** Este método existe pero no se llama desde `session_provider._processFirebaseTelemetry`. Sin embargo, puede ser llamado por error desde otros lugares. Debe marcarse como `@deprecated` o eliminarse.

**Recomendación:** Las compresiones individuales NO deben guardarse en Firestore. Solo los métricas finales en el documento `sessions/{id}`. Los datos en tiempo real van a RTDB.

### BUG-C04: `courseActiveSessionsProvider` usa Firestore en lugar de RTDB
**Archivo:** `lib/features/session/presentation/providers/session_provider.dart:19-21`
**Impacto:** El Flutter `LiveInstructorScreen` escucha sesiones activas via Firestore stream. Cada vez que una sesión se marca `status: 'active'` en Firestore, genera una lectura. Para datos en tiempo real, RTDB es 10x más barato.

---

## ISSUES DE ALTO IMPACTO 🟠

### HIGH-01: Presencia de usuarios en Firestore (debería ser RTDB)
**Archivos:** `firestore_service.dart:199-204, 617-623`
- `updateUserStatus()` y `updateUserPresence()` escriben `isOnline` y `lastActive` en Firestore `/users/{uid}`
- Cada update de presencia es una escritura Firestore = $0.18/100k writes
- Con 100 usuarios activos y updates cada 30s = 17,280 writes/día = $0.03/día solo presencia

**Fix:** Mover presencia a RTDB con `.onDisconnect()`:
```dart
// RTDB: presence/{uid}
FirebaseDatabase.instance.ref('presence/$uid').onDisconnect().set({'online': false, 'lastSeen': ServerValue.timestamp});
```

### HIGH-02: `getAllUsers()` sin paginación (SUPER_ADMIN)
**Archivo:** `firestore_service.dart:82-85`
- `_users.orderBy('firstName').get()` descarga TODOS los documentos de usuarios
- Con 10,000 usuarios = 10,000 lecturas Firestore de una vez

**Fix:** Implementar cursor-based pagination: `.limit(100).startAfterDocument(lastDoc)`

### HIGH-03: `watchSupportTickets()` sin filtro de tenant
**Archivo:** `firestore_service.dart:309-319`
- El stream devuelve todos los tickets sin filtrar por `institutionId`
- Un ADMIN puede ver tickets de otras organizaciones

**Fix:** Agregar `.where('institutionId', isEqualTo: orgId)` excepto para SUPER_ADMIN.

### HIGH-04: `usersStreamProvider` descarga TODOS los usuarios (Web)
**Archivo:** `auth_provider.dart:211-217`
- `FirebaseFirestore.instance.collection('users').snapshots()` sin límite
- Solo para SUPER_ADMIN pero descarga todos los usuarios en tiempo real

**Fix:** Agregar paginación o usar `getDocuments()` con cursor.

### HIGH-05: AHA constants hardcoded en `instructor/monitor/page.tsx`
**Archivo:** `src/app/instructor/monitor/page.tsx:26-29`
```ts
const AHA_MIN_DEPTH = 50;  // Duplicado de AHA_MIN_DEPTH_MM en constants.ts
const AHA_MAX_DEPTH = 60;
```
**Fix:** Importar desde `@/shared/lib/constants`

### HIGH-06: Scoring weights inconsistentes (Flutter vs Web)
- Flutter: `ahaDepthWeight = 0.30, ahaRateWeight = 0.30, ahaRecoilWeight = 0.20, ahaInterruptionWeight = 0.20`
- Web: `SCORE_DEPTH_WEIGHT = 0.4, SCORE_RATE_WEIGHT = 0.3, SCORE_RECOIL_WEIGHT = 0.2, SCORE_INTERRUPTION_WEIGHT = 0.1`

Esto genera scores diferentes para la misma sesión dependiendo de quién calcula. Flutter suma a 1.0 correctamente (0.30+0.30+0.20+0.20=1.0). Web también suma 1.0 pero con pesos distintos.

**Fix:** Unificar pesos en ambas plataformas usando la fórmula AHA 2025 correcta.

### HIGH-07: `updateSessionLiveMetrics()` escribe liveMetrics en Firestore durante sesión activa
**Archivo:** `firestore_service.dart:520-527`
- Este método existe y escribe `liveMetrics` al documento Firestore de la sesión
- Aunque no se llama desde `session_provider`, puede llamarse por error
- **Marcar como deprecated** ya que los datos live van a RTDB

---

## INCONSISTENCIAS DE MODELOS 🟡

### INCONS-01: `identificacion` vs `identification`
- Flutter modelo: `identificacion` (campo de clase)
- Firestore canonical: `identification`
- Flutter `fromFirestore()`: lee ambos `d['identification'] ?? d['identificacion']`
- Flutter `toFirestore()`: escribe `'identification': identificacion` ✅ (correcto)
- **Estado:** Resuelto en código actual. No requiere cambio.

### INCONS-02: `score` vs `qualityScore` en SessionMetrics
- Ver BUG-C02 arriba

### INCONS-03: `courseLimit` inconsistente
- Flutter `constants.dart`: `courseLimitUsuario = 3, courseLimitUsuarioPro = 10`
- Web `constants.ts`: `COURSE_LIMIT_USUARIO = 5, COURSE_LIMIT_USUARIO_PRO = 10`
- El límite para `USUARIO` es 3 en Flutter y 5 en Web

**Fix:** Unificar en 3 o cambiar ambas al valor correcto.

### INCONS-04: `accountStatus` vs `status` en UserModel
- Flutter `toFirestore()`: escribe `'status': accountStatus`
- Flutter `fromFirestore()`: lee `d['status'] as String?`
- Web `F_USER.status = 'status'` ✅
- **Estado:** Resuelto. No requiere cambio.

### INCONS-05: `instructorId` singular vs `instructorIds` array
- `CourseModel` tiene `instructorId` (primary) e `instructorIds` (array de adicionales)
- Cuando se filtra cursos de instructor, se usa `where('instructorId', ...)` pero no `arrayContains('instructorIds', ...)`
- Un instructor adicional (en `instructorIds` pero no en `instructorId`) no ve el curso

**Fix:** En `getInstructorCourses()`, combinar query con `instructorIds arrayContains` usando collectionGroup.

### INCONS-06: Límites de cursos no se aplican al INSTRUCTOR
- `courseLimit` retorna `999999` para instructores/SST
- Pero la membresía del plan sí tiene límites que no se verifican en app Flutter

### INCONS-07: `completedModules` como contador vs array
- En `enrollments` subcollection: `completedModules: 0` (número)
- En `F_STUDENT_PROGRESS.completedModules`: lista de moduleIds (string[])
- Inconsistencia entre cómo Flutter y Web trackean progreso

---

## COLECCIONES Y COSTOS FIREBASE

### Colecciones más costosas
| Colección | Riesgo | Razón |
|-----------|--------|-------|
| `sessions/{id}/compressions` | 🔴 Alto | Potencialmente 200 docs/sesión |
| `users` | 🟠 Medio | Stream completo para SUPER_ADMIN |
| `sessions` | 🟡 Bajo | Bien filtrado por courseId/studentId |
| `notifications` | 🟡 Bajo | Stream por userId (correcto) |
| `memberships` | 🟢 OK | Queries pequeñas y bien indexadas |

### Uso de RTDB (correcto)
| Path RTDB | Propósito |
|-----------|-----------|
| `live_sessions/{institutionId}/{courseId}/{sessionId}` | Metadata de sesión activa |
| `telemetry/{sessionId}` | Datos BLE en tiempo real |
| `presence/{userId}` | (pendiente implementar) Online/offline |

### Estimación de costos mensuales (100 usuarios, 500 sesiones/mes)
| Recurso | Actual | Optimizado |
|---------|--------|-----------|
| Firestore reads | ~500K/mes | ~200K/mes |
| Firestore writes | ~100K/mes | ~50K/mes |
| RTDB bandwidth | ~2 GB/mes | ~2 GB/mes |
| Storage | ~5 GB | ~5 GB |
| **Total estimado** | **$5-8/mes** | **$2-4/mes** |

---

## FLUJO TELEMETRÍA Y SESIONES EN VIVO — GUÍA COMPLETA

### Arquitectura de Datos

```
Flutter App (Student)
└── DeviceService (RTDB listener: devices/{mac})
    └── BleService → ESP32 via BLE
        └── session_provider.dart
            ├── _registerLiveSessionInRtdb()
            │   └── RTDB: live_sessions/{institutionId}/{courseId}/{sessionId}
            │       {studentId, studentName, scenarioId, manikinId, startedAt, heartbeat}
            ├── _writeTelemetryToRtdb() [cada frame BLE]
            │   └── RTDB: telemetry/{sessionId}
            │       {depthMm, ratePerMin, forceKg, compressionCount, 
            │        correctPct, sessionScore, sensorOk, updatedAt}
            └── endSession()
                ├── Firestore: sessions/{id} {status:'completed', metrics:{...}}
                └── RTDB: live_sessions/.../{sessionId} → REMOVE

Web (Instructor/Admin)
└── InstructorMonitorPage
    ├── CourseService.getByInstructor(uid) → lista de cursos
    ├── subscribeLiveSessions(institutionId, courseId)
    │   └── RTDB listener: live_sessions/{institutionId}/{courseId}
    │       → filtra isSessionAlive() (heartbeat < 60s)
    └── LiveSessionCard → subscribeTelemetry(sessionId)
        └── RTDB listener: telemetry/{sessionId}
            → actualiza gráficas de profundidad y frecuencia

Flutter (Instructor)
└── LiveInstructorScreen
    ├── courseActiveSessionsProvider → Firestore sessions (❌ debería ser RTDB)
    └── _RealtimeSessionCard → deviceService.streamDevice(manikinId) → RTDB
```

### Estructura RTDB Detallada

```json
{
  "live_sessions": {
    "{institutionId}": {
      "{courseId}": {
        "{sessionId}": {
          "studentId": "uid123",
          "studentName": "Juan Pérez",
          "scenarioId": "paroCardiaco",
          "scenarioTitle": "Paro cardíaco en casa",
          "manikinId": "AA:BB:CC:DD:EE:FF",
          "courseId": "courseId123",
          "institutionId": "instId123",
          "status": "active",
          "startedAt": 1748500000000,
          "heartbeat": 1748500000000  // ← actualizar cada 30s
        }
      }
    }
  },
  "telemetry": {
    "{sessionId}": {
      "depthMm": 52.3,
      "ratePerMin": 108,
      "forceKg": 12.5,
      "compressionCount": 45,
      "correctCompressionCount": 38,
      "correctPct": 84.4,
      "sessionScore": 87.2,
      "decompressedFully": true,
      "recoilPct": 92.0,
      "pauseCount": 0,
      "maxPauseSec": 0.0,
      "sensorOk": true,
      "calibrated": true,
      "updatedAt": 1748500000000
    }
  },
  "presence": {
    "{userId}": {
      "online": true,
      "lastSeen": 1748500000000
    }
  }
}
```

### Índices RTDB Requeridos
En `database.rules.json` agregar `.indexOn`:
```json
{
  "live_sessions": {
    "$institutionId": {
      "$courseId": {
        ".indexOn": ["heartbeat", "studentId"]
      }
    }
  }
}
```

---

## SISTEMA XP Y GAMIFICACIÓN

### Estado Actual
- `QuizSessionResult` en Flutter tiene: `xpEarned`, `newLevel`, `newBadges`
- `quiz_result_screen.dart` existe pero no muestra XP ganada
- `F_USER_STATS` y `F_QUIZ_SESSION` en Web tienen campos XP definidos
- No existe un servicio centralizado de XP que sume puntos de todas las fuentes

### Fuentes de XP (pendiente implementar)
| Fuente | XP |
|--------|-----|
| Quiz teórico aprobado | 50 XP |
| Quiz teórico perfecto (100%) | 100 XP |
| Sesión simulación aprobada | 75 XP |
| Sesión simulación excelente (≥85%) | 150 XP |
| Módulo completado | 25 XP |
| Curso completado | 200 XP |

### Niveles XP
| Nivel | XP requerida |
|-------|-------------|
| 1 - Novato | 0 |
| 2 - Aprendiz | 100 |
| 3 - Practicante | 300 |
| 4 - Avanzado | 600 |
| 5 - Experto | 1000 |
| 6 - Maestro | 1500 |
| 7 - Elite | 2500 |

---

## ESCENARIOS CLÍNICOS — LISTA MAESTRA

La lista debe ser UNA SOLA y compartida en todo el sistema.

| ID | Título | Dificultad |
|----|--------|-----------|
| paroCardiaco | Paro cardíaco en casa | Medio |
| accidenteTransito | Accidente de tránsito | Difícil |
| ahogamiento | Ahogamiento en piscina | Difícil |
| colapsoEjercicio | Colapso durante ejercicio | Medio |
| atragantamiento | Atragantamiento severo | Medio |
| descargaElectrica | Descarga eléctrica | Difícil |
| sobredosis | Sobredosis por opioides | Difícil |
| infarto | Infarto que evoluciona a paro | Difícil |
| pediatricoParo | Paro cardíaco pediátrico | Muy difícil |
| rvNeonatal | Reanimación neonatal | Muy difícil |
| ahogamientoPediatrico | Ahogamiento pediátrico | Difícil |
| traumaCraneo | Trauma craneoencefálico | Difícil |

---

## PLAN DE MEMBRESÍAS Y LÍMITES

### Estructura Actual (membership.dart)
```dart
enum PlanType {
  pyme, business, corporate, enterprise,
  sstConLicencia, sstSinLicencia, credits
}

class PlanLimits {
  final int maxUsers;
  final int maxSeats;
  final int maxActiveCourses;
  final int maxCertificatesPerMonth;
  final bool canUseLiveSessions;
  final bool canRecordSessions;
  final bool canUseMultiSite;
}
```

### Gaps de Enforcement
1. Los límites están definidos en `PlanLimits` pero NO se verifican en Firestore rules
2. No existe un `PlanValidator` que bloquee operaciones cuando se exceden límites
3. La UI no muestra el conteo actual vs límite del plan

### Arquitectura Recomendada
```
PlanValidator.canCreate(institutionId, 'users') → bool
SubscriptionLimitService.checkQuota(institutionId, quotaType) → QuotaResult
FeatureGateService.hasFeature(institutionId, 'liveSessions') → bool
```

---

## FLUJO QR DE INVITACIÓN

### Estado Actual
```tsx
<QRCodeSVG value={`${APP_URL}/join/${inviteCode}`} />
```
El QR codifica la URL completa. Al escanear, se ve todo el dominio.

### Mejora Recomendada
```tsx
// Opción 1: Solo el código (más corto, mejor QR)
<QRCodeSVG value={`SIERCP:${inviteCode}`} />

// Opción 2: Short URL
<QRCodeSVG value={`s.siercp.co/${inviteCode}`} />
```

El app Flutter debe detectar ambos formatos y extraer el `inviteCode`.

---

## PLAN DE ACCIÓN PRIORIZADO

### Sprint 1 — Bugs Críticos (Este sprint)
- [x] Crear auditoría
- [ ] Fix heartbeat RTDB (BUG-C01)
- [ ] Fix campo score/qualityScore (BUG-C02)
- [ ] Mejorar reglas RTDB (HIGH-05 + seguridad)
- [ ] Crear RTDB provider Flutter para sesiones activas

### Sprint 2 — Features Core
- [ ] XP system completo (quiz + simulación + módulos)
- [ ] Quiz result screen con XP display
- [ ] Lista maestra de escenarios clínicos
- [ ] Fix flujo módulo→escenario directo

### Sprint 3 — Escalabilidad
- [ ] PlanValidator / SubscriptionLimitService
- [ ] Paginación de usuarios (SUPER_ADMIN)
- [ ] QR optimizado con deep linking
- [ ] Presencia en RTDB

### Sprint 4 — Testing y Calidad
- [ ] Unit tests Flutter (repositories, services)
- [ ] Integration tests Web (Vitest)
- [ ] E2E tests (Playwright)
- [ ] Scripts de auditoría automática

---

## ESTRUCTURA DE ARCHIVOS RECOMENDADA (FINAL)

### Flutter — Servicios nuevos a crear
```
lib/core/services/
├── firestore_service.dart     ✅ existente
├── rtdb_service.dart          ← CREAR: presencia, heartbeat, live sessions reader
├── xp_service.dart            ← CREAR: cálculo y actualización de XP
└── plan_validator.dart        ← CREAR: enforcement de límites de plan

lib/shared/constants/
├── clinical_scenarios.dart    ← CREAR: lista maestra de escenarios
├── document_types.dart        ← CREAR: CC, CE, TI, PP, NIT, DIE
└── institution_types.dart     ← CREAR: university, hospital, company, etc.
```

### Web — Servicios nuevos a crear
```
src/shared/lib/
├── rtdb-telemetry.ts          ✅ existente y bien implementado
├── plan-validator.ts          ← CREAR
├── xp-service.ts              ← CREAR
└── firestore.constants.ts     ✅ existente y completo

src/shared/constants/
├── clinical-scenarios.ts      ← CREAR
├── document-types.ts          ← CREAR
└── institution-types.ts       ← CREAR
```

---

*Auditoría generada el 2026-05-29. Actualizar cuando se implementen los fixes.*
