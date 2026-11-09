# Documentación Profesional — SICAP

**Sistema Inteligente de Capacitación en Reanimación Cardiopulmonar**

Versión: 1.0 — Julio 2026

---

## Contenido

1. [Requerimientos funcionales](#1-requerimientos-funcionales)
2. [Requerimientos no funcionales](#2-requerimientos-no-funcionales)
3. [Casos de uso](#3-casos-de-uso)
4. [Diagramas UML](#4-diagramas-uml)
5. [Modelo entidad-relación](#5-modelo-entidad-relacion)
6. [Arquitectura](#6-arquitectura)
7. [Plan de pruebas](#7-plan-de-pruebas)
8. [Mantenimiento](#8-mantenimiento)
9. [Control de versiones](#9-control-de-versiones)

---

## 1. Requerimientos funcionales

### 1.1. Módulo de autenticación

| ID | Requerimiento | Prioridad | Dependencia |
|---|---|---|---|
| RF-001 | El sistema debe permitir el inicio de sesión con correo electrónico y contraseña | Alta | Firebase Auth |
| RF-002 | El sistema debe permitir el restablecimiento de contraseña mediante enlace por correo | Alta | Firebase Auth |
| RF-003 | El sistema debe mantener la sesión activa mediante HttpOnly cookies | Alta | — |
| RF-004 | El sistema debe redirigir al usuario al dashboard correspondiente según su rol | Alta | RF-001 |
| RF-005 | El sistema debe cerrar la sesión al presionar "Cerrar sesión" y eliminar la cookie | Alta | — |
| RF-006 | El sistema debe detectar cuentas desactivadas en tiempo real y cerrar la sesión | Media | Firestore onSnapshot |

### 1.2. Módulo de usuarios

| ID | Requerimiento | Prioridad | Dependencia |
|---|---|---|---|
| RF-007 | El sistema debe permitir al ADMIN crear usuarios con rol específico | Alta | RF-001 |
| RF-008 | El sistema debe permitir al ADMIN editar datos de usuarios existentes | Alta | RF-007 |
| RF-009 | El sistema debe permitir al ADMIN desactivar y activar cuentas de usuario | Alta | RF-007 |
| RF-010 | El sistema debe permitir al ADMIN importar estudiantes desde archivo CSV | Media | RF-007 |
| RF-011 | El sistema debe permitir al INSTRUCTOR ver la lista de sus estudiantes | Alta | RF-001 |
| RF-012 | El sistema debe permitir al INSTRUCTOR ver el detalle de progreso de un estudiante | Alta | RF-011 |
| RF-013 | El sistema debe crear instructores en estado "pendiente de aprobación" | Alta | RF-007 |
| RF-014 | El sistema debe permitir al ADMIN aprobar instructores pendientes | Alta | RF-013 |

### 1.3. Módulo de sesiones RCP

| ID | Requerimiento | Prioridad | Dependencia |
|---|---|---|---|
| RF-015 | El sistema debe permitir al ESTUDIANTE iniciar una sesión RCP desde la app móvil | Alta | — |
| RF-016 | El sistema debe conectar el maniquí ESP32 vía Bluetooth BLE | Alta | — |
| RF-017 | El sistema debe mostrar métricas en tiempo real: profundidad, frecuencia, fuerza, recoil | Alta | RF-016 |
| RF-018 | El sistema debe mostrar barras de colores según rangos AHA (verde/amarillo/rojo) | Alta | RF-017 |
| RF-019 | El sistema debe mostrar una gráfica de onda de compresión en tiempo real | Media | RF-017 |
| RF-020 | El sistema debe contabilizar compresiones totales y correctas | Alta | RF-016 |
| RF-021 | El sistema debe permitir finalizar la sesión en cualquier momento | Alta | RF-015 |
| RF-022 | El sistema debe calcular la puntuación AHA al finalizar la sesión | Alta | RF-020 |
| RF-023 | El sistema debe mostrar el resultado detallado: puntuación, desglose, violaciones | Alta | RF-022 |
| RF-024 | El sistema debe almacenar la sesión en Firestore con todas las métricas | Alta | RF-022 |
| RF-025 | El sistema debe permitir al INSTRUCTOR monitorear sesiones activas en tiempo real desde el web | Media | RF-017 |

### 1.4. Módulo de cursos

| ID | Requerimiento | Prioridad | Dependencia |
|---|---|---|---|
| RF-026 | El sistema debe permitir al INSTRUCTOR y ADMIN crear cursos | Alta | RF-001 |
| RF-027 | El sistema debe generar un código de invitación de 6 caracteres al crear un curso | Alta | RF-026 |
| RF-028 | El sistema debe generar un código QR del código de invitación | Media | RF-027 |
| RF-029 | El sistema debe permitir agregar módulos a un curso (teoría, evaluación, práctica, certificación) | Alta | RF-026 |
| RF-030 | El sistema debe permitir al ESTUDIANTE inscribirse en un curso mediante código de invitación | Alta | RF-027 |
| RF-031 | El sistema debe permitir al ADMIN crear plantillas de curso reutilizables | Media | RF-026 |
| RF-032 | El sistema debe generar cohortes automáticamente según la configuración de la plantilla | Baja | RF-031 |
| RF-033 | El sistema debe permitir al ADMIN gestionar cohortes (abrir, cerrar, completar) | Media | RF-032 |

### 1.5. Módulo de dispositivos

| ID | Requerimiento | Prioridad | Dependencia |
|---|---|---|---|
| RF-034 | El sistema debe permitir al ADMIN registrar maniquíes con nombre, UUID y API Key | Alta | RF-001 |
| RF-035 | El sistema debe mostrar el estado de cada maniquí (disponible/en uso/mantenimiento/offline) | Alta | RF-034 |
| RF-036 | El sistema debe mostrar telemetría en vivo de los maniquíes conectados | Alta | RTDB |
| RF-037 | El sistema debe permitir al ADMIN asignar dispositivos a instructores | Media | RF-034 |

### 1.6. Módulo de pagos

| ID | Requerimiento | Prioridad | Dependencia |
|---|---|---|---|
| RF-038 | El sistema debe procesar pagos mediante Wompi (CARD, PSE, NEQUI) | Alta | — |
| RF-039 | El sistema debe tokenizar tarjetas del lado cliente (cumplimiento PCI-DSS SAQ-A) | Alta | Wompi |
| RF-040 | El sistema debe procesar webhooks de Wompi para actualizar estado de transacciones | Alta | RF-038 |
| RF-041 | El sistema debe activar la inscripción al curso automáticamente tras pago exitoso | Alta | RF-040 |
| RF-042 | El sistema debe enviar correo de confirmación de pago | Media | Resend |
| RF-043 | El sistema debe permitir al ADMIN ver el historial de transacciones | Media | RF-040 |

### 1.7. Módulo de reportes

| ID | Requerimiento | Prioridad | Dependencia |
|---|---|---|---|
| RF-044 | El sistema debe mostrar al ESTUDIANTE su historial de sesiones con métricas | Alta | RF-024 |
| RF-045 | El sistema debe mostrar al INSTRUCTOR reportes de rendimiento por curso | Alta | RF-024 |
| RF-046 | El sistema debe mostrar al ADMIN métricas operativas de la institución | Alta | RF-024 |
| RF-047 | El sistema debe mostrar al SUPER ADMIN métricas globales de todas las instituciones | Alta | RF-024 |
| RF-048 | El sistema debe permitir exportar reportes a CSV | Media | RF-044 |

### 1.8. Módulo de notificaciones

| ID | Requerimiento | Prioridad | Dependencia |
|---|---|---|---|
| RF-049 | El sistema debe enviar correos transaccionales (bienvenida, confirmación, recuperación) | Alta | Resend |
| RF-050 | El sistema debe enviar notificaciones push FCM | Media | Cloudflare Worker |
| RF-051 | El sistema debe permitir al SUPER ADMIN enviar notificaciones masivas | Baja | RF-050 |

---

## 2. Requerimientos no funcionales

| ID | Requerimiento | Categoría | Métrica |
|---|---|---|---|
| RNF-001 | El sistema debe estar disponible el 99.5% del tiempo | Disponibilidad | Uptime mensual ≥ 99.5% |
| RNF-002 | La latencia de carga del dashboard web debe ser ≤ 2 segundos | Rendimiento | TTFB < 1s, LCP < 2s |
| RNF-003 | La telemetría en vivo debe tener una latencia ≤ 500 ms | Rendimiento | Tiempo sensor → pantalla < 500 ms |
| RNF-004 | El sistema debe soportar hasta 1000 usuarios concurrentes | Escalabilidad | Prueba de carga con 1000 usuarios |
| RNF-005 | El sistema debe cumplir WCAG 2.1 Nivel AA | Accesibilidad | Lighthouse ≥ 90 |
| RNF-006 | Las contraseñas deben almacenarse con hash bcrypt (Firebase Auth) | Seguridad | — |
| RNF-007 | Las sesiones deben expirar después de 24 horas de inactividad | Seguridad | — |
| RNF-008 | Los datos de telemetría deben cifrarse en tránsito (HTTPS/BLE encriptado) | Seguridad | — |
| RNF-009 | La app móvil debe funcionar en Android 8+ y iOS 15+ | Compatibilidad | — |
| RNF-010 | El dashboard web debe funcionar en Chrome 90+, Firefox 90+, Edge 90+, Safari 15+ | Compatibilidad | — |
| RNF-011 | El sistema debe soportar sedes múltiples dentro de una institución | Mantenibilidad | — |
| RNF-012 | El sistema debe registrar todas las acciones en la colección de auditoría | Auditoría | Audit log completo |
| RNF-013 | El sistema debe soportar cambios de plan sin pérdida de datos | Mantenibilidad | — |

---

## 3. Casos de uso

### 3.1. Diagrama de casos de uso (textual)

#### Actor: ESTUDIANTE

| CU | Nombre | Descripción |
|---|---|---|
| CU-01 | Iniciar sesión | El estudiante ingresa correo y contraseña para acceder al sistema |
| CU-02 | Ver dashboard | El estudiante visualiza sus métricas, actividad reciente y cursos activos |
| CU-03 | Conectar maniquí | El estudiante escanea y conecta un maniquí vía Bluetooth BLE |
| CU-04 | Realizar sesión RCP | El estudiante realiza compresiones y ve métricas en tiempo real |
| CU-05 | Ver resultados | El estudiante revisa puntuación, desglose AHA y violaciones |
| CU-06 | Ver historial | El estudiante consulta sesiones anteriores |
| CU-07 | Inscribirse en curso | El estudiante ingresa código de invitación para unirse a un curso |
| CU-08 | Ver ranking | El estudiante consulta su posición frente a compañeros |
| CU-09 | Editar perfil | El estudiante modifica su información personal |
| CU-10 | Ver certificados | El estudiante consulta sus certificados obtenidos |

#### Actor: INSTRUCTOR

| CU | Nombre | Descripción |
|---|---|---|
| CU-11 | Ver dashboard instructor | El instructor ve KPIs de estudiantes supervisados |
| CU-12 | Crear curso | El instructor crea un nuevo curso con módulos |
| CU-13 | Ver estudiantes | El instructor consulta lista y detalle de sus estudiantes |
| CU-14 | Monitorear sesión en vivo | El instructor ve métricas en tiempo real de un estudiante |
| CU-15 | Evaluar sesión | El instructor califica sesiones de estudiantes |
| CU-16 | Generar reportes | El instructor exporta reportes de rendimiento |

#### Actor: ADMIN

| CU | Nombre | Descripción |
|---|---|---|
| CU-17 | Gestionar usuarios | El admin crea, edita, activa/desactiva usuarios |
| CU-18 | Importar estudiantes | El admin carga estudiantes masivamente desde CSV |
| CU-19 | Gestionar dispositivos | El admin registra y asigna maniquíes |
| CU-20 | Gestionar sedes | El admin crea y configura sedes |
| CU-21 | Ver reportes institucionales | El admin genera reportes operativos |
| CU-22 | Aprobar instructores | El admin activa cuentas de instructores pendientes |
| CU-23 | Configurar institución | El admin modifica ajustes institucionales |

#### Actor: SUPER ADMIN

| CU | Nombre | Descripción |
|---|---|---|
| CU-24 | Ver dashboard global | El SA ve KPIs de todas las instituciones |
| CU-25 | Gestionar instituciones | El SA crea, edita y aprueba instituciones |
| CU-26 | Gestionar planes | El SA configura planes y límites |
| CU-27 | Aprobar solicitudes | El SA aprueba instituciones, admins e instructores |
| CU-28 | Ver logs de auditoría | El SA consulta el registro completo de acciones |
| CU-29 | Enviar notificaciones | El SA envía notificaciones masivas |

### 3.2. Especificación de caso de uso crítico: CU-04 Realizar sesión RCP

| Campo | Valor |
|---|---|
| **ID** | CU-04 |
| **Nombre** | Realizar sesión RCP |
| **Actor** | ESTUDIANTE |
| **Descripción** | El estudiante realiza una sesión de entrenamiento RCP con el maniquí conectado |
| **Precondición** | Maniquí conectado vía BLE, sesión no iniciada |
| **Postcondición** | Sesión almacenada en Firestore con métricas completas |
| **Flujo principal** | |
| 1. | El estudiante presiona "Iniciar sesión" |
| 2. | El sistema envía comando START (0x01) al ESP32 |
| 3. | El ESP32 comienza a enviar telemetría a 20 Hz |
| 4. | El sistema muestra métricas en tiempo real |
| 5. | El estudiante realiza compresiones |
| 6. | El sistema actualiza métricas cada 50 ms |
| 7. | El estudiante presiona "Finalizar sesión" |
| 8. | El sistema envía comando STOP (0x00) al ESP32 |
| 9. | El sistema calcula puntuación AHA |
| 10. | El sistema muestra pantalla de resultados |
| 11. | El sistema guarda la sesión en Firestore |
| **Flujo alternativo** | |
| 4a. | Conexión BLE perdida: mostrar mensaje de reconexión |
| 6a. | Compresiones muy débiles (<15mm): mostrar "Aumenta la profundidad" |
| **Excepciones** | |
| - | El maniquí se desconecta: mostrar alerta, finalizar sesión automáticamente tras 30s |

---

## 4. Diagramas UML

### 4.1. Diagrama de clases (modelo principal)

```
┌─────────────────────────────┐
│           User              │
├─────────────────────────────┤
│ - uid: String               │
│ - email: String             │
│ - firstName: String         │
│ - lastName: String          │
│ - role: UserRole            │
│ - institutionId: String     │
│ - isActive: Boolean         │
│ - stats: UserStats          │
│ - createdAt: Timestamp      │
├─────────────────────────────┤
│ + getFullName(): String     │
│ + hasRole(role): Boolean    │
└──────────────┬──────────────┘
               │
               │ 1
               │
┌──────────────┴──────────────┐
│         Institution         │
├─────────────────────────────┤
│ - id: String                │
│ - name: String              │
│ - code: String              │
│ - planType: String          │
│ - maxStudents: Number       │
│ - adminIds: String[]        │
│ - status: String            │
├─────────────────────────────┤
│ + isPlanActive(): Boolean   │
│ + canAddUser(): Boolean     │
└─────────────────────────────┘

┌─────────────────────────────┐        ┌─────────────────────────────┐
│         Session             │        │        Course              │
├─────────────────────────────┤        ├─────────────────────────────┤
│ - id: String                │        │ - id: String                │
│ - studentId: String         │◄───────│ - instructorId: String      │
│ - studentName: String       │        │ - title: String             │
│ - scenarioId: String        │        │ - inviteCode: String        │
│ - courseId: String          │        │ - institutionId: String     │
│ - manikinId: String         │        │ - isActive: Boolean         │
│ - startedAt: Timestamp      │        │ - moduleCount: Number       │
│ - endedAt: Timestamp        │        │ - studentCount: Number      │
│ - duration: Number          │        ├─────────────────────────────┤
│ - metrics: SessionMetrics   │        │ + generateInviteCode(): void│
├─────────────────────────────┤        │ + addModule(module): void   │
│ + calculateScore(): Number  │        │ + enrollStudent(user): void │
│ + isApproved(): Boolean     │        └──────────────┬──────────────┘
│ + getViolations(): String[] │                       │
└─────────────────────────────┘                       │ 1
                                                       │
                                              ┌────────┴────────┐
                                              │  CourseModule   │
                                              ├─────────────────┤
                                              │ - id: String    │
                                              │ - title: String │
                                              │ - type: ModType │
                                              │ - order: Number │
                                              │ - isRequired    │
                                              └─────────────────┘

┌─────────────────────────────┐
│      SessionMetrics         │
├─────────────────────────────┤
│ - totalCompressions: Number │
│ - correctCompressions: Number│
│ - averageDepthMm: Float     │
│ - averageRatePerMin: Float  │
│ - averageForceKg: Float     │
│ - recoilPct: Float          │
│ - interruptionCount: Number │
│ - maxPauseSeconds: Float    │
│ - ccfPct: Float             │
│ - depthScore: Float         │
│ - rateScore: Float          │
│ - recoilScore: Float        │
│ - interruptionScore: Float  │
│ - score: Float              │
│ - approved: Boolean         │
│ - violations: String[]      │
└─────────────────────────────┘

┌─────────────────────────────┐
│        Maniqui              │
├─────────────────────────────┤
│ - id: String                │
│ - name: String              │
│ - uuid: String              │
│ - apiKey: String            │
│ - status: DeviceStatus      │
│ - assignedTo: String        │
│ - currentSessionId: String  │
│ - lastConnection: Timestamp │
└─────────────────────────────┘
```

### 4.2. Diagrama de secuencia: Realizar sesión RCP

```
Estudiante      App Flutter      ESP32          Firebase         Instructor
    │                │              │               │                │
    │   Iniciar      │              │               │                │
    │──sesión────────►              │               │                │
    │                │              │               │                │
    │                │ START(0x01)  │               │                │
    │                ├──────────────►               │                │
    │                │              │               │                │
    │                │    Telemetría batch (20Hz)    │                │
    │                │◄─────────────┤               │                │
    │                │              │               │                │
    │    Métricas    │              │               │                │
    │◄───────────────┤              │               │                │
    │                │              │               │                │
    │                │  RTDB update │               │                │
    │                ├──────────────┼───────────────►                │
    │                │              │               │                │
    │                │              │               │   Real-time    │
    │                │              │               │◄───────────────┤
    │                │              │               │                │
    │   Finalizar    │              │               │                │
    │──sesión────────►              │               │                │
    │                │              │               │                │
    │                │ STOP(0x00)   │               │                │
    │                ├──────────────►               │                │
    │                │              │               │                │
    │                │              │   Save session │                │
    │                ├──────────────┼───────────────►                │
    │                │              │               │                │
    │   Resultados   │              │               │                │
    │◄───────────────┤              │               │                │
    │                │              │               │                │
```

### 4.3. Diagrama de estado: Maniquí

```
          ┌──────────┐
          │  Offline  │
          └─────┬─────┘
                │ Conecta BLE
                ▼
          ┌──────────┐
          │Dispobile │◄────┐
          └─────┬─────┘    │
                │ START    │ STOP + reset
                ▼          │
          ┌──────────┐     │
          │ En uso   │─────┘
          │ (sesión) │
          └─────┬─────┘
                │ Error / mantenimiento
                ▼
          ┌──────────┐
          │Mantenim. │
          └─────┬─────┘
                │ Reparado
                ▼
          ┌──────────┐
          │ Dispobile │
          └──────────┘
```

---

## 5. Modelo entidad-relación

### 5.1. MER conceptual (Firestore)

Firestore es una base de datos NoSQL documental. No hay joins tradicionales. Las relaciones se modelan mediante referencias (IDs) y subcolecciones.

```
┌─────────────────────────────────────────────────────────────┐
│                        INSTITUTION                           │
├─────────────────────────────────────────────────────────────┤
│ PK: institutionId                                            │
├─────────────────────────────────────────────────────────────┤
│ name, code, nit, address, city, department                   │
│ contactEmail, contactPhone, logoUrl                          │
│ planType, status, tier                                       │
│ maxDevices, maxInstructors, maxStudents                      │
│ adminIds[], primaryAdminId                                   │
│ createdAt, updatedAt                                         │
└─────────────────────────────────────────────────────────────┘
         │ 1
         │
         ├──────────────────────────────────┐
         │                                  │
         ▼ 1:N                             ▼ 1:N
┌──────────────────┐             ┌──────────────────┐
│      USER        │             │     COURSE       │
├──────────────────┤             ├──────────────────┤
│ PK: uid          │             │ PK: courseId     │
├──────────────────┤             ├──────────────────┤
│ FK: institutionId│             │ FK: instructorId │
│ email, firstName │             │ FK: institutionId│
│ role, isActive   │             │ title, desc      │
│ stats {...}      │             │ inviteCode       │
│ fcmTokens[]      │             │ isActive         │
└──────────────────┘             └──────┬───────────┘
         │                              │
         │ 1:N                          │ 1
         │                              │
         ▼ 1:N                          ├──────────────────┐
┌──────────────────┐                    │                  │
│     SESSION      │                    ▼ 1:N             ▼ 1:N
├──────────────────┤          ┌──────────────────┐  ┌──────────────────┐
│ PK: sessionId    │          │   COURSE_MODULE  │  │   ENROLLMENT     │
├──────────────────┤          ├──────────────────┤  ├──────────────────┤
│ FK: studentId    │          │ PK: moduleId     │  │ PK: enrollmentId │
│ FK: courseId     │          ├──────────────────┤  ├──────────────────┤
│ FK: manikinId    │          │ FK: courseId     │  │ FK: courseId     │
│ startedAt        │          │ title, type      │  │ FK: userId       │
│ endedAt          │          │ contentUrl       │  │ status, score    │
│ metrics {...}    │          │ order, isRequired│  │ joinedAt         │
└──────────────────┘          └──────────────────┘  └──────────────────┘

┌──────────────────┐          ┌──────────────────────────┐
│    MANIQUI       │          │   COURSE_TEMPLATE         │
├──────────────────┤          ├──────────────────────────┤
│ PK: deviceId     │          │ PK: templateId            │
├──────────────────┤          ├──────────────────────────┤
│ name, uuid       │          │ FK: institutionId         │
│ apiKey, status   │          │ title, level, modality    │
│ assignedTo       │          │ priceCOP, priceUSD        │
│ lastConnection   │          │ modules[], isAutomated    │
└──────────────────┘          └──────────┬────────────────┘
                                          │ 1
                                          │
                                          ▼ 1:N
                                 ┌──────────────────┐
                                 │     COHORT       │
                                 ├──────────────────┤
                                 │ PK: cohortId     │
                                 ├──────────────────┤
                                 │ FK: templateId   │
                                 │ cohortNumber     │
                                 │ maxStudents      │
                                 │ priceCOP/USD     │
                                 │ status           │
                                 │ enrollmentStart  │
                                 │ classesEnd       │
                                 └──────────────────┘
```

---

## 6. Arquitectura

### 6.1. Diagrama de despliegue

```
┌──────────────────────────────────────────────────┐
│                   CLIENTE                         │
│                                                   │
│  ┌──────────────┐     ┌──────────────────┐       │
│  │  App Móvil   │     │  Navegador Web   │       │
│  │  (Flutter)   │     │  (Next.js SPA)   │       │
│  │  Android/iOS │     │  Chrome/Firefox  │       │
│  └──────┬───────┘     └────────┬─────────┘       │
│         │                      │                  │
└─────────┼──────────────────────┼──────────────────┘
          │ BLE                  │ HTTPS
          │                      │
┌─────────┼──────────────────────┼──────────────────┐
│         ▼                      ▼                   │
│  ┌──────────────┐     ┌──────────────────┐       │
│  │   ESP32      │     │    Vercel        │       │
│  │   (Maniquí)  │     │  Next.js App     │       │
│  │   VL53L0X    │     │  Server Components│       │
│  │   HX711      │     │  API Routes      │       │
│  │   BLE Server │     └────────┬─────────┘       │
│  └──────────────┘              │                  │
│                                │                  │
│  ┌─────────────────────────────┼────────────────┐ │
│  │         Firebase            │                │ │
│  │                             │                │ │
│  │  ┌──────────┐ ┌──────────┐ │                │ │
│  │  │   Auth   │ │Firestore │◄┘                │ │
│  │  └──────────┘ └──────────┘                  │ │
│  │  ┌──────────┐ ┌──────────┐                  │ │
│  │  │   RTDB   │ │ Storage  │                  │ │
│  │  └──────────┘ └──────────┘                  │ │
│  └──────────────────────────────────────────────┘ │
│                                                   │
│  ┌──────────────────────────────────────────────┐ │
│  │         Cloudflare Worker                    │ │
│  │         (Push Notifications FCM)             │ │
│  └──────────────────────────────────────────────┘ │
│                                                   │
│  ┌──────────────────────────────────────────────┐ │
│  │         Wompi API (Pagos)                   │ │
│  └──────────────────────────────────────────────┘ │
│                                                   │
│  ┌──────────────────────────────────────────────┐ │
│  │         Resend API (Correos)                │ │
│  └──────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

### 6.2. Stack tecnológico resumido

| Capa | Tecnología | Proveedor |
|---|---|---|
| Presentación web | Next.js 16 + React 19 + Tailwind 4 | Open source |
| Presentación móvil | Flutter 3.22+ | Open source |
| Lógica de negocio (web) | API Routes Next.js + Zustand | Vercel |
| Lógica de negocio (app) | Riverpod + Dio | Open source |
| Firmware | Arduino C++ (ESP32) | Espressif |
| Autenticación | Firebase Auth | Google |
| Base de datos principal | Firestore (NoSQL) | Google |
| Tiempo real | Firebase RTDB | Google |
| Archivos | Firebase Storage | Google |
| Pagos | Wompi API | Wompi |
| Correos | Resend API | Resend |
| Notificaciones push | Cloudflare Workers + FCM | Cloudflare/Google |

---

## 7. Plan de pruebas

### 7.1. Estrategia de pruebas

| Tipo | Herramienta | Cobertura objetivo | Frecuencia |
|---|---|---|---|
| Unitarias (web) | Vitest | ≥ 80% | Cada commit |
| Unitarias (app) | flutter_test | ≥ 70% | Cada commit |
| Integración (API) | Postman / Supertest | Endpoints críticos | Cada PR |
| E2E (web) | Playwright | Flujos core | Cada release |
| E2E (móvil) | Patrol / Flutter Driver | Flujo sesión RCP | Cada release |
| Carga | k6 / Artillery | 1000 usuarios concurrentes | Mensual |
| Seguridad | OWASP ZAP | Autenticación, datos | Trimestral |
| Accesibilidad | axe + Lighthouse | WCAG AA | Cada release |

### 7.2. Pruebas unitarias críticas

#### Backend (scoring AHA)

```typescript
// tests/scoring.test.ts
describe('AHA Scoring', () => {
  test('score 100 when all metrics perfect', () => {
    const metrics = {
      averageDepthMm: 55,    // ideal
      averageRatePerMin: 110, // ideal
      recoilPct: 1.0,        // perfect recoil
      maxPauseSeconds: 0     // no interruptions
    };
    expect(calculateScore(metrics)).toBe(100);
  });

  test('fail when depth below 50mm', () => {
    const metrics = {
      averageDepthMm: 30,
      averageRatePerMin: 110,
      recoilPct: 1.0,
      maxPauseSeconds: 0
    };
    const result = calculateScore(metrics);
    expect(result.approved).toBe(false);
    expect(result.violations).toContain('Profundidad insuficiente');
  });

  test('fail when rate outside 100-120', () => {
    const metrics = {
      averageDepthMm: 55,
      averageRatePerMin: 140,
      recoilPct: 1.0,
      maxPauseSeconds: 0
    };
    const result = calculateScore(metrics);
    expect(result.approved).toBe(false);
  });
});
```

#### Firmware (FSM de compresión)

```cpp
// tests/test_fsm.cpp
void test_compression_detection() {
  State state = IDLE;
  uint32_t now = 1000;

  // Simular compresión válida
  state = updateFSM(20.0, now);  // PRESSING
  state = updateFSM(20.0, now);  // HOLDING (confirmado)

  state = updateFSM(5.0, now);   // RELEASING
  state = updateFSM(5.0, now);   // IDLE (compresión contada)

  assert(compressionCount == 1);
}
```

### 7.3. Pruebas de integración

| Escenario | Pasos | Resultado esperado |
|---|---|---|
| Inicio de sesión exitoso | POST /api/auth/session con credenciales válidas | 200 + HttpOnly cookie |
| Inicio de sesión fallido | POST /api/auth/session con credenciales inválidas | 401 + mensaje de error |
| Crear curso | POST /api/courses con datos válidos | 201 + courseId |
| Inscribir estudiante | POST /api/courses/{id}/enroll | 200 + enrollmentId |
| Webhook Wompi | POST /api/wompi-webhook con payload válido | 200 + actualización de inscripción |

### 7.4. Pruebas E2E (Playwright)

```
Flujo: Registro → Login → Ver dashboard → Cerrar sesión
Flujo: Login → Conectar maniquí → Iniciar sesión RCP → Finalizar → Ver resultados
Flujo: Login (admin) → Crear usuario → Verificar que aparece en lista → Editar → Desactivar
Flujo: Login (instructor) → Crear curso → Agregar módulo → Generar invitación
```

---

## 8. Mantenimiento

### 8.1. Mantenimiento del firmware ESP32

| Tarea | Frecuencia | Descripción |
|---|---|---|
| Actualización de umbrales AHA | Anual (cuando AHA publica nuevas guías) | Revisar DEPTH_DOWN, DEPTH_UP, COOLDOWN según nuevas guías |
| Calibración de sensores | Mensual | Verificar baselineDepth, ajustar scale de HX711 |
| Limpieza de sensor óptico | Semanal | Limpiar ventana del VL53L0X con paño seco |
| Reemplazo de espuma del tórax | Cada 6 meses | La espuma pierde resiliencia y afecta lecturas |

### 8.2. Mantenimiento del dashboard web

| Tarea | Frecuencia | Descripción |
|---|---|---|
| Actualizar dependencias npm | Mensual | Revisar vulnerabilidades con `npm audit` |
| Rotar claves de Firebase | Anual | Generar nuevas claves privadas de cuenta de servicio |
| Revisar reglas de seguridad Firestore | Trimestral | Verificar que las reglas sigan siendo adecuadas |
| Limpiar datos antiguos | Trimestral | Archivar sesiones con más de 1 año |
| Backup de Firestore | Diario | Exportación automática programada en Firebase Console |

### 8.3. Mantenimiento de la app móvil

| Tarea | Frecuencia | Descripción |
|---|---|---|
| Actualizar Flutter SDK | Por release estable | Seguir versión estable de Flutter |
| Revisar permisos de plataforma | Por release de SO | Android/iOS pueden cambiar políticas de permisos |
| Actualizar dependencias | Mensual | `flutter pub outdated` + `flutter pub upgrade` |

---

## 9. Control de versiones

### 9.1. Estrategia de ramas (Git Flow simplificado)

```
master
  │
  ├── develop
  │     │
  │     ├── feature/nueva-funcionalidad
  │     ├── feature/otra-funcionalidad
  │     │
  │     └── release/v1.2.0
  │           │
  │           └── master (tag v1.2.0)
  │
  └── hotfix/arreglo-critico
        │
        └── master (tag v1.1.1)
```

### 9.2. Convención de commits (Conventional Commits)

```
feat: agregar monitoreo en vivo para instructores
fix: corregir cálculo de puntuación de profundidad
docs: actualizar manual de instalación
refactor: simplificar FSM de compresión en firmware
test: agregar pruebas de scoring AHA
chore: actualizar dependencias de Firebase
style: ajustar colores de barras AHA
```

### 9.3. Versionado semántico

| Componente | Versión actual | Siguiente |
|---|---|---|
| SICAP Web | v0.65.0 | v1.0.0 (estable) |
| SICAP App | v0.60.0 | v1.0.0 (estable) |
| Firmware ESP32 | v1.0.0 | v1.1.0 |
| Cloudflare Worker | v1.0.0 | v1.1.0 |

Formato: `MAJOR.MINOR.PATCH`
- **MAJOR**: cambios incompatibles con versiones anteriores
- **MINOR**: nuevas funcionalidades compatibles
- **PATCH**: correcciones de errores compatibles

### 9.4. Tags y releases

Cada release en master debe incluir:
1. Tag semántico: `git tag v1.0.0`
2. Release notes en GitHub con:
   - Nuevas funcionalidades
   - Correcciones
   - Cambios de configuración
   - Instrucciones de actualización

---

*Documento generado el Julio 2026. Para la versión más reciente, consulta el repositorio oficial.*
