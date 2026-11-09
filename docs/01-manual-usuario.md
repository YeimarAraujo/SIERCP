# Manual de Usuario — SICAP

**Sistema Inteligente de Capacitación en Reanimación Cardiopulmonar**

Versión: 1.0 — Julio 2026

---

## Contenido

1. [Inicio de sesión](#1-inicio-de-sesion)
2. [Menú principal](#2-menu-principal)
3. [Gestión de estudiantes](#3-gestion-de-estudiantes)
4. [Gestión de docentes](#4-gestion-de-docentes)
5. [Gestión de programas](#5-gestion-de-programas)
6. [Reportes](#6-reportes)
7. [Preguntas frecuentes](#7-preguntas-frecuentes)
8. [Solución de problemas](#8-solucion-de-problemas)

---

## 1. Inicio de sesión

### 1.1. Acceder al sistema

**Objetivo:** Ingresar a la plataforma SICAP con credenciales institucionales.

**Requisitos previos:**
- Tener una cuenta activa creada por el administrador de tu institución
- Contar con conexión a internet
- Tener un navegador compatible (Chrome 90+, Firefox 90+, Edge 90+, Safari 15+)

**Pasos:**

1. Abre tu navegador e ingresa a la URL proporcionada por tu institución.
2. En la pantalla de inicio, presiona el botón **"Iniciar sesión"** ubicado en la esquina superior derecha.
3. Ingresa tu **correo electrónico** en el campo correspondiente.
4. Ingresa tu **contraseña** en el campo de contraseña. Puedes presionar el ícono del ojo para ver u ocultar la contraseña.
5. Presiona el botón **"Iniciar sesión"**.

**Resultado esperado:** Serás redirigido al dashboard correspondiente a tu rol (Estudiante, Instructor, Admin o Super Admin).

> **Nota:** Si es tu primer inicio de sesión, es posible que debas cambiar tu contraseña temporal. Sigue las instrucciones que aparecen en pantalla.

### 1.2. Restablecer contraseña

**Objetivo:** Recuperar el acceso a tu cuenta cuando olvidaste tu contraseña.

**Requisitos previos:** Tener acceso al correo electrónico registrado en la plataforma.

**Pasos:**

1. En la pantalla de inicio de sesión, presiona el enlace **"¿Olvidaste tu contraseña?"**.
2. Ingresa tu **correo electrónico** registrado.
3. Presiona **"Enviar enlace de recuperación"**.
4. Revisa tu bandeja de entrada. Recibirás un correo con un enlace para restablecer tu contraseña.
5. Abre el enlace e ingresa tu nueva contraseña.
6. Confirma la nueva contraseña y presiona **"Guardar"**.

**Resultado esperado:** Podrás iniciar sesión con tu nueva contraseña.

### 1.3. Cerrar sesión

**Objetivo:** Salir de la plataforma de forma segura.

**Pasos:**

1. En la esquina superior derecha, presiona tu **foto de perfil** o **ícono de usuario**.
2. Selecciona **"Cerrar sesión"** del menú desplegable.

**Resultado esperado:** Serás redirigido a la pantalla de inicio de sesión y tu sesión se cerrará completamente.

---

## 2. Menú principal

El menú principal varía según el rol del usuario. A continuación se describen las opciones disponibles para cada perfil.

### 2.1. Rol ESTUDIANTE

#### 2.1.1. Dashboard de inicio

Al iniciar sesión como estudiante, verás:

- **KPIS principales:** sesiones totales, puntuación promedio, mejor puntuación, cursos activos
- **Barra de XP:** Nivel de experiencia basado en sesiones completadas y puntuaciones
- **Actividad reciente:** Feed con las últimas sesiones realizadas y logros obtenidos
- **Cursos activos:** Tarjetas de cursos con progreso
- **Acceso rápido:** Botones para iniciar nueva sesión y ver cursos

#### 2.1.2. Navegación lateral (sidebar)

| Opción | Descripción |
|---|---|
| Inicio | Dashboard principal con métricas y actividad reciente |
| Cursos | Ver cursos inscritos y unirse a nuevos cursos |
| Historial | Consultar sesiones anteriores y progreso |
| Dispositivo | Estado y conexión del maniquí |
| Ranking | Tabla de posiciones con compañeros |
| Reportes | Descargar reportes de rendimiento |
| Perfil | Editar información personal y ver certificados |

### 2.2. Rol INSTRUCTOR

#### 2.2.1. Dashboard del instructor

Al iniciar sesión como instructor, verás:

- **KPIS:** estudiantes supervisados, calidad promedio, cumplimiento AHA, sesiones totales
- **Feed de sesiones recientes** de todos tus estudiantes
- **Tarjeta de consejo AHA 2025:** tips basados en las guías más recientes
- **Acciones rápidas:** crear curso, monitorear sesión activa, ver estudiantes

#### 2.2.2. Navegación lateral

| Opción | Descripción |
|---|---|
| Dashboard | Panel de control con métricas generales |
| Cursos | Crear, editar y gestionar cursos |
| Estudiantes | Lista de estudiantes, detalle y progreso |
| Monitoreo en vivo | Ver sesiones activas de estudiantes en tiempo real |
| Evaluaciones | Calificar sesiones y módulos |
| Historial | Consultar sesiones de todos los estudiantes |
| Reportes | Generar reportes por curso y estudiante |
| Perfil | Configuración de perfil |

### 2.3. Rol ADMIN

#### 2.3.1. Dashboard del admin

Al iniciar sesión como administrador, verás:

- **KPIS operativos:** dispositivos en línea, sesiones activas, instructores activos, estudiantes registrados
- **Feed de actividad** de toda la institución
- **Métricas operativas** con opción de exportación CSV

#### 2.3.2. Navegación lateral

| Opción | Descripción |
|---|---|
| Dashboard | Panel de control institucional |
| Usuarios | Gestión completa de usuarios (crear, editar, importar) |
| Dispositivos | Registrar y gestionar maniquíes |
| Cursos | Gestionar cursos y plantillas |
| Sesiones | Visión general de todas las sesiones |
| Sedes | Gestionar sedes/sucursales |
| Configuración | Ajustes de la institución y plan |
| Reportes | Reportes institucionales |
| Perfil | Configuración de perfil |

### 2.4. Rol SUPER ADMIN

#### 2.4.1. Dashboard global

- **KPIS globales:** instituciones, usuarios, cursos, sesiones, certificados
- **Gráficos:** tendencias mensuales, distribución de usuarios, MRR
- **Rankings:** mejores instituciones, mejores cursos
- **Alertas:** solicitudes pendientes de aprobación

#### 2.4.2. Navegación lateral

| Opción | Descripción |
|---|---|
| Dashboard | Panel global con analytics |
| Instituciones | Gestionar instituciones y aprobaciones |
| Usuarios | Gestión global de usuarios |
| Planes | Configurar planes y límites |
| Cursos | Gestión de cursos globales |
| Aprobaciones | Aprobar instituciones, admins e instructores |
| Logs | Registro de auditoría |
| Notificaciones | Enviar notificaciones masivas |
| Stock | Inventario de maniquíes |
| Pedidos | Órdenes de compra |

---

## 3. Gestión de estudiantes

### 3.1. Ver lista de estudiantes (INSTRUCTOR / ADMIN)

**Objetivo:** Consultar la lista de estudiantes registrados en la institución.

**Requisitos previos:** Tener rol INSTRUCTOR o ADMIN.

**Pasos:**

1. En el menú lateral, selecciona **"Estudiantes"** (INSTRUCTOR) o **"Usuarios"** (ADMIN).
2. La tabla muestra: nombre, correo, identificación, sesiones totales, puntuación promedio, cursos inscritos.
3. Usa el **buscador** para filtrar por nombre o correo.
4. Usa los **filtros** para ordenar por fecha de registro, puntuación o actividad.

**Resultado esperado:** Visualizarás la lista completa de estudiantes con sus métricas principales.

### 3.2. Agregar un estudiante (ADMIN)

**Objetivo:** Crear una nueva cuenta de estudiante en la plataforma.

**Requisitos previos:** Tener rol ADMIN.

**Pasos:**

1. Ve a **Admin → Usuarios**.
2. Presiona el botón **"Crear usuario"** o **"Agregar estudiante"**.
3. Completa el formulario con:
   - **Nombres y apellidos** completos
   - **Tipo de identificación** (CC, TI, CE, Pasaporte)
   - **Número de identificación**
   - **Correo electrónico**
   - **Teléfono** (opcional)
   - **Rol:** selecciona ESTUDIANTE
   - **Contraseña temporal**
   - **Sede** (si aplica)
4. Presiona **"Guardar"**.

**Resultado esperado:** El estudiante recibirá un correo electrónico con sus credenciales. Aparecerá en la lista de usuarios con estado ACTIVO.

### 3.3. Importar estudiantes masivamente (ADMIN)

**Objetivo:** Crear múltiples cuentas de estudiantes desde un archivo CSV.

**Requisitos previos:** Tener rol ADMIN. Tener un archivo CSV con los datos.

**Pasos:**

1. Ve a **Admin → Usuarios → Importar**.
2. Descarga la **plantilla CSV** presionando el botón de descarga.
3. Completa la plantilla con los datos de los estudiantes.
4. Presiona **"Subir archivo"** y selecciona tu CSV.
5. Revisa la vista previa con los datos detectados.
6. Presiona **"Confirmar importación"**.

**Resultado esperado:** Los estudiantes se crearán automáticamente. Recibirás un resumen con los resultados (creados, duplicados omitidos, errores).

### 3.4. Ver detalle de un estudiante

**Objetivo:** Consultar el progreso y rendimiento de un estudiante específico.

**Requisitos previos:** Tener rol INSTRUCTOR o ADMIN.

**Pasos:**

1. Ve a la lista de estudiantes.
2. Presiona el **nombre del estudiante** para abrir su detalle.
3. En la pantalla de detalle verás:
   - **Información personal** con datos de contacto
   - **Estadísticas:** sesiones totales, puntuación promedio, mejor puntuación, horas de entrenamiento
   - **Historial de sesiones:** lista cronológica con puntuaciones
   - **Progreso en cursos:** módulos completados, calificaciones
   - **Gráfica de progresión:** evolución de puntuaciones en el tiempo

**Resultado esperado:** Podrás evaluar el rendimiento del estudiante y detectar áreas de mejora.

### 3.5. Editar o desactivar un estudiante (ADMIN)

**Objetivo:** Modificar datos de un estudiante o desactivar su cuenta.

**Requisitos previos:** Tener rol ADMIN.

**Pasos:**

1. Ve al detalle del estudiante.
2. Presiona **"Editar"** para modificar: nombre, correo, teléfono, rol.
3. Para desactivar, presiona **"Desactivar cuenta"** y confirma.
4. Para activar una cuenta desactivada, presiona **"Activar cuenta"**.

**Resultado esperado:** Los cambios se guardan inmediatamente. Un estudiante desactivado no podrá iniciar sesión.

### 3.6. Inscribir estudiante en un curso (INSTRUCTOR / ADMIN)

**Objetivo:** Asignar un estudiante a un curso específico.

**Requisitos previos:** Tener el código de invitación del curso o ser ADMIN/INSTRUCTOR del curso.

**Pasos:**

1. Ve al **detalle del curso**.
2. Presiona la pestaña **"Estudiantes"**.
3. Presiona **"Agregar estudiante"**.
4. Busca al estudiante por nombre o correo.
5. Selecciona al estudiante de la lista.
6. Presiona **"Confirmar"**.

**Resultado esperado:** El estudiante aparecerá en la lista de inscritos del curso con acceso a los módulos.

---

## 4. Gestión de docentes

### 4.1. Ver lista de instructores (ADMIN)

**Objetivo:** Consultar los instructores registrados en la institución.

**Requisitos previos:** Tener rol ADMIN.

**Pasos:**

1. Ve a **Admin → Usuarios**.
2. Usa el filtro de rol y selecciona **"INSTRUCTOR"**.
3. La tabla mostrará: nombre, correo, estudiantes a cargo, cursos activos, última actividad.

**Resultado esperado:** Visualizarás todos los instructores con sus métricas.

### 4.2. Agregar un instructor (ADMIN / SUPER ADMIN)

**Objetivo:** Crear una cuenta de instructor en la plataforma.

**Requisitos previos:** Tener rol ADMIN o SUPER ADMIN.

**Pasos:**

1. Ve a **Admin → Usuarios → Crear usuario**.
2. Completa el formulario seleccionando rol **"INSTRUCTOR"**.
3. Ingresa los datos requeridos (nombre, correo, identificación, contraseña temporal).
4. Presiona **"Guardar"**.

**Resultado esperado:** El instructor se crea en estado **pendiente de aprobación**. Un ADMIN debe aprobarlo antes de que pueda acceder al sistema.

### 4.3. Aprobar instructor (ADMIN)

**Objetivo:** Activar la cuenta de un instructor pendiente.

**Requisitos previos:** Tener rol ADMIN.

**Pasos:**

1. Ve a la lista de usuarios.
2. Filtra por **estado "pendiente"** .
3. Localiza al instructor y presiona **"Aprobar"** .
4. Confirma la acción.

**Resultado esperado:** El instructor recibirá una notificación y podrá iniciar sesión con acceso completo a sus funciones.

### 4.4. Asignar estudiantes a un instructor

**Objetivo:** Vincular estudiantes a un instructor para supervisión.

**Requisitos previos:** Tener rol ADMIN.

**Pasos:**

1. Ve al **detalle del instructor**.
2. Presiona la pestaña **"Estudiantes asignados"** .
3. Presiona **"Asignar estudiante"** .
4. Busca y selecciona los estudiantes.
5. Presiona **"Guardar"** .

**Resultado esperado:** Los estudiantes aparecerán en el dashboard del instructor.

---

## 5. Gestión de programas

En SICAP, los programas equivalen a **cursos** que pueden ser de tipo legacy (código de invitación) o plataforma (plantillas con cohortes).

### 5.1. Crear un curso (INSTRUCTOR / ADMIN)

**Objetivo:** Crear un nuevo curso de entrenamiento RCP.

**Requisitos previos:** Tener rol INSTRUCTOR o ADMIN.

**Pasos:**

1. En el menú lateral, selecciona **"Cursos"** .
2. Presiona **"Crear curso"** .
3. Completa los campos del formulario:
   - **Título del curso**
   - **Descripción**
   - **Nivel:** básico / intermedio / avanzado
   - **Modalidad:** presencial / virtual / híbrida
   - **Duración estimada** en horas
   - **Instructor asignado** (solo ADMIN)
   - **Fecha de inicio y fin**
4. Presiona **"Guardar"** .

**Resultado esperado:** El curso se crea y se genera automáticamente un **código de invitación de 6 caracteres** y un **código QR** para compartir con los estudiantes.

### 5.2. Agregar módulos a un curso

**Objetivo:** Estructurar el contenido del curso en módulos.

**Requisitos previos:** Tener un curso creado. Ser INSTRUCTOR o ADMIN del curso.

**Pasos:**

1. Abre el **detalle del curso**.
2. Presiona la pestaña **"Módulos"** .
3. Presiona **"Agregar módulo"** .
4. Selecciona el **tipo de módulo**:

| Tipo | Descripción |
|---|---|
| Teoría | Contenido teórico con video o PDF |
| Evaluación teórica | Cuestionario con preguntas |
| Práctica guiada | Sesión RCP supervisada |
| Certificación | Evaluación final para certificar |

5. Completa: título, descripción, contenido (URL de video o PDF), tiempo estimado.
6. Para evaluaciones, agrega las preguntas con opciones y la respuesta correcta.
7. Define si el módulo es **obligatorio**.
8. Presiona **"Guardar"** .

**Resultado esperado:** El módulo aparece en la estructura del curso. Los estudiantes pueden verlo y completarlo.

### 5.3. Crear plantilla de curso (ADMIN)

**Objetivo:** Crear un curso reutilizable con cohortes automáticas.

**Requisitos previos:** Tener rol ADMIN.

**Pasos:**

1. Ve a **Admin → Cursos de plataforma** .
2. Presiona **"Nueva plantilla"** .
3. Configura:
   - **Título y descripción**
   - **Nivel y modalidad**
   - **Objetivos y requisitos**
   - **Módulos** (misma estructura que cursos legacy)
   - **Precio** en COP y USD
   - **Configuración de cohortes automáticas:** frecuencia de generación, capacidad máxima, fechas
4. Presiona **"Guardar plantilla"** .

**Resultado esperado:** La plantilla queda disponible. Las cohortes se generan automáticamente según la configuración.

### 5.4. Gestionar cohortes

**Objetivo:** Administrar las instancias de un curso plantilla.

**Requisitos previos:** Tener una plantilla de curso creada.

**Pasos:**

1. Ve al detalle de la plantilla de curso.
2. Presiona la pestaña **"Cohortes"** .
3. Verás las cohortes generadas con su estado:

| Estado | Significado |
|---|---|
| UPCOMING | Próxima a abrir |
| OPEN | Inscripciones abiertas |
| FULL | Capacidad máxima alcanzada |
| IN_PROGRESS | Clases en curso |
| CLOSED | Finalizada |
| COMPLETED | Finalizada y evaluada |

4. Presiona una cohorte para ver estudiantes inscritos, pagos y progreso.

### 5.5. Inscribir estudiantes con código de invitación

**Objetivo:** Que los estudiantes se inscriban a un curso usando un código.

**Requisitos previos:** Tener el código de invitación del curso (6 caracteres alfanuméricos).

**Pasos (para el estudiante):**

1. En el menú lateral, selecciona **"Cursos"** .
2. Presiona **"Unirse a curso"** .
3. Ingresa el **código de invitación** de 6 caracteres.
4. Presiona **"Confirmar"** .

**Resultado esperado:** El curso aparece en la lista de cursos del estudiante con acceso a todos los módulos.

---

## 6. Reportes

### 6.1. Reporte de rendimiento individual (ESTUDIANTE)

**Objetivo:** Consultar tu propio progreso y rendimiento en las sesiones RCP.

**Requisitos previos:** Tener al menos una sesión completada.

**Pasos:**

1. En el menú lateral, selecciona **"Historial"** .
2. Visualiza el resumen: total de sesiones, aprobadas, puntuación promedio.
3. Desplázate para ver la **lista de sesiones** ordenadas por fecha.
4. Presiona una sesión individual para ver:
   - **Puntuación total** (0-100)
   - **Estado:** APROBADO (≥70) / EXCELENTE (≥90) / NO APROBADO (<70)
   - **Desglose AHA:**
     - Profundidad (40% del peso)
     - Frecuencia (30% del peso)
     - Recoil (20% del peso)
     - Interrupciones (10% del peso)
   - **Violaciones** detectadas durante la sesión
5. Usa el **calendario** o los **filtros de fecha** para acotar la búsqueda.

**Resultado esperado:** Podrás identificar tendencias y áreas de mejora en tu técnica RCP.

### 6.2. Reporte por curso (INSTRUCTOR / ADMIN)

**Objetivo:** Obtener métricas agregadas de todos los estudiantes de un curso.

**Requisitos previos:** Tener rol INSTRUCTOR o ADMIN. Tener estudiantes inscritos en el curso.

**Pasos:**

1. Ve al **detalle del curso**.
2. Presiona la pestaña **"Reportes"** .
3. Verás:
   - **Puntuación promedio del curso**
   - **Tasa de aprobación** (% de estudiantes con ≥70)
   - **Distribución de puntuaciones** (gráfico de barras)
   - **Estudiantes con mejor y peor rendimiento**
   - **Sesiones por estudiante** (tabla detallada)
4. Presiona **"Exportar CSV"** para descargar los datos.

**Resultado esperado:** Podrás evaluar la efectividad del curso y detectar estudiantes que necesitan apoyo adicional.

### 6.3. Reporte institucional (ADMIN)

**Objetivo:** Obtener métricas operativas de toda la institución.

**Requisitos previos:** Tener rol ADMIN.

**Pasos:**

1. Ve a **Admin → Reportes**.
2. Selecciona el **tipo de reporte**:

| Reporte | Contenido |
|---|---|
| Métricas operativas | Dispositivos en línea, sesiones activas, usuarios por rol |
| Rendimiento general | Puntuaciones promedio por curso, tasas de aprobación |
| Uso de dispositivos | Horas de uso por maniquí, frecuencia de uso |
| Actividad diaria | Sesiones por día, usuarios activos |

3. Selecciona el **rango de fechas**.
4. Presiona **"Generar reporte"** .
5. Presiona **"Exportar CSV"** si necesitas el archivo.

**Resultado esperado:** Obtendrás una visión completa del estado operativo y académico de la institución.

### 6.4. Reportes globales (SUPER ADMIN)

**Objetivo:** Visualizar métricas de todas las instituciones en la plataforma.

**Requisitos previos:** Tener rol SUPER ADMIN.

**Pasos:**

1. Ve a **Super Admin → Dashboard**.
2. Los KPIS globales se muestran automáticamente:
   - Total de instituciones
   - Total de usuarios (desglosado por rol)
   - Total de cursos y sesiones
   - Ingresos mensuales (MRR)
3. En **"Instituciones"** puedes ver el detalle por institución.
4. En **"Logs"** puedes consultar el registro de auditoría completo.

**Resultado esperado:** Podrás tomar decisiones estratégicas basadas en datos globales.

---

## 7. Preguntas frecuentes

### 7.1. Generales

**¿Qué es SICAP?**

SICAP es un Sistema Inteligente de Capacitación en Reanimación Cardiopulmonar que combina maniquíes con sensores ESP32, una app móvil y un dashboard web para medir y mejorar la técnica RCP según estándares AHA 2025.

**¿Qué necesito para usar SICAP?**
- Un maniquí con ESP32 (proporcionado por tu institución)
- Un dispositivo móvil con Bluetooth (Android 8+ o iOS 15+)
- Credenciales de acceso proporcionadas por tu administrador
- Conexión a internet durante las sesiones

**¿Qué estándares AHA usa SICAP?**

SICAP implementa las guías AHA 2020/2025 con estos parámetros:
- Profundidad: 50-60 mm
- Frecuencia: 100-120 compresiones/minuto
- Pausa máxima: < 10 segundos
- Descompresión completa (recoil)
- Puntuación mínima aprobatoria: 70/100

**¿Cuánto cuesta SICAP?**

SICAP es una plataforma institucional. Los costos dependen del plan contratado por tu institución. Consulta con tu administrador para más información.

### 7.2. Cuenta y acceso

**¿Cómo obtengo mis credenciales?**

Las credenciales son creadas por el administrador de tu institución. Si eres nuevo, solicita tu cuenta al administrador.

**¿Puedo cambiar mi contraseña?**

Sí. En la pantalla de inicio de sesión, presiona "¿Olvidaste tu contraseña?" y sigue las instrucciones. También puedes cambiarla desde tu Perfil una vez autenticado.

**¿Por qué mi cuenta está desactivada?**

Las cuentas pueden ser desactivadas por el administrador de tu institución. Contacta a tu administrador para resolverlo.

**¿Puedo tener múltiples roles?**

No. Cada usuario tiene un único rol asignado por el administrador.

### 7.3. Sesiones RCP

**¿Cuánto dura una sesión de entrenamiento?**

No hay límite de duración. La sesión termina cuando presionas "Finalizar sesión". Se recomiendan sesiones de 2 minutos para evaluaciones estándar AHA.

**¿Puedo pausar una sesión?**

No. Las sesiones son continuas. Si necesitas detenerte, finaliza la sesión y comienza una nueva cuando estés listo.

**¿Qué significan los colores en las barras de métricas?**

- **Verde:** dentro del rango AHA óptimo
- **Amarillo:** cerca del límite, requiere atención
- **Rojo:** fuera del rango recomendado

**¿Qué pasa si pierdo conexión con el maniquí durante una sesión?**

La sesión continuará pero los datos pueden verse afectados. Reconecta el maniquí lo antes posible. Si la conexión no se restablece en 30 segundos, finaliza la sesión y verifica el dispositivo.

### 7.4. Dispositivos (maniquí)

**¿Cómo sé si el maniquí está correctamente conectado?**

El LED del maniquí indica el estado:
- **Parpadeo lento:** esperando conexión
- **Fijo encendido:** sesión activa
- **Apagado:** sin alimentación o desconectado

**¿Cuántos maniquíes puedo conectar a la vez?**

Cada dispositivo móvil puede conectarse a un maniquí a la vez. Un maniquí solo puede estar vinculado a una sesión activa.

**¿Cada cuánto debo calibrar el maniquí?**

El maniquí se calibra automáticamente al encenderse (primeros 2 segundos). Se recomienda una verificación manual mensual.

### 7.5. Pagos (solo para plataforma pública)

**¿Qué métodos de pago aceptan?**

Aceptamos tarjetas débito/crédito (CARD), transferencia bancaria (PSE) y NEQUI, procesados a través de Wompi.

**¿Cómo obtengo un reembolso?**

Los reembolsos deben gestionarse a través del administrador de tu institución o contactando a soporte.

**¿El pago incluye el maniquí?**

Depende del plan. Algunos planes incluyen el maniquí físico, otros solo el acceso a la plataforma. Consulta los detalles en tu plan.

---

## 8. Solución de problemas

### 8.1. Problemas de inicio de sesión

| Síntoma | Causa probable | Solución |
|---|---|---|
| "Credenciales inválidas" | Correo o contraseña incorrectos | Usa "¿Olvidaste tu contraseña?" o contacta al administrador |
| "Cuenta desactivada" | Administrador desactivó la cuenta | Contacta al administrador de tu institución |
| No se carga la página | Problema de conexión o navegador | Verifica internet, limpia caché, actualiza el navegador |
| La página redirige al login | Sesión expirada | Inicia sesión nuevamente |

### 8.2. Problemas con la app móvil

| Síntoma | Causa probable | Solución |
|---|---|---|
| No encuentra el maniquí | Bluetooth desactivado o maniquí no visible | Activa Bluetooth, acérca el móvil, reinicia el maniquí |
| La app se cierra | Versión desactualizada o caché dañada | Actualiza la app o reinstálala |
| Las métricas no se actualizan | Sesión no iniciada o desconexión | Verifica conexión BLE y reinicia la sesión |
| No recibe notificaciones | Permisos desactivados | Activa notificaciones en ajustes del dispositivo |

### 8.3. Problemas con el dashboard web

| Síntoma | Causa probable | Solución |
|---|---|---|
| Error 401 | Sesión expirada | Cierra sesión y vuelve a iniciar |
| Los datos no cargan | Error de conexión o Firebase | Refresca la página (F5), espera e intenta de nuevo |
| El monitor en vivo no muestra datos | Estudiante no ha iniciado sesión o maniquí desconectado | Verifica que el estudiante esté en sesión activa |

### 8.4. Problemas con el maniquí

| Síntoma | Causa probable | Solución |
|---|---|---|
| LED apagado | Sin alimentación | Verifica cable USB y fuente de poder |
| LED parpadea rápido | Error interno | Desconecta y reconecta; si persiste, actualiza firmware |
| Lecturas erráticas | Sensor sucio o superficie inestable | Limpia sensor VL53L0X, coloca en superficie firme |
| Compresiones no se contabilizan | Fuerza insuficiente o ritmo muy rápido | Aplica compresiones firmes y completas (>15 mm) |

---

*Documento generado el Julio 2026. Para la versión más reciente, consulta el repositorio oficial.*
