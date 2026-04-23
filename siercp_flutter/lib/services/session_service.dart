import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../models/alert_course.dart';
import 'firestore_service.dart';

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
    final scenario  = scenarios.firstWhere(
      (s) => s.id == scenarioId,
      orElse: () => scenarios.first,
    );

    final sessionId = await _db.createSession(
      studentId:     studentId,
      studentName:   studentName,
      scenarioId:    scenarioId,
      scenarioTitle: scenario.title,
      patientType:   patientType,
      courseId:      courseId,
      manikinId:     manikinId,
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
    if (role == 'INSTRUCTOR' || role == 'ADMIN') {
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
      title:          name,
      description:    description,
      instructorId:   instructorId,
      instructorName: instructorName,
      inviteCode:     code,
      certification:  'BLS AHA 2020',
    );
  }

  Future<CourseModel?> joinCourse(String code, {
    required String studentId,
    required String studentName,
    required String studentEmail,
    String? identificacion,
  }) async {
    final course = await _db.getCourseByInviteCode(code);
    if (course == null) throw Exception('Código de curso no válido.');

    await _db.enrollStudent(
      courseId:       course.id,
      studentId:      studentId,
      studentName:    studentName,
      studentEmail:   studentEmail,
      identificacion: identificacion,
    );
    return course;
  }

  Future<List<Map<String, dynamic>>> getCourseStudents(String courseId) {
    return _db.getCourseStudents(courseId);
  }

  Future<DeviceStatusData> getDeviceStatus() async {
    try {
      final manikins = await _db.getManikins();
      if (manikins.isEmpty) return const DeviceStatusData(isConnected: false);
      final active = manikins.first;
      return DeviceStatusData(
        isConnected: active.status == 'en_uso' || active.status == 'disponible',
        deviceName:  active.name,
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
