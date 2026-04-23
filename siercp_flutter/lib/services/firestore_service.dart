import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../models/session.dart';
import '../models/alert_course.dart';
import '../models/maniqui.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Refs ───────────────────────────────────────────────────────────────────
  CollectionReference get _users     => _db.collection('users');
  CollectionReference get _sessions  => _db.collection('sessions');
  CollectionReference get _courses   => _db.collection('courses');
  CollectionReference get _manikins  => _db.collection('manikins');
  CollectionReference get _scenarios => _db.collection('scenarios');

  // ══════════════════════════════════════════════════════════════════════════
  //  USUARIOS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> createUser(UserModel user) async {
    await _users.doc(user.id).set(user.toFirestore());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
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
    final snap = await _users
        .where('identificacion', isEqualTo: cedula)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return UserModel.fromFirestore(snap.docs.first);
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

  // ══════════════════════════════════════════════════════════════════════════
  //  SESIONES
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> createSession({
    required String studentId,
    required String studentName,
    required String scenarioId,
    required String scenarioTitle,
    required String patientType,
    String? courseId,
    String? manikinId,
  }) async {
    final ref = _sessions.doc();
    await ref.set({
      'id':            ref.id,
      'studentId':     studentId,
      'studentName':   studentName,
      'courseId':      courseId,
      'manikinId':     manikinId,
      'scenarioId':    scenarioId,
      'scenarioTitle': scenarioTitle,
      'patientType':   patientType,
      'status':        'active',
      'startedAt':     FieldValue.serverTimestamp(),
      'endedAt':       null,
      'duration':      0,
      'metrics':       null,
      'createdAt':     FieldValue.serverTimestamp(),
      'updatedAt':     FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> completeSession(
    String sessionId,
    SessionMetrics metrics,
    int durationSeconds,
  ) async {
    await _sessions.doc(sessionId).update({
      'status':    'completed',
      'endedAt':   FieldValue.serverTimestamp(),
      'duration':  durationSeconds,
      'metrics':   metrics.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> abortSession(String sessionId) async {
    await _sessions.doc(sessionId).update({
      'status':    'aborted',
      'endedAt':   FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<SessionModel?> getSession(String sessionId) async {
    final doc = await _sessions.doc(sessionId).get();
    if (!doc.exists) return null;
    return SessionModel.fromFirestore(doc);
  }

  Future<List<SessionModel>> getStudentSessions(String studentId, {int limit = 30}) async {
    final snap = await _sessions
        .where('studentId', isEqualTo: studentId)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(SessionModel.fromFirestore).toList();
  }

  Future<List<SessionModel>> getCourseSessions(String courseId, {int limit = 50}) async {
    final snap = await _sessions
        .where('courseId', isEqualTo: courseId)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(SessionModel.fromFirestore).toList();
  }

  Future<void> addCompression(String sessionId, LiveSessionData data) async {
    await _sessions.doc(sessionId).collection('compressions').add({
      'timestamp':       FieldValue.serverTimestamp(),
      'depthMm':         data.depthMm,
      'forceKg':         data.forceKg,
      'ratePerMin':      data.ratePerMin,
      'decompressedFully': data.decompressedFully,
      'correct':         data.correctPct >= 80,
    });
  }

  Future<void> addSessionAlert(String sessionId, AlertModel alert) async {
    await _sessions.doc(sessionId).collection('alerts').add(alert.toFirestore());
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CURSOS
  // ══════════════════════════════════════════════════════════════════════════

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
      'id':             ref.id,
      'title':          title,
      'description':    description ?? '',
      'instructorId':   instructorId,
      'instructorName': instructorName,
      'inviteCode':     inviteCode.toUpperCase(),
      'requiredScore':  requiredScore,
      'certification':  certification,
      'isActive':       true,
      'studentCount':   0,
      'totalModules':   0,
      'completedModules': 0,
      'nextDeadline':   null,
      'nextDeadlineTitle': null,
      'createdAt':      FieldValue.serverTimestamp(),
      'updatedAt':      FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<List<CourseModel>> getInstructorCourses(String instructorId) async {
    final snap = await _courses
        .where('instructorId', isEqualTo: instructorId)
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.map(CourseModel.fromFirestore).toList();
  }

  Future<List<CourseModel>> getStudentCourses(String studentId) async {
    // Busca todos los cursos donde el estudiante está inscrito
    final coursesSnap = await _courses.where('isActive', isEqualTo: true).get();
    final result = <CourseModel>[];
    for (final courseDoc in coursesSnap.docs) {
      final enrollRef = _courses
          .doc(courseDoc.id)
          .collection('enrollments')
          .doc(studentId);
      final enroll = await enrollRef.get();
      if (enroll.exists) {
        result.add(CourseModel.fromFirestore(courseDoc));
      }
    }
    return result;
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
    final batch = _db.batch();

    final enrollRef = _courses
        .doc(courseId)
        .collection('enrollments')
        .doc(studentId);
    batch.set(enrollRef, {
      'studentId':     studentId,
      'studentName':   studentName,
      'studentEmail':  studentEmail,
      'identificacion': identificacion,
      'enrolledAt':    FieldValue.serverTimestamp(),
      'completedModules': 0,
      'avgScore':      0.0,
      'sessionCount':  0,
      'status':        'active',
    });

    batch.update(_courses.doc(courseId), {
      'studentCount': FieldValue.increment(1),
      'updatedAt':    FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getCourseStudents(String courseId) async {
    final snap = await _courses
        .doc(courseId)
        .collection('enrollments')
        .get();
    return snap.docs.map((d) => d.data()).toList();
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
    final enrollRef = _courses.doc(courseId).collection('enrollments').doc(studentId);
    final enrollSnap = await enrollRef.get();
    if (!enrollSnap.exists) return;

    final data = enrollSnap.data() as Map<String, dynamic>;
    int currentSessionCount = (data['sessionCount'] as num?)?.toInt() ?? 0;
    double currentAvgScore = (data['avgScore'] as num?)?.toDouble() ?? 0.0;

    // Calcular nuevo promedio
    double newAvgScore = ((currentAvgScore * currentSessionCount) + metrics.score) / (currentSessionCount + 1);

    await enrollRef.update({
      'sessionCount': FieldValue.increment(1),
      'avgScore': newAvgScore,
      'lastSessionDate': FieldValue.serverTimestamp(),
      if (metrics.approved) 'completedModules': FieldValue.increment(1),
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MANIQUÍES
  // ══════════════════════════════════════════════════════════════════════════

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
      'status':           status,
      'assignedTo':       assignedTo,
      'currentSessionId': currentSessionId,
      'lastConnection':   FieldValue.serverTimestamp(),
      'updatedAt':        FieldValue.serverTimestamp(),
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ESCENARIOS
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<ScenarioModel>> getScenarios() async {
    final snap = await _scenarios.orderBy('orderIndex').get();
    if (snap.docs.isEmpty) {
      // Fallback a escenarios locales si Firestore aún no tiene datos
      return _localScenarios();
    }
    return snap.docs.map(ScenarioModel.fromFirestore).toList();
  }

  List<ScenarioModel> _localScenarios() => [
    const ScenarioModel(
      id: 'paroCardiaco',
      title: '🏠 Paro cardíaco en casa',
      description: 'Familiar inconsciente en el suelo. Sin pulso ni respiración.',
      audioIntroText: 'Adulto de 52 años. Sin pulso. Inicie RCP de inmediato.',
      patientAge: 'Adulto (52 años)',
      patientType: 'adult',
      category: ScenarioCategory.paroCardiaco,
      difficulty: 'medium',
      relatedGuideId: 'guide_001',
    ),
    const ScenarioModel(
      id: 'accidenteTransito',
      title: '🚗 Accidente de tránsito',
      description: 'Víctima en la vía, sin respuesta. Múltiples traumas.',
      audioIntroText: 'Adulto de 35 años. Accidente vial. Sin respuesta. Evalúa la escena.',
      patientAge: 'Adulto (35 años)',
      patientType: 'adult',
      category: ScenarioCategory.accidenteTransito,
      difficulty: 'hard',
    ),
    const ScenarioModel(
      id: 'ahogamiento',
      title: '🌊 Ahogamiento en piscina',
      description: 'Rescatado del agua. Protocolo especial: ventilaciones primero.',
      audioIntroText: 'Adulto rescatado de la piscina. Sin respiración. Ventile primero.',
      patientAge: 'Adulto',
      patientType: 'adult',
      category: ScenarioCategory.ahogamiento,
      difficulty: 'hard',
      relatedGuideId: 'guide_005',
      isNew: true,
    ),
    const ScenarioModel(
      id: 'colapsoEjercicio',
      title: '🏋️ Colapso durante ejercicio',
      description: 'Atleta en el gimnasio. Posible fibrilación ventricular.',
      audioIntroText: 'Adulto de 28 años. Colapso en gimnasio. Usa el DEA disponible.',
      patientAge: 'Adulto (28 años)',
      patientType: 'adult',
      category: ScenarioCategory.colapsoEjercicio,
      difficulty: 'medium',
      relatedGuideId: 'guide_003',
      isNew: true,
    ),
    const ScenarioModel(
      id: 'atragantamiento',
      title: '🍽️ Atragantamiento severo',
      description: 'Obstrucción de vía aérea. Heimlich + RCP si pierde el conocimiento.',
      audioIntroText: 'Adulto. Atragantamiento durante cena. Aplica Heimlich primero.',
      patientAge: 'Adulto',
      patientType: 'adult',
      category: ScenarioCategory.atragantamiento,
      difficulty: 'medium',
    ),
    const ScenarioModel(
      id: 'descargaElectrica',
      title: '⚡ Descarga eléctrica',
      description: 'Accidente laboral. Asegurar escena antes de actuar.',
      audioIntroText: 'Adulto electrocutado. Asegura la escena. Sin pulso ni respiración.',
      patientAge: 'Adulto',
      patientType: 'adult',
      category: ScenarioCategory.descargaElectrica,
      difficulty: 'hard',
    ),
    const ScenarioModel(
      id: 'sobredosis',
      title: '🛏️ Sobredosis por opioides',
      description: 'Intoxicación con respiración lenta. Naloxona + RCP si hay paro.',
      audioIntroText: 'Adulto con sobredosis. Respiración muy lenta. Administra Naloxona si disponible.',
      patientAge: 'Adulto',
      patientType: 'adult',
      category: ScenarioCategory.sobredosis,
      difficulty: 'hard',
    ),
    const ScenarioModel(
      id: 'infarto',
      title: '🚨 Infarto que evoluciona a paro',
      description: 'Dolor torácico que evoluciona a paro cardíaco. Actúa rápido.',
      audioIntroText: 'Adulto de 60 años. Dolor torácico severo. Ahora pierde el conocimiento.',
      patientAge: 'Adulto (60 años)',
      patientType: 'adult',
      category: ScenarioCategory.infarto,
      difficulty: 'hard',
      relatedGuideId: 'guide_002',
    ),
  ];
}
