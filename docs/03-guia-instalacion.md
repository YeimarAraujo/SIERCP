# Guía de Instalación — SICAP

**Sistema Inteligente de Capacitación en Reanimación Cardiopulmonar**

Versión: 1.0 — Julio 2026

---

## Contenido

1. [Requisitos del sistema](#1-requisitos-del-sistema)
2. [Configuración del servidor](#2-configuracion-del-servidor)
3. [Variables de entorno](#3-variables-de-entorno)
4. [Base de datos](#4-base-de-datos)
5. [Ejecución](#5-ejecucion)
6. [Verificación post-instalación](#6-verificacion-post-instalacion)

---

## 1. Requisitos del sistema

### 1.1. Hardware recomendado

| Componente | Mínimo | Recomendado |
|---|---|---|
| Procesador | 2 cores, 2.0 GHz | 4 cores, 3.0 GHz |
| RAM | 4 GB | 8 GB |
| Almacenamiento | 20 GB SSD | 50 GB SSD |
| Conexión a internet | 5 Mbps | 20 Mbps |

### 1.2. Software requerido

| Software | Versión | Propósito |
|---|---|---|
| Node.js | 18.x LTS o superior | Entorno de ejecución del dashboard web |
| npm | 9.x o superior | Gestor de paquetes |
| Flutter SDK | 3.22+ | Compilación de la app móvil |
| Dart SDK | 3.0+ | Lenguaje de la app móvil |
| Arduino IDE | 2.x | Programación del firmware ESP32 |
| Git | 2.x | Control de versiones |
| Firebase CLI | latest | Emulación y despliegue de Firebase |

### 1.3. Cuentas requeridas

| Servicio | Propósito |
|---|---|
| Firebase (Google) | Autenticación, base de datos, almacenamiento |
| Vercel (opcional) | Despliegue del dashboard web |
| Wompi (opcional) | Pasarela de pagos para Colombia |
| Resend (opcional) | Correos transaccionales |
| Cloudflare (opcional) | Notificaciones push |

---

## 2. Configuración del servidor

### 2.1. Configuración de Firebase

#### 2.1.1. Crear proyecto en Firebase

**Objetivo:** Configurar el proyecto Firebase que servirá como backend del sistema.

**Pasos:**

1. Ve a [console.firebase.google.com](https://console.firebase.google.com).
2. Presiona **"Crear un proyecto"**.
3. Ingresa el nombre del proyecto (ej. "SICAP-Produccion").
4. Selecciona o crea una cuenta de Google Analytics (opcional).
5. Espera a que se cree el proyecto.

**Resultado esperado:** El proyecto Firebase queda creado con un ID único.

#### 2.1.2. Habilitar servicios

**Objetivo:** Activar los servicios de Firebase necesarios para el funcionamiento.

**Pasos:**

1. En la consola de Firebase, ve a **Authentication** → **Sign-in method**.
2. Habilita el proveedor **"Correo electrónico/contraseña"**.
3. Ve a **Firestore Database** → **Crear base de datos**.
4. Selecciona **"Modo de prueba"** (se ajustarán reglas después).
5. Elige una ubicación cercana a tus usuarios.
6. Ve a **Realtime Database** → **Crear base de datos**.
7. Selecciona **"Modo de prueba"** y una ubicación.
8. Ve a **Storage** → **Comenzar** → **Modo de prueba**.
9. Ve a **Cloud Messaging** → toma nota del **Server Key** (para notificaciones push).

**Resultado esperado:** Todos los servicios Firebase están habilitados con reglas de prueba.

#### 2.1.3. Registrar app web

**Objetivo:** Obtener las credenciales de Firebase para el dashboard web.

**Pasos:**

1. En la consola de Firebase, ve a **Configuración del proyecto** → **General**.
2. En "Tus apps", presiona **"Agregar app"** → **Web**.
3. Registra un nombre (ej. "SICAP-Web").
4. Copia el objeto `firebaseConfig` con las credenciales. Lo usarás para las variables de entorno.
5. Presiona **"Continuar"** → **"Omitir"** (configurarás el SDK más adelante).

#### 2.1.4. Registrar app móvil

**Objetivo:** Configurar Firebase para la app Flutter.

**Pasos:**

1. En la consola de Firebase, ve a **Configuración del proyecto** → **General**.
2. Presiona **"Agregar app"** → **Android**.
3. Ingresa el nombre del paquete: `com.siercp.app` (o el que uses).
4. Descarga el archivo `google-services.json`.
5. Coloca el archivo en `siercp_flutter/android/app/`.
6. Repite para iOS: descarga `GoogleService-Info.plist` y colócalo en `siercp_flutter/ios/Runner/`.

#### 2.1.5. Configurar Firebase Admin SDK

**Objetivo:** Permitir que el dashboard web acceda a Firebase desde el servidor.

**Pasos:**

1. En la consola de Firebase, ve a **Configuración del proyecto** → **Cuentas de servicio**.
2. Presiona **"Generar nueva clave privada"**.
3. Guarda el archivo JSON con la clave privada.
4. Los valores `FIREBASE_CLIENT_EMAIL` y `FIREBASE_PRIVATE_KEY` se toman de este archivo.

### 2.2. Configuración de Wompi (pagos)

**Objetivo:** Integrar la pasarela de pagos colombiana.

**Pasos:**

1. Regístrate en [wompi.co](https://wompi.co) como comercio.
2. Ve a **Configuración** → **Credenciales**.
3. Copia las claves:
   - **Public Key**: para el frontend (tokenización de tarjetas)
   - **Private Key**: para el backend (confirmación de transacciones)
   - **Events Key**: para verificar webhooks
4. Configura el webhook apuntando a `https://tu-dominio.com/api/wompi-webhook`.

### 2.3. Configuración de Resend (correos)

**Objetivo:** Habilitar envío de correos transaccionales.

**Pasos:**

1. Regístrate en [resend.com](https://resend.com).
2. Ve a **API Keys** y genera una nueva clave.
3. Verifica un dominio remitente (o usa el dominio por defecto de Resend).

### 2.4. Configuración de Cloudflare Worker (notificaciones push)

**Objetivo:** Habilitar notificaciones push FCM gratuitas.

**Pasos:**

1. Crea una cuenta en [Cloudflare](https://cloudflare.com).
2. Ve a **Workers & Pages** → **Create application** → **Worker**.
3. Usa el código en `cloudflare-worker/` como base.
4. Configura las variables de entorno del Worker con las credenciales FCM.
5. Despliega con `npx wrangler deploy`.

---

## 3. Variables de entorno

### 3.1. Dashboard Web (`.env.local`)

Crea un archivo `.env.local` en `SIERCP-WEB/`:

```env
# Firebase Client (frontend)
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSy...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=tu-proyecto.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=tu-proyecto
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=tu-proyecto.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=123456789
NEXT_PUBLIC_FIREBASE_APP_ID=1:123456789:web:abc123

# Firebase Admin (backend)
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@tu-proyecto.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

# Base de datos
NEXT_PUBLIC_RTDB_URL=https://tu-proyecto-rtdb.firebaseio.com

# Wompi (pagos)
WOMPI_PUBLIC_KEY=pub_...
WOMPI_PRIVATE_KEY=prv_...
WOMPI_EVENTS_KEY=evt_...

# Resend (correos)
RESEND_API_KEY=re_...

# Opcional: URL del sitio para notificaciones
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

### 3.2. App Móvil (`config.json`)

Crea un archivo `config.json` en `siercp_flutter/`:

```json
{
  "RTDB_URL": "https://tu-proyecto-rtdb.firebaseio.com",
  "API_URL": "http://localhost:3000/api",
  "ENVIRONMENT": "development"
}
```

> **IMPORTANTE:** Este archivo no debe subirse al repositorio. Ya está incluido en `.gitignore`.

### 3.3. Firmware ESP32

Las constantes se configuran directamente en `esp32_siercp.ino`:

```cpp
// Umbrales de compresión
const float DEPTH_DOWN = 15.0;      // mm para detectar presión
const float DEPTH_UP   = 8.0;       // mm para detectar liberación
const uint8_t CONFIRM  = 2;         // confirmaciones consecutivas
const uint32_t COOLDOWN = 180;      // ms entre compresiones

// Factor de escala de la celda de carga
scale.set_scale(2280.f);
// Opcional: descomentar para tarar al iniciar
// scale.tare();

// Filtro exponencial (0.0 - 1.0)
// Profundidad: rawDepth * 0.5 + filteredDepth * 0.5
// Fuerza: rawForce * 0.4 + filteredForce * 0.6
```

---

## 4. Base de datos

### 4.1. Configurar Firestore

#### 4.1.1. Aplicar reglas de seguridad

**Objetivo:** Proteger los datos de acceso no autorizado.

**Pasos:**

1. En la consola de Firebase, ve a **Firestore Database** → **Reglas**.
2. Reemplaza las reglas por defecto con las reglas del proyecto (ver `firestore.rules` en `siercp_flutter/`).
3. Presiona **"Publicar"**.

#### 4.1.2. Crear índices

**Objetivo:** Optimizar las consultas de Firestore.

**Pasos:**

1. Ejecuta el emulador de Firebase localmente: `firebase emulators:start`.
2. Navega a las rutas del dashboard web y realiza las consultas típicas.
3. Firebase detectará los índices faltantes y mostrará enlaces para crearlos.
4. Alternativamente, usa `firestore.indexes.json` ya configurado en `siercp_flutter/`.

### 4.2. Configurar RTDB

#### 4.2.1. Reglas de la base de datos en tiempo real

```json
{
  "rules": {
    "telemetria": {
      "$mac": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    },
    "sessions_active": {
      "$sessionId": {
        ".read": "auth != null",
        ".write": "auth != null"
      }
    }
  }
}
```

> **Importante:** En producción, estas reglas deben ser más restrictivas, limitando escritura solo a dispositivos autenticados y lectura solo a usuarios autorizados.

### 4.3. Seed de datos iniciales

**Objetivo:** Poblar la base de datos con datos de prueba.

**Pasos:**

1. Navega a la carpeta `scripts/` en la raíz del proyecto.
2. Ejecuta el script de seed:

```bash
cd scripts
npm install
node seed.js
```

Este script creará:
- Un SUPER ADMIN por defecto
- Una institución de prueba
- Planes base (Pyme, Business, Corporate, Enterprise, SST)
- Cursos de ejemplo

---

## 5. Ejecución

### 5.1. Entorno de desarrollo

#### 5.1.1. Dashboard web

```bash
cd SIERCP-WEB
npm install
npm run dev
```

El servidor se iniciará en `http://localhost:3000`.

#### 5.1.2. App móvil

```bash
cd siercp_flutter
flutter pub get
flutter run
```

Para ejecutar en un dispositivo específico:
```bash
flutter devices                  # Listar dispositivos disponibles
flutter run -d <device_id>      # Ejecutar en dispositivo específico
```

#### 5.1.3. Firmware ESP32

1. Abre `esp32_siercp/esp32_siercp.ino` en Arduino IDE.
2. Conecta el ESP32 vía USB.
3. Selecciona la placa: **Tools** → **Board** → **ESP32 Arduino** → **ESP32 Dev Module**.
4. Selecciona el puerto: **Tools** → **Port** → `COMx`.
5. Presiona **Upload** (Ctrl+U).
6. Abre el **Monitor Serie** (115200 baudios) para verificar.

#### 5.1.4. Emulador de Firebase (opcional)

Para desarrollo sin afectar datos de producción:

```bash
firebase emulators:start --import=./.manifests
```

### 5.2. Entorno de producción

#### 5.2.1. Dashboard web (Vercel)

```bash
cd SIERCP-WEB
npm run build
npx vercel --prod
```

O conecta el repositorio a Vercel para despliegue automático desde Git.

#### 5.2.2. App móvil

```bash
cd siercp_flutter

# Android APK
flutter build apk --release

# Android App Bundle (Google Play)
flutter build appbundle --release

# iOS (requiere macOS + Xcode)
flutter build ios --release
```

#### 5.2.3. Cloudflare Worker

```bash
cd cloudflare-worker
npm install
npx wrangler deploy
```

---

## 6. Verificación post-instalación

### 6.1. Checklist de verificación

Una vez completada la instalación, verifica los siguientes puntos:

- [ ] **Firebase Auth**: registrar un usuario de prueba desde el dashboard web
- [ ] **Firestore**: crear un curso y verificar que se guarda en la base de datos
- [ ] **RTDB**: conectar un maniquí y verificar que los datos de telemetría aparecen
- [ ] **App móvil**: iniciar sesión y conectar un maniquí vía BLE
- [ ] **Dashboard web**: monitorear una sesión en vivo desde el rol instructor
- [ ] **Correos**: registrar un usuario y verificar que recibe el correo de bienvenida (si configuraste Resend)
- [ ] **Pagos**: realizar una transacción de prueba en el entorno sandbox de Wompi (si aplica)

### 6.2. Prueba rápida de conexión

```bash
# Verificar que el servidor web responde
curl http://localhost:3000/api/health

# Verificar que Firebase está configurado
curl http://localhost:3000/api/auth/me
```

### 6.3. Logs y monitoreo

| Herramienta | Propósito |
|---|---|
| Firebase Console | Monitoreo de Auth, Firestore, RTDB, Functions |
| Vercel Dashboard | Logs de despliegue del dashboard web |
| Monitor Serie (Arduino) | Depuración del firmware ESP32 |
| Cloudflare Dashboard | Métricas del Worker de notificaciones |

---

*Documento generado el Julio 2026. Para la versión más reciente, consulta el repositorio oficial.*
