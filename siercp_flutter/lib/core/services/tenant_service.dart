import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/models/institution.dart';
import 'package:siercp/core/models/membership.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/features/courses/data/models/alert_course.dart';
import 'package:siercp/features/session/data/models/session.dart';
import 'package:siercp/features/users/data/models/user.dart';

// ── Modelo combinado: usuario + su rol en la org ──────────────────────────────

class OrgMember {
  final UserModel user;
  final MembershipModel membership;

  const OrgMember({required this.user, required this.membership});

  String get role => membership.role;
  String get membershipId => membership.id;
  bool get isActive => membership.isActive && user.isActive;
}

// ── Analytics de la org ───────────────────────────────────────────────────────

class OrgAnalytics {
  final int totalMembers;
  final int activeMembers;
  final int totalCourses;
  final int activeSessions;
  final int sessionsThisMonth;
  final int certificatesThisMonth;
  final double avgSessionScore;

  const OrgAnalytics({
    this.totalMembers = 0,
    this.activeMembers = 0,
    this.totalCourses = 0,
    this.activeSessions = 0,
    this.sessionsThisMonth = 0,
    this.certificatesThisMonth = 0,
    this.avgSessionScore = 0.0,
  });
}

// ── Servicio principal ────────────────────────────────────────────────────────

/// Todas las queries están filtradas por [institutionId].
/// NUNCA devuelve datos fuera del tenant activo.
class TenantService {
  final FirebaseFirestore _db;
  final String institutionId;

  TenantService({required this.institutionId})
      : _db = FirebaseFirestore.instance;

  // ── Memberships ───────────────────────────────────────────────────────────

  Future<List<MembershipModel>> getOrgMemberships({
    String? role,
    bool onlyActive = true,
  }) async {
    var q = _db
        .collection(AppConstants.colMemberships)
        .where('institutionId', isEqualTo: institutionId);
    if (onlyActive) q = q.where('isActive', isEqualTo: true);
    if (role != null) q = q.where('role', isEqualTo: role);
    final snap = await q.get();
    return snap.docs.map(MembershipModel.fromFirestore).toList();
  }

