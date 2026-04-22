# SIERCP — Diagrama UML de Base de Datos

**Sistema Integrado de Evaluación y Retroalimentación de RCP**

---

## Diagrama Entidad-Relación (Mermaid)

```mermaid
erDiagram
    USER {
        int id PK
        string username
        string email
        string first_name
        string last_name
        string password_hash
        bool is_active
        bool is_superuser
        datetime date_joined
        datetime last_login
    }

    PERFIL {
        int id PK
        int user_id FK
        string rol
        string identificacion
    }

    CURSO {
        int id PK
        string nombre
        string descripcion
        int instructor_id FK
        string codigo
        datetime created_at
        datetime updated_at
    }

    MATRICULA {
        int id PK
        int estudiante_id FK
        int curso_id FK
        datetime fecha_inscripcion
    }

    CURSOSESION {
        int id PK
        int curso_id FK
        string titulo
        string descripcion
        string scenario_id
        datetime fecha_limite
        datetime created_at
    }

    MANIQUI {
        int id PK
        string nombre
        string uuid
        string estado
        string ubicacion
        datetime ultima_conexion
        datetime created_at
    }

    SESIONRCP {
        int id PK
        int estudiante_id FK
        int curso_id FK
        int maniqui_id FK
        string scenario_id
        string scenario_title
        string patient_type
        string status
        datetime started_at
        datetime ended_at
    }

    METRICARCP {
        int id PK
        int sesion_id FK
        int total_compressions
        float average_depth_mm
        float average_rate_per_min
        float correct_compressions_pct
        float average_force_kg
        int interruption_count
        float max_pause_seconds
        float score
        bool approved
    }

    SENSORDATA {
        int id PK
        int maniqui_id FK
        int sesion_id FK
        float ritmo_cardiaco
        float oxigeno
        float presion
        float temperatura
        datetime fecha
    }

    ALERTA {
        int id PK
        string mensaje
        string nivel
        int sesion_id FK
        datetime fecha
    }

    %% Relaciones
    USER ||--o| PERFIL : "tiene"
    USER ||--o{ CURSO : "dicta"
    USER ||--o{ MATRICULA : "inscrito en"
    USER ||--o{ SESIONRCP : "realiza"

    CURSO ||--o{ MATRICULA : "tiene inscritos"
    CURSO ||--o{ CURSOSESION : "asigna"
    CURSO ||--o{ SESIONRCP : "referencia"

    MANIQUI ||--o{ SESIONRCP : "usado en"
    MANIQUI ||--o{ SENSORDATA : "genera"

    SESIONRCP ||--o| METRICARCP : "tiene (1:1)"
    SESIONRCP ||--o{ SENSORDATA : "registra"
    SESIONRCP ||--o{ ALERTA : "genera"
```

---

## Diagrama de Clases UML (Mermaid)

