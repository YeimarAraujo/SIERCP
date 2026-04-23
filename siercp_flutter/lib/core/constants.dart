/// Constantes globales de la aplicacion SIERCP.
class AppConstants {
  AppConstants._();

  // -- Roles ----------------------------------------------------------------
  static const String roleAdmin      = 'ADMIN';
  static const String roleInstructor = 'INSTRUCTOR';
  static const String roleStudent    = 'ESTUDIANTE';

  // -- Guias AHA 2025 (Adulto) ----------------------------------------------
  static const double ahaMinDepthMm    = 50.0;  // 5 cm
  static const double ahaMaxDepthMm    = 60.0;  // 6 cm
  static const int    ahaMinRatePerMin = 100;
  static const int    ahaMaxRatePerMin = 120;
  static const double ahaMaxPauseSec   = 10.0;
  static const String ahaRatio         = '30:2';

  // -- Guias AHA 2025 (Pediatrico) ------------------------------------------
  static const double ahaMinDepthMmPedia = 40.0; // 4 cm
  static const double ahaMaxDepthMmPedia = 50.0; // 5 cm

  // -- Scoring AHA (pesos por componente) -----------------------------------
  static const double ahaDepthWeight        = 0.30; // 30%
  static const double ahaRateWeight         = 0.30; // 30%
  static const double ahaRecoilWeight       = 0.20; // 20%
  static const double ahaInterruptionWeight = 0.20; // 20%

  // -- Umbrales de aprobacion -----------------------------------------------
  static const double ahaPassScore      = 70.0;   // Aprobado
  static const double ahaExcellentScore = 85.0;    // Excelente
  static const double passScore         = 70.0;    // Alias legacy

  // -- Firestore Collections ------------------------------------------------
  static const String colUsers     = 'users';
  static const String colSessions  = 'sessions';
  static const String colCourses   = 'courses';
  static const String colManikins  = 'manikins';
  static const String colScenarios = 'scenarios';

  // -- SharedPreferences Keys -----------------------------------------------
  static const String prefThemeMode   = 'theme_mode';
  static const String prefLastCourse  = 'last_course';
  static const String prefOnboarding  = 'onboarding_done';

  // -- App Info -------------------------------------------------------------
  static const String appName    = 'SIERCP';
  static const String appVersion = '2.1.0';
}
