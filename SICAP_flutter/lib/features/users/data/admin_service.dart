import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/core/services/tenant_service.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart'
    show authStateProvider;
import 'package:siercp/features/users/data/models/user.dart';
import 'package:siercp/features/devices/data/models/maniqui.dart';
import 'package:siercp/features/notifications/data/models/notification.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/features/auth/data/firebase_auth_service.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(
    ref.read(firestoreServiceProvider),
    ref.read(firebaseAuthServiceProvider),
    ref,
  );
});

/// Lista de miembros de la org activa. Siempre filtrado por tenant.
/// Retorna lista vacía si no hay org activa (SuperAdmin sin org seleccionada).
final orgUsersProvider = FutureProvider<List<OrgMember>>((ref) {
  final orgId = ref.watch(orgContextProvider).activeOrgId;
  if (orgId == null) return Future.value([]);
  return ref.watch(tenantServiceProvider).getOrgMembers();
});

/// @deprecated Usar [orgUsersProvider]. Solo accesible para SUPER_ADMIN.
final allUsersProvider = FutureProvider<List<UserModel>>((ref) {
  final user = ref.watch(authStateProvider.select((s) => s.value?.user));
  if (user == null || !user.isSuperAdmin) return Future.value([]);
  return ref.read(adminServiceProvider).getAllUsersGlobal();
});

final allManiquisProvider = FutureProvider<List<ManiquiModel>>((ref) {
  return ref.read(adminServiceProvider).getManiquis();
});

// ── AdminService ──────────────────────────────────────────────────────────────

class AdminService {
  final FirestoreService _db;
  final FirebaseAuthService _authSvc;
  final Ref _ref;

  AdminService(this._db, this._authSvc, this._ref);

  // ── Creación de usuario (siempre crea membership a la org del admin) ───────