  Stream<List<MembershipModel>> watchOrgMemberships({String? role}) {
    var q = _db
        .collection(AppConstants.colMemberships)
        .where('institutionId', isEqualTo: institutionId)
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: 'approved');
    if (role != null) q = q.where('role', isEqualTo: role);
    return q.snapshots().map(
          (s) => s.docs.map(MembershipModel.fromFirestore).toList(),
        );
  }

  // ── Usuarios de la org (memberships + datos de usuario) ───────────────────

  /// Retorna lista de [OrgMember] (membership + UserModel) para la org activa.
  Future<List<OrgMember>> getOrgMembers({String? role}) async {
    final memberships = await getOrgMemberships(role: role);
    if (memberships.isEmpty) return [];

    final userIds =
        memberships.map((m) => m.userId).where((id) => id.isNotEmpty).toList();

    final users = await _fetchUsersByIds(userIds);
    final userMap = {for (final u in users) u.id: u};

    return memberships
        .where((m) => userMap.containsKey(m.userId))
        .map((m) => OrgMember(user: userMap[m.userId]!, membership: m))
        .toList();
  }

  Stream<List<OrgMember>> watchOrgMembers({String? role}) {
    return watchOrgMemberships(role: role).asyncMap((memberships) async {
      if (memberships.isEmpty) return [];
      final userIds =
          memberships.map((m) => m.userId).where((id) => id.isNotEmpty).toList();
      final users = await _fetchUsersByIds(userIds);
      final userMap = {for (final u in users) u.id: u};
      return memberships
          .where((m) => userMap.containsKey(m.userId))
          .map((m) => OrgMember(user: userMap[m.userId]!, membership: m))
          .toList();
    });
  }

  Future<MembershipModel?> getMembershipForUser(String userId) async {
    final snap = await _db
        .collection(AppConstants.colMemberships)
        .where('institutionId', isEqualTo: institutionId)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return MembershipModel.fromFirestore(snap.docs.first);
  }

  Future<bool> isMember(String userId) async {
    return await getMembershipForUser(userId) != null;
  }

  // ── Cursos de la org ──────────────────────────────────────────────────────

  Future<List<CourseModel>> getOrgCourses({String? instructorId}) async {
    var q = _db
        .collection(AppConstants.colCourses)
        .where('institutionId', isEqualTo: institutionId)
        .where('isActive', isEqualTo: true);
    if (instructorId != null) {
      q = q.where('instructorId', isEqualTo: instructorId);
    }
    final snap = await q.orderBy('createdAt', descending: true).get();
    return snap.docs.map(CourseModel.fromFirestore).toList();
  }

  Stream<List<CourseModel>> watchOrgCourses() {
    return _db
        .collection(AppConstants.colCourses)
        .where('institutionId', isEqualTo: institutionId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(CourseModel.fromFirestore).toList());
  }

  // ── Sesiones de la org ────────────────────────────────────────────────────

  Future<List<SessionModel>> getOrgSessions({int limit = 50}) async {
    final snap = await _db
        .collection(AppConstants.colSessions)
        .where('institutionId', isEqualTo: institutionId)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(SessionModel.fromFirestore).toList();
  }

  Stream<List<SessionModel>> watchOrgActiveSessions() {
    return _db
        .collection(AppConstants.colSessions)
        .where('institutionId', isEqualTo: institutionId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((s) => s.docs.map(SessionModel.fromFirestore).toList());
  }

  // ── Analytics básicos de la org ───────────────────────────────────────────

  Future<OrgAnalytics> getOrgAnalytics() async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month);

      final results = await Future.wait([
        // total memberships activas
        _db
            .collection(AppConstants.colMemberships)
            .where('institutionId', isEqualTo: institutionId)
            .where('isActive', isEqualTo: true)
            .count()
            .get(),
        // cursos activos
        _db
            .collection(AppConstants.colCourses)
            .where('institutionId', isEqualTo: institutionId)
            .where('isActive', isEqualTo: true)
            .count()
            .get(),
        // sesiones este mes
        _db
            .collection(AppConstants.colSessions)
            .where('institutionId', isEqualTo: institutionId)
            .where('startedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
            .count()
            .get(),
        // sesiones activas ahora
        _db
            .collection(AppConstants.colSessions)
            .where('institutionId', isEqualTo: institutionId)
            .where('status', isEqualTo: 'active')
            .count()
            .get(),
      ]);

      return OrgAnalytics(
        totalMembers:        results[0].count ?? 0,
        totalCourses:        results[1].count ?? 0,
        sessionsThisMonth:   results[2].count ?? 0,
        activeSessions:      results[3].count ?? 0,
      );
    } catch (e) {
      debugPrint('[TenantService] Error en analytics: $e');
      return const OrgAnalytics();
    }
  }

  // ── Membership CRUD ───────────────────────────────────────────────────────

  Future<MembershipModel> createMembership({
    required String userId,
    required String role,
    required String approvedBy,
    PlanType planType = PlanType.pyme,
  }) async {
    // ID determinístico requerido por Firestore Security Rules (§9):
    // las reglas hacen exists/get sobre '{userId}_{institutionId}' directamente.
    final deterministicId = '${userId}_$institutionId';
    final ref = _db.collection(AppConstants.colMemberships).doc(deterministicId);
    final membership = MembershipModel(
      id:            deterministicId,
      userId:        userId,
      institutionId: institutionId,
      role:          role,
      status:        MembershipStatus.approved,
      isActive:      true,
      approvedBy:    approvedBy,
      createdAt:     DateTime.now(),
      planType:      planType,
    );
    await ref.set(membership.toFirestore());

    // Actualizar counter en institution doc
    await _db
        .collection(AppConstants.colInstitutions)
        .doc(institutionId)
        .update({'memberCount': FieldValue.increment(1)});

    // Agregar membership ID al array del usuario
    await _db
        .collection(AppConstants.colUsers)
        .doc(userId)
        .update({'memberships': FieldValue.arrayUnion([ref.id])});

    return membership;
  }

  Future<void> updateMembershipRole(
    String membershipId,
    String newRole,
    String updatedBy,
  ) async {
    await _db.collection(AppConstants.colMemberships).doc(membershipId).update({
      'role':      newRole,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  Future<void> deactivateMembership(
    String membershipId,
    String deactivatedBy,
  ) async {
    await _db.collection(AppConstants.colMemberships).doc(membershipId).update({
      'isActive':      false,
      'status':        'suspended',
      'updatedAt':     FieldValue.serverTimestamp(),
      'deactivatedBy': deactivatedBy,
    });

    // Decrementar counter en institution
    await _db
        .collection(AppConstants.colInstitutions)
        .doc(institutionId)
        .update({'memberCount': FieldValue.increment(-1)});
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  Future<List<UserModel>> _fetchUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final List<UserModel> result = [];
    // Firestore whereIn max 30 por query
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      final snap = await _db
          .collection(AppConstants.colUsers)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      result.addAll(snap.docs.map(UserModel.fromFirestore));
    }
    return result;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Instancia de TenantService scoped al org activo.
/// Se invalida automáticamente cuando cambia la org activa.
final tenantServiceProvider = Provider<TenantService>((ref) {
  final orgId = ref.watch(orgContextProvider).activeOrgId;
  if (orgId == null) {
    throw StateError(
      'TenantService requiere una org activa. '
      'Asegúrate de llamar OrgContextNotifier.loadForUser() tras el login.',
    );
  }
  return TenantService(institutionId: orgId);
});

/// Lista de miembros de la org activa (stream reactivo).
final orgMembersStreamProvider = StreamProvider<List<OrgMember>>((ref) {
  return ref.watch(tenantServiceProvider).watchOrgMembers();
});

/// Lista de cursos de la org activa (stream reactivo).
final orgCoursesStreamProvider = StreamProvider<List<CourseModel>>((ref) {
  return ref.watch(tenantServiceProvider).watchOrgCourses();
});

/// Sesiones activas en la org activa (stream en tiempo real).
final orgActiveSessionsProvider = StreamProvider<List<SessionModel>>((ref) {
  return ref.watch(tenantServiceProvider).watchOrgActiveSessions();
});

/// Analytics de la org activa (future).
final orgAnalyticsProvider = FutureProvider<OrgAnalytics>((ref) {
  return ref.watch(tenantServiceProvider).getOrgAnalytics();
});

/// Para SUPER_ADMIN: stream de todas las instituciones.
final allInstitutionsStreamProvider =
    StreamProvider<List<InstitutionModel>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colInstitutions)
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(InstitutionModel.fromFirestore).toList());
});
