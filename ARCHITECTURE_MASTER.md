# SIERCP - Ecosistema de Entrenamiento RCP Inteligente
## Documento Maestro de Arquitectura y Definición de Proyecto

### 1. Definición del Proyecto
**SIERCP** (Sistema Inteligente de Entrenamiento de Reanimación Cardiopulmonar) es una solución integral (Software + Hardware + Cloud) diseñada para transformar el entrenamiento médico. Utiliza telemetría en tiempo real capturada por sensores IoT para evaluar la calidad de las compresiones torácicas según las guías internacionales (AHA 2020/2025).

---

### 2. Arquitectura del Sistema

#### 2.1. Backend & Cloud (Firebase + Next.js API)
- **Base de Datos Principal**: Google Firestore (NoSQL) para perfiles, cursos y registros históricos.
- **Base de Datos en Tiempo Real**: Firebase Realtime Database (RTDB) para la telemetría de baja latencia (latidos por minuto, profundidad).
- **Autenticación**: Firebase Auth con JWT.
- **API Middleware**: Next.js API Routes para procesos sensibles (pagos, inscripciones, reportes pesados) con:
  - **Rate Limiting**: 60 peticiones/min para prevenir ataques DoS.
  - **CORS**: Restricción de origen para proteger el acceso al backend.
  - **Input Sanitization**: Limpieza de datos contra inyecciones SQL/NoSQL.

#### 2.2. Frontend Web (Next.js 16+)
- **Tecnologías**: React, TypeScript, Tailwind CSS, Zustand (Estado ligero).
- **Módulos**:
  - **Admin Dashboard**: Gestión de instituciones, usuarios y analíticas globales.
  - **Learning Management System (LMS)**: Visualización de cursos y progreso teórico.
  - **Pasarela de Pagos**: Integración con Stripe/MercadoPago para inscripciones.

#### 2.3. Aplicación Móvil (Flutter 3.22+)
- **Estado**: **Riverpod** (Arquitectura robusta, testable y reactiva).
- **Navegación**: **GoRouter** con soporte nativo para Deep Linking.
- **Seguridad**: **Flutter Secure Storage** para tokens y **InputSanitizer** para validación local.
- **Offline-First**: Caché local con SQLite (Sqflite) para entrenamientos en zonas sin cobertura.

#### 2.4. Hardware (IoT - ESP32)
- **Conectividad**: Dual (Wi-Fi para RTDB directa / Bluetooth Low Energy para App móvil).
- **Sensores**: VL53L1X (Tiempo de Vuelo) para profundidad milimétrica y Celdas de Carga para presión.

---

### 3. Metodología de Desarrollo
El proyecto utiliza una metodología **Feature-First (Modular)**:
- Cada funcionalidad (Autenticación, Sesión, Reportes) es un módulo independiente.
- Esto permite que un cambio en el módulo de pagos no afecte el motor de telemetría en la App.
- **CI/CD**: Despliegue automático a Firebase Hosting y Play Store/App Store.

---

### 4. Seguridad de Grado Clínico
1. **RLS (Row Level Security)**: Las reglas de Firestore garantizan que un estudiante X jamás pueda leer los resultados del estudiante Y.
2. **Encripción SSL/TLS**: Toda la comunicación (Web/App/Hardware) viaja bajo canales encriptados de extremo a extremo.
3. **Data Sanitization**: Evitamos que caracteres maliciosos lleguen a la base de datos o se ejecuten en el cliente (XSS).

---

### 5. Definición del Modelo de Negocio (SaaS + Hardware)

#### 5.1. Target Market
- **B2B**: Universidades de medicina, Centros de entrenamiento, Hospitales, Aseguradoras.
- **B2C**: Estudiantes de salud y paramédicos independientes.

#### 5.2. Estrategia de Monetización
- **Suscripción Institucional**: Pago mensual por número de estudiantes y estaciones de entrenamiento.
- **Certificación por Pago**: Venta de acceso a cursos específicos con certificación digital automática.
- **Venta/Leasing de Hardware**: Venta del kit de sensores SIERCP para retrofit de maniquíes existentes.

---

### 6. Viabilidad y Rentabilidad (Cálculos)

| Concepto | Estimado SIERCP | Competencia (Laerdal/SimMan) |
|---|---|---|
| **Costo Maniquí Inteligente** | ~$150 USD (Retrofit Kit) | ~$3,000 - $8,000 USD |
| **Escalabilidad** | Alta (Cloud SaaS) | Baja (Hardware propietario cerrado) |
| **Mantenimiento** | Bajo (Actualizaciones OTA) | Alto (Requiere técnicos in-situ) |

**Análisis de Rentabilidad**: 
Con un costo de producción de hardware de $80 USD y una suscripción anual de $500 USD por institución, el **ROI** se alcanza en el primer trimestre con solo 5 clientes activos. La escalabilidad es masiva al ser una plataforma basada en la nube.

---

### 7. Glosario Tecnológico
- **Riverpod**: Motor de inyección de dependencias y estado para Flutter que elimina los errores de tiempo de ejecución.
- **Zustand**: Gestor de estado ultra ligero para la web que mejora el rendimiento de renderizado.
- **Firestore RLS**: Motor de lógica en la base de datos para cumplimiento de leyes de privacidad de datos médicos (HIPAA compliance).
- **Rate Limiting**: Estratégia de protección para asegurar que los servidores siempre estén disponibles bajo alta demanda.
