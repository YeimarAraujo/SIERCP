import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:siercp/core/models/membership.dart';
import 'package:siercp/core/providers/org_context_provider.dart';
import 'package:siercp/core/services/tenant_service.dart';
import 'package:siercp/core/services/firestore_service.dart';
import 'package:siercp/features/auth/data/firebase_auth_service.dart';
import 'package:siercp/features/notifications/data/models/notification.dart';
import 'package:siercp/features/users/data/models/user.dart';

// ── Resultado de la operación invite/create ───────────────────────────────────

enum InviteResultType { newUserCreated, existingUserAdded, alreadyMember }

class InviteResult {
  final InviteResultType type;
  final UserModel user;
  final MembershipModel membership;
  final String message;

  const InviteResult._({
    required this.type,
    required this.user,
    required this.membership,
    required this.message,
  });

  factory InviteResult.newUserCreated(
          UserModel user, MembershipModel membership) =>
      InviteResult._(
        type:       InviteResultType.newUserCreated,
        user:       user,
        membership: membership,
        message:    '✓ Usuario creado y vinculado a la organización.',
      );

  factory InviteResult.existingUserAdded(
          UserModel user, MembershipModel membership) =>
      InviteResult._(
        type:       InviteResultType.existingUserAdded,
        user:       user,
        membership: membership,
        message:    '✓ Usuario existente añadido a esta organización.',
      );

  factory InviteResult.alreadyMember(
          UserModel user, MembershipModel membership) =>
      InviteResult._(
        type:       InviteResultType.alreadyMember,
        user:       user,
        membership: membership,
        message:    'Este usuario ya pertenece a la organización.',
      );

  bool get isSuccess =>
      type == InviteResultType.newUserCreated ||
      type == InviteResultType.existingUserAdded;
}

// ── Repositorio ───────────────────────────────────────────────────────────────

class UserOrgRepository {
  final FirestoreService _db;
  final FirebaseAuthService _authSvc;
  final TenantService _tenant;

  UserOrgRepository({
    required FirestoreService db,
    required FirebaseAuthService authSvc,
    required TenantService tenant,
  })  : _db = db,
        _authSvc = authSvc,
        _tenant = tenant;

  /// Flujo principal: busca si el usuario existe en el sistema.
  /// - Si existe y YA es miembro de la org → retorna [InviteResult.alreadyMember].
  /// - Si existe pero NO es miembro       → agrega la membership.
  /// - Si NO existe                       → crea cuenta + membership.
  Future<InviteResult> inviteOrCreate({
    required String email,
    required String role,
    required String approvedBy,
    String? firstName,
    String? lastName,
    String? identificacion,
    String? password,
  }) async {
    // 1. Buscar usuario por email en el sistema
    final existing = await _db.getUserByEmail(email);

    if (existing != null) {
      // 2. Ya existe en el sistema — verificar si ya es miembro de esta org
      final existingMembership =
          await _tenant.getMembershipForUser(existing.id);

      if (existingMembership != null) {
        return InviteResult.alreadyMember(existing, existingMembership);
      }

      // 3. No es miembro todavía — solo crear la membership
      final membership = await _tenant.createMembership(
        userId:     existing.id,
        role:       role,
        approvedBy: approvedBy,
      );

      await _db.createNotification(
        NotificationModel(
          id:        '',
          userId:    existing.id,
          title:     'Acceso a nueva organización',
          message:   'Has sido añadido a una nueva organización en SIERCP.',
          createdAt: DateTime.now(),
          type:      NotificationType.systemAlert,
        ),
      );

      return InviteResult.existingUserAdded(existing, membership);
    }

    // 4. No existe — crear cuenta + membership
    final effectivePassword =
        password ?? _generateTempPassword();

    final newUser = await _authSvc.adminCreateUser(
      email:          email,
      password:       effectivePassword,
      firstName:      firstName ?? '',
      lastName:       lastName ?? '',
      role:           role,
      identificacion: identificacion,
    );

    final membership = await _tenant.createMembership(
      userId:     newUser.id,
      role:       role,
      approvedBy: approvedBy,
    );

    await _db.createNotification(
      NotificationModel(
        id:        '',
        userId:    newUser.id,
        title:     'Bienvenido a SIERCP',
        message:   'Tu cuenta ha sido creada. Revisa tu email para acceder.',
        createdAt: DateTime.now(),
        type:      NotificationType.systemAlert,
      ),
    );

    return InviteResult.newUserCreated(newUser, membership);
  }

  // HIGH-02 fix: replaced predictable timestamp-based seed with Random.secure(),
  // which uses the OS CSPRNG (urandom on Linux/Android, SecRandomCopyBytes on iOS).
  String _generateTempPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$';
    final rng = Random.secure();
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Retorna null mientras el orgContext está cargando (activeOrgId == null).
/// Se reconstruye automáticamente cuando cambia la org activa.
final userOrgRepositoryProvider = Provider<UserOrgRepository?>((ref) {
  final orgId = ref.watch(orgContextProvider).activeOrgId;
  if (orgId == null) return null;
  return UserOrgRepository(
    db:      ref.read(firestoreServiceProvider),
    authSvc: ref.read(firebaseAuthServiceProvider),
    // Crear TenantService directamente con el orgId ya validado,
    // evitando el StateError de tenantServiceProvider durante la carga.
    tenant:  TenantService(institutionId: orgId),
  );
});

/// Provider que escucha la org activa para saber si el contexto está listo.
final orgReadyProvider = Provider<bool>((ref) {
  return ref.watch(orgContextProvider).hasOrg;
});
