import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:siercp/core/constants/constants.dart';
import 'package:siercp/core/use_cases/user/user_use_case_params.dart';
import 'package:siercp/features/auth/data/firebase_auth_service.dart';
import 'package:siercp/features/users/data/models/user.dart';

class CreateUserUseCase {
  final FirebaseAuthService _auth;

  const CreateUserUseCase({required FirebaseAuthService auth}) : _auth = auth;

  Future<UserModel> execute(CreateUserParams params) async {
    // Nunca se puede crear un SUPER_ADMIN desde la app cliente
    if (params.role == AppConstants.roleSuperAdmin) {
      throw ArgumentError('No se puede crear un SUPER_ADMIN desde la aplicación.');
    }

    // Crear usuario en Firebase Auth + Firestore
    final user = await _auth.adminCreateUser(
      email:          params.email,
      password:       params.password,
      firstName:      params.firstName,
      lastName:       params.lastName,
      role:           params.role,
      identificacion: params.identificacion,
    );

    // Si tiene institutionId, crear membership
    if (params.institutionId != null && params.institutionId!.isNotEmpty) {
      final db = FirebaseFirestore.instance;
      final membershipId = '${params.institutionId}_${user.id}';
      await db.collection(AppConstants.colMemberships).doc(membershipId).set({
        'userId':        user.id,
        'institutionId': params.institutionId,
        'role':          params.role,
        'status':        'approved',
        'isActive':      true,
        'approvedBy':    params.approvedBy ?? '',
        'createdAt':     FieldValue.serverTimestamp(),
        'updatedAt':     FieldValue.serverTimestamp(),
      });

      // Notificación de bienvenida
      await db.collection(AppConstants.colNotifications).add({
        'userId':    user.id,
        'title':     'Bienvenido a SIERCP',
        'body':      'Tu cuenta ha sido creada y vinculada a la organización.',
        'type':      'welcome',
        'read':      false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return user;
  }
}
