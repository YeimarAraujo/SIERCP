# SIERCP — Documentación Técnica Profesional

**Sistema Integrado de Evaluación y Retroalimentación de RCP**  
Versión 2.1.0 | Última actualización: Abril 2026

---

## Tabla de Contenido

1. [Visión General del Sistema](#1-visión-general-del-sistema)
2. [Arquitectura del Sistema](#2-arquitectura-del-sistema)
3. [Backend Django — API REST](#3-backend-django--api-rest)
4. [Frontend Flutter — Aplicación Móvil](#4-frontend-flutter--aplicación-móvil)
5. [Base de Datos — Modelos y Relaciones](#5-base-de-datos--modelos-y-relaciones)
6. [Diagrama UML de la Base de Datos](#6-diagrama-uml-de-la-base-de-datos)
7. [API Reference](#7-api-reference)
8. [Control de Acceso por Roles (RBAC)](#8-control-de-acceso-por-roles-rbac)
9. [Integración ESP-32 / IoT](#9-integración-esp-32--iot)
10. [Configuración y Despliegue](#10-configuración-y-despliegue)
11. [Variables de Entorno](#11-variables-de-entorno)
12. [Seguridad](#12-seguridad)

---

## 1. Visión General del Sistema

SIERCP es una plataforma educativa clínica diseñada para la enseñanza y evaluación de técnicas de **Resucitación Cardiopulmonar (RCP)** basadas en las guías **AHA 2020** (American Heart Association).

### Componentes Principales

| Componente | Tecnología | Descripción |
|---|---|---|
| **Backend API** | Django 4.x + DRF | API REST con autenticación JWT |
| **App Móvil** | Flutter 3.x | Interfaz de usuario para todas las plataformas |
| **Dispositivo IoT** | ESP-32 | Maniquí de entrenamiento con sensores |
| **Base de Datos** | SQLite (dev) / PostgreSQL (prod) | Almacenamiento persistente |
| **WebSocket** | Django Channels + Daphne | Telemetría en tiempo real (Session monitor) |
| **Reportes** | ReportLab | Generación de certificados PDF |

### Flujo de Uso Principal

```
Instructor crea curso → Enrola estudiantes → Asigna sesiones RCP
         ↓
Estudiante abre app → Selecciona escenario → Conecta maniquí ESP-32
         ↓
ESP-32 envía datos de sensores → Backend los procesa → WebSocket → App
         ↓
Sesión finaliza → Métricas calculadas → Instructor revisa resultados
```

---

## 2. Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENTE (Flutter)                        │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Auth Screen │  │ Home Screen  │  │ Session Screen   │   │
│  │  Login/Reg  │  │  Dashboard  │  │  Waveform+Timer │   │
│  └──────┬──────┘  └──────┬───────┘  └─────────┬────────┘   │
│         │                │                     │            │
│         └────────────────┼─────────────────────┘            │
│                    Riverpod Providers                        │
│         ┌──────────────────────────────────────┐            │
│         │        ApiService (Dio + JWT)         │            │
│         │        WebSocketService               │            │
│         └─────────────────┬────────────────────┘            │
└───────────────────────────│─────────────────────────────────┘
                            │ HTTP REST / WebSocket
┌───────────────────────────▼─────────────────────────────────┐
│                   BACKEND (Django + DRF)                     │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    API Endpoints                      │   │
│  │  /auth/  /courses/  /sessions/  /users/  /manikins/ │   │
│  │  /data/recibir/  /alertas/  /test/                  │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────┐   ┌──────────────────────────────┐    │
│  │   JWT Auth       │   │     Permission Classes       │    │
│  │  SimpleJWT       │   │  IsAdmin/IsInstructor/etc.   │    │
│  └──────────────────┘   └──────────────────────────────┘    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Django ORM + Models                      │   │
│  └──────────────────────┬───────────────────────────────┘   │
└─────────────────────────│───────────────────────────────────┘
                          │ SQL
┌─────────────────────────▼───────────────────────────────────┐
│              BASE DE DATOS (SQLite / PostgreSQL)             │
└─────────────────────────────────────────────────────────────┘
                          ↑ HTTP POST /data/recibir/
┌─────────────────────────┴───────────────────────────────────┐
│              DISPOSITIVO IoT (ESP-32 + Sensores)            │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐ │
│  │  Sensor HR   │  │  Sensor O2    │  │  Sensor Fuerza   │ │
│  │  (BPM)       │  │  (SpO2%)      │  │  (Compresiones)  │ │
│  └──────────────┘  └───────────────┘  └──────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Backend Django — API REST

### Estructura de Archivos

```
siercp_backend/
├── manage.py
├── db.sqlite3
├── .env.example
├── siercp_backend/
│   ├── settings.py       # Configuración principal
│   ├── urls.py           # URL raíz
│   ├── wsgi.py
│   └── asgi.py
└── api/
    ├── models.py         # Modelos de datos
    ├── serializers.py    # Serialización JSON
    ├── views.py          # ViewSets y vistas
    ├── urls.py           # Rutas de la API
    ├── admin.py          # Panel de administración
    ├── utils.py          # Evaluación de alertas
    ├── tests.py          # Pruebas unitarias
    └── migrations/       # Migraciones de BD
```

### Dependencias Principales

| Paquete | Versión | Propósito |
|---|---|---|
| `Django` | ≥4.2 | Framework web |
| `djangorestframework` | ≥3.14 | API REST |
| `djangorestframework-simplejwt` | ≥5.3 | Autenticación JWT |
| `django-cors-headers` | ≥4.0 | Control de CORS |

### Configuración de Seguridad (settings.py)

- **SECRET_KEY**: Varía entre dev (fallback inseguro) y prod (obligatorio en .env)
- **DEBUG**: `True` en dev, `False` en prod
- **JWT Access Token**: 2 horas de vida
- **JWT Refresh Token**: 14 días de vida, con rotación automática
- **Blacklist**: Tokens anteriores se invalidan al rotar
- **Throttling**: 30 req/min para anónimos, 200 req/min para usuarios
- **CORS**: Solo origenes explícitos en producción

---

## 4. Frontend Flutter — Aplicación Móvil

### Estructura de Archivos (lib/)

```
lib/
├── main.dart                    # Punto de entrada
├── core/
│   ├── theme.dart               # Sistema de diseño (dark/light)
│   ├── routes.dart              # Navegación con go_router
│   └── constants.dart           # URLs, claves, parámetros AHA
├── models/
│   ├── user.dart                # UserModel, PerfilModel
│   ├── session.dart             # SessionModel, SessionMetrics, LiveSessionData
│   ├── alert_course.dart        # AlertModel, ScenarioModel, CourseModel
│   └── maniqui.dart             # ManiquiModel
├── providers/
│   ├── auth_provider.dart       # Estado de autenticación
│   ├── session_provider.dart    # Estado de sesión activa
│   └── theme_provider.dart      # Tema claro/oscuro
├── services/
│   ├── api_service.dart         # Cliente HTTP con Dio + interceptores
│   ├── auth_service.dart        # Login, registro, perfil
│   ├── session_service.dart     # Sesiones, escenarios, cursos
│   ├── admin_service.dart       # Gestión de usuarios/maniquíes
│   ├── websocket_service.dart   # Stream de datos en tiempo real
│   └── export_service.dart      # Exportación PDF/Excel
└── screens/
    ├── splash_screen.dart
    ├── login_screen.dart
    ├── register_screen.dart
    ├── main_shell.dart          # Navegación inferior por rol
    ├── home_screen.dart         # Dashboard del usuario
    ├── scenario_select_screen.dart
    ├── session_screen.dart      # Pantalla de sesión en vivo
    ├── session_result_screen.dart
    ├── history_screen.dart
    ├── courses_screen.dart
    ├── profile_screen.dart
    ├── manage_users_screen.dart # Solo ADMIN
    ├── user_detail_screen.dart
    ├── live_instructor_screen.dart
    └── device_status_screen.dart
```

### Gestión de Estado (Riverpod)

```dart
// Ejemplo de flujo de autenticación
final authStateProvider → AuthNotifier → ApiService → backend
final activeSessionProvider → ActiveSessionNotifier → SessionService + WebSocketService
final scenariosProvider → FutureProvider (local, sin backend)
final coursesProvider → FutureProvider → SessionService.getCourses()
```

### Parámetros AHA 2020 configurados

| Parámetro | Adulto | Niño | Lactante |
|---|---|---|---|
| Profundidad mín. | 50 mm | 50 mm | 40 mm |
| Profundidad máx. | 60 mm | 60 mm | — |
| Frecuencia | 100–120/min | 100–120/min | 100–120/min |
| Pausa máxima | 10 seg | 10 seg | 10 seg |
| Relación | 30:2 | 30:2 | 30:2 |

---

## 5. Base de Datos — Modelos y Relaciones

### Descripción de Modelos

#### `Perfil`
Extiende el modelo `User` de Django con rol e identificación.
- **Roles**: `ADMIN`, `INSTRUCTOR`, `ESTUDIANTE`
- **Relación**: `OneToOne → User`

#### `Curso`
Curso educativo creado por un instructor.
- Genera un código único de 6 caracteres al crearse
- Un instructor puede tener múltiples cursos

#### `Matricula`
Relación muchos-a-muchos entre `Estudiante` y `Curso`.
- Restricción `unique_together` para evitar duplicados

#### `CursoSesion`
Sesión RCP asignada como tarea dentro de un curso.
- Referencia un `scenario_id` de los escenarios locales

#### `Maniqui`
Dispositivo ESP-32 registrado en el sistema.
- Identificado por UUID único (MAC address del ESP-32)
- Rastrea estado: `disponible`, `en_uso`, `mantenimiento`, `offline`

#### `SesionRCP`
Registro de una sesión de entrenamiento RCP.
- Conecta `Estudiante`, `Curso`, y `Maniqui`
- Estados: `pending`, `active`, `completed`, `aborted`

#### `MetricaRCP`
Métricas de calidad de una sesión completada.
- `OneToOne → SesionRCP`
- Calcula `score` (0–100), `approved` (≥85)

#### `SensorData`
Lectura de sensores del maniquí ESP-32.
- Trazable a `Maniqui` (por UUID) y `SesionRCP`
- Campos: `ritmo_cardiaco`, `oxigeno`, `presion`, `temperatura`

#### `Alerta`
Alerta generada cuando los datos del sensor exceden umbrales.
- Niveles: `normal`, `medio`, `critico`
- Opcionalmente trazable a una `SesionRCP`

---

## 6. Diagrama UML de la Base de Datos

> Ver archivo `DB_UML.md` para el diagrama completo en formato Mermaid.

---

## 7. API Reference

### Autenticación

| Método | Endpoint | Descripción | Auth |
|---|---|---|---|
| `POST` | `/api/auth/register/` | Registro de usuario | Público |
| `POST` | `/api/auth/login/` | Inicio de sesión (JWT) | Público |
| `POST` | `/api/auth/refresh/` | Renovar access token | Público |
| `POST` | `/api/auth/logout/` | Cerrar sesión (blacklist) | JWT |
| `GET` | `/api/auth/me/` | Datos del usuario actual | JWT |

### Reportes
| Método | Endpoint | Descripción | Roles |
|---|---|---|---|
| `GET` | `/api/sessions/{id}/export/` | Descargar reporte clínico PDF | Todos |

### Cursos

| Método | Endpoint | Descripción | Roles |
|---|---|---|---|
| `GET` | `/api/courses/` | Listar cursos | Todos |
| `POST` | `/api/courses/` | Crear curso | INSTRUCTOR, ADMIN |
| `GET` | `/api/courses/{id}/` | Detalle de curso | Todos |
| `POST` | `/api/courses/join/` | Unirse por código | ESTUDIANTE |
| `POST` | `/api/courses/{id}/enroll/` | Enrolar estudiante | INSTRUCTOR, ADMIN |
| `DELETE` | `/api/courses/{id}/unenroll/{student_id}/` | Remover estudiante | INSTRUCTOR, ADMIN |
| `GET` | `/api/courses/{id}/students/` | Listar estudiantes | INSTRUCTOR, ADMIN |
| `POST` | `/api/courses/{id}/add-session/` | Añadir tarea sesión | INSTRUCTOR, ADMIN |
| `GET` | `/api/courses/{id}/sessions/` | Listar sesiones del curso | INSTRUCTOR, ADMIN |

### Sesiones RCP

| Método | Endpoint | Descripción | Roles |
|---|---|---|---|
| `GET` | `/api/sessions/` | Listar sesiones | Todos |
| `POST` | `/api/sessions/` | Iniciar sesión | ESTUDIANTE |
| `GET` | `/api/sessions/{id}/` | Detalle con métricas | Todos |
| `PATCH` | `/api/sessions/{id}/complete/` | Completar sesión | Propietario, INSTRUCTOR, ADMIN |
| `PATCH` | `/api/sessions/{id}/abort/` | Abortar sesión | Propietario, INSTRUCTOR, ADMIN |

### Usuarios (Admin)

| Método | Endpoint | Descripción | Roles |
|---|---|---|---|
| `GET` | `/api/users/` | Listar todos los usuarios | ADMIN |
| `DELETE` | `/api/users/{id}/` | Eliminar usuario | ADMIN |
| `PATCH` | `/api/users/{id}/toggle-active/` | Activar/Desactivar cuenta | ADMIN |
| `GET` | `/api/users/by-role/{rol}/` | Filtrar por rol | ADMIN |

### Maniquíes

| Método | Endpoint | Descripción | Roles |
|---|---|---|---|
| `GET` | `/api/manikins/` | Listar maniquíes | Todos |
| `POST` | `/api/manikins/` | Registrar maniquí | ADMIN |
| `PUT/PATCH` | `/api/manikins/{id}/` | Actualizar estado | ADMIN |

### IoT / Sensores

| Método | Endpoint | Descripción | Auth |
|---|---|---|---|
| `POST` | `/api/data/recibir/` | Enviar datos del ESP-32 | Público (IoT) |
| `GET` | `/api/data/obtener/` | Últimas 20 lecturas | JWT |
| `GET` | `/api/alertas/` | Últimas 10 alertas | JWT |
| `GET` | `/api/test/` | Health check | Público |

### WebSocket (Real-time)
- **Host**: `ws://<domain>/session/<id>/` (dev: `ws://127.0.0.1:8000/session/<id>/`)
- **Protocolo**: JSON
- **Token**: `?token=<access_token>`

### Ejemplo: Envío de datos ESP-32

```json
POST /api/data/recibir/
Content-Type: application/json

{
  "api_key": "YOUR_DEVICE_API_KEY",
  "maniqui_uuid": "AA:BB:CC:DD:EE:FF",
  "sesion": 42,
  "ritmo_cardiaco": 35.0,
  "oxigeno": 92.0,
  "presion": 75.0,
  "temperatura": 36.5
}

Response 200:
{
  "mensaje": "Datos guardados correctamente.",
  "nivel": "critico"
}
```

---

## 8. Control de Acceso por Roles (RBAC)

### Matriz de Permisos

| Funcionalidad | ADMIN | INSTRUCTOR | ESTUDIANTE |
|---|:---:|:---:|:---:|
| Ver todos los usuarios | ✅ | ❌ | ❌ |
| Eliminar usuarios | ✅ | ❌ | ❌ |
| Crear cursos | ✅ | ✅ | ❌ |
| Enrolar estudiantes | ✅ | ✅ (solo sus cursos) | ❌ |
| Unirse a curso por código | ❌ | ❌ | ✅ |
| Iniciar sesión RCP | ❌ | ❌ | ✅ |
| Ver sesiones de estudiantes | ✅ | ✅ (sus cursos) | Solo propias |
| Registrar maniquíes | ✅ | ❌ | ❌ |
| Ver maniquíes | ✅ | ✅ | ✅ |

---

## 9. Integración ESP-32 / IoT

Ver archivo `ESP32_GUIDE.md` para la guía completa paso a paso.

### Contrato de datos (ESP-32 → Backend)

El ESP-32 hace un `HTTP POST` a `/api/data/recibir/` cada segundo con:

```json
{
  "maniqui_uuid": "<MAC_ADDRESS>",
  "sesion": <ID_SESION_ACTIVA_O_NULL>,
  "ritmo_cardiaco": <float_BPM>,
  "oxigeno": <float_porcentaje>,
  "presion": <float_mmHg>,
  "temperatura": <float_grados_C>
}
```

### Lógica de Alertas (utils.py)

| Condición | Nivel |
|---|---|
| HR: 60–100 BPM y Presión: 90–140 mmHg | `normal` |
| HR: 50–59 ó 101–120 BPM | `medio` |
| HR < 50 ó > 120, o Presión < 80 ó > 160 | `critico` |

---

## 10. Configuración y Despliegue

### Instalación en Desarrollo

```bash
# 1. Clonar el repositorio
git clone <repo_url>
cd SIERCP/siercp_backend

# 2. Instalar dependencias
pip install django djangorestframework djangorestframework-simplejwt django-cors-headers

# 3. Copiar y configurar el .env
cp .env.example .env
# Editar .env con tus valores

# 4. Ejecutar migraciones
python manage.py migrate

# 5. Crear superusuario
python manage.py createsuperuser

# 6. Iniciar servidor
python manage.py runserver 0.0.0.0:8000
```

### Configuración Flutter

```bash
cd SIERCP/siercp_flutter
flutter pub get
# Para desarrollo: asegurarse que baseUrlDev en constants.dart apunte al servidor
flutter run
```

---

## 11. Variables de Entorno

Copiar `.env.example` a `.env` y configurar:

| Variable | Ejemplo | Requerido en Prod |
|---|---|---|
| `SECRET_KEY` | `django-secret-key-...` | ✅ Obligatorio |
| `DEBUG` | `False` | ✅ |
| `ALLOWED_HOSTS` | `api.siercp.edu.co,localhost` | ✅ |
| `DB_NAME` | `SIERCP_DB` | ✅ (PostgreSQL) |
| `DB_USER` | `siercp_user` | ✅ (PostgreSQL) |
| `DB_PASSWORD` | `<contraseña_segura>` | ✅ (PostgreSQL) |
| `DB_HOST` | `localhost` | ✅ (PostgreSQL) |
| `DB_PORT` | `5432` | ✅ (PostgreSQL) |
| `CORS_ALLOWED_ORIGINS` | `https://app.siercp.edu.co` | ✅ |

> **Nota**: Si `DB_NAME` no está configurado, el sistema usa SQLite automáticamente (solo para desarrollo).

---

## 12. Seguridad

Ver archivo `SECURITY_TESTING.md` para el plan completo de pruebas de seguridad.

### Medidas Implementadas

- ✅ JWT con blacklist (invalidación de tokens)
- ✅ Rotación de refresh tokens
- ✅ Throttling: 30 req/min anónimos / 200 req/min autenticados
- ✅ Permisos granulares por rol (RBAC)
- ✅ CORS configurado explícitamente en producción
- ✅ Validación de unicidad en email e identificación
- ✅ HSTS, XSS Filter, X-Frame-Options en producción
- ✅ Contraseñas con mínimo 8 caracteres
- ✅ Endpoint IoT con **X-API-Key** (seguridad por dispositivo)
- ✅ Transmisión WebSocket en tiempo real
- ✅ Generación de reportes PDF firmados
