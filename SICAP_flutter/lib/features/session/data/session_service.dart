import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/features/courses/data/models/alert_course.dart';
import 'package:siercp/features/users/data/models/user.dart';
import 'package:siercp/features/notifications/data/models/notification.dart';
import 'package:siercp/features/skills/data/skill_service.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:flutter/foundation.dart'; // ← agregar esta línea

final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService(ref.read(firestoreServiceProvider));
});

class SessionService {
  final FirestoreService _db;
  SessionService(this._db);

  Future<SessionModel> startSession({
    required String studentId,
    required String studentName,
    required String scenarioId,
    String patientType = 'adult',
    String? courseId,
    String? manikinId,
    String? institutionId,
  }) async {
    try {
      // 1. Obtener escenarios con timeout (ya tiene fallback interno)
      final scenarios = await getScenarios();
      final scenario = scenarios.firstWhere(
        (s) => s.id == scenarioId,
        orElse: () => scenarios.first,
      );

      // 2. Intentar crear sesión en Firestore con un timeout agresivo
      // Si falla por red, Firestore lo pondrá en cola si la persistencia está activa,
      // pero no queremos bloquear la UI 30 segundos.
      String sessionId;
      try {
        // Pasar institutionId null cuando no hay org: Firestore rules permite
        // sesiones sin org (práctica libre). Una cadena vacía '' rompería
        // tenant isolation al dejar la sesión en un namespace inválido.
        sessionId = await _db
            .createSession(
              studentId: studentId,
              studentName: studentName,
              scenarioId: scenarioId,
              scenarioTitle: scenario.title,
              patientType: patientType,
              courseId: courseId,
              manikinId: manikinId,
              institutionId: (institutionId?.isNotEmpty == true) ? institutionId : null,
            )
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('⚠️ Fallo creación en nube, usando ID local temporal: $e');
        sessionId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      }

      // 3. Intentar obtener el documento (caché o servidor)
      try {
        final doc =
            await _db.getSession(sessionId).timeout(const Duration(seconds: 1));
        if (doc != null) return doc;
      } catch (_) {}

      // 4. Fallback: Crear objeto local si el getSession falló o es una sesión offline
      return SessionModel(
        id: sessionId,
        studentId: studentId,
        studentName: studentName,
        scenarioId: scenarioId,
        scenarioTitle: scenario.title,
        patientType: patientType == 'pediatric'
            ? PatientType.pediatric
            : (patientType == 'infant'
                ? PatientType.infant
                : PatientType.adult),
        status: SessionStatus.active,
        startedAt: DateTime.now(),
        courseId: courseId,
      );
    } catch (e) {
      debugPrint('Error crítico en startSession: $e');
      // Último recurso: sesión básica
      return SessionModel(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        studentId: studentId,
        studentName: studentName,
        patientType: PatientType.adult,
        status: SessionStatus.active,
        startedAt: DateTime.now(),
      );
    }
  }

  Future<SessionModel> endSession(
    String sessionId,
    SessionMetrics metrics,
    int durationSeconds,
  ) async {
    await _db.completeSession(sessionId, metrics, durationSeconds);

    // Spark: emitir Skills vía Vercel (/api/skills/evaluate) — best-effort, no
    // bloquea el resultado. Se omiten sesiones offline (aún no existen en la nube).
    if (!sessionId.startsWith('offline_') && !sessionId.startsWith('error_')) {
      unawaited(
        SkillService().evaluateSession(sessionId).then((issued) {
          if (issued.isNotEmpty) {
            debugPrint('🎖️ Skills emitidas: ${issued.join(", ")}');
          }
        }).catchError((Object e) {
          debugPrint('evaluateSession (no-fatal): $e');
        }),
      );
    }

    final doc = await _db.getSession(sessionId);
    return doc!;
  }

  /// Actualiza el progreso/score del estudiante SOLO en el curso al que pertenece
  /// la sesión. Si la sesión no tiene curso (práctica libre), no toca ningún curso.
  ///
  /// IMPORTANTE: antes iteraba sobre TODOS los cursos inscritos, lo que inflaba el
  /// avgScore/sessionCount/completedModules en cursos donde el estudiante NO practicó
  /// (un resultado de un curso aparecía en otro). El score es POR CURSO.
  Future<void> updateCourseProgressAfterSession(
      String studentId, SessionMetrics metrics, {String? courseId}) async {
    final id = courseId?.trim() ?? '';
    if (id.isEmpty) return; // práctica libre → no pertenece a ningún curso
    await _db.updateEnrollmentProgress(id, studentId, metrics);
  }

  Future<List<SessionModel>> getSessions(String studentId, {int limit = 30}) {
    return _db.getStudentSessions(studentId, limit: limit);
  }

  Future<SessionModel?> getSession(String sessionId) {
    return _db.getSession(sessionId);
  }

  Future<List<ScenarioModel>> getScenarios() {
    return _db.getScenarios();
  }

