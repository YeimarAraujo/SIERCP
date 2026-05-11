import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// El título de la pantalla de perfil
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profileTitle;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settings;

  /// No description provided for @darkMode.
  ///
  /// In es, this message translates to:
  /// **'Modo Oscuro'**
  String get darkMode;

  /// No description provided for @alerts.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones de alerta'**
  String get alerts;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @about.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get about;

  /// No description provided for @appVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión de la app'**
  String get appVersion;

  /// No description provided for @ahaGuidelines.
  ///
  /// In es, this message translates to:
  /// **'Guías AHA 2020'**
  String get ahaGuidelines;

  /// No description provided for @privacyPolicy.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get privacyPolicy;

  /// No description provided for @logout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logout;

  /// No description provided for @totalSessions.
  ///
  /// In es, this message translates to:
  /// **'Total sesiones'**
  String get totalSessions;

  /// No description provided for @averageScore.
  ///
  /// In es, this message translates to:
  /// **'Promedio global'**
  String get averageScore;

  /// No description provided for @practiceHours.
  ///
  /// In es, this message translates to:
  /// **'Horas práctica'**
  String get practiceHours;

  /// No description provided for @currentStreak.
  ///
  /// In es, this message translates to:
  /// **'Racha actual'**
  String get currentStreak;

  /// No description provided for @student.
  ///
  /// In es, this message translates to:
  /// **'ESTUDIANTE'**
  String get student;

  /// No description provided for @instructor.
  ///
  /// In es, this message translates to:
  /// **'INSTRUCTOR'**
  String get instructor;

  /// No description provided for @admin.
  ///
  /// In es, this message translates to:
  /// **'ADMINISTRADOR'**
  String get admin;

  /// No description provided for @user.
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get user;

  /// No description provided for @selectLanguage.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar idioma'**
  String get selectLanguage;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Sistema de Entrenamiento RCP'**
  String get loginSubtitle;

  /// No description provided for @loginInstruction.
  ///
  /// In es, this message translates to:
  /// **'Ingresa con tu correo institucional'**
  String get loginInstruction;

  /// No description provided for @emailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In es, this message translates to:
  /// **'usuario@siercp.edu.co'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get passwordLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get forgotPassword;

  /// No description provided for @noAccountRegister.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta? Regístrate aquí'**
  String get noAccountRegister;

  /// No description provided for @loginErrorEmptyFields.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo y contraseña'**
  String get loginErrorEmptyFields;

  /// No description provided for @forgotPassErrorEmpty.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo para restablecer la contraseña.'**
  String get forgotPassErrorEmpty;

  /// No description provided for @forgotPassSuccess.
  ///
  /// In es, this message translates to:
  /// **'📧 Correo de restablecimiento enviado.'**
  String get forgotPassSuccess;

  /// No description provided for @registerTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Únete a SIERCP y comienza tu entrenamiento'**
  String get registerSubtitle;

  /// No description provided for @roleStudentLabel.
  ///
  /// In es, this message translates to:
  /// **'Estudiante'**
  String get roleStudentLabel;

  /// No description provided for @roleInstructorLabel.
  ///
  /// In es, this message translates to:
  /// **'Instructor'**
  String get roleInstructorLabel;

  /// No description provided for @firstName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In es, this message translates to:
  /// **'Apellido'**
  String get lastName;

  /// No description provided for @idLabel.
  ///
  /// In es, this message translates to:
  /// **'Número de identificación / Cédula'**
  String get idLabel;

  /// No description provided for @idHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 1234567890'**
  String get idHint;

  /// No description provided for @requiredField.
  ///
  /// In es, this message translates to:
  /// **'Requerido'**
  String get requiredField;

  /// No description provided for @min5Digits.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 5 dígitos'**
  String get min5Digits;

  /// No description provided for @invalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo inválido'**
  String get invalidEmail;

  /// No description provided for @min6Chars.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 6 caracteres'**
  String get min6Chars;

  /// No description provided for @acceptPrivacy1.
  ///
  /// In es, this message translates to:
  /// **'Acepto las '**
  String get acceptPrivacy1;

  /// No description provided for @acceptPrivacy2.
  ///
  /// In es, this message translates to:
  /// **'Políticas de privacidad'**
  String get acceptPrivacy2;

  /// No description provided for @registerPrivacyError.
  ///
  /// In es, this message translates to:
  /// **'Debes aceptar las Políticas de privacidad'**
  String get registerPrivacyError;

  /// No description provided for @closeButton.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get closeButton;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In es, this message translates to:
  /// **'Políticas de Privacidad'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicyContent.
  ///
  /// In es, this message translates to:
  /// **'1. Introducción\n\nEl Sistema de Entrenamiento en RCP se compromete a proteger la privacidad y seguridad de la información personal de sus usuarios. Esta política explica cómo recopilamos, usamos, almacenamos y protegemos los datos personales conforme a la normativa vigente en Colombia (Ley 1581 de 2012 y normas complementarias).\n\n2. Información que Recopilamos\n\nPodemos recopilar la siguiente información:\n\nDatos personales: nombre completo, número de identificación, correo electrónico, número de teléfono.\nDatos académicos o profesionales: institución, cargo, certificaciones previas.\nDatos de uso del sistema: progreso en módulos, resultados de evaluaciones, fechas de acceso.\nInformación técnica: dirección IP, tipo de dispositivo y navegador.\n\n3. Finalidad del Tratamiento de Datos\n\nLa información recopilada será utilizada para:\n\nGestionar el registro y acceso al sistema.\nRealizar seguimiento del progreso del usuario en los módulos de RCP.\nEmitir certificados de participación o aprobación.\nEnviar información relevante sobre capacitaciones o actualizaciones.\nMejorar la calidad del servicio y la experiencia del usuario.\n\n4. Almacenamiento y Seguridad\n\nLa información será almacenada en bases de datos seguras y se implementarán medidas técnicas, administrativas y organizativas para evitar acceso no autorizado, pérdida o alteración de la información.\n\n5. Compartición de Información\n\nLos datos personales no serán vendidos ni compartidos con terceros, salvo:\n\nCuando sea requerido por autoridad competente.\nCuando sea necesario para emitir certificaciones oficiales.\nCuando el usuario otorgue autorización expresa.\n\n6. Derechos del Usuario\n\nDe acuerdo con la legislación colombiana, el usuario tiene derecho a:\n\nConocer, actualizar y rectificar sus datos personales.\nSolicitar prueba de la autorización otorgada.\nRevocar la autorización o solicitar la eliminación de sus datos.\nPresentar quejas ante la Superintendencia de Industria y Comercio.\n\n7. Uso de Cookies\n\nEl sistema puede utilizar cookies para mejorar la experiencia de navegación y analizar el uso de la plataforma.\n\n8. Modificaciones a la Política\n\nNos reservamos el derecho de actualizar esta política en cualquier momento. Los cambios serán publicados en la plataforma.\n\n9. Contacto\n\nPara consultas relacionadas con la privacidad y tratamiento de datos, puede comunicarse a través del correo electrónico oficial del sistema.'**
  String get privacyPolicyContent;

  /// No description provided for @navDashboard.
  ///
  /// In es, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navUsers.
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get navUsers;

  /// No description provided for @navDevices.
  ///
  /// In es, this message translates to:
  /// **'Maniquíes'**
  String get navDevices;

  /// No description provided for @navProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get navProfile;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navSession.
  ///
  /// In es, this message translates to:
  /// **'Sesión'**
  String get navSession;

  /// No description provided for @navHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get navHistory;

  /// No description provided for @navCourses.
  ///
  /// In es, this message translates to:
  /// **'Cursos'**
  String get navCourses;

  /// No description provided for @coursesTitle.
  ///
  /// In es, this message translates to:
  /// **'Cursos'**
  String get coursesTitle;

  /// No description provided for @searchingDevice.
  ///
  /// In es, this message translates to:
  /// **'Buscando...'**
  String get searchingDevice;

  /// No description provided for @deviceError.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get deviceError;

  /// No description provided for @noDevice.
  ///
  /// In es, this message translates to:
  /// **'Sin maniquí'**
  String get noDevice;

  /// No description provided for @searchingManikin.
  ///
  /// In es, this message translates to:
  /// **'Buscando maniquí...'**
  String get searchingManikin;

  /// No description provided for @manikinNotDetected.
  ///
  /// In es, this message translates to:
  /// **'⚠️ Maniquí no detectado. Verificar conexión del ESP32.'**
  String get manikinNotDetected;

  /// No description provided for @adminDashboardTitle.
  ///
  /// In es, this message translates to:
  /// **'Panel de Control'**
  String get adminDashboardTitle;

  /// No description provided for @welcomeName.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido, {name}'**
  String welcomeName(String name);

  /// No description provided for @adminSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Administrador SIERCP'**
  String get adminSubtitle;

  /// No description provided for @instructorSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Instructor'**
  String get instructorSubtitle;

  /// No description provided for @studentSubtitle.
  ///
  /// In es, this message translates to:
  /// **'ESTUDIANTE'**
  String get studentSubtitle;

  /// No description provided for @historicalSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen histórico'**
  String get historicalSummary;

  /// No description provided for @sessionsToday.
  ///
  /// In es, this message translates to:
  /// **'Sesiones hoy'**
  String get sessionsToday;

  /// No description provided for @avgDepth.
  ///
  /// In es, this message translates to:
  /// **'Prof. promedio'**
  String get avgDepth;

  /// No description provided for @avgRate.
  ///
  /// In es, this message translates to:
  /// **'Frecuencia media'**
  String get avgRate;

  /// No description provided for @compressionScore.
  ///
  /// In es, this message translates to:
  /// **'% Compresiones OK'**
  String get compressionScore;

  /// No description provided for @depthHint.
  ///
  /// In es, this message translates to:
  /// **'Rango: 50–60mm'**
  String get depthHint;

  /// No description provided for @rateHint.
  ///
  /// In es, this message translates to:
  /// **'Meta: 100–120'**
  String get rateHint;

  /// No description provided for @scoreHint.
  ///
  /// In es, this message translates to:
  /// **'Meta: 85%+'**
  String get scoreHint;

  /// No description provided for @courseProgress.
  ///
  /// In es, this message translates to:
  /// **'Progreso del curso'**
  String get courseProgress;

  /// No description provided for @systemAlerts.
  ///
  /// In es, this message translates to:
  /// **'Alertas del sistema'**
  String get systemAlerts;

  /// No description provided for @latestAlerts.
  ///
  /// In es, this message translates to:
  /// **'Últimas alertas'**
  String get latestAlerts;

  /// No description provided for @noRecentAlerts.
  ///
  /// In es, this message translates to:
  /// **'Sin alertas recientes.'**
  String get noRecentAlerts;

  /// No description provided for @adminUsersSub.
  ///
  /// In es, this message translates to:
  /// **'Instructores y Estudiantes'**
  String get adminUsersSub;

  /// No description provided for @adminDevicesSub.
  ///
  /// In es, this message translates to:
  /// **'Estado de conexión'**
  String get adminDevicesSub;

  /// No description provided for @adminCoursesSub.
  ///
  /// In es, this message translates to:
  /// **'Gestionar programas'**
  String get adminCoursesSub;

  /// No description provided for @adminReportsSub.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas globales'**
  String get adminReportsSub;

  /// No description provided for @newCourse.
  ///
  /// In es, this message translates to:
  /// **'Nuevo Curso'**
  String get newCourse;

  /// No description provided for @myStudents.
  ///
  /// In es, this message translates to:
  /// **'Mis Estudiantes'**
  String get myStudents;

  /// No description provided for @exportData.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get exportData;

  /// No description provided for @myActiveCourses.
  ///
  /// In es, this message translates to:
  /// **'Mis cursos activos'**
  String get myActiveCourses;

  /// No description provided for @viewAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todos'**
  String get viewAll;

  /// No description provided for @noCoursesCreated.
  ///
  /// In es, this message translates to:
  /// **'Aún no has creado ningún curso. Crea el primero.'**
  String get noCoursesCreated;

  /// No description provided for @noCoursesCreatedPlain.
  ///
  /// In es, this message translates to:
  /// **'Aún no has creado ningún curso'**
  String get noCoursesCreatedPlain;

  /// No description provided for @noCoursesJoinedPlain.
  ///
  /// In es, this message translates to:
  /// **'No estás inscrito en ningún curso'**
  String get noCoursesJoinedPlain;

  /// No description provided for @noCoursesCreatedDesc.
  ///
  /// In es, this message translates to:
  /// **'Crea tu primer curso para comenzar a gestionar estudiantes.'**
  String get noCoursesCreatedDesc;

  /// No description provided for @noCoursesJoinedDesc.
  ///
  /// In es, this message translates to:
  /// **'Pide a tu instructor el código para unirte o aguarda a que te inscriban.'**
  String get noCoursesJoinedDesc;

  /// No description provided for @createFirstCourseBtn.
  ///
  /// In es, this message translates to:
  /// **'Crear primer curso'**
  String get createFirstCourseBtn;

  /// No description provided for @joinWithCodeBtn.
  ///
  /// In es, this message translates to:
  /// **'Unirse con código'**
  String get joinWithCodeBtn;

  /// No description provided for @joinCourseBtn.
  ///
  /// In es, this message translates to:
  /// **'Unirse a curso'**
  String get joinCourseBtn;

  /// No description provided for @joinCourseTitle.
  ///
  /// In es, this message translates to:
  /// **'Unirse a un curso'**
  String get joinCourseTitle;

  /// No description provided for @courseCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código del curso'**
  String get courseCodeLabel;

  /// No description provided for @courseCodeHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: X9J2P1'**
  String get courseCodeHint;

  /// No description provided for @joinSuccess.
  ///
  /// In es, this message translates to:
  /// **'Te has unido al curso con éxito'**
  String get joinSuccess;

  /// No description provided for @joinError.
  ///
  /// In es, this message translates to:
  /// **'Error: Verifica el código ({error})'**
  String joinError(String error);

  /// No description provided for @createCourseTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear nuevo curso'**
  String get createCourseTitle;

  /// No description provided for @courseNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre del curso'**
  String get courseNameLabel;

  /// No description provided for @courseDescLabel.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get courseDescLabel;

  /// No description provided for @studentsCedulaLabel.
  ///
  /// In es, this message translates to:
  /// **'Estudiantes (cédulas)'**
  String get studentsCedulaLabel;

  /// No description provided for @studentsCedulaHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 1234567, 9876543...'**
  String get studentsCedulaHint;

  /// No description provided for @createSuccess.
  ///
  /// In es, this message translates to:
  /// **'Curso creado con éxito'**
  String get createSuccess;

  /// No description provided for @enrollStudentTitle.
  ///
  /// In es, this message translates to:
  /// **'Inscribir estudiante'**
  String get enrollStudentTitle;

  /// No description provided for @cedulaLabel.
  ///
  /// In es, this message translates to:
  /// **'Cédula / Número de identificación'**
  String get cedulaLabel;

  /// No description provided for @cedulaHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 1234567890'**
  String get cedulaHint;

  /// No description provided for @enrollInfo.
  ///
  /// In es, this message translates to:
  /// **'El estudiante debe estar registrado en SIERCP con esa cédula.'**
  String get enrollInfo;

  /// No description provided for @enrollBtn.
  ///
  /// In es, this message translates to:
  /// **'Inscribir'**
  String get enrollBtn;

  /// No description provided for @enrollSuccess.
  ///
  /// In es, this message translates to:
  /// **'Estudiante inscrito con éxito'**
  String get enrollSuccess;

  /// No description provided for @cprCertificate.
  ///
  /// In es, this message translates to:
  /// **'Certificado SIERCP'**
  String get cprCertificate;

  /// No description provided for @courseDetail.
  ///
  /// In es, this message translates to:
  /// **'Detalle'**
  String get courseDetail;

  /// No description provided for @courseEnroll.
  ///
  /// In es, this message translates to:
  /// **'Inscribir'**
  String get courseEnroll;

  /// No description provided for @courseExport.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get courseExport;

  /// No description provided for @courseLive.
  ///
  /// In es, this message translates to:
  /// **'En Vivo'**
  String get courseLive;

  /// No description provided for @exportGradesSuccess.
  ///
  /// In es, this message translates to:
  /// **'CSV de notas exportado'**
  String get exportGradesSuccess;

  /// No description provided for @exportGradesError.
  ///
  /// In es, this message translates to:
  /// **'Error al exportar: {error}'**
  String exportGradesError(String error);

  /// No description provided for @courseStudentsTitle.
  ///
  /// In es, this message translates to:
  /// **'Estudiantes del curso'**
  String get courseStudentsTitle;

  /// No description provided for @noStudentsInscribed.
  ///
  /// In es, this message translates to:
  /// **'Sin estudiantes inscritos'**
  String get noStudentsInscribed;

  /// No description provided for @cancelBtn.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelBtn;

  /// No description provided for @unirseBtn.
  ///
  /// In es, this message translates to:
  /// **'Unirse'**
  String get unirseBtn;

  /// No description provided for @joinErrorInvalidCode.
  ///
  /// In es, this message translates to:
  /// **'Error: Verifica el código'**
  String get joinErrorInvalidCode;

  /// No description provided for @coursesSubtitleManage.
  ///
  /// In es, this message translates to:
  /// **'Gestión de entrenamiento RCP'**
  String get coursesSubtitleManage;

  /// No description provided for @coursesSubtitleStudent.
  ///
  /// In es, this message translates to:
  /// **'Tus cursos de entrenamiento'**
  String get coursesSubtitleStudent;

  /// No description provided for @activeCourses.
  ///
  /// In es, this message translates to:
  /// **'Cursos activos'**
  String get activeCourses;

  /// No description provided for @myCourses.
  ///
  /// In es, this message translates to:
  /// **'Mis cursos'**
  String get myCourses;

  /// No description provided for @loadCoursesError.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar cursos: {error}'**
  String loadCoursesError(String error);

  /// No description provided for @createBtn.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get createBtn;

  /// No description provided for @studentsCount.
  ///
  /// In es, this message translates to:
  /// **'{count} estudiantes'**
  String studentsCount(int count);

  /// No description provided for @noCourseAssigned.
  ///
  /// In es, this message translates to:
  /// **'Sin curso asignado'**
  String get noCourseAssigned;

  /// No description provided for @noCourseAssignedDesc.
  ///
  /// In es, this message translates to:
  /// **'Tu instructor aún no te ha inscrito en ningún curso. Contacta a tu instructor para unirte a un programa de entrenamiento RCP.'**
  String get noCourseAssignedDesc;

  /// No description provided for @viewAvailableCourses.
  ///
  /// In es, this message translates to:
  /// **'Ver cursos disponibles'**
  String get viewAvailableCourses;

  /// No description provided for @deviceConnected.
  ///
  /// In es, this message translates to:
  /// **'Dispositivo conectado'**
  String get deviceConnected;

  /// No description provided for @deviceDisconnected.
  ///
  /// In es, this message translates to:
  /// **'Sin dispositivo'**
  String get deviceDisconnected;

  /// No description provided for @startCPRTitle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión RCP'**
  String get startCPRTitle;

  /// No description provided for @startCPRDescConnected.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un escenario para comenzar'**
  String get startCPRDescConnected;

  /// No description provided for @startCPRDescDisconnected.
  ///
  /// In es, this message translates to:
  /// **'Conecta el maniquí ESP32 antes de iniciar'**
  String get startCPRDescDisconnected;

  /// No description provided for @startTrainingBtn.
  ///
  /// In es, this message translates to:
  /// **'Comenzar entrenamiento'**
  String get startTrainingBtn;

  /// No description provided for @completedPct.
  ///
  /// In es, this message translates to:
  /// **'{pct}% completado'**
  String completedPct(String pct);

  /// No description provided for @deadlineStr.
  ///
  /// In es, this message translates to:
  /// **'Entrega: {day}/{month}'**
  String deadlineStr(int day, int month);

  /// No description provided for @historyLoadError.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar historial'**
  String get historyLoadError;

  /// No description provided for @historyTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get historyTitle;

  /// No description provided for @historySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Todas tus sesiones de RCP'**
  String get historySubtitle;

  /// No description provided for @exportError.
  ///
  /// In es, this message translates to:
  /// **'Error al exportar: {error}'**
  String exportError(String error);

  /// No description provided for @exportCsv.
  ///
  /// In es, this message translates to:
  /// **'Exportar CSV'**
  String get exportCsv;

  /// No description provided for @exportPdf.
  ///
  /// In es, this message translates to:
  /// **'Exportar PDF (última sesión)'**
  String get exportPdf;

  /// No description provided for @exportBtn.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get exportBtn;

  /// No description provided for @globalAvg.
  ///
  /// In es, this message translates to:
  /// **'Promedio global'**
  String get globalAvg;

  /// No description provided for @bestSession.
  ///
  /// In es, this message translates to:
  /// **'Mejor sesión'**
  String get bestSession;

  /// No description provided for @sessionsCountLabel.
  ///
  /// In es, this message translates to:
  /// **'{count} sesiones'**
  String sessionsCountLabel(int count);

  /// No description provided for @studentNameFallback.
  ///
  /// In es, this message translates to:
  /// **'Estudiante'**
  String get studentNameFallback;

  /// No description provided for @withMetrics.
  ///
  /// In es, this message translates to:
  /// **'Con métricas'**
  String get withMetrics;

  /// No description provided for @scoreProgression.
  ///
  /// In es, this message translates to:
  /// **'Progresión de calificaciones'**
  String get scoreProgression;

  /// No description provided for @latestSessions.
  ///
  /// In es, this message translates to:
  /// **'Últimas sesiones'**
  String get latestSessions;

  /// No description provided for @noSessions.
  ///
  /// In es, this message translates to:
  /// **'Sin sesiones registradas.'**
  String get noSessions;

  /// No description provided for @cprSession.
  ///
  /// In es, this message translates to:
  /// **'Sesión RCP'**
  String get cprSession;

  /// No description provided for @compLabel.
  ///
  /// In es, this message translates to:
  /// **'comp.'**
  String get compLabel;

  /// No description provided for @approved.
  ///
  /// In es, this message translates to:
  /// **'aprobado'**
  String get approved;

  /// No description provided for @review.
  ///
  /// In es, this message translates to:
  /// **'revisar'**
  String get review;

  /// No description provided for @noData.
  ///
  /// In es, this message translates to:
  /// **'sin datos'**
  String get noData;

  /// No description provided for @selectScenarioTitle.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar escenario'**
  String get selectScenarioTitle;

  /// No description provided for @selectScenarioSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige el caso clínico a simular'**
  String get selectScenarioSubtitle;

  /// No description provided for @manikinBtn.
  ///
  /// In es, this message translates to:
  /// **'Maniquí'**
  String get manikinBtn;

  /// No description provided for @scenarioInfoBanner.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un escenario y conecta el maniquí ESP32 para comenzar.'**
  String get scenarioInfoBanner;

  /// No description provided for @lockedScenarioMsg.
  ///
  /// In es, this message translates to:
  /// **'Completa los módulos anteriores para desbloquear.'**
  String get lockedScenarioMsg;

  /// No description provided for @newBadge.
  ///
  /// In es, this message translates to:
  /// **'Nuevo'**
  String get newBadge;

  /// No description provided for @demoTitle1.
  ///
  /// In es, this message translates to:
  /// **'🏠 Paro cardíaco en casa'**
  String get demoTitle1;

  /// No description provided for @demoSub1.
  ///
  /// In es, this message translates to:
  /// **'Adulto · 52 años · Colapso repentino'**
  String get demoSub1;

  /// No description provided for @demoDesc1.
  ///
  /// In es, this message translates to:
  /// **'Familiar encuentra a la víctima inconsciente en el suelo. Sin pulso ni respiración.'**
  String get demoDesc1;

  /// No description provided for @demoTitle2.
  ///
  /// In es, this message translates to:
  /// **'🚗 Accidente de tránsito'**
  String get demoTitle2;

  /// No description provided for @demoSub2.
  ///
  /// In es, this message translates to:
  /// **'Adulto · 35 años · Múltiples traumas'**
  String get demoSub2;

  /// No description provided for @demoDesc2.
  ///
  /// In es, this message translates to:
  /// **'Víctima encontrada en la vía, sin respuesta. Evalúa la escena antes de actuar.'**
  String get demoDesc2;

  /// No description provided for @demoTitle3.
  ///
  /// In es, this message translates to:
  /// **'🌊 Ahogamiento en piscina'**
  String get demoTitle3;

  /// No description provided for @demoSub3.
  ///
  /// In es, this message translates to:
  /// **'Adulto · Sin respiración ni pulso'**
  String get demoSub3;

  /// No description provided for @demoDesc3.
  ///
  /// In es, this message translates to:
  /// **'Rescatado de la piscina. Protocolo de ahogamiento: ventilaciones primero.'**
  String get demoDesc3;

  /// No description provided for @demoTitle4.
  ///
  /// In es, this message translates to:
  /// **'🏋️ Colapso durante ejercicio'**
  String get demoTitle4;

  /// No description provided for @demoSub4.
  ///
  /// In es, this message translates to:
  /// **'Adulto · 28 años · Atleta'**
  String get demoSub4;

  /// No description provided for @demoDesc4.
  ///
  /// In es, this message translates to:
  /// **'Colapso súbito en el gimnasio. Posible fibrilación ventricular. Usa el DEA.'**
  String get demoDesc4;

  /// No description provided for @demoTitle5.
  ///
  /// In es, this message translates to:
  /// **'🍽️ Atragantamiento severo'**
  String get demoTitle5;

  /// No description provided for @demoSub5.
  ///
  /// In es, this message translates to:
  /// **'Adulto · Obstrucción de vía aérea'**
  String get demoSub5;

  /// No description provided for @demoDesc5.
  ///
  /// In es, this message translates to:
  /// **'Cena familiar. Maniobra de Heimlich + RCP si pierde el conocimiento.'**
  String get demoDesc5;

  /// No description provided for @demoTitle6.
  ///
  /// In es, this message translates to:
  /// **'⚡ Descarga eléctrica'**
  String get demoTitle6;

  /// No description provided for @demoSub6.
  ///
  /// In es, this message translates to:
  /// **'Adulto · Accidente laboral'**
  String get demoSub6;

  /// No description provided for @demoDesc6.
  ///
  /// In es, this message translates to:
  /// **'Trabajador electrocutado. Asegurar la escena antes de tocar a la víctima.'**
  String get demoDesc6;

  /// No description provided for @demoTitle7.
  ///
  /// In es, this message translates to:
  /// **'🛏️ Sobredosis por opioides'**
  String get demoTitle7;

  /// No description provided for @demoSub7.
  ///
  /// In es, this message translates to:
  /// **'Adulto · Intoxicación · Respiración lenta'**
  String get demoSub7;

  /// No description provided for @demoDesc7.
  ///
  /// In es, this message translates to:
  /// **'Víctima con sobredosis: Naloxona si disponible + RCP si paro cardíaco.'**
  String get demoDesc7;

  /// No description provided for @demoTitle8.
  ///
  /// In es, this message translates to:
  /// **'🚨 Infarto que evoluciona a paro'**
  String get demoTitle8;

  /// No description provided for @demoSub8.
  ///
  /// In es, this message translates to:
  /// **'Adulto · 60 años · Dolor torácico'**
  String get demoSub8;

  /// No description provided for @demoDesc8.
  ///
  /// In es, this message translates to:
  /// **'Paciente con dolor torácico que evoluciona a paro cardíaco. Actúa rápido.'**
  String get demoDesc8;

  /// No description provided for @scanQr.
  ///
  /// In es, this message translates to:
  /// **'Escanear QR'**
  String get scanQr;

  /// No description provided for @qrHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe el código o toca el ícono QR para escanear.'**
  String get qrHint;

  /// No description provided for @qrSuccess.
  ///
  /// In es, this message translates to:
  /// **'QR escaneado correctamente'**
  String get qrSuccess;

  /// No description provided for @scanAgain.
  ///
  /// In es, this message translates to:
  /// **'Escanear de nuevo'**
  String get scanAgain;

  /// No description provided for @aimQrHint.
  ///
  /// In es, this message translates to:
  /// **'Apunta al código QR del curso'**
  String get aimQrHint;

  /// No description provided for @qrScannerTitle.
  ///
  /// In es, this message translates to:
  /// **'Escanear código QR'**
  String get qrScannerTitle;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In es, this message translates to:
  /// **'Se requiere permiso de cámara'**
  String get cameraPermissionRequired;

  /// No description provided for @grantPermission.
  ///
  /// In es, this message translates to:
  /// **'Otorgar permiso'**
  String get grantPermission;

  /// No description provided for @createCourseBtn.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get createCourseBtn;

  /// No description provided for @courseCreatedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Curso creado con éxito'**
  String get courseCreatedSuccess;

  /// No description provided for @deleteCourseConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar curso?'**
  String get deleteCourseConfirmTitle;

  /// No description provided for @deleteCourseConfirmDesc.
  ///
  /// In es, this message translates to:
  /// **'Esta acción desactivará el curso \"{title}\". Los alumnos no podrán acceder.'**
  String deleteCourseConfirmDesc(String title);

  /// No description provided for @deleteBtn.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get deleteBtn;

  /// No description provided for @editCourseTitle.
  ///
  /// In es, this message translates to:
  /// **'Modificar curso'**
  String get editCourseTitle;

  /// No description provided for @saveBtn.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get saveBtn;

  /// No description provided for @modulesBtn.
  ///
  /// In es, this message translates to:
  /// **'Módulos'**
  String get modulesBtn;

  /// No description provided for @studentsBtn.
  ///
  /// In es, this message translates to:
  /// **'Alumnos'**
  String get studentsBtn;

  /// No description provided for @qrBtn.
  ///
  /// In es, this message translates to:
  /// **'QR'**
  String get qrBtn;

  /// No description provided for @completed.
  ///
  /// In es, this message translates to:
  /// **'Completado'**
  String get completed;

  /// No description provided for @remainingSessions.
  ///
  /// In es, this message translates to:
  /// **'Faltan {count} sesiones'**
  String remainingSessions(int count);

  /// No description provided for @shareInviteText.
  ///
  /// In es, this message translates to:
  /// **'¡Únete a mi curso de RCP en SIERCP!\nCurso: {title}\nCódigo de invitación: {code}\n\nO escanea el QR desde la app.'**
  String shareInviteText(String title, String code);

  /// No description provided for @shareInviteSubject.
  ///
  /// In es, this message translates to:
  /// **'Invitación a curso SIERCP'**
  String get shareInviteSubject;

  /// No description provided for @shareInviteBtn.
  ///
  /// In es, this message translates to:
  /// **'Compartir invitación'**
  String get shareInviteBtn;

  /// No description provided for @recentActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad Reciente'**
  String get recentActivity;

  /// No description provided for @ahaTipTitle.
  ///
  /// In es, this message translates to:
  /// **'Consejo AHA 2025'**
  String get ahaTipTitle;

  /// No description provided for @ahaTipBody.
  ///
  /// In es, this message translates to:
  /// **'Recuerda que la profundidad de las compresiones debe ser de al menos 5 cm (2 pulgadas) pero no más de 6 cm (2.4 pulgadas). Permite la expansión torácica completa después de cada compresión.'**
  String get ahaTipBody;

  /// No description provided for @totalStudents.
  ///
  /// In es, this message translates to:
  /// **'Estudiantes'**
  String get totalStudents;

  /// No description provided for @activeManikins.
  ///
  /// In es, this message translates to:
  /// **'Maniquíes'**
  String get activeManikins;

  /// No description provided for @alertsToday.
  ///
  /// In es, this message translates to:
  /// **'Alertas Hoy'**
  String get alertsToday;

  /// No description provided for @manageUsers.
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get manageUsers;

  /// No description provided for @manageManikins.
  ///
  /// In es, this message translates to:
  /// **'Maniquíes'**
  String get manageManikins;

  /// No description provided for @manageCourses.
  ///
  /// In es, this message translates to:
  /// **'Cursos'**
  String get manageCourses;

  /// No description provided for @manageReports.
  ///
  /// In es, this message translates to:
  /// **'Reportes'**
  String get manageReports;

  /// No description provided for @manageAnalytics.
  ///
  /// In es, this message translates to:
  /// **'Analíticas'**
  String get manageAnalytics;

  /// No description provided for @quickNewCourse.
  ///
  /// In es, this message translates to:
  /// **'Nuevo Curso'**
  String get quickNewCourse;

  /// No description provided for @quickMyStudents.
  ///
  /// In es, this message translates to:
  /// **'Mis Estudiantes'**
  String get quickMyStudents;

  /// No description provided for @quickExport.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get quickExport;

  /// No description provided for @activeCoursesTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis cursos activos'**
  String get activeCoursesTitle;

  /// No description provided for @navReports.
  ///
  /// In es, this message translates to:
  /// **'Reportes'**
  String get navReports;

  /// No description provided for @navAnalytics.
  ///
  /// In es, this message translates to:
  /// **'Analíticas'**
  String get navAnalytics;

  /// No description provided for @equipmentSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Equipos y Conectividad'**
  String get equipmentSectionTitle;

  /// No description provided for @manikinsLabel.
  ///
  /// In es, this message translates to:
  /// **'Maniquíes SIERCP'**
  String get manikinsLabel;

  /// No description provided for @disconnected.
  ///
  /// In es, this message translates to:
  /// **'Desconectados'**
  String get disconnected;

  /// No description provided for @editProfile.
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get editProfile;

  /// No description provided for @errorOpeningLink.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el enlace'**
  String get errorOpeningLink;

  /// No description provided for @devicesConnectedCount.
  ///
  /// In es, this message translates to:
  /// **'{count} conectados'**
  String devicesConnectedCount(int count);

  /// No description provided for @noInternet.
  ///
  /// In es, this message translates to:
  /// **'SIN CONEXIÓN A INTERNET'**
  String get noInternet;

  /// No description provided for @continueLearning.
  ///
  /// In es, this message translates to:
  /// **'Continuar Aprendizaje'**
  String get continueLearning;

  /// No description provided for @viewDetail.
  ///
  /// In es, this message translates to:
  /// **'Ver detalle'**
  String get viewDetail;

  /// No description provided for @continueTraining.
  ///
  /// In es, this message translates to:
  /// **'Continuar entrenamiento'**
  String get continueTraining;

  /// No description provided for @connected.
  ///
  /// In es, this message translates to:
  /// **'Conectado'**
  String get connected;

  /// No description provided for @noDeviceMini.
  ///
  /// In es, this message translates to:
  /// **'Sin disp.'**
  String get noDeviceMini;

  /// No description provided for @approvedAndSessions.
  ///
  /// In es, this message translates to:
  /// **'{approvedCount}/{requiredCount} aprobadas · {totalDone} sesiones'**
  String approvedAndSessions(
      int approvedCount, int requiredCount, int totalDone);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
