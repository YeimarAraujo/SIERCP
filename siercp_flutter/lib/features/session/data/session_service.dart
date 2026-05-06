import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/features/courses/data/models/alert_course.dart';
import 'package:siercp/features/users/data/models/user.dart';
import 'package:siercp/features/notifications/data/models/notification.dart';
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
  }) async {
    // Obtener título del escenario
    final scenarios = await _db.getScenarios();
    final scenario = scenarios.firstWhere(
      (s) => s.id == scenarioId,
      orElse: () => scenarios.first,
    );

    final sessionId = await _db.createSession(
      studentId: studentId,
      studentName: studentName,
      scenarioId: scenarioId,
      scenarioTitle: scenario.title,
      patientType: patientType,
      courseId: courseId,
      manikinId: manikinId,
    );

    final doc = await _db.getSession(sessionId);
    return doc!;
  }

  Future<SessionModel> endSession(
    String sessionId,
    SessionMetrics metrics,
    int durationSeconds,
  ) async {
    await _db.completeSession(sessionId, metrics, durationSeconds);
    final doc = await _db.getSession(sessionId);
    return doc!;
  }

  Future<void> updateCourseProgressAfterSession(
      String studentId, SessionMetrics metrics) async {
    final enrolledCourseIds = await _db.getStudentEnrolledCourseIds(studentId);
    for (final courseId in enrolledCourseIds) {
      await _db.updateEnrollmentProgress(courseId, studentId, metrics);
    }
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

  Future<List<CourseModel>> getCoursesForUser(String userId, String role) {
    if (role == 'ADMIN') {
      return _db.getAllCourses();
    }
    if (role == 'INSTRUCTOR') {
      return _db.getInstructorCourses(userId);
    }
    return _db.getStudentCourses(userId);
  }

  Future<List<CourseModel>> getAllCourses() {
    return _db.getAllCourses();
  }

  Future<String> createCourse({
    required String name,
    String? description,
    required String instructorId,
    required String instructorName,
  }) async {
    // Generar código de invitación único de 6 caracteres
    final code = _generateCode();
    return _db.createCourse(
      title: name,
      description: description,
      instructorId: instructorId,
      instructorName: instructorName,
      inviteCode: code,
      certification: 'BLS AHA 2020',
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
  }) {
    return _db.markAttendance(
      courseId: courseId,
      studentId: studentId,
      studentName: studentName,
      attended: attended,
      date: date,
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
