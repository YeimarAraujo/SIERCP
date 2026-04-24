import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/session.dart';
import '../models/alert_course.dart';
import '../models/user.dart';

/// Provider global del servicio de almacenamiento local.
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

/// Servicio de almacenamiento local offline basado en Hive.
///
/// Persiste localmente:
///  - Sesiones de RCP (con métricas AHA)
///  - Usuarios (perfil y stats)
///  - Cursos y enrollments
///  - PDFs generados (metadatos + path local)
///
/// Funciona completamente sin internet.
class LocalStorageService {
  static const String _sessionsBox = 'sessions';
  static const String _usersBox = 'users';
  static const String _coursesBox = 'courses';
  static const String _enrollmentsBox = 'enrollments';
  static const String _reportsBox = 'reports';
  static const String _syncQueueBox = 'sync_queue';

  // ─── Inicialización ────────────────────────────────────────────────────────
  /// Inicializa Hive y abre todos los boxes necesarios.
  /// Debe llamarse en main() antes de runApp().
  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(_sessionsBox),
      Hive.openBox<Map>(_usersBox),
      Hive.openBox<Map>(_coursesBox),
      Hive.openBox<Map>(_enrollmentsBox),
      Hive.openBox<Map>(_reportsBox),
      Hive.openBox<Map>(_syncQueueBox),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SESIONES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda una sesión completa con sus métricas.
  Future<void> saveSession(SessionModel session) async {
    final box = Hive.box<Map>(_sessionsBox);
    await box.put(session.id, _sessionToMap(session));
  }

  /// Guarda múltiples sesiones (sincronización masiva).
  Future<void> saveSessions(List<SessionModel> sessions) async {
    final box = Hive.box<Map>(_sessionsBox);
    final entries = <String, Map>{};
    for (final s in sessions) {
      entries[s.id] = _sessionToMap(s);
    }
    await box.putAll(entries);
  }

  /// Obtiene todas las sesiones de un estudiante, ordenadas por fecha desc.
  List<SessionModel> getStudentSessions(String studentId) {
    final box = Hive.box<Map>(_sessionsBox);
    final sessions = <SessionModel>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final map = Map<String, dynamic>.from(data);
        if (map['studentId'] == studentId) {
          sessions.add(_sessionFromMap(key as String, map));
        }
      }
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  /// Obtiene todas las sesiones de un curso.
  List<SessionModel> getCourseSessions(String courseId) {
    final box = Hive.box<Map>(_sessionsBox);
    final sessions = <SessionModel>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final map = Map<String, dynamic>.from(data);
        if (map['courseId'] == courseId) {
          sessions.add(_sessionFromMap(key as String, map));
        }
      }
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  /// Obtiene las sesiones de un estudiante en un curso específico.
  List<SessionModel> getStudentCourseSessions(String studentId, String courseId) {
    final box = Hive.box<Map>(_sessionsBox);
    final sessions = <SessionModel>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final map = Map<String, dynamic>.from(data);
        if (map['studentId'] == studentId && map['courseId'] == courseId) {
          sessions.add(_sessionFromMap(key as String, map));
        }
      }
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  /// Obtiene una sesión por ID.
  SessionModel? getSession(String sessionId) {
    final box = Hive.box<Map>(_sessionsBox);
    final data = box.get(sessionId);
    if (data == null) return null;
    return _sessionFromMap(sessionId, Map<String, dynamic>.from(data));
  }

  /// Obtiene todas las sesiones almacenadas localmente.
  List<SessionModel> getAllSessions() {
    final box = Hive.box<Map>(_sessionsBox);
    final sessions = <SessionModel>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        sessions.add(_sessionFromMap(key as String, Map<String, dynamic>.from(data)));
      }
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  int get totalSessionsStored => Hive.box<Map>(_sessionsBox).length;

  // ═══════════════════════════════════════════════════════════════════════════
  //  USUARIOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda datos de un usuario (perfil + stats).
  Future<void> saveUser(UserModel user) async {
    final box = Hive.box<Map>(_usersBox);
    await box.put(user.id, {
      'id': user.id,
      'email': user.email,
      'firstName': user.firstName,
      'lastName': user.lastName,
      'role': user.role,
      'avatarUrl': user.avatarUrl,
      'identificacion': user.identificacion,
      'isActive': user.isActive,
      'stats': user.stats != null
          ? {
              'totalSessions': user.stats!.totalSessions,
              'sessionsToday': user.stats!.sessionsToday,
              'averageScore': user.stats!.averageScore,
              'bestScore': user.stats!.bestScore,
              'streakDays': user.stats!.streakDays,
              'totalHours': user.stats!.totalHours,
              'averageDepthMm': user.stats!.averageDepthMm,
              'averageRatePerMin': user.stats!.averageRatePerMin,
            }
          : null,
    });
  }

