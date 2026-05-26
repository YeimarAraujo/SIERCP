import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:siercp/core/constants/constants.dart';

class ChangeRoleUseCase {
  const ChangeRoleUseCase();

  Future<void> execute({
    required String userId,
    required String newRole,
    required String actorId,
    String? membershipId,
    String? institutionId,
  }) async {
    if (!AppConstants.assignableRoles.contains(newRole)) {
      throw ArgumentError('Rol no asignable: $newRole');
    }

    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // Actualizar rol global del usuario
    batch.update(db.collection(AppConstants.colUsers).doc(userId), {
      'role':      newRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Si se especifica una membership, actualizar también el rol en la org
    if (membershipId != null && membershipId.isNotEmpty) {
      batch.update(db.collection(AppConstants.colMemberships).doc(membershipId), {
        'role':       newRole,
        'approvedBy': actorId,
        'updatedAt':  FieldValue.serverTimestamp(),
      });
    } else if (institutionId != null && institutionId.isNotEmpty) {
      // Buscar la membership activa del usuario en la org
      final snap = await db
          .collection(AppConstants.colMemberships)
          .where('userId', isEqualTo: userId)
          .where('institutionId', isEqualTo: institutionId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        batch.update(snap.docs.first.reference, {
          'role':       newRole,
          'approvedBy': actorId,
          'updatedAt':  FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }
}