```mermaid
classDiagram
    direction TB

    class User {
        +int id
        +string username
        +string email
        +string first_name
        +string last_name
        +bool is_active
        +bool is_superuser
    }

    class Perfil {
        +int id
        +string rol
        +string identificacion
        +__str__() string
    }

    class Curso {
        +int id
        +string nombre
        +string descripcion
        +string codigo
        +datetime created_at
        +save() void
        +__str__() string
    }

    class Matricula {
        +int id
        +datetime fecha_inscripcion
        +__str__() string
    }

    class CursoSesion {
        +int id
        +string titulo
        +string descripcion
        +string scenario_id
        +datetime fecha_limite
        +datetime created_at
        +__str__() string
    }

    class Maniqui {
        +int id
        +string nombre
        +string uuid
        +string estado
        +string ubicacion
        +datetime ultima_conexion
        +__str__() string
    }

    class SesionRCP {
        +int id
        +string scenario_id
        +string scenario_title
        +string patient_type
        +string status
        +datetime started_at
        +datetime ended_at
        +duration_seconds() float
        +__str__() string
    }

    class MetricaRCP {
        +int id
        +int total_compressions
        +float average_depth_mm
        +float average_rate_per_min
        +float correct_compressions_pct
        +float average_force_kg
        +int interruption_count
        +float max_pause_seconds
        +float score
        +bool approved
        +__str__() string
    }

    class SensorData {
        +int id
        +float ritmo_cardiaco
        +float oxigeno
        +float presion
        +float temperatura
        +datetime fecha
        +__str__() string
    }

    class Alerta {
        +int id
        +string mensaje
        +string nivel
        +datetime fecha
        +__str__() string
    }

    %% Herencia / Composición
    User "1" --o "0..1" Perfil : has profile
    User "1" --o "*" Curso : instructs
    User "1" --o "*" Matricula : enrolled
    User "1" --o "*" SesionRCP : performs

    Curso "1" --o "*" Matricula : has students
    Curso "1" --o "*" CursoSesion : assigns sessions
    Curso "1" --o "*" SesionRCP : contains

    Maniqui "1" --o "*" SesionRCP : used in
    Maniqui "1" --o "*" SensorData : generates

    SesionRCP "1" --o "0..1" MetricaRCP : evaluates
    SesionRCP "1" --o "*" SensorData : records
    SesionRCP "1" --o "*" Alerta : triggers
```

---

## Descripción de Relaciones

| Relación | Tipo | Descripción |
|---|---|---|
| `User → Perfil` | OneToOne | Cada usuario tiene exactamente un perfil |
| `User → Curso` | OneToMany | Un instructor puede tener muchos cursos |
| `User → Matricula` | OneToMany | Un estudiante puede estar en muchos cursos |
| `User → SesionRCP` | OneToMany | Un estudiante puede realizar muchas sesiones |
| `Curso → Matricula` | OneToMany | Un curso puede tener muchos estudiantes |
| `Curso → CursoSesion` | OneToMany | Un curso puede asignar muchas tareas |
| `Curso → SesionRCP` | OneToMany | Un curso puede tener muchas sesiones registradas |
| `Maniqui → SesionRCP` | OneToMany | Un maniquí puede ser usado en muchas sesiones |
| `Maniqui → SensorData` | OneToMany | Un maniquí genera muchas lecturas |
| `SesionRCP → MetricaRCP` | OneToOne | Cada sesión tiene exactamente una métrica |
| `SesionRCP → SensorData` | OneToMany | Una sesión puede tener muchas lecturas |
| `SesionRCP → Alerta` | OneToMany | Una sesión puede generar múltiples alertas |

---

## Restricciones de Integridad

| Modelo | Restricción | Descripción |
|---|---|---|
| `Perfil.identificacion` | `unique=True` | No dos usuarios con la misma cédula |
| `Maniqui.uuid` | `unique=True` | No dos maniquíes con el mismo UUID |
| `Curso.codigo` | `unique=True` | Código de curso único (6 chars alfanuméricos) |
| `Matricula` | `unique_together(estudiante, curso)` | Un estudiante no puede inscribirse dos veces al mismo curso |
| `MetricaRCP.sesion` | `OneToOne` | Solo una métrica por sesión |

---

## Índices Recomendados para PostgreSQL

```sql
-- Búsqueda de sesiones por estudiante
CREATE INDEX idx_sesion_estudiante ON api_sesionrcp (estudiante_id);

-- Búsqueda de sesiones por curso
CREATE INDEX idx_sesion_curso ON api_sesionrcp (curso_id);

-- Búsqueda de sensor data por fecha
CREATE INDEX idx_sensordata_fecha ON api_sensordata (fecha DESC);

-- Búsqueda de alertas por nivel
CREATE INDEX idx_alerta_nivel ON api_alerta (nivel);

-- Búsqueda de maniquí por UUID (ya tiene unique, que crea index automático)
-- Búsqueda de perfil por identificacion (ya tiene unique)
```
