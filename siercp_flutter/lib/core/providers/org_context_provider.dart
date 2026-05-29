import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/models/institution.dart';
import 'package:siercp/core/models/membership.dart';
import 'package:siercp/core/Security/secure_storage_service.dart';

// ── Estado del contexto de organización activo ────────────────────────────────

class OrgContextState {
  final String? activeOrgId;
  final String? activeOrgName;
  final MembershipModel? activeMembership;
  final List<MembershipModel> allMemberships;
  final InstitutionModel? activeInstitution;
  final bool isLoading;

  const OrgContextState({
    this.activeOrgId,
    this.activeOrgName,
    this.activeMembership,
    this.allMemberships = const [],
    this.activeInstitution,
    this.isLoading = false,
  });

  bool get hasOrg => activeOrgId != null;
  bool get isMultiOrg => allMemberships.length > 1;

  /// Rol del usuario en la org activa (null si no hay org seleccionada).
  String? get activeRole => activeMembership?.role;

  // SECURITY (MED-06): isSuperAdmin must NEVER be derived from a membership
  // document, because any admin could create a membership with role=SUPER_ADMIN.
  // SuperAdmin status is a global property checked from UserModel.role (via
  // authStateProvider). OrgContextState only handles org-scoped roles.
  bool get isSuperAdmin => false;
  bool get isAdmin      => activeRole == AppConstants.roleAdmin;
  bool get isInstructor => activeRole == AppConstants.roleInstructor || isAdmin;

  bool get canManageUsers   => isAdmin;
  bool get canManageCourses => isInstructor;
  bool get canViewAnalytics => isAdmin;

  OrgContextState copyWith({
    String? activeOrgId,
    String? activeOrgName,
    MembershipModel? activeMembership,
    List<MembershipModel>? allMemberships,
    InstitutionModel? activeInstitution,
    bool? isLoading,
  }) =>
      OrgContextState(
        activeOrgId:       activeOrgId ?? this.activeOrgId,
        activeOrgName:     activeOrgName ?? this.activeOrgName,
        activeMembership:  activeMembership ?? this.activeMembership,
        allMemberships:    allMemberships ?? this.allMemberships,
        activeInstitution: activeInstitution ?? this.activeInstitution,
        isLoading:         isLoading ?? this.isLoading,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class OrgContextNotifier extends Notifier<OrgContextState> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  OrgContextState build() => const OrgContextState();

  // ── Carga inicial tras login ──────────────────────────────────────────────

  /// Llamado justo después de que el login es exitoso.
  /// Carga todas las memberships del usuario y activa la org correcta.
  Future<void> loadForUser(String userId) async {
    state = state.copyWith(isLoading: true);

    try {
      final memberships = await _fetchActiveMemberships(userId);

      if (memberships.isEmpty) {
        // Usuario sin org asignada aún (recién registrado o sin invite)
        state = const OrgContextState(allMemberships: []);
        return;
      }

      // Intentar restaurar la última org usada
      final storage = SecureStorageService();
      final lastOrgId = await storage.read(SecureKeys.lastOrgId);

      MembershipModel target;
      if (lastOrgId != null) {
        target = memberships.firstWhere(
          (m) => m.institutionId == lastOrgId,
          orElse: () => memberships.first,
        );
      } else {
        target = memberships.first;
      }

      await _activateOrg(target, memberships);
    } catch (e) {
      debugPrint('[OrgContext] Error cargando org para usuario: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // ── Cambio de org activa ──────────────────────────────────────────────────

  // SECURITY (ARCH-05): re-fetches memberships from Firestore before switching
  // so that revoked memberships (admin removed user while in session) are not
  // honoured from the stale in-memory list.
  Future<void> switchOrg(String orgId) async {
    state = state.copyWith(isLoading: true);
    try {
      final currentUserId = state.allMemberships.isNotEmpty
          ? state.allMemberships.first.userId
          : null;
      if (currentUserId == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final freshMemberships = await _fetchActiveMemberships(currentUserId);
      final membership = freshMemberships.firstWhere(
        (m) => m.institutionId == orgId,
        orElse: () => throw StateError('El usuario no pertenece a la org $orgId'),
      );
      await _activateOrg(membership, freshMemberships);
    } catch (e) {
      debugPrint('[OrgContext] switchOrg error: $e');
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  // ── Agregar nueva membership (sin recargar todo) ──────────────────────────

  void addMembership(MembershipModel membership) {
    final updated = [...state.allMemberships, membership];
    state = state.copyWith(allMemberships: updated);
  }

  // ── Reset (logout) ────────────────────────────────────────────────────────

  void reset() {
    state = const OrgContextState();
  }

  // ── Privado ───────────────────────────────────────────────────────────────

  Future<void> _activateOrg(
    MembershipModel membership,
    List<MembershipModel> allMemberships,
  ) async {
    // Guardar en SecureStorage para próxima sesión
    final storage = SecureStorageService();
    await storage.write(SecureKeys.lastOrgId, membership.institutionId);

    // Cargar datos de la institución
    InstitutionModel? institution;
    try {
      final doc = await _db
          .collection(AppConstants.colInstitutions)
          .doc(membership.institutionId)
          .get()
          .timeout(const Duration(seconds: 5));
      if (doc.exists) institution = InstitutionModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('[OrgContext] No se pudo cargar institución: $e');
    }

    state = OrgContextState(
      activeOrgId:       membership.institutionId,
      activeOrgName:     institution?.name ?? 'Mi Organización',
      activeMembership:  membership,
      allMemberships:    allMemberships,
      activeInstitution: institution,
      isLoading:         false,
    );
  }

  Future<List<MembershipModel>> _fetchActiveMemberships(String userId) async {
    try {
      // Aceptamos status 'approved' (asignado por admin via app) y
      // 'active' (seteado directamente desde la consola Firebase o Cloud Function).
      // whereIn requiere un índice compuesto en Firestore.
      final snap = await _db
          .collection(AppConstants.colMemberships)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .where('status', whereIn: ['approved', 'active'])
          .get()
          .timeout(const Duration(seconds: 5));
      return snap.docs.map(MembershipModel.fromFirestore).toList();
    } catch (e) {
      debugPrint('[OrgContext] Error fetching memberships: $e');
      return [];
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final orgContextProvider =
    NotifierProvider<OrgContextNotifier, OrgContextState>(
  OrgContextNotifier.new,
);

/// Shortcut: ID de la org activa. Lanza si no hay contexto cargado.
final activeOrgIdProvider = Provider<String>((ref) {
  final orgId = ref.watch(orgContextProvider).activeOrgId;
  if (orgId == null) throw StateError('No hay organización activa cargada.');
  return orgId;
});

/// Shortcut: membership activa (puede ser null mientras carga).
final activeMembershipProvider = Provider<MembershipModel?>((ref) {
  return ref.watch(orgContextProvider).activeMembership;
});

/// Stream de datos actualizados de la institución activa.
final activeInstitutionStreamProvider =
    StreamProvider<InstitutionModel?>((ref) {
  final orgId = ref.watch(orgContextProvider).activeOrgId;
  if (orgId == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection(AppConstants.colInstitutions)
      .doc(orgId)
      .snapshots()
      .map((doc) => doc.exists ? InstitutionModel.fromFirestore(doc) : null);
});
