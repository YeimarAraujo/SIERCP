import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/session.dart';
import '../models/alert_course.dart';
import '../models/user.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

class LocalStorageService {
  static Database? _db;

  // ─── Inicialización ────────────────────────────────────────────────────────
  /// Inicializa SQLite y crea las tablas necesarias.
  /// Debe llamarse en main() antes de runApp().
  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'siercp.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            studentId TEXT NOT NULL,
            scenarioId TEXT,
            scenarioTitle TEXT,
            patientType TEXT NOT NULL DEFAULT 'adult',
            status TEXT NOT NULL DEFAULT 'pending',
            startedAt TEXT NOT NULL,
            endedAt TEXT,
            courseId TEXT,
            metrics TEXT
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_sessions_student ON sessions(studentId)');
        await db
            .execute('CREATE INDEX idx_sessions_course ON sessions(courseId)');
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            email TEXT NOT NULL,
            firstName TEXT NOT NULL,
            lastName TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'ESTUDIANTE',
            avatarUrl TEXT,
            identificacion TEXT,
            isActive INTEGER NOT NULL DEFAULT 1,
            stats TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE courses (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            instructorName TEXT NOT NULL,
            instructorId TEXT,
            inviteCode TEXT,
            totalModules INTEGER NOT NULL DEFAULT 0,
            completedModules INTEGER NOT NULL DEFAULT 0,
            certification TEXT NOT NULL DEFAULT '',
            requiredScore REAL NOT NULL DEFAULT 85.0,
            studentCount INTEGER,
            description TEXT,
            createdAt TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE enrollments (
            courseId TEXT PRIMARY KEY,
            studentsJson TEXT NOT NULL,
            savedAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE reports (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            studentId TEXT,
            studentName TEXT,
            courseId TEXT,
            courseName TEXT,
            filePath TEXT NOT NULL,
            generatedAt TEXT NOT NULL,
            sessionCount INTEGER NOT NULL DEFAULT 0,
            averageScore REAL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            dataJson TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Database get _database {
    if (_db == null) {
      throw StateError(
          'LocalStorageService no inicializado. Llama init() primero.');
    }
    return _db!;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SESIONES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda una sesión completa con sus métricas.
  Future<void> saveSession(SessionModel session) async {
    await _database.insert(
      'sessions',
      _sessionToRow(session),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _invalidateCache('sessions');
  }

  /// Guarda múltiples sesiones (sincronización masiva).
  Future<void> saveSessions(List<SessionModel> sessions) async {
    final batch = _database.batch();
    for (final s in sessions) {
      batch.insert('sessions', _sessionToRow(s),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await _invalidateCache('sessions');
  }

  /// Obtiene todas las sesiones de un estudiante, ordenadas por fecha desc.
  List<SessionModel> getStudentSessions(String studentId) {
    return _querySessionsSync('studentId = ?', [studentId]);
  }

  /// Obtiene todas las sesiones de un curso.
  List<SessionModel> getCourseSessions(String courseId) {
    return _querySessionsSync('courseId = ?', [courseId]);
  }

  /// Obtiene las sesiones de un estudiante en un curso específico.
  List<SessionModel> getStudentCourseSessions(
      String studentId, String courseId) {
    return _querySessionsSync(
        'studentId = ? AND courseId = ?', [studentId, courseId]);
  }

  /// Obtiene una sesión por ID.
  SessionModel? getSession(String sessionId) {
    final results = _querySessionsSync('id = ?', [sessionId]);
    return results.isEmpty ? null : results.first;
  }

  /// Obtiene todas las sesiones almacenadas localmente.
  List<SessionModel> getAllSessions() {
    return _querySessionsSync(null, null);
  }

  int get totalSessionsStored =>
      _querySyncCached('sessions', null, null).length;

  // ═══════════════════════════════════════════════════════════════════════════
  //  USUARIOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda datos de un usuario (perfil + stats).
  Future<void> saveUser(UserModel user) async {
    final statsJson = user.stats != null
        ? jsonEncode({
            'totalSessions': user.stats!.totalSessions,
            'sessionsToday': user.stats!.sessionsToday,
            'averageScore': user.stats!.averageScore,
            'bestScore': user.stats!.bestScore,
            'streakDays': user.stats!.streakDays,
            'totalHours': user.stats!.totalHours,
            'averageDepthMm': user.stats!.averageDepthMm,
            'averageRatePerMin': user.stats!.averageRatePerMin,
          })
        : null;

    await _database.insert(
        'users',
        {
          'id': user.id,
          'email': user.email,
          'firstName': user.firstName,
          'lastName': user.lastName,
          'role': user.role,
          'avatarUrl': user.avatarUrl,
          'identificacion': user.identificacion,
          'isActive': user.isActive ? 1 : 0,
          'stats': statsJson,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _invalidateCache('users');
  }

  /// Obtiene un usuario por ID.
  UserModel? getUser(String userId) {
    try {
      final rows = _querySyncCached('users', 'id = ?', [userId]);
      if (rows.isEmpty) return null;
      return _userFromRow(rows.first);
    } catch (_) {
      return null;
    }
  }

  /// Obtiene todos los usuarios almacenados.
  List<UserModel> getAllUsers() {
    try {
      final rows = _querySyncCached('users', null, null);
      return rows.map(_userFromRow).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CURSOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda datos de un curso.
  Future<void> saveCourse(CourseModel course) async {
    await _database.insert(
        'courses',
        {
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
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _invalidateCache('courses');
  }

  /// Guarda múltiples cursos.
  Future<void> saveCourses(List<CourseModel> courses) async {
    final batch = _database.batch();
    for (final c in courses) {
      batch.insert(
          'courses',
          {
            'id': c.id,
            'title': c.title,
            'instructorName': c.instructorName,
            'instructorId': c.instructorId,
            'inviteCode': c.inviteCode,
            'totalModules': c.totalModules,
            'completedModules': c.completedModules,
            'certification': c.certification,
            'requiredScore': c.requiredScore,
            'studentCount': c.studentCount,
            'description': c.description,
            'createdAt': c.createdAt?.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await _invalidateCache('courses');
  }

  /// Obtiene un curso por ID.
  CourseModel? getCourse(String courseId) {
    try {
      final rows = _querySyncCached('courses', 'id = ?', [courseId]);
      if (rows.isEmpty) return null;
      return _courseFromRow(rows.first);
    } catch (_) {
      return null;
    }
  }

  /// Obtiene todos los cursos almacenados.
  List<CourseModel> getAllCourses() {
    try {
      final rows = _querySyncCached('courses', null, null);
      return rows.map(_courseFromRow).toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ENROLLMENTS (Inscripciones del curso)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda los estudiantes inscritos en un curso.
  Future<void> saveCourseEnrollments(
      String courseId, List<Map<String, dynamic>> students) async {
    await _database.insert(
        'enrollments',
        {
          'courseId': courseId,
          'studentsJson': jsonEncode(students),
          'savedAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _invalidateCache('enrollments');
  }

  /// Obtiene los estudiantes inscritos en un curso.
  List<Map<String, dynamic>> getCourseEnrollments(String courseId) {
    try {
      final rows = _querySyncCached('enrollments', 'courseId = ?', [courseId]);
      if (rows.isEmpty) return [];
      final decoded = jsonDecode(rows.first['studentsJson'] as String? ?? '[]');
      return (decoded as List)
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  REPORTES PDF (Metadatos locales)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda el registro de un reporte PDF generado.
  Future<void> saveReportRecord(ReportRecord report) async {
    await _database.insert('reports', report.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _invalidateCache('reports');
  }

  /// Obtiene todos los reportes generados.
  List<ReportRecord> getAllReports() {
    try {
      final rows =
          _querySyncCached('reports', null, null, orderBy: 'generatedAt DESC');
      return rows.map((r) => ReportRecord.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
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
    await _database.delete('reports', where: 'id = ?', whereArgs: [reportId]);
    await _invalidateCache('reports');
  }

  int get totalReportsStored => _querySyncCached('reports', null, null).length;

  // ═══════════════════════════════════════════════════════════════════════════
  //  SYNC QUEUE (Cola de sincronización pendiente)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Agrega un item a la cola de sincronización.
  Future<void> addToSyncQueue(String type, Map<String, dynamic> data) async {
    final id = '${type}_${DateTime.now().millisecondsSinceEpoch}';
    await _database.insert('sync_queue', {
      'id': id,
      'type': type,
      'dataJson': jsonEncode(data),
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _invalidateCache('sync_queue');
  }

  /// Obtiene todos los items pendientes de sincronizar.
  List<Map<String, dynamic>> getPendingSyncItems() {
    try {
      final rows = _querySyncCached('sync_queue', null, null);
      return rows.map((r) {
        final data = jsonDecode(r['dataJson'] as String? ?? '{}');
        return {
          'id': r['id'],
          'type': r['type'],
          'data': data,
          'createdAt': r['createdAt'],
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Limpia items ya sincronizados.
  Future<void> removeSyncItem(String id) async {
    await _database.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
    await _invalidateCache('sync_queue');
  }

  int get pendingSyncCount => _querySyncCached('sync_queue', null, null).length;

  // ═══════════════════════════════════════════════════════════════════════════
  //  LIMPIEZA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Limpia todos los datos locales.
  Future<void> clearAll() async {
    await Future.wait([
      _database.delete('sessions'),
      _database.delete('users'),
      _database.delete('courses'),
      _database.delete('enrollments'),
      _database.delete('reports'),
      _database.delete('sync_queue'),
    ]);
    _syncCache.clear();
  }

  /// Limpia solo sesiones.
  Future<void> clearSessions() async {
    await _database.delete('sessions');
    _syncCache.remove('sessions');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CACHE EN MEMORIA PARA LECTURAS SYNC
  // ═══════════════════════════════════════════════════════════════════════════
  // sqflite es asíncrono por naturaleza. Mantenemos un cache por tabla
  // que se actualiza tras cada escritura para preservar la API sincrónica
  // que los consumidores existentes utilizan.

  final Map<String, List<Map<String, dynamic>>> _syncCache = {};

  /// Precarga tablas en cache para acceso sincrónico. Llamar tras init().
  Future<void> preloadCache() async {
    for (final table in [
      'sessions',
      'users',
      'courses',
      'enrollments',
      'reports',
      'sync_queue'
    ]) {
      _syncCache[table] = await _database.query(table);
    }
  }

  /// Invalidar cache de una tabla específica.
  Future<void> _invalidateCache(String table) async {
    _syncCache[table] = await _database.query(table);
  }

  List<Map<String, dynamic>> _querySyncCached(
      String table, String? where, List<Object?>? whereArgs,
      {String? orderBy}) {
    final cached = _syncCache[table];
    if (cached == null) return [];

    var results = cached.toList();

    if (where != null && whereArgs != null) {
      results = results.where((row) {
        final conditions = where.split(' AND ');
        for (int i = 0; i < conditions.length; i++) {
          final cond = conditions[i].trim();
          final parts = cond.split(' = ');
          if (parts.length == 2) {
            final col = parts[0].trim();
            final val = whereArgs.length > i ? whereArgs[i] : null;
            if (row[col]?.toString() != val?.toString()) return false;
          }
        }
        return true;
      }).toList();
    }

    if (orderBy != null) {
      final parts = orderBy.split(' ');
      final col = parts[0];
      final desc = parts.length > 1 && parts[1].toUpperCase() == 'DESC';
      results.sort((a, b) {
        final va = a[col]?.toString() ?? '';
        final vb = b[col]?.toString() ?? '';
        return desc ? vb.compareTo(va) : va.compareTo(vb);
      });
    }

    return results;
  }

  List<SessionModel> _querySessionsSync(String? where, List<Object?>? args) {
    final rows =
        _querySyncCached('sessions', where, args, orderBy: 'startedAt DESC');
    return rows.map((r) => _sessionFromRow(r)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS PRIVADOS
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _sessionToRow(SessionModel s) => {
        'id': s.id,
        'studentId': s.studentId,
        'scenarioId': s.scenarioId,
        'scenarioTitle': s.scenarioTitle,
        'patientType': s.patientType.name,
        'status': s.status.name,
        'startedAt': s.startedAt.toIso8601String(),
        'endedAt': s.endedAt?.toIso8601String(),
        'courseId': s.courseId,
        'metrics': s.metrics != null ? jsonEncode(s.metrics!.toMap()) : null,
      };

  SessionModel _sessionFromRow(Map<String, dynamic> r) {
    Map<String, dynamic>? metricsMap;
    if (r['metrics'] != null) {
      metricsMap =
          Map<String, dynamic>.from(jsonDecode(r['metrics'] as String) as Map);
    }

    return SessionModel(
      id: r['id'] as String,
      studentId: r['studentId'] as String? ?? '',
      scenarioId: r['scenarioId'] as String?,
      scenarioTitle: r['scenarioTitle'] as String?,
      patientType: _parsePatientType(r['patientType'] as String?),
      status: _parseStatus(r['status'] as String?),
      startedAt:
          DateTime.tryParse(r['startedAt'] as String? ?? '') ?? DateTime.now(),
      endedAt: r['endedAt'] != null
          ? DateTime.tryParse(r['endedAt'] as String)
          : null,
      courseId: r['courseId'] as String?,
      metrics: metricsMap != null ? SessionMetrics.fromMap(metricsMap) : null,
    );
  }

  UserModel _userFromRow(Map<String, dynamic> r) {
    Map<String, dynamic>? statsMap;
    if (r['stats'] != null) {
      statsMap =
          Map<String, dynamic>.from(jsonDecode(r['stats'] as String) as Map);
    }
    return UserModel(
      id: r['id'] as String? ?? '',
      email: r['email'] as String? ?? '',
      firstName: r['firstName'] as String? ?? '',
      lastName: r['lastName'] as String? ?? '',
      role: r['role'] as String? ?? 'ESTUDIANTE',
      avatarUrl: r['avatarUrl'] as String?,
      identificacion: r['identificacion'] as String?,
      isActive: (r['isActive'] as int? ?? 1) == 1,
      stats: statsMap != null ? UserStats.fromMap(statsMap) : null,
    );
  }

  CourseModel _courseFromRow(Map<String, dynamic> r) => CourseModel(
        id: r['id'] as String? ?? '',
        title: r['title'] as String? ?? '',
        instructorName: r['instructorName'] as String? ?? '',
        instructorId: r['instructorId'] as String?,
        inviteCode: r['inviteCode'] as String?,
        totalModules: r['totalModules'] as int? ?? 0,
        completedModules: r['completedModules'] as int? ?? 0,
        certification: r['certification'] as String? ?? '',
        requiredScore: (r['requiredScore'] as num? ?? 85).toDouble(),
        studentCount: r['studentCount'] as int?,
        description: r['description'] as String?,
        createdAt: r['createdAt'] != null
            ? DateTime.tryParse(r['createdAt'] as String)
            : null,
      );

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
        id: m['id']?.toString() ?? '',
        type: m['type']?.toString() ?? 'student',
        title: m['title']?.toString() ?? '',
        studentId: m['studentId']?.toString(),
        studentName: m['studentName']?.toString(),
        courseId: m['courseId']?.toString(),
        courseName: m['courseName']?.toString(),
        filePath: m['filePath']?.toString() ?? '',
        generatedAt: DateTime.tryParse(m['generatedAt']?.toString() ?? '') ??
            DateTime.now(),
        sessionCount: m['sessionCount'] is int ? m['sessionCount'] as int : 0,
        averageScore: (m['averageScore'] as num?)?.toDouble(),
      );
}
