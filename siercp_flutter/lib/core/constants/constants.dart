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
  static const String roleSuperAdmin       = 'SUPER_ADMIN';
  static const String roleAdmin            = 'ADMIN';
  static const String roleInstructor       = 'INSTRUCTOR';
  static const String roleUsuarioSST       = 'USUARIO_SST';
  static const String roleUsuarioProfesional = 'USUARIO_PROFESIONAL';
  static const String roleUsuario          = 'USUARIO';

  /// @deprecated Usa [roleUsuario]. Conservado para migración.
  static const String roleStudent          = roleUsuario;

  // Límites de cursos creados por rol (Infinity = sin límite en app; limitado por plan)
  static const int courseLimitUsuario    = 3;
  static const int courseLimitUsuarioPro = 10;

  // ── Colecciones Firestore ──────────────────────────────────────────────────
  static const String colUsers                  = 'users';
  static const String colSessions               = 'sessions';
  static const String colCourses                = 'courses';
  static const String colManikins               = 'manikins';
  static const String colScenarios              = 'scenarios';
  static const String colUserCertificates       = 'user_certificates';
  static const String colCertificationPayments  = 'certification_payments';
  static const String colAuditLogs              = 'audit_logs';

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