  Future<List<CourseModel>> getCoursesForUser(
    String userId,
    String role, {
    String? institutionId,
  }) async {
    if (role == 'ADMIN' || role == 'SUPER_ADMIN') {
      if (institutionId != null && institutionId.isNotEmpty) {
        return _db.getCoursesByInstitution(institutionId);
      }
      return [];
    }

    final Set<String> seenIds = {};
    final List<CourseModel> result = [];

    // Cursos como instructor (por asignación en la org)
    if (institutionId != null && institutionId.isNotEmpty) {
      final orgCourses = await _db.getCoursesByInstitution(institutionId);
      for (final c in orgCourses.where((c) => c.isInstructorOf(userId))) {
        seenIds.add(c.id);
        result.add(c);
      }
    }

    // Cursos como instructor primario fuera de la org
    for (final c in await _db.getInstructorCourses(userId)) {
      if (seenIds.add(c.id)) result.add(c);
    }

    // Cursos como estudiante (inscrito)
    for (final c in await _db.getStudentCourses(userId)) {
      if (seenIds.add(c.id)) result.add(c);
    }

    return result;
  }

  /// Verifica si el usuario está asignado como instructor en algún curso de la org.
  Future<bool> isInstructorOnAnyCourse(String userId, String institutionId) async {
    if (institutionId.isEmpty) return false;
    final orgCourses = await _db.getCoursesByInstitution(institutionId);
    return orgCourses.any((c) => c.isInstructorOf(userId));
  }

  Future<List<CourseModel>> getAllCourses() {
    return _db.getAllCourses();
  }

  Future<String> createCourse({
    required String name,
    String? description,
    required String instructorId,
    required String instructorName,
    String? institutionId,
  }) async {
    final user = await _db.getUser(instructorId);
    if (user == null) throw Exception('Usuario no encontrado');

    if (user.courseLimit < 999999) {
      final now = DateTime.now();
      final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      if (user.courseCreationMonth == currentMonth &&
          user.coursesCreatedThisMonth >= user.courseLimit) {
        throw Exception(
            'Has alcanzado el límite mensual de ${user.courseLimit} cursos');
      }
    }

    final code = _generateCode();
    return _db.createCourse(
      title: name,
      description: description,
      instructorId: instructorId,
      instructorName: instructorName,
      inviteCode: code,
      certification: 'BLS AHA 2020',
      institutionId: institutionId,
    );
  }

  Future<void> updateCourse(String courseId, Map<String, dynamic> data) {
    return _db.updateCourse(courseId, data);
  }

  Future<void> deleteCourse(String courseId) {
    return _db.deleteCourse(courseId);
  }

  Future<CourseModel?> joinCourse(
    String code, {
    required String studentId,
    required String studentName,
    required String studentEmail,
    String? identificacion,
  }) async {
    debugPrint('Buscando curso con código: "$code"');

    final course = await _db.getCourseByInviteCode(code);

    debugPrint('Curso encontrado: ${course?.id} - ${course?.title}');

    if (course == null) throw Exception('Código de curso no válido.');

    debugPrint('Inscribiendo estudiante: $studentId en curso: ${course.id}');

    await _db.enrollStudent(
      courseId: course.id,
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      identificacion: identificacion,
    );

    // Notificar al instructor vía Notificación del sistema
    if (course.instructorId != null && course.instructorId!.isNotEmpty) {
      await _db.createNotification(
        NotificationModel(
          id: '',
          userId: course.instructorId!,
          title: 'Nuevo estudiante',
          message: '$studentName se ha unido a tu curso "${course.title}"',
          createdAt: DateTime.now(),
          type: NotificationType.studentJoinedCourse,
          extraData: {'courseId': course.id, 'studentId': studentId},
        ),
      );
    }

    debugPrint('Inscripción completada');
    return course;
  }

  Future<List<AlertModel>> getInstructorAlerts(String instructorId) {
    return _db.getInstructorAlerts(instructorId);
  }

  Stream<List<AlertModel>> watchInstructorAlerts(String instructorId) {
    return _db.watchInstructorAlerts(instructorId);
  }

  Future<List<Map<String, dynamic>>> getCourseStudents(String courseId) {
    return _db.getCourseStudents(courseId);
  }

  Stream<List<Map<String, dynamic>>> watchCourseStudents(String courseId) {
    return _db.watchCourseStudents(courseId);
  }

  Future<void> markAttendance({
    required String courseId,
    required String studentId,
    required String studentName,
    required bool attended,
    required DateTime date,
    String? status,
  }) {
    return _db.markAttendance(
      courseId: courseId,
      studentId: studentId,
      studentName: studentName,
      attended: attended,
      date: date,
      status: status,
    );
  }

  Stream<List<Map<String, dynamic>>> watchAttendance(
      String courseId, DateTime date) {
    return _db.watchAttendance(courseId, date);
  }

  Stream<List<Map<String, dynamic>>> watchCourseAttendanceHistory(
      String courseId) {
    return _db.watchCourseAttendanceHistory(courseId);
  }

  Stream<List<UserModel>> watchUsersStatus(List<String> userIds) {
    return _db.watchUsersStatus(userIds);
  }

  Future<DeviceStatusData> getDeviceStatus() async {
    try {
      final manikins = await _db.getManikins();
      if (manikins.isEmpty) return const DeviceStatusData(isConnected: false);
      final active = manikins.first;
      return DeviceStatusData(
        isConnected: active.status == 'en_uso' || active.status == 'disponible',
        deviceName: active.name,
      );
    } catch (_) {
      return const DeviceStatusData(isConnected: false);
    }
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buf = StringBuffer();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 6; i++) {
      buf.write(chars[(now ~/ (i + 1)) % chars.length]);
    }
    return buf.toString();
  }
}

class DeviceStatusData {
  final bool isConnected;
  final String? deviceName;
  const DeviceStatusData({required this.isConnected, this.deviceName});
}
