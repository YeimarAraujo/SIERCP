# Manual Técnico — SICAP

**Sistema Inteligente de Capacitación en Reanimación Cardiopulmonar**

Versión: 1.0 — Julio 2026

---

## Contenido

1. [Arquitectura del sistema](#1-arquitectura-del-sistema)
2. [Tecnologías utilizadas](#2-tecnologias-utilizadas)
3. [Base de datos](#3-base-de-datos)
4. [API](#4-api)
5. [Estructura del proyecto](#5-estructura-del-proyecto)
6. [Instalación para desarrollo](#6-instalacion-para-desarrollo)
7. [Despliegue](#7-despliegue)

---

## 1. Arquitectura del sistema

### 1.1. Visión general

SICAP sigue una arquitectura **cliente-servidor descentralizada** con tres capas principales:

```
┌─────────────────────────────────────────────────────┐
│                   CLIENTES                           │
│                                                      │
│  ┌──────────────┐   ┌──────────────┐                │
│  │  App Flutter  │   │  Web Next.js │                │
│  │  (iOS/Android)│   │  (Dashboard) │                │
│  └──────┬───────┘   └──────┬───────┘                │
│         │                  │                         │
│         │    Bluetooth     │   HTTPS                 │
│         │    (BLE)         │   (REST)                │
└─────────┼──────────────────┼─────────────────────────┘
          │                  │
┌─────────┼──────────────────┼─────────────────────────┐
│         ▼                  ▼                         │
│  ┌──────────────┐   ┌──────────────┐                │
│  │  Maniquí     │   │   Firebase   │                │
│  │  ESP32       │   │              │                │
│  │              │   │  ┌─────────┐ │                │
│  │  VL53L0X     │   │  │ Auth    │ │                │
│  │  HX711       │   │  ├─────────┤ │                │
│  │  BLE         │   │  │Firestore│ │                │
│  └──────────────┘   │  ├─────────┤ │                │
│                      │  │  RTDB   │ │                │
│                      │  ├─────────┤ │                │
│                      │  │Storage  │ │                │
│                      │  ├─────────┤ │                │
│                      │  │Functions│ │                │
│                      │  └─────────┘ │                │
│                      └──────────────┘                │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │         Cloudflare Worker                    │   │
│  │         (Push Notifications FCM)             │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │         Wompi (Pasarela de pagos)            │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### 1.2. Flujo de datos en una sesión RCP

```
1. ESP32 (maniquí) captura datos de sensores a 100 Hz
   ↓
2. Filtrado exponencial en firmware (profundidad: α=0.5, fuerza: α=0.4)
   ↓
3. Envío BLE a app Flutter cada 50 ms (20 Hz)
   ↓
4. App Flutter muestra métricas en tiempo real y envía a Firebase RTDB
   ↓
5. Dashboard web (Next.js) se suscribe a RTDB para monitoreo en vivo
   ↓
6. Al finalizar sesión, datos se persisten en Firestore
```

### 1.3. Modelo de autenticación

```
Usuario → Firebase Auth (Email/Password)
                ↓
        HttpOnly Session Cookie (API Route)
                ↓
        onAuthStateChanged + onSnapshot
                ↓
        Zustand Store (useAuthStore)
                ↓
        RoleGuard + redirect por rol
```

---

## 2. Tecnologías utilizadas

### 2.1. Frontend Web

| Tecnología | Versión | Propósito |
|---|---|---|
| Next.js | 16 (App Router) | Framework React con rutas y SSR |
| React | 19 | Librería de UI |
| TypeScript | ~5.x | Tipado estático |
| Tailwind CSS | 4 | Estilos utilitarios |
| Radix UI | — | Componentes accesibles headless |
| Framer Motion | — | Animaciones |
| Zustand | — | Gestión de estado global |
| Firebase Client SDK | — | Auth, Firestore, RTDB, Storage |

### 2.2. App Móvil

| Tecnología | Versión | Propósito |
|---|---|---|
| Flutter | 3.22+ | Framework multiplataforma |
| Dart | 3.0+ | Lenguaje de programación |
| go_router | ^13.0.0 | Navegación declarativa con guards |
| flutter_riverpod | ^2.5.1 | Gestión de estado reactivo |
| dio | ^5.4.3 | Cliente HTTP con interceptores |
| web_socket_channel | ^2.4.0 | WebSocket para tiempo real |
| flutter_secure_storage | ^9.0.0 | Almacenamiento seguro de JWT |
| fl_chart | ^0.68.0 | Gráficas de compresión y progreso |

### 2.3. Firmware (ESP32)

| Componente | Propósito |
|---|---|
| Arduino framework | Plataforma de desarrollo |
| BLEDevice / BLEServer | Comunicación Bluetooth Low Energy |
| HX711 | Amplificador para celda de carga |
| Adafruit_VL53L0X | Sensor ToF láser para profundidad |
| Wire (I2C) | Comunicación con sensores |

### 2.4. Backend / Infraestructura

| Tecnología | Propósito |
|---|---|
| Firebase Auth | Autenticación de usuarios |
| Firestore | Base de datos principal (documental) |
| Firebase Realtime Database | Telemetría en tiempo real de maniquíes |
| Firebase Storage | Almacenamiento de archivos (PDF, imágenes) |
| Firebase Functions | Lógica serverless (próximamente) |
| Cloudflare Worker | Notificaciones push FCM |
| Resend | Correos transaccionales |
| Wompi | Pasarela de pagos colombiana |

### 2.5. Herramientas de desarrollo

| Herramienta | Propósito |
|---|---|
| VS Code | IDE principal |
| Flutter SDK | Compilación de app móvil |
| Arduino IDE | Programación del ESP32 |
| Firebase CLI | Emulación y despliegue de Firebase |
| Postman | Pruebas de API |
| Vitest | Pruebas unitarias del dashboard web |

---

## 3. Base de datos

### 3.1. Firestore (Datos persistentes)

#### Colecciones principales

```
/users/{uid}
  ├── email: string
  ├── firstName, lastName: string
  ├── role: enum (SUPER_ADMIN, ADMIN, INSTRUCTOR, USUARIO_SST, USUARIO_PROFESIONAL, USUARIO)
  ├── institutionId: string
  ├── isActive: boolean
  ├── stats: {
  │     totalSessions, averageScore, bestScore, streakDays, totalHours,
  │     averageDepthMm, averageRatePerMin
  │   }
  ├── courses[]: { courseId, slug, title, cohortId, role, joinedAt, status }
  ├── certificates[]: { id, userId, type, issuer, certificateNumber, fileUrl }
  ├── fcmTokens[]: string
  └── createdAt, updatedAt: timestamp

/sessions/{sessionId}
  ├── studentId, studentName: string
  ├── scenarioId, scenarioTitle: string
  ├── courseTitle: string
  ├── patientType: enum (adult, pediatric, infant)
  ├── status: string
  ├── startedAt, endedAt: timestamp
  ├── duration: number (segundos)
  ├── metrics: {
  │     totalCompressions, correctCompressions, averageDepthMm,
  │     averageRatePerMin, correctCompressionsPct, averageForceKg,
  │     recoilPct, interruptionCount, maxPauseSeconds, ccfPct,
  │     depthScore, rateScore, recoilScore, interruptionScore,
  │     score, qualityScore, approved: boolean, violations[]
  │   }
  ├── courseId: string
  └── manikinId: string

/courses/{courseId}
  ├── title, description: string
  ├── instructorId, instructorName: string
  ├── institutionId, institutionName: string
  ├── inviteCode: string (6 chars)
  ├── certification: boolean
  ├── minScore, minAttendance: number
  ├── endDate: timestamp
  ├── isActive: boolean
  ├── studentCount, moduleCount: number
  ├── scenarioMode: boolean
  ├── guides[]: subcollection
  └── enrollments: subcollection

/institutions/{institutionId}
  ├── name, code, nit: string
  ├── mode: enum (AUTOMATED, MANUAL)
  ├── address, city, department: string
  ├── contactEmail, contactPhone: string
  ├── logoUrl: string
  ├── adminIds[], primaryAdminId: string
  ├── memberCount: number
  ├── planType: string
  ├── status: string
  ├── maxDevices, maxInstructors, maxStudents: number
  ├── tier: enum (OWNER, PARTNER, CLIENT)
  └── billingOwnerUid: string

/course_templates/{templateId}
  ├── institutionId: string
  ├── slug, title: string
  ├── level: enum (basico, intermedio, avanzado)
  ├── modality: enum (presencial, virtual, hibrida)
  ├── duration, sessions: number
  ├── priceCOP, priceUSD: number
  ├── objectives, requirements: string[]
  ├── modules[]: CourseModule[]
  ├── isAutomated, isActive: boolean
  └── autoConfig: { frequency, maxStudents, ... }

/cohorts/{cohortId}
  ├── templateId, institutionId: string
  ├── courseSlug, courseTitle: string
  ├── cohortNumber: number
  ├── scheduleLabel: string
  ├── enrollmentStart/End, classesStart/End: timestamp
  ├── maxStudents, enrolledCount: number
  ├── priceCOP, priceUSD: number
  ├── status: enum (UPCOMING, OPEN, FULL, IN_PROGRESS, CLOSED, COMPLETED)
  └── isAutoGenerated, parentCohortId: string

/devices/{deviceId}
  ├── name, uuid: string
  ├── status: enum (disponible, en_uso, mantenimiento, offline)
  ├── apiKey: string
  ├── assignedTo: string (uid)
  ├── currentSessionId: string
  └── lastConnection: timestamp

/plans/{planId}
  ├── name, slug, description: string
  ├── priceCOP, annualPriceCOP: number
  ├── displayOrder: number
  ├── isPublic, isRecommended: boolean
  ├── limits: PlanLimits
  └── ...

/audit/{logId}
  ├── action: string
  ├── userId: string
  ├── role: string
  ├── timestamp: timestamp
  ├── details: object
  └── ipAddress: string
```

#### Subcolecciones

```
/courses/{courseId}/enrollments/{enrollmentId}
/courses/{courseId}/guides/{guideId}
/courses/{courseId}/guides/{guideId}/progress/{userId}
/institutions/{institutionId}/memberships/{membershipId}
```

### 3.2. Firebase Realtime Database (RTDB)

#### Estructura de telemetría

```
/telemetria/{macAddress}/
  ├── fuerzaKg: float
  ├── profundidadMm: float
  ├── frecuenciaCpm: float
  ├── compresiones: int
  ├── compresionesCorrectas: int
  ├── recoilOk: boolean
  ├── enCompresion: boolean
  ├── compresionCorrecta: boolean
  ├── calidadPct: float
  ├── recoilPct: float
  ├── avgProfundidadMm: float
  ├── avgFuerzaKg: float
  ├── pausas: int
  ├── maxPausaSeg: float
  ├── sensorOk: boolean
  ├── calibrado: boolean
  ├── isActive: boolean
  ├── timestamp: number
  └── bateriaPct: number (opcional)

/sessions_active/{sessionId}/
  ├── telemetry: { ... }  (copia en vivo de telemetría)
  ├── studentId: string
  ├── startedAt: number
  └── status: string
```

### 3.3. Reglas de seguridad (Firestore - extracto)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read: if request.auth != null && (
        request.auth.uid == uid ||
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['ADMIN', 'SUPER_ADMIN']
      );
      allow write: if request.auth != null && (
        request.auth.uid == uid ||
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['ADMIN', 'SUPER_ADMIN']
      );
    }
    match /sessions/{session} {
      allow read: if request.auth != null && (
        resource.data.studentId == request.auth.uid ||
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['ADMIN', 'SUPER_ADMIN', 'INSTRUCTOR']
      );
      allow create: if request.auth != null;
    }
  }
}
```

### 3.4. Cálculo de puntuación AHA

La puntuación se calcula con los siguientes pesos:

| Componente | Peso | Fórmula |
|---|---|---|
| Profundidad | 40% | min(100, max(0, 100 * (1 - abs(avgDepth - 55) / 25))) |
| Frecuencia | 30% | min(100, max(0, 100 * (1 - abs(avgRate - 110) / 40))) |
| Recoil | 20% | recoilPct * 100 |
| Interrupciones | 10% | min(100, max(0, 100 * (maxPause / 10))) invertido |

- **Puntuación total** = profundidad×0.4 + frecuencia×0.3 + recoil×0.2 + interrupciones×0.1
- **Aprobado**: ≥ 70 puntos
- **Excelente**: ≥ 90 puntos

---

## 4. API

### 4.1. API Routes (Next.js)

Todas las rutas API están bajo `/api/` y utilizan Firebase Admin SDK para operaciones del lado servidor.

#### Autenticación

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/auth/session` | Crea cookie de sesión HttpOnly |
| DELETE | `/api/auth/session` | Elimina cookie de sesión |
| GET | `/api/auth/me` | Obtiene usuario actual desde cookie |

#### Cursos

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/courses` | Listar cursos |
| POST | `/api/courses` | Crear curso |
| GET | `/api/courses/[id]` | Detalle de curso |
| PUT | `/api/courses/[id]` | Actualizar curso |
| DELETE | `/api/courses/[id]` | Eliminar curso |
| POST | `/api/courses/[id]/enroll` | Inscribir estudiante |

#### Admin

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/admin/courses` | Listar plantillas de curso |
| POST | `/api/admin/courses` | Crear plantilla |
| GET | `/api/admin/courses/[id]` | Detalle de plantilla |

#### Inscripciones

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/enrollment` | Procesar inscripción + pago |

#### Pagos (Wompi)

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/wompi-webhook` | Webhook de confirmación de pago |
| GET | `/api/checkout` | Obtener información de checkout |

#### Super Admin

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/super-admin/institutions` | Listar instituciones |
| POST | `/api/super-admin/institutions` | Crear institución |
| GET | `/api/super-admin/analytics` | Obtener analytics globales |

### 4.2. Servicio REST (app Flutter)

La app Flutter se comunica con el backend Next.js a través de `api_service.dart` usando **Dio**.

**Headers:**
```json
{
  "Authorization": "Bearer {jwt_token}",
  "Content-Type": "application/json"
}
```

**Interceptors:**
- JWT interceptor: agrega token automáticamente
- Refresh interceptor: renueva token expirado
- Error interceptor: manejo unificado de errores

### 4.3. WebSocket (telemetría en vivo)

La app Flutter usa WebSocket para recibir datos en tiempo real del maniquí:

**Endpoint:** `ws://{host}/ws/session/{sessionId}`

**Mensaje entrante:**
```json
{
  "depth": 52.3,
  "force": 45.1,
  "rate": 108,
  "compressions": 42,
  "recoil": 0.95,
  "timestamp": 1719876543210
}
```

---

## 5. Estructura del proyecto

### 5.1. Dashboard Web (SIERCP-WEB)

```
SIERCP-WEB/
├── src/
│   ├── app/                      # Next.js App Router (páginas)
│   │   ├── (auth)/(form)/        # Login, Register
│   │   ├── (dashboard)/          # Student dashboard
│   │   ├── admin/                # Admin pages
│   │   ├── instructor/           # Instructor pages
│   │   ├── student/              # Student pages
│   │   ├── super-admin/          # Super admin pages
│   │   ├── checkout/             # Payment pages
│   │   └── api/                  # API routes
│   ├── components/
│   │   ├── layout/               # Shells, sidebars, headers
│   │   ├── ui/                   # Reusable UI (DataTable, StatCard, etc.)
│   │   ├── charts/               # Gráficas (compression-chart, score-gauge)
│   │   ├── sessions/             # Session components
│   │   └── page/                 # Landing page sections
│   ├── features/
│   │   ├── auth/                 # Auth store, hooks, components
│   │   ├── courses/              # Course management
│   │   ├── sessions/             # Session management
│   │   ├── devices/              # Device/RTDB management
│   │   ├── checkout/             # Payment flow
│   │   └── institutions/         # Institution management
│   ├── services/                 # Firebase services
│   ├── data/                     # Static data (geo, FAQs, plans)
│   ├── models/                   # TypeScript types
│   ├── stores/                   # Zustand stores
│   ├── hooks/                    # React hooks
│   ├── shared/
│   │   ├── lib/                  # Firebase, scoring, constants
│   │   ├── types/                # Shared type definitions
│   │   └── hooks/                # Shared hooks
│   └── ...
├── docs/                         # Developer docs
├── public/                       # Static assets
├── package.json
├── next.config.mjs
├── tailwind.config.ts
└── tsconfig.json
```

### 5.2. App Móvil (siercp_flutter)

```
siercp_flutter/
├── lib/
│   ├── main.dart                 # Entry point con ProviderScope
│   ├── core/
│   │   ├── constants.dart        # URLs, AHA params, roles
│   │   ├── routes.dart           # go_router + auth guards
│   │   └── theme.dart            # Tema y colores
│   ├── models/
│   │   ├── user.dart             # UserModel, AuthTokens, UserStats
│   │   ├── session.dart          # SessionModel, CompressionReading
│   │   └── alert_course.dart     # AlertModel, ScenarioModel, CourseModel
│   ├── services/
│   │   ├── api_service.dart      # Dio HTTP client
│   │   ├── auth_service.dart     # Login/logout/getMe
│   │   ├── session_service.dart  # Sesiones y métricas
│   │   └── websocket_service.dart # WebSocket reconexión automática
│   ├── providers/
│   │   ├── auth_provider.dart    # AuthNotifier, authStateProvider
│   │   └── session_provider.dart # activeSessionProvider
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── login_screen.dart
│   │   ├── main_shell.dart
│   │   ├── home_screen.dart
│   │   ├── session_screen.dart
│   │   ├── session_result_screen.dart
│   │   ├── history_screen.dart
│   │   └── ...
│   └── widgets/
│       ├── metric_card.dart
│       ├── compression_wave.dart
│       └── aha_status_bar.dart
├── android/
├── ios/
├── web/
├── assets/
├── pubspec.yaml
└── config.json                   # Configuración de entorno
```

### 5.3. Firmware ESP32 (esp32_siercp)

```
esp32_siercp/
├── esp32_siercp.ino              # Firmware principal (277 líneas)
│   └── Contenido:
│       ├── BLE Server (SERVICE_UUID, CHAR_TELEMETRY_UUID, CHAR_CTRL_UUID)
│       ├── HX711 (celda de carga)
│       ├── VL53L0X (sensor de profundidad)
│       ├── FSM de compresión (IDLE → PRESSING → HOLDING → RELEASING)
│       ├── Filtro exponencial (profundidad α=0.5, fuerza α=0.4)
│       └── Telemetría batch cada 50ms
```

---

## 6. Instalación para desarrollo

### 6.1. Prerrequisitos

| Herramienta | Versión |
|---|---|
| Node.js | 18+ |
| npm | 9+ |
| Flutter SDK | 3.22+ |
| Android Studio / VS Code | — |
| Arduino IDE | 2.x |
| Firebase CLI | latest |
| Git | 2.x |

### 6.2. Clonar repositorio

```bash
git clone https://github.com/YeimarAraujo/SIERCP.git
cd SICAP
```

### 6.3. Configurar dashboard web

```bash
cd SIERCP-WEB
npm install
cp .env.example .env.local
# Editar .env.local con credenciales de Firebase
npm run dev
```

### 6.4. Configurar app Flutter

```bash
cd siercp_flutter
flutter pub get
mkdir -p assets/images assets/audio assets/fonts
# Crear config.json con RTDB_URL
flutter run
```

### 6.5. Configurar firmware ESP32

```bash
# Abrir esp32_siercp/esp32_siercp.ino en Arduino IDE
# Instalar librerías: HX711, Adafruit_VL53L0X, BLE
# Conectar ESP32 vía USB
# Seleccionar placa: ESP32 Dev Module
# Click en Upload
```

---

## 7. Despliegue

### 7.1. Dashboard Web (Vercel)

```bash
cd SIERCP-WEB
npm run build
vercel --prod
```

Variables de entorno requeridas:
```
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=
NEXT_PUBLIC_FIREBASE_APP_ID=
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=
NEXT_PUBLIC_RTDB_URL=
WOMPI_PUBLIC_KEY=
WOMPI_PRIVATE_KEY=
WOMPI_EVENTS_KEY=
RESEND_API_KEY=
```

### 7.2. App Móvil

```bash
cd siercp_flutter
# Android
flutter build apk --release
# iOS (requiere macOS + Xcode)
flutter build ios --release
```

### 7.3. Cloudflare Worker

```bash
cd cloudflare-worker
npm install
npx wrangler deploy
```

---

*Documento generado el Julio 2026. Para la versión más reciente, consulta el repositorio oficial.*
