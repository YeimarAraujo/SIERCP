/// Constantes globales de la aplicación SIERCP.
class AppConstants {
  AppConstants._();

  // ── Roles ─────────────────────────────────────────────────────────────────
  // Jerarquía ordenada de mayor a menor privilegio:
  //   SUPER_ADMIN → Ingenieros de Jomar Segurid. Monitoreo completo, crea ADMINs.
  //   ADMIN       → Instituciones. Registra instructores para su org.
  //   INSTRUCTOR  → Agregado por un ADMIN. Dirige sesiones de entrenamiento.
  //   USUARIO_SST → Usuario con licencia SST. Más beneficios; requiere planes SST.
  //   USUARIO_PROFESIONAL → Usuario con título profesional (sin licencia SST).
  //                  Hasta 10 cursos; paga por certificar estudiantes.
  //   USUARIO     → Antes ESTUDIANTE. Hasta 3 cursos. Funciones básicas.
  static const String roleSuperAdmin        = 'SUPER_ADMIN';
  static const String roleAdmin             = 'ADMIN';
  static const String roleInstructor        = 'INSTRUCTOR';
  static const String roleUsuarioSST        = 'USUARIO_SST';
  static const String roleUsuarioProfesional = 'USUARIO_PROFESIONAL';
  static const String roleUsuario           = 'USUARIO';

  /// @deprecated Usa [roleUsuario]. Conservado para migración.
  static const String roleStudent = roleUsuario;

  /// Roles asignables por un ADMIN dentro de su org (excluye SUPER_ADMIN).
  /// SuperAdmin usa esta lista para cambios de rol también (excepto SUPER_ADMIN).
  static const List<String> assignableRoles = [
    roleAdmin,
    roleInstructor,
    roleUsuarioSST,
    roleUsuarioProfesional,
    roleUsuario,
  ];

  /// Roles de administración (pueden gestionar usuarios dentro de su org).
  static const List<String> adminRoles = [roleSuperAdmin, roleAdmin];

  // Límites de cursos creados por rol (Infinity = sin límite en app; limitado por plan)
  static const int courseLimitUsuario    = 3;
  static const int courseLimitUsuarioPro = 10;
  static const int courseLimitUsuarioSST = 10;

  // ── Colecciones Firestore ──────────────────────────────────────────────────
  static const String colUsers                  = 'users';
  static const String colSessions               = 'sessions';
  static const String colCourses                = 'courses';
  static const String colManikins               = 'manikins';
  static const String colScenarios              = 'scenarios';
  static const String colGuides                 = 'guides';
  static const String colInstitutions           = 'institutions';
  static const String colMemberships            = 'memberships';
  static const String colUserCertificates       = 'user_certificates';
  static const String colCertificationPayments  = 'certification_payments';
  static const String colAuditLogs              = 'audit_logs';
  static const String colNotifications          = 'notifications';
  static const String colSupportTickets         = 'supportTickets';
  static const String colCourseLimits          = 'course_limits';

  // ── Colecciones LMS + Gamificación ──────────────────────────────────────────
  static const String colQuizTopics            = 'quizTopics';
  static const String colQuizQuestions         = 'quizQuestions';
  static const String colQuizSessions          = 'quizSessions';
  static const String colUserStats             = 'userStats';
  static const String colStudentProgress       = 'student_progress';
  static const String colCourseTemplates       = 'course_templates';
  static const String colCohorts               = 'cohorts';
  static const String colPlatformEnrollments   = 'platform_enrollments';
  static const String colLeaderboards          = 'leaderboards';
  static const String colPayments              = 'payments';
  static const String colTransactions          = 'transactions';

  // ── Subcol Firestore ───────────────────────────────────────────────────────
  static const String subColEnrollments        = 'enrollments';
  static const String subColModules            = 'modules';
  static const String subColAttendance         = 'attendance';
  static const String subColCompressions       = 'compressions';
  static const String subColCompressionBatches = 'compression_batches';
  static const String subColAlerts             = 'alerts';
  static const String subColGuideProgress      = 'guideProgress';
  static const String subColStudents           = 'students';
  static const String subColPlanMembership     = 'planMembership';

  // ── Nombres de campos canónicos (alineados con Web firestore.constants.ts) ──
  // users
  static const String fieldIdentification  = 'identification';
  static const String fieldInstitutionId   = 'institutionId';
  static const String fieldStatus          = 'status';
  static const String fieldIsActive        = 'isActive';
  static const String fieldRole            = 'role';
  static const String fieldCreatedAt       = 'createdAt';
  static const String fieldUpdatedAt       = 'updatedAt';
  // sessions
  static const String fieldStudentId       = 'studentId';
  static const String fieldCourseId        = 'courseId';
  static const String fieldPatientType     = 'patientType';
  static const String fieldQualityScore    = 'qualityScore';
  static const String fieldAverageForceKg  = 'averageForceKg';
  // memberships
  static const String fieldUserId          = 'userId';

  // ── ID determinísticos ────────────────────────────────────────────────────
  /// ID de membership: '{userId}_{institutionId}'
  static String membershipId(String userId, String institutionId) =>
      '${userId}_$institutionId';

  /// ID de progreso de estudiante: '{userId}_{courseId}'
  static String studentProgressId(String userId, String courseId) =>
      '${userId}_$courseId';

  // ── Guías AHA 2025 (Adulto) ───────────────────────────────────────────────
  static const double ahaMinDepthMm      = 50.0;
  static const double ahaMaxDepthMm      = 60.0;
  static const int    ahaMinRatePerMin   = 100;
  static const int    ahaMaxRatePerMin   = 120;
  static const double ahaMaxPauseSec     = 10.0;
  static const String ahaRatio           = '30:2';

  // ── Guías AHA 2025 (Pediátrico) ───────────────────────────────────────────
  static const double ahaMinDepthMmPedia = 40.0;
  static const double ahaMaxDepthMmPedia = 50.0;

  // ── Pesos de puntuación AHA ───────────────────────────────────────────────
  static const double ahaDepthWeight         = 0.30;
  static const double ahaRateWeight          = 0.30;
  static const double ahaRecoilWeight        = 0.20;
  static const double ahaInterruptionWeight  = 0.20;

  // ── Umbrales de aprobación ────────────────────────────────────────────────
  static const double ahaPassScore      = 70.0;
  static const double ahaExcellentScore = 85.0;
  static const double passScore         = 70.0;

  // ── SharedPreferences Keys ────────────────────────────────────────────────
  static const String prefThemeMode  = 'theme_mode';
  static const String prefLastCourse = 'last_course';
  static const String prefOnboarding = 'onboarding_done';

  // ── App Info ──────────────────────────────────────────────────────────────
  static const String appName    = 'SIERCP';
  static const String appVersion = '2.2.0';
}
