# SIERCP — Guía Completa de Conexión ESP-32

**Sistema de telemetría del maniquí de entrenamiento RCP**

---

## Tabla de Contenido

1. [Hardware Requerido](#1-hardware-requerido)
2. [Diagrama de Conexiones](#2-diagrama-de-conexiones)
3. [Instalación del Entorno Arduino IDE](#3-instalación-del-entorno-arduino-ide)
4. [Registrar el Maniquí en el Backend](#4-registrar-el-maniquí-en-el-backend)
5. [Código Completo Arduino (ESP-32)](#5-código-completo-arduino-esp-32)
6. [Configuración de Red Wi-Fi](#6-configuración-de-red-wi-fi)
7. [Verificar Datos Recibidos](#7-verificar-datos-recibidos)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Hardware Requerido

| Componente | Modelo Recomendado | Propósito |
|---|---|---|
| Microcontrolador | ESP-32 WROOM-32 / DevKitC | Procesamiento y Wi-Fi |
| Sensor de fuerza | FSR 402 / HX711 | Medir profundidad/fuerza de compresión |
| Sensor de ritmo | Pulsioxímetro MAX30102 | HR y SpO2 simulado |
| Cable USB | Micro-USB data cable | Programación y alimentación |
| Resistencias | 10kΩ x2 | Pull-down para FSR |
| Breadboard | 400+ pins | Montaje de circuito |

---

## 2. Diagrama de Conexiones

```
ESP-32 DevKitC
┌─────────────────────────────────────┐
│  3.3V ──── VCC (MAX30102)           │
│  GND  ──── GND (MAX30102 + FSR)     │
│  GPIO 21 ── SDA (MAX30102)          │
│  GPIO 22 ── SCL (MAX30102)          │
│                                     │
│  GPIO 34 ── OUT (FSR 402)           │
│            FSR 402 ─── 10kΩ ─── GND│
│                                     │
│  EN   ──── RESET                    │
│  USB  ──── Computador               │
└─────────────────────────────────────┘

MAX30102 (I2C)        FSR 402 (Analógico)
┌──────────┐          ┌──────────────┐
│ VCC 3.3V │          │ Pin 1 → 3.3V │
│ GND      │          │ Pin 2 → GPIO34│
│ SDA → 21 │          │        → 10kΩ → GND
│ SCL → 22 │          └──────────────┘
│ INT (NC) │
└──────────┘
```

---

## 3. Instalación del Entorno Arduino IDE

### Paso 1: Instalar Arduino IDE
1. Descargar Arduino IDE 2.x desde [arduino.cc](https://www.arduino.cc/en/software)
2. Instalar y abrir Arduino IDE

### Paso 2: Agregar soporte ESP-32
1. Ir a **Archivo → Preferencias**
2. En "URLs adicionales para el gestor de placas", agregar:
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
3. Ir a **Herramientas → Placa → Gestor de placas**
4. Buscar `esp32` e instalar "esp32 by Espressif Systems"

### Paso 3: Instalar Librerías Necesarias
Ir a **Herramientas → Administrar bibliotecas** e instalar:

| Librería | Autor | Versión |
|---|---|---|
| `ArduinoJson` | Benoit Blanchon | ≥ 6.x |
| `HTTPClient` | Arduino (incluida con ESP32) | — |
| `MAX30105` (o `SparkFun MAX3010x`) | SparkFun | ≥ 1.1.2 |
| `WiFi` | Arduino (incluida con ESP32) | — |

### Paso 4: Configurar la Placa
1. Ir a **Herramientas → Placa** → Seleccionar `ESP32 Dev Module`
2. Puerto: seleccionar el COM que aparece al conectar el ESP-32
3. Velocidad de carga: `115200`

---

## 4. Registrar el Maniquí en el Backend

Antes de cargar el código al ESP-32, registrar el dispositivo en el sistema usando la MAC Address del módulo Wi-Fi.

### Paso 1: Obtener la MAC Address del ESP-32

Cargar este sketch temporal:
```cpp
#include <WiFi.h>
void setup() {
  Serial.begin(115200);
  Serial.print("MAC Address: ");
  Serial.println(WiFi.macAddress());
}
void loop() {}
```

Abrir el **Monitor Serie** y copiar la dirección MAC (formato `AA:BB:CC:DD:EE:FF`).

### Paso 2: Registrar en el Backend

```bash
# Con el servidor Django corriendo, enviar POST como ADMIN:
curl -X POST http://localhost:8000/api/manikins/ \
  -H "Authorization: Bearer <TU_TOKEN_ADMIN>" \
  -H "Content-Type: application/json" \
  -d '{
    "nombre": "Maniquí RCP-01",
    "uuid": "AA:BB:CC:DD:EE:FF",
    "estado": "disponible",
    "ubicacion": "Laboratorio 3-A"
  }'
```

**Respuesta esperada:**
```json
{
  "id": 1,
  "nombre": "Maniquí RCP-01",
  "uuid": "AA:BB:CC:DD:EE:FF",
  "api_key": "siercp_key_7f8a...",
  "estado": "disponible"
}
```

> [!IMPORTANT]
> **Guarda la `api_key`**. Es necesaria para que el ESP-32 se autentique. Si la pierdes, puedes consultarla en la App Móvil (Vista de Administrador → Detalles del Maniquí).

---

## 5. Código Completo Arduino (ESP-32)

Guardar como `siercp_esp32.ino`:

```cpp
/**
 * SIERCP ESP-32 — Cliente IoT del Maniquí de RCP
 * ================================================
 * Envía datos de sensores al backend SIERCP cada segundo.
 * 
 * Configurar:
 *   - WIFI_SSID y WIFI_PASSWORD con tu red
 *   - SERVER_HOST con la IP del servidor Django
 *   - MANIQUI_UUID con la MAC Address del dispositivo (registrada en el backend)
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ─── CONFIGURACIÓN ────────────────────────────────────────────────────────────
const char* WIFI_SSID     = "TU_RED_WIFI";
const char* WIFI_PASSWORD = "TU_CONTRASEÑA";
const char* SERVER_HOST   = "http://192.168.1.100:8000";  // IP del PC con Django
const char* MANIQUI_UUID  = "AA:BB:CC:DD:EE:FF";          // MAC del ESP-32
const char* API_KEY       = "siercp_key_XXXXX";           // Obtener del backend
const int   INTERVAL_MS   = 1000;                          // Envío cada 1 segundo

// ─── PINES ────────────────────────────────────────────────────────────────────
const int FSR_PIN = 34;  // Pin analógico para sensor de fuerza

// ─── ESTADO GLOBAL ────────────────────────────────────────────────────────────
int    sesion_activa_id = -1;  // -1 = sin sesión
float  compressions_count = 0;
unsigned long last_send_ms = 0;

// ─── SETUP ────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("\n[SIERCP] Iniciando ESP-32...");

  // Conectar Wi-Fi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("[WiFi] Conectando");
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WiFi] Conectado!");
    Serial.print("[WiFi] IP local: ");
    Serial.println(WiFi.localIP());
    Serial.print("[WiFi] MAC Address: ");
    Serial.println(WiFi.macAddress());
  } else {
    Serial.println("\n[WiFi] ERROR: No se pudo conectar. Reiniciando...");
    ESP.restart();
  }

  pinMode(FSR_PIN, INPUT);
  Serial.println("[SIERCP] Listo. Enviando datos...");
}

// ─── LOOP ─────────────────────────────────────────────────────────────────────
void loop() {
  if (millis() - last_send_ms >= INTERVAL_MS) {
    last_send_ms = millis();

    if (WiFi.status() == WL_CONNECTED) {
      // Leer sensores
      float fsr_raw       = analogRead(FSR_PIN);
      float presion       = mapFloat(fsr_raw, 0, 4095, 0, 180); // mmHg estimado
      float ritmo         = simularRitmo();   // En producción: leer MAX30102
      float oxigeno       = simularSpO2();    // En producción: leer MAX30102
      float temperatura   = simularTemp();    // En producción: leer DS18B20

      // Enviar al backend
      enviarDatos(ritmo, oxigeno, presion, temperatura);
    } else {
      Serial.println("[WiFi] Desconectado. Reconectando...");
      WiFi.reconnect();
    }
  }
}

// ─── FUNCIÓN: Enviar datos al servidor ───────────────────────────────────────
void enviarDatos(float hr, float spo2, float presion, float temp) {
  HTTPClient http;
  String url = String(SERVER_HOST) + "/api/data/recibir/";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-API-Key", API_KEY); // SEGURIDAD OBLIGATORIA

  // Construir JSON
  StaticJsonDocument<256> doc;
  doc["maniqui_uuid"]  = MANIQUI_UUID;
  doc["ritmo_cardiaco"] = hr;
  doc["oxigeno"]        = spo2;
  doc["presion"]        = presion;
  doc["temperatura"]    = temp;
  
  // Añadir sesión si hay una activa
  if (sesion_activa_id > 0) {
    doc["sesion"] = sesion_activa_id;
  }

  String body;
  serializeJson(doc, body);

  Serial.print("[HTTP] POST → ");
  Serial.println(url);
  Serial.println("  Body: " + body);

  int httpCode = http.POST(body);
  
  if (httpCode > 0) {
    String response = http.getString();
    Serial.print("[HTTP] Response " + String(httpCode) + ": ");
    Serial.println(response);
    
    // Parsear respuesta para detectar nivel de alerta
    StaticJsonDocument<128> resp;
    if (deserializeJson(resp, response) == DeserializationError::Ok) {
      String nivel = resp["nivel"] | "normal";
      if (nivel == "critico") {
        Serial.println("[ALERTA] ⚠️  NIVEL CRÍTICO DETECTADO");
        // Aquí puedes encender un LED rojo, activar buzzer, etc.
      }
    }
  } else {
    Serial.print("[HTTP] ERROR: ");
    Serial.println(http.errorToString(httpCode));
  }

  http.end();
}

// ─── SIMULADORES (reemplazar con lectura real del sensor) ─────────────────────
float simularRitmo() {
  // Simula una señal cardíaca sinusoidal para testing
  static float t = 0;
  t += 0.1;
  return 75 + 15 * sin(t);
}

float simularSpO2() {
  return 96.5 + random(-5, 5) * 0.1;
}

float simularTemp() {
  return 36.5 + random(-2, 2) * 0.1;
}

float mapFloat(float x, float in_min, float in_max, float out_min, float out_max) {
  return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

// ─── FUNCIÓN OPCIONAL: Establecer sesión activa ───────────────────────────────
// Llamar desde loop() con el ID de sesión que el instructor inicia
void setSesionActiva(int id) {
  sesion_activa_id = id;
  Serial.print("[SIERCP] Sesión activa: #");
  Serial.println(id);
}
```

---

## 6. Configuración de Red Wi-Fi

### Para usar con Emulador Android (desarrollo)
```cpp
const char* SERVER_HOST = "http://10.0.2.2:8000";
```
> **Nota**: `10.0.2.2` es el alias del PC host desde el emulador Android.

### Para usar con Dispositivo Físico en red local
```cpp
// Obtener la IP local del PC con Django:
// Windows: ipconfig | buscar "IPv4"
// macOS/Linux: ifconfig | grep inet
const char* SERVER_HOST = "http://192.168.1.XXX:8000";
```

### Asegurarse que Django acepta conexiones externas
```bash
# Iniciar con 0.0.0.0 para aceptar todas las IPs
python manage.py runserver 0.0.0.0:8000

# Y en settings.py, agregar la IP del servidor a ALLOWED_HOSTS:
ALLOWED_HOSTS = ['localhost', '127.0.0.1', '192.168.1.XXX', '10.0.2.2']
```

---

## 7. Verificar Datos Recibidos

### Opción A: Panel de Admin Django
1. Abrir `http://localhost:8000/admin/`
2. Ir a **Datos del Sensor** → Verificar nuevas filas
3. Ir a **Alertas** → Verificar alertas generadas

### Opción B: Endpoint REST
```bash
# Autenticarse primero
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "tu_contraseña"}'

# Obtener últimas lecturas
curl http://localhost:8000/api/data/obtener/ \
  -H "Authorization: Bearer <ACCESS_TOKEN>"

# Obtener alertas
curl http://localhost:8000/api/alertas/ \
  -H "Authorization: Bearer <ACCESS_TOKEN>"
```

### Opción C: Monitor Serie Arduino IDE
Con el ESP-32 conectado, abrir el Monitor Serie a `115200 baud` para ver:
```
[SIERCP] Iniciando ESP-32...
[WiFi] Conectando....
[WiFi] Conectado!
[WiFi] IP local: 192.168.1.105
[HTTP] POST → http://192.168.1.100:8000/api/data/recibir/
  Body: {"maniqui_uuid":"AA:BB:CC:DD:EE:FF","ritmo_cardiaco":78.5,...}
[HTTP] Response 200: {"mensaje":"Datos guardados correctamente.","nivel":"normal"}
```

---

## 8. Troubleshooting

### ❌ Error: No se conecta al Wi-Fi
```
Verificar:
1. SSID y contraseña correctos en el código
2. Red 2.4 GHz (ESP-32 no soporta 5 GHz)
3. Router no tiene filtro MAC activado
4. El ESP-32 está dentro del rango del router
```

### ❌ Error: HTTP 404 o "Connection refused"
```
Verificar:
1. Django está corriendo con: python manage.py runserver 0.0.0.0:8000
2. La IP en SERVER_HOST es correcta (no usar 'localhost' desde ESP-32)
3. Firewall de Windows permite el puerto 8000:
   New-NetFirewallRule -DisplayName "Django Dev" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
```

### ❌ Error: HTTP 400 Bad Request
```
Verificar:
1. El MANIQUI_UUID existe en la base de datos (registrado en /api/manikins/)
2. El JSON enviado tiene todos los campos requeridos
3. Los valores son numéricos (no strings)
```

### ❌ Error: Maniquí no aparece en el backend
```
Verificar:
1. Registrar el maniquí primero con POST /api/manikins/ (requiere token ADMIN)
2. El UUID debe ser exactamente la MAC Address del ESP-32
3. Verificar en admin: Maniquíes → buscar por UUID
```

### ❌ ESP-32 se reinicia en bucle
```
Causas comunes:
1. Alimentación insuficiente: usar cable USB de datos (no de carga)
2. Exception: revisar Monitor Serie para ver el tipo de error
3. WatchDog Reset: agregar delay(10) en el loop
```

### 🔧 Verificar conexión rápida con CURL
```bash
# Simular un envío desde ESP-32 (sin autenticación)
curl -X POST http://localhost:8000/api/data/recibir/ \
  -H "Content-Type: application/json" \
  -H "X-API-Key: siercp_key_XXXXX" \
  -d '{
    "maniqui_uuid": "AA:BB:CC:DD:EE:FF",
    "ritmo_cardiaco": 45.0,
    "oxigeno": 88.0,
    "presion": 70.0,
    "temperatura": 36.5
  }'

# Respuesta esperada (nivel critico por ritmo y presion bajos):
{"mensaje":"Datos guardados correctamente.","nivel":"critico"}
```