  /// Obtiene un usuario por ID.
  UserModel? getUser(String userId) {
    final box = Hive.box<Map>(_usersBox);
    final data = box.get(userId);
    if (data == null) return null;
    final map = Map<String, dynamic>.from(data);
    final statsMap = map['stats'] != null
        ? Map<String, dynamic>.from(map['stats'] as Map)
        : null;
    return UserModel(
      id: map['id'] ?? userId,
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      role: map['role'] ?? 'ESTUDIANTE',
      avatarUrl: map['avatarUrl'],
      identificacion: map['identificacion'],
      isActive: map['isActive'] ?? true,
      stats: statsMap != null ? UserStats.fromMap(statsMap) : null,
    );
  }

  /// Obtiene todos los usuarios almacenados.
  List<UserModel> getAllUsers() {
    final box = Hive.box<Map>(_usersBox);
    final users = <UserModel>[];
    for (final key in box.keys) {
      final user = getUser(key as String);
      if (user != null) users.add(user);
    }
    return users;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CURSOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda datos de un curso.
  Future<void> saveCourse(CourseModel course) async {
    final box = Hive.box<Map>(_coursesBox);
    await box.put(course.id, {
      'id': course.id,
      'title': course.title,
      'instructorName': course.instructorName,
      'instructorId': course.instructorId,
      'inviteCode': course.inviteCode,
      'totalModules': course.totalModules,
      'completedModules': course.completedModules,
      'certification': course.certification,
      'requiredScore': course.requiredScore,
      'studentCount': course.studentCount,
      'description': course.description,
      'createdAt': course.createdAt?.toIso8601String(),
    });
  }

  /// Guarda múltiples cursos.
  Future<void> saveCourses(List<CourseModel> courses) async {
    for (final c in courses) {
      await saveCourse(c);
    }
  }

  /// Obtiene un curso por ID.
  CourseModel? getCourse(String courseId) {
    final box = Hive.box<Map>(_coursesBox);
    final data = box.get(courseId);
    if (data == null) return null;
    final map = Map<String, dynamic>.from(data);
    return CourseModel(
      id: map['id'] ?? courseId,
      title: map['title'] ?? '',
      instructorName: map['instructorName'] ?? '',
      instructorId: map['instructorId'],
      inviteCode: map['inviteCode'],
      totalModules: map['totalModules'] ?? 0,
      completedModules: map['completedModules'] ?? 0,
      certification: map['certification'] ?? '',
      requiredScore: (map['requiredScore'] ?? 85).toDouble(),
      studentCount: map['studentCount'],
      description: map['description'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'])
          : null,
    );
  }

  /// Obtiene todos los cursos almacenados.
  List<CourseModel> getAllCourses() {
    final box = Hive.box<Map>(_coursesBox);
    final courses = <CourseModel>[];
    for (final key in box.keys) {
      final course = getCourse(key as String);
      if (course != null) courses.add(course);
    }
    return courses;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ENROLLMENTS (Inscripciones del curso)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda los estudiantes inscritos en un curso.
  Future<void> saveCourseEnrollments(
      String courseId, List<Map<String, dynamic>> students) async {
    final box = Hive.box<Map>(_enrollmentsBox);
    await box.put(courseId, {
      'courseId': courseId,
      'students': students.map((s) => Map<String, dynamic>.from(s)).toList(),
      'savedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Obtiene los estudiantes inscritos en un curso.
  List<Map<String, dynamic>> getCourseEnrollments(String courseId) {
    final box = Hive.box<Map>(_enrollmentsBox);
    final data = box.get(courseId);
    if (data == null) return [];
    final map = Map<String, dynamic>.from(data);
    final rawStudents = map['students'] as List? ?? [];
    return rawStudents
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  REPORTES PDF (Metadatos locales)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda el registro de un reporte PDF generado.
  Future<void> saveReportRecord(ReportRecord report) async {
    final box = Hive.box<Map>(_reportsBox);
    await box.put(report.id, report.toMap());
  }

  /// Obtiene todos los reportes generados.
  List<ReportRecord> getAllReports() {
    final box = Hive.box<Map>(_reportsBox);
    final reports = <ReportRecord>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        reports.add(ReportRecord.fromMap(Map<String, dynamic>.from(data)));
      }
    }
    reports.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return reports;
  }

  /// Obtiene reportes por tipo (student, course).
  List<ReportRecord> getReportsByType(String type) {
    return getAllReports().where((r) => r.type == type).toList();
  }

  /// Obtiene reportes de un estudiante específico.
  List<ReportRecord> getStudentReports(String studentId) {
    return getAllReports().where((r) => r.studentId == studentId).toList();
  }

  /// Obtiene reportes de un curso específico.
  List<ReportRecord> getCourseReports(String courseId) {
    return getAllReports().where((r) => r.courseId == courseId).toList();
  }

  /// Elimina un registro de reporte.
  Future<void> deleteReport(String reportId) async {
    final box = Hive.box<Map>(_reportsBox);
    await box.delete(reportId);
  }

  int get totalReportsStored => Hive.box<Map>(_reportsBox).length;

  // ═══════════════════════════════════════════════════════════════════════════
  //  SYNC QUEUE (Cola de sincronización pendiente)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Agrega un item a la cola de sincronización.
  Future<void> addToSyncQueue(String type, Map<String, dynamic> data) async {
    final box = Hive.box<Map>(_syncQueueBox);
    final id = '${type}_${DateTime.now().millisecondsSinceEpoch}';
    await box.put(id, {
      'id': id,
      'type': type,
      'data': data,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Obtiene todos los items pendientes de sincronizar.
  List<Map<String, dynamic>> getPendingSyncItems() {
    final box = Hive.box<Map>(_syncQueueBox);
    return box.values
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
  }

  /// Limpia items ya sincronizados.
  Future<void> removeSyncItem(String id) async {
    final box = Hive.box<Map>(_syncQueueBox);
    await box.delete(id);
  }

  int get pendingSyncCount => Hive.box<Map>(_syncQueueBox).length;

  // ═══════════════════════════════════════════════════════════════════════════
  //  LIMPIEZA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Limpia todos los datos locales.
  Future<void> clearAll() async {
    await Future.wait([
      Hive.box<Map>(_sessionsBox).clear(),
      Hive.box<Map>(_usersBox).clear(),
      Hive.box<Map>(_coursesBox).clear(),
      Hive.box<Map>(_enrollmentsBox).clear(),
      Hive.box<Map>(_reportsBox).clear(),
      Hive.box<Map>(_syncQueueBox).clear(),
    ]);
  }

  /// Limpia solo sesiones.
  Future<void> clearSessions() async {
    await Hive.box<Map>(_sessionsBox).clear();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS PRIVADOS
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _sessionToMap(SessionModel s) => {
        'id': s.id,
        'studentId': s.studentId,
        'scenarioId': s.scenarioId,
        'scenarioTitle': s.scenarioTitle,
        'patientType': s.patientType.name,
        'status': s.status.name,
        'startedAt': s.startedAt.toIso8601String(),
        'endedAt': s.endedAt?.toIso8601String(),
        'courseId': s.courseId,
        'metrics': s.metrics != null ? s.metrics!.toMap() : null,
      };

  SessionModel _sessionFromMap(String id, Map<String, dynamic> m) {
    return SessionModel(
      id: id,
      studentId: m['studentId'] ?? '',
      scenarioId: m['scenarioId'],
      scenarioTitle: m['scenarioTitle'],
      patientType: _parsePatientType(m['patientType']),
      status: _parseStatus(m['status']),
      startedAt: DateTime.tryParse(m['startedAt'] ?? '') ?? DateTime.now(),
      endedAt: m['endedAt'] != null ? DateTime.tryParse(m['endedAt']) : null,
      courseId: m['courseId'],
      metrics: m['metrics'] != null
          ? SessionMetrics.fromMap(Map<String, dynamic>.from(m['metrics'] as Map))
          : null,
    );
  }

  static PatientType _parsePatientType(String? t) {
    switch (t) {
      case 'pediatric':
        return PatientType.pediatric;
      case 'infant':
        return PatientType.infant;
      default:
        return PatientType.adult;
    }
  }

  static SessionStatus _parseStatus(String? s) {
    switch (s) {
      case 'active':
        return SessionStatus.active;
      case 'completed':
        return SessionStatus.completed;
      case 'aborted':
        return SessionStatus.aborted;
      default:
        return SessionStatus.pending;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MODELO: ReportRecord
// ═══════════════════════════════════════════════════════════════════════════════

/// Registro de un PDF generado y guardado localmente.
class ReportRecord {
  final String id;
  final String type; // 'student' | 'course'
  final String title;
  final String? studentId;
  final String? studentName;
  final String? courseId;
  final String? courseName;
  final String filePath;
  final DateTime generatedAt;
  final int sessionCount;
  final double? averageScore;

  const ReportRecord({
    required this.id,
    required this.type,
    required this.title,
    this.studentId,
    this.studentName,
    this.courseId,
    this.courseName,
    required this.filePath,
    required this.generatedAt,
    this.sessionCount = 0,
    this.averageScore,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'title': title,
        'studentId': studentId,
        'studentName': studentName,
        'courseId': courseId,
        'courseName': courseName,
        'filePath': filePath,
        'generatedAt': generatedAt.toIso8601String(),
        'sessionCount': sessionCount,
        'averageScore': averageScore,
      };

  factory ReportRecord.fromMap(Map<String, dynamic> m) => ReportRecord(
        id: m['id'] ?? '',
        type: m['type'] ?? 'student',
        title: m['title'] ?? '',
        studentId: m['studentId'],
        studentName: m['studentName'],
        courseId: m['courseId'],
        courseName: m['courseName'],
        filePath: m['filePath'] ?? '',
        generatedAt: DateTime.tryParse(m['generatedAt'] ?? '') ?? DateTime.now(),
        sessionCount: m['sessionCount'] ?? 0,
        averageScore: (m['averageScore'] as num?)?.toDouble(),
      );
}
