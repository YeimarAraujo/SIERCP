import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/features/users/data/models/user.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/features/courses/data/models/alert_course.dart';
import 'package:siercp/features/devices/data/models/maniqui.dart';
import 'package:siercp/features/notifications/data/models/notification.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection('users');
  CollectionReference get _sessions => _db.collection('sessions');
  CollectionReference get _courses => _db.collection('courses');
  CollectionReference get _manikins => _db.collection('manikins');
  CollectionReference get _scenarios => _db.collection('scenarios');
  CollectionReference get _notifications => _db.collection('notifications');
  CollectionReference get _institutions => _db.collection('institutions');
  CollectionReference get _memberships => _db.collection('memberships');

  CollectionReference _userAlerts(String userId) =>
      _users.doc(userId).collection('alerts');

  Future<void> createUser(UserModel user) async {
    await _users.doc(user.id).set(user.toFirestore());
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _users
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 3));
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error obteniendo usuario (usando caché): $e');
      final doc =
          await _users.doc(uid).get(const GetOptions(source: Source.cache));
      if (doc.exists) return UserModel.fromFirestore(doc);
      return null;
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final snap = await _users
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 3));
      if (snap.docs.isEmpty) return null;
      return UserModel.fromFirestore(snap.docs.first);
    } catch (e) {
      debugPrint('Error obteniendo usuario por email (usando caché): $e');
      final snap = await _users
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get(const GetOptions(source: Source.cache));
      if (snap.docs.isNotEmpty) return UserModel.fromFirestore(snap.docs.first);
      return null;
    }
  }

  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  Future<List<UserModel>> getAllUsers() async {
    final snap = await _users.orderBy('firstName').get();
    return snap.docs.map(UserModel.fromFirestore).toList();
  }

  Future<List<UserModel>> getUsersByRole(String role) async {
    final snap = await _users
        .where('role', isEqualTo: role)
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.map(UserModel.fromFirestore).toList();
  }

  Future<UserModel?> getUserByIdentificacion(String cedula) async {
    final snap =
        await _users.where('identificacion', isEqualTo: cedula).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return UserModel.fromFirestore(snap.docs.first);
  }

  Future<List<UserModel>> getUsersByEmails(List<String> emails) async {
    if (emails.isEmpty) return [];
    // Firestore 'where in' tiene límite de 10 o 30 elementos dependiendo de la versión
    // Lo haremos en chunks de 10 para mayor seguridad
    List<UserModel> found = [];
    for (var i = 0; i < emails.length; i += 10) {
      final end = (i + 10 < emails.length) ? i + 10 : emails.length;
      final chunk = emails.sublist(i, end);
      final snap = await _users.where('email', whereIn: chunk).get();
      found.addAll(snap.docs.map(UserModel.fromFirestore));
    }
    return found;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserAvatar(String uid, String avatarUrl) async {
    await _users.doc(uid).update({
      'avatarUrl': avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserStats(String uid, Map<String, dynamic> stats) async {
    await _users.doc(uid).update({
      'stats': stats,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUser(String uid) async {
    await _users.doc(uid).delete();
  }

  Future<void> toggleUserActive(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return;
    final current = (doc.data() as Map<String, dynamic>)['isActive'] ?? true;
    await _users.doc(uid).update({
      'isActive': !current,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserStatus(String uid, {required bool isOnline}) async {
    await _users.doc(uid).update({
      'isOnline': isOnline,
      'lastActive': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Multitenancy ---

  Future<void> createInstitution(Map<String, dynamic> data) async {
    final ref = _institutions.doc();
    await ref.set({
      ...data,
      'id': ref.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllInstitutions() async {
    final snap = await _institutions.where('status', isEqualTo: 'active').get();
    return snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList();
  }

  Future<void> createMembership({
    required String userId,
    required String institutionId,
    required String role,
    String status = 'pending',
  }) async {
    final ref = _memberships.doc();
    await ref.set({
      'id': ref.id,
      'userId': userId,
      'institutionId': institutionId,
      'role': role,
      'status': status,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchUserMemberships(String userId) {
    return _memberships
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => d.data() as Map<String, dynamic>).toList());
  }

  Future<List<Map<String, dynamic>>> getInstitutionMemberships(
      String institutionId) async {
    final snap = await _memberships
        .where('institutionId', isEqualTo: institutionId)
        .get();
    return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
  }

  Future<void> updateMembershipStatus(
      String membershipId, String status, String adminId) async {
    await _memberships.doc(membershipId).update({
      'status': status,
      'approvedBy': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Notifications ---
  Future<void> createNotification(NotificationModel notification) async {
    await _notifications.add(notification.toFirestore());
  }

  Stream<List<NotificationModel>> watchNotifications(String userId) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(NotificationModel.fromFirestore).toList());
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _notifications.doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    final batch = _db.batch();
    final snap = await _notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    for (var doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // --- Sessions ---

  String getNewSessionId() => _sessions.doc().id;

  Future<void> markAttendance({
    required String courseId,
    required String studentId,
    required String studentName,
    required bool attended,
    required DateTime date,
  }) async {
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final ref = _courses
        .doc(courseId)
        .collection('attendance')
        .doc(dateStr)
        .collection('records')
        .doc(studentId);

    await ref.set({
      'studentId': studentId,
      'studentName': studentName,
      'attended': attended,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchAttendance(
      String courseId, DateTime date) {
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return _courses
        .doc(courseId)
        .collection('attendance')
        .doc(dateStr)
        .collection('records')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Stream<List<Map<String, dynamic>>> watchCourseAttendanceHistory(
      String courseId) {
    return _courses
        .doc(courseId)
        .collection('attendance')
        .orderBy(FieldPath.documentId, descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'date': d.id, ...d.data()}).toList());
  }

  Future<String> createSession({
    String? id,
    required String studentId,
    required String studentName,
    required String scenarioId,
    required String scenarioTitle,
    required String patientType,
    String? courseId,
    String? manikinId,
  }) async {
    final ref = id != null ? _sessions.doc(id) : _sessions.doc();
    await ref.set({
      'id': ref.id,
      'studentId': studentId,
      'studentName': studentName,
      'courseId': courseId,
      'manikinId': manikinId,
      'scenarioId': scenarioId,
      'scenarioTitle': scenarioTitle,
      'patientType': patientType,
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
      'endedAt': null,
      'duration': 0,
      'metrics': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> completeSession(
    String sessionId,
    SessionMetrics metrics,
    int durationSeconds,
  ) async {
    // Usamos set con merge: true para que si la sesión se creó offline
    // y el documento aún no existe en el servidor, se cree con los datos básicos.
    await _sessions.doc(sessionId).set({
      'status': 'completed',
      'endedAt': FieldValue.serverTimestamp(),
      'duration': durationSeconds,
      'metrics': metrics.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> abortSession(String sessionId) async {
    await _sessions.doc(sessionId).update({
      'status': 'aborted',
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<SessionModel?> getSession(String sessionId) async {
    final doc = await _sessions.doc(sessionId).get();
    if (!doc.exists) return null;
    return SessionModel.fromFirestore(doc);
  }

  Future<List<SessionModel>> getStudentSessions(String studentId,
      {int limit = 30}) async {
    final snap = await _sessions
        .where('studentId', isEqualTo: studentId)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(SessionModel.fromFirestore).toList();
  }

  Future<List<SessionModel>> getCourseSessions(String courseId,
      {int limit = 50}) async {
    final snap = await _sessions
        .where('courseId', isEqualTo: courseId)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(SessionModel.fromFirestore).toList();
  }

  Stream<List<SessionModel>> watchCourseActiveSessions(String courseId) {
    return _sessions
        .where('courseId', isEqualTo: courseId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs.map(SessionModel.fromFirestore).toList());
  }

  Future<void> addCompression(String sessionId, LiveSessionData data) async {
    await _sessions.doc(sessionId).collection('compressions').add({
      'timestamp': FieldValue.serverTimestamp(),
      'depthMm': data.depthMm,
      'forceKg': data.forceKg,
      'ratePerMin': data.ratePerMin,
      'decompressedFully': data.decompressedFully,
      'correct': data.correctPct >= 80,
    });
  }

  Future<void> addSessionAlert(String sessionId, AlertModel alert) async {
    await _sessions
        .doc(sessionId)
        .collection('alerts')
        .add(alert.toFirestore());
  }

  Future<void> addInstructorAlert(String instructorId, AlertModel alert) async {
    debugPrint('💾 Guardando alerta en users/$instructorId/alerts');
    await _userAlerts(instructorId).add(alert.toFirestore());
  }

  Future<List<AlertModel>> getInstructorAlerts(String instructorId,
      {int limit = 10}) async {
    final snap = await _userAlerts(instructorId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(AlertModel.fromFirestore).toList();
  }

  Stream<List<AlertModel>> watchInstructorAlerts(String instructorId,
      {int limit = 10}) {
    return _userAlerts(instructorId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(AlertModel.fromFirestore).toList());
  }

  Future<void> updateUserActivity(String uid) async {
    await _users.doc(uid).update({
      'lastActive': FieldValue.serverTimestamp(),
      'isOnline': true,
    });
  }

  Future<void> updateUserPresence(String uid, bool isOnline) async {
    await _users.doc(uid).update({
      'isOnline': isOnline,
      if (!isOnline) 'lastActive': FieldValue.serverTimestamp(),
    });
  }

  // --- Courses ---

  Future<CourseModel?> getCourse(String id) async {
    final doc = await _courses.doc(id).get();
    if (!doc.exists) return null;
    return CourseModel.fromFirestore(doc);
  }

  Future<String> createCourse({
    required String title,
    String? description,
    required String instructorId,
    required String instructorName,
    required String inviteCode,
    required String certification,
    double requiredScore = 85.0,
  }) async {
    final ref = _courses.doc();
    await ref.set({
      'id': ref.id,
      'title': title,
      'description': description ?? '',
      'instructorId': instructorId,
      'instructorName': instructorName,
      'inviteCode': inviteCode.toUpperCase(),
      'requiredScore': requiredScore,
      'certification': certification,
      'isActive': true,
      'studentCount': 0,
      'totalModules': 0,
      'completedModules': 0,
      'nextDeadline': null,
      'nextDeadlineTitle': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateCourse(String courseId, Map<String, dynamic> data) async {
    await _courses.doc(courseId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getInstructorStudents(
      List<String> courseIds) async {
    if (courseIds.isEmpty) return [];
    final allStudents = <String, Map<String, dynamic>>{};
    for (final cid in courseIds) {
      final snap = await _courses.doc(cid).collection('enrollments').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final sid = data['studentId'] as String;
        if (!allStudents.containsKey(sid)) {
          allStudents[sid] = {
            ...data,
            'sourceCourseId': cid, // Keep track of one course they are in
          };
        }
      }
    }
    return allStudents.values.toList();
  }

  Future<void> deleteCourse(String courseId) async {
    await _courses.doc(courseId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<CourseModel>> getInstructorCourses(String instructorId) async {
    final snap = await _courses
        .where('instructorId', isEqualTo: instructorId)
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.map(CourseModel.fromFirestore).toList();
  }

  Future<List<CourseModel>> getStudentCourses(String studentId) async {
    try {
      // Usamos serverAndCache para que Firebase use lo que tenga a mano sin quejarse
      final coursesSnap = await _courses
          .where('isActive', isEqualTo: true)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));

      final results = await Future.wait(coursesSnap.docs.map((courseDoc) async {
        try {
          final enrollSnap = await _courses
              .doc(courseDoc.id)
              .collection('enrollments')
              .doc(studentId)
              .get(const GetOptions(source: Source.serverAndCache))
              .timeout(const Duration(seconds: 3));

          if (enrollSnap.exists) {
            return CourseModel.fromFirestore(courseDoc);
          }
        } catch (_) {
          // Ignorar errores individuales (offline)
        }
        return null;
      }));

      return results.whereType<CourseModel>().toList();
    } catch (e) {
      debugPrint('Firestore Session Info: $e');
      return [];
    }
  }

  Future<List<CourseModel>> getAllCourses() async {
    final snap = await _courses.where('isActive', isEqualTo: true).get();
    return snap.docs.map(CourseModel.fromFirestore).toList();
  }

  Future<CourseModel?> getCourseByInviteCode(String code) async {
    final snap = await _courses
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return CourseModel.fromFirestore(snap.docs.first);
  }

  Future<void> enrollStudent({
    required String courseId,
    required String studentId,
    required String studentName,
    required String studentEmail,
    String? identificacion,
  }) async {
    final enrollRef =
        _courses.doc(courseId).collection('enrollments').doc(studentId);

    await enrollRef.set({
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'identificacion': identificacion,
      'enrolledAt': FieldValue.serverTimestamp(),
      'completedModules': 0,
      'avgScore': 0.0,
      'sessionCount': 0,
      'status': 'active',
    });

    // El incremento de studentCount en el documento del curso padre
    // suele fallar por permisos cuando lo hace un estudiante (QR).
    // Es mejor calcularlo dinámicamente o que lo actualice el instructor.
  }

  Future<List<Map<String, dynamic>>> getCourseStudents(String courseId) async {
    final snap = await _courses.doc(courseId).collection('enrollments').get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Stream<List<Map<String, dynamic>>> watchCourseStudents(String courseId) {
    return _courses
        .doc(courseId)
        .collection('enrollments')
        .orderBy('studentName')
        .snapshots()
        .asyncMap((snap) async {
      final enrollments = snap.docs.map((d) => d.data()).toList();
      // We could also fetch user status here if needed, or use a separate stream
      return enrollments;
    });
  }

  // To see real-time status of users (online/offline)
  Stream<List<UserModel>> watchUsersStatus(List<String> userIds) {
    if (userIds.isEmpty) return Stream.value([]);
    // Chunking might be needed if userIds > 30
    return _users
        .where(FieldPath.documentId, whereIn: userIds.take(30).toList())
        .snapshots()
        .map((snap) => snap.docs.map(UserModel.fromFirestore).toList());
  }

  Future<List<String>> getStudentEnrolledCourseIds(String studentId) async {
    final coursesSnap = await _courses.where('isActive', isEqualTo: true).get();
    final List<String> enrolledIds = [];
    for (final courseDoc in coursesSnap.docs) {
      final enrollSnap = await _courses
          .doc(courseDoc.id)
          .collection('enrollments')
          .doc(studentId)
          .get();
      if (enrollSnap.exists) {
        enrolledIds.add(courseDoc.id);
      }
    }
    return enrolledIds;
  }

  Future<void> updateEnrollmentProgress(
    String courseId,
    String studentId,
    SessionMetrics metrics,
  ) async {
    final enrollRef =
        _courses.doc(courseId).collection('enrollments').doc(studentId);
    final enrollSnap = await enrollRef.get();
    if (!enrollSnap.exists) return;

    final data = enrollSnap.data() as Map<String, dynamic>;
    int currentSessionCount = (data['sessionCount'] as num?)?.toInt() ?? 0;
    double currentAvgScore = (data['avgScore'] as num?)?.toDouble() ?? 0.0;

    // Calcular nuevo promedio
    double newAvgScore =
        ((currentAvgScore * currentSessionCount) + metrics.score) /
            (currentSessionCount + 1);

    await enrollRef.update({
      'sessionCount': FieldValue.increment(1),
      'avgScore': newAvgScore,
      'lastSessionDate': FieldValue.serverTimestamp(),
      if (metrics.approved) 'completedModules': FieldValue.increment(1),
    });
  }

  Future<List<ManiquiModel>> getManikins() async {
    final snap = await _manikins.get();
    return snap.docs.map(ManiquiModel.fromFirestore).toList();
  }

  Stream<List<ManiquiModel>> watchManikins() {
    return _manikins.snapshots().map(
          (snap) => snap.docs.map(ManiquiModel.fromFirestore).toList(),
        );
  }

  Future<void> updateManikinStatus(
    String manikinId,
    String status, {
    String? assignedTo,
    String? currentSessionId,
  }) async {
    await _manikins.doc(manikinId).update({
      'status': status,
      'assignedTo': assignedTo,
      'currentSessionId': currentSessionId,
      'lastConnection': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<ScenarioModel>> getScenarios() async {
    try {
      // Intentamos obtener de la nube con un timeout muy corto
      final snap = await _scenarios
          .orderBy('orderIndex')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 3));

      if (snap.docs.isEmpty) {
        return _localScenarios();
      }
      return snap.docs.map(ScenarioModel.fromFirestore).toList();
    } catch (e) {
      debugPrint('Usando escenarios locales por error de red: $e');
      return _localScenarios(); // Fallback inmediato
    }
  }

  List<ScenarioModel> _localScenarios() => [
        const ScenarioModel(
          id: 'paroCardiaco',
          title: 'Paro cardíaco en casa',
          description:
              'Familiar inconsciente en el suelo. Sin pulso ni respiración.',
          audioIntroText:
              'Adulto de 52 años. Sin pulso. Inicie RCP de inmediato.',
          patientAge: 'Adulto (52 años)',
          patientType: 'adult',
          category: ScenarioCategory.paroCardiaco,
          difficulty: 'medium',
          relatedGuideId: 'guide_001',
        ),
        const ScenarioModel(
          id: 'accidenteTransito',
          title: 'Accidente de tránsito',
          description: 'Víctima en la vía, sin respuesta. Múltiples traumas.',
          audioIntroText:
              'Adulto de 35 años. Accidente vial. Sin respuesta. Evalúa la escena.',
          patientAge: 'Adulto (35 años)',
          patientType: 'adult',
          category: ScenarioCategory.accidenteTransito,
          difficulty: 'hard',
        ),
        const ScenarioModel(
          id: 'ahogamiento',
          title: 'Ahogamiento en piscina',
          description:
              'Rescatado del agua. Protocolo especial: ventilaciones primero.',
          audioIntroText:
              'Adulto rescatado de la piscina. Sin respiración. Ventile primero.',
          patientAge: 'Adulto',
          patientType: 'adult',
          category: ScenarioCategory.ahogamiento,
          difficulty: 'hard',
          relatedGuideId: 'guide_005',
          isNew: true,
        ),
        const ScenarioModel(
          id: 'colapsoEjercicio',
          title: 'Colapso durante ejercicio',
          description:
              'Atleta en el gimnasio. Posible fibrilación ventricular.',
          audioIntroText:
              'Adulto de 28 años. Colapso en gimnasio. Usa el DEA disponible.',
          patientAge: 'Adulto (28 años)',
          patientType: 'adult',
          category: ScenarioCategory.colapsoEjercicio,
          difficulty: 'medium',
          relatedGuideId: 'guide_003',
          isNew: true,
        ),
        const ScenarioModel(
          id: 'atragantamiento',
          title: 'Atragantamiento severo',
          description:
              'Obstrucción de vía aérea. Heimlich + RCP si pierde el conocimiento.',
          audioIntroText:
              'Adulto. Atragantamiento durante cena. Aplica Heimlich primero.',
          patientAge: 'Adulto',
          patientType: 'adult',
          category: ScenarioCategory.atragantamiento,
          difficulty: 'medium',
        ),
        const ScenarioModel(
          id: 'descargaElectrica',
          title: 'Descarga eléctrica',
          description: 'Accidente laboral. Asegurar escena antes de actuar.',
          audioIntroText:
              'Adulto electrocutado. Asegura la escena. Sin pulso ni respiración.',
          patientAge: 'Adulto',
          patientType: 'adult',
          category: ScenarioCategory.descargaElectrica,
          difficulty: 'hard',
        ),
        const ScenarioModel(
          id: 'sobredosis',
          title: 'Sobredosis por opioides',
          description:
              'Intoxicación con respiración lenta. Naloxona + RCP si hay paro.',
          audioIntroText:
              'Adulto con sobredosis. Respiración muy lenta. Administra Naloxona si disponible.',
          patientAge: 'Adulto',
          patientType: 'adult',
          category: ScenarioCategory.sobredosis,
          difficulty: 'hard',
        ),
        const ScenarioModel(
          id: 'infarto',
          title: 'Infarto que evoluciona a paro',
          description:
              'Dolor torácico que evoluciona a paro cardíaco. Actúa rápido.',
          audioIntroText:
              'Adulto de 60 años. Dolor torácico severo. Ahora pierde el conocimiento.',
          patientAge: 'Adulto (60 años)',
          patientType: 'adult',
          category: ScenarioCategory.infarto,
          difficulty: 'hard',
          relatedGuideId: 'guide_002',
        ),
      ];
}
