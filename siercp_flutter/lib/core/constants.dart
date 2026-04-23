/// Constantes globales de la aplicación SIERCP.
/// ⚠️ Las URLs del backend Django han sido eliminadas en la migración a Firebase.
class AppConstants {
  AppConstants._();

  // ── Roles ──────────────────────────────────────────────────────────────────
  static const String roleAdmin      = 'ADMIN';
  static const String roleInstructor = 'INSTRUCTOR';
  static const String roleStudent    = 'ESTUDIANTE';

  // ── Guías AHA 2020 (Adulto) ───────────────────────────────────────────────
  static const double ahaMinDepthMm    = 50.0;  // 5 cm
  static const double ahaMaxDepthMm    = 60.0;  // 6 cm
  static const int    ahaMinRatePerMin = 100;
  static const int    ahaMaxRatePerMin = 120;
  static const double ahaMaxPauseSec   = 10.0;  // sin interrupción > 10 s
  static const double ahaMaxPauseSecExtended = 10.0;
  static const String ahaRatio         = '30:2';

  // ── Guías AHA (Pediátrico) ────────────────────────────────────────────────
  static const double ahaMinDepthMmPedia = 40.0; // 4 cm
  static const double ahaMaxDepthMmPedia = 50.0; // 5 cm

  // ── Scoring ───────────────────────────────────────────────────────────────
  static const double passScore = 85.0;

  // ── Firestore Collections ─────────────────────────────────────────────────
  static const String colUsers     = 'users';
  static const String colSessions  = 'sessions';
  static const String colCourses   = 'courses';
  static const String colManikins  = 'manikins';
  static const String colScenarios = 'scenarios';

  // ── SharedPreferences Keys (para preferencias locales) ────────────────────
  static const String prefThemeMode   = 'theme_mode';
  static const String prefLastCourse  = 'last_course';
  static const String prefOnboarding  = 'onboarding_done';

  // ── App Info ──────────────────────────────────────────────────────────────
  static const String appName    = 'SIERCP';
  static const String appVersion = '2.0.0';
}
