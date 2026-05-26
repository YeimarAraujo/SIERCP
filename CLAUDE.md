# SIERCP — Sistema de Entrenamiento en RCP

## Descripción del proyecto
Plataforma multi-tenant de entrenamiento en Reanimación Cardiopulmonar (RCP) con dispositivos Bluetooth (maniquíes), evaluaciones, certificaciones y gestión de organizaciones. Stack: **Flutter + Riverpod + Firebase (Firestore/Auth/Storage) + GoRouter**.

---

## Arquitectura

```
siercp_flutter/lib/
├── core/
│   ├── constants/constants.dart      ← AppConstants (roles, colecciones)
│   ├── models/                       ← institution.dart, membership.dart, support_ticket.dart
│   ├── providers/org_context_provider.dart   ← OrgContextState (activeOrgId, hasOrg)
│   ├── routes.dart                   ← GoRouter con guards de auth, org y rol
│   ├── services/
│   │   ├── firestore_service.dart    ← CRUD genérico Firestore
│   │   └── tenant_service.dart       ← Queries filtradas por institutionId
│   └── theme/theme.dart              ← AppColors, AppRadius
├── features/
│   ├── auth/                         ← Login, Register, RegisterInstitution
│   ├── super_admin/                  ← Dashboard, Support, Certificates, Users global
│   ├── org/                          ← NoOrgScreen, OrgSwitcher
│   ├── users/                        ← ManageUsers, CreateUser, Profile, InstructorApply
│   ├── courses/                      ← Cursos, editor, módulos, quiz
│   ├── session/                      ← Sesiones BLE con maniquí
│   ├── devices/                      ← Maniquíes (manikins)
│   └── notifications/                ← Sistema de notificaciones
```

---

## Roles del Sistema

### SUPER_ADMIN (Jomar Segurid)
- **Acceso absoluto** a todo el software, sin restricción de organización.
- No pertenece a ninguna org (ni necesita hacerlo).
- **Responsabilidades**: Gestión global de orgs/usuarios, aprobación de certificados SST y licencias profesionales, atención de soporte/dudas/contactos, configuración del sistema, auditoría.
- Ruta propia: `/super-admin` (fuera del shell principal).

### ADMIN
- **Debe pertenecer** a una empresa/institución.
- Gestiona su organización: añade instructores y estudiantes, crea cursos, importa estudiantes masivamente (CSV), asigna estudiantes a cursos en bloque.
- Puede registrar nuevos usuarios y agregarlos directamente a su org.
- Un usuario puede ser ADMIN en múltiples orgs simultáneamente (via memberships).

### INSTRUCTOR
Existen **dos tipos**, determinados por su membership y estado de certificación:

| Tipo | Requisito | Orgs |
|------|-----------|------|
| **Org (asignado)** | Admin lo asigna en su org. No necesita certs. | Solo en esa org |
| **Independiente** | Subió certs profesionales + licencia SST verificados por SuperAdmin | Opera sin org |

- El mismo usuario puede ser INSTRUCTOR en la empresa A y USUARIO en la empresa B.
- Si no ha subido certs y no pertenece a ninguna org → debe subir documentos o unirse a una org para tener el rol de instructor.

### USUARIO (Student)
- **No necesita** pertenecer a ninguna org para registrarse y acceder a la plataforma.
- Puede pertenecer a ninguna, una o múltiples orgs al mismo tiempo.
- Puede aspirar a instructor independiente subiendo sus certificados.
- En cada org puede tener un rol diferente (USUARIO en una, INSTRUCTOR en otra).

---

## Regla clave: Rol por membresía
```
UserModel.role      → rol base/máximo global del usuario
MembershipModel.role → rol de esa persona EN esa organización específica
```
El router y las vistas usan `OrgContextState` (basado en la membership activa) para determinar permisos en pantalla.

---

## Flujos principales

### Registro de Usuario
1. `/register` → campos: nombre, apellido, cédula, teléfono (opcional), email, contraseña, confirmar contraseña.
2. Post-registro: Si es USUARIO → `/home` (no necesita org).
3. Si es ADMIN sin org → `/no-org`.

### Flujo de Instructor Independiente
1. En `/home` (como USUARIO), ve sección "Conviértete en instructor".
2. Va a `/instructor-apply` → sube licencia SST + certificados profesionales.
3. Estado: `CertVerificationStatus.pending`.
4. SuperAdmin recibe alerta, revisa en `/super-admin/certificates`.
5. Si aprueba → `UserModel.role` cambia a `INSTRUCTOR`, `certVerification = approved`.

### Flujo de Registro de Institución
1. `/register-institution` → datos de la empresa/institución + admin principal.
2. Se crea `institutions/{id}` con status `pending`.
3. SuperAdmin lo activa → status `active`.
4. Admin puede acceder a su dashboard.

