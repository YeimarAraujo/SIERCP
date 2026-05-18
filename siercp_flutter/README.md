# SIERCP — App Flutter
## Sistema Inteligente de Entrenamiento de Reanimación Cardiopulmonar

Aplicación móvil multiplataforma (iOS + Android) desarrollada en Flutter para el monitoreo,
entrenamiento y evaluación objetiva de la técnica de RCP según los estándares AHA 2025.

> [!IMPORTANT]
> Consulta el documento [ARCHITECTURE_MASTER.md](../ARCHITECTURE_MASTER.md) para detalles sobre la arquitectura modular, seguridad y modelo de negocio del ecosistema completo.

---

## Requisitos previos

| Herramienta | Versión mínima |
|---|---|
| Flutter SDK | 3.22+ |
| Dart | 3.0+ |
| Android Studio | Hedgehog+ (o VS Code con extensiones Flutter/Dart) |
| Xcode (solo macOS) | 15+ |
| Backend SIERCP (Next.js) | corriendo vía npm run dev |

---

## Instalación paso a paso

### 1. Clonar / ubicar el proyecto
```bash
cd siercp_flutter
```

### 2. Instalar dependencias
```bash
flutter pub get
```

### 3. Crear directorio de assets
```bash
mkdir -p assets/images assets/audio assets/fonts
```

### 4. Descargar fuentes (Space Mono)
Descarga desde [Google Fonts](https://fonts.google.com/specimen/Space+Mono) y coloca:
```
assets/fonts/SpaceMono-Regular.ttf
assets/fonts/SpaceMono-Bold.ttf
```

### 5. Configurar Variables de Entorno

Crea un archivo `config.json` en la raíz de `siercp_flutter`:
```json
{
  "RTDB_URL": "https://tu-proyecto.firebaseio.com"
}
```

> [!IMPORTANT]
> Nunca subas el archivo `config.json` al repositorio. Ya está incluido en el `.gitignore`.

### 6. Ejecutar la app
```bash
# Verificar dispositivos disponibles
flutter devices

# Ejecutar en emulador / dispositivo
flutter run

# Ejecutar en modo release
flutter run --release
```

---

## Estructura del proyecto

```
lib/
├── main.dart                    # Entry point · ProviderScope · MaterialApp.router
├── core/
│   ├── constants.dart           # URLs, constantes AHA, roles
│   ├── routes.dart              # go_router con guards de autenticación
│   └── theme.dart               # AppTheme · AppColors · ThemeData
├── models/
│   ├── user.dart                # UserModel · AuthTokens · UserStats
│   ├── session.dart             # SessionModel · SessionMetrics · CompressionReading · LiveSessionData
│   └── alert_course.dart        # AlertModel · ScenarioModel · CourseModel
├── services/
│   ├── api_service.dart         # Dio · interceptor JWT · refresh automático
│   ├── auth_service.dart        # Login · logout · getMe
│   ├── session_service.dart     # Sesiones · métricas · escenarios · cursos
│   └── websocket_service.dart   # WebSocket con reconexión automática
├── providers/
│   ├── auth_provider.dart       # AuthNotifier · authStateProvider · currentUserProvider
│   └── session_provider.dart    # activeSessionProvider · sessionsHistoryProvider · scenariosProvider
├── screens/
│   ├── splash_screen.dart       # Pantalla de inicio · verificación de token
│   ├── login_screen.dart        # Formulario · acceso demo por rol
│   ├── main_shell.dart          # Shell con NavigationBar · go_router
│   ├── home_screen.dart         # Dashboard · métricas del día · alertas · progreso
│   ├── session_screen.dart      # Sesión RCP live · WebSocket · métricas en tiempo real
│   ├── session_result_screen.dart # Resultado final · evaluación AHA · violaciones
│   ├── history_screen.dart      # Historial de sesiones · gráfica de progresión
│   ├── scenario_select_screen.dart # Selección de escenario clínico
│   ├── courses_screen.dart      # Cursos · escenarios · entregas
│   └── profile_screen.dart      # Perfil · estadísticas · configuración
└── widgets/
    ├── metric_card.dart         # MetricCard · AlertCard · SectionLabel (reutilizables)
    ├── compression_wave.dart    # Gráfica de señal de compresión (fl_chart)
    └── aha_status_bar.dart      # Barras de estado AHA en tiempo real
```

---

## Flujo de autenticación

```
App inicio
  └─► SplashScreen
        ├─ Token válido ──► HomeScreen (con rol)
        └─ Sin token   ──► LoginScreen
                                └─ Autenticación vía Firebase Auth
```

## Roles y vistas

| Rol | Acceso |
|---|---|
| `ESTUDIANTE` | Dashboard propio, sesiones, historial, cursos, perfil |
| `INSTRUCTOR` | Todo lo anterior + vista multi-estudiante, crear escenarios, calificar |
| `ADMIN` | Acceso total + gestión de usuarios y dispositivos |
| `DISPOSITIVO` | Solo envío de datos via token único (ESP32) |

---

## Parámetros AHA 2020 validados

| Parámetro | Rango correcto | Sensor |
|---|---|---|
| Profundidad adulto | 50 – 60 mm | VL53L1X |
| Frecuencia | 100 – 120 /min | Timestamps ESP32 |
| Pausa máxima | < 10 segundos | Backend |
| Descompresión | Retorno total (0 mm) | VL53L1X |
| Fuerza | ~40 – 60 kg | Celda de carga + ADS1115 |

---

## Build para producción

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Google Play)
flutter build appbundle --release

# iOS (requiere macOS + Xcode)
flutter build ios --release
```

---

Para manejar múltiples entornos, usa el archivo `config.json` y ejecútalo con:
```bash
flutter run --dart-define-from-file=config.json
```
O simplemente presiona **F5** en VS Code, ya que el archivo `.vscode/launch.json` ya está configurado.

---

## Dependencias principales

```yaml
go_router: ^13.0.0          # Navegación declarativa con guards
flutter_riverpod: ^2.5.1    # Gestión de estado reactivo
dio: ^5.4.3                 # HTTP client con interceptores
web_socket_channel: ^2.4.0  # WebSocket para datos en tiempo real
flutter_secure_storage: ^9.0.0  # Almacenamiento seguro de JWT
fl_chart: ^0.68.0           # Gráficas de compresión y progreso
google_fonts: ^6.2.1        # DM Sans
```

---

## Créditos
Proyecto SIERCP — IoT + Biomecánica + IA para entrenamiento de RCP  
Basado en las Guías AHA 2020 para reanimación cardiopulmonar.