  /// Crea un usuario nuevo y lo vincula a la org del admin.
  Future<UserModel> adminCreateUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? identificacion,
    String? institutionId,
    String? approvedBy,
  }) async {
    final orgId = institutionId ??
        _ref.read(orgContextProvider).activeOrgId ??
        (throw StateError('No hay organización activa para asignar al usuario.'));

    final user = await _authSvc.adminCreateUser(
      email:          email,
      password:       password,
      firstName:      firstName,
      lastName:       lastName,
      role:           role,
      identificacion: identificacion,
    );

    // Crear membership explícitamente con el orgId resuelto
    await TenantService(institutionId: orgId).createMembership(
      userId:     user.id,
      role:       role,
      approvedBy: approvedBy ?? '',
    );

    await _db.createNotification(
      NotificationModel(
        id:        '',
        userId:    user.id,
        title:     'Bienvenido a SIERCP',
        message:   'Tu cuenta ha sido creada y asignada a la organización.',
        createdAt: DateTime.now(),
        type:      NotificationType.systemAlert,
      ),
    );

    _ref.invalidate(orgUsersProvider);
    return user;
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Retorna usuarios de la org activa (org-scoped).
  Future<List<OrgMember>> getOrgUsers({String? role}) {
    return _ref.read(tenantServiceProvider).getOrgMembers(role: role);
  }

  /// SOLO SUPER_ADMIN — todos los usuarios del sistema.
  Future<List<UserModel>> getAllUsersGlobal() => _db.getAllUsers();

  Future<List<ManiquiModel>> getManiquis() => _db.getManikins();

  // ── Acciones sobre usuarios ───────────────────────────────────────────────

  Future<void> toggleUserActive(String userId) =>
      _db.toggleUserActive(userId);

  /// Desactiva la membership del usuario en la org activa (no borra la cuenta).
  Future<void> removeFromOrg(String userId, String removedBy) async {
    final membership = await _ref
        .read(tenantServiceProvider)
        .getMembershipForUser(userId);
    if (membership != null) {
      await _ref
          .read(tenantServiceProvider)
          .deactivateMembership(membership.id, removedBy);
    }
    _ref.invalidate(orgUsersProvider);
  }

  // Elimina al usuario de la org, desactiva su cuenta en Firestore y llama
  // la Cloud Function para borrar el registro en Firebase Auth. Las tres
  // operaciones son independientes: si la CF falla, el usuario ya está
  // desactivado en Firestore y no puede acceder al panel.
  Future<void> deleteUser(String userId) async {
    await removeFromOrg(userId, 'admin-delete');
    await _db.updateUserPrivileged(userId, isActive: false, accountStatus: 'deleted');

    // Borrado duro de la cuenta de Auth vía Vercel (plan Spark — sin Cloud
    // Functions). Best-effort: si falla, el usuario ya está desactivado en
    // Firestore y no puede entrar.
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null) {
        await http.post(
          Uri.parse('${AppConstants.apiBaseUrl}/admin/delete-user'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({'targetUid': userId}),
        );
      }
    } catch (e) {
      debugPrint('[AdminService] delete-user (non-fatal): $e');
    }

    _ref.invalidate(orgUsersProvider);
    _ref.invalidate(allUsersProvider);
  }

  Future<void> changeUserRole(
    String membershipId,
    String newRole,
    String updatedBy,
  ) {
    if (!AppConstants.assignableRoles.contains(newRole)) {
      throw ArgumentError(
        'Rol inválido: "$newRole". Debe ser uno de ${AppConstants.assignableRoles}.',
      );
    }
    return _ref
        .read(tenantServiceProvider)
        .updateMembershipRole(membershipId, newRole, updatedBy);
  }

  // ── Buscar usuario por cédula (sin check de membresía) ───────────────────

  /// Devuelve el usuario con esa cédula o null. No verifica membresía.
  /// Usado para mostrar preview antes de inscribir desde la creación de curso.
  Future<UserModel?> findUserByCedula(String cedula) =>
      _db.getUserByIdentificacion(cedula);

  // ── Inscribir estudiante por cédula ───────────────────────────────────────

  Future<void> enrollStudentByCedula({
    required String courseId,
    required String cedula,
    required String instructorId,
  }) async {
    final student = await _db.getUserByIdentificacion(cedula);
    if (student == null) {
      throw Exception('No se encontró ningún usuario con esa cédula.');
    }
    if (!student.isStudent) {
      throw Exception('El usuario no tiene rol de Estudiante.');
    }

    final isMember =
        await _ref.read(tenantServiceProvider).isMember(student.id);
    if (!isMember) {
      throw Exception(
        'El estudiante no pertenece a esta organización. '
        'Invítalo primero desde el directorio de usuarios.',
      );
    }

    await _db.enrollStudent(
      courseId:       courseId,
      studentId:      student.id,
      studentName:    student.fullName,
      studentEmail:   student.email,
      identificacion: student.identificacion,
    );

    final course = await _db.getCourse(courseId);
    if (course != null) {
      await _db.createNotification(
        NotificationModel(
          id:        '',
          userId:    student.id,
          title:     'Nuevo curso asignado',
          message:   'Has sido inscrito en el curso "${course.title}"',
          createdAt: DateTime.now(),
          type:      NotificationType.studentAddedToCourse,
          extraData: {'courseId': courseId},
        ),
      );
    }
  }

  // ── Inscribir estudiante directamente por cédula (desde creación de curso) ──
  // No verifica membresía: el instructor ya decidió agregarlo al crear el curso.
  // La autorización la controlan las Firestore Rules (instructorId == uid).

  Future<void> enrollStudentByCedulaDirect({
    required String courseId,
    required String cedula,
    required String instructorId,
  }) async {
    final student = await _db.getUserByIdentificacion(cedula);
    if (student == null) {
      throw Exception('No se encontró ningún usuario con cédula $cedula.');
    }

    await _db.enrollStudent(
      courseId:       courseId,
      studentId:      student.id,
      studentName:    student.fullName,
      studentEmail:   student.email,
      identificacion: student.identificacion,
    );

    final course = await _db.getCourse(courseId);
    if (course != null) {
      await _db.createNotification(
        NotificationModel(
          id:        '',
          userId:    student.id,
          title:     'Nuevo curso asignado',
          message:   'Has sido inscrito en el curso "${course.title}"',
          createdAt: DateTime.now(),
          type:      NotificationType.studentAddedToCourse,
          extraData: {'courseId': courseId},
        ),
      );
    }
  }
}
