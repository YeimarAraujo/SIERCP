import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/constants/clinical_scenarios.dart';
import 'package:siercp/core/models/support_ticket.dart';
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
  CollectionReference get _broadcasts => _db.collection('broadcasts');
  CollectionReference get _institutions => _db.collection('institutions');
  CollectionReference get _memberships => _db.collection('memberships');
  CollectionReference get _supportTickets =>
      _db.collection(AppConstants.colSupportTickets);

  CollectionReference _userAlerts(String userId) =>
      _users.doc(userId).collection('alerts');

  Future<void> createUser(UserModel user) async {
    await _users.doc(user.id).set({
      ...user.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _users
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8));
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error obteniendo usuario (intentando caché): $e');
      // Fallback a caché local. `Source.cache` LANZA (no devuelve un doc
      // inexistente) cuando no hay nada cacheado —p.ej. primer login en red
      // lenta—. Protegemos esa llamada para no propagar el error crudo y, si
      // tampoco hay caché, lanzamos un error de red claro en vez de devolver
      // null (que `login` interpretaría como "perfil no encontrado" y cerraría
      // la sesión de un usuario legítimo ante una caída transitoria).
      try {
        final cached =
            await _users.doc(uid).get(const GetOptions(source: Source.cache));
        if (cached.exists) return UserModel.fromFirestore(cached);
        return null;
      } catch (_) {
        throw Exception(
          'No se pudo cargar tu perfil. Verifica tu conexión e intenta de nuevo.',
        );
      }
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

  /// Solo para SUPER_ADMIN — devuelve todos los usuarios del sistema.
  /// Para admin de org usa TenantService.getOrgMembers().
  Future<List<UserModel>> getAllUsers() async {
    final snap = await _users.orderBy('firstName').get();
    return snap.docs.map(UserModel.fromFirestore).toList();
  }

  /// Usuarios filtrados por rol Y por org (via memberships).
  /// Úsalo directamente solo cuando ya tengas la lista de userIds de la org.
  Future<List<UserModel>> getUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final List<UserModel> result = [];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      final snap =
          await _users.where(FieldPath.documentId, whereIn: chunk).get();
      result.addAll(snap.docs.map(UserModel.fromFirestore));
    }
    return result;
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

  // SECURITY (MED-03): Accepts only safe, non-privileged fields.
  // Sensitive fields (role, certVerification, isActive, accountStatus) must be
  // changed only via Cloud Functions or explicit typed methods below.
  static const _allowedUserUpdateFields = {
    'firstName',
    'lastName',
    'phoneNumber',
    'avatarUrl',
    'identificacion',
    'bio',
    'isOnline',
    'lastActive',
    'coursesCreated',
    'stats',
    'language',
    'timezone',
  };

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    final safeData = Map<String, dynamic>.fromEntries(
      data.entries.where((e) => _allowedUserUpdateFields.contains(e.key)),
    );
    if (safeData.isEmpty) return;
    await _users.doc(uid).update({
      ...safeData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Privileged update — call only from trusted admin/SuperAdmin flows.
  Future<void> updateUserPrivileged(
    String uid, {
    String? role,
    String? certVerification,
    bool? isActive,
    String? accountStatus,
  }) async {
    final data = <String, dynamic>{};
    if (role != null) data['role'] = role;
    if (certVerification != null) data['certVerification'] = certVerification;
    if (isActive != null) data['isActive'] = isActive;
    if (accountStatus != null) data['accountStatus'] = accountStatus;
    if (data.isEmpty) return;
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
    // ID determinístico requerido por Firestore Security Rules.
    final deterministicId = '${userId}_$institutionId';
    final ref = _memberships.doc(deterministicId);
    await ref.set({
      'id': deterministicId,
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

  /// Stream del documento crudo del usuario. Necesario para los broadcasts:
  /// `role` e `institutionId` no están en UserModel, y `lastBroadcastSeenAt`
  /// determina el estado de lectura de los anuncios.
  Stream<Map<String, dynamic>> watchUserDocRaw(String userId) {
    return _users
        .doc(userId)
        .snapshots()
        .map((d) => d.data() as Map<String, dynamic>? ?? <String, dynamic>{});
  }

  /// Anuncios masivos filtrados por la audiencia del usuario. El filtrado por
  /// audiencia es en cliente (diseño "doc global + filtro en app").
  Stream<List<NotificationModel>> watchBroadcasts({
    String? role,
    String? institutionId,
    DateTime? lastSeen,
  }) {
    return _broadcasts
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .where((d) {
              final data = d.data() as Map<String, dynamic>;
              final audience = data['audience'];
              if (audience == 'all') return true;
              if (audience == 'role') {
                return role != null && data['role'] == role;
              }
              if (audience == 'institution') {
                return institutionId != null &&
                    data['institutionId'] == institutionId;
              }
              return false;
            })
            .map((d) => NotificationModel.fromBroadcast(d, lastSeen: lastSeen))
            .toList());
  }

  /// Marca todos los broadcasts como leídos hasta ahora (sello por usuario).
  Future<void> markBroadcastsSeen(String userId) async {
    await _users.doc(userId).set(
      {'lastBroadcastSeenAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
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

  // --- Support Tickets ---

  Future<SupportTicket> createSupportTicket(SupportTicket ticket) async {
    final ref = _supportTickets.doc();
    final t = ticket.copyWith();
    await ref.set({...t.toFirestore(), 'id': ref.id});
    return SupportTicket.fromFirestore(await ref.get());
  }

  Stream<List<SupportTicket>> watchSupportTickets({TicketStatus? status}) {
    var q = _supportTickets.orderBy('createdAt', descending: true);
    if (status != null) {
      q = _supportTickets
          .where('status', isEqualTo: status.name)
          .orderBy('createdAt', descending: true);
    }
    return q
        .snapshots()
        .map((s) => s.docs.map(SupportTicket.fromFirestore).toList());
  }

  Future<void> respondToTicket({
    required String ticketId,
    required String response,
    required String respondedBy,
  }) async {
    await _supportTickets.doc(ticketId).update({
      'response': response,
      'respondedBy': respondedBy,
      'status': TicketStatus.resolved.name,
      'respondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTicketStatus(String ticketId, TicketStatus status) async {
    await _supportTickets.doc(ticketId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- User Certificates (SuperAdmin verification) ---

  Stream<List<UserCertificate>> watchPendingCertificates() {
    return _db
        .collection(AppConstants.colUserCertificates)
        .where('verificationStatus',
            isEqualTo: CertVerificationStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(UserCertificate.fromFirestore).toList());
  }

  Future<void> approveCertificate(String certId, String approvedBy) async {
    final batch = _db.batch();
    final certRef =
        _db.collection(AppConstants.colUserCertificates).doc(certId);
    final certSnap = await certRef.get();
    final userId = certSnap.data()?['userId'] as String?;

    batch.update(certRef, {
      'verificationStatus': CertVerificationStatus.approved.name,
      'approvedBy': approvedBy,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    if (userId != null) {
      batch.update(_users.doc(userId), {
        'certVerification': CertVerificationStatus.approved.name,
        'role': AppConstants.roleInstructor,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> rejectCertificate(
      String certId, String rejectedBy, String reason) async {
    await _db.collection(AppConstants.colUserCertificates).doc(certId).update({
      'verificationStatus': CertVerificationStatus.rejected.name,
      'rejectionReason': reason,
      'rejectedBy': rejectedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitCertificateForVerification({
    required String userId,
    required String type,
    required String issuer,
    required String certificateNumber,
    required String issueDate,
    String? expiryDate,
    required String fileUrl,
  }) async {
    final ref = _db.collection(AppConstants.colUserCertificates).doc();
    await ref.set({
      'id': ref.id,
      'userId': userId,
      'type': type,
      'issuer': issuer,
      'certificateNumber': certificateNumber,
      'issueDate': issueDate,
      'expiryDate': expiryDate,
      'fileUrl': fileUrl,
      'verificationStatus': CertVerificationStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _users.doc(userId).update({
      'certVerification': CertVerificationStatus.pending.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- Sessions ---

  String getNewSessionId() => _sessions.doc().id;

  static String _classId(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  /// Marca la asistencia de un estudiante en una clase (fecha).
  ///
  /// MODELO CANÓNICO unificado con la Web: un doc PLANO por (estudiante, clase)
  /// en `courses/{courseId}/attendance/{studentId}__{classId}` con `status`
  /// (present/absent/late/excused). Tras marcar, recalcula `attendanceRate` en la
  /// matrícula, que alimenta el gating de certificación (igual que el servidor).
  Future<void> markAttendance({
    required String courseId,
    required String studentId,
    required String studentName,
    required bool attended,
    required DateTime date,
    String? status, // 'present'|'absent'|'late'|'excused' (anula `attended`)
  }) async {
    final classId = _classId(date);
    final st = status ?? (attended ? 'present' : 'absent');
    final ref = _courses
        .doc(courseId)
        .collection('attendance')
        .doc('${studentId}__$classId');

    await ref.set({
      'courseId': courseId,
      'classId': classId,
      'classLabel': 'Clase $classId',
      'studentId': studentId,
      'studentName': studentName,
      'status': st,
      'attended': st == 'present' || st == 'late', // compat de lectura
      'mode': 'presencial',
      'date': Timestamp.fromDate(date),
      'markedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      'markedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _recomputeAttendanceSummary(courseId, studentId);
  }

  /// Recalcula y persiste el resumen de asistencia del estudiante en su matrícula.
  /// present+late cuentan; excused se excluye del denominador; absent penaliza.
  Future<void> _recomputeAttendanceSummary(
      String courseId, String studentId) async {
    final snap = await _courses
        .doc(courseId)
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .get();
    int present = 0, late = 0, absent = 0, excused = 0;
    for (final d in snap.docs) {
      switch ((d.data())['status']) {
        case 'present':
          present++;
          break;
        case 'late':
          late++;
          break;
        case 'excused':
          excused++;
          break;
        default:
          absent++;
      }
    }
    final attended = present + late;
    final total = present + late + absent; // excused excluido
    final rate = total > 0 ? ((attended / total) * 100).round() : 100;
    await _courses.doc(courseId).collection('enrollments').doc(studentId).set({
      'attendanceRate': rate,
      'attendancePresent': attended,
      'attendanceTotal': total,
      'attendanceExcused': excused,
      'attendanceUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> watchAttendance(
      String courseId, DateTime date) {
    final classId = _classId(date);
    return _courses
        .doc(courseId)
        .collection('attendance')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final m = d.data();
              final status = (m['status'] as String?) ??
                  ((m['attended'] == true) ? 'present' : 'absent');
              return {
                'studentId': m['studentId'],
                'studentName': m['studentName'],
                'status': status,
                'attended':
                    m['attended'] ?? (status == 'present' || status == 'late'),
              };
            }).toList());
  }

  Stream<List<Map<String, dynamic>>> watchCourseAttendanceHistory(
      String courseId) {
    return _courses
        .doc(courseId)
        .collection('attendance')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
            (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<String> createSession({
    String? id,
    required String studentId,
    required String studentName,
    required String scenarioId,
    required String scenarioTitle,
    required String patientType,
    // institutionId es null para sesiones de práctica libre (sin org).
    // Firestore rules §11 permite sesiones con institutionId == null o ''.
    // NO pasar cadena vacía '' — se omite el campo cuando no hay org activa
    // para que la regla `!('institutionId' in request.resource.data)` aplique.
    String? institutionId,
    String? courseId,
    String? manikinId,
  }) async {
    final ref = id != null ? _sessions.doc(id) : _sessions.doc();
    await ref.set(<String, dynamic>{
      'id': ref.id,
      'studentId': studentId,
      'studentName': studentName,
      'courseId': courseId,
      'manikinId': manikinId,
      'scenarioId': scenarioId,
      'scenarioTitle': scenarioTitle,
      'patientType': patientType,
      // Solo incluir institutionId si hay org activa; omitirlo activa la
      // rama de "sesión libre" en las Firestore rules sin dejar '' huérfano.
      if (institutionId != null && institutionId.isNotEmpty)
        'institutionId': institutionId,
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

  Future<List<SessionModel>> getStudentSessions(
    String studentId, {
    int limit = 30,
  }) async {
    try {
      final snap = await _sessions
          .where('studentId', isEqualTo: studentId)
          .orderBy('startedAt', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map(SessionModel.fromFirestore).toList();
    } catch (e, st) {
      // Degradar a lista vacía en vez de propagar. Dos casos reales:
      //  1) Logout: el provider sigue vivo un instante sin auth → PERMISSION_DENIED.
      //  2) Instructor-por-membership (rol global USUARIO) viendo las sesiones de
      //     un alumno: las rules §11 exigen rol global instructor/admin.
      // En ambos, una pantalla de historial vacía es preferible a una excepción.
      debugPrint('getStudentSessions sin permiso/error (degradado a []): $e');
      debugPrintStack(stackTrace: st);
      return const [];
    }
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

  Future<void> addSessionAlert(String sessionId, AlertModel alert) async {
    await _sessions
        .doc(sessionId)
        .collection('alerts')
        .add(alert.toFirestore());
  }

  Future<void> addInstructorAlert(String instructorId, AlertModel alert) async {
    debugPrint('Guardando alerta en users/$instructorId/alerts');
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
    String? institutionId, // requerido para tenant isolation
  }) async {
    final ref = _courses.doc();
    await ref.set({
      'id': ref.id,
      'title': title,
      'description': description ?? '',
      'instructorId': instructorId,
      // `createdBy` e `instructorIds` (modelo nuevo) son los campos que las
      // Firestore rules §10 exigen para autorizar la CREACIÓN por un instructor
      // (`createdBy == uid()`) y la ruta de UPDATE del dueño. Sin ellos un
      // instructor-por-membership (rol global USUARIO) no podía crear ni editar
      // su propio curso. `isInstructorOfCourse` también los usa para autorizar
      // asistencia e inscripciones.
      'createdBy': instructorId,
      'instructorIds': [instructorId],
      'instructorName': instructorName,
      'inviteCode': inviteCode.toUpperCase(),
      'requiredScore': requiredScore,
      'certification': certification,
      'institutionId': institutionId, // tenant field
      'isActive': true,
      'studentCount': 0,
      'totalModules': 0,
      'completedModules': 0,
      'nextDeadline': null,
      'nextDeadlineTitle': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _users.doc(instructorId).update({
      'coursesCreated': FieldValue.increment(1),
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

  /// Elimina la inscripción de un alumno en un curso.
  ///
  /// El conteo de alumnos se deriva en vivo (count() sobre la subcolección
  /// enrollments) en los paneles de la web, por lo que NO decrementamos el
  /// contador denormalizado studentCount: hacerlo lo volvía negativo, ya que
  /// las inscripciones por QR no lo incrementan pero las bajas sí restaban.
  Future<void> unenrollStudent(String courseId, String studentId) async {
    await _db
        .collection(AppConstants.colCourses)
        .doc(courseId)
        .collection(AppConstants.subColEnrollments)
        .doc(studentId)
        .delete();
  }

  /// Asigna un instructor a un curso.
  /// Actualiza instructorId (primario) y agrega a instructorIds[] si no está.
  Future<void> assignInstructor(
      String courseId, String instructorId, String instructorName) async {
    await _courses.doc(courseId).update({
      'instructorId': instructorId,
      'instructorName': instructorName,
      'instructorIds': FieldValue.arrayUnion([instructorId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Agrega un instructor adicional (sin cambiar el primario).
  Future<void> addInstructor(String courseId, String instructorId) async {
    await _courses.doc(courseId).update({
      'instructorIds': FieldValue.arrayUnion([instructorId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Quita un instructor del array instructorIds (no cambia el primario).
  Future<void> removeInstructor(String courseId, String instructorId) async {
    await _courses.doc(courseId).update({
      'instructorIds': FieldValue.arrayRemove([instructorId]),
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

  // HIGH-06 fix: replaced the N+1 full-collection scan with a collectionGroup
  // query that searches all `enrollments` subcollections in one indexed read.
  // Previously: fetched ALL active courses → 1 read/course (O(n) Firestore reads).
  // Now: single collectionGroup query → batch fetch only enrolled course docs.
  // Requires a Firestore collectionGroup index on `enrollments` field `studentId`.
  Future<List<CourseModel>> getStudentCourses(String studentId) async {
    try {
      // Step 1: find all enrollment docs for this student across all courses.
      final enrollSnap = await _db
          .collectionGroup(AppConstants.subColEnrollments)
          .where('studentId', isEqualTo: studentId)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));

      if (enrollSnap.docs.isEmpty) return [];

      // Step 2: extract course IDs from enrollment doc paths (parent doc id).
      final courseIds = enrollSnap.docs
          .map((d) => d.reference.parent.parent?.id)
          .whereType<String>()
          .toSet()
          .toList();

      if (courseIds.isEmpty) return [];

      // Step 3: batch-fetch only the enrolled course documents.
      final courses = <CourseModel>[];
      for (var i = 0; i < courseIds.length; i += 30) {
        final chunk = courseIds.sublist(i, (i + 30).clamp(0, courseIds.length));
        final snap = await _courses
            .where(FieldPath.documentId, whereIn: chunk)
            .where('isActive', isEqualTo: true)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 5));
        courses.addAll(snap.docs.map(CourseModel.fromFirestore));
      }
      return courses;
    } catch (e) {
      debugPrint('[FirestoreService] getStudentCourses error: $e');
      return [];
    }
  }

  /// Solo para SUPER_ADMIN — retorna todos los cursos del sistema.
  /// Para admin de org usa TenantService.getOrgCourses().
  Future<List<CourseModel>> getAllCourses() async {
    final snap = await _courses.where('isActive', isEqualTo: true).get();
    return snap.docs.map(CourseModel.fromFirestore).toList();
  }

  Future<List<CourseModel>> getCoursesByInstitution(
      String institutionId) async {
    final snap = await _courses
        .where('institutionId', isEqualTo: institutionId)
        .where('isActive', isEqualTo: true)
        .get();
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
        .map((snap) => snap.docs.map((d) => d.data()).toList())
        // La lista de inscritos es OPCIONAL para la UI: si el caller no está
        // asignado al curso (rules §11: no es admin/instructor del curso) o el
        // doc del curso es antiguo y carece de createdBy/instructorIds, la query
        // a /enrollments lanza PERMISSION_DENIED. Degradamos a vacío en vez de
        // propagar al árbol de widgets (mismo patrón que watchUsersStatus).
        .handleError((Object e) {
      debugPrint('watchCourseStudents sin permiso/error (degradado a []): $e');
    });
  }

  // To see real-time status of users (online/offline)
  Stream<List<UserModel>> watchUsersStatus(List<String> userIds) {
    if (userIds.isEmpty) return Stream.value([]);
    // Chunking might be needed if userIds > 30
    return _users
        .where(FieldPath.documentId, whereIn: userIds.take(30).toList())
        .snapshots()
        .map((snap) => snap.docs.map(UserModel.fromFirestore).toList())
        // La presencia (punto "en línea") es OPCIONAL. Un instructor-por-
        // membership (rol global USUARIO) no puede leer /users de otros por las
        // rules §7; durante el logout tampoco hay auth. En ambos casos emitimos
        // vacío en lugar de propagar PERMISSION_DENIED al árbol de widgets.
        .handleError((Object e) {
          debugPrint('watchUsersStatus sin permiso/error (sin presencia): $e');
        });
  }

  Future<List<String>> getStudentEnrolledCourseIds(String studentId) async {
    final enrollSnap = await _db
        .collectionGroup(AppConstants.subColEnrollments)
        .where('studentId', isEqualTo: studentId)
        .get();
    return enrollSnap.docs
        .map((d) => d.reference.parent.parent?.id)
        .whereType<String>()
        .toList();
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
      final snap = await _scenarios
          .orderBy('orderIndex')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 3));

      if (snap.docs.isEmpty) return _localScenarios();
      return snap.docs.map(ScenarioModel.fromFirestore).toList();
    } catch (e) {
      debugPrint('Usando escenarios locales por error de red: $e');
      return _localScenarios();
    }
  }

  // Fallback estático: usa la lista maestra centralizada de clinical_scenarios.dart.
  List<ScenarioModel> _localScenarios() =>
      kClinicalScenarios.map((s) => s.toScenarioModel()).toList();
}
