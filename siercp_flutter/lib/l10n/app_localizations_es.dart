// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get profileTitle => 'Perfil';

  @override
  String get settings => 'Configuración';

  @override
  String get darkMode => 'Modo Oscuro';

  @override
  String get alerts => 'Notificaciones de alerta';

  @override
  String get language => 'Idioma';

  @override
  String get about => 'Acerca de';

  @override
  String get appVersion => 'Versión de la app';

  @override
  String get ahaGuidelines => 'Guías AHA 2020';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get totalSessions => 'Total sesiones';

  @override
  String get averageScore => 'Promedio global';

  @override
  String get practiceHours => 'Horas práctica';

  @override
  String get currentStreak => 'Racha actual';

  @override
  String get student => 'ESTUDIANTE';

  @override
  String get instructor => 'INSTRUCTOR';

  @override
  String get admin => 'ADMINISTRADOR';

  @override
  String get user => 'Usuario';

  @override
  String get selectLanguage => 'Seleccionar idioma';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get loginSubtitle => 'Sistema de Entrenamiento RCP';

  @override
  String get loginInstruction => 'Ingresa con tu correo institucional';

  @override
  String get emailLabel => 'Correo electrónico';

  @override
  String get emailHint => 'usuario@siercp.edu.co';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get noAccountRegister => '¿No tienes cuenta? Regístrate aquí';

  @override
  String get loginErrorEmptyFields => 'Ingresa tu correo y contraseña';

  @override
  String get forgotPassErrorEmpty =>
      'Ingresa tu correo para restablecer la contraseña.';

  @override
  String get forgotPassSuccess => '📧 Correo de restablecimiento enviado.';

  @override
  String get registerTitle => 'Crear cuenta';

  @override
  String get registerSubtitle => 'Únete a SIERCP y comienza tu entrenamiento';

  @override
  String get roleStudentLabel => 'Estudiante';

  @override
  String get roleInstructorLabel => 'Instructor';

  @override
  String get firstName => 'Nombre';

  @override
  String get lastName => 'Apellido';

  @override
  String get idLabel => 'Número de identificación / Cédula';

  @override
  String get idHint => 'Ej: 1234567890';

  @override
  String get requiredField => 'Requerido';

  @override
  String get min5Digits => 'Mínimo 5 dígitos';

  @override
  String get invalidEmail => 'Correo inválido';

  @override
  String get min6Chars => 'Mínimo 6 caracteres';

  @override
  String get acceptPrivacy1 => 'Acepto las ';

  @override
  String get acceptPrivacy2 => 'Políticas de privacidad';

  @override
  String get registerPrivacyError =>
      'Debes aceptar las Políticas de privacidad';

  @override
  String get closeButton => 'Cerrar';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navUsers => 'Usuarios';

  @override
  String get navDevices => 'Maniquíes';

  @override
  String get navProfile => 'Perfil';

  @override
  String get navHome => 'Inicio';

  @override
  String get navSession => 'Sesión';

  @override
  String get navHistory => 'Historial';

  @override
  String get navCourses => 'Cursos';

  @override
  String get coursesTitle => 'Cursos';

  @override
  String get searchingDevice => 'Buscando...';

  @override
  String get deviceError => 'Error';

  @override
  String get noDevice => 'Sin maniquí';

  @override
  String get searchingManikin => 'Buscando maniquí...';

  @override
  String get manikinNotDetected =>
      '⚠️ Maniquí no detectado. Verificar conexión del ESP32.';

  @override
  String get adminDashboardTitle => 'Panel de Control';

  @override
  String welcomeName(String name) {
    return 'Bienvenido, $name';
  }

  @override
  String get adminSubtitle => 'Administrador SIERCP';

  @override
  String get instructorSubtitle => 'Instructor';

  @override
  String get studentSubtitle => 'ESTUDIANTE';

  @override
  String get historicalSummary => 'Resumen histórico';

  @override
  String get sessionsToday => 'Sesiones hoy';

  @override
  String get avgDepth => 'Prof. promedio';

  @override
  String get avgRate => 'Frecuencia media';

  @override
  String get compressionScore => '% Compresiones OK';

  @override
  String get depthHint => 'Rango: 50–60mm';

  @override
  String get rateHint => 'Meta: 100–120';

  @override
  String get scoreHint => 'Meta: 85%+';

  @override
  String get courseProgress => 'Progreso del curso';

  @override
  String get systemAlerts => 'Alertas del sistema';

  @override
  String get latestAlerts => 'Últimas alertas';

  @override
  String get noRecentAlerts => 'Sin alertas recientes.';

  @override
  String get adminUsersSub => 'Instructores y Estudiantes';

  @override
  String get adminDevicesSub => 'Estado de conexión';

  @override
  String get adminCoursesSub => 'Gestionar programas';

  @override
  String get adminReportsSub => 'Estadísticas globales';

  @override
  String get newCourse => 'Nuevo Curso';

  @override
  String get myStudents => 'Mis Estudiantes';

  @override
  String get exportData => 'Exportar';

  @override
  String get myActiveCourses => 'Mis cursos activos';

  @override
  String get viewAll => 'Ver todos';

  @override
  String get noCoursesCreated =>
      'Aún no has creado ningún curso. Crea el primero.';

  @override
  String get noCoursesCreatedPlain => 'Aún no has creado ningún curso';

  @override
  String get noCoursesJoinedPlain => 'No estás inscrito en ningún curso';

  @override
  String get noCoursesCreatedDesc =>
      'Crea tu primer curso para comenzar a gestionar estudiantes.';

  @override
  String get noCoursesJoinedDesc =>
      'Pide a tu instructor el código para unirte o aguarda a que te inscriban.';

  @override
  String get createFirstCourseBtn => 'Crear primer curso';

  @override
  String get joinWithCodeBtn => 'Unirse con código';

  @override
  String get joinCourseBtn => 'Unirse a curso';

  @override
  String get joinCourseTitle => 'Unirse a un curso';

  @override
  String get courseCodeLabel => 'Código del curso';

  @override
  String get courseCodeHint => 'Ej: X9J2P1';

  @override
  String get joinSuccess => 'Te has unido al curso con éxito';

  @override
  String joinError(String error) {
    return 'Error: Verifica el código ($error)';
  }

  @override
  String get createCourseTitle => 'Crear nuevo curso';

  @override
  String get courseNameLabel => 'Nombre del curso';

  @override
  String get courseDescLabel => 'Descripción';

  @override
  String get studentsCedulaLabel => 'Estudiantes (cédulas)';

  @override
  String get studentsCedulaHint => 'Ej: 1234567, 9876543...';

  @override
  String get createSuccess => 'Curso creado con éxito';

  @override
  String get enrollStudentTitle => 'Inscribir estudiante';

  @override
  String get cedulaLabel => 'Cédula / Número de identificación';

  @override
  String get cedulaHint => 'Ej: 1234567890';

  @override
  String get enrollInfo =>
      'El estudiante debe estar registrado en SIERCP con esa cédula.';

  @override
  String get enrollBtn => 'Inscribir';

  @override
  String get enrollSuccess => 'Estudiante inscrito con éxito';

  @override
  String get cprCertificate => 'Certificado SIERCP';

  @override
  String get courseDetail => 'Detalle';

  @override
  String get courseEnroll => 'Inscribir';

  @override
  String get courseExport => 'Exportar';

  @override
  String get courseLive => 'En Vivo';

  @override
  String get exportGradesSuccess => 'CSV de notas exportado';

  @override
  String exportGradesError(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get courseStudentsTitle => 'Estudiantes del curso';

  @override
  String get noStudentsInscribed => 'Sin estudiantes inscritos';

  @override
  String get cancelBtn => 'Cancelar';

  @override
  String get unirseBtn => 'Unirse';

  @override
  String get coursesSubtitleManage => 'Gestión de entrenamiento RCP';

  @override
  String get coursesSubtitleStudent => 'Tus cursos de entrenamiento';

  @override
  String get activeCourses => 'Cursos activos';

  @override
  String get myCourses => 'Mis cursos';

  @override
  String loadCoursesError(String error) {
    return 'Error al cargar cursos: $error';
  }

  @override
  String get createBtn => 'Crear';

  @override
  String studentsCount(int count) {
    return '$count estudiantes';
  }

  @override
  String get noCourseAssigned => 'Sin curso asignado';

  @override
  String get noCourseAssignedDesc =>
      'Tu instructor aún no te ha inscrito en ningún curso. Contacta a tu instructor para unirte a un programa de entrenamiento RCP.';

  @override
  String get viewAvailableCourses => 'Ver cursos disponibles';

  @override
  String get deviceConnected => 'Dispositivo conectado';

  @override
  String get deviceDisconnected => 'Sin dispositivo';

  @override
  String get startCPRTitle => 'Iniciar sesión RCP';

  @override
  String get startCPRDescConnected => 'Selecciona un escenario para comenzar';

  @override
  String get startCPRDescDisconnected =>
      'Conecta el maniquí ESP32 antes de iniciar';

  @override
  String get startTrainingBtn => 'Comenzar entrenamiento';

  @override
  String completedPct(String pct) {
    return '$pct% completado';
  }

  @override
  String deadlineStr(int day, int month) {
    return 'Entrega: $day/$month';
  }

  @override
  String get historyLoadError => 'Error al cargar historial';

  @override
  String get historyTitle => 'Historial';

  @override
  String get historySubtitle => 'Todas tus sesiones de RCP';

  @override
  String exportError(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get exportCsv => 'Exportar CSV';

  @override
  String get exportPdf => 'Exportar PDF (última sesión)';

  @override
  String get exportBtn => 'Exportar';

  @override
  String get globalAvg => 'Promedio global';

  @override
  String get bestSession => 'Mejor sesión';

  @override
  String sessionsCountLabel(int count) {
    return '$count sesiones';
  }

  @override
  String get studentNameFallback => 'Estudiante';

  @override
  String get withMetrics => 'Con métricas';

  @override
  String get scoreProgression => 'Progresión de calificaciones';

  @override
  String get latestSessions => 'Últimas sesiones';

  @override
  String get noSessions => 'Sin sesiones registradas.';

  @override
  String get cprSession => 'Sesión RCP';

  @override
  String get compLabel => 'comp.';

  @override
  String get approved => 'aprobado';

  @override
  String get review => 'revisar';

  @override
  String get noData => 'sin datos';

  @override
  String get selectScenarioTitle => 'Seleccionar escenario';

  @override
  String get selectScenarioSubtitle => 'Elige el caso clínico a simular';

  @override
  String get manikinBtn => 'Maniquí';

  @override
  String get scenarioInfoBanner =>
      'Selecciona un escenario y conecta el maniquí ESP32 para comenzar.';

  @override
  String get lockedScenarioMsg =>
      'Completa los módulos anteriores para desbloquear.';

  @override
  String get newBadge => 'Nuevo';

  @override
  String get demoTitle1 => '🏠 Paro cardíaco en casa';

  @override
  String get demoSub1 => 'Adulto · 52 años · Colapso repentino';

  @override
  String get demoDesc1 =>
      'Familiar encuentra a la víctima inconsciente en el suelo. Sin pulso ni respiración.';

  @override
  String get demoTitle2 => '🚗 Accidente de tránsito';

  @override
  String get demoSub2 => 'Adulto · 35 años · Múltiples traumas';

  @override
  String get demoDesc2 =>
      'Víctima encontrada en la vía, sin respuesta. Evalúa la escena antes de actuar.';

  @override
  String get demoTitle3 => '🌊 Ahogamiento en piscina';

  @override
  String get demoSub3 => 'Adulto · Sin respiración ni pulso';

  @override
  String get demoDesc3 =>
      'Rescatado de la piscina. Protocolo de ahogamiento: ventilaciones primero.';

  @override
  String get demoTitle4 => '🏋️ Colapso durante ejercicio';

  @override
  String get demoSub4 => 'Adulto · 28 años · Atleta';

  @override
  String get demoDesc4 =>
      'Colapso súbito en el gimnasio. Posible fibrilación ventricular. Usa el DEA.';

  @override
  String get demoTitle5 => '🍽️ Atragantamiento severo';

  @override
  String get demoSub5 => 'Adulto · Obstrucción de vía aérea';

  @override
  String get demoDesc5 =>
      'Cena familiar. Maniobra de Heimlich + RCP si pierde el conocimiento.';

  @override
  String get demoTitle6 => '⚡ Descarga eléctrica';

  @override
  String get demoSub6 => 'Adulto · Accidente laboral';

  @override
  String get demoDesc6 =>
      'Trabajador electrocutado. Asegurar la escena antes de tocar a la víctima.';

  @override
  String get demoTitle7 => '🛏️ Sobredosis por opioides';

  @override
  String get demoSub7 => 'Adulto · Intoxicación · Respiración lenta';

  @override
  String get demoDesc7 =>
      'Víctima con sobredosis: Naloxona si disponible + RCP si paro cardíaco.';

  @override
  String get demoTitle8 => '🚨 Infarto que evoluciona a paro';

  @override
  String get demoSub8 => 'Adulto · 60 años · Dolor torácico';

  @override
  String get demoDesc8 =>
      'Paciente con dolor torácico que evoluciona a paro cardíaco. Actúa rápido.';
}