### Importación masiva de estudiantes (Admin)
1. Admin sube CSV/Excel con cédulas o emails.
2. Sistema busca usuarios existentes o los crea.
3. Les asigna membership en la org con rol USUARIO.
4. Los inscribe en el curso seleccionado.

---

## Constantes importantes

```dart
// Roles
AppConstants.roleSuperAdmin        = 'SUPER_ADMIN'
AppConstants.roleAdmin             = 'ADMIN'
AppConstants.roleInstructor        = 'INSTRUCTOR'
AppConstants.roleUsuarioSST        = 'USUARIO_SST'
AppConstants.roleUsuarioProfesional = 'USUARIO_PROFESIONAL'
AppConstants.roleUsuario           = 'USUARIO'

// Colecciones Firestore
AppConstants.colUsers              = 'users'
AppConstants.colInstitutions       = 'institutions'
AppConstants.colMemberships        = 'memberships'
AppConstants.colSessions           = 'sessions'
AppConstants.colCourses            = 'courses'
AppConstants.colUserCertificates   = 'userCertificates'
AppConstants.colSupportTickets     = 'supportTickets'
```

---

## Colores del tema (AppColors)

```dart
AppColors.brand        // Azul primario
AppColors.accent       // Complementario
AppColors.cyan         // Dispositivos/BLE
AppColors.green        // Éxito/activo
AppColors.amber        // Advertencia/pendiente
AppColors.red          // Error/suspendido
AppColors.darkBg / darkBg2 / darkBg3  // Fondos dark
AppColors.lightCard / lightBg2        // Superficies light
AppColors.darkBorder / lightBorder    // Bordes
AppColors.redBg                       // Fondo de error
AppRadius.sm / md / lg                // Bordes redondeados
```

---

## Proveedores clave (Riverpod)

```dart
authStateProvider            // AsyncNotifier<AuthState> — autenticación
currentUserProvider          // UserModel? — usuario activo (Firestore stream)
orgContextProvider           // OrgContextState — org activa + rol en ella
tenantServiceProvider        // TenantService — queries por institutionId
orgUsersProvider             // FutureProvider<List<OrgMember>> — miembros de la org
superAdminServiceProvider    // SuperAdminService — queries globales
globalKpisProvider           // FutureProvider<GlobalKpis>
superAdminInstitutionsProvider // StreamProvider.family<List<InstitutionModel>, InstitutionStatus?>
```

---

## Reglas Firestore resumidas

- **SUPER_ADMIN**: acceso read/write a TODA la base de datos (catch-all rule al inicio).
- **ADMIN**: read/write en su org, usuarios de su org, cursos, certificados dentro de su org.
- **INSTRUCTOR**: read de cursos y sesiones de su org. Write limitado.
- **USUARIO**: read de sus propios datos, sesiones, certificados. Write propio.
- Los guards de cuota (plan) se verifican en Firestore Rules antes de cada write.

---

## Comandos de desarrollo

```bash
# Levantar app
flutter run

# Analizar errores
dart analyze lib/

# Regenerar l10n
flutter gen-l10n

# Deploy Firestore Rules
firebase deploy --only firestore:rules

# Deploy Firestore Rules + Indexes
firebase deploy --only firestore
```

---

## Patrones de código usados en el proyecto

### Providers
```dart
// FutureProvider con guard de orgId
final myProvider = FutureProvider<List<X>>((ref) {
  final orgId = ref.watch(orgContextProvider).activeOrgId;
  if (orgId == null) return Future.value([]);
  return ref.watch(tenantServiceProvider).getX();
});
```

### Pantallas con Riverpod
```dart
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP  = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS  = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    // ...
  }
}
```

### AsyncValue.valueOrNull (no .value — lanza en error)
```dart
final count = asyncValue.valueOrNull?.length ?? 0;
```

---

## Estado del proyecto (mayo 2026)

- Multi-tenant implementado con `institutions` + `memberships`.
- SuperAdmin con dashboard global y acceso total.
- Registro de usuarios libre (sin org obligatoria para USUARIO).
- ADMIN bloqueado en `/no-org` si no tiene org asignada.
- Flujo de instructor independiente: upload → verificación SuperAdmin → aprobación.
- Soporte y contacto gestionado desde panel SuperAdmin.
- fl_chart ^0.68.0 instalado para gráficas.

---

## Skills disponibles (slash commands)

Cuando trabajes en este proyecto puedes invocar:
- `/ultrareview` — Revisión multi-agente del branch actual o un PR de GitHub.
- `/remember` — Guardar información importante en memoria persistente.

---

## UIDs conocidos (desarrollo/prueba)

| Usuario | UID | Rol |
|---------|-----|-----|
| JOMAR ADMIN (SuperAdmin) | `tj7W7lGXYfe25tmZpgrQ49YfrWn1` | `SUPER_ADMIN` |
| Admin SIERCP | `qsXu5nFciDS7TL8zlpJOKZKT2uw1` | `ADMIN` |

Org de prueba: `institutions/RCP-PRUEBA`
