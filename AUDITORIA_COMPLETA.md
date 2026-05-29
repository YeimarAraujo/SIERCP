# SIERCP — AUDITORÍA COMPLETA DE ARQUITECTURA Y PRODUCCIÓN
> Versión: Mayo 2026 | Auditor: Claude Sonnet 4.6

---

## ÍNDICE
1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Arquitectura Actual](#2-arquitectura-actual)
3. [Problemas Críticos Detectados](#3-problemas-críticos-detectados)
4. [Plan de Migración Firebase](#4-plan-de-migración-firebase-reducción-de-costos)
5. [Estandarización de Modelos](#5-estandarización-de-modelos-y-campos)
6. [Constantes Compartidas](#6-constantes-compartidas)
7. [Cursos, Módulos e Instructores](#7-cursos-módulos-e-instructores)
8. [Arquitectura Telemetría y Sesiones en Vivo](#8-arquitectura-telemetría-y-sesiones-en-vivo)
9. [QR de Invitación](#9-qr-de-invitación)
10. [XP, Niveles y Quizzes](#10-xp-niveles-y-quizzes)
11. [Testing Automático](#11-testing-automático)
12. [UI/UX](#12-uiux)
13. [Arquitectura de Planes](#13-arquitectura-de-planes)
14. [Roadmap Priorizado](#14-roadmap-priorizado)

---

## 1. RESUMEN EJECUTIVO

### Estado General: PRODUCIBLE CON DEUDA TÉCNICA MODERADA

| Área | Estado | Prioridad |
|------|--------|-----------|
| Auth & Seguridad | ✅ Sólido | Mantener |
| Multi-tenancy | ✅ Funcional | Optimizar |
| Telemetría BLE → Firestore | ❌ MUY COSTOSO | MIGRAR a RTDB |
| ScenarioModel enum | ❌ Duplicado | CORREGIDO |
| Typo compilación session_provider | ❌ Error | CORREGIDO |
| XP display en resultados | ❌ Faltaba | CORREGIDO |
| Live instructor gráficas | ⚠️ Sin chart | CORREGIDO |
| Arquitectura de planes | ⚠️ Parcial | Implementar |
| Testing | ❌ Mínimo | Implementar |
| QR links | ⚠️ URL expuesta | Optimizar |

---

## 2. ARQUITECTURA ACTUAL

### 2.1 Autenticación

```
FirebaseAuth.signIn()
    ↓
AuthNotifier._fetchAndActivate()
    ↓
FirestoreService.getUser(uid) → UserModel
    ↓
OrgContextNotifier.loadForUser(userId)
    ↓ 
_fetchActiveMemberships() → [MembershipModel]
    ↓
_activateOrg(membership) → OrgContextState
    ↓
GoRouter redirect → /home o /no-org (ADMIN sin org)
```

**Fortalezas:**
- `isSuperAdmin` nunca deriva de membership (SECURITY MED-06)
- `switchOrg()` re-fetcha de Firestore (revoca memberships en caliente)
- Timeout de 5s en carga de memberships
- Restaura última org desde SecureStorage

**Debilidades:**
- `OrgContextNotifier` usa `FirebaseFirestore.instance` directamente (no inyectado)
- No hay renovación automática de token al expirar

### 2.2 Multi-tenancy (Memberships)

```
users/{uid}               → rol base global
memberships/{uid}_{orgId} → rol en esa org específica
institutions/{orgId}      → datos de la institución
```

**Regla de rol por membership:**
```
UserModel.role      = rol base (USUARIO, INSTRUCTOR, ADMIN, SUPER_ADMIN)
MembershipModel.role = rol en esa organización
OrgContextState usa activeMembership.role para permisos en pantalla
```

**Fortalezas:** ID determinístico `{userId}_{institutionId}` evita duplicados.

**Problema:** `UserModel.institutionId` es solo la org "primaria" — no refleja todas las memberships. Se usa inconsistentemente en algunas queries.

### 2.3 Cursos y Módulos

```
courses/{courseId}
    ├── instructorId: string        (instructor primario)
    ├── instructorIds: string[]     (instructores adicionales)
    ├── institutionId: string       (tenant)
    ├── inviteCode: string          (6 chars para QR)
    └── enrollments/               (subcolección)
        └── {studentId}
            ├── studentName
            ├── completedModules: int
            └── progress: double

courses/{courseId}/modules/{moduleId}
    ├── type: 'teoria' | 'evaluacion_teorica' | 'practica_guiada' | 'certificacion'
    ├── scenario: string            (escenario clínico canónico)
    └── order: int
```

**Problema crítico:** No hay validación de "módulo requerido" antes de iniciar sesión.
Si `totalModules == 0`, el botón iniciar debería estar deshabilitado.

### 2.4 Sesiones de Práctica

**Flujo actual:**
```
SessionScreen → SessionService.startSession()
    → Firestore: sessions/{sessionId} = { status: active, ... }
    → DeviceService.streamDevice(mac) → RTDB stream
    → _processFirebaseTelemetry() → calcula métricas localmente
    → Firestore: sessions/{sessionId}.liveMetrics = { ... }  ← ¡MUY COSTOSO!
    → endSession() → completeSession() en Firestore
```

**Problema CRÍTICO de costo:** `liveMetrics` se escribe en Firestore cada vez que llega telemetría del BLE (aprox. cada 200ms). Esto genera:
- ~300 escrituras Firestore/minuto por sesión
- ~18.000 escrituras/hora por sesión activa
- Con 10 sesiones simultáneas: 180.000 escrituras/hora

**Solución:** Mover `liveMetrics` a Realtime Database (ver Sección 8).

### 2.5 Telemetría BLE

```
ESP32 Maniquí → Firebase RTDB → DeviceService.streamDevice() → Flutter
```

La telemetría YA usa RTDB correctamente para el stream del dispositivo.
El problema es que el provider escribe los datos procesados de vuelta a Firestore.

### 2.6 Leaderboard e XP

```
userStats/{uid}
    ├── xp: int
    ├── level: int
    └── quizzesCompleted: int

quizSessions/{auto}
    ├── userId, topicId, score, passed, xpEarned
    └── completedAt
```

**Problema:** `userStats` se actualiza en cada quiz (write Firestore OK).
Pero el `userStatsProvider` calcula stats desde `sessionsHistoryProvider` localmente en vez de leer `userStats` de Firestore — doble source of truth.

### 2.7 Qué Usa Firestore vs RTDB

| Entidad | Firestore | RTDB |
|---------|-----------|------|
| users | ✅ | ❌ |
| institutions | ✅ | ❌ |
| memberships | ✅ | ❌ |
| courses | ✅ | ❌ |
| sessions (metadata) | ✅ | ❌ |
| sessions (liveMetrics) | ❌ MUY COSTOSO | Debe migrar |
| telemetría BLE (devices) | ❌ | ✅ Ya usa RTDB |
| viewers online | ❌ | Debe migrar |
| heartbeats | ❌ | Debe migrar |

---

## 3. PROBLEMAS CRÍTICOS DETECTADOS

### 3.1 BUG CRÍTICO: Typo de compilación ✅ CORREGIDO
**Archivo:** `session_provider.dart:506`
**Error:** `averageForcKg:` → debía ser `averageForceKg:`
**Impacto:** El proyecto no compilaba con ese cambio en el working tree.
**Fix aplicado:** Corregido directamente.

### 3.2 BUG: XP no se mostraba en resultados ✅ CORREGIDO
**Archivo:** `practical_evaluations_screen.dart`
**Error:** `_awardXp()` calculaba y guardaba XP pero nunca pasaba el valor a `_ResultScreen`.
**Fix aplicado:** `_xpEarned` y `_levelAfter` en state, pasados a `_ResultScreen` que los muestra.

### 3.3 BUG: ScenarioCategory enum duplicado ✅ CORREGIDO
**Archivo:** `alert_course.dart`
**Error:** `accident`/`accidenteTransito`, `drowning`/`ahogamiento`, `cardiac`/`paroCardiaco`, `pediatric`/`pediatrico`, `electrocution`/`descargaElectrica` — duplicados que causaban ambigüedad.
**Fix aplicado:** Enum canónico de 10 categorías. Legacy strings mapeados en `_parseCategory`.

### 3.4 BUG: Emojis en ScenarioModel ✅ CORREGIDO
**Error:** `get emoji` retornaba strings emoji (rompe UI en algunos dispositivos).
**Fix aplicado:** Reemplazado por `get icon → IconData` usando Material Icons.

### 3.5 BUG: Live instructor sin gráficas ✅ CORREGIDO
**Archivo:** `live_instructor_screen.dart`
**Error:** Solo mostraba gauges estáticos. Sin historial visual.
**Fix aplicado:** `_RealtimeSessionCard` ahora es stateful, acumula historial y renderiza `_DepthHistoryChart` con fl_chart mostrando zona AHA (50-60mm).

### 3.6 PROBLEMA CRÍTICO: liveMetrics en Firestore
**Impacto:** Costo exponencial. Con 10 sesiones activas → ~180k writes/hora.
**Estado:** PENDIENTE migración a RTDB (ver Sección 8).

### 3.7 PROBLEMA: Duplicación de FirestoreService
**Archivos:** 
- Flutter: `core/services/firestore_service.dart` (1062 líneas)
- Web: `src/lib/firestore.service.ts`, `src/shared/lib/firestore.service.ts`, `src/services/firestore.service.ts`

Tres servicios Firestore en Web para el mismo propósito. Consolidar en uno.

### 3.8 PROBLEMA: userStats double source of truth
- `userStatsProvider` calcula desde `sessionsHistoryProvider` (local, solo métricas de sesiones)
- `userStats/{uid}` en Firestore tiene XP, level, quizzesCompleted
- Las dos fuentes no están sincronizadas

### 3.9 PROBLEMA: Cursos sin validación de módulos
Si `course.totalModules == 0`, el botón "Iniciar módulo" o "Iniciar práctica" no bloquea al usuario.

### 3.10 PROBLEMA: updateCourseProgressAfterSession ineficiente
```dart
// session_service.dart
final enrolledCourseIds = await _db.getStudentEnrolledCourseIds(studentId);
for (final courseId in enrolledCourseIds) {
  await _db.updateEnrollmentProgress(courseId, studentId, metrics);
}
```
Si el estudiante tiene 5 cursos → 5 writes secuenciales. Usar batch.

### 3.11 INCONSISTENCIA: identificacion vs identification
Flutter escribe `identification` (canónico) pero también lee `identificacion` (legacy).
Hay código que usa ambas. El `identificacion` field en `UserModel` está marcado `@deprecated` pero sigue en uso.

### 3.12 PROBLEMA: sessionId generado sin cryptographic randomness
```dart
String _generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final now = DateTime.now().millisecondsSinceEpoch;
  for (var i = 0; i < 6; i++) {
    buf.write(chars[(now ~/ (i + 1)) % chars.length]);
  }
}
```
Basado en timestamp → predecible. Usar `dart:math Random.secure()`.

### 3.13 WEB: Tres inicializaciones Firebase
- `/src/lib/firebase.ts`
- `/src/shared/lib/firebase.ts`  
- `/src/lib/firebase-admin.ts`

Dos clientes distintos (client + admin). Consolidar el client en uno.

---

## 4. PLAN DE MIGRACIÓN FIREBASE (REDUCCIÓN DE COSTOS)

### 4.1 Estrategia

**Usar Firestore SOLO para:**
- Datos estructurados persistentes (users, courses, sessions finalizadas)
- Queries complejas con índices
- Multi-tenancy (memberships, institutions)

**Usar RTDB para:**
- Telemetría en tiempo real (depthMm, rate, force, quality)
- Estado de sesión activa (live)
- Presencia online (heartbeats, viewers)
- Alertas en vivo

### 4.2 Estructura RTDB propuesta

```json
{
  "telemetry": {
    "{sessionId}": {
      "depthMm": 52.3,
      "ratePerMin": 112,
      "forceKg": 5.1,
      "compressionCount": 45,
      "correctCompressionCount": 38,
      "correctPct": 84.4,
      "sessionScore": 78.2,
      "decompressedFully": true,
      "recoilPct": 92.0,
      "pauseCount": 1,
      "maxPauseSec": 3.2,
      "sensorOk": true,
      "calibrated": true,
      "alertMessage": null,
      "alertType": null,
      "updatedAt": 1716840000000
    }
  },

  "live_sessions": {
    "{institutionId}": {
      "{courseId}": {
        "{sessionId}": {
          "studentId": "uid123",
          "studentName": "Juan Pérez",
          "scenarioId": "paro_cardiaco",
          "scenarioTitle": "Paro Cardíaco Adulto",
          "manikinId": "AA:BB:CC:DD:EE:FF",
          "status": "active",
          "startedAt": 1716840000000,
          "heartbeat": 1716840300000
        }
      }
    }
  },

  "viewers": {
    "{sessionId}": {
      "{viewerId}": {
        "name": "Instructor García",
        "role": "INSTRUCTOR",
        "joinedAt": 1716840000000,
        "heartbeat": 1716840300000
      }
    }
  },

  "device_status": {
    "{institutionId}": {
      "{manikinMac}": {
        "status": "disponible | en_uso | offline",
        "lastSeen": 1716840000000,
        "batteryPct": 85,
        "firmwareVersion": "2.3.1"
      }
    }
  }
}
```

### 4.3 RTDB Security Rules

```json
{
  "rules": {
    "telemetry": {
      "$sessionId": {
        ".read": "auth != null",
        ".write": "auth != null && (
          root.child('live_sessions').child($sessionId).child('studentId').val() === auth.uid ||
          auth.token.role === 'INSTRUCTOR' ||
          auth.token.role === 'ADMIN' ||
          auth.token.role === 'SUPER_ADMIN'
        )"
      }
    },
    "live_sessions": {
      "$institutionId": {
        ".read": "auth != null",
        "$courseId": {
          "$sessionId": {
            ".write": "auth != null"
          }
        }
      }
    },
    "viewers": {
      "$sessionId": {
        ".read": "auth != null",
        "$viewerId": {
          ".write": "auth != null && auth.uid === $viewerId"
        }
      }
    },
    "device_status": {
      "$institutionId": {
        ".read": "auth != null",
        ".write": "auth != null && (
          auth.token.institutionId === $institutionId ||
          auth.token.role === 'ADMIN' ||
          auth.token.role === 'SUPER_ADMIN'
        )"
      }
    }
  }
}
```

### 4.4 Impacto de Costos Estimado

| Escenario | Antes (Firestore) | Después (RTDB) | Ahorro |
|-----------|-------------------|-----------------|--------|
| 1 sesión activa (1h) | ~18k writes | ~0 writes Firestore | ~95% |
| 10 sesiones activas (1h) | ~180k writes | ~0 writes Firestore | ~95% |
| Costo mensual estimado (50 sesiones/día) | ~$45/mes | ~$5/mes | ~89% |

---

## 5. ESTANDARIZACIÓN DE MODELOS Y CAMPOS

### 5.1 Campos Canónicos Flutter ↔ Web

| Entidad | Campo Flutter | Campo Web | Estado |
|---------|--------------|-----------|--------|
| User | `id` | `uid` | ⚠️ Inconsistente |
| User | `identificacion` | `identification` | ✅ Flutter lee ambos |
| User | `institutionId` | `institutionId` | ✅ |
| User | `accountStatus` | `status` | ✅ |
| Session | `studentId` | `studentId` | ✅ |
| Session | `metrics.score` | `metrics.qualityScore` | ❌ Diferente nombre |
| Course | `instructorId` | `instructorId` | ✅ |
| Course | `instructorIds` | `instructorIds` | ✅ |
| Membership | `userId` | `userId` | ✅ |

### 5.2 Campos a Unificar

```dart
// PROBLEMA: session metrics tiene nombres distintos
// Flutter: score
// Web: qualityScore
// DECISIÓN: usar 'qualityScore' como canónico
```

### 5.3 IDs Determinísticos (ya implementados)

```dart
membershipId      = "${userId}_${institutionId}"
studentProgressId = "${userId}_${courseId}"
```

---

## 6. CONSTANTES COMPARTIDAS

### 6.1 Web: ya existe `/src/shared/lib/firestore.constants.ts`

Este archivo centraliza colecciones y campos. Todo código Web DEBE importar desde ahí.

**Falta:**
- Lista canónica de escenarios clínicos
- Lista de tipos de institución
- Lista de tipos de documento
- Configuración de planes

### 6.2 Flutter: `AppConstants` centraliza roles y colecciones

**Falta:**
- Escenarios clínicos como constantes (actualmente hardcodeados en múltiples pantallas)
- Tipos de documento como constantes

### 6.3 Lista Maestra de Escenarios Clínicos

Debe existir en UN SOLO lugar y ser reutilizable por Flutter y Web:

**Flutter:** `core/constants/clinical_scenarios.dart`
```dart
class ClinicalScenarios {
  static const paroCardiaco      = 'paroCardiaco';
  static const infarto           = 'infarto';
  static const pediatrico        = 'pediatrico';
  static const ahogamiento       = 'ahogamiento';
  static const accidenteTransito = 'accidenteTransito';
  static const colapsoEjercicio  = 'colapsoEjercicio';
  static const atragantamiento   = 'atragantamiento';
  static const descargaElectrica = 'descargaElectrica';
  static const sobredosis        = 'sobredosis';
  static const quemadura         = 'quemadura';

  static const List<String> all = [
    paroCardiaco, infarto, pediatrico, ahogamiento,
    accidenteTransito, colapsoEjercicio, atragantamiento,
    descargaElectrica, sobredosis, quemadura,
  ];
}
```

**Web:** `src/shared/constants/clinical_scenarios.ts`
```typescript
export const CLINICAL_SCENARIOS = {
  PARO_CARDIACO:       'paroCardiaco',
  INFARTO:             'infarto',
  PEDIATRICO:          'pediatrico',
  AHOGAMIENTO:         'ahogamiento',
  ACCIDENTE_TRANSITO:  'accidenteTransito',
  COLAPSO_EJERCICIO:   'colapsoEjercicio',
  ATRAGANTAMIENTO:     'atragantamiento',
  DESCARGA_ELECTRICA:  'descargaElectrica',
  SOBREDOSIS:          'sobredosis',
  QUEMADURA:           'quemadura',
} as const;

export type ClinicalScenario = typeof CLINICAL_SCENARIOS[keyof typeof CLINICAL_SCENARIOS];

export const CLINICAL_SCENARIO_LABELS: Record<ClinicalScenario, string> = {
  paroCardiaco:      'Paro Cardíaco',
  infarto:           'Infarto Agudo',
  pediatrico:        'RCP Pediátrico',
  ahogamiento:       'Ahogamiento',
  accidenteTransito: 'Accidente de Tránsito',
  colapsoEjercicio:  'Colapso por Ejercicio',
  atragantamiento:   'Atragantamiento (OVACE)',
  descargaElectrica: 'Descarga Eléctrica',
  sobredosis:        'Sobredosis / Opioides',
  quemadura:         'Quemadura',
};
```

---

## 7. CURSOS, MÓDULOS E INSTRUCTORES

### 7.1 Reglas de Negocio a Implementar

**Regla 1: Curso sin módulos no puede iniciarse**
```dart
// En CourseModel, agregar:
bool get hasModules => totalModules > 0;
bool get canStart => hasModules;
```

En `StudentCourseDetailScreen` y `StudentCourseModulesScreen`:
```dart
ElevatedButton(
  onPressed: course.canStart ? _startFirstModule : null,
  child: Text(course.canStart ? 'Iniciar' : 'Sin módulos disponibles'),
)
```

**Regla 2: El módulo define el escenario**
```
module.scenario → string canónico (ej: 'paroCardiaco')
```
Al iniciar práctica, el escenario viene del módulo. NO hay selector.

**Regla 3: Instructores ven SOLO sus cursos asignados**
```dart
// ya implementado en session_service.getCoursesForUser()
// Verificar que todas las vistas lo respeten
```

### 7.2 Visibilidad de Cursos para Instructores

Cuando el admin agrega un `instructorId` o `instructorIds[]` a un curso:
1. El curso aparece inmediatamente en la vista del instructor
2. `coursesProvider` ya lo detecta via `isInstructorOf(userId)`
3. No se necesita cambio adicional en membership

### 7.3 Synchronización Admin ↔ Instructor

El flujo actual es correcto. El instructor ve el curso si:
```dart
course.instructorId == userId || course.instructorIds.contains(userId)
```

---

## 8. ARQUITECTURA TELEMETRÍA Y SESIONES EN VIVO

### 8.1 Flujo Completo de Telemetría

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FLUJO DE TELEMETRÍA                         │
└─────────────────────────────────────────────────────────────────────┘

ESP32 Maniquí (BLE → WiFi)
         │
         ▼
Firebase Realtime Database
  devices/{mac}/
    ├── profundidadMm: 52.3
    ├── frecuenciaCpm: 112
    ├── fuerzaKg: 5.1
    ├── compresiones: 145
    ├── compresionesCorrectas: 122
    ├── recoilOk: true
    ├── sensorOk: true
    └── timestamp: 1716840300000
         │
         ▼
Flutter DeviceService.streamDevice(mac)
         │
         ▼
session_provider._processFirebaseTelemetry(deviceInfo)
         │
         ├──→ Calcula LiveSessionData (local en memoria)
         ├──→ Calcula SessionMetrics (local en memoria)
         │
         ├──→ [ACTUAL — COSTOSO] Escribe liveMetrics en Firestore
         │
         └──→ [DEBE SER] Escribe liveMetrics en RTDB
                  telemetry/{sessionId}/...
```

### 8.2 Cómo Implementar la Migración (Telemetría → RTDB)

**Paso 1:** En `session_provider.dart`, cambiar `_processFirebaseTelemetry`:

```dart
// ANTES (costoso):
// await _db.updateLiveMetrics(sessionId, data.toLiveMap());

// DESPUÉS (barato):
final rtdb = FirebaseDatabase.instance;
await rtdb.ref('telemetry/${sessionId}').set(data.toLiveMap());
```

**Paso 2:** En `LiveInstructorScreen`, cambiar el provider:

```dart
// ANTES:
// ref.watch(courseActiveSessionsProvider(courseId))
// que lee sessions con liveMetrics de Firestore

// DESPUÉS:
// Leer sesiones metadata de Firestore (sin liveMetrics)
// Suscribir a RTDB para liveMetrics por sessionId
StreamBuilder(
  stream: FirebaseDatabase.instance
    .ref('telemetry/$sessionId')
    .onValue,
  builder: (ctx, snap) {
    final data = LiveSessionData.fromMap(
      (snap.data?.snapshot.value as Map?) ?? {}
    );
    return _SessionMonitorCard(liveMetrics: data, ...);
  }
)
```

**Paso 3:** Limpiar `session.dart` — quitar `liveMetrics` del modelo `SessionModel`.
Los datos en vivo NO deben persistirse en Firestore.

### 8.3 Gráficas Implementadas en live_instructor_screen.dart

La versión actualizada incluye:
- `_DepthHistoryChart`: LineChart con fl_chart
- Zona AHA (50-60mm) sombreada en verde
- Líneas de referencia punteadas en 50mm y 60mm
- Color del trazo: verde si en rango, rojo si fuera de rango
- Historial de 40 muestras rolling
- Tooltip con valor exacto en mm

### 8.4 Limpieza Automática de Sesiones en RTDB

Usar Firebase RTDB `.onDisconnect()` o Cloud Functions con TTL:

```typescript
// Cloud Function: limpiar telemetría de sesiones finalizadas
exports.cleanupTelemetry = functions.firestore
  .document('sessions/{sessionId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === 'active' && after.status !== 'active') {
      // Sesión finalizada → limpiar RTDB después de 5 min
      setTimeout(async () => {
        await admin.database().ref(`telemetry/${sessionId}`).remove();
      }, 5 * 60 * 1000);
    }
  });
```

### 8.5 Heartbeats y Presencia Online

```typescript
// En Flutter, al iniciar sesión:
final heartbeatRef = FirebaseDatabase.instance
  .ref('live_sessions/$institutionId/$courseId/$sessionId');

await heartbeatRef.set({
  'studentId': userId,
  'studentName': userName,
  'startedAt': ServerValue.timestamp,
  'heartbeat': ServerValue.timestamp,
});

// Actualizar heartbeat cada 30s
Timer.periodic(Duration(seconds: 30), (_) {
  heartbeatRef.update({'heartbeat': ServerValue.timestamp});
});

// Al finalizar sesión:
await heartbeatRef.remove();
```

---

## 9. QR DE INVITACIÓN

### 9.1 Sistema Actual

```dart
// Flutter — generación del QR:
QrImageView(data: '${APP_URL}/join/${course.inviteCode}')

// Problema: el QR contiene toda la URL (larga y visible)
```

### 9.2 Arquitectura Mejorada

**Opción A: Solo el código (recomendada)**
```dart
// QR contiene solo el código de 6 chars:
QrImageView(data: course.inviteCode)  // ej: "RCP123"

// La app, al escanear, auto-rellena el campo de código
```

**Opción B: Esquema personalizado (deep link)**
```dart
QrImageView(data: 'siercp://join/${course.inviteCode}')
// iOS/Android interceptan el esquema y abren la app
```

**Para Web:** Redirigir `/${APP_URL}/join/{code}` directamente a la página de entrada.

### 9.3 Scanner en Flutter

```dart
// En el scanner, al detectar el QR:
void _onQrDetected(BarcodeCapture capture) {
  final raw = capture.barcodes.first.rawValue ?? '';
  
  // Extrae solo el código sin importar el formato del QR
  final code = _extractCode(raw);
  
  // Auto-rellena y puede auto-confirmar
  _codeController.text = code;
  _joinCourse(code);
}

String _extractCode(String raw) {
  // Soporta: "RCP123", "siercp://join/RCP123", "https://.../join/RCP123"
  final uri = Uri.tryParse(raw);
  if (uri != null && uri.pathSegments.contains('join')) {
    return uri.pathSegments.last;
  }
  // Si es solo el código
  if (raw.length == 6 && raw == raw.toUpperCase()) return raw;
  return raw;
}
```

### 9.4 Código generado más seguro

```dart
// ANTES: basado en timestamp (predecible)
String _generateCode() {
  final now = DateTime.now().millisecondsSinceEpoch;
  for (var i = 0; i < 6; i++) {
    buf.write(chars[(now ~/ (i + 1)) % chars.length]);
  }
}

// DESPUÉS: usando Random.secure()
import 'dart:math';
String _generateCode() {
  final rng = Random.secure();
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
}
```

---

## 10. XP, NIVELES Y QUIZZES

### 10.1 Sistema XP Actual

**Fuentes de XP (quizzes teóricos y evaluaciones prácticas):**
- Evaluación práctica aprobada (≥75%): +20 XP
- Evaluación práctica perfecta (100%): +50 XP
- Quiz teórico: lógica similar en `quiz_screen.dart`

**Problema:** Las sesiones BLE exitosas NO dan XP. Tampoco la finalización de módulos.

### 10.2 XP por Sesión BLE (a implementar)

```dart
// En session_provider.dart, endSession():
if (metrics.approved) {
  final xp = _calcSessionXp(metrics);
  await _db.addXp(userId: user.id, xp: xp, source: 'session');
}

int _calcSessionXp(SessionMetrics m) {
  if (m.score >= 90) return 100;
  if (m.score >= 85) return 75;
  if (m.score >= 70) return 50;
  return 25;
}
```

### 10.3 Pantalla de Resultado — Ya Corregida ✅

El `_ResultScreen` en `practical_evaluations_screen.dart` ahora muestra:
- XP ganados (badge dorado)
- Nivel actual
- Mensaje "Necesitas ≥75% para ganar XP" si no aprueba

### 10.4 Thresholds de Nivel

```dart
static const _xpThresholds = [0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5500];
// Nivel 1: 0-99 XP
// Nivel 2: 100-299 XP
// Nivel 3: 300-599 XP
// ...
// Nivel 10: 5500+ XP
```

### 10.5 Quiz Teórico — Problemas Detectados

**Archivo:** `quiz_screen.dart`

El quiz teórico finaliza pero:
1. No muestra XP ganado claramente (similar al bug del practical eval, YA CORREGIDO en el otro)
2. No muestra botón de repetir claramente
3. La pantalla de resultado puede no navegar correctamente al finalizar todos los temas

**Pendiente:** aplicar el mismo patrón de `_ResultScreen` al quiz teórico.

---

## 11. TESTING AUTOMÁTICO

### 11.1 Estado Actual

**Web:**
- `vitest` instalado pero solo 4 archivos de test
- `enrollment.spec.ts`, `wompi-webhook.spec.ts`, `debug.spec.ts`, `wompi-price.spec.ts`
- Sin tests de componentes React
- Sin tests E2E

**Flutter:**
- Sin archivos `*_test.dart` detectados
- Sin `flutter_test` fixtures configurados

### 11.2 Estrategia de Testing Web

```bash
# Instalar dependencias de testing
npm install -D @testing-library/react @testing-library/user-event @playwright/test

# Estructura de tests
src/__tests__/
├── unit/
│   ├── scoring.test.ts          # _calcSessionXp, AHA rules
│   ├── plan-limits.test.ts      # PlanValidator
│   └── firestore-constants.test.ts
├── integration/
│   ├── enrollment.spec.ts       # existente
│   └── courses.spec.ts
└── e2e/
    ├── auth.spec.ts             # login, registro
    ├── course-join.spec.ts      # QR, código de invitación
    └── checkout.spec.ts         # flujo de pago Wompi
```

### 11.3 Estrategia de Testing Flutter

```dart
// test/
// ├── unit/
// │   ├── scoring_test.dart
// │   ├── session_metrics_test.dart
// │   └── org_context_test.dart
// ├── widget/
// │   ├── live_instructor_screen_test.dart
// │   └── practical_evaluations_test.dart
// └── integration/
//     └── session_flow_test.dart

// Ejemplo: test de SessionMetrics
void main() {
  group('SessionMetrics AHA validation', () {
    test('score is 0 when no compressions', () {
      final metrics = SessionMetrics(
        totalCompressions: 0,
        averageDepthMm: 0,
        averageRatePerMin: 0,
        correctCompressionsPct: 0,
        averageForceKg: 0,
        interruptionCount: 0,
        maxPauseSeconds: 0,
        score: 0,
        approved: false,
        violations: [],
      );
      expect(metrics.score, equals(0.0));
      expect(metrics.approved, isFalse);
    });

    test('approves when score >= 70', () {
      // ...
    });
  });
}
```

### 11.4 Scripts Automatizados

```bash
# package.json scripts
"test:unit": "vitest run src/__tests__/unit",
"test:integration": "vitest run src/__tests__/integration",
"test:e2e": "playwright test",
"test:all": "npm run test:unit && npm run test:integration",
"audit:firestore": "grep -r 'firestore' src/ --include='*.ts' | grep -v 'constants' | wc -l",
"audit:dead-code": "ts-unused-exports tsconfig.json"
```

---

## 12. UI/UX

### 12.1 Principios a Aplicar

- **Sin emojis** en código (corregido en ScenarioModel)
- **Iconos Material** para todas las categorías visuales
- **Loaders reales** (shimmer, ya instalado: `shimmer: ^3.0.0`)
- **Estados vacíos** con mensaje y acción (ya implementado en algunos lugares)
- **Estados error** con retry button

### 12.2 Pantallas Críticas a Revisar

| Pantalla | Problema | Acción |
|----------|----------|--------|
| `CoursesScreen` | Sin estado vacío claro | Agregar EmptyState |
| `StudentCourseModulesScreen` | No bloquea si sin módulos | Deshabilitar botón |
| `QuizResultScreen` (teórico) | Sin XP display | Aplicar mismo patrón |
| `SessionResultScreen` | OK | Mantener |
| `HomeScreen` | OK | Mantener |
| `ManageUsersScreen` | Sin loader en búsqueda | Agregar shimmer |

### 12.3 Consistency Check

- Usar siempre `theme.colorScheme.surface` para superficies
- Usar `AppColors.brand`, `AppColors.green`, `AppColors.amber`, `AppColors.red` consistentemente
- Bordes: `AppRadius.sm/md/lg` (no valores hardcoded)

---

## 13. ARQUITECTURA DE PLANES

### 13.1 Problema Actual

Los límites de planes están parcialmente hardcodeados en Flutter:
```dart
// user.dart
int get courseLimit => switch (role) {
  AppConstants.roleUsuario => AppConstants.courseLimitUsuario,          // 3
  AppConstants.roleUsuarioProfesional => AppConstants.courseLimitUsuarioPro, // 10
  _ => 999999,
};
```

Y en Firestore Rules (plan-aware):
```javascript
// Solo valida si supera límites del plan, pero los límites están en el código
```

### 13.2 Arquitectura de Plan Dinámica

**Colección Firestore:** `pricing_plans/{planId}`
```json
{
  "id": "pyme",
  "name": "Pyme",
  "annual_price": 1200000,
  "monthly_discount_pct": 20,
  "limits": {
    "admins": 10,
    "branches": 10,
    "employees": 50,
    "courses": 20,
    "storage_gb": 10,
    "manikins": 5
  },
  "features": {
    "multi_branch": true,
    "advanced_reports": true,
    "api_access": false,
    "bulk_import": true,
    "custom_branding": false,
    "live_monitoring": true
  }
}
```

**Colección Firestore:** `institutions/{orgId}`
```json
{
  "planId": "pyme",
  "planLimits": { ... },  // snapshot del plan al momento de compra
  "planExpiry": "2027-05-28",
  "usage": {
    "admins": 3,
    "employees": 28,
    "courses": 7
  }
}
```

### 13.3 PlanValidator Service (Flutter)

```dart
class PlanValidator {
  final FirestoreService _db;
  PlanValidator(this._db);

  Future<LimitCheckResult> canAddAdmin(String institutionId) async {
    final inst = await _db.getInstitution(institutionId);
    final limit = inst?.planLimits?['admins'] ?? 999;
    final usage = inst?.usage?['admins'] ?? 0;
    return LimitCheckResult(
      allowed: usage < limit,
      current: usage,
      max: limit,
    );
  }

  Future<LimitCheckResult> canCreateCourse(String institutionId) async {
    // similar
  }

  Future<bool> hasFeature(String institutionId, String feature) async {
    final inst = await _db.getInstitution(institutionId);
    return inst?.planFeatures?[feature] ?? false;
  }
}

class LimitCheckResult {
  final bool allowed;
  final int current;
  final int max;
  const LimitCheckResult({required this.allowed, required this.current, required this.max});
  
  String get message => allowed 
    ? '$current/$max usados'
    : 'Límite alcanzado: $current/$max. Actualiza tu plan.';
}
```

### 13.4 Precio Mensual Calculado

```dart
double get monthlyPrice {
  // Precio mensual = anual / 12, sin descuento adicional
  return annualPrice / 12;
}

double get monthlyWithDiscount {
  // Si ofrecen "pago mensual" con recargo
  return monthlyPrice * (1 + (monthlyPremiumPct / 100));
}
```

### 13.5 Feature Gates

```dart
// En cualquier widget que requiera feature premium:
final hasFeature = await planValidator.hasFeature(orgId, 'advanced_reports');

if (!hasFeature) {
  return UpgradeCTAWidget(
    feature: 'Reportes Avanzados',
    requiredPlan: 'Corporate',
  );
}
```

### 13.6 Enforcement en Firestore Rules

```javascript
// Verificar límite de admins al crear membership
function withinAdminLimit(institutionId) {
  let inst = get(/databases/$(database)/documents/institutions/$(institutionId)).data;
  let usage = inst.usage.admins;
  let limit = inst.planLimits.admins;
  return usage < limit;
}

match /memberships/{membershipId} {
  allow create: if isAdmin(institutionId) && withinAdminLimit(institutionId);
}
```

---

## 14. ROADMAP PRIORIZADO

### Sprint 1 (Inmediato — ya completado en esta auditoría)
- ✅ Fix typo compilación `averageForcKg` → `averageForceKg`
- ✅ Fix XP display en PracticalEvaluationsScreen
- ✅ Gráficas de profundidad en LiveInstructorScreen
- ✅ Unificar ScenarioCategory enum (13 → 10 categorías)
- ✅ Reemplazar emojis por IconData en ScenarioModel

### Sprint 2 (Semana 1)
- [ ] Migrar `liveMetrics` de Firestore → RTDB
- [ ] Implementar `telemetry/{sessionId}` en RTDB
- [ ] Actualizar `LiveInstructorScreen` para leer de RTDB
- [ ] Código de invitación más seguro (Random.secure)
- [ ] Bloquear inicio de módulo si `totalModules == 0`

### Sprint 3 (Semana 2)
- [ ] XP por sesiones BLE exitosas
- [ ] XP display en QuizResultScreen (teórico)
- [ ] `updateCourseProgressAfterSession` con batch writes
- [ ] PlanValidator service básico
- [ ] Tests unitarios: SessionMetrics, ScoreCalculation

### Sprint 4 (Semana 3-4)
- [ ] Arquitectura de planes dinámica completa
- [ ] Feature gates en UI
- [ ] Migración de datos de planes existentes
- [ ] Tests E2E básicos (Web)
- [ ] Widget tests (Flutter)
- [ ] QR scanner con `_extractCode()` unificado

### Sprint 5 (Mes 2)
- [ ] Heartbeats y presencia online en RTDB
- [ ] Limpieza automática de telemetría via Cloud Functions
- [ ] Tests de integración completos
- [ ] Audit automático (npm run audit)
- [ ] Documentación técnica por feature

---

## APÉNDICE: COSTOS FIREBASE ESTIMADOS

### Plan Spark (Gratuito)
- Firestore: 50k reads/día, 20k writes/día, 20k deletes/día
- RTDB: 1GB almacenamiento, 10GB/mes transferencia
- Auth: Ilimitado
- Storage: 5GB

### Con telemetría en Firestore (actual): EXCEDE plan gratuito
- 1 sesión activa × 300 writes/min × 60 min = 18k writes SOLO de liveMetrics
- Excede el límite diario con 2 sesiones activas

### Con telemetría en RTDB (propuesto): Dentro del plan gratuito
- RTDB: datos en vivo < 1MB por sesión = bien dentro del límite
- Firestore: solo escrituras finales (1 write por sesión completa + metadata)

---

*Documento generado el 2026-05-28 como resultado de auditoría completa de SIERCP.*
*Los cambios de código indicados como ✅ ya fueron aplicados en el working tree.*
