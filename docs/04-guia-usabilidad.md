# Guía de Usabilidad — SICAP

**Sistema Inteligente de Capacitación en Reanimación Cardiopulmonar**

Versión: 1.0 — Julio 2026

---

## Contenido

1. [Objetivos](#1-objetivos)
2. [Principios de diseño](#2-principios-de-diseno)
3. [Consistencia](#3-consistencia)
4. [Accesibilidad](#4-accesibilidad)
5. [Flujo de navegación](#5-flujo-de-navegacion)
6. [Validaciones](#6-validaciones)
7. [Mensajes de error](#7-mensajes-de-error)
8. [Buenas prácticas](#8-buenas-practicas)

---

## 1. Objetivos

### 1.1. Objetivos de usabilidad del sistema

La documentación de usabilidad de SICAP persigue los siguientes objetivos:

| Objetivo | Descripción | Métrica |
|---|---|---|
| **Eficiencia** | El usuario debe completar tareas comunes en menos de 3 pasos desde el dashboard | Tiempo promedio por tarea < 30 segundos |
| **Efectividad** | El usuario debe poder completar las tareas sin asistencia externa | Tasa de éxito ≥ 95% en tareas core |
| **Satisfacción** | La experiencia de uso debe ser intuitiva y agradable | NPS ≥ 40 (encuestas post-uso) |
| **Aprendizaje** | Un usuario nuevo debe poder realizar una sesión RCP sin leer el manual | Tiempo hasta primera sesión < 5 minutos |
| **Seguridad** | El usuario debe poder recuperarse de errores sin pérdida de datos | Tasa de recuperación ≥ 99% |

### 1.2. Público objetivo

| Perfil | Nivel técnico | Frecuencia de uso | Dispositivo principal |
|---|---|---|---|
| Estudiante (ESTUDIANTE) | Bajo | Diaria/semanal | Móvil (app) |
| Instructor (INSTRUCTOR) | Medio | Diaria | Web + Móvil |
| Administrador (ADMIN) | Medio-alto | Semanal | Web |
| Super Admin (SUPER_ADMIN) | Alto | Semanal/mensual | Web |
| Técnico de hardware | Alto | Ocasional | Móvil + firmware |

---

## 2. Principios de diseño

### 2.1. Principios generales

#### Claridad ante todo
Cada pantalla debe comunicar su propósito en menos de 3 segundos. La información más importante debe estar visible sin necesidad de scroll.

#### Consistencia multiplataforma
La app móvil y el dashboard web deben compartir:
- Misma nomenclatura para roles, acciones y métricas
- Mismos códigos de color (verde = correcto, rojo = alerta)
- Mismas iconografías para acciones equivalentes

#### Progresión natural
El flujo de navegación debe seguir la secuencia mental del usuario:
1. **Ver estado actual** (dashboard)
2. **Elegir acción** (menú/botones)
3. **Ejecutar tarea** (formulario/sesión)
4. **Confirmar resultado** (feedback visual)

#### Feedback inmediato
Toda acción del usuario debe tener una respuesta visual o textual en menos de 500 ms:
- Botón presionado → cambio de estado visible
- Formulario enviado → indicador de carga
- Error → mensaje explicativo

### 2.2. Principios específicos por plataforma

#### App móvil (Flutter)
- **Diseño táctil**: botones mínimos de 48x48 dp, espaciado generoso
- **Una mano**: las acciones principales deben estar en la mitad inferior de la pantalla
- **Modo offline**: la app debe funcionar sin conexión para tareas básicas (ver historial, configurar perfil)

#### Dashboard web (Next.js)
- **Diseño responsive**: la interfaz debe funcionar desde 320px hasta 1920px
- **Atajos de teclado**: Ctrl+Enter para enviar formularios, Escape para cerrar modales
- **Carga progresiva**: primero el esqueleto (skeleton loading), luego los datos

---

## 3. Consistencia

### 3.1. Consistencia visual

#### Paleta de colores

| Color | Uso | Hex |
|---|---|---|
| Primario | Botones principales, enlaces, header | `#1E40AF` (azul) |
| Secundario | Acentos, badges, tabs activos | `#3B82F6` (azul claro) |
| Éxito | Métricas correctas, aprobado | `#10B981` (verde) |
| Advertencia | Límites cercanos, pendiente | `#F59E0B` (amarillo) |
| Error | Violaciones, no aprobado, errores | `#EF4444` (rojo) |
| Neutro | Fondos, texto secundario, bordes | `#6B7280` (gris) |

#### Tipografía
- **Web**: DM Sans (google_fonts) con tamaños: 12px (label), 14px (body), 16px (h3), 20px (h2), 24px+ (h1)
- **App**: Space Mono (monoespaceada) para métricas en tiempo real, DM Sans para el resto
- **Jerarquía visual**: un solo salto de tamaño entre niveles (ej. 14px → 16px → 20px)

#### Iconografía
- Usar un solo set de iconos (Lucide para web, Material Icons para app)
- Los iconos deben tener label textual acompañante (nunca solo icono)
- Tamaño consistente: 20x20px en navegación, 24x24px en acciones

### 3.2. Consistencia funcional

#### Nomenclatura de roles

| Sistema | App Móvil | Dashboard Web |
|---|---|---|
| ESTUDIANTE | Estudiante | Estudiante |
| INSTRUCTOR | Instructor | Instructor |
| ADMIN | Administrador | Admin |
| SUPER_ADMIN | Super Admin | Super Admin |

#### Nomenclatura de acciones

| Acción | App Móvil | Dashboard Web |
|---|---|---|
| Iniciar sesión | Iniciar sesión | Iniciar sesión |
| Finalizar sesión RCP | Finalizar | Finalizar sesión |
| Ver historial | Historial | Historial |
| Crear curso | — (no disponible) | Crear curso |
| Conectar dispositivo | Conectar | Vincular |

### 3.3. Consistencia de datos

- Las métricas AHA usan las mismas unidades en ambas plataformas (mm, kg, comp/min)
- Las fechas siguen el formato `DD/MM/AAAA` (configuración regional Colombia)
- Los valores monetarios usan formato `$XX.XXX` COP con separador de miles

---

## 4. Accesibilidad

### 4.1. Estándares

SICAP se adhiere a las pautas **WCAG 2.1 Nivel AA** como mínimo.

### 4.2. Requisitos de accesibilidad

#### Contraste de color
- Texto normal: relación de contraste ≥ 4.5:1
- Texto grande (≥18px bold o ≥24px): relación ≥ 3:1
- Componentes UI (botones, inputs): relación ≥ 3:1

#### Navegación por teclado
- Todos los elementos interactivos deben ser accesibles por teclado (Tab, Enter, Escape)
- El orden de tabulación debe seguir el orden visual
- Indicador de foco visible (outline 2px) en todos los elementos

#### Texto alternativo
- Todas las imágenes informativas deben tener `alt` descriptivo
- Los iconos decorativos deben tener `aria-hidden="true"`
- Las gráficas de datos deben tener una tabla o texto alternativo con los valores

#### Lectura de pantalla
- Los encabezados deben seguir una jerarquía semántica (h1 → h2 → h3, sin saltos)
- Los formularios deben tener etiquetas `<label>` asociadas a cada campo
- Los mensajes de error deben estar asociados al campo mediante `aria-describedby`
- Los botones deben tener texto descriptivo (evitar "Click aquí")

#### Tamaño de fuente
- El texto debe poder ampliarse al 200% sin pérdida de funcionalidad
- No usar unidades fijas (px) para texto, usar rem/em

### 4.3. Validación de accesibilidad

Antes de cada release, verificar:

- [ ] **Lighthouse Audit** → puntuación ≥ 90 en accesibilidad
- [ ] **axe DevTools** → 0 violaciones críticas
- [ ] **Navegación por teclado** → todas las rutas principales navegables sin mouse
- [ ] **Zoom al 200%** → sin pérdida de contenido ni funcionalidad
- [ ] **Contraste** → todas las combinaciones de color pasan relación 4.5:1

---

## 5. Flujo de navegación

### 5.1. Mapa de navegación general

```
Landing (público)
  │
  └── Login
        │
        ├── ESTUDIANTE ──┬── Dashboard (Inicio)
        │                 ├── Cursos
        │                 ├── Sesión RCP (conectar maniquí → entrenar → resultado)
        │                 ├── Historial
        │                 ├── Ranking
        │                 └── Perfil
        │
        ├── INSTRUCTOR ──┬── Dashboard
        │                 ├── Cursos (crear, editar, gestionar)
        │                 ├── Estudiantes (lista, detalle, progreso)
        │                 ├── Monitoreo en vivo
        │                 ├── Evaluaciones
        │                 └── Reportes
        │
        ├── ADMIN ───────┬── Dashboard
        │                 ├── Usuarios (CRUD + importación)
        │                 ├── Dispositivos
        │                 ├── Cursos (legacy + plataforma)
        │                 ├── Sedes
        │                 ├── Reportes
        │                 └── Configuración
        │
        └── SUPER_ADMIN ─┬── Dashboard global
                          ├── Instituciones
                          ├── Usuarios globales
                          ├── Planes
                          ├── Aprobaciones
                          ├── Logs
                          └── Pedidos/Stock
```

### 5.2. Flujo de sesión RCP (tarea crítica)

```
Dashboard ESTUDIANTE
  │
  ├── [1] Presionar "Conectar dispositivo"
  │      └── Escanear BLE → Seleccionar maniquí → Conectado (LED verde)
  │
  ├── [2] Presionar "Iniciar sesión"
  │      └── Temporizador iniciado → Métricas en 0
  │
  ├── [3] Realizar compresiones
  │      └── Métricas en vivo: profundidad, frecuencia, fuerza, recoil
  │      └── Barras de colores: verde/amarillo/rojo
  │      └── Gráfica de onda en movimiento
  │
  ├── [4] Presionar "Finalizar sesión"
  │      └── Confirmación: "¿Deseas finalizar la sesión?"
  │
  └── [5] Ver resultados
         └── Puntuación total
         └── Desglose AHA
         └── Violaciones
         └── Botones: "Nueva sesión" / "Ver historial"
```

### 5.3. Flujo de creación de curso (ADMIN/INSTRUCTOR)

```
Dashboard → Cursos → Crear curso
  │
  ├── [1] Completar formulario: título, descripción, nivel, modalidad
  ├── [2] Agregar módulos (teoría, evaluación, práctica, certificación)
  ├── [3] Guardar curso
  │
  └── [4] Compartir código de invitación (6 caracteres + QR)
         └── Los estudiantes se inscriben desde "Unirse a curso"
```

### 5.4. Reglas de navegación

| Regla | Descripción |
|---|---|
| Breadcrumbs | Siempre visibles en páginas internas (excepto dashboard) |
| Botón de retroceso | En formularios multi-paso, siempre visible |
| Confirmación de salida | Si hay datos sin guardar, preguntar antes de salir |
| Carga de datos | Mostrar skeleton loading (no spinner genérico) |
| Estado vacío | Mostrar ilustración + mensaje + acción sugerida ("No hay sesiones aún. ¡Comienza tu primera sesión!") |

---

## 6. Validaciones

### 6.1. Validación de formularios

| Campo | Validación | Mensaje de error |
|---|---|---|
| Correo electrónico | Formato email válido, no duplicado | "Ingresa un correo electrónico válido" |
| Contraseña | Mín. 8 caracteres, 1 mayúscula, 1 número | "La contraseña debe tener al menos 8 caracteres, una mayúscula y un número" |
| Nombre completo | Mín. 3 caracteres, solo letras | "Ingresa un nombre válido (mín. 3 caracteres)" |
| Identificación | Según tipo (CC: 6-10 dígitos, TI: 6-12 dígitos) | "El número de identificación no es válido" |
| Teléfono | 10 dígitos (Colombia) | "Ingresa un número de teléfono válido de 10 dígitos" |
| Código de invitación | 6 caracteres alfanuméricos | "El código de invitación debe tener 6 caracteres" |
| Profundidad AHA | 0-100 mm | "La profundidad debe estar entre 0 y 100 mm" |

### 6.2. Validación en tiempo real

- Los campos deben validarse **al perder el foco** (onBlur), no al escribir
- La contraseña debe mostrar indicador de fortaleza **mientras se escribe** (débil/media/fuerte)
- Los formularios extensos deben tener **validación al enviar** además de la validación por campo
- Los códigos de invitación deben validarse contra Firestore para verificar que existen

### 6.3. Validación de negocio

| Regla | Validación | Acción |
|---|---|---|
| Límite de estudiantes por plan | Verificar contador vs plan | Bloquear creación si se excede |
| Dispositivo en uso | Verificar estado en RTDB | Mostrar "Maniquí en uso por [usuario]" |
| Sesión duplicada | Verificar sesión activa del estudiante | "Ya tienes una sesión activa. ¿Deseas finalizarla primero?" |
| Cohorte llena | Verificar enrolledCount vs maxStudents | "La cohorte ha alcanzado su capacidad máxima" |

---

## 7. Mensajes de error

### 7.1. Categorías de mensajes

| Categoría | Estilo | Icono | Duración |
|---|---|---|---|
| Éxito | Verde | ✓ | 5 segundos o hasta cerrar |
| Información | Azul | ℹ | Hasta cerrar |
| Advertencia | Amarillo | ⚠ | Hasta cerrar |
| Error | Rojo | ✕ | Hasta cerrar |
| Error crítico | Rojo + modal | ✕ | Hasta interacción |

### 7.2. Mensajes de error comunes

#### Autenticación

| Código | Mensaje para el usuario | Acción sugerida |
|---|---|---|
| `auth/user-not-found` | "No encontramos una cuenta con este correo" | "Verifica el correo o crea una cuenta" |
| `auth/wrong-password` | "Contraseña incorrecta" | "Usa '¿Olvidaste tu contraseña?' para restablecerla" |
| `auth/too-many-requests` | "Demasiados intentos. Cuenta temporalmente bloqueada" | "Espera 30 segundos e intenta de nuevo" |
| `auth/email-already-in-use` | "Este correo ya está registrado" | "Inicia sesión o usa '¿Olvidaste tu contraseña?'" |
| `auth/user-disabled` | "Tu cuenta ha sido desactivada" | "Contacta al administrador de tu institución" |

#### Sesión RCP

| Situación | Mensaje | Acción sugerida |
|---|---|---|
| Maniquí desconectado durante sesión | "Conexión con el maniquí perdida. Intentando reconectar..." | "Acerca el móvil al maniquí y verifica que esté encendido" |
| Sin maniquí conectado | "No hay ningún dispositivo conectado" | "Presiona 'Conectar dispositivo' para vincular un maniquí" |
| Sesión muy corta (< 30 seg) | "La sesión fue muy corta para generar métricas significativas" | "Realiza una sesión de al menos 30 segundos para obtener resultados" |

#### Red y datos

| Situación | Mensaje | Acción sugerida |
|---|---|---|
| Sin conexión a internet | "No hay conexión a internet. Algunas funciones pueden no estar disponibles" | "Verifica tu conexión e intenta de nuevo" |
| Error al cargar datos | "No pudimos cargar los datos. Intenta de nuevo" | "Refresca la página o contacta a soporte si el problema persiste" |
| Timeout de Firebase | "El servidor está tardando más de lo esperado" | "Espera unos segundos y vuelve a intentar" |

### 7.3. Principios para mensajes de error

1. **Qué pasó**: explicación clara en lenguaje de usuario (no técnico)
2. **Por qué pasó**: causa probable
3. **Qué hacer**: acción concreta que el usuario puede tomar
4. **Dónde ir**: enlace a ayuda o soporte si aplica

> **Ejemplo:** ❌ "Error 401: Token inválido"
> ✅ "Tu sesión ha expirado por seguridad. Inicia sesión nuevamente para continuar."

---

## 8. Buenas prácticas

### 8.1. Diseño de formularios

- Un solo campo por línea en móvil, máximo 2 columnas en web
- Los campos opcionales deben marcarse como "(opcional)" — no usar asteriscos
- Los botones de acción deben estar alineados a la derecha o al final del formulario
- El botón primario debe ser el primero en el orden de tabulación
- En formularios de más de 5 campos, agrupar por secciones con títulos

### 8.2. Diseño de tablas

- Siempre incluir búsqueda y filtros en tablas con más de 10 filas
- Permitir ordenamiento por columnas haciendo clic en el encabezado
- Mostrar máximo 25 filas por página con paginación
- Las filas deben tener hover effect para indicar interactividad
- Incluir checkbox para selección múltiple cuando aplique

### 8.3. Manejo de estados

Cada componente debe considerar 4 estados:

| Estado | Descripción | Ejemplo |
|---|---|---|
| **Loading** | Datos cargando | Skeleton cards, spinner sutil |
| **Empty** | Sin datos | Ilustración + mensaje + CTA |
| **Error** | Error al cargar | Mensaje + botón reintentar |
| **Success** | Datos disponibles | Contenido normal |

### 8.4. Performance percibida

| Técnica | Descripción |
|---|---|
| Skeleton loading | Mostrar estructura vacía mientras cargan datos (no spinner) |
| Optimistic UI | Actualizar la UI antes de la respuesta del servidor y revertir si falla |
| Lazy loading | Cargar imágenes y componentes fuera de la pantalla solo cuando sean visibles |
| Paginación infinita | En listas largas, cargar más datos al hacer scroll |
| Caché local | Almacenar datos consultados recientemente para evitar llamadas repetidas |

### 8.5. Mobile first

- Diseñar primero para pantallas de 375px, luego expandir
- Los menús de navegación deben colapsarse en un hamburger menu en móvil
- Las tablas extensas deben convertirse en cards o listas en móvil
- Los botones deben ser fáciles de presionar con el pulgar (zona de alcance natural)

### 8.6. Pruebas de usabilidad

| Frecuencia | Tipo | Participantes |
|---|---|---|
| Semanal | Pruebas internas con equipo de desarrollo | 3-5 |
| Mensual | Pruebas con usuarios reales (estudiantes e instructores) | 5-8 |
| Por release | Pruebas de accesibilidad (Lighthouse + axe) | Automatizado |
| Trimestral | Pruebas de campo (sesiones reales con maniquíes) | 10+ |

---

*Documento generado el Julio 2026. Para la versión más reciente, consulta el repositorio oficial.*
